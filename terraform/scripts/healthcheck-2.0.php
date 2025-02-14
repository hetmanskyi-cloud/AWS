<?php
header("Content-Type: text/plain");

// PHP Check
echo "PHP OK\n";

// MySQL Check
$db_host = getenv("DB_HOST");
$db_user = getenv("DB_USER");
$db_pass = getenv("DB_PASSWORD");
$db_name = getenv("DB_NAME");

// MySQL Connection
$conn = mysqli_connect($db_host, $db_user, $db_pass, $db_name);
if (!$conn) {
    http_response_code(500);
    echo "MySQL ERROR\n";
    exit;
}
echo "MySQL OK\n";
mysqli_close($conn);

// Redis Check
$redis_host = getenv("REDIS_HOST");
$redis_port = getenv("REDIS_PORT");

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