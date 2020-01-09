# DANDI Jupyter Hub

https://hub.dandiarchive.org

This has been based on [this blog post](https://mast-labs.stsci.io/2019/02/zero-to-jupyterhub-with-ansible)
and [this corresponding repo](https://github.com/spacetelescope/z2jh-aws-ansible).

### Steps to deploy DANDI hub

#### Manual steps
1. Create an https certificate using AWS cert manager.
  For attaching this to load balancers, it's free, and JupyterHub allows 
  proxy offloading to this certificate.
2. Create the GitHub App id/token. 
   We have it done through a bot github user account (dandibot).
3. Setup AWS CI instance with authorized roles. 
4. Install ansible locally and create a password for ansible to encrypt some of 
   the ansible variables.
   `openssl rand -hex 32 > ansible_password`
   This is used to encrypt some of the values such as github tokens, AWS 
   certificate ID using the following form. 
   `ansible-vault encrypt_string "string_to_encrypt"`
5. Update the variables and some yaml files.
   Specifically this involves: `group_vars/all`, `config.yaml.j2`, `github connect)

#### Deployment steps
1. ansible-playbook -i hosts z2jh.yml -v --vault-password-file ansible_password
2. ansible-playbook -i hosts apply_github_auth.yml -v --vault-password-file ansible_password

The deployment steps can be combined.

To use this repo for dandi deployment:

```bash
cd z2jh-aws-ansible
cp -r ../dandi-info/. .
ansible-playbook -i hosts z2jh.yml -v --vault-password-file ansible_password
ansible-playbook -i hosts apply_github_auth.yml -v --vault-password-file ansible_password
```

This will be automated using travis soon.