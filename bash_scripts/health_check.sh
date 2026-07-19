#!/bin/bash

echo "===== System Health Report ====="

echo ""
echo "Hostname:"
hostname

echo ""
echo "Date:"
date

echo ""
echo "CPU Load:"
uptime

echo ""
echo "Memory Usage:"
free -h

echo ""
echo "Disk Usage:"
df -h

echo ""
echo "Top 5 Memory Consuming Processes:"
ps -eo pid,comm,%mem --sort=-%mem | head -6

echo ""
echo "Health Check Completed Successfully."