# Dandihub

This terraform blueprint creates a Kubernetes environment (EKS) and installs jupyterhub.
Based on https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub

## Prerequisites

This guide assumes that you have:
 - a registered domain
 - an AWS Cert for the domain and subdomains
 - AWS IAM account
 - terraform >= 1.8.3
 - kubectl >= 1.26.15

## AWS Cloud Configuration for Terraform

This document explains how to set up the necessary AWS resources and configurations for using Terraform to provision JupyterHub.

### 1. Create and Configure an S3 Bucket for Terraform State Storage

1. **Create an S3 Bucket**:
    - Go to the S3 console in AWS.
    - Click "Create bucket".
    - Name the bucket `jupyterhub-terraform-state-bucket` (ensure the name is unique per AWS account. ).
    - Choose the region `us-east-2`.
    - Enable default encryption
    - Create the bucket.

2. **Configure Terraform to Use the S3 Bucket**:
    - In your Terraform project directory, create a file named `backend.tf` with the following content:

    ```hcl
    terraform {
      backend "s3" {
        bucket         = "jupyterhub-terraform-state-bucket"
        key            = "terraform.tfstate"
        region         = "us-east-2"
        encrypt        = true
        dynamodb_table = "jupyterhub-terraform-lock-table"
      }
    }
    ```

### 2. Set Up DynamoDB for State Locking

1. **Create a DynamoDB Table**:
    - Go to the DynamoDB console in AWS.
    - Click "Create table".
    - Name the table `jupyterhub-terraform-lock-table`.
    - Set the primary key to `LockID` (String).
    - Create the table.

### 3. Set Up IAM Roles and Policies

1. **Create an IAM Role**:
    - Go to the IAM console in AWS.
    - Click "Roles" and then "Create role".
    - Choose `AWS service` and select `EC2` (or other relevant service).
    - Attach the following managed policies:
        - `AmazonS3FullAccess`
        - `AmazonDynamoDBFullAccess`
        - `AmazonEC2FullAccess`
        - `AmazonEKSClusterPolicy`
        - `CloudWatchLogsFullAccess`
        - `IAMFullAccess`
        - `SecretsManagerReadWrite`
    - Name the role `JupyterhubProvisioningRole`.

2. **Attach Inline Policy for Additional Permissions**:
    - Create a JSON policy document with the necessary actions and attach it to the role as an inline policy. Below is an example policy:

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ec2:RunInstances",
            "ec2:CreateLaunchTemplate",
            "ec2:DeleteLaunchTemplate",
            "ec2:DescribeLaunchTemplates",
            "ec2:CreateLaunchTemplateVersion",
            "ec2:DeleteLaunchTemplateVersions",
            "ec2:DescribeLaunchTemplateVersions",
            "iam:PassRole",
            "elasticfilesystem:DescribeLifecycleConfiguration",
            "elasticfilesystem:PutLifecycleConfiguration",
            "elasticfilesystem:DeleteLifecycleConfiguration",
            "secretsmanager:PutSecretValue",
            "secretsmanager:UpdateSecretVersionStage",
            "elasticfilesystem:CreateMountTarget",
            "elasticfilesystem:DeleteMountTarget",
            "elasticfilesystem:DescribeMountTargets",
            "elasticfilesystem:ModifyMountTargetSecurityGroups",
            "elasticfilesystem:DescribeMountTargetSecurityGroups"
          ],
          "Resource": "*"
        }
      ]
    }
    ```
3. **Set Up the Trust Policy**:
    - Edit the trust relationship for the `JupyterhubProvisioningRole` role to allow the necessary entities to assume the role. The trust policy might look something like this:

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    ```

 
### AWS CLI Configuration for Multiple Accounts and Environments

To manage multiple AWS accounts and environments, you need to configure your AWS CLI with the appropriate profiles. Follow the steps below to set up your `.aws/config` and `.aws/credentials` files.

#### Step 1: Set Up AWS Credentials

1. **Obtain Your AWS Access Keys**:
   - Log in to the AWS Management Console.
   - Navigate to the **IAM** service.
   - Select **Users** and click on your user name.
   - Go to the **Security credentials** tab.
   - Click **Create access key** and note down the **Access key ID** and **Secret access key**.

2. **Edit Your `.aws/credentials` File**:
   - Open the `.aws/credentials` file in your home directory. If it doesn't exist, create it.
   - Add your access keys for each profile:

    ```ini
    [mcgovern]
    aws_access_key_id = YOUR_MCGOVERN_ACCESS_KEY_ID
    aws_secret_access_key = YOUR_MCGOVERN_SECRET_ACCESS_KEY

    [bican]
    aws_access_key_id = YOUR_BICAN_ACCESS_KEY_ID
    aws_secret_access_key = YOUR_BICAN_SECRET_ACCESS_KEY
    ```

#### Step 2: Set Up AWS Config

1. **Obtain Your Role ARN**:
   - Log in to the AWS Management Console.
   - Navigate to the **IAM** service.
   - Select **Roles** and find the role you will assume (e.g., `JupyterhubProvisioningRole`).
   - Note down the **Role ARN**.

2. **Edit Your `.aws/config` File**:
   - Open the `.aws/config` file in your home directory. If it doesn't exist, create it.
   - Add the region, role ARN, and source profile for each environment. Here’s an example:

    ```ini
    [profile mcgovern]
    region = us-east-2
    role_arn = arn:aws:iam::MCGOVERN_ACCOUNT_ID:role/JupyterhubProvisioningRole
    source_profile = mcgovern

    [profile bican]
    region = us-east-2
    role_arn = arn:aws:iam::BICAN_ACCOUNT_ID:role/JupyterhubProvisioningRole
    source_profile = bican
    ```

### Environment variables

Environment variables store secrets and hub deployment name:
  - `AWS_PROFILE` ie `mcgovern`, the profile for the AWS account to deploy to, see AWS config above
  - `TF_VAR_github_client_id`: See Github Oauth Step
  - `TF_VAR_github_client_secret` See Github Oauth Step
  - `TF_VAR_aws_certificate_arn` See Create Cert Step
  - `TF_VAR_danditoken` Api token for the dandi instance used for user auth

### Variables File

The variables are set in a `terraform.tfvars` for each `env`, ie `envs/dandi/terraform.tfvars`

 - name: (optional, defaults to jupyerhub-on-eks)
 - singleuser_image_repo: Dockerhub repository containing custom jupyterhub image
 - singleuser_image_tag: tag
 - jupyterhub_domain: The domain to host the jupytehub landing page: (ie "hub.dandiarchive.org")
 - dandi_api_domain: The domain that hosts the DANDI API with list of registered users
 - admin_users: List of adming github usernames (ie: ["github_username"])
 - region: Cloud vendor region (ie us-west-1)

WARNING: If changing `region` it must be changed both in the tfvars and in the `backend.tf`

### Github Oauth

1. Open the GitHub OAuth App Wizard: GitHub settings -> Developer settings -> Oauth Apps.
   For dandihub, this is owned by a bot GitHub user account (e.g. dandibot).
2. Create App:
  - `Homepage URL` to the site root (e.g., `https://hub.dandiarchive.org`). Must be the same as jupyterhub_domain
  - `Authorization callback URL` must be <jupyterhub_domain>/hub/oauth_callback


Most of the configuration is set in the template `helm/jupyterhub/dandihub.yaml` using the variables described here.
This template is configuration for the jupyterhub helmchart [administrator guide for jupyerhub](https://z2jh.jupyter.org/en/stable/administrator/index.html)


The original [AWS Jupyterhub Example Blueprint docs](https://awslabs.github.io/data-on-eks/docs/blueprints/ai-ml/jupyterhub) may be helpful.


### Installation

Preflight checklist:

 - Ensure the correct AWS profile is currently enabled, `echo $AWS_PROFILE` should match the desired entry in `~/.aws/credentials`
TODO(asmacdo) probably this needs to be added to JupyterhubProvisioningRole?
 - Make sure your IAM has permissions to run spot `aws iam create-service-linked-role --aws-service-name spot.amazonaws.com`


WARNING: Amazon Key Management Service objects have a 7 day waiting period to delete.
If there is a problem with tfstate and KMS fails due to a duplicate resource, the workaround is to change/add a `name` var to the tfvars (and mark the existing KMS for deletion).

`./install.sh <env>`

Occasionally there are timeout and race condition failures.
Usually these are resolved by simply retrying the install script.


### Cleanup

Cleanup requires the same variables and is run `./cleanup.sh <env>`

NOTE: Occasionally the kubernetes namespace fails to delete.

WARNING: Sometimes AWS VPCs are left up due to an upstream terraform race condition, and must be deleted by hand (including hand-deleting each nested object)

### Update

Changes to variables or the template configuration usually is updated idempotently by running
`./install.sh <env>` **without the need to cleanup prior**.

### Route the domain in Route 53

In Route 53 -> Hosted Zones -> <jupyterhub_domain> create an `A` type Record that routes to an
`Alias to Network Load Balancer`. Set the region, and the EXTERNAL_IP of the `service/proxy-public`
Kubernetes object in the `jupyterhub` namespace.

This will need to be redone each time the `proxy-public` service is recreated (occurs during
`./cleanup.sh`.

### Manual Takedown of just the hub

`terraform destroy -target=module.eks_data_addons.helm_release.jupyterhub -auto-approve` will
destroy all the jupyterhub assets, but will leave the EKS and VPC infrastructure intact.

### Adding admins to EKS

Add the user/iam to `mapUsers`

`$ kubectl edit configMap -n kube-system aws-auth`

```
apiVersion: v1
data:
  mapAccounts: <snip>
  mapRoles: <snip>
  mapUsers: |
    - groups:
      - system:masters
      userarn: arn:aws:iam::<acct_id>:user/<iam_username>
      username: <iam_username>
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
```

### Adjusting Available "Server Options"

These are the options for user-facing machines that run as a pod on the node and they are configured
in `profileList` in `dandihub.yaml`

Each profile can have multiple user-facing `profile_options` including `images`.

### Adjusting Available Nodes

These are the EKS machines that may run underneath one or more user-hub pods and they are configured via Karpenter.

The nodepools are configured in addons.tf with `karpenter-resources-*` objects.

### Adjusting Core Node

The configuration for the machines that run the autoscaling and montitoring layer is `eks_managed_node_groups` in `main.tf`

## Kubernetes Layer Tour

### Jupyterhub Namespace

These objects are created by z2jh.

https://z2jh.jupyter.org/en/stable/

`kubectl get all -n jupyterhub`

Notable objects:

  - `pod/hub-23490-393` Jupyterhub server and culler pod
  - `pod/jupyter-<github_username>`: User pod
  - `pod/user-scheduler-5d8b9567-26x6j`: Creates user pods. There are 2 one has been elected leader, with one backup.
  - `service/proxy-public`: LoadBalancer, External IP must be connected to DNS (Route 53)

### Karpenter Namespace

`pod/karpenter-75fc7784bf-cjddv` responds similarly to the cluster-autoscaler.

When Jupyterhub user pods are scheduled and sufficient Nodes are not available, Karpenter creates a NodeClaim and then interacts with AWS to spin up machines.

  `nodeclaims`: Create a node from one of the Karpenter Nodepools. (This is where spot/on demand is configured for user-pods)
