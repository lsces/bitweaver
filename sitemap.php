<?php
/**
 * Sitemap index — discovers active packages with a sitemap.php and lists them.
 * Served via nginx rewrite of /sitemap.xml -> /sitemap.php
 *
 * @package kernel
 */

require_once 'kernel/includes/setup_inc.php';

$gSiteMapIndex = [];
foreach( $gBitSystem->mPackages as $package ) {
	if( !empty( $package['active_switch'] ) && file_exists( $package['path'].'sitemap.php' ) ) {
		$gSiteMapIndex[] = [
			'loc'     => BIT_BASE_URI . $package['url'] . 'sitemap.php',
			'lastmod' => date( 'Y-m-d' ),
		];
	}
}

$gBitSmarty->assign( 'gSiteMapIndex', $gSiteMapIndex );
$gBitThemes->setFormatHeader( 'xml' );
header( 'Content-Type: application/xml; charset=utf-8' );
$gBitSystem->display( 'bitpackage:kernel/sitemapindex.tpl' );
