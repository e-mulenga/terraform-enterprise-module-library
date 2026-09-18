output "role_arn"              { 
    value = aws_iam_role.main.arn 
}

output "role_name"             { 
    value = aws_iam_role.main.name 
}

output "role_id"               { 
    value = aws_iam_role.main.unique_id 
}

output "instance_profile_arn"  { 
    value = try(aws_iam_instance_profile.main[0].arn, null) 
}

output "instance_profile_name" { 
    value = try(aws_iam_instance_profile.main[0].name, null) 
}
