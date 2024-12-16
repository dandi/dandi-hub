#!/usr/bin/env python3

import os
import csv
import json
import sys
import unittest
from collections import defaultdict
from pathlib import Path
from pprint import pprint
from typing import Iterable


def propagate_dir(stats, current_parent, previous_parent):
    assert os.path.isabs(current_parent) == os.path.isabs(
        previous_parent
    ), "current_parent and previous_parent must both be abspath or both be relpath"
    highest_common = os.path.commonpath([current_parent, previous_parent])
    assert highest_common, "highest_common must either be a target directory or /"

    path_to_propagate = os.path.relpath(previous_parent, highest_common)
    # leaves off last to avoid propagating to the path we are propagating from
    nested_dir_list = path_to_propagate.split(os.sep)[:-1]
    # Add each dir count to all ancestors up to highest common dir
    while nested_dir_list:
        working_dir = os.path.join(highest_common, *nested_dir_list)
        stats[working_dir]["file_count"] += stats[previous_parent]["file_count"]
        stats[working_dir]["total_size"] += stats[previous_parent]["total_size"]
        nested_dir_list.pop()
        previous_parent = working_dir
    stats[highest_common]["file_count"] += stats[previous_parent]["file_count"]
    stats[highest_common]["total_size"] += stats[previous_parent]["total_size"]


def generate_directory_statistics(data: Iterable[str]):
    # Assumes dirs are listed depth first (files are listed prior to directories)

    stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})
    previous_parent = ""
    for filepath, size, modified, created, error in data:
        # TODO if error is not None:
        this_parent = os.path.dirname(filepath)
        stats[this_parent]["file_count"] += 1
        stats[this_parent]["total_size"] += int(size)

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
    # During final run, leading dir cannot be empty string, propagate_dir requires
    # both to be abspath or both to be relpath
    leading_dir = previous_parent.split(os.sep)[0] or "/"
    propagate_dir(stats, leading_dir, previous_parent)
    return stats


def iter_file_metadata(file_path):
    """
    Reads a tsv and returns an iterable that yields one row of file metadata at
    a time, excluding comments.
    """
    file_path = Path(file_path)
    with file_path.open(mode="r", newline="", encoding="utf-8") as file:
        reader = csv.reader(file, delimiter="\t")
        for row in reader:
            # Skip empty lines or lines starting with '#'
            if not row or row[0].startswith("#"):
                continue
            yield row

def update_stats(stats, directory, stat):
    stats["total_size"] += stat["total_size"]
    stats["file_count"] += stat["file_count"]

    # Caches track directories, but not report as a whole
    if stats.get("directories") is not None:
        stats["directories"].append(directory)

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <input_json_file>")
        sys.exit(1)

    input_tsv_file = sys.argv[1]
    username = input_tsv_file.split("-index.tsv")[0]

    data = iter_file_metadata(input_tsv_file)
    stats = generate_directory_statistics(data)
    cache_types = ["pycache", "user_cache", "yarn_cache", "pip_cache", "nwb_cache"]
    report_stats = {
        "total_size": 0,
        "file_count": 0,
        "caches": {
            cache_type: {"total_size": 0, "file_count": 0, "directories": []}
            for cache_type in cache_types
        }
    }
    # print(f"{directory}: File count: {stat['file_count']}, Total Size: {stat['total_size']}")
    for directory, stat in stats.items():
        if directory.endswith("__pycache__"):
            update_stats(report_stats["caches"]["pycache"], directory, stat)
        elif directory.endswith(f"{username}/.cache"):
            update_stats(report_stats["caches"]["user_cache"], directory, stat)
        elif directory.endswith(".cache/yarn"):
            update_stats(report_stats["caches"]["yarn_cache"], directory, stat)
        elif directory.endswith(".cache/pip"):
            update_stats(report_stats["caches"]["pip_cache"], directory, stat)
        elif directory == username:
            update_stats(report_stats, username, stat)

    pprint(report_stats)


class TestDirectoryStatistics(unittest.TestCase):
    def test_propagate_dir(self):
        stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})
        stats["a/b/c"] = {"total_size": 100, "file_count": 3}
        stats["a/b"] = {"total_size": 10, "file_count": 0}
        stats["a"] = {"total_size": 1, "file_count": 0}

        propagate_dir(stats, "a", "a/b/c")
        self.assertEqual(stats["a"]["file_count"], 3)
        self.assertEqual(stats["a/b"]["file_count"], 3)
        self.assertEqual(stats["a"]["total_size"], 111)

    def test_propagate_dir_abs_path(self):
        stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})
        stats["/a/b/c"] = {"total_size": 0, "file_count": 3}
        stats["/a/b"] = {"total_size": 0, "file_count": 0}
        stats["/a"] = {"total_size": 0, "file_count": 0}

        propagate_dir(stats, "/a", "/a/b/c")
        self.assertEqual(stats["/a"]["file_count"], 3)
        self.assertEqual(stats["/a/b"]["file_count"], 3)

    def test_propagate_dir_files_in_all(self):
        stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})
        stats["a/b/c"] = {"total_size": 0, "file_count": 3}
        stats["a/b"] = {"total_size": 0, "file_count": 2}
        stats["a"] = {"total_size": 0, "file_count": 1}

        propagate_dir(stats, "a", "a/b/c")
        self.assertEqual(stats["a"]["file_count"], 6)
        self.assertEqual(stats["a/b"]["file_count"], 5)

    def test_generate_directory_statistics(self):
        sample_data = [
            ("a/b/file3.txt", 3456, "2024-12-01", "2024-12-02", "OK"),
            ("a/b/c/file1.txt", 1234, "2024-12-01", "2024-12-02", "OK"),
            ("a/b/c/file2.txt", 2345, "2024-12-01", "2024-12-02", "OK"),
            ("a/b/c/d/file4.txt", 4567, "2024-12-01", "2024-12-02", "OK"),
            ("a/e/file3.txt", 5678, "2024-12-01", "2024-12-02", "OK"),
            ("a/e/f/file1.txt", 6789, "2024-12-01", "2024-12-02", "OK"),
            ("a/e/f/file2.txt", 7890, "2024-12-01", "2024-12-02", "OK"),
            ("a/e/f/g/file4.txt", 8901, "2024-12-01", "2024-12-02", "OK"),
        ]
        stats = generate_directory_statistics(sample_data)
        self.assertEqual(stats["a/b/c/d"]["file_count"], 1)
        self.assertEqual(stats["a/b/c"]["file_count"], 3)
        self.assertEqual(stats["a/b"]["file_count"], 4)
        self.assertEqual(stats["a/e/f/g"]["file_count"], 1)
        self.assertEqual(stats["a/e/f"]["file_count"], 3)
        self.assertEqual(stats["a/e"]["file_count"], 4)
        self.assertEqual(stats["a"]["file_count"], 8)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        unittest.main(
            argv=sys.argv[:1]
        )  # Run tests if "test" is provided as an argument
    else:
        main()
