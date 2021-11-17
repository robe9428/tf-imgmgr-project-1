data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.bucket
    key    = "env:/common/vpc.tfstate"
    region = var.region
  }
}

resource "aws_security_group" "lb_sg" {
     name        = "lb_sg"
     description = "Allow http from internet"
     vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

    ingress {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  resource "aws_iam_role" "role" {
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${terraform.workspace}-ec2Profile"
  role = aws_iam_role.role.id
}

resource "aws_security_group" "imgmgr_server" {
    name        = "imgmgr_server-sg"
    description = "Allow HTTP and SSH traffic"
    vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

    ingress {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      security_groups = [aws_security_group.lb_sg.id]
    }

    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_s3_bucket" "imgmgr-bucket" {
  bucket_prefix = "imgmgr-bucket-tf3-"
  acl    = "private"

  versioning {
     enabled = false
  }
  tags = {
    Name = "imgmgr-bucket-tf3"
  }
}

resource "aws_elb" "imgmgr-elb" {
  name               = "imgmgr-terraform-elb"
  internal           = false
  cross_zone_load_balancing = true
  subnets            = ["subnet-04d95d0aafacbd4ec", "subnet-02a31115597bd10fa"]
  security_groups    = [aws_security_group.lb_sg.id]

  listener {
     instance_port     = 80
     instance_protocol = "http"
     lb_port           = 80
     lb_protocol       = "http"
   }

     health_check {
     healthy_threshold   = 2
     unhealthy_threshold = 2
     timeout             = 5
     target              = "HTTP:80/"
     interval            = 10
   }
 }

 resource "aws_launch_template" "imgmgr_template" {
   name_prefix   = "imgmgr_template"
   image_id      = "ami-02f5781cba46a5e8a"
   instance_type = "t2.micro"
   vpc_security_group_ids = ["${aws_security_group.imgmgr_server.id}"]
   user_data = base64encode(templatefile("${path.module}/install.sh", {S3Bucket = aws_s3_bucket.imgmgr-bucket.id }))
   iam_instance_profile {
     name = aws_iam_instance_profile.ec2_profile.id
   }
 }

 resource "aws_autoscaling_group" "imgmgr_scaling" {
   name                = "${terraform.workspace}-imgmgr-asg"
   desired_capacity    = 2
   max_size            = 2
   min_size            = 1
   health_check_type   = "EC2"
   force_delete        = true
   load_balancers      = [aws_elb.imgmgr-elb.id]
   vpc_zone_identifier = ["subnet-066b2847bb53ca658", "subnet-0135d39fa2a9b9113"]
   health_check_grace_period = 300
   launch_template {
       id      = aws_launch_template.imgmgr_template.id
       version = "$Latest"
   }
 }

 resource "aws_autoscaling_policy" "web_policy_up" {
   name = "web_policy_up"
   scaling_adjustment = 1
   adjustment_type = "ChangeInCapacity"
   cooldown = 300
   autoscaling_group_name = aws_autoscaling_group.imgmgr_scaling.name
   }

 resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
   alarm_name = "web_cpu_alarm_up"
   comparison_operator = "GreaterThanOrEqualToThreshold"
   evaluation_periods = "2"
   metric_name = "CPUUtilization"
   namespace = "AWS/EC2"
   period = "120"
   statistic = "Average"
   threshold = "60"

   dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.imgmgr_scaling.name
   }

    alarm_description = "This metric monitor EC2 instance CPU utilization"
    alarm_actions = [ aws_autoscaling_policy.web_policy_up.arn ]
 }

 resource "aws_autoscaling_policy" "web_policy_down" {
   name = "web_policy_down"
   scaling_adjustment = -1
   adjustment_type = "ChangeInCapacity"
   cooldown = 300
   autoscaling_group_name = aws_autoscaling_group.imgmgr_scaling.name
 }

 resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
   alarm_name = "web_cpu_alarm_down"
   comparison_operator = "LessThanOrEqualToThreshold"
   evaluation_periods = "2"
   metric_name = "CPUUtilization"
   namespace = "AWS/EC2"
   period = "120"
   statistic = "Average"
   threshold = "10"

   dimensions = {
     AutoScalingGroupName = aws_autoscaling_group.imgmgr_scaling.name
   }
 }

 resource "aws_iam_role_policy" "imgmgr-s3-tf-policy" {
   name = "imgmgr-s3-tf-policy"
   role = aws_iam_role.role.id
   policy = jsonencode({
     Version = "2012-10-17"
     Statement = [
       {
         Action = [
           "s3:GetObject",
           "s3:PutObject",
           "s3:DeleteObject",
           "s3:ListBucket"
         ],
         Effect   = "Allow"
         Sid      = ""
         Resource = [
            "${aws_s3_bucket.imgmgr-bucket.arn}/*",
            "${aws_s3_bucket.imgmgr-bucket.arn}"
          ]
       },
       {
         Action   = "ec2:DescribeTags"
         Effect   = "Allow"
         Sid      = ""
         Resource = ["*"]
       }
     ]
   })
 }
