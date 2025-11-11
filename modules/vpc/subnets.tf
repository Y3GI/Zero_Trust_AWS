resource "aws_subnet" "public"{
    for_each = var.public_subnets

    vpc_id = aws_vpc.main.id
    cidr_block = each.value.cidr
    availability_zone = each.value.az
    map_public_ip_on_launch = true

    tags = merge(
    var.tags,
        {
            Name = "${var.env}-public-${each.value.az}"
        }
    )
}

resource "aws_subnet" "private"{
    for_each = var.private_subnets

    vpc_id = aws_vpc.main.id
    cidr_block = each.value.cidr
    availability_zone = each.value.az

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-private-${each.value.az}"
        }
    )
}

resource "aws_subnet" "isolated"{
    count = var.create_isolated_subnet ? 1:0

    vpc_id = aws_vpc.main.id
    cidr_block = cidrsubnet(var.vpc_cidr, 3, 3)
    availability_zone = var.region

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-isolated-${var.azs[count.index]}"
        }
    )
}