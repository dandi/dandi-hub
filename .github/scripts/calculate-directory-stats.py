#!/usr/bin/env python3

import os
import gzip
import json
import sys
import unittest
from collections import defaultdict

def propagate_dir(stats, current_parent, previous_parent):
    highest_common = os.path.commonpath([current_parent, previous_parent])
    path_to_propagate = os.path.relpath(previous_parent, highest_common)
    nested_dir_list = path_to_propagate.split(os.sep)[:-1]
    # Add each dir count to all ancestors up to highest common dir
    while nested_dir_list:
        working_dir = os.path.join(highest_common, *nested_dir_list)
        stats[working_dir]['file_count'] += stats[previous_parent]['file_count']
        nested_dir_list.pop()
        previous_parent = working_dir
    stats[highest_common]['file_count'] += stats[previous_parent]['file_count']

def generate_directory_statistics(data):
    # Assumes dirs are listed depth first (files are listed prior to directories)

    stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})
    previous_parent = ""
    for file_metadata in data["files"]:
        print(f"Calculating {file_metadata['path']}")
        this_parent = os.path.dirname(file_metadata["path"])
        stats[this_parent]["file_count"] += 1

        if previous_parent == this_parent:
            continue
        # going deeper
        elif not previous_parent or previous_parent == os.path.dirname(this_parent):
            previous_parent = this_parent
            continue
        else:  # previous dir done
            propagate_dir(stats, this_parent, previous_parent)
            previous_parent = this_parent

    # Run a final time with the root directory as this parent
    leading_dir = previous_parent.split(os.sep)[0]
    propagate_dir(stats, leading_dir, previous_parent)
    return stats

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <input_json_file>")
        sys.exit(1)

    input_json_file = sys.argv[1]
    username = input_json_file.split(".")[0]
    with open(input_json_file, 'r', encoding='utf-8') as json_file:
        data = json.load(json_file)

    stats = generate_directory_statistics(data)
    for directory, stat in stats.items():
        print(f"{directory}: {stat['file_count']}")


class TestDirectoryStatistics(unittest.TestCase):
    def test_propagate_dir(self):
        stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})
        stats["a/b/c"] = {"total_size": 0, "file_count": 3}
        stats["a/b"] = {"total_size": 0, "file_count": 0}
        stats["a"] = {"total_size": 0, "file_count": 0}

        propagate_dir(stats, "a", "a/b/c")
        self.assertEqual(stats["a"]["file_count"], 3)
        self.assertEqual(stats["a/b"]["file_count"], 3)

    def test_generate_directory_statistics(self):
        sample_data = {
            "files": [
                {"path": "a/b/file3.txt"},
                {"path": "a/b/c/file1.txt"},
                {"path": "a/b/c/file2.txt"},
                {"path": "a/b/c/d/file4.txt"}
            ]
        }
        stats = generate_directory_statistics(sample_data)
        self.assertEqual(stats["a/b/c/d"]["file_count"], 1)
        self.assertEqual(stats["a/b/c"]["file_count"], 3)
        self.assertEqual(stats["a/b"]["file_count"], 4)
        self.assertEqual(stats["a"]["file_count"], 4)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        unittest.main(argv=sys.argv[:1])  # Run tests if "test" is provided as an argument
    else:
        main()
