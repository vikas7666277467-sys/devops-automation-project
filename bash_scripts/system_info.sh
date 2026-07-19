#!/bin/bash

echo "========== System Information =========="

echo "Hostname: $(hostname)"
echo "Current User: $(whoami)"
echo "Operating System:"
uname -a

echo
echo "Uptime:"
uptime

echo
echo "CPU Information:"
lscpu | head -10

echo
echo "Memory:"
free -h

echo
echo "Disk:"
df -h

echo
echo "Network:"
hostname -I

echo
echo "========== End of Report =========="