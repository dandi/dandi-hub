import json
import requests
import datetime
import os

TO_NOTIFY = 30  # days
TO_REMOVE = 45  # days
api_url = 'https://hub.dandiarchive.org/hub/api'

token = os.environ.get("DANDI_API_TOKEN")
if token is None:
    raise Exception("Set DANDI_API_TOKEN")

r = requests.get(api_url + '/users',
    headers={
        'Authorization': f'token {token}',
    }
)

r.raise_for_status()
users = r.json()
#
active_users = []
to_notify_users = []
to_remove_users = []
now_utc = datetime.datetime.now(datetime.timezone.utc)

def days_since_used(user):
    last_activity = user.get("last_activity")
    if last_activity is None:
        print(f"DEBUG: last_activity none {user['name']}")
        return

    dt_parsed = datetime.datetime.fromisoformat(last_activity.replace('Z', '+00:00'))
    time_diff = now_utc - dt_parsed
    days_elapsed = time_diff.total_seconds() / 86400
    return days_elapsed

for user in users:
    days_elapsed = days_since_used(user)
    if days_elapsed is None:
        continue
    if days_elapsed <= TO_NOTIFY:
        active_users.append(user)
    elif days_elapsed > TO_NOTIFY and days_elapsed <= TO_REMOVE:
        to_notify_users.append(user)
    elif days_elapsed > TO_REMOVE:
        to_remove_users.append(user)
    else:
        import sys
        print("asmacdo mistake!")
        sys.exit(1)


print("USERS TO BE REMOVED-------------------")
for user in to_remove_users:
    print(f"{user['name']}: {days_since_used(user)}")

print("USERS TO BE NOTIFIED-------------------")
for user in to_notify_users:
    print(f"{user['name']}: {days_since_used(user)}")

print("ACTIVE USERS -------------------")
for user in active_users:
    print(f"{user['name']}: {days_since_used(user)}")

print()
print("=====SUMMARY=====")
print(f"Active: {len(active_users)}")
print(f"To Notify: {len(to_notify_users)}")
print(f"To Remove: {len(to_remove_users)}")
