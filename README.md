This terraform blueprint creates a Kubernetes environment (EKS) and
installs jupyterhub.

Jupyterhub itself is installed by their provided helm chart, which is
configured via the template `helm/jupyterhub/dandihub.yaml`, and 
via 

For information on configuration, see the [administrator guide for jupyerhub](https://z2jh.jupyter.org/en/stable/administrator/index.html)

To install for the first time:

1. Create the GitHub OAuth App id/token: GitHub settings -> Developer settings -> Oauth Apps.
We have done this via a bot GitHub user account (e.g. dandibot). You
will need to set Homepage URL (e.g., `https://hub.dandiarchive.org`) and
the Authorization callback URL (e.g. `https://hub.dandiarchive.org/hub/oauth_callback`). 

1. Create an https certificate for your domain using AWS cert manager.
  It's free to attach this certificate to load balancers, and JupyterHub also allows
  proxy offloading to this certificate.

1. Set the following environment variables: 
    - `TF_VAR_github_client_id`
    - `TF_VAR_github_client_secret`
    - `TF_VAR_aws_certificate_arn`


`./install.sh`

