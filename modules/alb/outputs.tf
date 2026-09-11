output "alb_arn"              { value = aws_lb.main.arn }
output "alb_dns_name"         { value = aws_lb.main.dns_name }
output "alb_zone_id"          { value = aws_lb.main.zone_id }
output "target_group_arn"     { value = aws_lb_target_group.main.arn }
output "security_group_id"    { value = aws_security_group.alb.id }
output "waf_acl_arn"          { value = aws_wafv2_web_acl.main.arn }
output "https_listener_arn"   { value = aws_lb_listener.https.arn }
