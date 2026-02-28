#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /tmp/test_secgen_vm
BUNDLE_GEMFILE= vagrant up 2>&1 | tail -50
