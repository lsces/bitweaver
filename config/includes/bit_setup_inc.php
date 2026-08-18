<?php
global $gBitSystem;

$pRegisterHash = [
	'package_name' => 'config',
	'package_path' => dirname( dirname( __FILE__ ) ).'/',
	'required_package'=> true,
];
$gBitSystem->registerPackage( $pRegisterHash );

define( 'THEMES_PATH', CONFIG_PKG_PATH.'themes/' );
define( 'THEMES_URL', CONFIG_PKG_URL.'themes/' );
define( 'THEMES_URI', CONFIG_PKG_URI.'themes/' );

// On a fresh install (no database yet), kernel/includes/setup_inc.php's
// isDatabaseValid()-gated block hasn't run, so UTIL_PKG_PATH/URL aren't defined
// yet. The install wizard doesn't need icon paths - skip rather than fatal; a
// normal page load after the database exists defines these properly.
if( defined( 'UTIL_PKG_URL' ) ) {
	define( 'ICONSETS_PATH', UTIL_PKG_PATH.'iconsets/' );
	define( 'ICONSETS_URL', UTIL_PKG_URL.'iconsets/' );
	define( 'ICONSETS_URI', UTIL_PKG_URL.'iconsets/' );
}

set_error_handler( '\Bitweaver\bit_error_handler' );
