output "hub_id"           { 
    value = aws_securityhub_account.main.id 
}

output "alerts_topic_arn" { 
    value = aws_sns_topic.alerts.arn 
}
