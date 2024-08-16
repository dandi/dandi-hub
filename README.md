# Dandihub

This Terraform blueprint creates a Kubernetes environment (EKS) and installs JupyterHub. Based on [AWS Data on EKS JupyterHub](https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub).

## Table of Contents

- [Prerequisites](#prerequisites)
- [AWS Cloud Configuration for Terraform](#aws-cloud-configuration-for-terraform)
  - [1. Create and Configure an S3 Bucket](#1-create-and-configure-an-s3-bucket)
  - [2. Set Up DynamoDB for State Locking](#2-set-up-dynamodb-for-state-locking)
  - [3. Set Up IAM Roles and Policies](#3-set-up-iam-roles-and-policies)
- [AWS CLI Configuration for Multiple Accounts and Environments](#aws-cli-configuration-for-multiple-accounts-and-environments)
  - [Step 1: Set Up AWS Credentials](#step-1-set-up-aws-credentials)
  - [Step 2: Set Up AWS Config](#step-2-set-up-aws-config)
- [Environment Variables](#environment-variables)
- [Variables File](#variables-file)
- [Github OAuth](#github-oauth)
- [Deployment](#deployment)
- [Cleanup](#cleanup)
- [Update](#update)
- [Route the Domain in Route 53](#route-the-domain-in-route-53)
- [Manual Takedown of Just the Hub](#manual-takedown-of-just-the-hub)
- [Adding Admins to EKS](#adding-admins-to-eks)
- [Adjusting Available Server Options](#adjusting-available-server-options)
- [Adjusting Available Nodes](#adjusting-available-nodes)
- [Adjusting Core Node](#adjusting-core-node)
- [Upgrading Kubernetes](#upgrading-kubernetes)
- [Kubernetes Layer Tour](#kubernetes-layer-tour)

## Prerequisites

This guide assumes that you have:
 - A registered domain
 - An AWS Certificate for the domain and subdomains
 - An AWS IAM account (Trust Policy to assume JupyerhubProvisioningRole, or Admin if Role has not
     been created).
 - Terraform >= 1.8.3 ([installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli))
 - kubectl >= 1.26.15 ([installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/))
 - yamllint >= 1.35.1 ([installation guide](https://yamllint.readthedocs.io/en/stable/quickstart.html#installing-yamllint)

## Directory Layout

The project directory is structured to separate environment-specific configurations from the main
Terraform configuration. This allows for easier management and scalability when dealing with
multiple environments. Each deployment is given its own directory in `envs/`.

## AWS Cloud Configuration for Terraform

This document explains how to set up the necessary AWS resources and configurations for using Terraform to provision JupyterHub.

### 1. Create and Configure an S3 Bucket for Terraform State Storage

1. **Create an S3 Bucket**:
    - Go to the S3 console in AWS.
    - Click "Create bucket".
    - Name the bucket `jupyterhub-terraform-state-bucket` (ensure the name is unique per AWS account).
    - Choose the region `us-east-2`.
    - Enable default encryption.
    - Create the bucket.

2. **Configure Terraform to Use the S3 Bucket**:
    - In the `envs/<deployment>` directory, create a file named `backend.tf` with the following content:

    ```hcl
    bucket         = "jupyterhub-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "jupyterhub-terraform-lock-table"
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
    - Choose `AWS service` and select `Custom trust policy`


2. **Set Up the Trust Policy**:
    - Edit the trust relationship for the `JupyterhubProvisioningRole` role to allow the necessary entities to assume the role. Copy and paste below:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::<account>:root"
            },
            "Action": "sts:AssumeRole",
              "Condition": {
                "StringEquals": {
                    "aws:PrincipalType": "User"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

3. **Create and attach inline policies**
    - From the `JupyterhubProvisioningRole` under the `permissions` tab, select `create inline policy`
    - From the `JSON` tab, create `terraform-jupyterhub-backend-policies` using the json in `.aws`
    - From the `JSON` tab, create `terraform-jupyterhub-provisioning-policies` using the json in `.aws`

4. **Set Maximum Session Duration**
    - 1 hour is usually sufficient, but will occassionally fail.
    - Recommend 4 hours.

### AWS CLI Configuration for Multiple Accounts and Environments

To manage multiple AWS accounts and environments, you need to configure your AWS CLI with the appropriate profiles. Follow the steps below to set up your `~/.aws/config` and `~/.aws/credentials` files.

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

## Environment Variables

Environment variables store secrets and hub deployment name:
  - `AWS_PROFILE`: The profile for the AWS account to deploy to, see AWS config above.
  - `TF_VAR_github_client_id`: See Github OAuth Step.
  - `TF_VAR_github_client_secret`: See Github OAuth Step.
  - `TF_VAR_aws_certificate_arn`: See Create Cert Step.
  - `TF_VAR_danditoken`: API token for the DANDI instance used for user auth.

## Variables File

The variables are set in a `terraform.tfvars` for each `env`, ie `envs/dandi/terraform.tfvars`

- `name`: (optional, defaults to jupyerhub-on-eks)
- `singleuser_image_repo`: Dockerhub repository containing custom jupyterhub image
- `singleuser_image_tag`: tag
- `jupyterhub_domain`: The domain to host the jupyterhub landing page: (ie "hub.dandiarchive.org")
- `dandi_api_domain`: The domain that hosts the DANDI API with list of registered users
- `region`: Cloud vendor region (ie us-west-1)

WARNING: If changing `region` it must be changed both in the tfvars and in the `backend.tf`.

## Jupyterhub Configuration

JupyterHub is configured by merging two YAML files:

- `envs/shared/jupyterhub.yaml`
- `envs/$ENV/jupyterhub-overrides.yaml`

Env Minimum Requirements:

- hub.config.Authenticator.admin_users

This template is configuration for the jupyterhub helmchart [administrator guide for jupyerhub](https://z2jh.jupyter.org/en/stable/administrator/index.html).

The `jupyterhub.yaml` and `jupyterhub-overrides.yaml` can use `${terraform.templating.syntax}`
with values that are explicitly passed to the `jupyterhub_helm_config` template object
in `addons.tf`

The original [AWS Jupyterhub Example Blueprint docs](https://awslabs.github.io/data-on-eks/docs/blueprints/ai-ml/jupyterhub) may be helpful.

**Merge Strategy**:

- Additive: New fields are added.
- Clobbering: Existing values, including lists, are overwritten.

*example*

Base Configuration (envs/shared/jupyterhub.yaml)
```yaml
singleuser:
  some_key: some_val
  profileList:
    - item1
    - item2
```
Override Configuration (envs/$ENV/jupyterhub-overrides.yaml)
```yaml
singleuser:
  new_key: new_val
  profileList:
    - item3
```
Resulting Configuration
```yaml
singleuser:
  some_key: some_val
  new_key: new_val
  profileList:
    - item3
```


## Github OAuth

1. Open the GitHub OAuth App Wizard: GitHub settings -> Developer settings -> OAuth Apps.
   For dandihub, this is owned by a bot GitHub user account (e.g. dandibot).
2. Create App:
  - `Homepage URL` to the site root (e.g., `https://hub.dandiarchive.org`). Must be the same as jupyterhub_domain.
  - `Authorization callback URL` must be <jupyterhub_domain>/hub/oauth_callback.


## Deployment

**Execute install script**

`./install.sh <env>`

### Common deployment issues

**Timeouts and race conditions**
`Context Deadline Exceeded`: This just happens sometimes, usually resolved by rerunning the install script.

**Key Management Service Duplicate Resource**
This is usually caused by a problem with tfstate, it can't be immediately fixed because Amazon Key Management Service objects have a 7-day waiting period to delete.
The workaround is to change/add a `name` var to the tfvars (ie `jupyerhub-on-eks-2`)
Mark the existing KMS for deletion. You will need to assume the AWS IAM Role used to create it (ie `JupyterhubProvisioningRole`)

**Show config of current jupyterhub deployment**

Warning: This is the fully templated jupyterhub. Be careful not to expose secrets.
`helm get values jupyterhub -n jupyterhub`

### Connect Jupyterhub proxy to DNS

**Route the Domain in Route 53**

In Route 53 -> Hosted Zones -> <jupyterhub_domain> create an `A` type Record that routes to an
`Alias to Network Load Balancer`. Set the region and the EXTERNAL_IP of the `service/proxy-public`
Kubernetes object in the `jupyterhub` namespace.

This will need to be redone each time the `proxy-public` service is recreated (occurs during
`./cleanup.sh`).

## Update

Changes to variables or the template configuration usually are updated idempotently by running
`./install.sh <env>` **without the need to cleanup prior**.

## Cleanup

Prior to cleanup ensure that kubectl and helm are using the appropriate `kubeconfig`.
(`<name>` is the value `name` `in terraform.tfvars`.)

```
aws eks --region us-east-2 update-kubeconfig --name <name-prefix>
```
Cleanup requires the same variables and is run `./cleanup.sh <env>`.

NOTE: Occasionally the Kubernetes namespace fails to delete.

WARNING: Sometimes AWS VPCs are left up due to an upstream Terraform race condition and must be deleted by hand (including hand-deleting each nested object).

## Take Down Jupyterhub, leave up EKS

`terraform destroy -target=module.eks_data_addons.helm_release.jupyterhub -auto-approve` will
destroy all the jupyterhub assets, but will leave the EKS and VPC infrastructure intact.

## Adding Admins to EKS

Add the user/IAM to `mapUsers`.

```sh
kubectl edit configMap -n kube-system aws-auth
```

```yaml
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

## Adjusting Available Server Options

These are the options for user-facing machines that run as a pod on the node, and they are configured in `profileList` in `dandihub.yaml`.

Each profile can have multiple user-facing `profile_options` including `images`.

## Adjusting Available Nodes

These are the EKS machines that may run underneath one or more user-hub pods, and they are configured via Karpenter.

The node pools are configured in `addons.tf` with `karpenter-resources-*` objects.

## Adjusting Core Node

The configuration for the machines that run the autoscaling and monitoring layer is `eks_managed_node_groups` in `main.tf`.

## Upgrading Kubernetes

**⚠️ Warning:** Do not click the "Upgrade k8s" button in AWS Console.
When AWS manages upgrade it will go slowly and upgrade components carefully to avoid downtime.
When the upgrade is finished however, on the next run tfstate will not match and terraform will destroy the
cluster and bring it back up.

Kubernetes version is controlled via the terraform variable `eks_cluster_version`, the default is
in `versions.tf`, but each deployment can specify their own value in their `tfvars`.

## Kubernetes Layer Tour

### Jupyterhub Namespace

These objects are created by z2jh.

https://z2jh.jupyter.org/en/stable/

```sh
kubectl get all -n jupyterhub
```

Notable objects:

  - `pod/hub-23490-393`: Jupyterhub server and culler pod
  - `pod/jupyter-<github_username>`: User pod
  - `pod/user-scheduler-5d8b9567-26x6j`: Creates user pods. There are two; one has been elected leader, with one backup.
  - `service/proxy-public`: LoadBalancer, External IP must be connected to DNS (Route 53)

### Karpenter Namespace

`pod/karpenter-75fc7784bf-cjddv` responds similarly to the cluster-autoscaler.

When Jupyterhub user pods are scheduled and sufficient Nodes are not available, Karpenter creates a NodeClaim and then interacts with AWS to spin up machines.

- `nodeclaims`: Create a node from one of the Karpenter Nodepools. (This is where spot/on-demand is configured for user-pods).
