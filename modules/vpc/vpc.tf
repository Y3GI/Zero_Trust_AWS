# Vpc setup and gateway

resource "aws_vpc" "main"{
    cidr_block = var.vpc_cidr

    enable_dns_support = true
    enable_dns_hostnames = true

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-vpc"
        }
    )
}

resource "aws_internet_gateway" "igw"{
    vpc_id = aws_vpc.main.id

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-igw"
        }
    )
}

# Nat setup and gateway

resource "aws_eip" "nat"{
    domain = "vpc"

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-nat"
        }
    )
}

resource "aws_nat_gateway" "nat_gtw"{
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public[keys(aws_subnet.public)[0]].id

    tags  = merge(
        var.tags,
        {
            Name = "${var.env}-nat-gtw"
        }
    )

    depends_on = [aws_internet_gateway.igw]
}
