# DANDI Jupyter Hub

https://hub.dandiarchive.org

This has been based on:
- [this blog post](https://mast-labs.stsci.io/2019/02/zero-to-jupyterhub-with-ansible)
 and [this corresponding repo](https://github.com/spacetelescope/z2jh-aws-ansible).
- [this blog post on autoscaling and spot pricing](https://www.replex.io/blog/the-ultimate-guide-to-deploying-kubernetes-cluster-on-aws-ec2-spot-instances-using-kops-and-eks#walkthrough)

### Steps to deploy the hub

#### Manual steps
0. Make sure to do all the operations in the same AWS zone that you will use in 
  step 5 in the `group_vars/all` file.
1. Create an https certificate using AWS cert manager.
  For attaching this to load balancers, it's free, and JupyterHub allows 
  proxy offloading to this certificate.
2. Create the GitHub App id/token. 
   We have it done through a bot github user account (dandibot).
3. Setup AWS CI instance with authorized roles. (see the blog post for details)
    - AmazonEC2FullAccess
    - AmazonSQSFullAccess
    - IAMFullAccess
    - AmazonS3FullAccess
    - AmazonVPCFullAccess
    - AmazonElasticFileSystemFullAccess
    - AmazonRoute53FullAccess
    - AmazonEventBridgeFullAccess
   and then add the public dns name to the hosts file
   **also install git in the CI instance.**
4. Install ansible locally and create a password for ansible to encrypt some of 
   the ansible variables.
   `openssl rand -hex 32 > ansible_password`
   This is used to encrypt some of the values such as github tokens, AWS 
   certificate ID using the following form. 
   `ansible-vault encrypt_string "string_to_encrypt"`
5. Update the variables and some yaml files.
   Specifically this involves: `group_vars/all`, `config.yaml.j2`)
   Also note that the namespace has to be unique across any JH
   instances created with this setup. 
6. create policy
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
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*"
        }
    ]
}
```
7. update `z2jh.yaml` to reflect new policy arn.

#### Deployment steps
1. `ansible-playbook -i hosts z2jh.yml -v --vault-password-file ansible_password`


To use this repo for reprohub deployment:

```bash
cd z2jh-aws-ansible
cp -r ../dandi-info/. .
ansible-playbook -i hosts z2jh.yml -v --vault-password-file ansible_password
```

To teardown

```bash
ansible-playbook -i hosts teardown.yml -v --vault-password-file ansible_password -t all-fixtures
```

To remove kubernetes without removing shared EFS:
```bash
ansible-playbook -i hosts teardown.yml -v --vault-password-file ansible_password -t kubernetes
```

Notes: keeping EFS around 
- Removing VPC mount targets does not work.
- The instance roles associated with the hub also don't get removed.
Both have to be manually removed.

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