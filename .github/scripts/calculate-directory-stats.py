#!/usr/bin/env python3

import os
import gzip
import json
import sys
from collections import defaultdict

USER_QUOTA = 8_000_000_000

# TODO trash files


def propagate_dir(stats, highest_common, dir_list, prev_dir):
    while dir_list:
        working_dir = os.path.join(highest_common, *dir_list)
        stats[working_dir]['file_count'] += stats[prev_dir]['file_count']
        dir_list.pop()
        prev_dir = working_dir
    stats[highest_common]['file_count'] += stats[prev_dir]['file_count']

def generate_statistics(input_file):
    # Load the JSON data from the compressed file
    with open(input_file, 'r', encoding='utf-8') as json_file:
        data = json.load(json_file)

    # Dictionary to hold statistics per leading directory
    stats = defaultdict(lambda: {"total_size": 0, "file_count": 0})


    # Assumes dirs are listed depth first (files are listed prior to directories)
    previous_parent = ""
    for file_metadata in data["files"]:
        print(f"Calculating {file_metadata['path']}")
        this_parent = os.path.dirname(file_metadata["path"])
        stats[this_parent]["file_count"] += 1

        if previous_parent == this_parent:
            continue
        # going deeper
        # TODO account for going multiple levels deeper
        elif not previous_parent or previous_parent == os.path.dirname(this_parent):
            previous_parent = this_parent
            continue
        else:
            # previous dir done, possibly ancestors done too
            highest_common_dir = os.path.commonpath([this_parent, previous_parent])

            path_to_propagate = os.path.relpath(previous_parent, highest_common_dir)
            dir_list_to_propagate = path_to_propagate.split(os.sep)[:-1]

            print(f"{previous_parent} done, propegating to ancestors")
            print(f"Highest common: {highest_common_dir}")
            print(f"dir list to prop: {dir_list_to_propagate}")
            propagate_dir(stats, highest_common_dir, dir_list_to_propagate, previous_parent)
            previous_parent = this_parent

    leading_dir = previous_parent.split(os.sep)[0]
    highest_common_dir = os.path.commonpath([leading_dir, previous_parent])
    path_to_propagate = os.path.relpath(previous_parent, highest_common_dir)
    dir_list_to_propagate = path_to_propagate.split(os.sep)[:-1]
    print(f"a is currently {stats['a']['file_count']}")
    print(f"FINAL {previous_parent} done, propegating to ancestors")
    print(f"Highest common: {highest_common_dir}")
    print(f"dir list to prop: {dir_list_to_propagate}")
    propagate_dir(stats, highest_common_dir, dir_list_to_propagate, previous_parent)
    # propagate_dir(stats, highest_common_dir)
    # for each in dir_list_to_propagate:
    #     highest_common_dir = os.path.join(highest_common_dir, each)
    #     propagate_dir(stats, highest_common_dir)
    return stats


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <input_json_file>")
        sys.exit(1)

    input_json_file = sys.argv[1]
    username = input_json_file.split(".")[0]
    stats = generate_statistics(input_json_file)
    for directory, stat in stats.items():
        print(f"{directory}: {stat['file_count']}")

