#!/usr/bin/env python3
import os
import re
import sys
import yaml


def str_presenter(dumper, data):
    """configures yaml for dumping multiline strings
    Ref: https://stackoverflow.com/questions/8640959/how-can-i-control-what-scalar-form-pyyaml-uses-for-my-data"""
    if len(data.splitlines()) > 1:  # check for multiline string
        return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
    return dumper.represent_scalar('tag:yaml.org,2002:str', data)


yaml.add_representer(str, str_presenter)
yaml.representer.SafeRepresenter.add_representer(str, str_presenter) # to use with safe_dum


# Used for correct YAML indentation. PyYAML default indents lists improperly
class IndentDumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(IndentDumper, self).increase_indent(flow, False)


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

    base_config = load_yaml(base_config_path)
    # import ipdb; ipdb.set_trace()
    if os.path.exists(env_config_path):
        env_config = load_yaml(env_config_path)
        merged_config = merge_dicts(base_config, env_config)
    else:
        merged_config = base_config

    with open(output_path, 'w') as output_file:
        yaml.dump(merged_config, output_file, Dumper=IndentDumper)


if __name__ == "__main__":
    main()
