resource "aws_budgets_budget" "monthly"{
    name = "${var.env}-Monthly-Budget"
    budget_type = "COST"
    limit_amount = var.limit_amount
    limit_unit = "EUR"
    time_unit = "MONTHLY"
    time_period_start = "2024-01-01_00:00"

    notification {
        comparison_operator = "GREATER_THAN"
        threshold = 20
        threshold_type = "PERCENTAGE"
        notification_type = "ACTUAL"
        subscriber_email_addresses = [var.email]
    }

    notification {
        comparison_operator = "GREATER_THAN"
        threshold = 50
        threshold_type = "PERCENTAGE"
        notification_type = "ACTUAL"
        subscriber_email_addresses = [var.email]
    }

    notification {
        comparison_operator = "GREATER_THAN"
        threshold = 80
        threshold_type = "PERCENTAGE"
        notification_type = "ACTUAL"
        subscriber_email_addresses = [var.email]
    }

    notification {
        comparison_operator = "GREATER_THAN"
        threshold = 100
        threshold_type = "PERCENTAGE"
        notification_type = "ACTUAL"
        subscriber_email_addresses = [var.email]
    }

    tags = var.tags
}