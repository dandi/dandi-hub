# nebari-deployments

# Requirements

1. https://github.com/nebari-dev/nebari
2. https://github.com/nebari-dev/nebari-self-registration
3. k9s

## Steps for Deployment / Updating Deployments / Etc

0. Checkout custom Nebari branch: from the [dandi-fork](https://github.com/dandi/nebari), branch: `deploy` and pip install.

1. Be in the root directory where you have `stages` and the config file

2. Create a `.env` file with the following:

```bash
AWS_ACCESS_KEY_ID=<something>
AWS_SECRET_ACCESS_KEY=<something-else>
GITHUB_CLIENT_ID=<something-else-else>
GITHUB_CLIENT_SECRET=<something-else-else-else>
KEYCLOAK_INITIAL_PASSWORD=<something-else-else-else-else>
```

You can load into your shell with the following:
```bash
export $(grep -v '^#' .env | xargs)
```

Replace the values in the config file if you are using

```bash
envsubst < nebari-production-config.yaml > nebari-config-deploy.yaml
```

3. Determine drift (e.g. essentially a terraform plan) of your current config changes

WARNING: Do not use `-o`, everything should go to `stages/`. 
The deploy step does not always respect the custom path, and can be destructive.

```
nebari render --config nebari-config-deploy.yaml
```

4. If happy, deploy

```
nebari deploy --config nebari-config-deploy.yaml
```

wait for ingress to show up. Then adjust the hub.dandiarchive.org
(or whichever domain you are using) dns record to point to the
ingress load balancer dns name.

5. If bad results, sorry, time to debug!

6. If good results, look at the output of the logs to see where to go, and then
  run `aws eks update-config <cluster-name> ...` to start to inspect behavior
  on cluster

  `aws eks update-kubeconfig --region us-east-2 --name dandi-hub`

7. Use k9s to monitor the cluster

8. Add users to keycloak. See below.

## Adding users to keycloak

1. First get users from the DANDI instances.
   api.dandiarchive.org/admin -> users
   filter by approved
   select all (empty box to select first 100, then select all)
   WARNING: DO NOT SELECT DELETE ALL USERNAMES
   Action: "Export selected users' Github usernames" -> GO
   copy the csv contents

2. paste the users into the file cooresponding to their group, (ie dandi, linc, ember)
   This can clobber the previous list.

3. Follow the steps above to template the config file, and export AWS env vars.

4. Using a venv with the [dandi fork of nebari](https://github.com/dandi/nebari/tree/deploy)
   `python create_users.py nebari-config-deploy.yaml`

## Notes

1. Setup keycloak:

   - Login in to https://hub.dandiarchive.org/auth with root credentials
   - Add SMTP settings
   - Add users and groups

2. Setup conda-store environments:

   - Login in to https://hub.dandiarchive.org/conda-store
   - Add environments using the lock yaml files from the environments folder

3. This deployment uses a custom nebari source (see nebari deploy branch on DANDI)

   - supports multiple instance types
   - supports spot pricing
   - supports public and private subnets
   - supports not using kms[0]

4. Uses custom dandi image from nebari-docker-images (on dandi org)

   - enh/dandi branch
   - docker buildx build -t dandiarchive/dandihub:latest-nebari -f Dockerfile . --target dandi --platform linux/amd64
   - docker buildx build -t dandiarchive/dandihub:latest-nebari-gpu -f Dockerfile.gpu . --target dandi --platform linux/amd64
   - no matlab support yet
   - privileged mode turned off (no apptainer/podman)

5. Debugging:

   - if keyclock is unresponsive, try terminating the general instance
   - if the general instance comes back on a different subnet, try again till it comes
    back on the same subnet as the volumes
   - Sometimes the deployment will generate errors that are simply
     due to timeouts. Try again.

6. Cleanup:

   - The destroy command will not remove the ELB, so you will need to remove it manually.
   - Sometimes it will also not remove the VPC, so you will need to remove it manually.
   - It will not remove the volumes attached. Search for them (they should be named dandi,
     i.e the project name in the config) and delete them manually.
   - If the destroy gets stuck in a weird state, you will also need to remove roles and
     policies. Search for dandi and remove those associated with the hub.
   - A resource group is created which will list all the resources created by nebari.

