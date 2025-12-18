<?php
header("Content-Type: text/plain; charset=UTF-8");

# Load constants like DB_HOST, DB_USER, etc.
require_once('/var/www/html/wp-config.php');

# --- Output helper --- #
# ALB expects a fast and deterministic response.
# We print a simple checklist and return HTTP 500 on the first failure.
fail:
function fail(string $msg): void {
    http_response_code(500);
    echo $msg . "\n";
    exit;
}

echo "PHP OK\n";

# --- MySQL Check with SSL --- #

if (!defined('DB_HOST') || !defined('DB_USER') || !defined('DB_PASSWORD') || !defined('DB_NAME')) {
    fail("MySQL ERROR: DB_* constants are missing");
}

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
    $conn = mysqli_init();

    # Keep SSL enabled for RDS (CA bundle must exist if require_secure_transport=ON).
    $ca_bundle = '/etc/ssl/certs/rds-combined-ca-bundle.pem';
    if (!file_exists($ca_bundle)) {
        error_log("healthcheck: RDS CA bundle not found: {$ca_bundle}");
        fail("MySQL ERROR");
    }

    # Prevent long hangs on connect (ALB healthcheck must be fast).
    $conn->options(MYSQLI_OPT_CONNECT_TIMEOUT, 2);

    $conn->ssl_set(NULL, NULL, $ca_bundle, NULL, NULL);
    $conn->real_connect(
        DB_HOST,
        DB_USER,
        DB_PASSWORD,
        DB_NAME,
        defined('DB_PORT') ? (int)DB_PORT : 3306,
        NULL,
        MYSQLI_CLIENT_SSL
    );

    # Minimal query to ensure the DB can execute statements.
    $conn->query("SELECT 1");

    echo "MySQL OK\n";
    $conn->close();
} catch (mysqli_sql_exception $e) {
    error_log("healthcheck: MySQL ERROR: " . $e->getMessage());
    fail("MySQL ERROR");
}

# --- Redis Check --- #

# If WP_REDIS_HOST is not defined, we skip the Redis check entirely, assuming it's not used.
if (defined('WP_REDIS_HOST')) {

    if (!defined('WP_REDIS_PORT')) {
        fail("Redis ERROR: WP_REDIS_PORT is missing");
    }

    $redis = new Redis();
    try {
        # Use host only (Redis::connect expects host, not URI).
        $redis_host = WP_REDIS_HOST;

        # If WP_REDIS_SCHEME is set to 'tls', prepend it (verified: TLS works in your environment).
        if (defined('WP_REDIS_SCHEME') && WP_REDIS_SCHEME === 'tls') {
            $redis_host = 'tls://' . $redis_host;
        }

        # Connect to Redis (short timeout to avoid hanging healthchecks).
        if (!$redis->connect($redis_host, (int)WP_REDIS_PORT, 2.0)) {
            throw new RedisException("Could not connect to Redis.");
        }

        # Authenticate only if a password is defined.
        if (defined('WP_REDIS_PASSWORD') && WP_REDIS_PASSWORD) {
            if (!$redis->auth(WP_REDIS_PASSWORD)) {
                throw new RedisException("Authentication failed.");
            }
        }

        # Minimal command to ensure Redis responds.
        $redis->ping();

        echo "Redis OK\n";
    } catch (RedisException $e) {
        error_log("healthcheck: Redis ERROR: " . $e->getMessage());
        fail("Redis ERROR");
    }

} else {
    echo "Redis SKIP\n";
}

# --- WordPress REST API Check --- #

# Use rest_route to avoid dependency on Nginx rewrite/permalinks (/wp-json may 301 or return HTML).
$api_url = "http://127.0.0.1/?rest_route=/wp/v2/posts";

# Add a short timeout to prevent healthcheck hangs.
$ctx = stream_context_create([
    'http' => [
        'timeout' => 2,
        'ignore_errors' => true,
    ]
]);

$response = @file_get_contents($api_url, false, $ctx);
if ($response === false) {
    fail("REST API ERROR");
}

# Minimal validation: ensure response looks like JSON (avoid HTML error pages with 200).
$trim = ltrim($response);
if ($trim === '' || ($trim[0] !== '[' && $trim[0] !== '{')) {
    fail("REST API ERROR");
}

echo "REST API OK\n";
exit;

# --- Notes --- #
# This healthcheck file is used by the ALB (Application Load Balancer)
# to determine if the EC2 instance is healthy.
#
# What it checks:
#   - PHP execution (script runs)
#   - MySQL database connectivity using DB_* constants from wp-config.php (with SSL)
#   - Redis connectivity using WP_REDIS_* constants (only if WP_REDIS_HOST is defined; supports TLS via WP_REDIS_SCHEME=tls)
#   - WordPress REST API availability via localhost (via rest_route to avoid permalink/rewrite dependency)
#
# Security & Independence:
#   - Does NOT rely on environment variables during runtime
#   - wp-config.php is the only source of secrets (DB, Redis)
#
# Compatibility:
#   - Tested with PHP 8.3 with mysqli and redis extensions
#   - Supports MySQL (with require_secure_transport=ON)
#   - Redis must be accessible over TCP (TLS supported when WP_REDIS_SCHEME=tls)
#
# Other:
#   - REST API check may fail if WordPress is not fully installed yet
#   - This script is intended to be used *after* WordPress deployment
#
# Deployment:
#   - It is uploaded to the S3 "scripts" bucket and downloaded during EC2 provisioning via user-data script
#   - Ensure the object exists at the specified S3 path before instance launch
