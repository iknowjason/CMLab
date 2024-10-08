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

   Do a quick ping test from win1 to win2.  Open up a cmd or pwsh prompt and type:
   ```
   ping win2
   ```

   You should see name resolution working, but firewall will block ping.  This is important, because the host entries are added to the Windows hosts file that are important to all of the labs, allowing name resolution between win1 and win2 systems.

1. Write the configuration script in Powershell.  Open up **Windows Powershell ISE** and **Run as Administrator** by right clicking on the GUI.  Once the application has opened, select **File** in the menu followed by **New**.

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

2. Generate the MOF file.  Run the configuration script you just created to generate the MOF file.  You can run this using Powershell ISE by the blue powershell session that is below.  You might need to change into the default directory where the file was saved.
   
   Run the script:
   ```bash
   .\AuditPolicyConfig.ps1
   ```

   This will create a ```win1.mof``` file in the ```C:\DSC``` directory and you should see output showing this artifact.  Nice job.  In the script you should see that the targetNode is listed as "win1".  When you use DSC, the target node name must match in order for DSC to apply the changes.

3. Apply the MOF file on the Target Node (win1).  You can now apply the MOF file to the target node using the powershell command:

   ```bash
   Start-DscConfiguration -Path "C:\DSC" -Wait -Verbose
   ```

   If you receive an error of **Access Denied**, this means you didnt' start Powershell with **Run as Administrator**.  If so, open up a new Powershell session and **Run as Administrator**.  Change into the directory where you saved the file and run the script again.

   YOu should see this output in the beginning and be able to track each of the three changes being applied by the Local Configuration Manager in the script:
   ```
   VERBOSE: Perform operation 'Invoke CimMethod' with following parameters, ''methodName' =                                SendConfigurationApply,'className' =    MSFT_DSCLocalConfigurationManager,'namespaceName' =                                root/Microsoft/Windows/DesiredStateConfiguration'.
   ```

   At the end of the run, you should  see similar to:
   ```
   VERBOSE: Operation 'Invoke CimMethod' complete.
   VERBOSE: Time taken for configuration job to complete is 4.007 seconds
   ```

   Nice work!  You have successfully created and applied a local DSC configuration to win1.
   

## Lab 2:  DSC push between systems
In this quick lab, you will push DSC changes from **win1** to **win2**.  This is a more common use case for development and debugging.  Not production, where you will use a DSC pull from a DSC server in the next lab.  Let's dive in.

1. On **win1**, ensure that you have already successfully completed lab 1.

2. RDP into **win2** which will be the DSC client receiving the push from **win1**.  Follow the previous instructions for RDP by looking at the output from ```terraform output``` and ensure that you use the local Administrator account.

3. Open up a ```Windows Powershell``` session and **Run as Administrator**.  Configure ```win2``` to accept DSC configurations by setting the LCM (Local Configuration Manager) mode to ApplyAndAutoCorrect or ApplyAndMonitor.  This can be done with the following command which can be copy and pasted into the powershell session:
   ```bash
   [DSCLocalConfigurationManager()] 
   configuration LCMConfig { 
	   Node "Win2" { 
		   Settings { 
			   RefreshMode = "Push" 
			   ConfigurationMode = "ApplyAndAutoCorrect" 
		   } 
	   } 
   } 
   LCMConfig -OutputPath "C:\DSC\LCMConfig" 
   Set-DscLocalConfigurationManager -Path "C:\DSC\LCMConfig"
   ```

   In the output area, you will see a directory of ``` Directory: C:\DSC\LCMConfig``` with a filename created of ```win2.meta.mof```.  Nice job.  The LCM on win2 is now ready to accept DSC configurations as **Push** from remote, authenticated sessions.

4. Generate and prepare the MOF file on **win1**.  Back on the **win1** RDP session, look at the previous lab file you had created, named ```win1.mof```.  YOu need to have a file in the ```C:\DSC``` directory called ```win2.mof``` that will be pushed to the remote system.  To do this, you have two options.  You can simply rename the previous file from ```win1.mof``` to ```win2.mof```.  Or you can change the Targetnode parameter in the script to be ```win2``` and run ```.\AuditPolicyConfig.ps1``` once again.  It will generate ```win2.mof```.  To make this easy, let's just rename ```win1.mof``` to be ```win2.mof```:
   
   ```bash
   Rename-Item -Path "C:\DSC\win1.mof" -NewName "Win2.mof"
   ```

5. Push the configuration from **win1** to **win2**.  Use the ```Start-DscConfiguration``` powershell cmdlet on **win1** to push the configuration to **win2**.  In the command, you pass a **ComputerName** parameter to specify that the configuration should be applied to the remote computer ```win2```.

   ```bash
   Start-DscConfiguration -Path "C:\DSC" -ComputerName "Win2" -Wait -Verbose
   ```

   You are able to track the output and see the configuration changes applied to the remote system with the ```-Verbose``` flag.  You now should have gained some knowledge on how to push DSC configurations to remote systems.  Nice job.  In the next section, we will setup a pull configuration and practice a lab with a more common production use case.
   

## Lab 3:  DSC pull between systems
In this next section, you will configure ```win1``` to be a pull server and set up ```win2``` to fetch and apply configuration changes from the pull server.  

1. Install the DSC Service Feature.  This is a Windows feature that needs to be insalled on ```win1```.

   ```bash
   Install-WindowsFeature -Name DSC-Service -IncludeManagementTools
   ```

   Install the xPSDesiredStateConfiguration module from the Powershell Gallery and follow the yes prompts to install it:
   ```
   ﻿Install-Module -Name xPSDesiredStateConfiguration -Repository PSGallery -Force
   ```

   Install the PSDesiredStateConfiguration module and follow the yes prompts to install it:
   ```bash
   ﻿Install-Module -Name PSDesiredStateConfiguration -Repository PSGallery -Force
   ```

2. Next, configure the DSC pull server on ```win1```.  Create a new powershell script to set up this service.  This script sets up one endpoint for pulling configurations (PSDSCPullServer) using cleartext HTTP transport.  As an additional challenge, you can set up a certificate and use HTTPS for additional security.  The pull server listens on port 8080 and is set to use unencrypted traffic by default (only for testing purposes).  The **registrationKey** is hard-coded in this example but you can generate a dynamic one.  It is used as a shared secret between pull server and clients, allowing the clients to register.  Copy and paste this into your powershell session as Administrator, or open up Powershell ISE and create a new script and run it interactively.
   ```bash
   $registrationKey = "8dd78714-b559-496b-8911-56554bc4bda5"

   configuration Sample_xDscWebServiceRegistration
   {
     param
     (
        [string[]]$NodeName = 'localhost',
        [string] $RegistrationKey
     )

   Import-DSCResource -ModuleName PSDesiredStateConfiguration
   Import-DSCResource -ModuleName xPSDesiredStateConfiguration

   Node $NodeName
   {
        WindowsFeature DSCServiceFeature
        {
            Ensure = "Present"
            Name   = "DSC-Service"
        }

   xDscWebService PSDSCPullServer
        {
            Ensure                  = "Present"
            EndpointName            = "PSDSCPullServer"
            Port                    = 8080
            PhysicalPath            = "$env:SystemDrive\inetpub\PSDSCPullServer"
            CertificateThumbPrint   = "AllowUnencryptedTraffic"
            ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            State                   = "Started"
            DependsOn               = "[WindowsFeature]DSCServiceFeature"
            RegistrationKeyPath     = "$env:PROGRAMFILES\WindowsPowerShell\DscService"
            AcceptSelfSignedCertificates = $true
            UseSecurityBestPractices     = $false
            Enable32BitAppOnWin64   = $false

        }

   File RegistrationKeyFile
        {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
     }
   }
   ```
3. On win1, open up a new powershell session as Administrator or use the Powershell ISE open a **New Script**.  Paste this code in and hit the green button in Powershell ISE.  This will apply the DSC configuration to the Location Configuration Manager by using the ```Start-DscConfiguration``` cmdlet:
   
   ```bash
   $registrationKey = "8dd78714-b559-496b-8911-56554bc4bda5"

   $sample_xDscWebServiceRegistrationSplat = @{
       RegistrationKey = $registrationKey
       OutputPath = 'C:\Configs\PullServer'
   }
   Sample_xDscWebServiceRegistration @sample_xDscWebServiceRegistrationSplat
   Start-DscConfiguration -Path c:\Configs\PullServer -Wait -Verbose
   ```

   You should seee some debug output showing succesful run of the configuration changes.  This will also add the RegistrationKey shared secret to a file used by the PullServer.

4. Still on **win1**, you need to generate the DSC Configurations that will be pulled from ```win1```.  In the previous lab you had created a mof file for applying a configuration.  In this step, we will create a new client configuration.  This DSC configuration will change or otherwise control the password policy on the clients.  Copy and paste this into a new Windows Powershell Administrator session or use Powershell ISE as Administrator to open a new script and run it:

   ```bash
   Configuration ClientConfig {

   Node "win2" {
      Script SetPasswordPolicy {
         SetScript = {
               secedit.exe /export /cfg C:\windows\temp\secpol.cfg
               $secpol = Get-Content -Path C:\windows\temp\secpol.cfg
               $secpol = $secpol -replace 'MinimumPasswordLength = .+', 'MinimumPasswordLength = 12'
               $secpol = $secpol -replace 'PasswordComplexity = .+', 'PasswordComplexity = 1'
               $secpol = $secpol -replace 'MaximumPasswordAge = .+', 'MaximumPasswordAge = 42'
               Set-Content -Path C:\windows\temp\secpol.cfg -Value $secpol -Force
                secedit.exe /configure /db C:\windows\temp\secpol.sdb /cfg C:\windows\temp\secpol.cfg /areas SECURITYPOLICY
           }
           TestScript = {
               $result = secedit.exe /export /cfg C:\windows\temp\secpol.cfg
               $secpol = Get-Content -Path C:\windows\temp\secpol.cfg
               $minLength = $secpol -match 'MinimumPasswordLength = 12'
               $complexity = $secpol -match 'PasswordComplexity = 1'
               $maxAge = $secpol -match 'MaximumPasswordAge = 42'
                return ($minLength -and $complexity -and $maxAge)
           }
           GetScript = { return $null }
          }
      }
   }
   ClientConfig -OutputPath "C:\DSC"
   ```

   YOu should see a file created with the name of ```win2.mof```.  In DSC, you can configure the Pull client to fetch a configuration with a ConfigurationId or a ConfigurationName.  For this lab, we will be using the ConfigurationName.  You will see shortly that we will be renaming this ```win2.mof``` to a file named ```ClientConfig.mof``` and copying it to a destination directory where the client will trigger a pull from.  Very nice!

5. On **win2** system:  next we need to configure the DSC pull client on **win2**.  Configure the Local Configuration Manager (LCM) on ```win2``` to pull its configuration from ```win1```.  Create a script to configure the LCM.  Copy and paste this code into a Windows Powershell session that is **Run as Administrator**, or run in Powershell ISE and create a new script:
   ```bash
   [DSCLocalConfigurationManager()]
   configuration PullClientConfigNames
   {
       Node localhost
       {
           Settings
           {
               RefreshMode = 'Pull'
               ConfigurationMode = 'ApplyOnly'
               RefreshFrequencyMins = 30
               RebootNodeIfNeeded = $true
           }
           ConfigurationRepositoryWeb win1
           {
               ServerURL = 'http://win1.example.local:8080/PSDSCPullServer.svc'
               RegistrationKey = '8dd78714-b559-496b-8911-56554bc4bda5'
               AllowUnsecureConnection = $true
               ConfigurationNames = @('ClientConfig')
           }
       }
   }
   PullClientConfigNames
   Set-DSCLocalConfigurationManager –ComputerName localhost –Path .\PullClientConfigNames –Verbose
   ```

   You should see some verbose output.  This sets up the Local Configuration Manager as a pull client pointing to the win1 system as seen by the ServerURL.  This registers the DSC client on win2 using the shared secret RegistrationKey.  It also knows from the **ConfigurationNames** parameter that it is looking for a remote file named ```ClientConfig``` to pull its updated configuration.  You should have seen the following message in the output and nice job!
   ```bash
   Registration of the Dsc Agent with the server http://win1.example.local:8080/PSDSCPullServer.svc was successful
   ```

6. Back on **win1**, we are very close to the finish line.  We simply need to copy the mof file to the target directory and update the checksum.  Then when the win2 client polls for an updated configuration, it knows from an updated checksum that it needs to pull a new configuration.  Run the following commands in an elevated powershell session. First, rename the previously created win2.mof to ClientConfig.mof:
    
   ```bash
   Rename-Item -Path C:\DSC\win2.mof -NewName "ClientConfig.mof"
   ```

   Next, copy the ClientConfig.mof to the destination DSC configuration directory that the client checks for its configuration with a pull:
   ```bash
   Copy-Item -Path "C:\DSC\ClientConfig.mof" -Destination "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
   ```

   Finally, add a DSC checksum so the changes will get picked up by the DSC client:
   ```bash
   New-Dscchecksum "C:\Program Files\WindowsPowershell\DscService\configuration\ClientConfig.mof"
   ```

7. Now for the final step of pulling the configuration from the DSC client!  On **win2** DSC client, return to the last powershell session you ran when you set up the PullClient configuration and run:

   ```bash
   Update-DscConfiguration -Wait -Verbose
   ```

   You should see the client pulling the configuration for password policy changes and applying them, as shown below:
   ```bash
   VERBOSE: [WIN2]:                            [] Applying the new configuration(s) pulled.
   VERBOSE: [WIN2]: LCM:  [ Start  Resource ]  [[Script]SetPasswordPolicy]
   VERBOSE: [WIN2]: LCM:  [ Start  Test     ]  [[Script]SetPasswordPolicy]
   VERBOSE: [WIN2]: LCM:  [ End    Test     ]  [[Script]SetPasswordPolicy]  in 0.6320 seconds.
   VERBOSE: [WIN2]: LCM:  [ Start  Set      ]  [[Script]SetPasswordPolicy]
   VERBOSE: [WIN2]:                            [[Script]SetPasswordPolicy] Performing the operation "Set-TargetResource" on target "Executing the SetScript with 
   the user supplied credential".
   VERBOSE: [WIN2]: LCM:  [ End    Set      ]  [[Script]SetPasswordPolicy]  in 0.6690 seconds.
   VERBOSE: [WIN2]: LCM:  [ End    Resource ]  [[Script]SetPasswordPolicy] 
   ```

   Nice work!  You have successfuly setup a pull server, pull client, and pulled a new configuration. For an added challenge, try to setup HTTPS encryption with certificates and apply a different configuration to the client.
      
   
