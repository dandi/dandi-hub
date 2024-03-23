./install.sh should be idempotent, and skip steps,

workflow: change -> install.sh

if the change doesn't propegate into jupyterhub this can be used
without destroying all the eks

  terraform destroy -target=module.eks_data_addons.helm_release.jupyterhub -auto-approve

module.eks_data_addons.helm_release.jupyterhub

Note on terraform blueprint
  race conditions are seeming pretty common, especially when things
  fail, and state can be hard to return to correct.
    - We sometimes during an up/down cycle, AWS VPCs are left up, and
        are undeletable without first removing nested objects
    - KMS have  7 day waiting period to delete. Therefore NEVER run
        without first obtaining tfstate with `terraform init`
    - context deadline exceeded is common
    - Error: cannot re-use a name that is still in use   --- usually
          - I had to manually delete namespace jupyterhub
          

  however first thing to try is just run install.sh a few times
  sometimes it can fix itself.

~Ive needed to add an "All traffic" override to the Security Group for
the VPC~ ruled out.

Manually change route53 record to the proxy

manually add admins to aws-auth  via mapUsers

$ k get configMap -n kube-system aws-auth -o yaml
```
apiVersion: v1
data:
  mapAccounts: |
    []
  mapRoles: |
    - "groups":
      - "system:bootstrappers"
      - "system:nodes"
      "rolearn": "arn:aws:iam::278212569472:role/jupyterhub-node-group-eks-node-group-20240315201456887100000003"
      "username": "system:node:{{EC2PrivateDNSName}}"
    - "groups":
      - "system:bootstrappers"
      - "system:nodes"
      "rolearn": "arn:aws:iam::278212569472:role/karpenter-jupyterhub-on-eks-2024031520225643870000000d"
      "username": "system:node:{{EC2PrivateDNSName}}"
  mapUsers: |
    []
kind: ConfigMap
metadata:
  creationTimestamp: "2024-03-15T20:24:26Z"
  name: aws-auth
  namespace: kube-system
  resourceVersion: "1548"
  uid: 3539c124-e643-430b-998d-12b01230c2f7
```
