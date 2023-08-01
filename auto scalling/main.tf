

# Create a VPC
resource "aws_vpc" "vpc_1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terra_vpc"
  }
}

# Create subnets in different availability zones
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1d"
  tags = {
    Name = "public_subnet_2"
  }
}

############IGW###############

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_1.id

  tags = {
    Name = "igw"
  }
}

###############RTW##############

resource "aws_route_table" "rtw" {
  vpc_id = aws_vpc.vpc_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rtw"
  }
}

############ROUTE##############

resource "aws_route" "my_route" {
  route_table_id            = aws_route_table.rtw.id
  destination_cidr_block    = "0.0.0.0/0"  
  gateway_id                = aws_internet_gateway.igw.id  
}

#################SUBNET-ASSOCIATION#################

resource "aws_route_table_association" "association_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.rtw.id
}

resource "aws_route_table_association" "association_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.rtw.id
}



# Create a security group to allow traffic on the load balancer
resource "aws_security_group" "lb_sg" {
  name_prefix = "lb_sg"
  vpc_id      = aws_vpc.vpc_1.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Create an Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
}

# Create an ALB Target Group
resource "aws_lb_target_group" "tg_1" {
  name     = "tg-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_1.id
}

# Create a Launch Configuration for the Auto Scaling Group
resource "aws_launch_configuration" "lanch_conf" {
  name_prefix            = "lanch-conf"
  image_id               = "ami-0d52744d6551d851e"  
  instance_type          = "t2.micro"
  associate_public_ip_address = true
  key_name = "vishnu"
  security_groups        = [aws_security_group.lb_sg.id]

  # Optional: Add user data script if needed
  # user_data = <<EOF
  #   #!/bin/bash
  #   echo "Hello from user data!"
  #   EOF
}

# Create an Auto Scaling Group
resource "aws_autoscaling_group" "auto_group" {
  name                  = "auto-group"
  desired_capacity      = 2
  min_size              = 1
  max_size              = 5
  launch_configuration  = aws_launch_configuration.lanch_conf.name
  vpc_zone_identifier = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  

  tag {
    key                 = "name"
    value               = "vishnu"
    propagate_at_launch = true
  }
}


resource "aws_autoscalingplans_scaling_plan" "example" {
  name = "example-dynamic-cost-optimization"

  application_source {
    tag_filter {
      key    = "application"
      values = ["example"]
    }
  }

  scaling_instruction {
    max_capacity       = 3
    min_capacity       = 0
    resource_id        = format("autoScalingGroup/%s", aws_autoscaling_group.auto_group.name)
    scalable_dimension = "autoscaling:autoScalingGroup:DesiredCapacity"
    service_namespace  = "autoscaling"

    target_tracking_configuration {
      predefined_scaling_metric_specification {
        predefined_scaling_metric_type = "ASGAverageCPUUtilization"
      }

      target_value = 70
    }
  }
}

# Attach the Auto Scaling Group to the Target Group
resource "aws_autoscaling_attachment" "attach_1" {
  autoscaling_group_name = aws_autoscaling_group.auto_group.name
  lb_target_group_arn   = aws_lb_target_group.tg_1.arn
}
