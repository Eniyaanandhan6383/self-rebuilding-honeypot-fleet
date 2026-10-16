#!/usr/bin/env bash
# Launches the test image as a one-off task in the SAME subnet + security group as the honeypots.
# Usage: ./run_test.sh <cluster> <task-def-for-test-image> <subnet-id> <security-group-id>
set -e
CLUSTER=$1
TASKDEF=$2
SUBNET=$3
SG=$4

TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER" \
  --launch-type FARGATE \
  --task-definition "$TASKDEF" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET],securityGroups=[$SG],assignPublicIp=DISABLED}" \
  --query 'tasks[0].taskArn' --output text)

aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$TASK_ARN"

EXIT_CODE=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[0].exitCode' --output text)

if [ "$EXIT_CODE" = "0" ]; then
  echo "PASS: honeypot network is isolated"
  exit 0
fi
echo "FAIL: isolation test exit code $EXIT_CODE"
exit 1
