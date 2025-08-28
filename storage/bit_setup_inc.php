<?php
global $gBitSystem;

$pRegisterHash = array(
	'package_name' => 'storage',
	'package_path' => dirname( __FILE__ ).'/',
	'required_package'=> true,
);
$gBitSystem->registerPackage( $pRegisterHash );
?>
