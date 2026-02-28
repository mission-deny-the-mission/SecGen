#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /home/harry/new_hackerbot_zeroclaw/SecGen
rbenv local 3.3.0
ruby --version
gem --version
bundle --version
rm -rf vendor Gemfile.lock
# Revert Gemfile to use compatible versions
sed -i "s/gem 'librarian-puppet', '>= 5.0.0'/gem 'librarian-puppet'/" Gemfile
sed -i "s/gem 'puppet_forge', '>= 6.0.0'/gem 'puppet_forge'/" Gemfile
bundle install
