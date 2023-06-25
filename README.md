# Ansible playbook to install my home services

## Jibux services

See [README.md](roles/jibux_svc/README.md).

```bash
ansible-playbook playbooks/jibux_svc.yml -l jibux-taf -D
```

## MEGA cli

See [README.md](roles/mega/README.md).

```bash
ansible-playbook playbooks/mega.yml -l jibux-taf -D
```

## Home server

```bash
ansible-playbook playbooks/home_server_all.yml -D
```

