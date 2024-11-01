# Salt Stack Configuration Management
## Introduction

This lab guide will walk you through setting up a Saltstack environment and performing configuration management tasks between a Linux Salt master and a salt minion running on linux.  You will install and configure a Salt Stack master on a Linux server and a Salt minion on another Linux server. You will then apply a configuration change using Salt to install and configure auditd on the minion.


## Lab Environment
Your lab environment consists of two Linux systems:

- Salt master (linux1)
- Salt minion (linux2)

## Lab Steps

### Verify Salt Master

1. Install salt on the master using the bootstrap script with instructions here:  https://docs.saltproject.io/salt/install-guide/en/latest/topics/bootstrap.html.  SSH into the **linux1** master by looking at output from ```terraform output```.  The Salt Stack master software is already installed when the linux1 system bootstraps through the user-data script and ec2-agent.  Verify that the service is running:
   
   ```bash
   sudo systemctl status salt-master
   ``` 

### Salt Minion Setup

1. Install salt on the minion using the bootstrap script with instructions here:  https://docs.saltproject.io/salt/install-guide/en/latest/topics/bootstrap.html.  SSH into the **linux2** minion by looking at output from ```terraform output```.  The Salt Stack minion software is already installed when the linux2 system bootstraps through the user-data script and ec2-agent.  Verify that the service is running:

   ```bash
   sudo systemctl status salt-minion
   ```

2. Configure the Salt minion to connect to the Salt master.  Edit the /etc/salt/minion configuration file:

   ```bash
   sudo vi /etc/salt/minion
   ```

   Uncomment and set the master parameter to the IP address or hostname of your Salt master.  Grab the private IP address of your Salt Master by typing ```ifconfig``` from the ssh session or ```terraform output```.  In my example shown below, the master IP address is ```10.100.20.125```.

   ```bash
   master: 10.100.20.125
   ```

   Save and close the file.

   Restart the Salt minion service:
   ```bash
   sudo systemctl restart salt-minion
   ```

### Accept the Minion's Key on the Master

1. Back on the Salt Master linux system, list the pending keys:
   ```bash
   sudo salt-key -L
   ```

   Under ```Unaccepted Keys```, you should see the request from the minion.  Example shown below:
   ```
   Unaccepted Keys:
   ip-10-100-20-170.us-east-2.compute.internal
   ```

   Accept the minion's key by copying and pasting the FQDN shown for the key.  My example shows an unaccepted key for the fqdn of ```ip-10-100-20-170.us-east-2.compute.internal``` which I will use below:
   ```bash
   sudo salt-key -a ip-10-100-20-170.us-east-2.compute.internal
   ```

   Confirm the key acceptance when prompted.
   ```bash
   The following keys are going to be accepted:
   Unaccepted Keys:
   ip-10-100-20-170.us-east-2.compute.internal
   Proceed? [n/Y] y
   Key for minion ip-10-100-20-170.us-east-2.compute.internal accepted.
   ```

   Verify that the minion is communicating with the master:
   ```bash
   sudo salt '*' test.ping
   ```

   The minion should respond with ```True``` as the example shows below:
   ```bash
   sudo salt '*' test.ping
   ip-10-100-20-170.us-east-2.compute.internal:
      True
   ```

   Nice job!  You can see the power and simplicity of using Salt stack and how easy it is to register a minion to master.  Now we can start to create a salt state to push this configuration for Auditd!

### Create a Salt State to Install Auditd

1. On Master: Let's create a Salt State that will install install auditd on minion.  Create a directory for your Salt state files on the master:
   ```bash
   sudo mkdir -p /srv/salt
   ```

   Next, create a Salt state file to install and configure auditd:
   ```bash
   sudo vi /srv/salt/auditd.sls
   ```

   Add the following content into the file.  This will install auditd and configure ```audit.rules```:
   ```bash
   install_auditd:
     pkg.installed:
       - name: auditd

   start_auditd:
     service.running:
       - name: auditd
       - enable: True
       - require:
         - pkg: install_auditd

   audit_rules:
     file.managed:
       - name: /etc/audit/audit.rules
       - source: salt://audit.rules
       - user: root
       - group: root
       - mode: 0640
       - require:
         - pkg: install_auditd

   audit_conf:
     file.managed:
       - name: /etc/audit/auditd.conf
       - source: salt://auditd.conf
       - user: root
       - group: root
       - mode: 0640
       - require:
         - pkg: install_auditd

   reload_auditd:
     cmd.run:
       - name: 'augenrules --load'
       - require:
         - file: audit_rules
   ```
   
   Save and close the file.

2. Create the audit.rules file on the Salt master:
   ```bash
   sudo vi /srv/salt/audit.rules
   ```

   Add the following content and save the file:
   ```bash
   # First rule - delete all
   -D

   # Increase the buffers to survive stress events.
   # Make this bigger for busy systems
   -b 8192

   # Audit the audit logs
   -w /var/log/audit/ -k auditlog

   # Auditd configuration
   -w /etc/audit/ -p wa -k auditconfig
   -w /etc/libaudit.conf -p wa -k auditconfig
   -w /etc/audisp/ -p wa -k audispconfig

   # Monitor for use of audit management tools
   -w /sbin/auditctl -p x -k audittools
   -w /sbin/auditd -p x -k audittools

   # Monitor AppArmor configuration changes
   -w /etc/apparmor/ -p wa -k apparmor
   -w /etc/apparmor.d/ -p wa -k apparmor

   # Monitor usage of passwd command
   -w /usr/bin/passwd -p x -k passwd_modification

   # Monitor user/group tools
   -w /usr/sbin/groupadd -p x -k group_modification
   -w /usr/sbin/groupmod -p x -k group_modification
   -w /usr/sbin/addgroup -p x -k group_modification
   -w /usr/sbin/useradd -p x -k user_modification
   -w /usr/sbin/usermod -p x -k user_modification
   -w /usr/sbin/adduser -p x -k user_modification

   # Monitor changes to /etc/passwd and /etc/shadow
   -w /etc/passwd -p wa -k passwd_changes
   -w /etc/shadow -p wa -k shadow_changes
   ```

3. Creat the ```auditd.conf``` file on the Salt master:
   ```bash
   sudo vi /srv/salt/auditd.conf
   ```

   Add the following content and save the file:
   ```bash
   # Sample Auditd Configuration
   log_file = /var/log/audit/audit.log
   log_format = ENRICHED
   priority_boost = 4
   flush = INCREMENTAL_ASYNC
   freq = 50
   num_logs = 5
   max_log_file = 8
   max_log_file_action = ROTATE
   space_left = 75
   space_left_action = SYSLOG
   admin_space_left = 50
   admin_space_left_action = SUSPEND
   disk_full_action = SUSPEND
   disk_error_action = SUSPEND
   ```

   Nice job.  We are now ready to push the salt state file to the minion.


### Apply the Configuration to the Minion

1. From Salt Master, apply the ```auditd```, ```audit.rules```, and ```auditd.conf``` configuration to the minion by using the salt minion host.  In this example, the salt minion was listed with ** sudo salt-key -L** and discovered as ```ip-10-100-20-170.us-east-2.compute.internal```.
   ```bash
   sudo salt ip-10-100-20-170.us-east-2.compute.internal state.apply auditd
   ```

   You should see the following successful results:
   ```bash
   Summary for ip-10-100-20-170.us-east-2.compute.internal
   ------------
   Succeeded: 5 (changed=3)
   Failed:    0
   ------------
   Total states run:     5
   Total run time: 169.547 ms
   ```

   Nice job applying salt state to a minion!

### Verify the Configuration

1. On master, check that ```auditd``` was successfully installed on the minion:

   ```bash
   sudo salt ip-10-100-20-170.us-east-2.compute.internal pkg.version auditd
   ```

   This should return the installed version of auditd.

2. On master, confirm that the ```auditd``` service is running.  Change your minion hostname to match your environment:

    ```bash
    sudo salt ip-10-100-20-170.us-east-2.compute.internal service.status auditd
    ```

    You should see that the auditd service is active and running.
   
4. On master, verify that the ```audit.rules``` are correctly applied:
   
   ```bash
   sudo salt ip-10-100-20-170.us-east-2.compute.internal cmd.run 'auditctl -l'
   ```

5. On master, verify the ```auditd.conf``` configuration:
   
   ```bash
   sudo salt ip-10-100-20-170.us-east-2.compute.internal cmd.run 'cat /etc/audit/auditd.conf'
   ```
