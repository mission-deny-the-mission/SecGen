#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install Ruby 3.2.2 which is compatible with SecGen and librarian-puppet 3.x
rbenv install 3.2.2

# Set it as local version for SecGen
cd /home/harry/new_hackerbot_zeroclaw/SecGen
rbenv local 3.2.2

# Verify
ruby --version
gem --version

# Reinstall gems with Ruby 3.2
rm -rf vendor Gemfile.lock
bundle install
