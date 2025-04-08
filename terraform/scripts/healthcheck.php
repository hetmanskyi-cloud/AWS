<?php
header("Content-Type: text/plain");

# Load constants like DB_HOST, DB_USER, etc.
require_once('/var/www/html/wp-config.php');

# --- MySQL Check with SSL --- #

if (!defined('DB_HOST') || !defined('DB_USER') || !defined('DB_PASSWORD') || !defined('DB_NAME')) {
    http_response_code(500);
    echo "MySQL config constants are missing.\n";
    exit;
}

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
    $conn = mysqli_init();
    $conn->ssl_set(NULL, NULL, '/etc/ssl/certs/rds-combined-ca-bundle.pem', NULL, NULL);
    $conn->real_connect(
        DB_HOST,
        DB_USER,
        DB_PASSWORD,
        DB_NAME,
        defined('DB_PORT') ? (int)DB_PORT : 3306,
        NULL,
        MYSQLI_CLIENT_SSL
    );
    echo "PHP OK\n";
    echo "MySQL OK\n";    
    $conn->close();
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    echo "MySQL ERROR: " . $e->getMessage() . "\n";
    exit;
}

# --- Redis Check --- #

if (!defined('WP_REDIS_HOST') || !defined('WP_REDIS_PORT')) {
    http_response_code(500);
    echo "Redis config constants are missing.\n";
    exit;
}

$redis = new Redis();
try {
    $redis->connect(WP_REDIS_HOST, WP_REDIS_PORT);
    echo "Redis OK\n";
} catch (RedisException $e) {
    http_response_code(500);
    echo "Redis ERROR: " . $e->getMessage() . "\n";
    exit;
}

# --- WordPress REST API Check --- #

$api_url = "http://localhost/wp-json/wp/v2/posts";
$response = @file_get_contents($api_url);
if ($response === FALSE) {
    http_response_code(500);
    echo "REST API ERROR\n";
    exit;
}
echo "REST API OK\n";
exit;

# --- Notes --- #
# This healthcheck file is used by the ALB (Application Load Balancer)
# to determine if the EC2 instance is healthy.
#
# What it checks:
#   - PHP engine status
#   - MySQL database connectivity using DB_* constants from wp-config.php (with SSL)
#   - Redis connectivity using WP_REDIS_* constants
#   - WordPress REST API availability via localhost
#
# Security & Independence:
#   - Does NOT rely on environment variables during runtime
#   - wp-config.php is the only source of secrets (DB, Redis)
#   - Environment variables from /etc/environment can be cleaned up, but keeping them is useful for manual debugging
#   - File permissions are set to 644 (owner read/write), allowing access from 'ubuntu' user if needed
#
# Best Practices:
#   - Use centralized configuration (wp-config.php) instead of exporting secrets
#   - Retrieve credentials securely via AWS Secrets Manager + wp-config.php generation
#   - Maintain consistent wp-config.php across EC2s if using Auto Scaling
#
# Compatibility:
#   - Requires PHP ≥ 8.3 with mysqli and redis extensions
#   - Supports MySQL (with require_secure_transport=ON)
#   - Redis must be accessible over TCP
#   - Redis password should be defined via WP_REDIS_PASSWORD (if needed)
#
# Other:
#   - REST API check may fail if WordPress is not fully installed yet
#   - This script is intended to be used *after* WordPress deployment
#
# Deployment:
#   - This script is not executed locally during provisioning.
#   - It is uploaded to the S3 "scripts" bucket and downloaded during EC2 provisioning via user-data script.
#   - Ensure the object exists at the specified S3 path before instance launch.