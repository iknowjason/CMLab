# Salt Stack Configuration Management
## Introduction

This lab guide will walk you through setting up a Saltstack environment and performing configuration management tasks between a Linux Salt master and a salt minion running on linux.  You will install and configure a Salt Stack master on a Linux server and a Salt minion on another Linux server. You will then apply a configuration change using Salt to install and configure auditd on the minion.


## Lab Environment
Your lab environment consists of two Linux systems:

- Salt master (linux1)
- Salt minion (linux2)

## Lab Steps

### Verify Salt Stack Master

1. SSH into the **linux1** master by looking at output from ```terraform output```.  The Salt Stack master software is already installed when the linux1 system bootstraps through the user-data script and ec2-agent.  Verify that the service is running:
   
   ```bash
   sudo systemctl status salt-master
   ``` 

### Install Salt Minion

Step 2: Installing Salt Minion

    Update the package list on the minion server:

    bash

sudo apt-get update

Install the Salt minion package:

bash

sudo apt-get install salt-minion -y

Configure the Salt minion to connect to the Salt master:

Edit the /etc/salt/minion configuration file:

bash

sudo nano /etc/salt/minion

Uncomment and set the master parameter to the IP address or hostname of your Salt master:

bash

master: <Salt_Master_IP_or_Hostname>

Save and close the file.

Start and enable the Salt minion service:

bash

sudo systemctl start salt-minion
sudo systemctl enable salt-minion

Verify that the Salt minion service is running:

bash

    sudo systemctl status salt-minion

### Accept the Minion's Key on the Master

Step 3: Accepting the Minion's Key on the Master

    List the pending keys on the Salt master:

    bash

sudo salt-key -L

Accept the minion's key:

bash

sudo salt-key -a <minion_hostname>

Confirm the key acceptance when prompted.

Verify that the minion is communicating with the master:

bash

    sudo salt '*' test.ping

    The minion should respond with True.

### Create a Salt State to Install Auditd

Step 4: Creating a Salt State to Install auditd

    Create a directory for your Salt state files on the master:

    bash

sudo mkdir -p /srv/salt

Create a Salt state file to install and configure auditd:

bash

sudo nano /srv/salt/auditd.sls

Add the following content to install auditd:

yaml

    install_auditd:
      pkg.installed:
        - name: auditd

    start_auditd:
      service.running:
        - name: auditd
        - enable: True
        - require:
          - pkg: install_auditd

    Save and close the file.

### Apply the Configuration to the Minion

Step 5: Applying the Configuration to the Minion

    Apply the auditd configuration to the minion:

    bash

sudo salt '<minion_hostname>' state.apply auditd

### Verify the Configuration

Verify the installation and status of auditd:

On the minion server, run:

bash

    systemctl status auditd

    You should see that the auditd service is active and running.

Step 6: Verifying the Configuration

    Check that auditd was successfully installed on the minion:

    bash

sudo salt '<minion_hostname>' pkg.version auditd

This should return the installed version of auditd.

Confirm that the auditd service is running:

bash

sudo salt '<minion_hostname>' service.status auditd

The response should indicate that the service is running.
