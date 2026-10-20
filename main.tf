# --- 1. VPC & NETWORKING ---

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "assignment-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "assignment-igw" }
}

# Public Subnet (Web Server)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "assignment-public-subnet" }
}

# Private Subnet (Database Server)
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
  tags       = { Name = "assignment-private-subnet" }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway (placed in public subnet to allow private instances internet outbound access)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags          = { Name = "assignment-nat-gw" }
}

# --- 2. ROUTE TABLES ---

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "assignment-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "assignment-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# --- 3. SECURITY GROUPS ---

# Web Server Security Group (Public)
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow SSH from specific IP and HTTP from anywhere"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "web-server-sg" }
}

# Database Server Security Group (Private)
resource "aws_security_group" "db_sg" {
  name        = "db-server-sg"
  description = "Allow database traffic and SSH exclusively from web server"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description     = "Allow SSH from Web Server"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description     = "Allow Database traffic (e.g., MongoDB/MySQL) from Web Server"
    from_port       = 27017 # Change to 3306 for MySQL, 5432 for PostgreSQL, etc.
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "db-server-sg" }
}

# --- 4. IAM ROLES FOR EC2 ---

resource "aws_iam_role" "ec2_ssm_role" {
  name = "assignment-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach standard AWS managed policy for Systems Manager / CloudWatch logging capability
resource "aws_iam_role_policy_attachment" "ssm_server_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "assignment-ec2-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# --- 5. EC2 INSTANCE PROVISIONING ---

# Web Server (Public Subnet)
resource "aws_instance" "web_server" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = { Name = "assignment-web-server" }
}

# Database Server (Private Subnet)
resource "aws_instance" "db_server" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = { Name = "assignment-db-server" }
}