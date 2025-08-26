# Golden AMI Drift Detection

This project automates **Golden Amazon Machine Image (AMI) drift detection** using AWS Systems Manager (SSM), EC2, and IAM.
It was designed for portfolio demonstration and interview discussions.

## Project Overview
- Launch EC2 instance from a Golden AMI.
- Attach IAM Role with SSM and CloudWatch permissions.
- Install and configure drift detection script on the instance.
- Use CloudWatch Logs to monitor drift events.
- Example includes detecting creation of an unauthorized user.

## Architecture
1. **Golden AMI**: Pre-approved secure baseline AMI.
2. **IAM Role & Policies**: Provides required permissions for EC2 to communicate with AWS SSM & CloudWatch.
3. **Drift Detection Script**: Compares the live instance state to the AMI baseline and reports differences.
4. **CloudWatch Logs**: Stores drift detection logs for review.

## How to Run
1. Launch EC2 from Golden AMI.
2. Attach IAM role with SSM and CloudWatch access.
3. Upload `drift_check.sh` to `/usr/local/bin/`.
4. Make it executable: `chmod +x /usr/local/bin/drift_check.sh`.
5. Set up a cron job to run every 5 minutes:  
   ```bash
   */5 * * * * /bin/bash /usr/local/bin/drift_check.sh
   ```
6. Check CloudWatch Logs for drift alerts.

## Example Drift Test
1. SSH into the instance.
2. Create a fake user:  
   ```bash
   sudo useradd hacker_user
   ```
3. Wait for the cron job to run.
4. Check CloudWatch logs — drift will be detected.

## Skills Demonstrated
- AWS EC2 & AMI management
- IAM role and policy creation
- Shell scripting for automation
- AWS CloudWatch Logs
- Security compliance monitoring

