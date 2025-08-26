#!/bin/bash

# Drift Detection Script
# Compares running instance configuration against a Golden AMI baseline.

LOG_GROUP="GoldenAMIDriftLogs"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
DATE=$(date)

# Baseline: For example, no unauthorized users
UNAUTHORIZED_USERS=$(grep -E -v '^(root|ec2-user|ssm-user):' /etc/passwd | cut -d: -f1)

if [ ! -z "$UNAUTHORIZED_USERS" ]; then
    MESSAGE="[$DATE] Drift detected on $INSTANCE_ID: Unauthorized users found: $UNAUTHORIZED_USERS"
    echo "$MESSAGE"
    aws logs create-log-group --log-group-name $LOG_GROUP --region us-east-1 2>/dev/null
    aws logs create-log-stream --log-group-name $LOG_GROUP --log-stream-name $INSTANCE_ID --region us-east-1 2>/dev/null
    aws logs put-log-events         --log-group-name $LOG_GROUP         --log-stream-name $INSTANCE_ID         --log-events timestamp=$(date +%s%3N),message="$MESSAGE"         --region us-east-1
else
    echo "[$DATE] No drift detected on $INSTANCE_ID"
fi
