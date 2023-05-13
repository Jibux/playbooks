# Ansible playbook to install my home services

## Jibux services

See [README.md](roles/jibux_svc/README.md).

```bash
ansible-playbook jibux_svc.yml -l jibux-taf -D
```

## Raspberry server - should be deprecated/replaced by jibux_svc

* To play the first time do:

```bash
ansible-playbook -c ssh all.yml --extra-vars "first_install=yes"
```

* Otherwise just do:
```bash
ansible-playbook -c ssh all.yml
```

