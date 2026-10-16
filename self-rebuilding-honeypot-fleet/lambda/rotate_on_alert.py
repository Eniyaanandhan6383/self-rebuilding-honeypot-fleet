# Triggered by a CloudWatch alarm (via SNS). Forces ECS to replace all honeypot tasks.
# Lambda requires a handler function, so this file is the one exception to the no-function style.
import os
import boto3

ecs = boto3.client("ecs")


def lambda_handler(event, context):
    ecs.update_service(
        cluster=os.environ["CLUSTER"],
        service=os.environ["SERVICE"],
        forceNewDeployment=True,
    )
    print("rotation triggered")
    return {"status": "rotation triggered"}
