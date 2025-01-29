#!/usr/bin/env python3

import glob
import os
import csv
import json
import sys
import unittest
from collections import defaultdict
from pathlib import Path
from pprint import pprint
from typing import Iterable

TOTALS_OUTPUT_FILE = "all_users_total.tsv"
OUTPUT_DIR = "/tmp/hub-user-reports/"
INPUT_DIR = "/tmp/hub-user-indexes"


csv.field_size_limit(sys.maxsize)


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

def inc_if_bids(stats, this_parent, path):
    if path.endswith("dataset_description.json")
        stats[this_parent]["bids_datasets"] += 1

def inc_if_zarr(stats, this_parent, path):
    raise NotImplementedError("TODO")

def inc_if_nwb(stats, this_parent, path):
    raise NotImplementedError("TODO")

def generate_statistics(data: Iterable[str]):
    # Assumes dirs are listed depth first (files are listed prior to directories)

    # TODO filter by file , "nwb_files", "bids_datasets", "zarr_files"]
    # TODO counter
    # stats = defaultdict(lambda: {"total_size": 0, "file_count": 0,"nwb_files": 0, "bids_datasets": 0 ", "zarr_files"})
    stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})
    previous_parent = ""
    for filepath, size, modified, created in data:
        this_parent = os.path.dirname(filepath)
        stats[this_parent]["file_count"] += 1
        stats[this_parent]["total_size"] += int(size)

        inc_if_bids(this_parent, filepath)
        inc_if_nwb(this_parent, filepath)
        inc_ifzarr(this_parent, filepath)

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
                print(f"SANITY {row}")
                continue
            yield row


def update_stats(stats, directory, stat):
    stats["total_size"] += stat["total_size"]
    stats["file_count"] += stat["file_count"]


def process_user(user_tsv_file, totals_writer):
    filename = os.path.basename(user_tsv_file)
    username = filename.removesuffix("-index.tsv")
    data = iter_file_metadata(user_tsv_file)
    stats = generate_directory_statistics(data)
    output_stat_types = ["total", "user_cache", "nwb_cache"] 
    output_stats = {key: {"total_size": 0, "file_count": 0} for key in output_stat_types}

    for directory, stat in stats.items():
        print(f"D: {directory}")
        if directory.endswith(f"{username}/.cache"):
            update_stats(output_stats["user_cache"], directory, stat)
        elif directory.endswith("nwb_cache"):  # TODO how do you identify nwb_cache?
            update_stats(output_stats["nwb_cache"], directory, stat)
        elif directory == username:
            update_stats(output_stats["total"], directory, stat)

    print([f"{username}", output_stats['total']])
    totals_writer.writerow([f"{username}", output_stats['total']])


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    pattern = f"{INPUT_DIR}/*-index.tsv"  # Ensure pattern includes the directory
    file_path = Path(OUTPUT_DIR, TOTALS_OUTPUT_FILE)
    with file_path.open(mode="w", newline="", encoding="utf-8") as totals_file:
        totals_writer = csv.writer(totals_file, delimiter="\t")
        for user_index_path in glob.iglob(pattern):
            process_user(user_index_path, totals_writer)
    print(f"Output file: {file_path} complete")


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
            ("a/b/file3.txt", 3456, "2024-12-01", "2024-12-02"),
            ("a/b/c/file1.txt", 1234, "2024-12-01", "2024-12-02"),
            ("a/b/c/file2.txt", 2345, "2024-12-01", "2024-12-02"),
            ("a/b/c/d/file4.txt", 4567, "2024-12-01", "2024-12-02"),
            ("a/e/file3.txt", 5678, "2024-12-01", "2024-12-02"),
            ("a/e/f/file1.txt", 6789, "2024-12-01", "2024-12-02"),
            ("a/e/f/file2.txt", 7890, "2024-12-01", "2024-12-02"),
            ("a/e/f/g/file4.txt", 8901, "2024-12-01", "2024-12-02"),
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
