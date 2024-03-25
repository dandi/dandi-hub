# Dandihub

This terraform blueprint creates a Kubernetes environment (EKS) and installs jupyterhub.
Based on https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub

### Environment variables

Environment variables store secrets and hub deployment name:
  - `HUB_DEPLOYMENT_NAME`: (ie dandihub)
  - `TF_VAR_github_client_id`: See Github Oauth Step
  - `TF_VAR_github_client_secret` See Github Oauth Step
  - `TF_VAR_aws_certificate_arn` See Create Cert Step

### Variables File

Create a variables file `$HUB_DEPLOYMENT_NAME.tfvars` (ie dandihub.tfvars)

 - singleuser_image_repo: Dockerhub repository containing custom jupyterhub image
 - singleuser_image_tag: tag
 - jupyterhub_domain: The domain to hust the jupytehub landing page: (ie "hub.dandiarchive.org")
 - admin_users: List of adming github usernames (ie: ["github_username"])

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

WARNING: Amazon Key Management Service objects have a 7 day waiting period to delete.
Be absolutely sure that tfstate is up to date before runnning. 

`./install.sh`

Occassionally there are timeout and race condition failures.
Usually these are resolved by simply retrying the install script.


### Cleanup

Cleanup requires the same variables and is run `./cleanup.sh`

NOTE: Occassionally the kubernetes namespace fails to delete.

WARNING: Sometimes AWS VPCs are left up due to an upstream terraform race condition, and must be deleted by hand (including hand-deleting each nested object)

### Update

Changes to variables or the template configuration usually is updated idempotently by running
`./install.sh` **without the need to cleanup prior**.

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
