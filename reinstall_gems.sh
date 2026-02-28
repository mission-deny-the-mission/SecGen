#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /home/harry/new_hackerbot_zeroclaw/SecGen
rbenv local 3.2.2
rm -rf vendor Gemfile.lock
bundle install 2>&1 | tail -20
