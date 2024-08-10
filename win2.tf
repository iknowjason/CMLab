# CMLab Windows Client - win2

variable "ad_domain_win2" {
  default = "rtc.local"
}

variable "win2_hostname" {
  default = "win2"
}

variable "ansible-username-win2" {
  default = "ansible"
}

variable "ansible-password-win2" {
  default = "Brave-monkey-2024!"
}

variable "admin-username-win2" {
  default = "RTCAdmin"
}

variable "admin-password-win2" {
  default = "Proud-lion-2024!"
}

variable "endpoint_hostname-win2" {
  default = "win2"
}

# AWS AMI for Windows Server
data "aws_ami" "win2" {
  most_recent = true

  filter {
    name   = "name"
    #values = ["Windows_Server-2019-English-Full-Base-*"]
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  owners = ["801119661308"] # Amazon
}

# EC2 Instance
resource "aws_instance" "win2" {
  ami           = data.aws_ami.win2.id
  #instance_type = "t2.micro"
  instance_type = "t3a.medium"
  key_name	= module.key_pair.key_pair_name
  subnet_id     = aws_subnet.user_subnet.id
  associate_public_ip_address = true
  user_data	= data.template_file.ps_template_win2.rendered
  vpc_security_group_ids = [
    aws_security_group.operator_windows.id
  ]

  # Set the static private IP address
  private_ip = cidrhost(var.user_subnet_prefix, 13)

  
  
  root_block_device {
    volume_size           = 30
  }

  tags = {
    "Name" = "win2"
  }
  depends_on = [
    # reserved for later
  ]
}

data "template_file" "ps_template_win2" {
  template = file("${path.module}/files/windows/bootstrap-win2.ps1.tpl")

  vars = {
    hostname                  = var.win2_hostname 
    ad_domain                 = var.ad_domain_win2
    admin_username            = var.admin-username-win2
    admin_password            = var.admin-password-win2
    ansible_username          = var.ansible-username-win2
    ansible_password          = var.ansible-password-win2
    script_files              = join(",", local.script_files_win)
    s3_bucket                 = "${aws_s3_bucket.staging.id}"
    region                    = var.region
    domain            = var.default_domain
    lin1_ip           = cidrhost(var.user_subnet_prefix, 10)
    lin2_ip           = cidrhost(var.user_subnet_prefix, 11)
    win1_ip           = cidrhost(var.user_subnet_prefix, 12)
    win2_ip           = cidrhost(var.user_subnet_prefix, 13)
  }
}

resource "local_file" "debug-bootstrap-script-win2" {
  # For inspecting the rendered powershell script as it is loaded onto endpoint 
  content = data.template_file.ps_template_win2.rendered
  filename = "${path.module}/output/windows/bootstrap-${var.endpoint_hostname-win2}.ps1"
}

output "windows_endpoint_details_win2" {
  value = <<EOS
-------------------------
Virtual Machine ${aws_instance.win2.tags["Name"]}
-------------------------
Instance ID: ${aws_instance.win2.id}
Computer Name:  ${aws_instance.win2.tags["Name"]}
Private IP: ${aws_instance.win2.private_ip}
Public IP:  ${aws_instance.win2.public_ip}
local Admin:  ${var.admin-username-win2}
local password: ${var.admin-password-win2}
Ansible User:  ${var.ansible-username-win2}
Ansible Pass:  ${var.ansible-password-win2}

-------------
SSH to ${aws_instance.win2.tags["Name"]}
-------------
ssh ${var.admin-username-win2}@${aws_instance.win2.public_ip}

EOS
}
