# Data Retention Policy

Dandihub data storage on AWS EFS is expensive, and we suppose that significant portions of the data
currently stored are no longer used. Data migration is where the cost becomes extreme.

## Persistent Data Locations

Each user has access to 2 locations: `/home/{user}` and `/shared/`.

Within jupyterhub `/home/{user}` the user always sees `/home/jovyan`, but is stored in EFS as their GitHub
username.



## Determining Last Access

- Use the [JupyterHub REST API](https://jupyterhub.readthedocs.io/en/stable/reference/rest-api.html#operation/get-users) to check when user last logged in to the hub.
- On a daily basis determine if any users had last logged in 30 or 45 days ago.  If so, send the emails noted in the #reset-home-directories-after-45-days-of-inactivity section. 

## Automated Data Audit

At an interval of every 7 days, calculate home directory disk usage.



### Reset home directories after 45 days of inactivity 

If a user has not logged in for 30 days, send a warning: 
`In 15 days, the files in your home directory on DANDI Hub will be deleted.  Please review your files stored on DANDI Hub and upload any relevant files to your respective Dandisets on DANDI Archive.  If you would like to keep the files on DANDI Hub, please log into the Hub within the next 15 days.`

If the user has not logged in for 45 days, send a confirmation:
`The files in your home directory on DANDI Hub were deleted.`
