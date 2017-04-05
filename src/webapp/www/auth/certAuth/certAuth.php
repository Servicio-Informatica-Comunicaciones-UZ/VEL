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



////Get the Common Name
//$cn = $prs['subject']['CN'];
//
//Try to extract the user ID number
//
////Search for the string NIF
//$dni = preg_replace('/.*NIF[: ] */','', $cn);
////If not found (replace had no effect), it should be in the serial number
//if ($dni == $cn)
//    $dni = $prs['subject']['serialNumber'];


$parser = guessParser($prs['issuer'], false);

$dni = getDNI($prs,$parser);

if (isDNI($dni)){
    //Store it in session
    $x509['DNI'] = $dni;
}
else{
    $x509['DNI'] = '';  // TODO check that this won't break anything
}





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








//////////////////////Parsing lib



#List of accepted certificate formats, structured by issuer country,
#organisation, organisation unit and common name and the parser they
#need to extract the DNI
$PARSEFORMATS = array (
    
    'ES' => array (

        'ACCV' => array(

            'PKIACCV' => array(
                'ACCVCA-120' => 'serial',
            ),
        ),
        
        'FNMT' => array(
            
            'FNMT CLASE 2 CA' => 'fnmt-1',
        ),
        
        'FNMT-RCM' => array(
            
            'CERES' => array(
                
                'AC FNMT USUARIOS' => 'fnmt-rep',
                'AC REPRESENTACIÓN' => 'fnmt-rep',
           ),
        ),
        
        'DIRECCION GENERAL DE LA POLICIA' => array(

            'DNIE' => array(
                
                'AC DNIE 001' => 'serial',
                'AC DNIE 002' => 'serial',
                'AC DNIE 003' => 'serial',
            ),
        ),
        
    ),
    
    
);



function guessParser ($issuer, $strict=false) {

    global $PARSEFORMATS;
    
    $parser='default';
    $currentDict = $PARSEFORMATS;
    foreach (array('C','O','OU','CN') as $level){


        
        //Current level not in issuer
        if (!array_key_exists($level,$issuer)){
            
            //If current level has a wildcard, use it
            if (array_key_exists('*',$currentDict)){
                $currentDict = $currentDict['*'];
                continue;
            }
            //Otherwise, give up
            else{
                //echo "level '$level' not in issuer, setting empty string";
                break;
            }
        }

        $levelKey = mb_strtoupper($issuer[$level]);
        //Current level value not accepted, give up
        if (!array_key_exists($levelKey,$currentDict)){
            //echo "level '$level' value '".$levelKey."' not accepted\n";
            break;
        }
        
        //Reached a leaf
        if ( ! is_array($currentDict[$levelKey])){
            
            //This is the parser to be returned
            if( is_string($currentDict[$levelKey])
                && $currentDict[$levelKey] != ''){
                //echo "found a string leaf at level -$level- valued -$levelKey-: -"
                //    .$currentDict[$levelKey]."-\n";
                $parser = $currentDict[$levelKey];
                break;
            }
            //Bad leaf (this error should only happen in dev)
            else{
                //echo "Parser tree error. Found a leaf node which is not a ".
                //    "string or empty at level -$level- valued -$levelKey-\n";
                return '';
            }
        }
        
        //Keep going down
        $currentDict = $currentDict[$levelKey];
    }

    //On strict mode, default is not accepted. CA must appear explicitly on the list
    if($strict && $parser == "default")
        $parser = '';
    
    return $parser;
}


//Returns DNI number followed by checksum letter, no spaces or separators.
function getDNI($cert,$parser){
    
    
    
 
    switch($parser){
        
    case 'serial':
        //Just the subject/serialNumber field, whole string.
        return $cert['subject']['serialNumber'];
        break;
        
    case 'fnmt-1':
        //A substring at the end of the subject/CN field, everything after "- NIF ".
        return preg_replace('/.*NIF[: ] */', '', $cert['subject']['CN']);
        break;
        
    case 'fnmt-rep':
        //Just the subject/serialNumber field, everything after "IDCES-".
        return preg_replace('/.*IDCES-/', '', $cert['subject']['serialNumber']);
        break;
        
    case 'default' :
        return findDNI($cert);
        break;
    }
    
}




//Do a heuristic search for a DNI
function findDNI($cert){
    $dnis = array();
    
    //Search these fields if they exist, in this order.
    $searchFields = array();
    
    if (array_key_exists('serialNumber',$cert['subject'])
    && is_string($cert['subject']['serialNumber']))
        $searchFields []= $cert['subject']['serialNumber'];
    
    
    if (array_key_exists('CN',$cert['subject'])
    && is_string($cert['subject']['CN']))
        $searchFields []= $cert['subject']['CN'];

    if (array_key_exists('subjectAltName',$cert['extensions'])
    && is_string($cert['extensions']['subjectAltName']))
        $searchFields []= $cert['extensions']['subjectAltName'];
    
    
    
    foreach ($searchFields as $searchField) {
        
        //Search for XYZletter?+digits+letter, and possible separators
        $matches=array();
        if (! preg_match("/[xyzXYZ]?[-_.,;| ]?[0-9]{7,8}[-_.,;| ]?[a-zA-Z]/",$searchField,$matches))
            continue;
        
        
        //For each match, check if valid DNI
        foreach ($matches as $key => $match){
            if(!isDNI($match))
                unset($matches[$key]);
            
            $dnis []= harmoniseDNI($match);
        }
        
        //Remove duplicate matches
        $dnis = array_unique($dnis);
        
        //If just one DNI found, we are done
        if (count($dnis) == 1)
            break;
        
        //If more than one DNI already found, can't determine which
        //would it be, so return none
        if (count($dnis) > 1)
            return "";
    }
    
    return $dnis[0];
}



//Calculate DNI checksum letter
function getDNIControlDigit($dni) {
    return substr("TRWAGMYFPDXBNJZSQVHLCKE"
                  ,strtr($dni,"XYZ","012")%23
                  ,1);
}



//Remove any spaces or separators (-_.,;/\|TAB LF), letters to
//uppercase
function harmoniseDNI($dni){
    return mb_strtoupper(preg_replace("/[-_.,;\/|\\\ \t\n]+/","",$dni));
}




function isDNI($dni,$checksum=true){
    
    $hdni =  harmoniseDNI($dni);
    
    //Check format: letter X,Y,Z + 7 digits + letter or 8 digits + letter
    if (! preg_match("/^([XYZ]?[0-9]{7}[A-Z]|[0-9]{8}[A-Z])$/",$hdni))
        return false;
    
    if($checksum){
        //Trim the last letter
        $number = substr($hdni,0,-1);
        
        //Calculate control letter
        $letter = getDNIControlDigit($number);
        
        //If the given DNI equals the number and the calculated letter
        if ($number.$letter === $hdni)
            return true;   
        return false;
    }
    
    return true;
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




