#!/bin/bash
# Script to optimize Jenkins performance on existing instance
# Run this script on the Jenkins instance via SSH

set -e

echo "=== Jenkins Performance Optimization Script ==="
echo ""

# 1. Add swap space if not exists
if [ ! -f /swapfile ]; then
    echo "Creating 4GB swap file..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "Swap file created successfully"
else
    echo "Swap file already exists"
    sudo swapon --show
fi

# 2. Optimize swappiness
if ! grep -q "vm.swappiness=10" /etc/sysctl.conf; then
    echo "Optimizing swappiness..."
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo "Swappiness optimized"
else
    echo "Swappiness already optimized"
fi

# 3. Optimize Jenkins JVM settings
echo "Optimizing Jenkins JVM settings..."
sudo sed -i 's|JENKINS_JAVA_OPTIONS=.*|JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Xmx4g -Xms2g -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxMetaspaceSize=512m"|' /etc/default/jenkins

# 4. Optimize Docker daemon
echo "Optimizing Docker daemon..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10
}
EOF

# 5. Restart services
echo "Restarting Docker..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "Restarting Jenkins..."
sudo systemctl restart jenkins

# 6. Clean up old Docker images and containers
echo "Cleaning up old Docker images..."
docker system prune -af --volumes || true

# 7. Show current memory and swap
echo ""
echo "=== Current Memory Status ==="
free -h
echo ""
echo "=== Swap Status ==="
swapon --show
echo ""
echo "=== Jenkins JVM Settings ==="
grep JENKINS_JAVA_OPTIONS /etc/default/jenkins
echo ""
echo "=== Optimization Complete ==="
echo "Jenkins is restarting. Wait 30-60 seconds for Jenkins to be ready."
echo "Check status with: sudo systemctl status jenkins"

