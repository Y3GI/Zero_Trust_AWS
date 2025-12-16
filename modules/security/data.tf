# Get current AWS account ID and region
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# IAM Role Trust Policy: Allows the EC2 Service to assume this role.
data "aws_iam_policy_document" "ec2_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}
