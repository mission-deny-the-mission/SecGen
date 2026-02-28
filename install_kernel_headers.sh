#!/bin/bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
cd /home/harry/new_hackerbot_zeroclaw/SecGen
rbenv local 3.2.2
KERNEL_VER=$(uname -r)
echo "Running kernel: $KERNEL_VER"
sudo zypper install -y "kernel-default-devel = $KERNEL_VER" 2>&1 | tail -20
