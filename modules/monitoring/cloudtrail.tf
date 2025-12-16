resource "aws_cloudwatch_log_group" "cloudtrail_events" {
    name = "/aws/cloudtrail/${var.env}"
    retention_in_days = 90
    tags = var.tags
}

resource "aws_cloudtrail" "main"{
    name = "${var.env}-audit-trail"
    s3_bucket_name = var.cloudtrail_bucket_name
    include_global_service_events = true
    is_multi_region_trail = true
    enable_log_file_validation = true

    cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_events.arn}:*"
    cloud_watch_logs_role_arn = var.cloudtrail_role_arn
}