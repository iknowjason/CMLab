# Chef Configuration Management Lab Guide

## Introduction

This lab guide will walk you through setting up a Chef environment and performing various configuration management tasks. You'll learn how to use Chef to manage both Linux and Windows servers, automating the deployment of software and configurations.

## Lab Environment

Your lab environment consists of:

1. One Linux server (Chef Server and Chef Workstation)
2. One Linux workstation (Chef Client)
3. Two Windows servers (Chef Clients)

## Components Overview

- **Chef Server**: The central hub that stores cookbooks, policies, and metadata about the managed nodes.
- **Chef Workstation**: Where you create, test, and maintain cookbooks.
- **Chef Client**: Software installed on each node (server) that Chef manages.
- **Knife**: A command-line tool for interacting with the Chef Server.
- **Cookbooks**: Collections of recipes that describe a specific configuration or policy.
- **Recipes**: Written in Ruby, they specify the resources to use and the order in which they are applied.

## Setup

This lab guide was adapted from the Linode guide here:  https://www.linode.com/docs/guides/how-to-install-chef-on-ubuntu-20-04/
For this implementation, we have combined the chef server and chef workstation onto the lin1 system.

### Chef Master:  Initial Server Core Setup

In this section, you'll set up the Chef Server on your Linux master server.  SSH into the linux master Ubuntu 22.04 by looking at the results from ```terraform output```.

1. Install Chef Server on Linux Master (lin1):
   ```bash
   sudo dpkg -i chef-server-core_15.1.7-1_amd64.deb
   ``` 
2. Start the Chef Server and accept yes when prompted:
   ```bash
   sudo chef-server-ctl reconfigure
   ```
3. Create a ```.chef``` directory to store the keys for authentication used for the administrator.
   ```bash
   mkdir ~/.chef
   ```
4. Add a user account for Chef administration using the ```chef-server-ctrl``` command.  In this example below, I'm adding a user of ```John Doe``` with a username of ```admin``` and email address of ```jdoe888@gmail.com```.  This command will create a private key pem file and store it as ```admin.pem``` in your ```.chef``` directory.
   ```bash
   sudo chef-server-ctl user-create admin john doe jdoe888@gmail.com 'mypassword888' --filename ~/.chef/admin.pem
   ```
5. Review the user list and confirm that this account exists:
   ```bash
   sudo chef-server-ctl user-list
   ```
6. Create a new organizatin using the ```chef-server-ctl``` command.  For this example the organization is ```acme```.  The organization certificate will be associated with the ```admin``` user and stored in the ```.chef``` directory.
   ```bash
   sudo chef-server-ctl org-create acme "acme_corporation" --association_user admin --filename ~/.chef/acme.pem
   ```
7. List out the organizations, confirming that it was created:
   ```bash
   sudo chef-server-ctl org-list
   ```
### Chef Master:  Reconfigure for self-signed TLS certificate

8. You will need to generate a new self-signed TLS certificate that can be used to simulate proper DNS and certificate based authentication.  We will **cheat** here by using the /etc/hosts for DNS.  Get the private IP address of this system by typing ```ifconfig```.  Add an entry in the ```/etc/hosts``` file so that the chef workstation knife utility can manage the server.  This would show how a chef workstation administrator would be managing the chef installation to push changes from a secondary system.  For this lab, we are combining chef server and workstation into a single system.  In my example, my private IP address is ```10.100.20.143``` as determined by ```ifconfig``` or you can run ```terraform output``` to grab it.  Edit /etc/hosts to point an internal hosts entry for ```chef.acme.com``` pointing to this internal IP address, or replace it with whatever fqdn you desire.  For this example, we are using ```chef.acme.com``` to represent the chef server.
   ```bash
   sudo vi /etc/hosts
   ```
   My example shows:
   ```
   10.100.20.143 chef.acme.com
   ```
   Verify hostname resolution by typing ```ping chef.acme.com```.  Nice work!  You are now ready to setup a self-signed TLS certificate and reconfigure Chef to bind and use the TLS certificate on its nginx port 443.

9. Generate a self-signed TLS certificate with the following commands.  First, generate a private key:
   ```bash
   openssl genrsa -out chef-server.key 2048
   ```

   Next, create a certificate signing request (CSR).  In this example, we are using a Common Name (CN) of ```chef.acme.com```.  Replace as appropriate for your environment:
   ```bash
   openssl req -new -key chef-server.key -out chef-server.csr -subj "/CN=chef.acme.com"
   ```

   Third, generate the self-signed certificate using the csr and private key:
   ```bash
   openssl x509 -req -in chef-server.csr -signkey chef-server.key -out chef-server.crt -days 36
   ```

   Finally, create a combined PEM file that we can copy into the ca directory used by Chef's nginx service:
   ```bash
   cat chef-server.crt chef-server.key > chef-server.pem
   ```

10. Configure the Chef Server to use the self-signed certificate and private keys.  Move the ```chef-server.pem``` file to the Chef server's ca configuration directory:
    ```bash
    cp chef-server.pem /var/opt/opscode/nginx/ca/.
    ```

    Copy the private key file to the configuration directory:
    ```bash
    cp chef-server.key /var/opt/opscode/nginx/ca/.
    ```

    Edit the Chef Server configuration file to use the new certificate and private key.  Edit the following file:
    ```bash
    /etc/opscode/chef-server.rb
    ```

    Add the following lines to **/etc/opscode/chef-server.rb**:
    ```bash
    nginx['ssl_certificate'] = '/var/opt/opscode/nginx/ca/chef-server.crt'
    nginx['ssl_certificate_key'] = '/var/opt/opscode/nginx/ca/chef-server.key'
    ```

11. Reconfigure the Chef Server to apply the changes for the new certificates:
    ```bash
    sudo chef-server-ctl reconfigure
    ```
    Nice job!  Now the server should be listening once again on TCP/443.  If you want to verify this you can verify the listening service and make a test connection using openssl:
    ```bash
    sudo netstat -tulpn | grep 443
    openssl s_client -connect chef.acme.com:443
    ```

### Chef Master:  Chef Workstation Setup

In this section, you'll set up the Chef Workstation software on your Linux master server.  SSH into the linux master Ubuntu 22.04 by looking at the results from ```terraform output```.  For this lab, the workstation is running on the same server as the Chef Server core software.  

1. The chef workstation software has already been installed through the terraform bootstrap script using ec2 agent with user-data.  Go ahead and verify that it is installed by typing ```chef -v```.  You should see this in the output:
   ```bash
   ubuntu@ip-10-100-20-143:~$ chef -v
   Chef Workstation version: 22.10.1013
   Chef Infra Client version: 17.10.0
   Chef InSpec version: 4.56.20
   Chef CLI version: 5.6.1
   Chef Habitat version: 1.6.521
   Test Kitchen version: 3.3.2
   Cookstyle version: 7.32.1
   ```
   
2. Just in case it is not installed, you can type the following to download and install chef workstation software:
   ```bash
   wget https://packages.chef.io/files/stable/chef-workstation/22.10.1013/ubuntu/20.04/chef-workstation_22.10.1013-1_amd64.deb
   dpkg -i chef-workstation_*.deb
   ```

3. Create a ```chef-repo``` repository where we will store Chef cookbook and recipes for Configuration Management.  Enter yes when prompted:
   ```bash
   cd ~
   chef generate repo chef-repo
   ```

4. Create a ```.chef``` subdirectory inside of the created ```chef-repo``` directory.  This is where the knife configuration file is stored in addition to the authentication keys used by the admin to push changes.
   ```bash
   mkdir ~/chef-repo/.chef
   cd chef-repo
   ```
5. In the next section,  we will setup RSA private keys on the simulated "workstation" and copy over the new public keys.  This will provide better security between the Chf Server and workstation by permitting public key authentication.

   On the workstation (same system you should be on), generate an RSA key pair:
   ```bash
   ssh-keygen -b 4096
   ```
   Follow the prompts to enter a keyphrase, if applicable.

6. Setup a system password for the default ubuntu username and ensure that password authentication is enabled.  You will then copy over the public key from the workstation to the server.  This is the same system, but you might have a use case in the future for deploying the workstation on a separate system.  When prompted, enter a new password twice for ubuntu and take note of this password.
   ```bash
   sudo passwd ubuntu
   ```
   Edit the following file to ensure that password authentication is allowed:
   ```bash
   /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
   ```

   Ensure that ```yes``` is allowed for the value:
   ```
   PasswordAuthentication yes
   ```

   Restart the SSH service if you made any changes to allow password authentication:
   ```
   sudo systemctl restart ssh
   ```

   Finally, copy the ssh public key you created at the beginning of this step to the authorized keys by typing the following command.  SSH to the private IP address of the same server:
   ```bash
   ssh-copy-id ubuntu@chef.acme.com
   ```

7. Copy over the Chef admin user's keys used for authentication.  Normally you would use ```scp``` to copy them from the Chef server to the local Chef workstation.  But in this lab implementation, since you are running server and workstation on the same system, we can copy it locally.  Go ahead and copy the **admin.pem** and **acme.pem** from the server's directory to the workstation's ```~/chef-repo/.chef``` directory.
   ```bash
   cp ~/.chef/admin.pem ~/chef-repo/.chef/.
   cp ~/.chef/acme.pem ~/chef-repo/.chef/.
   ```

   Verify that the files are in place in the chef workstation target directory:
   ```bash
   ls ~/chef-repo/.chef
   ```

8. Setup a version control system repository for any Chef Workstation changes.  This is so we can track any changes to cookbook files and have versioning to restore earlier versions where necessary.  For this example, we will use git.  Configure Git client configuration, replacing username and email address parameters with your own:
   ```bash
   git config --global user.name username
   git config --global user.email user@email.com
   ```

   Add the ```.chef``` directory to the ```.gitignore``` file.
   ```bash
   echo ".chef" > ~/chef-repo/.gitignore
   ```

   Add and commit the existing files using git add and git commit.
   ```bash
   cd ~/chef-repo
   git add .
   git commit -m "Initial commit"
   ```

   Run git status to ensure the files have been staged and commited locally.
   ```bash
   git status
   ```

9. Create a Chef Cookbook.  Use the ```chef generate``` command to generate a new chef cookbook.
   ```bash
   chef generate cookbook my_cookbook
   ```

10. Next you will set up the Chef **Knife** utility and its configuration.  Chef Knife helps Chef Workstation to communicate with the server by managing cookbooks and nodes.  Chef uses a **config.rb** file in the **.chef** subdirectory to store the knife configuration.  Create a ```config.rb``` file in the destination .chef directory:
    ```bash
    cd ~/chef-repo/.chef
    vi config.rb
    ```

    Edit the config.rb to match your chef environment.  Here is a blank template of what you can copy and paste into the file:
    ```bash
    current_dir = File.dirname(__FILE__)
    log_level                :info
    log_location             STDOUT
    node_name                'node_name'
    client_key               "USER.pem"
    validation_client_name   'ORG_NAME-validator'
    validation_key           "ORG_NAME-validator.pem"
    chef_server_url          'https://example.com/organizations/ORG_NAME'
    cache_type               'BasicFile'
    cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
    cookbook_path            ["#{current_dir}/../cookbooks"]
    ```

    Make changes to the following to match your previous setup.  In the example below, we show the values that you could have used previously:
    ```
    current_dir = File.dirname(__FILE__)
    log_level                :info
    log_location             STDOUT
    node_name                'admin'
    client_key               "admin.pem"
    validation_client_name   'acme-validator'
    validation_key           "acme-validator.pem"
    chef_server_url          'https://chef.example.com/organizations/acme'
    cache_type               'BasicFile'
    cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
    cookbook_path            ["#{current_dir}/../cookbooks"]
    ```

11. Now that you're update the knife configuration file, config.rb, we can now test communication to the Chef Server!
    ```bash
    cd ..
    knife ssl fetch
    ```

    Now run the knife client list command to show the acme-validator.  If this shows the company name followed by validator, nice work!
    ```bash
    knife client list
    ```
   
 ### Bootstrapping a Chef Linux Node

In this section, you'll bootstrap a chef node or client.  The **linux2** system will be used as the node in this lab.  Look in the output from ```terraform output``` and access the system over SSH.   After remotely accessing **linux2** over SSH, set up the /etc/hosts file so the chef server IP address can be resolved.  

1. On **linux2:**  edit the /etc/hosts file so that the fqdn of Chef Server can be resolved:
   ```bash
   sudo vi /etc/hosts
   ```
   My example shows:
   ```
   10.100.20.143 chef.acme.com
   ```
   Verify hostname resolution by typing ```ping chef.acme.com``` from **linux2**.

2. On **linux2:**  setup a system password for the default ubuntu username and ensure that password authentication is enabled.  The Chef Workstation will be using password authentication to bootstrap this chef client node, linux2.
   ```bash
   sudo passwd ubuntu
   ```
   Edit the following file to ensure that password authentication is allowed:
   ```bash
   /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
   ```

   Ensure that ```yes``` is allowed for the value:
   ```
   PasswordAuthentication yes
   ```

   Restart the SSH service if you made any changes to allow password authentication:
   ```
   sudo systemctl restart ssh
   ```

3.  Now are ready to bootstrap the node using Chef Workstation!  Return back to the linux1 Chef Workstation system and run the following knife command, first ensuring you are in the workstation directory:
    ```bash
    cd ~/chef-repo/.chef
    ```

    Get the IP address of the linux2 chef node and the Ubuntu OS username and password you setup previously.  Copy and paste the command:
    ```bash
    knife bootstrap node_ip_address -U username -P password --sudo --use-sudo-password --node-name nodename
    ```
    Here is the command running from my lab system using the node IP address of ```10.100.20.180``` and a node friendly name of lin2.
    ```bash
    knife bootstrap 10.100.20.180 -U ubuntu -P mypassword456 --sudo --use-sudo-password --node-name lin2
    ```
    Finally, let's use the knife command to list and verify managed nodes or clients:
    ```bash
    knife client list
    ```
    If you see the new linux node listed, nice work.  You are now in business and ready to start applying cookbooks to the managed node.  In the next section, you will bootstrap the windows nodes so they too can be managed.

    Edit the workstation's etc/hosts to add the new bootstrap node's hostname and IP address:
    ```bash
    sudo vi /etc/hosts
    ```
    My example shows:
    ```
    10.100.20.180 lin2.acme.com
    ```

 ### Bootstrapping the Chef Windows Nodes

In this section, you'll bootstrap the two Windows servers to be Chef nodes.  The **win1** and **win2** systems will be used as the node in this lab.  Look in the output from ```terraform output``` and access the system over SSH.  They have been bootstrapped with OpenSSH server so you can access a powershell session and make the necessary changes.   After remotely accessing both systems over SSH, set up the /etc/hosts file so the chef server IP address can be resolved.  

1. On **win1:**  edit the Windows hosts file so that the fqdn of Chef Server can be resolved.  Get the remote SSH IP address from ```terraform output```.  Use the local administrator and password credentials.  The output in ```terraform output``` will look similar to this:
   ```bash
   -------------
   SSH to win1
   -------------
   ssh RTCAdmin@18.217.98.195
   ```
   Verify the correct password shown in the output above, it should be the **local password** of ```Proud-lion-2024!```.  Type the correct local administrator password.
   
   After you have the powershell session established, you can use this section of code to add a hosts entry so the Windows server can resolve chef.  Here is a copy and paste that should be adapted:
   
   ```  
   $hostname = "chef.acme.com"
   $ipAddress = "10.100.20.143"
   $entry = "$ipAddress `t $hostname"
   $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
   Add-Content -Path $hostsPath -Value $entry
   # Verify that hosts file looks correct
   Get-Content -Path $hostsPath | Select-String -Pattern $hostname
   ```
   Verify hostname resolution by typing ```ping chef.acme.com``` from **win1** powershell session.

2. On **win2:**  edit the Windows hosts file so that the fqdn of Chef Server can be resolved.  Get the remote SSH IP address from ```terraform output```.  Use the local administrator and password credentials.  The output in ```terraform output``` will look similar to this:
   ```bash
   -------------
   SSH to win2
   -------------
   ssh RTCAdmin@3.138.141.137
   ```
   Verify the correct password shown in the output above, it should be the **local password** of ```Proud-lion-2024!```.  Type the correct local administrator password.
   
   After you have the powershell session established, you can use this section of code to add a hosts entry so the Windows server can resolve chef.  Here is a copy and paste that should be adapted:
   
   ```  
   $hostname = "chef.acme.com"
   $ipAddress = "10.100.20.143"
   $entry = "$ipAddress `t $hostname"
   $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
   Add-Content -Path $hostsPath -Value $entry
   # Verify that hosts file looks correct
   Get-Content -Path $hostsPath | Select-String -Pattern $hostname
   ```
   Verify hostname resolution by typing ```ping chef.acme.com``` from **win2** powershell session.
   
3. On the Chef Workstation/Server linux system, bootstrap win1.  Replace the private IP address below with the correct private IP address of win1, as shown from terraform output.  These two windows systems have been bootstrapped to enable WinRM transport protocol for provisioning.  The command uses winrm protocol.
   ```bash
   cd ~/chef-repo/.chef
   knife bootstrap -o winrm 10.100.20.160 -U ansible -P Brave-monkey-2024! --node-name win1
   ```

4. On the Chef Workstation/Server linux system, bootstrap win2.  Replace the private IP address below with the correct private IP address of win2, as shown from terraform output.  These two windows systems have been bootstrapped to enable WinRM transport protocol for provisioning.  The command uses winrm protocol.
   ```bash
   cd ~/chef-repo/.chef
   knife bootstrap -o winrm 10.100.20.161 -U ansible -P Brave-monkey-2024! --node-name win2
   ```

5. Finally, let's use the knife command to list and verify managed nodes or clients:
   ```bash
   knife client list
   ```

   Nice work!  You should now see all three managed chef nodes listed, including lin2, win1, and win2!  Now you can update the /etc/hosts file on Chef workstation to include all three managed nodes.

   Edit the workstation's etc/hosts to add the new bootstrap node's hostname and IP address:
    ```bash
    sudo vi /etc/hosts
    ```
    My example shows:
    ```
    10.100.20.180 lin2.acme.com
    10.100.20.160 win1.acme.com
    10.100.20.161 win2.acme.com
    ```


### Build and Apply Linux Cookbooks
Some description here.
1.
2.
3.

### Build and Apply Windows Cookbooks
Some description here.
1.
2.
3.


   


