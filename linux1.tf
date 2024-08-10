# Created with Operator Lab
# The terraform file that creates a generic Linux OS 
variable "instance_type_linux1" {
  description = "The AWS instance type to use for servers."
  #default     = "t2.micro"
  default     = "t3a.medium"
}

variable "root_block_device_size_linux1" {
  description = "The volume size of the root block device."
  default     =  60 
}

data "aws_ami" "linux1" {
  most_recent      = true
  owners           = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "linux1" {
  ami                    = data.aws_ami.linux1.id
  instance_type          = var.instance_type_linux1
  subnet_id              = aws_subnet.user_subnet.id
  key_name               = module.key_pair.key_pair_name 
  vpc_security_group_ids = [aws_security_group.linux_ingress.id, aws_security_group.linux_ssh_ingress.id, aws_security_group.linux_allow_all_internal.id]

  # Set the static private IP address
  private_ip = cidrhost(var.user_subnet_prefix, 10)

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_ip
  }

  tags = {
    "Name" = "linux1"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size_linux1
    delete_on_termination = "true"
  }

  user_data = data.template_file.linux1.rendered 

}

data "template_file" "linux1" {
  template = file("${path.module}/files/linux/ubuntu1.sh.tpl")

  vars = {
    s3_bucket         = aws_s3_bucket.staging.id
    region            = var.region
    linux_os          = "ubuntu"
    ansible_linux_zip = var.ansible_linux_zip_filename
    domain            = var.default_domain
    lin1_ip           = cidrhost(var.user_subnet_prefix, 10) 
    lin2_ip           = cidrhost(var.user_subnet_prefix, 11) 
    win1_ip           = aws_instance.win1.private_ip
    win2_ip           = aws_instance.win2.private_ip
  }
}

resource "local_file" "linux1" {
  # For inspecting the rendered bash script as it is loaded onto linux system 
  content = data.template_file.linux1.rendered
  filename = "${path.module}/output/linux/ubuntu-linux1.sh"
}

output "details_linux1" {
  value = <<CONFIGURATION
----------------
linux1
----------------
OS:          ubuntu
Public IP:   ${aws_instance.linux1.public_ip} 
Private IP:  ${aws_instance.linux1.private_ip} 
EC2 Inst ID: ${aws_instance.linux1.id}

SSH to linux1
---------------
ssh -i ssh_key.pem ubuntu@${aws_instance.linux1.public_ip}  

CONFIGURATION
}
