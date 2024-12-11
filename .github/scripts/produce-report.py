#!/usr/bin/env python3

import os
import gzip
import json
import sys
from collections import defaultdict

USER_QUOTA = 8_000_000_000

# TODO trash files

def generate_statistics(input_file):
    # Load the JSON data from the compressed file
    with gzip.open(input_file, 'rt', encoding='utf-8') as gz_file:
        data = json.load(gz_file)

    # Dictionary to hold statistics per leading directory
    stats = {
        "directories": defaultdict(lambda: {"total_size": 0, "file_count": 0}),
        "total": {"total_size": 0, "file_count": 0},
    }


    # Process each file's metadata
    for file_metadata in data["files"]:
        # Get the leading directory (first part of the relative path)
        leading_dir = file_metadata["path"].split(os.sep)[0]
        # TODO trash files
        # if file_metadata["path"] matches trashglob
        #  stats["caches"]["<whichone>"] increment file and totalsize count
        # Update statistics for this leading directory
        stats["directories"][leading_dir]["file_count"] += 1
        stats["total"]["file_count"] += 1
        stats["directories"][leading_dir]["total_size"] += file_metadata["size"]
        stats["total"]["total_size"] += file_metadata["size"]
    return stats

def bytes_to_human_readable(size_in_bytes):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_in_bytes < 1024:
            return f"{size_in_bytes:.2f} {unit}"
        size_in_bytes /= 1024

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <input_json_gz_file>")
        sys.exit(1)

    input_json_gz_file = sys.argv[1]
    username = input_json_gz_file.split(".")[0]
    stats = generate_statistics(input_json_gz_file)
    human_readable_total = bytes_to_human_readable(stats["total"]["total_size"])

    if stats["total"]["total_size"] < USER_QUOTA:
        print(f"All ok, user {username} is below quota, consuming {human_readable_total}")
        sys.exit(0)

    human_readable_quota = bytes_to_human_readable(USER_QUOTA)
    with open(f"{username}-usage-report.txt", "w") as report:
        report.write(f"Total usage: {human_readable_total} exceeds quota amount: {human_readable_quota}\n\n")
        for directory, stat in stats["directories"].items():
            report.write(f"Directory: {directory}\n")
            report.write(f"  Total files: {stat['file_count']}\n")
            report.write(f"  Total size: {bytes_to_human_readable(stat['total_size'])}\n")
            report.write("\n")
