---
- hosts: windows
  vars:
    ansible_user: "${ansible_user}"
    ansible_password: "${ansible_pass}"
    ansible_port: 22
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    ansible_ssh_retries: 3
    ansible_shell_type: powershell
    ansible_become_method: runas
    ansible_become_user: "${ansible_user}"

  tasks:
    - name: test powershell
      win_shell: |
                get-host
      register: result_get_host

    - name: display result_get_host
      debug:
        var: result_get_host
