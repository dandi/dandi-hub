#!/usr/bin/env python3

import glob
import os
import csv
import json
import sys
import unittest
from collections import Counter, defaultdict
from pathlib import Path
from pprint import pprint
from typing import Iterable, Tuple

TOTALS_OUTPUT_FILE = "all_users_total.json"
OUTPUT_DIR = "/tmp/hub-user-reports/"
INPUT_DIR = "/tmp/hub-user-indexes"


csv.field_size_limit(sys.maxsize)


class DirectoryStats(defaultdict):
    COUNTED_FIELDS = [
        "total_size",
        "file_count",
        "nwb_files",
        "nwb_size",
        "bids_datasets",
        "zarr_files",
        "zarr_size",
        "user_cache_file_count",
        "user_cache_size",
    ]
    root = str

    def __init__(self, root):
        super().__init__(lambda: Counter({key: 0 for key in self.COUNTED_FIELDS}))
        self.root = root

    def increment(self, path: str, field: str, amount: int = 1):
        if field not in self.COUNTED_FIELDS:
            raise KeyError(
                f"Invalid field '{field}'. Allowed fields: {self.COUNTED_FIELDS}"
            )
        self[path][field] += amount

    def propagate_dir(self, current_parent: str, previous_parent: str):
        """Propagate counts up the directory tree."""
        assert os.path.isabs(current_parent) == os.path.isabs(
            previous_parent
        ), "Both must be absolute or both relative"

        highest_common = os.path.commonpath([current_parent, previous_parent])
        assert highest_common, "highest_common must either be a target directory or /"

        path_to_propagate = os.path.relpath(previous_parent, highest_common)
        nested_dir_list = path_to_propagate.split(os.sep)[:-1]  # Exclude last directory

        while nested_dir_list:
            working_dir = os.path.join(highest_common, *nested_dir_list)
            for field in self.COUNTED_FIELDS:
                self[working_dir][field] += self[previous_parent][field]
            nested_dir_list.pop()
            previous_parent = working_dir

        # Final propagation to the common root
        for field in self.COUNTED_FIELDS:
            self[highest_common][field] += self[previous_parent][field]

    def inc_if_bids(self, parent: str, path: str):
        """Check if a file indicates a BIDS dataset and increment the count."""
        if path.endswith("dataset_description.json"):
            self.increment(parent, "bids_datasets")

    def inc_if_usercache(self, parent: str, filepath: str, size: int):
        if filepath.startswith(f"{self.root}/.cache"):
            self.increment(parent, "user_cache_file_count")
            self.increment(parent, "user_cache_size", size)

    def inc_if_nwb(self, parent: str, path: str, size: int):
        if path.lower().endswith(".nwb"):
            self.increment(parent, "nwb_files")
            self.increment(parent, "nwb_size", size)

    def inc_if_zarr(self, parent: str, path: str, size: int):
        if path.lower().endswith(".zarr"):
            self.increment(parent, "zarr_files")
            self.increment(parent, "zarr_size", size)

    @classmethod
    def from_index(cls, username, user_tsv_file):
        """Separated from from_data for easier testing"""
        data = cls._iter_file_metadata(user_tsv_file)
        return cls.from_data(username, data)

    @classmethod
    def from_data(cls, root, data: Iterable[Tuple[str, str, str, str]]):
        """
        Build DirectoryStats from an iterable of (filepath, size, modified, created).
        Assumes depth-first listing.
        """
        instance = cls(root=root)
        previous_parent = ""

        for filepath, size, _, _ in data:
            parent = os.path.dirname(filepath)

            instance.increment(parent, "file_count")
            instance.increment(parent, "total_size", int(size))
            instance.inc_if_bids(parent, filepath)
            instance.inc_if_nwb(parent, filepath, int(size))
            instance.inc_if_zarr(parent, filepath, int(size))
            instance.inc_if_usercache(parent, filepath, int(size))

            if previous_parent == parent:
                continue
            # Going deeper
            elif not previous_parent or os.path.dirname(parent) == previous_parent:
                previous_parent = parent
                continue
            else:  # Done with this directory
                instance.propagate_dir(parent, previous_parent)
                previous_parent = parent

        # Final propagation to ensure root directory gets counts
        leading_dir = previous_parent.split(os.sep)[0] or "/"
        instance.propagate_dir(leading_dir, previous_parent)

        return instance

    def _iter_file_metadata(file_path):
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

    @property
    def summary(self):
        return self[self.root]

    def __repr__(self):
        """Cleaner representation for debugging."""
        return "\n".join([f"{path}: {dict(counts)}" for path, counts in self.items()])


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    pattern = f"{INPUT_DIR}/*-index.tsv"
    outfile_path = Path(OUTPUT_DIR, TOTALS_OUTPUT_FILE)
    output_stats = {}
    for user_index_path in glob.iglob(pattern):
        filename = os.path.basename(user_index_path)
        username = filename.removesuffix("-index.tsv")
        full_stats = DirectoryStats.from_index(username, user_index_path)
        output_stats[username] = full_stats.summary

    with outfile_path.open(mode="w", encoding="utf-8") as totals_file:
        json.dump(output_stats, totals_file, indent=2)

    print(f"Success: report written to {outfile_path}")


class TestDirectoryStatistics(unittest.TestCase):
    def test_propagate_dir(self):
        stats = DirectoryStats(root="a")
        stats["a/b/c"].update({"total_size": 100, "file_count": 3})
        stats["a/b"].update({"total_size": 10, "file_count": 0})
        stats["a"].update({"total_size": 1, "file_count": 0})

        stats.propagate_dir("a", "a/b/c")
        self.assertEqual(stats["a"]["file_count"], 3)
        self.assertEqual(stats["a/b"]["file_count"], 3)
        self.assertEqual(stats["a"]["total_size"], 111)

    def test_propagate_dir_abs_path(self):
        stats = DirectoryStats(root="/a")
        stats["/a/b/c"].update({"file_count": 3})

        stats.propagate_dir("/a", "/a/b/c")
        self.assertEqual(stats["/a"]["file_count"], 3)
        self.assertEqual(stats["/a/b"]["file_count"], 3)

    def test_propagate_dir_files_in_all(self):
        stats = DirectoryStats(root="a")
        stats["a/b/c"].update({"file_count": 3})
        stats["a/b"].update({"file_count": 2})
        stats["a"].update({"file_count": 1})

        stats.propagate_dir("a", "a/b/c")
        self.assertEqual(stats["a"]["file_count"], 6)
        self.assertEqual(stats["a/b"]["file_count"], 5)

    def test_generate_statistics_inc_bids_0(self):
        sample_data = [("a/b/file3.txt", 3456, "2024-12-01", "2024-12-02")]
        stats = DirectoryStats.from_data("a", sample_data)
        self.assertEqual(stats["a/b"]["bids_datasets"], 0)
        self.assertEqual(stats["a"]["bids_datasets"], 0)

    def test_generate_statistics_inc_bids_subdatasets(self):
        sample_data = [
            ("a/b/c/subdir_of_bids", 3456, "2024-12-01", "2024-12-02"),
            ("a/b/dataset_description.json", 3456, "2024-12-01", "2024-12-02"),
            ("a/d/dataset_description.json", 3456, "2024-12-01", "2024-12-02"),
            (
                "a/d/subdataset/dataset_description.json",
                3456,
                "2024-12-01",
                "2024-12-02",
            ),
        ]
        stats = DirectoryStats.from_data("a", sample_data)
        self.assertEqual(stats["a/b/c"]["bids_datasets"], 0)
        self.assertEqual(stats["a/b"]["bids_datasets"], 1)
        self.assertEqual(stats["a/d/subdataset"]["bids_datasets"], 1)
        self.assertEqual(stats["a/d"]["bids_datasets"], 2)
        self.assertEqual(stats["a"]["bids_datasets"], 3)

    def test_generate_statistics_inc_usercache(self):
        sample_data = [
            ("a/.cache/x", 3456, "2024-12-01", "2024-12-02"),
            ("a/.cache/y", 3456, "2024-12-01", "2024-12-02"),
            ("a/.cache/nested/y", 3456, "2024-12-01", "2024-12-02"),
            ("a/b/notcache", 3456, "2024-12-01", "2024-12-02"),
        ]
        stats = DirectoryStats.from_data("a", sample_data)
        self.assertEqual(stats["a"]["user_cache_file_count"], 3)
        self.assertEqual(stats["a"]["user_cache_size"], 3456 * 3)
        self.assertEqual(stats["a/.cache"]["user_cache_file_count"], 3)
        self.assertEqual(stats["a/.cache"]["user_cache_size"], 3456 * 3)
        self.assertEqual(stats["a/b"]["user_cache_file_count"], 0)
        self.assertEqual(stats["a/b"]["user_cache_size"], 0)

    def test_generate_statistics(self):
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
        stats = DirectoryStats.from_data("a", sample_data)
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
