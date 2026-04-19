<?php
// Minimal session check - no framework bootstrap
include 'auth_config.php';

if( !empty( $_SESSION['user_role'] ) && $_SESSION['user_role'] > 0 ) {
    http_response_code(200);
	exit;
}

// anonymous - check content_id from URI
preg_match( '|/attachments/\d+/(\d+)/|', $_SERVER['REQUEST_URI'], $matches );

if( !empty( $matches[1] ) ) {
    $contentId = (int)$matches[1];
    try {
        $pdo = new PDO( $gBitDbHost, $gBitDbUser, $gBitDbPassword );
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM LIBERTY_CONTENT_ROLE_MAP 
             WHERE content_id = ?"
        );
        $stmt->execute( [$contentId] );
        if( $stmt->fetchColumn() == 0 ) {
            http_response_code( 200 );
		} else {
			http_response_code( 403 );
		}
    } catch( PDOException $e ) {
        // db failure - deny access safely
        http_response_code( 403 );
        exit;
    }
    exit;
}