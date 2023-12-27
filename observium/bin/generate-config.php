<?php

function replaceTripleUnderscores($inputString) {
    $result = str_replace('___', '-', $inputString);
    return $result;
}

function getEnvVariablesByPrefix($prefix) {
    $result = [];
    foreach (getenv() as $key => $value) {
        if (strpos($key, $prefix) === 0) {
            $result[] = substr($key, strlen($prefix)) . '=' . $value;
        }
    }
    sort($result);
    return replaceTripleUnderscores($result);
}

function convertValue($value) {
    $lowercaseValue = strtolower($value);
    if ($lowercaseValue === 'true' || $lowercaseValue === 'false') {
        return ($lowercaseValue === 'true');
    } elseif (is_numeric($value)) {
        return intval($value);
    } else {
        return $value;
    }
}

function parseConfig($configStrings, &$config) {
    foreach ($configStrings as $configString) {
        $parts = explode('=', $configString, 2);
        $keys = explode('__', $parts[0]);
        $currentConfig = &$config;

        foreach ($keys as $key) {
            if (is_numeric($key)) {
                $currentConfig = &$currentConfig[];
            } else {
                if (!isset($currentConfig[$key])) {
                    $currentConfig[$key] = [];
                }
                $currentConfig = &$currentConfig[$key];
            }
        }
        if (isset($parts[1])) {
            $currentConfig = convertValue($parts[1]);
        }
    }
}

$observiumVariables = getEnvVariablesByPrefix("OBSERVIUM__");
$config = [];
parseConfig($observiumVariables, $config);

$resultString = '$customConfig = ' . var_export($config, true) . ';';
echo "<?php " . PHP_EOL . $resultString . PHP_EOL;
echo '$config = array_replace_recursive($config, $customConfig);' . PHP_EOL;
