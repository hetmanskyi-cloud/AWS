#!/bin/bash
# Update Ubuntu and upgrade all packages

# Refresh package lists
sudo apt-get update -y

# Upgrade all packages
sudo apt-get upgrade -y

# Clean up any unnecessary packages
sudo apt-get autoremove -y
sudo apt-get clean
