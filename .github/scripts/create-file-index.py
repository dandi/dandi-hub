#!/usr/bin/env python3

import os
import csv
import time
import sys
from datetime import datetime
from pathlib import Path

OUTPUT_DIR = "/home/ec2-user/hub-user-indexes"


class MetadataWriter:
    def __init__(self, output_path, error_path):
        self.output_path = Path(output_path)
        self.error_path = Path(error_path)
        self.start_time = None
        self.end_time = None
        self.meta = {
            "index_timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "duration": None,
            "total_files": 0,
            "total_size": 0,
        }
        self.outfile = None
        self.errfile = None
        self.outwriter = None
        self.errwriter = None

    def start(self):
        """Initialize the metadata and open the file for writing."""
        self.start_time = time.time()
        self.outfile = self.output_path.open(mode="w", newline="", encoding="utf-8")
        self.errfile = self.error_path.open(mode="w", newline="", encoding="utf-8")
        self.outwriter = csv.writer(self.outfile, delimiter="\t")
        self.outwriter.writerow(
            ["#file_name", "file_size", "file_type", "custom_metadata"]
        )
        self.errwriter = csv.writer(self.errfile, delimiter="\t")

    def write_row(self, file_name, file_size, created, modified, error):
        """Write data for a file."""
        if not self.outwriter and self.errwriter:
            raise RuntimeError("Writers not initialized.")
        if error is not None:
            self.errwriter.writerow([file_name, error])
        else:
            self.outwriter.writerow([file_name, file_size, created, modified])
            self.meta["total_size"] += file_size

        self.meta["total_files"] += 1

    def finish(self):
        """Finalize metadata, write it to the file, and close the file."""
        if not self.outwriter and self.errwriter:
            raise RuntimeError("Writers not initialized.")
        self.end_time = time.time()
        self.meta["duration"] = self.end_time - self.start_time

        self.outfile.write("\n# Execution Metadata\n")
        for key, value in self.meta.items():
            self.outfile.write(f"# {key}: {value}\n")

        self.outfile.close()
        self.errfile.close()
        print(
            f"Directory {self.output_path} complete, Duration: {self.meta['duration']:.2f}, Total Files: {self.meta['total_files']}, Total Size: {self.meta['total_size']}"
        )

    def get_meta(self):
        """Return the meta-metadata dictionary."""
        return self.meta


def directory_index(directory):
    for root, dirs, files in os.walk(directory):
        for name in files:
            filepath = os.path.join(root, name)
            try:
                stat_result = os.stat(filepath, follow_symlinks=False)
            except Exception as e:
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

    # We assume this directory is a user homedir
    path_to_index = sys.argv[1]
    username = path_to_index.split("/")[-1]

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_file = f"{OUTPUT_DIR}/{username}-index.tsv"
    error_file = f"{OUTPUT_DIR}/{username}-errors.tsv"

    file_index = MetadataWriter(output_file, error_file)
    file_index.start()

    for filename, size, created, modified, error in directory_index(path_to_index):
        relative_filename = f"{username}/{os.path.relpath(filename, path_to_index)}"
        file_index.write_row(relative_filename, size, created, modified, error)

    file_index.finish()
