# 1. Firewall Rule Group (The Policy Logic)
resource "aws_networkfirewall_rule_group" "allow_web" {
    capacity = 100
    name     = "${var.env}-web-allow-rules"
    type     = "STATEFUL"

    rule_group {
        rules_source {
            stateful_rule {
                action = "PASS"
                header {
                    destination      = "ANY"
                    destination_port = "443" # Allow HTTPS [cite: 172]
                    direction        = "FORWARD"
                    protocol         = "TCP"
                    source           = "ANY"
                    source_port      = "ANY"
                }
                rule_option {
                    keyword = "sid:1"
                }
            }
            # Block HTTP (Example of Zero Trust enforcement)
            stateful_rule {
                action = "DROP"
                header {
                    destination      = "ANY"
                    destination_port = "80"
                    direction        = "FORWARD"
                    protocol         = "TCP"
                    source           = "ANY"
                    source_port      = "ANY"
                }
                rule_option {
                    keyword = "sid:2"
                }
            }
        }
    }
}

# 2. Firewall Policy (Container for Rule Groups)
resource "aws_networkfirewall_firewall_policy" "main" {
    name = "${var.env}-firewall-policy"

    firewall_policy {
        stateless_default_actions          = ["aws:forward_to_sfe"]
        stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    
        stateful_rule_group_reference {
            resource_arn = aws_networkfirewall_rule_group.allow_web.arn
        }
    }
}

# 3. The Firewall Resource (The Appliance)
resource "aws_networkfirewall_firewall" "main" {
    name                = "${var.env}-network-firewall"
    firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
    vpc_id              = var.vpc_id
    
    # Deploy into the PUBLIC subnet so it can filter ingress/egress
    subnet_change_protection = false

    dynamic "subnet_mapping" {
        for_each = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : []
        content {
            subnet_id = subnet_mapping.value
        }
    }

    tags = merge(var.tags, {
        Service = "Firewall"
    })
}