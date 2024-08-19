# Data Retention Policy

Dandihub data storage on AWS EFS is expensive, and we suppose that significant portions of the data
currently stored are no longer used. Data migration is where the cost becomes extreme.

## Persistent Data locations

Each user has access to 2 locations: `/home/{user}` and `/shared/`

Within jupyterhub `/home/{user}` the user always sees `/home/jovyan`, but is stored in EFS as their GitHub
username.

## Known cache file cleanup 

We should be able to safely remove the following:
 - `/home/{user}/.cache`
 - `nwb_cache` 
 - Yarn Cache
 - `__pycache__`
 - pip cache


## Determining Last Access

EFS does not store metadata for the last access of the data. (Though they must track somehow to move
to `Infrequent Access`)

Alternatives: 
 - use the [jupyterhub REST API](https://jupyterhub.readthedocs.io/en/stable/reference/rest-api.html#operation/get-users) check when user last used/logged in to hub.
 - dandiarchive login information

## Automated Data Audit

At some interval (30 days with no login?):
   - find files larger than 1 (?) GB and mtime > 30 (?) days -- get total size and count
   - find _pycache_ and nwb-cache folders and pip cache and mtime > 30? days -- total sizes and list of them

Notify user if:
   - total du exceeds some threshold (e.g. 100G)
   - total outdated caches size exceeds some threshold (e.g. 1G)
   - prior notification was sent more than a week ago

Notification information:
   - large file list
   - summarized data retention policy
   - Notice number
   - request to cleanup

### Non-response cleanup 

If a user has not logged in for 60 days (30 days initial + 30 days following audit), send a warning: 
`In 10 days the following files will be cleaned up`

If the user has not logged in for 70 days (30 initial + 30 after audit + 10 warning):
`The following files were removed`

Reset timer. 
