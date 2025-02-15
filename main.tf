resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_subnet" "public" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private" {
  cidr_block              = "10.0.2.0/24"
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "Private-subnet"
  }
}

resource "aws_internet_gateway" "igw_vpc" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "igw-vpc"
  }
}

# 4. Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_vpc.id
}

resource "aws_security_group" "sg_ssh1" {
  name   = "sg_ssh1"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_ssh" {
  name   = "sg_ssh"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app" {
  name               = "load-balancer"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.sg_ssh.id, aws_security_group.sg_ssh1.id]
  subnets            = [aws_subnet.public.id, aws_subnet.private.id]
  tags = {
    Name = "terraform-alb"
  }
  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "lb_target" {
  name     = "lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "forward_action" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target.arn
  }
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.lb_target.arn
  target_id        = aws_instance.jenkins_slave.id
  port             = 80
}



resource "aws_launch_template" "jenkins_slave" {
  name          = "jenkins_slave"
  image_id      = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  max_size             = 3
  min_size             = 1
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.public.id]
  health_check_type    = "EC2"
  tag {
    key                 = "Name"
    value               = "jenkins_slave"
    propagate_at_launch = true
  }
  launch_template {
    id      = aws_launch_template.jenkins_slave.id
  }
}

# EC2 Instance Creation
resource "aws_instance" "jenkins_master" {
  ami           = "ami-04b4f1a9cf54c11d0" # Replace with your desired AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "jenkins_master"
    Role = "master"
  }
}

resource "aws_instance" "jenkins_slave" {
  ami           = "ami-04b4f1a9cf54c11d0" # Replace with your desired AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "jenkins_slave"
    Role = "slave"
  }
}

output "jenkins_master_public_ip" {
  value = aws_instance.jenkins_master.public_ip
}

output "jenkins_slave_public_ip" {
  value = [aws_instance.jenkins_slave.public_ip]
}