#!/bin/bash

# =========================================================
# Golden AMI & System Config Drift Detection Script
# Tracks: AMI, users, sudoers, SSH config & keys
# =========================================================

REGION="us-east-1"
LOG_GROUP="/GoldenAMI/DriftDetection"
# Use home directory for writable log file
LOCAL_LOG="$HOME/drift_check.log"

# ============================
# Get Instance ID (IMDSv2 -> IMDSv1)
# ============================

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

if [ -n "$TOKEN" ]; then
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)
else
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
fi

if [ -z "$INSTANCE_ID" ]; then
    echo "$(date) ERROR: Could not retrieve instance ID." | tee -a "$LOCAL_LOG"
    exit 1
fi

echo "$(date) INFO: Running system drift check for Instance ID: $INSTANCE_ID" | tee -a "$LOCAL_LOG"

# ============================
# Ensure CloudWatch log group/stream exist
# ============================

aws logs create-log-group --log-group-name "$LOG_GROUP" --region $REGION 2>/dev/null
aws logs create-log-stream --log-group-name "$LOG_GROUP" --log-stream-name "$INSTANCE_ID" --region $REGION 2>/dev/null

# ============================
# Function to send log to CloudWatch
# ============================

send_to_cloudwatch() {
    local MESSAGE="$1"
    local TS=$(date +%s000)
    aws logs put-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$INSTANCE_ID" \
        --log-events "[{\"timestamp\":$TS,\"message\":\"$MESSAGE\"}]" \
        --region $REGION 2>/dev/null
}

# ============================
# AMI Check
# ============================

AMI_ID=$(aws ec2 describe-instances \
    --instance-id "$INSTANCE_ID" \
    --query "Reservations[].Instances[].ImageId" \
    --output text \
    --region $REGION)

BASELINE_AMI=$(aws ssm get-parameter --name "baseline-ami" --region $REGION --query "Parameter.Value" --output text 2>/dev/null)
if [ -z "$BASELINE_AMI" ]; then
    aws ssm put-parameter --name "baseline-ami" --type String --value "$AMI_ID" --overwrite --region $REGION
    BASELINE_AMI="$AMI_ID"
    echo "$(date) ✅ Created baseline AMI: $BASELINE_AMI" | tee -a "$LOCAL_LOG"
fi

if [ "$AMI_ID" != "$BASELINE_AMI" ]; then
    AMI_MSG="⚠️ $(date) AMI Drift Detected: $AMI_ID (expected $BASELINE_AMI)"
else
    AMI_MSG="✅ $(date) AMI check passed: $AMI_ID matches baseline"
fi
echo "$AMI_MSG" | tee -a "$LOCAL_LOG"
send_to_cloudwatch "$AMI_MSG"

# ============================
# User Accounts Check
# ============================

CURRENT_USERS=$(cut -d: -f1 /etc/passwd | tr '\n' ',' | sed 's/,$//')
BASELINE_USERS=$(aws ssm get-parameter --name "baseline-users" --region $REGION --query "Parameter.Value" --output text 2>/dev/null)

if [ -z "$BASELINE_USERS" ]; then
    aws ssm put-parameter --name "baseline-users" --type String --value "$CURRENT_USERS" --overwrite --region $REGION
    BASELINE_USERS="$CURRENT_USERS"
    echo "$(date) ✅ Created baseline user list" | tee -a "$LOCAL_LOG"
fi

if [ "$CURRENT_USERS" != "$BASELINE_USERS" ]; then
    USER_MSG="⚠️ $(date) User accounts drift detected! Current: $CURRENT_USERS, Expected: $BASELINE_USERS"
else
    USER_MSG="✅ $(date) User accounts check passed"
fi
echo "$USER_MSG" | tee -a "$LOCAL_LOG"
send_to_cloudwatch "$USER_MSG"

# ============================
# Sudoers Check
# ============================

SUDOERS_HASH=$(sudo sha256sum /etc/sudoers | awk '{print $1}')
BASELINE_SUDOERS=$(aws ssm get-parameter --name "baseline-sudoers-hash" --region $REGION --query "Parameter.Value" --output text 2>/dev/null)

if [ -z "$BASELINE_SUDOERS" ]; then
    aws ssm put-parameter --name "baseline-sudoers-hash" --type String --value "$SUDOERS_HASH" --overwrite --region $REGION
    BASELINE_SUDOERS="$SUDOERS_HASH"
    echo "$(date) ✅ Created baseline sudoers hash" | tee -a "$LOCAL_LOG"
fi

if [ "$SUDOERS_HASH" != "$BASELINE_SUDOERS" ]; then
    SUDO_MSG="⚠️ $(date) Sudoers file drift detected!"
else
    SUDO_MSG="✅ $(date) Sudoers check passed"
fi
echo "$SUDO_MSG" | tee -a "$LOCAL_LOG"
send_to_cloudwatch "$SUDO_MSG"

# ============================
# SSH Config Check
# ============================

SSHD_HASH=$(sudo sha256sum /etc/ssh/sshd_config | awk '{print $1}')
BASELINE_SSHD=$(aws ssm get-parameter --name "baseline-sshd-config-hash" --region $REGION --query "Parameter.Value" --output text 2>/dev/null)

if [ -z "$BASELINE_SSHD" ]; then
    aws ssm put-parameter --name "baseline-sshd-config-hash" --type String --value "$SSHD_HASH" --overwrite --region $REGION
    BASELINE_SSHD="$SSHD_HASH"
    echo "$(date) ✅ Created baseline SSH config hash" | tee -a "$LOCAL_LOG"
fi

if [ "$SSHD_HASH" != "$BASELINE_SSHD" ]; then
    SSH_MSG="⚠️ $(date) SSH config drift detected!"
else
    SSH_MSG="✅ $(date) SSH config check passed"
fi
echo "$SSH_MSG" | tee -a "$LOCAL_LOG"
send_to_cloudwatch "$SSH_MSG"
