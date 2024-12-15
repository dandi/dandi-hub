#!/usr/bin/env python3

import os
import csv
import time
import sys
from datetime import datetime
from pathlib import Path

OUTPUT_DIR = "/tmp/hub-user-indexes"

class MetadataWriter:
    def __init__(self, output_path):
        self.output_path = Path(output_path)
        self.start_time = None
        self.end_time = None
        self.meta = {
            "index_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "duration": None,
            "total_files": 0,
        }
        self.file = None
        self.writer = None

    def start(self):
        """Initialize the metadata and open the file for writing."""
        self.start_time = time.time()
        self.file = self.output_path.open(mode="w", newline="", encoding="utf-8")
        self.writer = csv.writer(self.file, delimiter="\t")
        self.writer.writerow(["#file_name", "file_size", "file_type", "custom_metadata"])

    def write_row(self, file_name, file_size, created, modified, error):
        """Write data for a file."""
        if not self.writer:
            raise RuntimeError("Writer not initialized.")
        if error is not None:
            self.writer.writerow([file_name, "-", "-", "-", error])
        else:
            self.writer.writerow([file_name, file_size, created, modified, "OK"])

        self.meta["total_files"] += 1

    def finish(self):
        """Finalize metadata, write it to the file, and close the file."""
        if not self.writer:
            raise RuntimeError("Writer not initialized.")
        self.end_time = time.time()
        self.meta["duration"] = self.end_time - self.start_time

        self.file.write("\n# Execution Metadata\n")
        for key, value in self.meta.items():
            self.file.write(f"# {key}: {value}\n")

        self.file.close()

    def get_meta(self):
        """Return the meta-metadata dictionary."""
        return self.meta


def directory_index(directory):
    for root, dirs, files in os.walk(directory):
        for name in files:
            filepath = os.path.join(root, name)
            try:
                stat_result = os.stat(filepath, follow_symlinks=False)
            except (FileNotFoundError, PermissionError) as e:
                size = modified = created = None
                error = str(e)
            else: 
                size = stat_result.st_size
                modified = time.ctime(stat_result.st_mtime)
                created = time.ctime(stat_result.st_ctime)
                error = None
            yield filepath, size, modified, created, error

# Ensure the script is called with the required arguments
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <directory_to_index>")
        sys.exit(1)

    directory = sys.argv[1]

    # Ensure the output filename ends with .tsv for clarity

    os.makedirs(OUTPUT_DIR)
    output_file = f"{OUTPUT_DIR}/{directory}-index.tsv"
    file_index = MetadataWriter(output_file)
    file_index.start()
    for filename, size, created, modified, error in directory_index(directory):
        file_index.write_row(filename, size, created, modified, error)
    file_index.finish()
