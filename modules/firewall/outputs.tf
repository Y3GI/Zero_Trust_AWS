# Network Firewall Rule Group Outputs
output "firewall_rule_group_id" {
    description = "The ID of the Network Firewall rule group"
    value       = aws_networkfirewall_rule_group.allow_web.id
}

output "firewall_rule_group_arn" {
    description = "The ARN of the Network Firewall rule group"
    value       = aws_networkfirewall_rule_group.allow_web.arn
}

# Network Firewall Policy Outputs
output "firewall_policy_id" {
    description = "The ID of the Network Firewall policy"
    value       = aws_networkfirewall_firewall_policy.main.id
}

output "firewall_policy_arn" {
    description = "The ARN of the Network Firewall policy"
    value       = aws_networkfirewall_firewall_policy.main.arn
}

# Network Firewall Outputs
output "firewall_id" {
    description = "The ID of the Network Firewall"
    value       = aws_networkfirewall_firewall.main.id
}

output "firewall_arn" {
    description = "The ARN of the Network Firewall"
    value       = aws_networkfirewall_firewall.main.arn
}

output "firewall_status" {
    description = "The operational status of the Network Firewall"
    value       = aws_networkfirewall_firewall.main.firewall_status
}
