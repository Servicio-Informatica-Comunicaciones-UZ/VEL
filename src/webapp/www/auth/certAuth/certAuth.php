<?php


//Default language: English
mmSetLang(mmIniStr('en'),'en');






//If invoked with 'sid' parameter containing a session token
//identifier, prints the serialized session object for that token and
//dies
if ($sid=$_GET['sid']) {
    
    //This operation must be called only through backchannel
    //connections
    
    //Access control list. Only authorised SPs can request
    //For this purpose, only localhost
    $whitelist = array(
        '127.0.0.1',
        '::1',
        '###***ownIP***###'
    );
    
    //($_SERVER['SERVER_ADDR'] != $_SERVER['REMOTE_ADDR'])
    if(!in_array($_SERVER['REMOTE_ADDR'], $whitelist)){
        http_response_code(401); //Unauthorised
        exit;
    }
    
    
    session_id($sid);
    session_start();
    
    echo serialize($_SESSION);

    session_destroy();
    session_unset();
    
    die();
}







////// Perform the authentication


//First access, start a new session
session_start();


//Redirect request to SSL (in the example, on non-standard port 444),
//so it can receive a client certificate. Not needed here as we do
//this on Apache
//if ($_SERVER['SERVER_PORT'] != 444) {
//  header('Location: https://'.$_SERVER['HTTP_HOST'].':444'.$_SERVER['SCRIPT_NAME'].'?'.$_SERVER['QUERY_STRING']);
//  die();
//}



//Get the client certificate presented with the connection
//[requires SSLOptions +StdEnvVars +ExportCertData ]
$cert = $_SERVER['SSL_CLIENT_CERT'];

//Copy the client certificate to session
$x509 = & $_SESSION['x509_info'];
$x509['certificado'] = $cert;



//No certificate presented. Abort.
if (!$cert) {
    session_destroy();
    session_unset();

    #If client passes an error page, redirect there
    $errorPage = $_GET['error'];
    if ($errorPage)
        header("Location: $errorPage");
    
    #Show own error page
    die('<h1>'.__('No certificate provided.'.'<h1>'));
}


//Parse the client certificate
$prs = openssl_x509_parse($cert);


//Get the e-mail address to session
$email = $prs['subject']['emailAddress'];
if ( ! $email) {
    $email = $prs['extensions']['subjectAltName'];
    preg_match('/email: *([^,]*)/', $email, $ma);
    $email = $ma[1];
}
$x509['email'] = $email;


//Get the Common Name
$cn = $prs['subject']['CN'];






//Try to extract the user ID number  // TODO refine using user certificates as example

//Search for the string NIF
$dni = preg_replace('/.*NIF[: ] */','', $cn);
//If not found (replace had no effect), it should be in the serial number
if ($dni == $cn)
    $dni = $prs['subject']['serialNumber'];

//Store it in session
$x509['DNI'] = $dni;






//Build the return destination (different methods):

//Returns to the URL specified by the SP, passes the session token so
//info can be retrieved through backchannel [we use this]
$url = $_GET['reto'];
if ($url){
    $reto = 'reto_auth='.urlencode('?sid='.session_id());
    header("Location: $url$reto");
}

//Redirect back to the SP, session is shared and info will be read. Same server only
else if ($ret=$_GET['dirAuth'])
    header("Location: $ret");

// Just print the certificate
else {
    header("Content-type: text/plain");
    print_r($prs);
    print_r($x509);
}









// A short library for i18n
/* mmGetText start */

function mmIniStr($my) {
    global $lang_lang;
    $lang_lang=array(
        'No certificate provided.' => array(
            'ca' => 'No presenta certificats',
            'es' => 'No presenta ningún certificado', ),
        'Personal ID Number not found on the certificate.' => array(
            'ca' => 'No es troba cap NIF al certificat',
            'es' => 'No se encuentra el NIF en el certificado', ),
    );
    $idios[$my]=1;
    foreach($lang_lang as $st =>$tra)
        foreach($tra as $la => $kk)
        $idios[$la]=2;
    return $idios;
}

function mmSetLang($langs,$def) {
    global $whichLang, $altLang;
    $altLang=$def;
    if (!$langs[$altLang])
        $altLang="";
    if (!$whichLang) { //force?
        foreach(preg_split('/,/',
        preg_replace('/;.*/','',
        strtolower($_SERVER['HTTP_ACCEPT_LANGUAGE'])))
        as $lang) {
            $lang=substr($lang,0,2);
            if ($langs[$lang]) {
                $whichLang=$lang;
                break;
            }
        }
    }
    if (!$whichLang) {
        $whichLang=substr(setlocale(LC_ALL,""),0,2);
    }
    // si nada coincide asume $altLang
    if (strlen($whichLang) != 2)
        $whichLang=$altLang;
    if ($langs[$whichLang] == 1)
        $altLang="";
}

function forceLangSession($lang) {
    global $whichLang;
    if ($lang)
        $_SESSION["wichLang"]=$lang;
    if ($lang=$_SESSION["wichLang"])
        $whichLang=$lang;
}

function __($mes,$lang="") {
    global $lang_lang, $whichLang, $altLang;
    $idi=$lang or $idi=$whichLang;
    if (strlen($mes) > 70)
        $imes=substr($mes,0,58)."-".sprintf("%u",crc32($mes));
    else
        $imes=$mes;
    $mm=$lang_lang[$imes][$idi];
    if ($mm)
        return $mm;
    else {
        $mm=$lang_lang[$imes][$altLang];
        if ($mm)
            return $mm;
        else
            return $mes;
    }
}

/* mmGetText end */




