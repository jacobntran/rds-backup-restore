provider "aws" {
  region = "us-west-1"
}

### VARIABLES ###
variable "key_name" {
  description = "SSH key to access your instances"
}

variable "my_ip" {
  description = "Your public ip address"
}

output "bastion_host_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "application_host_private_ip" {
  value = aws_instance.app.private_ip
}

### NETWORKING ###
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/26"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/28"
  availability_zone       = "us-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "compute" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.16/28"
  availability_zone = "us-west-1b"

  tags = {
    Name = "Compute Subnet"
  }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.32/28"
  availability_zone = "us-west-1b"

  tags = {
    Name = "Database Subnet"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "Public Subnet Route Table"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_route_table" "compute" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public.id
  }

  tags = {
    Name = "Private Subnet Route Table"
  }
}

resource "aws_route_table_association" "compute" {
  route_table_id = aws_route_table.compute.id
  subnet_id      = aws_subnet.compute.id
}

### SERVICES ###
resource "aws_instance" "bastion" {
  ami               = "ami-0d53d72369335a9d6"
  availability_zone = "us-west-1b"
  instance_type     = "t2.micro"
  key_name          = var.key_name
  security_groups   = [aws_security_group.bastion.id]
  subnet_id         = aws_subnet.public.id

  tags = {
    Name = "Bastion Host"
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion_host_security_group"
  description = "Allow SSH access to bastion host"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion Host Security Group"
  }
}

resource "aws_instance" "app" {
  ami               = "ami-0d53d72369335a9d6"
  availability_zone = "us-west-1b"
  instance_type     = "t2.micro"
  key_name          = var.key_name
  security_groups   = [aws_security_group.app.id]
  subnet_id         = aws_subnet.compute.id

  tags = {
    Name = "Application Host"
  }
}

resource "aws_security_group" "app" {
  name        = "app_host_security_group"
  description = "Application Host Security Group"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/26"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Application Host Security Group"
  }
}