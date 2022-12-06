# DANDI JupyterHub

[Dandihub](https://hub.dandiarchive.org) provides a JupyterHub instance in the cloud to interact with the data stored in DANDI.

To use the hub, you will need to register for an account using the DANDI Web application. Note that Dandihub is not intended for significant computation, but provides a place to introspect Dandisets and to perform some analysis and visualization of data.

This information in this README is based on:
- [this blog post](https://mast-labs.stsci.io/2019/02/zero-to-jupyterhub-with-ansible)
 and [this corresponding repo](https://github.com/spacetelescope/z2jh-aws-ansible)
- [this blog post on autoscaling and spot pricing]( https://web.archive.org/web/20220127043940/https://www.replex.io/blog/the-ultimate-guide-to-deploying-kubernetes-cluster-on-aws-ec2-spot-instances-using-kops-and-eks)

**Note**: The original MAST setup is now significantly outdated.

## Deployment

Follow the steps below to deploy DANDI JupyterHub. 

**Note**: Be sure to perform all the operations in the same AWS zone 
that you will use in 
  step 5 in the `group_vars/all` file.

1. Create an https certificate for your domain using AWS cert manager.
  It's free to attach this certificate to load balancers, and JupyterHub also allows 
  proxy offloading to this certificate.

2. Create the GitHub OAuth App id/token: GitHub settings -> Developer settings -> Oauth Apps.
We have done this via a bot GitHub user account (e.g. dandibot).

3. Set up an AWS CI instance with these authorized roles
(see [this blog post](https://mast-labs.stsci.io/2019/02/zero-to-jupyterhub-with-ansible) for more details):
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
    - **install git in the CI instance**

4. Install ansible locally and create a password for ansible to encrypt some of 
   the ansible variables:

   `openssl rand -hex 32 > ansible_password`

   This is used to encrypt some of the values, such as GitHub tokens or the AWS 
   certificate ID, using the following form: 

   `ansible-vault encrypt_string --vault-password-file ansible_password`

   This will prompt for input.
   - Paste the string to encrypt without a carriage return
   - Hit Ctrl-d twice
   - Copy the encrypted string into the relevant section of `group_vars/all`

   Do this for:
   - client id
   - secret
   - certificate ARN (Amazon Resource Name)
   - dummy password (this is a string password you can use for testing without GitHub authentication)

5. Update the variables and some yaml files.

   Specifically, this involves:
   - `group_vars/all`
   - `config.yaml.j2`

   For the latter, this may involve adjusting authentication steps and profiles.

   Also note that the namespace has to be unique across any JH
   instances created with this setup. 

6. Create policy `ig-policy` and copy this ARN below:
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
7. Update `dandi-info/z2jh.yaml` to reflect the new policy ARN. Search for `ig-policy` in the file.

To use this z2jh-aws-ansible repo for Dandihub deployment, make sure it is populated (otherwise, 
do `git submodule update --init z2jh-aws-ansible` in the main repo before the `cd` step below):

```bash
cd z2jh-aws-ansible
cp -r ../dandi-info/. .
ansible-playbook -i hosts z2jh.yml -v --vault-password-file ../ansible_password
```

To tear down:

```bash
ansible-playbook -i hosts teardown.yml -v --vault-password-file ../ansible_password -t all-fixtures
```

To remove kubernetes without removing shared EFS:
```bash
ansible-playbook -i hosts teardown.yml -v --vault-password-file ../ansible_password -t kubernetes
```

## Pushing Changes to GitHub

- Inside `z2jh-aws-ansible`, do `rm -rf *` and then `git stash`. This will restore the submodule to its 
  pre-modification step.
- Step outside, commit changes, and either push or send a PR to Dandihub.

## `dandi-info` Files

For reference, the following files are located in the `dandi-info` subfolder:

- `group_vars/all`: ansible file contains variables for various templates
- `cluster-autoscaler-multi-asg.yaml.j2`: k8s cluster autoscaler spec
- `config.yaml.j2`: z2jh jupyterhub configuration
- `hosts`: ansible provides IP of control host
- `nodes[1-3].yaml.j2`: k8s node specs for on-demand nodes in multiple zones 
- `pod.yaml.j2`: k8s pod for introspecting shared storage
- `pv_efs.yaml.j2`: k8s persistent volume spec for EFS
- `pvc_efs.yaml.j2`: k8s persistent volume claim for EFS
- `spot-ig.yaml.j2`: k8s non-GPU spec for compute nodes
- `spot-ig-gpu.yaml.j2`: k8s GPU spec for compute nodes
- `storageclass.yaml.j2`: k8s EFS storageclass
- `teardown.yml`: ansible file for tearing down the cluster
- `z2jh.yml`: ansible file for starting up the cluster

## Resources

* To learn how to interact with the DANDI archive and for examples on how to use the DANDI Client in various use cases,
see [the handbook](https://www.dandiarchive.org/handbook/).

* To get help:
  - ask a question: https://github.com/dandi/helpdesk/discussions
  - file a feature request or bug report: https://github.com/dandi/helpdesk/issues/new/choose
  - contact the DANDI team: help@dandiarchive.org
