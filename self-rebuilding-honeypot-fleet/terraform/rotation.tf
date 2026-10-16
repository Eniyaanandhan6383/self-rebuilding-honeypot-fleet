# TODO (later): event-based rotation
# 1. aws_cloudwatch_log_metric_filter on eventid = "cowrie.session.file_download"
# 2. aws_cloudwatch_metric_alarm on that metric
# 3. aws_lambda_function using ../lambda/rotate_on_alert.py
#    with env vars CLUSTER and SERVICE, and IAM permission ecs:UpdateService
# 4. Alarm action -> SNS topic -> Lambda
