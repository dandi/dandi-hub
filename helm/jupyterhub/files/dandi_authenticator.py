from kubernetes_asyncio import client


def modify_pod_hook(spawner, pod):
    pod.spec.containers[0].security_context = client.V1SecurityContext(
        privileged=True
    )
    return pod


c.KubeSpawner.modify_pod_hook = modify_pod_hook

# Based on <https://github.com/jupyterhub/oauthenticator/blob/master/examples/auth_state/jupyterhub_config.py>:
import os
import warnings

from oauthenticator.github import GitHubOAuthenticator
from tornado.httpclient import HTTPRequest, HTTPClientError, AsyncHTTPClient
import json

# define our OAuthenticator with `.pre_spawn_start`
# for passing auth_state into the user environment


class IsDandiUserAuthenticator(GitHubOAuthenticator):

    async def check_allowed(self, username, auth_model):
        """
        Overrides the OAuthenticator.check_allowed to check dandi registered users
        """
        if auth_model["auth_state"].get("scope", []):
            scopes = []
            for val in auth_model["auth_state"]["scope"]:
                scopes.extend(val.split(","))
            auth_model["auth_state"]["scope"] = scopes
        auth_model = await self.update_auth_model(auth_model)
        # print("check_allowed:", username, auth_model)

        if await super().check_allowed(username, auth_model):
            return True
        req = HTTPRequest(
                    f"https://api.dandiarchive.org/api/users/search/?username={username}",
                    method="GET",
                    headers={"Accept": "application/json",
                             "User-Agent": "JupyterHub",
                             "Authorization": "token ${danditoken}"},
                    validate_cert=self.validate_server_cert,
               )
        try:
            client = AsyncHTTPClient()
            resp = await client.fetch(req)
        except HTTPClientError:
            return False
        else:
            if resp.body:
                resp_json = json.loads(resp.body.decode('utf8', 'replace'))
                for val in resp_json:
                    if val["username"].lower() == username.lower():
                        return True

        # users should be explicitly allowed via config, otherwise they aren't
        return False

    async def pre_spawn_start(self, user, spawner):
        auth_state = await user.get_auth_state()
        if not auth_state:
            # user has no auth state
            return
        # define some environment variables from auth_state
        spawner.environment['GITHUB_TOKEN'] = auth_state['access_token']
        spawner.environment['GITHUB_USER'] = auth_state['github_user']['login']
        spawner.environment['GITHUB_EMAIL'] = auth_state['github_user']['email']


c.JupyterHub.authenticator_class = IsDandiUserAuthenticator

# enable authentication state
c.GitHubOAuthenticator.enable_auth_state = True
