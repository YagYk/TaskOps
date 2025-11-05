#!/bin/bash
# Emergency disk cleanup script for Jenkins instance
# Run this when disk is full

set -e

echo "=== Emergency Disk Cleanup ==="
echo ""

# Show current disk usage
echo "Current disk usage:"
df -h / | head -2
echo ""

# Clean up Docker resources
echo "Cleaning up Docker resources..."
docker system prune -af --volumes || true
docker builder prune -af || true

# Clean up old Jenkins builds and logs
echo "Cleaning up Jenkins old builds..."
if [ -d /var/lib/jenkins/jobs ]; then
  find /var/lib/jenkins/jobs -name "builds" -type d -exec find {} -type d -mtime +7 -delete \; 2>/dev/null || true
  find /var/lib/jenkins/jobs -name "workspace" -type d -exec find {} -type f -mtime +7 -delete \; 2>/dev/null || true
fi

# Clean up old log files
echo "Cleaning up old log files..."
sudo journalctl --vacuum-time=7d || true
sudo find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
sudo find /var/log -name "*.gz" -type f -mtime +7 -delete 2>/dev/null || true

# Clean up APT cache
echo "Cleaning up APT cache..."
sudo apt-get clean || true
sudo apt-get autoclean || true

# Clean up old kernels (keep only 2 latest)
echo "Cleaning up old kernels..."
sudo apt-get autoremove -y || true

# Clean up temporary files
echo "Cleaning up temporary files..."
sudo rm -rf /tmp/* 2>/dev/null || true
sudo rm -rf /var/tmp/* 2>/dev/null || true

# Clean up old Jenkins workspace files
echo "Cleaning up Jenkins workspace files older than 7 days..."
if [ -d /var/lib/jenkins/workspace ]; then
  find /var/lib/jenkins/workspace -type f -mtime +7 -delete 2>/dev/null || true
  find /var/lib/jenkins/workspace -type d -empty -delete 2>/dev/null || true
fi

# Show disk usage after cleanup
echo ""
echo "Disk usage after cleanup:"
df -h / | head -2
echo ""

# Check available space
AVAILABLE=$(df / | tail -1 | awk '{print $4}')
echo "Available space: $AVAILABLE KB"

if [ "$AVAILABLE" -lt 2097152 ]; then
  echo "WARNING: Still less than 2GB available. More cleanup needed."
  echo ""
  echo "Largest directories:"
  sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
else
  echo "SUCCESS: Enough space available now!"
fi

echo ""
echo "=== Cleanup Complete ==="

