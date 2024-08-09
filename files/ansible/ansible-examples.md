##################
# WINDOWS EXAMPLES
##################

Command 1:  
cd /home/ubuntu/ansible
ansible windows -i winhosts -m win_ping
 
Description:  A simple ansible ping test using default WinRM against all Windows hosts in the 'winhosts' inventory file.

Command 2:
cd /home/ubuntu/ansible
ansible-playbook -i winhosts runcmd.yml

Description:  This runs the playbook called 'runcmd.yml' against all Windows hosts in the 'winhosts' inventory file.  It runs a couple of cmd.exe example commands.

Command 3:
cd /home/ubuntu/ansible
ansible-playbook -i winhosts-ssh powershell-ssh.yml

Description: Run the playbook called 'powershell-ssh.yml'.  This playbook runs some commands on the target hosts, using the default shell.  The default shell over SSH connection is Windows Powershell.  This runs over SSH connection against Windows hosts. 

####################################################
# ANSIBLE LOCKDOWN WINDOWS SERVER 2022 CIS HARDENING 
####################################################
Reference: https://github.com/ansible-lockdown/Windows-2022-CIS

Command 1:
cd /home/ubuntu/ansible/Windows-2022-CIS
ansible-playbook -i winhosts site.yml

Description:  This runs the Windows 2022 CIS benchmark ansible playbook against the target Windows Server 2022 systems.
There should be two systems in the inventory list.

################
# LINUX EXAMPLES
################

Command 1:
cd /home/ubuntu/ansible/
ansible -i linhosts linux -m ping

Description:  A simple ansible ping test using ssh against linux2 host in the 'linhosts' inventory file.

################################
# LIVE RESPONSE DFIR LAB EXAMPLE
################################
Run the Live Response DFIR Lab examples created by Brian Olson
Reference: https://github.com/brian-olson/ansible-live-response
There are three playbooks.  First, setup the lamp stack on target linux2.  Second, perform triage.  Third, perform response.

Step 2.1: Run the ansible playbook lamp.yml.  This is Ansible playbook that install the LAMP stack.
Commands:
cd /home/ubuntu/ansible/ansible-live-response
ansible-playbook lamp.yml -i linhosts

Step 2.2:  Run the DFIR Triage playbook
Commands:
cd /home/ubuntu/ansible/ansible-live-response
sudo ansible-playbook DFIR-triage.yml -i linhosts

Step 2.3:  Run the DFIR response playbook.  This playbook makes some changes to the host based on the findings of the triage phase.  This patches, reconfigures services.  Removes malware.  Removes unauthorized local uses and terminates suspicious processes and network connections.

Commands:
cd /home/ubuntu/ansible/ansible-live-response
sudo ansible-playbook DFIR-respond.yml -i linhosts
