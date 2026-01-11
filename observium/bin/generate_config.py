#!/usr/bin/env python3
"""
Generate Observium config.php from OBSERVIUM__ prefixed environment variables.

Environment variable naming conventions:
- OBSERVIUM__ prefix is stripped
- Double underscore (__) creates nested arrays
- Triple underscore (___) becomes a dash (-)
- Numeric keys create indexed arrays
- "true"/"false" are converted to PHP booleans
- Numeric strings are converted to integers

Example:
    OBSERVIUM__db_host=mysql           -> $config['db_host'] = 'mysql';
    OBSERVIUM__ping__retries=5         -> $config['ping']['retries'] = 5;
    OBSERVIUM__poller___wrapper__threads=2 -> $config['poller-wrapper']['threads'] = 2;
    OBSERVIUM__bad_if__0=docker0       -> $config['bad_if'][0] = 'docker0';
"""

import os
from typing import Union


def get_env_by_prefix(prefix: str) -> dict[str, str]:
    """Get all environment variables with given prefix, stripping the prefix from keys."""
    result = {}
    for key, value in os.environ.items():
        if key.startswith(prefix):
            stripped_key = key[len(prefix):]
            result[stripped_key] = value
    return result


def replace_triple_underscores(key: str) -> str:
    """Convert triple underscores to dashes in key names."""
    return key.replace("___", "-")


def convert_value(value: str) -> Union[bool, int, str]:
    """Convert string value to appropriate Python type for PHP output."""
    lower_value = value.lower()
    if lower_value == "true":
        return True
    elif lower_value == "false":
        return False
    elif value.isdigit() or (value.startswith("-") and value[1:].isdigit()):
        return int(value)
    return value


def parse_config(env_vars: dict[str, str]) -> dict:
    """
    Parse flat environment variables into a nested dict structure.

    Keys are split by __ to create nested dicts.
    Numeric keys create list-like structures (stored as dicts with int keys).
    """
    config: dict = {}

    for key, value in sorted(env_vars.items()):
        key = replace_triple_underscores(key)
        parts = key.split("__")

        current = config
        for i, part in enumerate(parts[:-1]):
            if part.isdigit():
                part = int(part)
            if part not in current:
                current[part] = {}
            current = current[part]

        final_key = parts[-1]
        if final_key.isdigit():
            final_key = int(final_key)
        current[final_key] = convert_value(value)

    return config


def to_php_value(value: Union[bool, int, str, dict], indent: int = 0) -> str:
    """Convert a Python value to PHP syntax."""
    indent_str = "  " * indent

    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    elif isinstance(value, int):
        return str(value)
    elif isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace("'", "\\'")
        return f"'{escaped}'"
    elif isinstance(value, dict):
        if not value:
            return "array()"

        items = []
        for k, v in value.items():
            key_str = str(k) if isinstance(k, int) else f"'{k}'"
            val_str = to_php_value(v, indent + 1)
            items.append(f"{indent_str}  {key_str} => {val_str}")

        return "array(\n" + ",\n".join(items) + f",\n{indent_str})"
    else:
        return f"'{value}'"


def generate_php_config(config: dict) -> str:
    """Generate the complete PHP config file content."""
    lines = [
        "<?php",
        f"$customConfig = {to_php_value(config)};",
        "$config = array_replace_recursive($config, $customConfig);",
    ]
    return "\n".join(lines) + "\n"


def main():
    env_vars = get_env_by_prefix("OBSERVIUM__")
    config = parse_config(env_vars)
    print(generate_php_config(config), end="")


if __name__ == "__main__":
    main()
