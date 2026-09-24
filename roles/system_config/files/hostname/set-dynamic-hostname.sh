#!/bin/bash
# Generate a unique hostname on each boot to prevent Bonjour/mDNS conflicts
# when multiple VMs are cloned from the same base image.
# Inspired by:
# https://github.com/actions/runner-images/blob/main/images/macos/scripts/build/configure-hostname.sh

name="tart-$(/usr/bin/uuidgen)"
scutil --set HostName "${name}.local"
scutil --set LocalHostName "${name}"
scutil --set ComputerName "${name}.local"
