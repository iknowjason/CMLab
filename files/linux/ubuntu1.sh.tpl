#!/bin/bash
# Custom bootstrap script for Ubuntu Linux

set -e
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# any important variables
HOME=/home/ubuntu
echo "Setting HOME to $HOME"

echo "Start bootstrap script for Linux ${linux_os}"
echo "Installing initial packages"
sudo apt-get update -y
sudo apt-get install net-tools -y
sudo apt-get install unzip -y
sudo apt-get install pipx -y
sudo apt-get install python3-pip -y
sudo apt-get install sshpass -y

# Allow password authentication via ssh
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart ssh


# Golang 1.22 install
echo "export GOROOT=/usr/local/go" >> /home/ubuntu/.profile
echo "export GOPATH=$HOME/go" >> /home/ubuntu/.profile 
echo "export PATH=$PATH:/usr/local/go/bin" >> /home/ubuntu/.profile
echo "export GOCACHE=/home/ubuntu/go/cache" >> /home/ubuntu/.profile
echo "export HOME=/home/ubuntu" >> /home/ubuntu/.profile
echo "export HOME=/home/ubuntu" >> /home/ubuntu/.bashrc
source /home/ubuntu/.profile
source /home/ubuntu/.bashrc

# Ansible Install
echo "Installing ansible"
#apt install ansible -y
#pipx install --include-deps ansible
#pipx install --include-deps pywinrm
#pipx ensurepath
pip install ansible
pip install pywinrm 
echo "export PATH=$PATH:/home/ubuntu/.local/bin" >> /home/ubuntu/.profile
export PATH=$PATH:/home/ubuntu/.local/bin

# Chef Install
cd /home/ubuntu

echo "Downloading Chef Server"
wget https://packages.chef.io/files/stable/chef-server/15.1.7/ubuntu/20.04/chef-server-core_15.1.7-1_amd64.deb
echo "Installing Chef workstation"
echo "Downloading Chef Workstation"
wget https://packages.chef.io/files/stable/chef-workstation/22.10.1013/ubuntu/20.04/chef-workstation_22.10.1013-1_amd64.deb
dpkg -i chef-workstation_*.deb

# Puppet Install
echo "Installing Puppet Server"
wget http://apt.puppet.com/puppet-release-jammy.deb
dpkg -i puppet-release-jammy.deb
apt-get update -y
apt-get install puppetserver -y 
systemctl start puppetserver

# Install DSCv3
echo "Installing DSCv3"
cd /home/ubuntu
mkdir /home/ubuntu/dsc 
cd /home/ubuntu/dsc
wget https://github.com/PowerShell/DSC/releases/download/v3.0.0-preview.8/DSC-3.0.0-preview.8-x86_64-unknown-linux-gnu.tar.gz
gzip -d DSC-3.0.0-preview.8-x86_64-unknown-linux-gnu.tar.gz 
tar xvf DSC-3.0.0-preview.8-x86_64-unknown-linux-gnu.tar
sudo wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl-dev_1.1.1f-1ubuntu2.23_amd64.deb
sudo wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.23_amd64.deb
dpkg -i libssl1.1_1.1.1f-1ubuntu2.23_amd64.deb 
dpkg -i libssl-dev_1.1.1f-1ubuntu2.23_amd64.deb
echo "export PATH=$PATH:/home/ubuntu/dsc" >> /home/ubuntu/.profile

# Download ansible linux zip file
echo "Get ansible linux zip file"
file="${ansible_linux_zip}"
object_url="https://${s3_bucket}.s3.${region}.amazonaws.com/$file"
echo "Downloading s3 object url: $object_url"
for i in {1..5}
do
    echo "Download attempt: $i"
    curl "$object_url" -o /home/ubuntu/${ansible_linux_zip}

    if [ $? -eq 0 ]; then
        echo "Download successful."
        break
    else
        echo "Download failed. Retrying..."
    fi
done

# unzip
echo "unzip the ansible linux zip"
cd /home/ubuntu
mkdir ansible
mv ${ansible_linux_zip} ansible/.
cd ansible
unzip ${ansible_linux_zip}

# Get Brian Olson's awesome ansible-live-response lab
echo "git clone ansible-live-response repo"
git clone https://github.com/brian-olson/ansible-live-response
cp lamp.yml ansible-live-response/.
cp DFIR-triage.yml ansible-live-response/.
cp DFIR-respond.yml ansible-live-response/.
cp linhosts ansible-live-response/.

# Get Windows 2022 Server CIS Benchmark hardening Ansible Playbook 
echo "git clone ansible-lockdown for WS2022 repo"
git clone https://github.com/ansible-lockdown/Windows-2022-CIS.git 
cp winhosts Windows-2022-CIS/.

# Adding /etc/hosts
echo "Adding /etc/hosts for default domain"
echo "${lin1_ip} puppet.${domain} puppet" >> /etc/hosts
echo "${lin1_ip} chef.${domain} chef" >> /etc/hosts
echo "${lin1_ip} salt.${domain} salt" >> /etc/hosts
echo "${lin2_ip} lin2.${domain} lin2" >> /etc/hosts
echo "${win1_ip} win1.${domain} win1" >> /etc/hosts
echo "${win2_ip} win2.${domain} win2" >> /etc/hosts

# SaltStack bootstrap script
echo "Installing Salt bootrap for master and minion"
curl -o bootstrap-salt.sh -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh
chmod +x bootstrap-salt.sh
echo "Installing both master and minion services"
# Seems to be an issue with this script, build manually
#./bootstrap-salt.sh -M

echo "End of bootstrap script"

