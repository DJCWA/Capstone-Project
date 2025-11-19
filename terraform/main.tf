provider "aws" {
  region = "ca-central-1"
}

# ---------- Availability Zones ----------
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------- Random ID (avoid name conflicts) ----------
resource "random_id" "suffix" {
  byte_length = 4
}

# ---------- VPC ----------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------- S3 Bucket (random name) ----------
resource "aws_s3_bucket" "dr_bucket" {
  bucket = "group6-dr-demo-bucket-${random_id.suffix.hex}"
}

# ---------- IAM Role (random name) ----------
resource "aws_iam_role" "ec2_role" {
  name = "group6-ec2-role-${random_id.suffix.hex}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Allow EC2 full S3 access (demo purpose)
resource "aws_iam_role_policy" "ec2_s3_policy" {
  role = aws_iam_role.ec2_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "group6-ec2-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

# ---------- Security Groups ----------
resource "aws_security_group" "frontend_sg" {
  name   = "frontend-sg-${random_id.suffix.hex}"
  vpc_id = aws_vpc.main.id

  ingress {
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
}

resource "aws_security_group" "backend_sg" {
  name   = "backend-sg-${random_id.suffix.hex}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- EC2 Instances ----------
resource "aws_instance" "frontend" {
  ami                    = "ami-09e7fb5d565f22127"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = file("userdata-frontend.sh")

  tags = {
    Name = "frontend-ec2-${random_id.suffix.hex}"
  }
}

resource "aws_instance" "backend" {
  ami                    = "ami-09e7fb5d565f22127"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = file("userdata-backend.sh")

  tags = {
    Name = "backend-ec2-${random_id.suffix.hex}"
  }
}
