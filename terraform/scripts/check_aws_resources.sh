#!/bin/bash

# Function to check for existing resources, filtering out AWS default resources
check_resources() {
    local service_name=$1
    local command=$2
    local query=$3
    local filter_default=$4  # Set to "true" to filter default AWS resources

    result=$(eval "$command --query \"$query\" --output text" 2>/dev/null | grep -v 'None' | grep -v '^$')

    if [[ "$filter_default" == "true" ]]; then
        result=$(echo "$result" | grep -v -i 'default' | grep -v -i 'aws-service')
    fi

    if [[ -n "$result" ]]; then
        echo "🔴 Resources remain in $service_name:"
        echo "$result"
    else
        echo "✅ No resources in $service_name."
    fi
}

echo "=== Checking remaining AWS resources ==="

### === NETWORK RESOURCES === ###
check_resources "VPC" "aws ec2 describe-vpcs" "Vpcs[*].[VpcId,IsDefault]" true
check_resources "Subnets" "aws ec2 describe-subnets" "Subnets[*].[SubnetId,CidrBlock]"
check_resources "Route Tables" "aws ec2 describe-route-tables" "RouteTables[*].[RouteTableId,Associations[*].Main]" true
check_resources "Security Groups" "aws ec2 describe-security-groups" "SecurityGroups[*].[GroupId,GroupName]" true
check_resources "Network ACLs" "aws ec2 describe-network-acls" "NetworkAcls[*].[NetworkAclId,IsDefault]" true
check_resources "VPC Endpoints" "aws ec2 describe-vpc-endpoints" "VpcEndpoints[*].VpcEndpointId"
check_resources "VPC Flow Logs" "aws ec2 describe-flow-logs" "FlowLogs[*].[FlowLogId,LogGroupName]"

### === EC2 INSTANCES === ###
check_resources "EC2 Instances" "aws ec2 describe-instances" "Reservations[*].Instances[*].[InstanceId,State.Name]"
check_resources "EBS Volumes" "aws ec2 describe-volumes" "Volumes[*].[VolumeId,State]"
check_resources "Elastic IPs" "aws ec2 describe-addresses" "Addresses[*].PublicIp"
check_resources "EC2 Launch Templates" "aws ec2 describe-launch-templates" "LaunchTemplates[*].LaunchTemplateId"
check_resources "Auto Scaling Groups" "aws autoscaling describe-auto-scaling-groups" "AutoScalingGroups[*].AutoScalingGroupName"

### === LOAD BALANCING === ###
check_resources "ALB (Load Balancers)" "aws elbv2 describe-load-balancers" "LoadBalancers[*].[LoadBalancerName,DNSName]"
check_resources "ALB Target Groups" "aws elbv2 describe-target-groups" "TargetGroups[*].TargetGroupName"
check_resources "ALB Listeners" "aws elbv2 describe-listeners --load-balancer-arn \$(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text)" "Listeners[*].ListenerArn"

### === DATABASES === ###
check_resources "RDS Instances" "aws rds describe-db-instances" "DBInstances[*].DBInstanceIdentifier"
check_resources "ElastiCache Clusters" "aws elasticache describe-cache-clusters" "CacheClusters[*].CacheClusterId"
check_resources "DynamoDB Tables" "aws dynamodb list-tables" "TableNames"
check_resources "DynamoDB Streams" "aws dynamodb list-streams" "Streams[*].StreamArn"

### === STORAGE SERVICES === ###
check_resources "S3 Buckets" "aws s3 ls" ""
check_resources "Kinesis Firehose Streams" "aws firehose list-delivery-streams" "DeliveryStreamNames"

### === SECURITY SERVICES === ###
check_resources "AWS WAF Web ACLs" "aws wafv2 list-web-acls --scope REGIONAL" "WebACLs[*].Name"

### === ACCESS MANAGEMENT === ###
check_resources "IAM Roles" "aws iam list-roles" "Roles[*].[RoleName,Path]" true
check_resources "IAM Policies" "aws iam list-policies" "Policies[*].[PolicyName,IsAttachable]" true
check_resources "IAM Role Policies" "aws iam list-attached-role-policies --role-name \$(aws iam list-roles --query 'Roles[*].RoleName' --output text)" "AttachedPolicies[*].PolicyName"

### === LOGGING SERVICES === ###
check_resources "CloudWatch Log Groups" "aws logs describe-log-groups" "logGroups[*].logGroupName"

### === ENCRYPTION SERVICES === ###
check_resources "KMS Keys" "aws kms list-keys" "Keys[*].KeyId"

### === NOTIFICATION SERVICES === ###
check_resources "SNS Topics" "aws sns list-topics" "Topics[*].TopicArn"
check_resources "SNS Subscriptions" "aws sns list-subscriptions" "Subscriptions[*].SubscriptionArn"

### === MONITORING SERVICES === ###
check_resources "CloudWatch Alarms" "aws cloudwatch describe-alarms" "MetricAlarms[*].AlarmName"
check_resources "CloudWatch Metrics" "aws cloudwatch list-metrics" "Metrics[*].MetricName"

### === AUDIT SERVICES === ###
check_resources "CloudTrail Trails" "aws cloudtrail describe-trails" "trailList[*].Name"

### === SERVERLESS SERVICES === ###
check_resources "Lambda Functions" "aws lambda list-functions" "Functions[*].FunctionName"
check_resources "Lambda Permissions" "aws lambda get-policy --function-name \$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)" "Policy"
check_resources "Lambda Event Source Mappings" "aws lambda list-event-source-mappings" "EventSourceMappings[*].UUID"

echo "=== AWS resource check completed. ==="