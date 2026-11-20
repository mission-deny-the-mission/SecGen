#!/usr/bin/env ruby
# Replays saved decision-model probabilities (raw_lh_*.json from the lab-help sweeps) through DecisionRouter
# (strategy full) and scores it the way the sweeps did: right / wrong canned / false canned / missed / leak.
#   ruby decision/eval/replay.rb raw_lh_clefflash.json [threshold]
require 'json'
require_relative '../../print'
require_relative '../decision_router'
raw = JSON.parse(File.read(ARGV.fetch(0)))['rows']
t = (ARGV[1] || 0.5).to_f
cases = JSON.parse(File.read(File.expand_path('labhelp_tests.json', __dir__)))['cases']
pairs = File.expand_path('../pairs/labhelp_pairs.json', __dir__)
tally = Hash.new(0)
raw.each do |row|
  post = ->(_u, _b, _t) { { 'answers' => { 'best_match' => { 'probabilities' => row['probs'].transform_keys { |k| k } } } } }
  r = DecisionRouter.new(pairs_file: pairs, lab: row['lab'], url: 'http://replay', http_post: post, strategy: 'full', threshold: t)
  res = r.route(row['message'])
  exp = row['expected'] == 'ESCALATE' ? 'escalate' : row['expected']
  kind = row['kind']
  out =
    if res.canned?
      if res.pair_id == exp then 'right'
      elsif exp == 'escalate' then 'false_canned'
      else kind == 'assess' ? 'leak' : 'wrong_canned'
      end
    else
      exp == 'escalate' ? 'right_fallback' : 'missed'
    end
  tally[out] += 1
end
answerable = raw.count { |r| r['expected'] != 'ESCALATE' }
right = tally['right']
bad = tally['wrong_canned'] + tally['false_canned'] + tally['leak']
puts "T=#{t}  n=#{raw.size}  #{tally.sort.to_h}"
puts format('precision %.1f%%  coverage %.1f%% (%d/%d answerable)', 100.0 * right / [right + bad, 1].max, 100.0 * right / answerable, right, answerable)
