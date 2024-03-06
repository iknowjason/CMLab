variable "ansible_linux_zip_filename" {
  default = "ansible_linux.zip"
}

data "archive_file" "ansible_linux_zip" {
  type        = "zip"
  source_dir  = "${path.module}/files/linux/ansible"
  output_path = "${path.module}/output/linux/${var.ansible_linux_zip_filename}"

  depends_on = [
    local_file.ansible_linhosts_linux,
    local_file.ansible_winhosts_linux,
    local_file.ansible_winhosts_ssh_linux,
    local_file.playbook_pwsh_ssh
  ]
}

resource "aws_s3_object" "ansible_linux_zip" {
  bucket = aws_s3_bucket.staging.id 
  key    = var.ansible_linux_zip_filename 
  source = data.archive_file.ansible_linux_zip.output_path

  depends_on = [
    local_file.ansible_linhosts_linux,
    local_file.ansible_winhosts_linux,
    local_file.ansible_winhosts_ssh_linux,
    local_file.playbook_pwsh_ssh,
    data.archive_file.ansible_linux_zip
  ]
}

resource "local_file" "ansible_linhosts_linux" {
  content  = data.template_file.ansible_linhosts_linux.rendered
  filename = "${path.module}/files/linux/ansible/linhosts"
}

resource "local_file" "ansible_winhosts_linux" {
  content  = data.template_file.ansible_winhosts_linux.rendered
  filename = "${path.module}/files/linux/ansible/winhosts"
}

resource "local_file" "ansible_winhosts_ssh_linux" {
  content  = data.template_file.ansible_winhosts_ssh_linux.rendered
  filename = "${path.module}/files/linux/ansible/winhosts-ssh"
}

resource "local_file" "playbook_pwsh_ssh" {
  content  = data.template_file.playbook_pwsh_ssh.rendered
  filename = "${path.module}/files/linux/ansible/powershell-ssh.yml"
}

data "template_file" "playbook_pwsh_ssh" {
  template = file("${path.module}/files/linux/templatefiles/powershell-ssh.yml.tpl")

  vars = {
    ansible_user  = var.ansible-username-win1
    ansible_pass  = var.ansible-password-win1
  }
}

data "template_file" "ansible_linhosts_linux" {
  template = file("${path.module}/files/linux/templatefiles/linhosts.tpl")

  vars = {
    lin2_host     = aws_instance.linux2.private_ip
    ansible_user  = var.ansible_linux_user
    ansible_pass  = var.ansible_linux_pass
  }
}

data "template_file" "ansible_winhosts_linux" {
  template = file("${path.module}/files/linux/templatefiles/winhosts.tpl")

  vars = {
    win1_host     = aws_instance.win1.private_ip
    win2_host     = aws_instance.win2.private_ip 
    ansible_user  = var.ansible-username-win1
    ansible_pass  = var.ansible-password-win1
  }
}

data "template_file" "ansible_winhosts_ssh_linux" {
  template = file("${path.module}/files/linux/templatefiles/winhosts-ssh.tpl")

  vars = {
    win1_host     = aws_instance.win1.private_ip
    win2_host     = aws_instance.win2.private_ip
    ansible_user  = var.ansible-username-win1
    ansible_pass  = var.ansible-password-win1
  }
}
