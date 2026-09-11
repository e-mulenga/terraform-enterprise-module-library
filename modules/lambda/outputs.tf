output "function_arn"   { value = aws_lambda_function.main.arn }
output "function_name"  { value = aws_lambda_function.main.function_name }
output "invoke_arn"     { value = aws_lambda_function.main.invoke_arn }
output "role_arn"       { value = aws_iam_role.lambda.arn }
output "dlq_arn"        { value = aws_sqs_queue.dlq.arn }
output "security_group_id" { value = try(aws_security_group.lambda[0].id, null) }
