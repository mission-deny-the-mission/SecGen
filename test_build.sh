#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /home/harry/new_hackerbot_zeroclaw/SecGen
rbenv local 3.2.2
rm -rf /tmp/test_secgen_project
bundle exec ruby secgen.rb build-project --project /tmp/test_secgen_project 2>&1 | tail -50
