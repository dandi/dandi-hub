#!/usr/bin/env python3

import os
import subprocess
import sys
import json

OUTPUT_FILE = "/output/du_report.json"
SIZE_THRESHOLD_GB = 1
SIZE_THRESHOLD_BYTES = SIZE_THRESHOLD_GB * 1024 * 1024 * 1024

# Function to calculate disk usage of a directory in bytes
def get_disk_usage_bytes(path):
    result = subprocess.run(['du', '-sb', path], capture_output=True, text=True)
    size_str = result.stdout.split()[0]  # Get the size in bytes (du -sb gives size in bytes)
    return int(size_str)

# Function to convert bytes to a human-readable format (e.g., KB, MB, GB)
def bytes_to_human_readable(size_in_bytes):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_in_bytes < 1024:
            return f"{size_in_bytes:.2f} {unit}"
        size_in_bytes /= 1024

def prepare_report(directory):
    report = {}
    # List user home dirs in the directory and calculate disk usage
    for user_dir in os.listdir(directory):
        user_path = os.path.join(directory, user_dir)
        if os.path.isdir(user_path):
            disk_usage_bytes = get_disk_usage_bytes(user_path)
            report[user_dir] = {
                "disk_usage_bytes": disk_usage_bytes
            }
            if disk_usage_bytes > SIZE_THRESHOLD_BYTES:
                # TODO: Placeholder for other actions
                report[user_dir]["action"] = f"Directory size exceeds {SIZE_THRESHOLD_BYTES / (1024**3):.2f}GB, further action taken."
            else:
                report[user_dir]["action"] = "No action required."

    for user, data in report.items():
        data["disk_usage_human_readable"] = bytes_to_human_readable(data["disk_usage_bytes"])

    with open(OUTPUT_FILE, 'w') as f:
        json.dump(report, f, indent=4)

    print(f"Disk usage report generated at {os.path.abspath(OUTPUT_FILE)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: du.py <directory_to_check>")
    else:
        directory = sys.argv[1]
        prepare_report(directory)
