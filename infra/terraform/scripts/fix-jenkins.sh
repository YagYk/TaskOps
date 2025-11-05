#!/bin/bash
# Script to fix Jenkins startup issues
# Run with sudo

set -e

echo "=== Fixing Jenkins Startup Issues ==="
echo ""

# Check Jenkins logs for errors
echo "Checking Jenkins logs for errors..."
sudo journalctl -u jenkins.service -n 50 --no-pager | tail -20
echo ""

# Check if swap file exists and is already mounted
if [ -f /swapfile ]; then
  echo "Swap file exists. Checking status..."
  sudo swapon --show
  echo ""
  
  # If swap is already active, we're good
  if sudo swapon --show | grep -q swapfile; then
    echo "Swap file is already active. Skipping swap creation."
  else
    echo "Swap file exists but not active. Activating..."
    sudo swapon /swapfile || echo "Swap activation failed, but continuing..."
  fi
else
  echo "No swap file found. Creating 1GB swap..."
  # Check available space first
  AVAILABLE=$(df / | tail -1 | awk '{print $4}')
  if [ "$AVAILABLE" -lt 1048576 ]; then
    echo "WARNING: Less than 1GB available. Creating smaller swap (512MB)..."
    sudo fallocate -l 512M /swapfile || echo "Failed to create swap file"
  else
    sudo fallocate -l 1G /swapfile || echo "Failed to create swap file"
  fi
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo ""
echo "Current swap status:"
sudo swapon --show
echo ""

# Check current Jenkins JVM settings
echo "Current Jenkins JVM settings:"
grep JENKINS_JAVA_OPTIONS /etc/default/jenkins || echo "No JVM settings found"
echo ""

# Fix Jenkins JVM settings (use conservative values)
echo "Setting Jenkins JVM settings (conservative for limited memory)..."
# Backup original file
sudo cp /etc/default/jenkins /etc/default/jenkins.backup

# Set conservative JVM settings (1GB max heap)
sudo sed -i 's|JENKINS_JAVA_OPTIONS=.*|JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Xmx1g -Xms512m -XX:+UseG1GC -XX:MaxMetaspaceSize=256m"|' /etc/default/jenkins

# Verify the change
echo "New Jenkins JVM settings:"
grep JENKINS_JAVA_OPTIONS /etc/default/jenkins
echo ""

# Check Jenkins home directory permissions
echo "Checking Jenkins home directory permissions..."
sudo chown -R jenkins:jenkins /var/lib/jenkins 2>/dev/null || true
echo ""

# Check if there's a corrupted config
if [ -f /var/lib/jenkins/config.xml ]; then
  echo "Checking Jenkins config.xml..."
  if ! sudo -u jenkins java -jar /usr/share/jenkins/jenkins.war -version 2>/dev/null; then
    echo "WARNING: Jenkins JAR might be corrupted, but continuing..."
  fi
fi

# Try to start Jenkins
echo "Attempting to start Jenkins..."
sudo systemctl daemon-reload
sudo systemctl reset-failed jenkins.service || true

# Wait a bit before starting
sleep 2

# Start Jenkins
sudo systemctl start jenkins

# Wait and check status
sleep 5
echo ""
echo "Jenkins status:"
sudo systemctl status jenkins.service --no-pager || true

echo ""
echo "=== Fix Complete ==="
echo "If Jenkins still fails, check logs with:"
echo "  sudo journalctl -u jenkins.service -f"

