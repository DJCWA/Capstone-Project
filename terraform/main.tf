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

# ---------- Subnets ----------
# Existing public + private
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

# Extra subnets for ALB/RDS (multi-AZ)
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

# ---------- Internet Gateway + Public Route Table ----------
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

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------- NAT Gateway + Private Route Table ----------
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private_rt.id
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
# Frontend SG (used by ALB targets + ALB itself)
resource "aws_security_group" "frontend_sg" {
  name   = "frontend-sg-${random_id.suffix.hex}"
  vpc_id = aws_vpc.main.id

  # HTTP from anywhere (internet to ALB)
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

# Backend SG (backend EC2, also allowed from Bastion on SSH)
resource "aws_security_group" "backend_sg" {
  name   = "backend-sg-${random_id.suffix.hex}"
  vpc_id = aws_vpc.main.id

  # App traffic from frontend
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  # SSH from bastion (added for Bastion/NAT requirement)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Bastion SG (SSH from internet)
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg-${random_id.suffix.hex}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For demo only; lock to your IP in real life
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS SG (DB only reachable from backend)
resource "aws_security_group" "db_sg" {
  name   = "db-sg-${random_id.suffix.hex}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- EC2 Instances (original) ----------
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

# ---------- Bastion Host (in public subnet) ----------
resource "aws_instance" "bastion" {
  ami                         = "ami-09e7fb5d565f22127"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "bastion-ec2-${random_id.suffix.hex}"
  }
}

# ---------- RDS (MySQL) ----------
resource "aws_db_subnet_group" "db_subnets" {
  name       = "group6-db-subnet-group-${random_id.suffix.hex}"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private2.id]
}

resource "aws_db_instance" "app_db" {
  identifier             = "group6-app-db-${random_id.suffix.hex}"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "group6db"
  username               = "dbuser"
  password               = "Group6StrongPwd123!" # demo only; use secrets in real life
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
}

# ---------- Application Load Balancer (ALB) ----------
resource "aws_lb" "frontend_alb" {
  name               = "group6-alb-${random_id.suffix.hex}"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.frontend_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public2.id]
}

resource "aws_lb_target_group" "frontend_tg" {
  name     = "group6-frontend-tg-${random_id.suffix.hex}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# Attach the standalone frontend instance to the ALB as a target
resource "aws_lb_target_group_attachment" "frontend_instance_attachment" {
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend.id
  port             = 80
}

# ---------- Launch Template + Auto Scaling Group (ASG) ----------
resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "group6-frontend-lt-"
  image_id      = "ami-09e7fb5d565f22127"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = filebase64("userdata-frontend.sh")

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "frontend-asg-ec2"
    }
  }
}

resource "aws_autoscaling_group" "frontend_asg" {
  name                      = "group6-frontend-asg-${random_id.suffix.hex}"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.private.id, aws_subnet.private2.id]
  health_check_type         = "EC2"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.frontend_tg.arn]

  tag {
    key                 = "Name"
    value               = "frontend-asg-ec2"
    propagate_at_launch = true
  }
}

# ---------- Useful Outputs ----------
output "alb_dns_name" {
  value = aws_lb.frontend_alb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.app_db.endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.dr_bucket.bucket
}
