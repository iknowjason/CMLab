# Configuration Management (CM) Lab

## Overview

Configuration Management (CM) Lab is a terraform template creating a small enterprise Security lab to practice automation for security tooling.  It automatically builds the following resources hosted in AWS:

* Two Ubuntu Linux 22.04 Servers
* Two Windows Server 2022
* CM tools automatically deployed: Ansible, Chef, Puppet, Saltstack, DSCv2, DSCv3
* "Ansible Content and Labs" with automated terraform infrastructure and configuration deployed for ansible host control
* Multiple Options for Configuration:
  - One Linux Master Server controlling one Linux client and two Windows clients
  - One Windows Server pulling its configuration from another DSC Windows Server
  - Flexibility to remove any of the systems, to just focus on one scenario (One Linux Master, one Windows client)
* Ansible Labs:
  - Ansible Cheat Sheet for commands pre-built.  Pre-configured Ansible infrastructure setup and inventory files host communication.
  - DFIR Live Response Ansible Playbook
  - Windows CIS Hardening Ansible Playbook
  - Ansible setup for Linux SSH, Windows WinRM, and Windows Powershell over SSH
  
## Requirements and Setup

**Tested with:**

* Mac OS 13.4
* terraform 1.5.7

**Clone this repository:**
```
git clone https://github.com/iknowjason/CMLab
```

**Credentials Setup:**

Generate an IAM programmatic access key that has permissions to build resources in your AWS account.  Setup your .env to load these environment variables.  You can also use the direnv tool to hook into your shell and populate the .envrc.  Should look something like this in your .env or .envrc:

```
export AWS_ACCESS_KEY_ID="VALUE"
export AWS_SECRET_ACCESS_KEY="VALUE"
```

## Build and Destroy Resources

### Run terraform init
Change into the AutomatedEmulation working directory and type:

```
terraform init
```

### Run terraform plan or apply
```
terraform apply -auto-approve
```
or
```
terraform plan -out=run.plan
terraform apply run.plan
```

### Destroy resources
```
terraform destroy -auto-approve
```

### View terraform created resources
The lab has been created with important terraform outputs showing services, endpoints, IP addresses, and credentials.  To view them:
```
terraform output
```

## Features and Capabilities

### Important Firewall and White Listing
By default when you run terraform apply, your public IPv4 address is determined via a query to ifconfig.so and the ```terraform.tfstate``` is updated automatically.  If your location changes, simply run ```terraform apply``` to update the security groups with your new public IPv4 address.  If ifconfig.me returns a public IPv6 address,  your terraform will break.  In that case you'll have to customize the white list.  To change the white list for custom rules, update this variable in ```sg.tf```:
```
locals {
  src_ip = "${chomp(data.http.firewall_allowed.response_body)}/32"
  #src_ip = "0.0.0.0/0"
}
```

## Customizing Ansible Playbooks
To add any Ansible playbooks, add any files to the ```files/linux/ansible/``` directory.  This directory is used to create a zip archive by terraform, uploaded to an S3 bucket, and then the Linux1 Master host downloads it from the S3 staging bucket.  This is a good location to update files into.  There is also a templatefiles directory in ```files/linux/templatefiles```. It stores all of the ansible template files that need rendered terraform variables for configuration dynamically built, such as host IP addresses or ansible credentials.

## Ansible Lab

All lab commands can be found in ```files/linux/ansible/EXAMPLES.README```

### Windows Examples

Command 1:
```
cd /home/ubuntu/ansible
ansible windows -i winhosts -m win_ping
```

Description:  A simple ansible ping test using default WinRM against all Windows hosts in the 'winhosts' inventory file.

Command 2:
```
cd /home/ubuntu/ansible
ansible-playbook -i winhosts runcmd.yml
```

Description:  This runs the playbook called 'runcmd.yml' against all Windows hosts in the 'winhosts' inventory file.  It runs a couple of cmd.exe example commands.

Command 3:
```
cd /home/ubuntu/ansible
ansible-playbook -i winhosts-ssh powershell-ssh.yml
```

Description: Run the playbook called 'powershell-ssh.yml'.  This playbook runs some commands on the target hosts, using the default shell.  The default shell over SSH connection is Windows Powershell.  This runs over SSH connection against Windows hosts.

### Ansible Lockdown Windows Server 2022 CIS Hardening

Reference: https://github.com/ansible-lockdown/Windows-2022-CIS

Command 1:
```
cd /home/ubuntu/ansible/Windows-2022-CIS
ansible-playbook -i winhosts site.yml
```

Description:  This runs the Windows 2022 CIS benchmark ansible playbook against the target Windows Server 2022 systems.
There should be two systems in the inventory list.

### Linux Examples

Command 1:
```
cd /home/ubuntu/ansible/
ansible -i linhosts linux -m ping
```

Description:  A simple ansible ping test using ssh against linux2 host in the 'linhosts' inventory file.

### Ansible Live Response DFIR Lab Example

Run the Live Response DFIR Lab examples created by Brian Olson

Reference: https://github.com/brian-olson/ansible-live-response

There are three playbooks.  First, setup the lamp stack on target linux2.  Second, perform triage.  Third, perform response.

Step 2.1: Run the ansible playbook lamp.yml.  This is Ansible playbook that install the LAMP stack.
Commands:
```
cd /home/ubuntu/ansible/ansible-live-response
ansible-playbook lamp.yml -i linhosts
```

Step 2.2:  Run the DFIR Triage playbook
Commands:
```
cd /home/ubuntu/ansible/ansible-live-response
sudo ansible-playbook DFIR-triage.yml -i linhosts
```

Step 2.3:  Run the DFIR response playbook.  This playbook makes some changes to the host based on the findings of the triage phase.  This patches, reconfigures services.  Removes malware.  Removes unauthorized local uses and terminates suspicious processes and network connections.

Commands:
```
cd /home/ubuntu/ansible/ansible-live-response
sudo ansible-playbook DFIR-respond.yml -i linhosts
```

