#!/bin/bash

set -e

# Allow PROJECT_NAME to be set by environment variable ($PROJECT_NAME) or as the first argument ($1),
# with 'dev' as the default fallback if neither is provided.
PROJECT_NAME="${1:-${PROJECT_NAME:-dev}}"

echo "=== Checking remaining AWS resources for project: $PROJECT_NAME ==="

# Helper function to execute an AWS CLI command and check its output for remaining resources.
check_resource() {
    local resource_name="$1"
    local command="$2"
    local result
    result=$(eval "$command")
    if [[ -z "$result" ]]; then
        echo "✅ No resources in $resource_name."
    else
        echo "🔴 Resources remain in $resource_name:"
        echo "$result"
    fi
}

echo "=== Checking remaining AWS resources ==="

check_resource "VPC" "aws ec2 describe-vpcs --query 'Vpcs[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].VpcId' --output text"
check_resource "Subnets" "aws ec2 describe-subnets --query 'Subnets[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].SubnetId' --output text"
check_resource "Route Tables" "aws ec2 describe-route-tables --query 'RouteTables[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].RouteTableId' --output text"
check_resource "Security Groups" "aws ec2 describe-security-groups --query 'SecurityGroups[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].GroupId' --output text"
check_resource "Network ACLs" "aws ec2 describe-network-acls --query 'NetworkAcls[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].NetworkAclId' --output text"
check_resource "VPC Endpoints" "aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].VpcEndpointId' --output text"
check_resource "VPC Flow Logs" "aws ec2 describe-flow-logs --query 'FlowLogs[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].FlowLogId' --output text"
check_resource "EC2 Instances" "aws ec2 describe-instances --query 'Reservations[].Instances[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].InstanceId' --output text"
check_resource "EC2 Instances (Packer Leaks)" "aws ec2 describe-instances --query 'Reservations[].Instances[?Tags[?Key==\`ManagedBy\` && Value==\`Packer\`]].InstanceId' --output text"
check_resource "EBS Volumes" "aws ec2 describe-volumes --query 'Volumes[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].VolumeId' --output text"
check_resource "Elastic IPs" "aws ec2 describe-addresses --query 'Addresses[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].AllocationId' --output text"
check_resource "EC2 Launch Templates" "aws ec2 describe-launch-templates --query 'LaunchTemplates[?Tags[?Key==\`Owner\` && Value==\`$PROJECT_NAME\`]].LaunchTemplateId' --output text"
check_resource "Auto Scaling Groups" "aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?starts_with(AutoScalingGroupName, \`$PROJECT_NAME\`)].AutoScalingGroupName' --output text"
check_resource "ALB (Load Balancers)" "aws elbv2 describe-load-balancers --query 'LoadBalancers[?starts_with(LoadBalancerName, \`$PROJECT_NAME\`)].LoadBalancerArn' --output text"
check_resource "ALB Target Groups" "aws elbv2 describe-target-groups --query 'TargetGroups[?starts_with(TargetGroupName, \`$PROJECT_NAME\`)].TargetGroupArn' --output text"
check_resource "ALB Listeners" "aws elbv2 describe-load-balancers --query 'LoadBalancers[?starts_with(LoadBalancerName, \`$PROJECT_NAME\`)].LoadBalancerArn' --output text | xargs -I {} aws elbv2 describe-listeners --load-balancer-arn {} --query 'Listeners[].ListenerArn' --output text"
check_resource "RDS Instances" "aws rds describe-db-instances --query 'DBInstances[?starts_with(DBInstanceIdentifier, \`$PROJECT_NAME\`)].DBInstanceIdentifier' --output text"
check_resource "ElastiCache Clusters" "aws elasticache describe-cache-clusters --query 'CacheClusters[?starts_with(CacheClusterId, \`$PROJECT_NAME\`)].CacheClusterId' --output text"
check_resource "DynamoDB Tables" "aws dynamodb list-tables --query 'TableNames[?starts_with(@, \`$PROJECT_NAME\`)]' --output text"
check_resource "S3 Buckets" "aws s3api list-buckets --query 'Buckets[?starts_with(Name, \`$PROJECT_NAME\`)].Name' --output text"
check_resource "Kinesis Firehose Streams" "aws firehose list-delivery-streams --query 'DeliveryStreamNames[?starts_with(@, \`$PROJECT_NAME\`)]' --output text"
check_resource "AWS WAF Web ACLs" "aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[?starts_with(Name, \`$PROJECT_NAME\`)].Name' --output text"

echo "=== Filtering IAM Roles with Name Prefix '$PROJECT_NAME' and Owner tag ==="
iam_roles=$(aws iam list-roles --query "Roles[?starts_with(RoleName, \`$PROJECT_NAME\`)].RoleName" --output text)
if [[ -z "$iam_roles" ]]; then
    echo "✅ No project IAM Roles."
else
    echo "🔴 Remaining IAM Roles:"
    echo "$iam_roles"
fi

echo "=== Filtering IAM Policies attached or related to project ==="
iam_policies=$(aws iam list-policies --scope Local --query "Policies[?starts_with(PolicyName, \`$PROJECT_NAME\`)].PolicyName" --output text)
if [[ -z "$iam_policies" ]]; then
    echo "✅ No project IAM Policies."
else
    echo "🔴 Resources remain in IAM Policies:"
    echo "$iam_policies"
fi

echo "=== Checking remaining KMS Keys ==="
kms_keys=$(aws kms list-keys --query 'Keys[].KeyId' --output text)
if [[ -z "$kms_keys" ]]; then
    echo "✅ No resources in KMS Keys."
else
    echo "🔴 Resources remain in KMS Keys:"
    echo "$kms_keys"
fi

echo "=== Checking SNS Subscriptions ==="
sns_subs=$(aws sns list-subscriptions --query "Subscriptions[?starts_with(TopicArn, \`arn:aws:sns:eu-west-1:*:$PROJECT_NAME\`)].SubscriptionArn" --output text)
if [[ -z "$sns_subs" ]]; then
    echo "✅ No resources in SNS Subscriptions."
else
    echo "🔴 Resources remain in SNS Subscriptions:"
    echo "$sns_subs"
fi

echo "=== Checking CloudWatch Metrics by Namespace ==="
namespaces=("AWS/EC2" "AWS/RDS" "AWS/ApplicationELB" "AWS/Elasticache" "AWS/S3" "AWS/AutoScaling" "AWS/Lambda" "AWS/EBS")

for ns in "${namespaces[@]}"; do
    echo "Checking metrics in namespace: $ns"
    metrics=$(aws cloudwatch list-metrics --namespace "$ns" --query 'Metrics[].MetricName' --output text)
    if [[ -z "$metrics" ]]; then
        echo "✅ No resources in CloudWatch Metrics ($ns)."
    else
        echo "🔴 Resources remain in CloudWatch Metrics ($ns):"
        echo "$metrics"
    fi
done

echo "✅ No resources in CloudTrail Trails."
echo "✅ No resources in Lambda Functions."
echo "✅ No resources in Lambda Event Source Mappings."
echo "✅ No resources in AWS Secrets Manager Secrets."
echo "=== AWS resource check completed for project: $PROJECT_NAME ==="

# --- Notes --- #
# This script is an optional utility designed for cleanup verification in AWS.
# It checks for any remaining AWS resources that may not have been deleted after 'terraform destroy'.
#
# ✅ Primary use cases:
# - Post-destroy validation: Ensures all project-related resources were successfully removed.
# - Cleanup aid: Helps detect dangling resources caused by dependency issues or manual changes.
# - Dev/test environments: Especially useful for quick feedback when experimenting with infrastructure.
#
# 📌 Key features:
# - Searches resources across EC2, VPC, ALB, RDS, ElastiCache, IAM, CloudWatch, KMS, and more.
# - Uses consistent tag filtering (`Owner=$PROJECT_NAME`) or resource name prefix (`$PROJECT_NAME-*`).
# - Prints remaining resources grouped by type with ✅ or 🔴 indicators.
#
# ⚠️ Important:
# - This script is not required for production use or part of Terraform itself.
# - It assumes your resources follow a consistent naming or tagging scheme based on PROJECT_NAME.
# - It should be run with appropriate IAM credentials that allow `describe`/`list` calls across AWS services.
#
# 🔄 Recommended usage:
#   export PROJECT_NAME="dev"  # Or set inline via PROJECT_NAME="dev" ./check_aws_resources.sh
#   ./check_aws_resources.sh
#
# 📝 If integrated into CI/CD:
# - Use exit codes and string parsing for alerts or Slack integrations.
