<?php
/**
 * Dynamically generated wp-config.php template
 * Rendered using `envsubst` inside deploy_wordpress.sh
 */

// ** Database settings ** //
define( 'DB_NAME',   '${DB_NAME}' );
define( 'DB_USER',   '${DB_USERNAME}' );
define( 'DB_PASSWORD', '${DB_PASSWORD}' );
define( 'DB_HOST',   '${DB_HOST}' );
define( 'DB_CHARSET',  'utf8' );
define( 'DB_COLLATE',  '' );

// ** Authentication Unique Keys and Salts ** //
// You can generate these using the WordPress.org secret-key service
// You can change these at any point in time to invalidate all existing cookies.
// Add each unique phrase on a new line.
// @link https://api.wordpress.org/secret-key/1.1/salt/ WordPress Secret Key Service
define( 'AUTH_KEY',          '${AUTH_KEY}' );
define( 'SECURE_AUTH_KEY',   '${SECURE_AUTH_KEY}' );
define( 'LOGGED_IN_KEY',     '${LOGGED_IN_KEY}' );
define( 'NONCE_KEY',         '${NONCE_KEY}' );
define( 'AUTH_SALT',         '${AUTH_SALT}' );
define( 'SECURE_AUTH_SALT',  '${SECURE_AUTH_SALT}' );
define( 'LOGGED_IN_SALT',    '${LOGGED_IN_SALT}' );
define( 'NONCE_SALT',        '${NONCE_SALT}' );

// ** Table prefix ** //
$table_prefix = 'wp_';

// ** Debugging mode ** //
// Change this to true to enable the display of notices during development.
// It is strongly recommended that you use WP_DEBUG in your development environment.
// For other WordPress debugging constants, visit:
// https://wordpress.org/support/article/debugging-in-wordpress/
define( 'WP_DEBUG', false );

/* --- ALB and HTTPS Support --- */
if ( isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https' ) {
    $_SERVER['HTTPS'] = 'on';
}
define( 'WP_HOME',   'http://${AWS_LB_DNS}' );
define( 'WP_SITEURL', 'http://${AWS_LB_DNS}' );

/* --- Disable WordPress automatic core updates --- */
define( 'WP_AUTO_UPDATE_CORE', false );
define( 'AUTOMATIC_UPDATER_DISABLED', true );

/* --- Redis Object Cache Configuration --- */
define( 'WP_REDIS_HOST',     '${REDIS_HOST}' );
define( 'WP_REDIS_PORT',     '${REDIS_PORT}' );
define( 'WP_REDIS_DATABASE', 0 );
define( 'WP_REDIS_SCHEME',   'tls' );
define( 'WP_CACHE',          true );

/* --- Additional Security Hardening --- */
define( 'DISALLOW_FILE_EDIT', true ); // Disables theme/plugin editor in admin panel

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';