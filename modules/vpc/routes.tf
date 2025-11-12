# Route tables

resource "aws_route_table" "public_rt"{
    vpc_id = aws_vpc.main.id

    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = merge (
        var.tags,
        {
            Name = "${var.env}-public-rt"
        }
    )
}

resource "aws_route_table" "private_rt"{
    vpc_id = aws_vpc.main.id

    route{
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gtw.id
    }
    tags = merge(
        var.tags,
        {
            Name = "${var.env}-private-rt"
        }
    )
}

# Routes

resource "aws_route_table_association" "public"{
    for_each = aws_subnet.public
    subnet_id = each.value.id
    route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private"{
    for_each = aws_subnet.private
    subnet_id = each.value.id
    route_table_id = aws_route_table.private_rt.id
}