#!/bin/bash
# Script to manually fix EKS access from Jenkins
# Run this script with AWS credentials configured

set -e

REGION="ap-south-1"
CLUSTER_NAME="taskops-k8s"
VPC_CIDR="10.0.0.0/16"

echo "=== Fixing EKS Access from Jenkins ==="
echo ""

# Get EKS cluster security group ID
echo "Getting EKS cluster security group..."
CLUSTER_SG=$(aws eks describe-cluster \
  --region $REGION \
  --name $CLUSTER_NAME \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

if [ -z "$CLUSTER_SG" ]; then
  echo "ERROR: Could not find EKS cluster security group"
  exit 1
fi

echo "EKS Cluster Security Group: $CLUSTER_SG"

# Get Jenkins security group ID
echo "Getting Jenkins security group..."
JENKINS_SG=$(aws ec2 describe-security-groups \
  --region $REGION \
  --filters "Name=group-name,Values=taskops-jenkins-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ -z "$JENKINS_SG" ]; then
  echo "ERROR: Could not find Jenkins security group"
  exit 1
fi

echo "Jenkins Security Group: $JENKINS_SG"

# Check if rule already exists for Jenkins SG
echo "Checking existing rules..."
EXISTING_RULE=$(aws ec2 describe-security-group-rules \
  --region $REGION \
  --filters "Name=group-id,Values=$CLUSTER_SG" "Name=is-egress,Values=false" \
    "Name=ip-protocol,Values=tcp" "Name=from-port,Values=443" "Name=to-port,Values=443" \
  --query "SecurityGroupRules[?GroupOwnerId=='' && SourcePrefixListId=='' && (ReferencedGroupInfo.GroupId=='$JENKINS_SG' || CidrIpv4=='$VPC_CIDR')].SecurityGroupRuleId" \
  --output text)

if [ -n "$EXISTING_RULE" ]; then
  echo "Security group rules already exist: $EXISTING_RULE"
else
  echo "Adding security group rules..."
  
  # Add rule for Jenkins security group
  echo "Adding rule for Jenkins security group..."
  aws ec2 authorize-security-group-ingress \
    --group-id $CLUSTER_SG \
    --protocol tcp \
    --port 443 \
    --source-group $JENKINS_SG \
    --region $REGION \
    --description "Allow Jenkins to access EKS cluster endpoint" || echo "Rule may already exist"
  
  # Add rule for VPC CIDR
  echo "Adding rule for VPC CIDR ($VPC_CIDR)..."
  aws ec2 authorize-security-group-ingress \
    --group-id $CLUSTER_SG \
    --protocol tcp \
    --port 443 \
    --cidr $VPC_CIDR \
    --region $REGION \
    --description "Allow access to EKS endpoint from VPC" || echo "Rule may already exist"
fi

# Verify rules
echo ""
echo "=== Verifying Security Group Rules ==="
aws ec2 describe-security-group-rules \
  --region $REGION \
  --filters "Name=group-id,Values=$CLUSTER_SG" "Name=is-egress,Values=false" \
    "Name=ip-protocol,Values=tcp" "Name=from-port,Values=443" "Name=to-port,Values=443" \
  --query 'SecurityGroupRules[*].[SecurityGroupRuleId,Description,ReferencedGroupInfo.GroupId,CidrIpv4]' \
  --output table

echo ""
echo "=== Fix Complete ==="
echo "Security group rules should now allow Jenkins to access EKS cluster"
echo "Try running the Jenkins pipeline again"

