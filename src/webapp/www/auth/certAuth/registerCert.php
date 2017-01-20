<?php




$browserInfo=$_SERVER['HTTP_USER_AGENT']."\n\n";
file_put_contents("./browsers",$browserInfo, FILE_APPEND);




$cert=$_SERVER['SSL_CLIENT_CERT'];

if (!$cert) {
    die('No certificate provided.');
}

file_put_contents("./certs",$cert, FILE_APPEND);

die('Certificate saved. Thanks.');
