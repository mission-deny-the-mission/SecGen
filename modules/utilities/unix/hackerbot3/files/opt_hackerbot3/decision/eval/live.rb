#!/usr/bin/env ruby
# Runs the 219 synthetic lab-help messages through DecisionRouter against REAL servers and scores them like replay.rb.
#   HB3_DECISION_URL=http://10.1.1.66:8001 HB3_DECISION_MODEL=clef-flash \
#   HB3_EMBED_URL=http://10.1.1.65:8002 HB3_EMBED_MODEL=qwen3-embedding \
#   ruby decision/eval/live.rb [strategy=twopass] [threshold=0.5]
# Messages go one at a time (no burst), so this measures accuracy and single-student latency only.
require 'json'
require_relative '../../print'
require_relative '../decision_router'
strategy = ARGV[0] || 'twopass'
t = (ARGV[1] || 0.5).to_f
cases = JSON.parse(File.read(File.expand_path('labhelp_tests.json', __dir__)))['cases']
pairs = File.expand_path('../pairs/labhelp_pairs.json', __dir__)
routers = {}
mk = lambda do |lab|
  DecisionRouter.new(pairs_file: pairs, lab: lab, url: ENV.fetch('HB3_DECISION_URL'), model: ENV['HB3_DECISION_MODEL'],
                     embed_url: ENV['HB3_EMBED_URL'], embed_model: ENV['HB3_EMBED_MODEL'], api_key: ENV['HB3_API_KEY'], strategy: strategy,
                     threshold: t, timeout: 30)
end
cases.map { |c| c['lab'] }.uniq.each { |lab| routers[lab] = mk.call(lab); 2.times { routers[lab].route('warmup message') } }
tally = Hash.new(0); lat = []; second = 0; misses = []
cases.each do |c|
  res = routers[c['lab']].route(c['message'])
  lat << res.latency_ms; second += 1 if res.second_pass
  exp = c['expected']
  out = if res.canned?
          if res.pair_id == exp then 'right'
          elsif exp == 'escalate' then 'false_canned'
          elsif c['kind'] == 'assess' then 'leak'
          else 'wrong_canned' end
        else
          exp == 'escalate' ? 'right_fallback' : 'missed'
        end
  tally[out] += 1
  misses << [out, c['message'], exp, res.pair_id, res.probability&.round(2)] if %w[wrong_canned false_canned leak].include?(out)
  $stderr.puts "error row: #{res.reason}" if res.reason.to_s.start_with?('error')
end
answerable = cases.count { |c| c['expected'] != 'escalate' }
right = tally['right']; bad = tally['wrong_canned'] + tally['false_canned'] + tally['leak']
lat.sort!
puts "strategy=#{strategy} T=#{t} n=#{cases.size} #{tally.sort.to_h}"
puts format('precision %.1f%%  coverage %.1f%% (%d/%d)  median %d ms  p95 %d ms  second-pass %d', 100.0 * right / [right + bad, 1].max, 100.0 * right / answerable, right, answerable, lat[lat.size / 2], lat[(lat.size * 0.95).to_i], second)
misses.each { |m| puts "  #{m[0]}: #{m[1].inspect} expected=#{m[2]} got=#{m[3]} p=#{m[4]}" }
