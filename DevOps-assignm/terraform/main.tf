data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "quickstart-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "quickstart-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "quickstart-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "quickstart-private-subnet"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "quickstart-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "quickstart-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "api" {
  name        = "quickstart-api-sg"
  description = "Allow public HTTP and SSH to the API gateway"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "API HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.owner_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quickstart-api-sg"
  }
}

resource "aws_security_group" "workers" {
  name        = "quickstart-workers-sg"
  description = "Allow RPC traffic from the API gateway only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Worker RPC from API"
    from_port       = 5000
    to_port         = 5001
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  ingress {
    description = "SSH from operator to private workers"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.owner_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quickstart-workers-sg"
  }
}

resource "aws_key_pair" "deploy_key" {
  key_name   = "quickstart-deploy-key"
  public_key = file(var.public_key_path)
}

resource "aws_instance" "api" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.api.id]
  key_name                    = aws_key_pair.deploy_key.key_name
  user_data                   = templatefile("${path.module}/templates/api_user_data.sh.tpl", {
    worker_a_ip = aws_instance.worker_a.private_ip
  })

  tags = {
    Name = "quickstart-api"
  }
}

resource "aws_instance" "worker_a" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.workers.id]
  key_name                    = aws_key_pair.deploy_key.key_name
  user_data                   = templatefile("${path.module}/templates/worker_a_user_data.sh.tpl", {
    worker_b_ip = aws_instance.worker_b.private_ip
  })

  tags = {
    Name = "quickstart-worker-a"
  }
}

resource "aws_instance" "worker_b" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.workers.id]
  key_name                    = aws_key_pair.deploy_key.key_name
  user_data                   = templatefile("${path.module}/templates/worker_b_user_data.sh.tpl", {})

  tags = {
    Name = "quickstart-worker-b"
  }
}
