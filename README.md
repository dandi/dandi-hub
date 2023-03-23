# DANDI JupyterHub

This repository spins up a Kubernetes cluster on AWS using
[`ansible`][ansible], [`boto`][boto] and [`kops`][kops], and then uses
the [`jupyterhub` helm chart][jupyter-helm] to deploy a JupyterHub
instance in the cluster.

This project is deployed at [Dandihub][dandihub] which a JupyterHub
instance in the cloud that allows users to interact with the data stored
in DANDI.

## Usage

To use the hub, you will need to register for an account using the DANDI
Web application (https://dandiarchive.org) using your GitHub account.

---
**NOTE:**
Note that Dandihub is not intended for significant
computation, but provides a place to introspect Dandisets and to
perform some analysis and visualization of data.

---

## Deployment

This information in this README is based on:
- [this blog post](https://mast-labs.stsci.io/2019/02/zero-to-jupyterhub-with-ansible)
 and [this corresponding repo](https://github.com/spacetelescope/z2jh-aws-ansible)
- [this blog post on autoscaling and spot pricing]( https://web.archive.org/web/20220127043940/https://www.replex.io/blog/the-ultimate-guide-to-deploying-kubernetes-cluster-on-aws-ec2-spot-instances-using-kops-and-eks)

**Note**: The original MAST setup is now significantly outdated.

Follow the steps below to deploy DANDI JupyterHub.

**Note**: Be sure to perform all the operations in the same AWS zone
that you will use in `group_vars/all` file. (US-east-2 Ohio)

1. Create an https certificate for your domain using AWS cert manager.
  It's free to attach this certificate to load balancers, and JupyterHub also allows
  proxy offloading to this certificate.

1. Create the GitHub OAuth App id/token: GitHub settings -> Developer settings -> Oauth Apps.
We have done this via a bot GitHub user account (e.g. dandibot). You
will need to set Homepage URL (e.g., `https://hub.dandiarchive.org`) and
the Authorization callback URL (e.g.
`https://hub.dandiarchive.org/hub/oauth_callback`). This can be set to a
subdomain, just be sure to set this to the same value as `ingress` in
`group_vars/all` and also set up the CNAME route via Route 53.

1. Set up an AWS CI instance with these authorized roles
(see [this blog post](https://mast-labs.stsci.io/2019/02/zero-to-jupyterhub-with-ansible) for more details):
    - AmazonEC2FullAccess
    - AmazonSQSFullAccess
    - IAMFullAccess
    - AmazonS3FullAccess
    - AmazonVPCFullAccess
    - AmazonElasticFileSystemFullAccess
    - AmazonRoute53FullAccess
    - AmazonEventBridgeFullAccess

1. Add the public dns name to the `hosts` file (This is an Ansible Inventory file.)

1. SSH into the ec2 instance (using the pem key downloaded in previous
   step) and **install git in the CI instance** `sudo yum install git -y`

1. Update the variables in `group_vars/all`

  1. Install ansible locally and create a password for ansible to encrypt some of
       the ansible variables:

       `openssl rand -hex 32 > ansible_password`

  1. Encrypt strings using ansible-vault

     `ansible-vault encrypt_string --vault-password-file ansible_password`

       This will prompt for input.
       - Paste the string to encrypt without a carriage return
       - Hit Ctrl-d twice
       - Copy the encrypted string into the relevant section of `group_vars/all`
       - NOTE: Use bash rather than a non-standard shell to prevent
           truncation.

    Required vault values:
       - github_client_id (From GH OAuth app)
       - github_client_secret (From GH OAuth app)
       - aws_certificate_arn (From aws certificate manager)
       - dummypass (a string password you can use for testing without GitHub authentication
             by uncommenting the relevant dummypass options in `config.yaml.j2`)
       - danditoken (used to authenticate github users against registered dandi users)

    1. Also note that `namespace` has to be unique across any JH
       instances created with this setup.

       1. Ensure `z2jh.yaml` uses the `ig-policy` in the file. (This
          is not necessary to change if there is already an instance of the
          policy in AWS. If you need to create `ig-policy` use the following:

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
                               "autoscaling:DescribeScalingActivities",
                               "autoscaling:DescribeTags",
                               "ec2:DescribeInstanceTypes",
                               "ec2:DescribeLaunchTemplateVersions"
                           ],
                           "Resource": ["*"]
                       },
                       {
                           "Effect": "Allow",
                           "Action": [
                               "autoscaling:SetDesiredCapacity",
                               "autoscaling:TerminateInstanceInAutoScalingGroup",
                               "ec2:DescribeImages",
                               "ec2:GetInstanceTypesFromInstanceRequirements",
                               "eks:DescribeNodegroup"
                           ],
                           "Resource": ["*"]
                       }
                   ]
               }
               ```

1. Run the playbook!

    `ansible-playbook -i hosts z2jh.yml -v --vault-password-file ansible_password`

1. To tear down:

    ```bash
    ansible-playbook -i hosts teardown.yml -v --vault-password-file ansible_password -t all-fixtures
    ```

To remove kubernetes without removing shared EFS:
```bash
ansible-playbook -i hosts teardown.yml -v --vault-password-file ansible_password -t kubernetes
```

## Pushing Changes to GitHub

- Inside `z2jh-aws-ansible`, do `rm -rf *` and then `git stash`. This will restore the submodule to its
  pre-modification step.
- Step outside, commit changes, and either push or send a PR to Dandihub.

## Files

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

[ansible]: https://docs.ansible.com/
[boto]: https://boto3.amazonaws.com/v1/documentation/api/latest/index.html
[dandihub]: https://hub.dandiarchive.org
[jupyter-helm]: https://hub.jupyter.org/helm-chart/
[kops]: https://kops.sigs.k8s.io/
