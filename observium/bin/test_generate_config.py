#!/usr/bin/env python3
"""Unit tests for generate_config.py"""

import os
import pytest
from unittest.mock import patch

# Import the module under test
import importlib.util
spec = importlib.util.spec_from_file_location("generate_config", "observium/bin/generate_config.py")
generate_config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generate_config)


class TestReplaceTripleUnderscores:
    def test_single_triple_underscore(self):
        assert generate_config.replace_triple_underscores("poller___wrapper") == "poller-wrapper"

    def test_multiple_triple_underscores(self):
        assert generate_config.replace_triple_underscores("a___b___c") == "a-b-c"

    def test_no_triple_underscores(self):
        assert generate_config.replace_triple_underscores("normal_key") == "normal_key"

    def test_double_underscore_preserved(self):
        assert generate_config.replace_triple_underscores("ping__retries") == "ping__retries"


class TestConvertValue:
    def test_true_lowercase(self):
        assert generate_config.convert_value("true") is True

    def test_true_uppercase(self):
        assert generate_config.convert_value("TRUE") is True

    def test_true_mixed_case(self):
        assert generate_config.convert_value("True") is True

    def test_false_lowercase(self):
        assert generate_config.convert_value("false") is False

    def test_false_uppercase(self):
        assert generate_config.convert_value("FALSE") is False

    def test_integer_positive(self):
        assert generate_config.convert_value("42") == 42

    def test_integer_zero(self):
        assert generate_config.convert_value("0") == 0

    def test_integer_negative(self):
        assert generate_config.convert_value("-5") == -5

    def test_string_value(self):
        assert generate_config.convert_value("hello") == "hello"

    def test_string_with_numbers(self):
        assert generate_config.convert_value("192.168.1.1") == "192.168.1.1"


class TestGetEnvByPrefix:
    def test_filters_by_prefix(self):
        env = {
            "OBSERVIUM__db_host": "mysql",
            "OBSERVIUM__db_user": "admin",
            "OTHER_VAR": "ignored",
        }
        with patch.dict(os.environ, env, clear=True):
            result = generate_config.get_env_by_prefix("OBSERVIUM__")
            assert result == {"db_host": "mysql", "db_user": "admin"}

    def test_empty_when_no_match(self):
        env = {"OTHER_VAR": "value"}
        with patch.dict(os.environ, env, clear=True):
            result = generate_config.get_env_by_prefix("OBSERVIUM__")
            assert result == {}


class TestParseConfig:
    def test_simple_key(self):
        env = {"db_host": "mysql"}
        result = generate_config.parse_config(env)
        assert result == {"db_host": "mysql"}

    def test_nested_key(self):
        env = {"ping__retries": "5"}
        result = generate_config.parse_config(env)
        assert result == {"ping": {"retries": 5}}

    def test_deeply_nested_key(self):
        env = {"a__b__c": "value"}
        result = generate_config.parse_config(env)
        assert result == {"a": {"b": {"c": "value"}}}

    def test_numeric_key(self):
        env = {"bad_if__0": "docker0", "bad_if__1": "lo"}
        result = generate_config.parse_config(env)
        assert result == {"bad_if": {0: "docker0", 1: "lo"}}

    def test_triple_underscore_to_dash(self):
        env = {"poller___wrapper__threads": "2"}
        result = generate_config.parse_config(env)
        assert result == {"poller-wrapper": {"threads": 2}}

    def test_boolean_conversion(self):
        env = {"enabled": "true", "disabled": "false"}
        result = generate_config.parse_config(env)
        assert result == {"enabled": True, "disabled": False}

    def test_combined_features(self):
        env = {
            "db_host": "mysql",
            "ping__retries": "5",
            "poller___wrapper__threads": "2",
            "bad_if__0": "docker0",
            "auth__enabled": "true",
        }
        result = generate_config.parse_config(env)
        expected = {
            "db_host": "mysql",
            "ping": {"retries": 5},
            "poller-wrapper": {"threads": 2},
            "bad_if": {0: "docker0"},
            "auth": {"enabled": True},
        }
        assert result == expected


class TestToPhpValue:
    def test_boolean_true(self):
        assert generate_config.to_php_value(True) == "TRUE"

    def test_boolean_false(self):
        assert generate_config.to_php_value(False) == "FALSE"

    def test_integer(self):
        assert generate_config.to_php_value(42) == "42"

    def test_string(self):
        assert generate_config.to_php_value("hello") == "'hello'"

    def test_string_with_quotes(self):
        assert generate_config.to_php_value("it's") == "'it\\'s'"

    def test_string_with_backslash(self):
        assert generate_config.to_php_value("path\\to") == "'path\\\\to'"

    def test_empty_dict(self):
        assert generate_config.to_php_value({}) == "array()"

    def test_simple_dict(self):
        result = generate_config.to_php_value({"key": "value"})
        assert "'key' => 'value'" in result
        assert result.startswith("array(")
        assert result.endswith(")")

    def test_dict_with_int_key(self):
        result = generate_config.to_php_value({0: "value"})
        assert "0 => 'value'" in result


class TestGeneratePhpConfig:
    def test_empty_config(self):
        result = generate_config.generate_php_config({})
        assert "<?php" in result
        assert "$customConfig = array();" in result
        assert "$config = array_replace_recursive($config, $customConfig);" in result

    def test_simple_config(self):
        result = generate_config.generate_php_config({"db_host": "mysql"})
        assert "<?php" in result
        assert "'db_host' => 'mysql'" in result


class TestIntegration:
    def test_full_pipeline(self):
        """Test the complete flow from env vars to PHP output."""
        env = {
            "OBSERVIUM__db_host": "mariadb",
            "OBSERVIUM__db_name": "observium",
            "OBSERVIUM__ping__retries": "5",
            "OBSERVIUM__poller___wrapper__threads": "2",
            "OBSERVIUM__bad_if__0": "docker0",
            "OBSERVIUM__bad_if__1": "lo",
            "OBSERVIUM__auth__enabled": "true",
        }
        with patch.dict(os.environ, env, clear=True):
            env_vars = generate_config.get_env_by_prefix("OBSERVIUM__")
            config = generate_config.parse_config(env_vars)
            php_output = generate_config.generate_php_config(config)

            assert "<?php" in php_output
            assert "'db_host' => 'mariadb'" in php_output
            assert "'db_name' => 'observium'" in php_output
            assert "'retries' => 5" in php_output
            assert "'poller-wrapper'" in php_output
            assert "'threads' => 2" in php_output
            assert "0 => 'docker0'" in php_output
            assert "1 => 'lo'" in php_output
            assert "'enabled' => TRUE" in php_output
            assert "array_replace_recursive" in php_output


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
