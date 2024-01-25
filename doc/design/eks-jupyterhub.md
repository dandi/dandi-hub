# Deployment of User Jupyterhubs with EKS

## Current Setup

Currently, we use an [Ansible
playbook](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html)
as the top level interface.  An admin first sets up an EC2 instance, and sets
some Amazon Web Services configuration, and then runs the playbook
against the EC2 instance. The playbook then creates all remaining Amazon
resources, uses [`kops`](https://kops.sigs.k8s.io/) to install and
configure Kubernetes, and then installs the official [Jupyterhub Helm
Chart](https://hub.jupyter.org/helm-chart/). DANDI users authenticate
with GitHub OAuth, and can create their own user-space `jupyterhub`
instances.

### Limitations

 - This approach cannot yet be fully automated, and requires administrator configuration in the AWS console.
 - The Ansible playbook is based on the [zero to jupyterhub](https://github.com/spacetelescope/z2jh-aws-ansible)
   approach used by the space-telescopes group, but this approach is no longer used upstream, and
   we currently have to maintain the whole Ansible playbook alone.
 - The majority of the complexity of this approach is the deployment and configuration of Kubernetes itself.

## Desired features

* Top priority

1. Environment/Compute
  1. Single hub with multiple groups that get allocated different resources*
  1. Bring/build your own image*
  1. Run other services on the Kubernetes layer that JupyterHub users can use
1. Costs
  1. Spot pricing (and more generally, minimize costs using any cloud feature)*
  1. Separate billing for each group
  1. Monitor access, storage, compute for each user and group
1. Storage
  1. Storage quotas controllable by user/group*
  1. Persistent home directories
  1. Persistent shared directories
  1. Regular clean up of shared directories
1. Authentication
  1. Connection to DANDI for OAuth
## Proposed Setup

Amazon Solutions Architects have created and maintained a repository for
common use cases on top of AWS, and [multi-tennant user-space
Jupyterhub](https://aws.amazon.com/blogs/containers/building-multi-tenant-jupyterhub-platforms-on-amazon-eks/)
instances is one of them. The
[jupyerhub](https://github.com/awslabs/data-on-eks/tree/main/ai-ml/jupyterhub)
Terraform blueprint example is capable of starting an EKS instance and
deploying self-healing, auto-scaling user-space jupyterhub instances on
the fly.

### Component Technologies

K8s Terminology - operators and controllers

#### Terraform

Terraform creates a Virtual Private Cluster, creates EKS cluster, and installs operators/controllers that manage each of the components.

#### Karpenter

Karpenter does the heavy lifting in this setup, it handles the auto-scaling via "just in time" provisioning of Kubernetes nodes to meet the needs of the users.
Karpenter currently only supports AWS, but it has [recently become a part of the Kubernetes SIG Autoscaling](https://github.com/kubernetes/org/issues/4258), which should affect governance and vendor neutrality.

Overview: https://www.cncf.io/blog/2023/06/26/kubernetes-workload-management-using-karpenter/

#### Grafana & Prometheus

Grafana and Prometheus are commonly used tools for metrics and monitoring with Kubernetes, and are included out-of-the-box.

## Work Needed, Gaps, Limitations, and Open Questions

1. The example blueprint can use `dummy` or `cognito`. We will need to
   investigate how to use OAuth via GitHub.
1. The examble includes "profiles" for Jupyterhub pod sizes and resource
   utilization. We can define our own profiles, but will need to ensure
   that the resources work as intended.

## Possible Setup Alternatives

TODO: Ansible or Bash instead of terraform
