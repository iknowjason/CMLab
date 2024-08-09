# Salt Stack Configuration Management
## Introduction

This lab guide will walk you through setting up a Saltstack environment and performing configuration management tasks between a Linux Salt master and a salt minion running on linux.  You will install and configure a Salt Stack master on a Linux server and a Salt minion on another Linux server. You will then apply a configuration change using Salt to install and configure auditd on the minion.


## Lab Environment
Your lab environment consists of two Linux systems:

- Salt master (linux1)
- Salt minion (linux2)

## Lab Steps

### Verify Salt Master

1. SSH into the **linux1** master by looking at output from ```terraform output```.  The Salt Stack master software is already installed when the linux1 system bootstraps through the user-data script and ec2-agent.  Verify that the service is running:
   
   ```bash
   sudo systemctl status salt-master
   ``` 

### Salt Minion Setup

1. SSH into the **linux2** minion by looking at output from ```terraform output```.  The Salt Stack minion software is already installed when the linux2 system bootstraps through the user-data script and ec2-agent.  Verify that the service is running:

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
