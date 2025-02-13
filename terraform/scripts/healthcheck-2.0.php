<?php
header("Content-Type: text/plain");

// PHP Check
echo "PHP OK
";

// MySQL Check
$db_host = getenv("DB_HOST");
$db_user = getenv("DB_USER");
$db_pass = getenv("DB_PASSWORD");
$conn = mysqli_connect($db_host, $db_user, $db_pass);

if (!$conn) {
    http_response_code(500);
    echo "MySQL ERROR
";
    exit;
}
echo "MySQL OK
";
mysqli_close($conn);

// Redis Check
$redis = new Redis();
if (!$redis->connect(getenv("WP_REDIS_HOST"), getenv("WP_REDIS_PORT"))) {
    http_response_code(500);
    echo "Redis ERROR
";
    exit;
}
echo "Redis OK
";

// WordPress REST API Check
$api_url = "http://localhost/wp-json/wp/v2/posts";
$response = file_get_contents($api_url);
if ($response === FALSE) {
    http_response_code(500);
    echo "REST API ERROR
";
    exit;
}
echo "REST API OK
";

http_response_code(200);
exit;
