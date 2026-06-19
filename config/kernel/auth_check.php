<?php
// Minimal session check - no framework bootstrap
include 'auth_config.php';

preg_match( '|/attachments/\d+/(\d+)/|', $_SERVER['REQUEST_URI'], $matches );

if( !empty( $matches[1] ) ) {
	$contentId = (int)$matches[1];
	try {
		$pdo = new PDO( $gBitDbHost, $gBitDbUser, $gBitDbPassword );

		// get the role restriction for this content, if any
		$stmt = $pdo->prepare( "SELECT ROLE_ID FROM LIBERTY_CONTENT_ROLE_MAP WHERE CONTENT_ID = ?" );
		$stmt->execute( [$contentId] );
		$requiredRoleId = $stmt->fetchColumn();

		if( $requiredRoleId === false ) {
			// no restriction - public content
			http_response_code( 200 );
		} elseif( in_array( (int)$requiredRoleId, $_SESSION['user_role'] ?? [] ) ) {
			http_response_code( 200 );
		} else {
			http_response_code( 403 );
		}
	} catch( PDOException $e ) {
		http_response_code( 403 );
	}
	exit;
}

// no content_id in URI - nothing to restrict
http_response_code( 200 );