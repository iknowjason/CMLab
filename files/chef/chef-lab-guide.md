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

In this section, you'll set up the Chef Server on your Linux master server.  SSH into the linux master Ubuntu 22.04 by looking at the results from ```terraform output```.  You might need to wait until all of the packages have installed (bootstrap complete) before starting this process.  You can ```tail -f /var/log/user-data.log``` and watch the logfile in realtime.  When bootstrap is complete, you should see **End of bootstrap script**.

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

8. You will need to generate a new self-signed TLS certificate that can be used to simulate proper DNS and certificate based authentication.  We will **cheat** here by using the /etc/hosts for DNS.  Get the private IP address of this system by typing ```ifconfig```.  Add an entry in the ```/etc/hosts``` file so that the chef workstation knife utility can manage the server.  This would show how a chef workstation administrator would be managing the chef installation to push changes from a secondary system.  For this lab, we are combining chef server and workstation into a single system.  In my example, my private IP address is ```10.100.20.143``` as determined by ```ifconfig``` or you can run ```terraform output``` to grab it.  Edit /etc/hosts to point an internal hosts entry for ```chef.acme.local``` pointing to this internal IP address, or replace it with whatever fqdn you desire.  For this example, we are using ```chef.acme.local``` to represent the chef server.
   ```bash
   sudo vi /etc/hosts
   ```
   My example shows:
   ```
   10.100.20.143 chef.acme.local
   ```
   Verify hostname resolution by typing ```ping chef.acme.local```.  Nice work!  You are now ready to setup a self-signed TLS certificate and reconfigure Chef to bind and use the TLS certificate on its nginx port 443.

9. Generate a self-signed TLS certificate with the following commands.  First, generate a private key:
   ```bash
   openssl genrsa -out chef-server.key 2048
   ```

   Next, create a certificate signing request (CSR).  In this example, we are using a Common Name (CN) of ```chef.acme.local```.  Replace as appropriate for your environment:
   ```bash
   openssl req -new -key chef-server.key -out chef-server.csr -subj "/CN=chef.acme.local"
   ```

   Third, generate the self-signed certificate using the csr and private key:
   ```bash
   openssl x509 -req -in chef-server.csr -signkey chef-server.key -out chef-server.crt -days 36
   ```


10. Configure the Chef Server to use the self-signed certificate and private keys.  Move the ```chef-server.pem``` file to the Chef server's ca configuration directory:
    ```bash
    sudo cp chef-server.crt /var/opt/opscode/nginx/ca/.
    ```

    Copy the private key file to the configuration directory:
    ```bash
    sudo cp chef-server.key /var/opt/opscode/nginx/ca/.
    ```

    Edit the Chef Server configuration file to use the new certificate and private key.  Copy and paste the following into your bash session:
    ```bash
    sudo bash -c 'cat <<EOF > /etc/opscode/chef-server.rb
    nginx["ssl_certificate"] = "/var/opt/opscode/nginx/ca/chef-server.crt"
    nginx["ssl_certificate_key"] = "/var/opt/opscode/nginx/ca/chef-server.key"
    EOF'
    ```

11. Reconfigure the Chef Server to apply the changes for the new certificates:
    ```bash
    sudo chef-server-ctl reconfigure
    ```
    Nice job!  Now the server should be listening once again on TCP/443.  If you want to verify this you can verify the listening service and make a test connection using openssl:
    
    ```bash
    sudo netstat -tulpn | grep 443
    ```
    Test the connection using openssl.  You should see the TLS handshake and the self-signed certificate:
    
    ```bash
    openssl s_client -connect chef.acme.local:443
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
   ssh-copy-id ubuntu@chef.acme.local
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
    chef_server_url          'https://chef.acme.local/organizations/acme'
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
   10.100.20.143 chef.acme.local
   ```
   Verify hostname resolution by typing ```ping chef.acme.local``` from **linux2**.

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

3.  Now you are ready to bootstrap the node using Chef Workstation!  Return back to the linux1 Chef Workstation system and run the following knife command, first ensuring you are in the workstation directory:
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
    10.100.20.180 lin2.acme.local
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
   $hostname = "chef.acme.local"
   $ipAddress = "10.100.20.143"
   $entry = "$ipAddress `t $hostname"
   $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
   Add-Content -Path $hostsPath -Value $entry
   # Verify that hosts file looks correct
   Get-Content -Path $hostsPath | Select-String -Pattern $hostname
   ```
   Verify hostname resolution by typing ```ping chef.acme.local``` from **win1** powershell session.

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
   $hostname = "chef.acme.local"
   $ipAddress = "10.100.20.143"
   $entry = "$ipAddress `t $hostname"
   $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
   Add-Content -Path $hostsPath -Value $entry
   # Verify that hosts file looks correct
   Get-Content -Path $hostsPath | Select-String -Pattern $hostname
   ```
   Verify hostname resolution by typing ```ping chef.acme.local``` from **win2** powershell session.
   
3. On the Chef Workstation/Server linux system, bootstrap win1.  Replace the private IP address below with the correct private IP address of win1, as shown from terraform output.  These two windows systems have been bootstrapped to enable WinRM transport protocol for provisioning.  The command uses winrm protocol.
   ```bash
   cd ~/chef-repo/.chef
   knife bootstrap -o winrm 10.100.20.160 -U RTCAdmin -P Proud-lion-2024! --node-name win1
   ```

4. On the Chef Workstation/Server linux system, bootstrap win2.  Replace the private IP address below with the correct private IP address of win2, as shown from terraform output.  These two windows systems have been bootstrapped to enable WinRM transport protocol for provisioning.  The command uses winrm protocol.
   ```bash
   cd ~/chef-repo/.chef
   knife bootstrap -o winrm 10.100.20.161 -U RTCAdmin -P Proud-lion-2024! --node-name win2
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
    10.100.20.180 lin2.acme.local
    10.100.20.160 win1.acme.local
    10.100.20.161 win2.acme.local
    ```


### Build and Apply a Linux Cookbook
In this next section, we will practice applying a cookbook to a target linux node.  Cookbooks are an efficient way to package configuration changes and update target nodes.
1. Change into the .chef directory and use the knife utility to download the an auditd cookbook from Chef supermarket.  Chef supermarket is a website where Chef users can share cookbooks.
   ```bash
   cd ~/chef-repo/.chef
   knife supermarket download auditd
   ```
   You should see in the output that the auditd package was downloaded to the following location:
   ```bash
   Cookbook saved: /home/ubuntu/chef-repo/.chef/auditd-2.4.0.tar.gz
   ```
2. Use tar to extract the tarball and move the extracted directory to the cookbooks directory you previously created:
   ```bash
   tar xf auditd-2.4.0.tar.gz
   cp -r auditd ~/chef-repo/cookbooks/
   ```
3. Review the cookbook's **default.rb** file to see the recipe written in ruby.
   ```bash
   more ~/chef-repo/cookbooks/auditd/recipes/default.rb
   ```
4. Add the recipe to the run list for the ```lin2``` node.
   ```bash
   knife node run_list add lin2 'recipe[auditd::default]'
   ```
   This will add the default recipe we looked at in ```default.rb``` to the run list for the ```lin2``` node.  You should see this in the output:
   ```bash
   lin2:
     run_list: recipe[auditd::default]
   ```
5. Upload the cookbook and its recipes to the Chef server:
   ```bash
   knife cookbook upload auditd
   ```
   You should see that the cookbook has been uploaded to the Chef server, as shown below:
   ```bash
   Uploading auditd         [2.4.0]
   Uploaded 1 cookbook.
   ```
6. Run the chef-client command on the ```lin2``` node using the knife ssh utility.  It uses SSH and will prompt for a password for the ubuntu user.  This will apply the auditd recipe that you previously added to the run list of that node by causing the node to pull the recipes in its run list from the Chef Server.  The Chef Server transmits the recipes to the target node.  It also checks for any required updates and applies them, if applicable. 
   ```bash
   knife ssh 'name:lin2' 'sudo chef-client' -x ubuntu
   ```
   You should see similar to the following in the output:
   ```bash
   hostname Chef Infra Client, version 17.10.0
   hostname Patents: https://www.chef.io/patents
   hostname Infra Phase starting
   hostname Resolving cookbooks for run list: ["auditd::default"]
   hostname Synchronizing cookbooks:
   hostname   - auditd (2.4.0)
   hostname Installing cookbook gem dependencies:
   hostname Compiling cookbooks...
   hostname Loading Chef InSpec profile files:
   hostname Loading Chef InSpec input files:
   hostname Loading Chef InSpec waiver files:
   hostname Converging 2 resources
   hostname Recipe: auditd::default
   hostname   * apt_package[auditd] action install
   hostname     - install version 1:3.0.7-1build1 of package auditd
   hostname   * service[auditd] action enable (up to date)
   ```
   If you see the output listed above, nice job!  There are a lot of cookbooks already created and shared that you can use via the Chef Supermarket.  You can also create your own cookbooks and apply them to your fleet of managed nodes.  In the next example, perhaps we will look at doing this for Windows.


### Build and Apply Windows Cookbooks
Some description here.
1. step on linux1
   ```bash
   cd ~/chef-repo/cookbooks
   chef generate cookbook windows_audit_policy
   ```
2. Edit the ~/chef-repo/cookbooks/windows_audit_policy/recipes/default.rb file.  You will be adding a new default recipe which will include a powershell script that adds Audit Policy configuration systems:
   ```bash
   vi ~/chef-repo/cookbooks/windows_audit_policy/recipes/default.rb
   ```

   Copy and paste the following and save the file after you are done:
   ```bash
   # recipes/default.rb
   powershell_script 'Configure Audit Policy and Process Creation Auditing' do
     code <<-EOH
       # Enable advanced audit policy
       auditpol /set /subcategory:"Security System Extension" /success:enable /failure:enable
       auditpol /set /subcategory:"System Integrity" /success:enable /failure:enable
       auditpol /set /subcategory:"Logon" /success:enable /failure:enable
       auditpol /set /subcategory:"Logoff" /success:enable /failure:enable
       auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable
       auditpol /set /subcategory:"Special Logon" /success:enable /failure:enable
       auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable

       # Enable command line process auditing
       $regPath = "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\\Audit"
       if (-not (Test-Path $regPath)) {
         New-Item -Path $regPath -Force | Out-Null
       }
       Set-ItemProperty -Path $regPath -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord

       # Enable PowerShell script block logging
       $regPath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\ScriptBlockLogging"
       if (-not (Test-Path $regPath)) {
         New-Item -Path $regPath -Force | Out-Null
       }
       Set-ItemProperty -Path $regPath -Name "EnableScriptBlockLogging" -Value 1 -Type DWord

       # Configure Windows Event Log sizes
       Limit-EventLog -LogName Application -MaximumSize 1GB
       Limit-EventLog -LogName Security -MaximumSize 1GB
       Limit-EventLog -LogName System -MaximumSize 1GB

       Write-Host "Audit policies and logging have been configured."
     EOH
   end
   ```
4.  Change into ```cookbooks``` directory and upload this new cookbook, ```windows_audit_policy```, to the Chef Server:
    ```bash
    cd ~/chef-repo/cookbooks
    knife cookbook upload windows_audit_policy
    ```

    you will see:
    ```bash
    Uploading windows_audit_policy [0.1.0]
    Uploaded 1 cookbook.
    ```
5.  Add to the run list of win1:
    ```bash
    knife node run_list add win1 'recipe[windows_audit_policy]'
    ```
    You should see:
    ```bash
    win1:
      run_list: recipe[windows_audit_policy]
    ```
6. Push changes to windows1:
   ```bash
   knife winrm 'win1.acme.com' 'chef-client' --winrm-user RTCAdmin --winrm-password 'Proud-lion-2024!' --manual-list
   ```


   


