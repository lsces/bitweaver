<?php

global $gBitInstaller;

// Re-assert required_package here too (not just bit_setup_inc.php) - this is a plain runtime
// directory, not a real content package, and shouldn't ever be selectable/uninstallable from the
// installer's package list regardless of which scan pass populates $gBitInstaller->mPackages.
$gBitInstaller->registerPackage( [
	'package_name'      => STORAGE_PKG_NAME,
	'package_path'      => dirname( dirname( __FILE__ ) ).'/',
	'required_package'  => true,
] );

$gBitInstaller->registerPackageInfo( STORAGE_PKG_NAME, [
	'description' => 'Directory to store information to the file system.',
	'license' => '<a href="http://www.gnu.org/licenses/licenses.html#LGPL">LGPL</a>',
] );

