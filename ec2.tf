# Fetching the latest Ubuntu AMI Version
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Ubuntu Official ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Creating the security group
# Only specifies the VPC ID
# Separates inbound and outbound rule to avoid errors
resource "aws_security_group" "ec3_sg" {
  name        = "project-ec2-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.vpc1.id

  tags = {
    Name = "ec2-security-group"
  }
}

# Defining Ingress rule to allow HTTP traffic from port 80
# Referencing the load balancer security group to only allow HTTP from ALB
resource "aws_vpc_security_group_ingress_rule" "ec2_inbound_HTTP" {
  security_group_id            = aws_security_group.ec3_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# Defining Egress rule to allow responding to requests from the internet via protocol "-1"
resource "aws_vpc_security_group_egress_rule" "ec2_outbound" {
  security_group_id = aws_security_group.ec3_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Creating a launch template
resource "aws_launch_template" "ec_templates" {
  name_prefix            = "portfolio-app"
  instance_type          = "t3.micro"
  image_id               = data.aws_ami.ubuntu.id
  vpc_security_group_ids = [aws_security_group.ec3_sg.id]
  user_data = base64encode(<<-EOF
              #!/bin/bash
              set -e

              # Update & install package
              apt-get update -y
              apt-get install -y python3-pip python3-venv nginx

              # Siapkan folder honeypot
              mkdir -p /var/www/honeypot
              cd /var/www/honeypot

              # Setup Python Virtual Environment
              python3 -m venv venv
              /var/www/honeypot/venv/bin/pip install --upgrade pip
              /var/www/honeypot/venv/bin/pip install flask gunicorn

              # Tulis kode aplikasi web Honeypot
              cat <<'APP' > /var/www/honeypot/app.py
              from flask import Flask, request, jsonify
              import logging
              from datetime import datetime

              app = Flask(__name__)

              logging.basicConfig(
                  filename='/var/log/honeypot.log',
                  level=logging.INFO,
                  format='%(asctime)s [%(levelname)s] %(message)s'
              )

              @app.route('/', defaults={'path': ''}, methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
              @app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
              def catch_all(path):
                  forwarded_for = request.headers.get('X-Forwarded-For')
                  client_ip = forwarded_for.split(',')[0].strip() if forwarded_for else request.remote_addr
                  
                  user_agent = request.headers.get('User-Agent', 'Unknown')
                  http_method = request.method
                  query_params = request.query_string.decode('utf-8')
                  payload = request.get_data(as_text=True)

                  log_entry = f"IP: {client_ip} | METHOD: {http_method} | PATH: /{path} | QUERY: {query_params} | PAYLOAD: {payload} | AGENT: {user_agent}"
                  logging.info(log_entry)

                  return jsonify({
                      "status": "success",
                      "server": "Apache/2.4.52 (Ubuntu)",
                      "message": "Resource accessed successfully",
                      "authenticated": False
                  }), 200

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=5000)
              APP

              # Setup systemd service agar jalan 24/7 di background
              cat <<'SERVICE' > /etc/systemd/system/honeypot.service
              [Unit]
              Description=Flask Web Honeypot Service
              After=network.target

              [Service]
              User=root
              WorkingDirectory=/var/www/honeypot
              ExecStart=/var/www/honeypot/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 app:app
              Restart=always

              [Install]
              WantedBy=multi-user.target
              SERVICE

              # Setup Nginx Reverse Proxy (Port 80 -> Port 5000)
              cat <<'NGINX' > /etc/nginx/sites-available/default
              server {
                  listen 80 default_server;
                  server_name _;

                  location / {
                      proxy_pass http://127.0.0.1:5000;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                  }
              }
              NGINX

              # Jalankan service
              systemctl daemon-reload
              systemctl enable --now honeypot
              systemctl restart nginx
              systemctl enable nginx
              EOF
  )
}

# Creating an autoscaling group for EC2 instances
resource "aws_autoscaling_group" "name" {
  max_size         = 3
  min_size         = 1
  desired_capacity = 2
  # Uses * to iterate through all public subnets
  vpc_zone_identifier = aws_subnet.subnets_public[*].id
  launch_template {
    id      = aws_launch_template.ec_templates.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.alb-tg.arn]
}