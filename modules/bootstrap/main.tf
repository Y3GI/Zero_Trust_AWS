terraform{
    backend "s3"{
        bucket = "terraform-state"
        key = "terraform.tfstate"
        region = var.region
        dynamodb_table = "terraform-state"

        tags = merge(
            var.tags,
            {
                Name = "${var.env}-s3"
            }
        )
    }
}