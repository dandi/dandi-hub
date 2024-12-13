#!/usr/bin/env python3

import os
import time
import json
import sys
from datetime import datetime

def list_files_with_metadata(directory, output_file):
    # Record the start time
    start_time = time.time()

    # Get the current date and time for indexing
    index_timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    files_metadata = []

    for root, dirs, files in os.walk(directory):
        for name in files:
            filepath = os.path.join(root, name)
            try:
                metadata = {
                    "path": filepath,
                    "size": os.path.getsize(filepath),
                    "modified": time.ctime(os.path.getmtime(filepath)),
                    "created": time.ctime(os.path.getctime(filepath))
                }
                files_metadata.append(metadata)
            except (FileNotFoundError, PermissionError) as e:
                print(f"Skipping {filepath}: {e}")

    # Record the end time and calculate the duration
    end_time = time.time()
    duration = end_time - start_time

    # Prepare the output data with additional metadata
    output_data = {
        "index_timestamp": index_timestamp,
        "duration_seconds": duration,
        "files": files_metadata
    }

    # Write the output data to a .json file
    with open(output_file, "w", encoding="utf-8") as json_file:
        json.dump(output_data, json_file, indent=4)

    print(f"Indexing completed. Compressed results written to {output_file}")

# Ensure the script is called with the required arguments
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <directory_to_index> <output_json_file>")
        sys.exit(1)

    directory_to_index = sys.argv[1]
    output_json_file = sys.argv[2]

    # Ensure the output filename ends with .json for clarity
    if not output_json_file.endswith(".json"):
        output_json_file += ".json"

    list_files_with_metadata(directory_to_index, output_json_file)
