#!/bin/bash
# stress-test.sh
# Used to trigger Auto Scaling Group scale-out during competition evaluation
# Simulates CPU load to validate step scaling policy thresholds

# Requires stress-ng: https://github.com/ColinIanKing/stress-ng
# Install: sudo apt install stress-ng  (Debian/Ubuntu)
#          sudo yum install stress-ng  (Amazon Linux/RHEL)

TARGET_LOAD=${1:-70}  # Default 70% CPU load; pass argument to override

echo "Starting CPU stress at ${TARGET_LOAD}% load on $(nproc) cores"
echo "Expected ASG behaviour:"
echo "  >= 75% CPU -> 3 instances"
echo "  50-75% CPU -> 2 instances"
echo "  < 50%  CPU -> 1 instance (scale-in)"
echo ""
echo "Warm-up / cooldown period: 60 seconds"
echo "CloudWatch detailed monitoring: 1-minute granularity"
echo ""
echo "Press Ctrl+C to stop"

stress-ng --cpu $(nproc) --cpu-method prime --cpu-load "$TARGET_LOAD"
