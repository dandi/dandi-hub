# DANDI Jupyter Hub

https://hub.dandiarchive.org

This has been based on:
- [this blog post](https://mast-labs.stsci.io/2019/02/zero-to-jupyterhub-with-ansible)
 and [this corresponding repo](https://github.com/spacetelescope/z2jh-aws-ansible).
- [this blog post on autoscaling and spot pricing]( https://web.archive.org/web/20220127043940/https://www.replex.io/blog/the-ultimate-guide-to-deploying-kubernetes-cluster-on-aws-ec2-spot-instances-using-kops-and-eks)

Please note that the original MAST setup is now significantly outdated.

### Steps to deploy the hub

#### Manual steps

0. Make sure to do all the operations in the same AWS zone that you will use in 
  step 5 in the `group_vars/all` file.

1. Create an https certificate for your domain using AWS cert manager.
  For attaching this to load balancers, it's free, and JupyterHub allows 
  proxy offloading to this certificate.

2. Create the GitHub OAuth App id/token. Github settings -> Developer settings -> Oauth Apps
   We have it done through a bot github user account (e.g., dandibot).

3. Setup AWS CI instance with authorized roles. (see the blog post for details)
    - AmazonEC2FullAccess
    - AmazonSQSFullAccess
    - IAMFullAccess
    - AmazonS3FullAccess
    - AmazonVPCFullAccess
    - AmazonElasticFileSystemFullAccess
    - AmazonRoute53FullAccess
    - AmazonEventBridgeFullAccess

   and then:
    - add the public dns name to the hosts file
    - **also install git in the CI instance.**

4. Install ansible locally and create a password for ansible to encrypt some of 
   the ansible variables.

   `openssl rand -hex 32 > ansible_password`

   This is used to encrypt some of the values such as github tokens, AWS 
   certificate ID using the following form. 

   `ansible-vault encrypt_string --vault-password-file ansible_password`

   This will prompt for input.
   - Paste the string to encrypt without a carriage return
   - Hit Ctrl-d twice
   - Copy the encrypted string into the relevant section of `group_vars/all`

   Do this for:
   - client id
   - secret
   - certificate ARN
   - dummy password (this is a string password you can use for testing without Github authentication)

5. Update the variables and some yaml files.

   Specifically this involves:
   - `group_vars/all`
   - `config.yaml.j2`

   In the latter this may involve adjusting authentication steps and profiles.

   Also note that the namespace has to be unique across any JH
   instances created with this setup. 

6. create policy `ig-policy` and copy the ARN from
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:DescribeInstanceTypes"
            ],
            "Resource": "*"
        }
    ]
}
```
7. update `dandi-info/z2jh.yaml` to reflect new policy ARN. search for `ig-policy` in the file.

#### Deployment steps

To use this repo for DandiHub deployment (make sure the z2jh-aws-ansible is populated, otherwise
do `git submodule update --init z2jh-aws-ansible` in the main repo before the `cd` step below):

```bash
cd z2jh-aws-ansible
cp -r ../dandi-info/. .
ansible-playbook -i hosts z2jh.yml -v --vault-password-file ../ansible_password
```

To teardown

```bash
ansible-playbook -i hosts teardown.yml -v --vault-password-file ../ansible_password -t all-fixtures
```

To remove kubernetes without removing shared EFS:
```bash
ansible-playbook -i hosts teardown.yml -v --vault-password-file ../ansible_password -t kubernetes
```

#### Quirks before pushing changes to github.

- Inside `z2jh-aws-ansible` do `rm -rf *` and then `git stash`. This will restore the submodule to its pre-modification step.
- Step outside, commit changes, push to DandiHub or send a PR to DandiHub.

#### Files under dandi-info

- `group_vars/all`: ansible file contains variables for various templates
- `cluster-autoscaler-multi-asg.yaml.j2`: k8s cluster autoscaler spec
- `config.yaml.j2`: z2jh jupyterhub configuration
- `hosts`: ansible provides IP of control host
- `nodes[1-3].yaml.j2`: k8s node specs for on demand nodes in multiple zones 
- `pod.yaml.j2`: k8s pod for introspecting shared storage
- `pv_efs.yaml.j2`: k8s persistent volume spec for EFS
- `pvc_efs.yaml.j2`: k8s persistent volume claim for EFS
- `spot-ig.yaml.j2`: k8s non-GPU spec for compute nodes
- `spot-ig-gpu.yaml.j2`: k8s GPU spec for compute nodes
- `storageclass.yaml.j2`: k8s EFS storageclass
- `teardown.yml`: ansible file for tearing down the cluster
- `z2jh.yml`: ansible file for starting up the cluster
