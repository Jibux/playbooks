<header>
Ansible playbook to install my home server
==========================================
</header>

<main>
Usage
=====
* To play the first time do:
```bash
ansible-playbook -c ssh setup_server.yml --extra-vars="first_install=True"
```
* Otherwise just do:
```bash
ansible-playbook -c ssh setup_server.yml
```
</main>

