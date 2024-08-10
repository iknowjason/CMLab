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

1. RDP into the **win1** system using the credentials and public IP address from ```terraform output```.  Use the local Administrator username and password.  After you RDP in, navigate the following file and make sure that the system has finished bootstrapping:
   ```bash
   C:\terraform\user_data.log
   ```

   When the system has finished bootstrapping, you will see this line:
   ```bash
   End of bootstrap powershell script
   ```

   This is important, because the DNS entries are added to the Windows hosts file that are important to all of the labs, allowing name resolution between win1 and win2 systems.

2. Write the configuration script in Powershell.  Open up **Windows Powershell ISE**.  Once the application has opened, select **File** in the menu followed by **New**.

   Copy and paste the following powershell into the top code editor area:
   
   ```bash
   Configuration AuditPolicyConfig {
     Node "win1" {
         Registry LogonAudit {
            Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Audit\AuditPolicy\Subsystem"
            ValueName = "Logon"
            ValueType = "Dword"
            ValueData = "3"
            Ensure = "Present"
         }
         Registry ObjectAccessAudit {
            Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Audit\AuditPolicy\Subsystem"
            ValueName = "File System"
            ValueType = "Dword"
            ValueData = "3"
            Ensure = "Present"
         }
         Registry ProcessCreationAudit {
            Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa"
            ValueName = "AuditProcessCreation"
            ValueType = "Dword"
            ValueData = "1"
            Ensure = "Present"
         }
      }
   }
   AuditPolicyConfig -OutputPath "C:\DSC"
   ```

   Save the file using Powershell ISE as:
   ```bash
   AuditPolicyConfig.ps1
   ```

3. Generate the MOF file.  Run the configuration script you just created to generate the MOF file.  You can run this using Powershell ISE by the blue powershell session that is below.  You might need to change into the default directory where the file was saved to by typing:

   ```bash
   cd Documents
   ```
   
   Run the script:
   ```bash
   .\AuditPolicyConfig.ps1
   ```

   This will create a ```win1.mof``` file in the ```C:\DSC``` directory.
   



## Lab 2:  DSC push between systems

## Lab 3:  DSC pull between systems
