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

### Chef Master Server

In this section, you'll set up the Chef Server on your Linux master server.

1. Install Chef Server on Linux Master (lin1):
   ```bash
   sudo dpkg -i chef-server-core_15.1.7-1_amd64.deb
   ``` 
2. 
Start the Chef Server
```bash
sudo chef-server-ctl reconfigure
```
