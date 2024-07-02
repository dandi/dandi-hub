#!/usr/bin/env python3
import os
import sys
import yaml


def load_yaml(file_path):
    with open(file_path, 'r') as file:
        return yaml.safe_load(file)


def merge_dicts(dict1, dict2):
    result = dict1.copy()
    for key, value in dict2.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge_dicts(result[key], value)
        else:
            result[key] = value
    return result


def main():
    if not len(sys.argv) == 4:
        print("Intended usage: ./merge-config.py <base-config-path> <override-path> <output-path>")

    base_config_path = sys.argv[1]
    env_config_path = sys.argv[2]
    output_path = sys.argv[3]
    # base_config_path = "jupyterhub.yaml"
    # env_config_path = "envs/test/z2jh_overrides.yaml"
    # output_path = "merged_jupyterhub.yaml"

    base_config = load_yaml(base_config_path)
    # import ipdb; ipdb.set_trace()
    if os.path.exists(env_config_path):
        env_config = load_yaml(env_config_path)
        merged_config = merge_dicts(base_config, env_config)
    else:
        merged_config = base_config

    with open(output_path, 'w') as output_file:
        yaml.safe_dump(merged_config, output_file)


if __name__ == "__main__":
    main()

