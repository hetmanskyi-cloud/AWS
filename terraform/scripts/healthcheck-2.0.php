<?php
header("Content-Type: text/plain");

// Function to retrieve an environment variable with a fallback to /etc/environment
function get_env_var($key) {
    $value = getenv($key);
    if ($value === false || $value === '') {
        $contents = @file_get_contents('/etc/environment');
        if ($contents !== false && preg_match('/' . preg_quote($key, '/') . '="([^"]+)"/', $contents, $matches)) {
            $value = $matches[1];
        }
    }
    return $value;
}

// PHP Check
echo "PHP OK\n";

// MySQL Check
$db_host = get_env_var("DB_HOST");
$db_user = get_env_var("DB_USER");
$db_pass = get_env_var("DB_PASSWORD");
$db_name = get_env_var("DB_NAME");

if (!$db_host) {
    http_response_code(500);
    echo "DB_HOST environment variable is not set.\n";
    exit;
}

// Enable MySQLi exceptions
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
    $conn = mysqli_connect($db_host, $db_user, $db_pass, $db_name);
    echo "MySQL OK\n";
    mysqli_close($conn);
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    echo "MySQL ERROR: " . $e->getMessage() . "\n";
    exit;
}

// Redis Check
$redis_host = get_env_var("REDIS_HOST");
$redis_port = get_env_var("REDIS_PORT");

if (!$redis_host) {
    http_response_code(500);
    echo "REDIS_HOST environment variable is not set.\n";
    exit;
}

$redis = new Redis();
if (!$redis->connect($redis_host, $redis_port)) {
    http_response_code(500);
    echo "Redis ERROR\n";
    exit;
}
echo "Redis OK\n";

// WordPress REST API Check
$api_url = "http://localhost/wp-json/wp/v2/posts";
$response = @file_get_contents($api_url);
if ($response === FALSE) {
    http_response_code(500);
    echo "REST API ERROR\n";
    exit;
}
echo "REST API OK\n";

http_response_code(200);
exit;