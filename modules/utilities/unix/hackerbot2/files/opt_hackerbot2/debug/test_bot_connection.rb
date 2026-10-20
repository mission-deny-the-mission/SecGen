#!/usr/bin/env ruby

require 'socket'
require 'thread'

puts "Testing Hackerbot IRC Connection"
puts "=" * 40

# Connect to IRC server
begin
  socket = TCPSocket.new('localhost', 6667)
  puts "✓ Connected to IRC server on localhost:6667"

  # Send IRC commands
  socket.puts("NICK debugbot")
  socket.puts("USER debugbot 0 * :Debug Bot")
  socket.puts("JOIN #hackerbot")
  socket.puts("JOIN #bots")

  puts "✓ Sent IRC connection commands"

  # Wait for responses
  sleep(2)

  # Send test message to see if hackerbot responds
  socket.puts("PRIVMSG #hackerbot :hello")
  puts "✓ Sent 'hello' message to #hackerbot"

  # Listen for responses
  puts "\nListening for responses (10 seconds)..."
  start_time = Time.now

  while Time.now - start_time < 10
    ready = IO.select([socket], nil, nil, 1)
    if ready
      data = socket.gets
      if data
        puts "IRC: #{data.strip}"

        # Look for hackerbot messages
        if data.include?("Hackerbot") || data.include?("PRIVMSG")
          puts "🎯 Found potential Hackerbot response!"
        end
      end
    end
  end

  # Try another test
  puts "\nSending 'help' message..."
  socket.puts("PRIVMSG #hackerbot :help")

  # Listen for more responses
  start_time = Time.now
  while Time.now - start_time < 5
    ready = IO.select([socket], nil, nil, 1)
    if ready
      data = socket.gets
      if data
        puts "IRC: #{data.strip}"
      end
    end
  end

  socket.puts("QUIT")
  socket.close
  puts "\n✓ Test completed"

rescue => e
  puts "✗ Error: #{e.message}"
  puts "Make sure the IRC server is running on localhost:6667"
end
```

Now let me run this debug script to see what's happening:
