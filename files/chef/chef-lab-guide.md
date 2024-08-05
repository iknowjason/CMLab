# Chef Configuration Management Lab Guide

## Introduction

This lab guide will walk you through setting up a Chef environment and performing various configuration management tasks. You'll learn how to use Chef to manage both Linux and Windows servers, automating the deployment of software and configurations.

## Lab Environment

Your lab environment consists of:

1. One Linux server (Chef Master)
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

### Chef Master Server

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
8. Next, you will need to generate a new self-signed TLS certificate that can be used to simulate proper DNS and certificate based authentication.  We will **cheat** here by using the /etc/hosts for DNS.  Get the private IP address of this system by typing ```ifconfig```.  Add an entry in the ```/etc/hosts``` file so that the chef workstation knife utility can manage the server.  This would show how a chef workstation administrator would be managing the chef installation to push changes from a secondary system.  For this lab, we are combining chef server and workstation into a single system.  In my example, my private IP address is ```10.100.20.143``` as determined by ```ifconfig``` or you can run ```terraform output``` to grab it.  Edit /etc/hosts to point an internal hosts entry for ```chef.acme.com``` pointing to this internal IP address, or replace it with whatever fqdn you desire.  For this example, we are using ```chef.acme.com``` to represent the chef server.
   ```bash
   sudo vi /etc/hosts
   ```
   My example shows:
   ```
   10.100.20.143 chef.example.com
   ```
