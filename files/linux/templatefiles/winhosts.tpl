[windows]
${win1_host}
${win2_host}

[windows:vars]
ansible_user="${ansible_user}"
ansible_password="${ansible_pass}"
#ansible_port="5985"
ansible_connection="winrm"
#ansible_winrm_transport="basic"
ansible_winrm_server_cert_validation=ignore
