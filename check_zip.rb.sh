#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /home/harry/new_hackerbot_zeroclaw/SecGen
rbenv local 3.3.0
bundle exec ruby -e "require 'zip'; puts Zip::File.instance_methods.grep(/create|open|new/i)"
