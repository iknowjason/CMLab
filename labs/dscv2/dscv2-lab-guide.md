# DSCv2 Configuration Management

## Introduction
Desired State Configuration (DSC) is a PowerShell-based configuration management system developed by Microsoft. It allows you to define and enforce the desired state of a system by declaring the configuration as code. DSC version 2 (DSCv2) is an enhanced version of the original DSC that provides improved performance, scalability, and additional features.
This lab guide will walk you through three DSC lab examples using two Windows systems.  

## Lab Environment
Your lab environment consists of two Linux systems:

- DSC server (win1)
- DSC client (win2)

## Lab 1:  DSC on single system
In this quick lab, we will build a desired state configuration on one system  (win1) and make the DSC changes locally.

1.  RDP into the **win1** system using the credentials and public IP address from ```terraform output```.  Use the local Administrator username and password.  After you RDP in, navigate the following file and make sure that the system has finished bootstrapping:
    ```bash
    C:\terraform\user_data.log
    ```

    When the system has finished bootstrapping, you will see this line:
    ```
    End of bootstrap powershell script
    ```

    This is important, because the DNS entries are added to the Windows hosts file that are important to all of the labs, allowing resolution between win1 and win2 systems.

## Lab 2:  DSC push between systems

## Lab 3:  DSC pull between systems
