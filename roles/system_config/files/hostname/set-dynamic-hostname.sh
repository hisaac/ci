#!/bin/bash
# Generate a unique hostname on each boot to prevent Bonjour/mDNS conflicts
# when multiple VMs are cloned from the same base image.
# Inspired by:
# https://github.com/actions/runner-images/blob/main/images/macos/scripts/build/configure-hostname.sh

name="Mac-$(python3 -c 'from time import time; print(int(round(time() * 1000)))')"
scutil --set HostName "${name}.local"
scutil --set LocalHostName "${name}"
scutil --set ComputerName "${name}.local"
