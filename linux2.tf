# Created with Operator Lab
# Ubuntu Linux - linux2 - the CM client system

variable "ansible_linux_user" {
  default = "ansible"
}

variable "ansible_linux_pass" {
  default = "Brave-monkey-2024!"
} 

variable "instance_type_linux2" {
  description = "The AWS instance type to use for servers."
  #default     = "t2.micro"
  default     = "t3a.medium"
}

variable "root_block_device_size_linux2" {
  description = "The volume size of the root block device."
  default     =  60 
}

data "aws_ami" "linux2" {
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

resource "aws_instance" "linux2" {
  ami                    = data.aws_ami.linux2.id
  instance_type          = var.instance_type_linux2
  subnet_id              = aws_subnet.user_subnet.id
  key_name               = module.key_pair.key_pair_name 
  vpc_security_group_ids = [aws_security_group.linux_ingress.id, aws_security_group.linux_ssh_ingress.id, aws_security_group.linux_allow_all_internal.id]

  # Set the static private IP address
  private_ip = cidrhost(var.user_subnet_prefix, 11)

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_ip
  }

  tags = {
    "Name" = "linux2"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size_linux2
    delete_on_termination = "true"
  }

  user_data = data.template_file.linux2.rendered 

}

data "template_file" "linux2" {
  template = file("${path.module}/files/linux/ubuntu2.sh.tpl")

  vars = {
    s3_bucket = aws_s3_bucket.staging.id
    region             = var.region
    linux_os           = "ubuntu"
    ansible_linux_user = var.ansible_linux_user
    ansible_linux_pass = var.ansible_linux_pass 
    domain            = var.default_domain
    #lin1_ip           = aws_instance.linux1.private_ip 
    #lin2_ip           = aws_instance.linux1.private_ip 
    lin1_ip           = cidrhost(var.user_subnet_prefix, 10)
    lin2_ip           = cidrhost(var.user_subnet_prefix, 11)
    win1_ip           = aws_instance.win1.private_ip
    win2_ip           = aws_instance.win2.private_ip
  }
}

resource "local_file" "linux2" {
  # For inspecting the rendered bash script as it is loaded onto linux system 
  content = data.template_file.linux2.rendered
  filename = "${path.module}/output/linux/ubuntu-linux2.sh"
}

output "details_linux2" {
  value = <<CONFIGURATION
----------------
linux2
----------------
OS:          ubuntu
Public IP:   ${aws_instance.linux2.public_ip} 
Private IP:  ${aws_instance.linux2.private_ip} 
EC2 Inst ID: ${aws_instance.linux2.id}

SSH to linux2
---------------
ssh -i ssh_key.pem ubuntu@${aws_instance.linux2.public_ip}  

CONFIGURATION
}
