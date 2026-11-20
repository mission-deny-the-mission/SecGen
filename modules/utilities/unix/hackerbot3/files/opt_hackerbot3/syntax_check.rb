#!/usr/bin/env ruby

# Test the problematic code block structure
def test_structure
  got_shell = true

  if got_shell
    puts "Shell success"

    post_cmd = "some command"
    if post_cmd
      puts "Running post command"
    end

    post_lines = "output"
    puts post_lines
  else
    puts "Shell failed..."

    if true
      puts "Error message"
    else
      puts "Default message"
    end
  end
end

test_structure
