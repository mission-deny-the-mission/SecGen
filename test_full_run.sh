#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /home/harry/new_hackerbot_zeroclaw/SecGen
rbenv local 3.2.2
rm -rf /tmp/test_secgen_vm
bundle exec ruby secgen.rb run -p /tmp/test_secgen_vm 2>&1
