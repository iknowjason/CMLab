<powershell>
# Beginning of bootstrap script
# This script bootstraps the Windows system and runs
# extra scripts downloaded from the s3 bucket

$stagingdir = "C:\terraform"

if (-not (Test-Path -Path $stagingdir)) {
    New-Item -ItemType Directory -Path $stagingdir
    Write-Host "Directory created: $stagingdir"
} else {
    Write-Host "Directory already exists: $stagingdir"
}

# Set logfile and function for writing logfile
$logfile = "C:\Terraform\bootstrap_log.log"
Function lwrite {
    Param ([string]$logstring)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logstring = "$timestamp $logstring"
    Add-Content $logfile -value $logstring
}

lwrite("Starting bootstrap powershell script")

# add a local user and add them to Administrators
$admin_username = "${admin_username}"
$admin_password = "${admin_password}"
$op = Get-LocalUser | Where-Object {$_.Name -eq $admin_username}
if ( -not $op ) {
  $secure_string = ConvertTo-SecureString $admin_password -AsPlainText -Force
  New-LocalUser $admin_username -Password $secure_string
  Add-LocalGroupMember -Group "Administrators" -Member $admin_username
  lwrite("User created and added to the Administrators group: $admin_username")
} else {
  lwrite("User already exists: $admin_username")
}

# add an Ansible local user and add them to Administrators
$ansible_username = "${ansible_username}"
$ansible_password = "${ansible_password}"
$op = Get-LocalUser | Where-Object {$_.Name -eq $ansible_username}
if ( -not $op ) {
  $secure_string = ConvertTo-SecureString $ansible_password -AsPlainText -Force
  New-LocalUser $ansible_username -Password $secure_string
  Add-LocalGroupMember -Group "Administrators" -Member $ansible_username
  lwrite("User created and added to the Administrators group: $ansible_username")
} else {
  lwrite("User already exists: $ansible_username")
}

# Set hostname
lwrite("Checking to rename computer to ${hostname}")

$current = $env:COMPUTERNAME

if ($current -ne "${hostname}") {
    Rename-Computer -NewName "${hostname}" -Force
    lwrite("Renaming computer and reboot")
    exit 3010
} else {
    lwrite("Hostname already set correctly")
}

#WinRM Config
$ComputerName = "${hostname}"
$RemoteHostName = "${hostname}" + "." + "${ad_domain}"
lwrite("ComputerName: $ComputerName")
lwrite("RemoteHostName: $RemoteHostName")

# Setup WinRM remoting
### Force Enabling WinRM and skip profile check
lwrite("Enabling PSRemoting SkipNetworkProfileCheck")
Enable-PSRemoting -SkipNetworkProfileCheck -Force

lwrite("Set Execution Policy Unrestricted")
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

$Cert = New-SelfSignedCertificate -DnsName $RemoteHostName, $ComputerName `
    -CertStoreLocation "cert:\LocalMachine\My" `
    -FriendlyName "Test WinRM Cert"

$Cert | Out-String

$Thumbprint = $Cert.Thumbprint

lwrite("Enable HTTPS in WinRM")
$WinRmHttps = "@{Hostname=`"$RemoteHostName`"; CertificateThumbprint=`"$Thumbprint`"}"
winrm create winrm/config/Listener?Address=*+Transport=HTTPS $WinRmHttps

lwrite("Set Basic Auth in WinRM")
$WinRmBasic = "@{Basic=`"true`"}"
winrm set winrm/config/service/Auth $WinRmBasic

lwrite("Open Firewall Ports")
netsh advfirewall firewall add rule name="Windows Remote Management (HTTP-In)" dir=in action=allow protocol=TCP localport=5985
netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=5986

### Force Enabling WinRM and skip profile check
Enable-PSRemoting -SkipNetworkProfileCheck -Force

# Set Trusted Hosts * for WinRM HTTPS
Set-Item -Force wsman:\localhost\client\trustedhosts *
# End WinRM Config

lwrite("Install chocolatey")
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))


lwrite("Installing puppet agent")
lwrite("Downloading puppet agent")
iwr -Uri "https://downloads.puppetlabs.com/windows/puppet5/puppet-agent-x64-latest.msi" -Outfile "C:\terraform\puppet-agent-x64-latest.msi"
lwrite("Download complete")
lwrite("msiexec install of msi")
msiexec /qn /norestart /i "C:\terraform\puppet-agent-x64-latest.msi"

lwrite("Import Powershell DSC module")
Install-Module 'PSDscResources' -Verbose -Force

lwrite("Install Powershell Core")
iwr -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi" -Outfile "C:\terraform\Powershell-7.4.1-win-x64.msi"
msiexec.exe /package "C:\terraform\PowerShell-7.4.1-win-x64.msi" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1

lwrite("Installing DSCv3")
lwrite("Downloading DSCv3")
iwr -Uri "https://github.com/PowerShell/DSC/releases/download/v3.0.0-alpha.5/DSC-3.0.0-alpha.5-x86_64-pc-windows-msvc.zip" -Outfile "C:\terraform\DSC-3.0.0-alpha.5-x86_64-pc-windows-msvc.zip"
lwrite("Download complete")
cd C:\terraform
Expand-Archive .\DSC-3.0.0-alpha.5-x86_64-pc-windows-msvc.zip

lwrite("VSCode Install")
lwrite("Download VSCode")
cd C:\terraform
iwr -Uri "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" -Outfile "C:\terraform\VSCodeUserSetup-x64.exe"
lwrite("Download complete")
lwrite("Silent install")
Start-Process -Wait -FilePath "C:\terraform\VSCodeUserSetup-x64.exe" -ArgumentList "/VERYSILENT /MERGETASKS=!runcode"

# OpenSSH Server
lwrite("Install of OpenSSH Server")
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start OpenSSH service 
lwrite("Start SSH Server service")
Start-Service sshd

# Set startup automatic 
Set-Service -Name sshd -StartupType 'Automatic'

# Firewall rules confirmed 
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    lwrite("Firewall Rule 'OpenSSH-Server-In-TCP' does not exist")
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    lwrite("Firewall rule 'OpenSSH-Server-In-TCP' created")
}

# Change sshd_config file
$sshd_config_file = "C:\ProgramData\ssh\sshd_config"

# Allow PasswordAuthentication to yes
((Get-Content -path $sshd_config_file -raw) -replace '#PasswordAuthentication yes', 'PasswordAuthentication yes') | Set-Content -Path $sshd_config_file

# Change subsystem line for ssh
$line = Get-Content $sshd_config_file | Select-String "Subsystem	sftp" | Select-Object -ExpandProperty Line

if ($line -eq $null) {
  lwrite("Subsystem line not found")
} else {
  lwrite("Replacing subsystem line in sshd_config file")
  $content = Get-Content $sshd_config_file 
  $content | ForEach-Object {$_ -replace $line, "Subsystem powershell c:/progra~1/powershell/7/pwsh.exe -sshs -nologo"} | Set-Content $sshd_config_file 
}

# Set default shell to Windows Powershell 
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force

# Restart OpenSSH Service 
lwrite("Restart sshd service")
Restart-Service sshd

lwrite("Install chef-workstation")
cd C:\terraform
lwrite("Download chef-workstation")
iwr -Uri "https://packages.chef.io/files/stable/chef-workstation/24.2.1058/windows/2016/chef-workstation-24.2.1058-1-x64.msi" -OutFile "C:\terraform\chef-workstation-24.2.1058-1-x64.msi"
lwrite("Download complete")
lwrite("Install chef-workstation with msiexec")
#Install with Chef GUI
#msiexec /q /i C:\terraform\chef-workstation-24.2.1058-1-x64.msi ADDLOCAL=ALL
#Install unattended with CLI
msiexec /q /i C:\terraform\chef-workstation-24.2.1058-1-x64.msi ADDLOCAL=ALL REMOVE=ChefWSApp

lwrite("Very Silent install of VSCode")
# Note:  This is not working to auto install, so you can just type this in elevated powershell after booting
# Or just double-click on the VSCodeUserSetup-x64.exe
Start-Process -Wait -FilePath "C:\terraform\VSCodeUserSetup-x64.exe" -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode"

# adjust the hosts file
lwrite("Adding to hosts file")
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$entries = @"
${lin1_ip} puppet.${domain} puppet
${lin1_ip} chef.${domain} chef
${lin1_ip} salt.${domain} salt
${lin2_ip} lin2.${domain} lin2
${win1_ip} win1.${domain} win1
${win2_ip} win2.${domain} win2
"@

Add-Content -Path $hostsPath -Value $entries

lwrite("End of bootstrap powershell script")

</powershell>
<persist>true</persist>
