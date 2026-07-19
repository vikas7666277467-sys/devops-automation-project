#!/bin/bash

LOG_DIR="/var/log"

echo "===== Log Cleanup Started ====="

find $LOG_DIR -type f -name "*.log" -mtime +7 -exec rm -f {} \;

echo "Old log files removed successfully."

echo "Cleanup Completed."