#!/bin/bash
# Aggressive disk cleanup for Jenkins when disk is full
# Run with sudo

set -e

echo "=== Aggressive Disk Cleanup ==="
echo ""

# Show current disk usage
echo "Before cleanup:"
df -h / | head -2
echo ""

# Clean up Docker with sudo
echo "Cleaning up Docker resources..."
sudo docker system prune -af --volumes || true
sudo docker builder prune -af || true

# Find largest directories in /var
echo "Finding largest directories in /var..."
sudo du -h --max-depth=1 /var 2>/dev/null | sort -hr | head -10
echo ""

# Clean up Jenkins old builds aggressively
echo "Cleaning up Jenkins old builds (keeping only last 5 builds per job)..."
if [ -d /var/lib/jenkins/jobs ]; then
  for job_dir in /var/lib/jenkins/jobs/*/builds; do
    if [ -d "$job_dir" ]; then
      # Keep only last 5 builds
      ls -t "$job_dir" 2>/dev/null | tail -n +6 | xargs -r sudo rm -rf
    fi
  done
fi

# Clean up Jenkins workspace files older than 1 day
echo "Cleaning up Jenkins workspace files older than 1 day..."
sudo find /var/lib/jenkins/workspace -type f -mtime +1 -delete 2>/dev/null || true
sudo find /var/lib/jenkins/workspace -type d -empty -delete 2>/dev/null || true

# Clean up Docker images and containers
echo "Removing all stopped containers..."
sudo docker container prune -f || true

echo "Removing all unused images..."
sudo docker image prune -af || true

# Clean up APT cache
echo "Cleaning up APT cache..."
sudo apt-get clean || true
sudo apt-get autoclean || true
sudo apt-get autoremove -y || true

# Clean up old logs in /var/log
echo "Cleaning up old log files..."
sudo find /var/log -name "*.log" -type f -mtime +3 -delete 2>/dev/null || true
sudo find /var/log -name "*.gz" -type f -mtime +7 -delete 2>/dev/null || true

# Clean up journal logs
echo "Vacuuming journal logs (keep only 1 day)..."
sudo journalctl --vacuum-time=1d || true

# Clean up snap packages (can free significant space)
echo "Cleaning up old snap versions..."
sudo snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
  sudo snap remove "$snapname" --revision="$revision" 2>/dev/null || true
done

# Clean up temporary files
echo "Cleaning up temporary files..."
sudo rm -rf /tmp/* 2>/dev/null || true
sudo rm -rf /var/tmp/* 2>/dev/null || true

# Clean up old Jenkins fingerprints
echo "Cleaning up Jenkins fingerprints..."
if [ -d /var/lib/jenkins/fingerprints ]; then
  sudo find /var/lib/jenkins/fingerprints -type f -mtime +7 -delete 2>/dev/null || true
fi

# Show disk usage after cleanup
echo ""
echo "After cleanup:"
df -h / | head -2
echo ""

# Show largest directories
echo "Largest directories remaining:"
sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
echo ""

AVAILABLE=$(df / | tail -1 | awk '{print $4}')
echo "Available space: $AVAILABLE KB"

if [ "$AVAILABLE" -lt 1048576 ]; then
  echo "WARNING: Still less than 1GB available."
  echo "Consider:"
  echo "1. Removing unused Docker images manually"
  echo "2. Cleaning up more Jenkins builds"
  echo "3. Increasing instance storage size"
else
  echo "SUCCESS: Enough space available!"
fi

