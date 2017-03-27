<?php

/*
  Copyright (c) 2009 Manuel Mollar
  mm AT nisu.org
  http://voto.nisu.org/
  This software is released under a GPL license
  http://www.opensource.org/licenses/gpl-2.0.php

*/

  // init {{{ // 13 lineas de codigo de depuracion eliminadas por mkInstaller

  get_magic_quotes_gpc() and die();
  error_reporting(E_ALL ^ E_NOTICE);
  if (!function_exists('apc_store')) { // {{{
    function apc_store($msg) { }
    function apc_fetch($msg) { }
    function apc_delete($msg) { }
  } // }}}


  if ($i=$_GET['upmon']) {
    if ($t=apc_fetch("t$i"))
      printf('p%02d%%',intval(apc_fetch("c$i")*100/$t));
    else if ($t=apc_fetch("l$i"))
      printf('l%02d%%',intval(apc_fetch("c$i")*100/$t));
    else {
      $x=apc_fetch("upload_$i");
      if ($t=$x["total"])
	printf('c%02d%%',intval($x["current"]*100/$t));
      else echo 'e';
    }
    die();
  }

  //!
  $ver='';

  $escr=$_SERVER['SCRIPT_NAME'];
  $hst=$dir="http".(($_SERVER['HTTPS']) ? 's' : '')."://".$_SERVER["HTTP_HOST"];
  if (($dnm=dirname($escr)) != '/')
    $dir.=$dnm;

  session_start();

  if ($_GET['cred']) {
    header('Content-type: text/html; charset=utf-8');
    die('<html><header><title>'.__('Acerca').'</title>
	<style>#g { border: 0.5em solid #ffcc00; box-sizing: border-box; -moz-box-sizing: border-box; -webkit-box-sizing: border-box;
	border-radius: 1em; -moz-border-radius: 1em; -webkit-border-radius: 1em; padding:  1em; position: relative; float:left; white-space: nowrap; }
	a:link, a:visited, a:active { text-decoration: none; color: blue; }
	</style></header>
	<body onblur="setTimeout(\'window.close()\',500);" onmouseout="e=event||window.event; s=e.srcElement||e.target; if ((e.clientX<0) || (e.clientY<0) || (e.clientX>an) || (e.clientY>al)) window.close();" onload="ol(); an=document.body.scrollWidth; al=document.body.scrollHeight;"><div id=g><h3><img align=left border=0 src="?getim=8">'.
	__('Sistema de voto telemático confiable').'<br><a target=_blank href="http://teclab.uji.es">TecLab</a>
	<br><a target=_blank href="http://www.uji.es">Universitat Jaume I</a></h3><br clear=left>
	<a href="http://voto.nisu.org" target=_blank>'.__('Diseñado</a> por M. Mollar &lt;<a href="mailto:mm@nisu.org">mm@nisu.org</a>&gt;<br>
	Sistema autónomo programado por F. Aragó &lt;<a href="mailto:paco@nisu.org">paco@nisu.org</a>&gt;<br>Interfaz programada por M. Mollar
	<p>Sistema de anonimato eSurvey<br><a href="http://esurvey.nisu.org" target=_blank>Diseñado</a> y programado por M. Mollar
	<p>Financiado por:').
	'<br><img src="?getim=6"><img src="?getim=2"><img src="?getim=3"><img src="?getim=4">
	</div>
	<script>function ol() { p=document.body; h=hi=p.scrollHeight; w=wi=p.scrollWidth; i=0; rsz10(); } function rsz10() { var ot=false; if (wi>p.clientWidth+10) { w+=10; window.resizeTo(w,h); ot=true; } if (hi>p.clientHeight+10) { h+=10; resizeTo(w,h); ot=true; } if (ot && (i++<100)) setTimeout("rsz10()",1);  }</script></body>');
  }

  //!
  $myHost='';
  //!
  $myUser='';
  //!
  $myPass='';
  //!
  $myDb='';
  //!
  $secr='';
  @mysql_connect($myHost,$myUser,$myPass) or die('Db');
  @mysql_select_db($myDb) or die('Db');

  if ($argv[1] == 'setpwd' and $us=mysql_real_escape_string($argv[2]) and $pw=$argv[3]) {
    mysql_query("update eVotPob set pwd='".genPwd($pw)."', clId='-1', oIP=-1, cadPw=0 where us='$us'");
    echo __('Contraseñas cambiadas').': '.mysql_affected_rows()."\n";
    die();
  }

  //!
  $klng='';

  $now=time();
  $lg=$_REQUEST['lang'];
  forceLangSession($lg);
  mmSetLang($idios=mmIniStr('es'),'es');
  setlocale(LC_ALL,array($whichLang."_ES.UTF-8","en_UK.UTF-8","en_US.UTF-8"));
  list($tiz,$infUrl,$css,$mante,$dAuth,$domdef,$pasSMS)=mysql_fetch_row(mysql_query("select TZ,infUrl,css,mante,dAuth,domdef,pasSMS from eVotDat"));
  date_default_timezone_set($tiz);
  $lngs=''; $tlngs=count($idios)-1;
  foreach($idios as $idio=>$dummy)
    if ($tlngs > 2)
      $lngs.=" <option value=\"$idio\" style=\"background-image:url(?getim=flag-$idio&e=1); background-repeat: no-repeat;\"".(($idio == $whichLang)?' selected':'')."> </option>";
    else
      if ($idio != $whichLang)
	$lngs.=" <a class=hlang href=\"?lang=$idio\"><img border=0 src=\"?getim=flag-$idio&e=1\" alt=\"$idio\"></a>";
  if ($tlngs > 2)
    $lngs="<img align=top id=curlg src=\"?getim=flag-$whichLang&e=1\" alt=$whichLang><select style=\"opacity: 0; position: relative; left: -1em; background-image:url(?getim=flag-$whichLang&e=1); background-repeat: no-repeat;\" onchange=\"location.href='$hst$escr?lang='+this.options[this.selectedIndex].value;\" name=selLang>$lngs</select>";
  $css="<style type=\"text/css\" id=elcss>$css</style>";
  $htcab='<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html><head><title>'.__('Voto telemático').
	"</title>$css</head>";
  $htban="<div id=htban><div id=lngs>$lngs</div><div id=ayud style=\"z-index:99999\"><a href=\"$infUrl\" target=\"_blank\"><div id=iayud style=\"z-index:99999\">".__('Ayuda').
	'</div></a></div><div id=cred style="z-index:99999"><script>function o(){window.open("?cred=1","cre","width=100,height=100,menubar=no,location=no,resizable=no,scrollbars=yes,status=no");}</script><a href="javascript:o()"><div id=icred style="z-index:99999">'.__('Acerca').
	'</div></a></div><div id=logo></div><h3 id=tit>'.__('Voto telemático').'</h3><div id=cubre style="background-color:#fff; z-index:9999; opacity:0.2; filter:alpha(opacity=20) ; display:none; position:absolute; top:0px; left:0px; margin: 0px 0px 0px 0px; padding: 0px 0px 0px 0px;"></div><script>function cubre() { with (document.body) { an=scrollWidth; al=scrollHeight; } with (document.getElementById("cubre").style) {display="block"; width=an+"px"; height=al+"px";}} function autocoff() { p=document.forms; for(i=0; i<p.length; i++) { pp=p[i].elements; for(j=0; j<pp.length; j++) pp[j].setAttribute("autocomplete","off"); } }</script></div>';
  $estas=array('0' => __('En edición'), '1' => __('Programada'), '2' => __('Activa'), '3' => __('Urna abierta'), '4' => __('Cerrada'), '99' => __('Errónea'));

  // }}}

  // pet no auth {{{

  // getim {{{
  //  va antes del tratamiento de $lg que si no se lía parda
  $tips=array('','gif','jpeg','png');
  if ($i=isset($_REQUEST['getim']) or $b=isset($_REQUEST['getB64im'])) {
    $i and $im=intval($nI=$_REQUEST['getim']);
    $b and $im=intval($_REQUEST['getB64im']);
    $pub=($_SESSION[$secr]) ? '' : ' and pub=1';
    if ($im)
      list($img,$tip)=@mysql_fetch_row(mysql_query("select img,tipo from eVotImgs where idI = $im$pub"));
    else
      list($img,$tip)=@mysql_fetch_row(mysql_query("select img,tipo from eVotImgs where nomImg = '".mysql_real_escape_string($nI)."'$pub"));
    if (!$img) {
      if ($_REQUEST['e'])
	die();
      list($eim)=mysql_fetch_row(mysql_query("select imgErr from eVotDat"));
      list($img,$tip)=@mysql_fetch_row(mysql_query("select img,tipo from eVotImgs where idI = $eim"));
    }
    if ($i) {
      header("Content-type: image/".$tips[$tip]);
      header("Pragma:");
      header("Cache-control:");
      if ($eim)
	 header('Expires: '.date("r",$now-600));
      else if ($im)
	header('Expires: '.date("r",$now+86400000));
      else
	header('Expires: '.date("r",$now+600));
      die($img);
    }
    else {
      header("Content-type: text/xml");
      die('<b64img><type>image/'.$tips[$tip].'</type><cont>'.base64_encode($img).'</cont></b64img>');
    }
  }
  // }}} // 10 lineas de codigo de depuracion eliminadas por mkInstaller
  if ($idE=intval($_REQUEST['abs'])) {
    $_SESSION['saltar'][$idE]=true;
    header("Location: $hst$escr");
    die();
  }
  // ver actas {{{
  if ($idEt=intval($_REQUEST['hash']) and $act='tokens' or
      $idEv=intval($_REQUEST['vHash']) and $act='tokens' or
      $idEr=intval($_REQUEST['record']) and $act='record' or
      $idEv=intval($_REQUEST['vRecord']) and $act='record') {
    list($acta,$nom)=mysql_fetch_row(mysql_query("select $act,nomElec from eVotMes,eVotElecs where mesaElec = idM and idE = '".($idEt+$idEr+$idEv)."' and (est > 3)"));
    if ($acta) {
      if ($idEv) {
	header('Content-type: text/html; charset=utf-8');
	header("Content-Disposition: inline; filename=\"$nom.html\""); 
	list($dum,$bod)=explode("Content-Description: Acta\n\n",$acta);
	list($bod,$dum)=explode("\n\n",$bod);
	echo '<html><head><title>'.__('Acta de la elección ').$nom.'</title>'.$css.'</head><body id=ifrBody onload="try {frameElement.parentNode.style.height=Math.min(500,document.body.scrollHeight+document.body.style.marginTop+document.body.style.paddingTop)+\'px\';} catch(e) {}">';
	die(preg_replace('/(<img[^>]*src=")cid:[^-]*-([0-9]*">)/','\1?getim=\2',base64_decode($bod)));
      }
      if ($mai=dirmail('',$iAm=$_SESSION[$secr]['iAm'])) { // preciso asignar iAm
	enviAct($mai,$acta);
	die("<html><head>$css</head><body id=ifrBody>".__('Enviada'));
      }
      header('Content-type: message/rfc822; charset=utf-8');
      header("Content-Disposition: inline; filename=\"$nom.eml\"");
      die("Subject:\n$acta");
    }
    header('Content-type: text/html; charset=utf-8');
    die("$htcab<body id=ifrBody>$htban".__('Acta no encontrada. Recuerde que las actas no están disponibles hasta que no se cierra la mesa.'));
  }
  if ($idM=intval($_REQUEST['vCRec'])) {
    list($acta,$nom)=mysql_fetch_row(mysql_query("select actap,nomMes from eVotMes where idM = '$idM'"));
    if (!$acta) {
      header('Content-type: text/html; charset=utf-8');
      die("$htcab<body id=ifrBody>$htban".__('Acta no encontrada.'));
    }
    if ($mai=dirmail('',$iAm=$_SESSION[$secr]['iAm'])) {
      enviAct($mai,$acta);
      die("<html><head>$css</head><body id=ifrBody>".__('Enviada'));
    }
    header('Content-type: message/rfc822; charset=utf-8');
    header("Content-Disposition: inline; filename=\"$nom.eml\"");
    die("Subject:\n$acta");
  }
  if ($idE=intval($_REQUEST['vRoll'])) {
    header('Content-type: text/html; charset=utf-8');
    if (!($iAm=$_SESSION[$secr]['iAm'] and mysql_num_rows(mysql_query("select idM from eVotMes,eVotMiem,eVotElecs where mesMiemb = idM and idM = mesaElec and idE = '$idE' and miembMes = $iAm and est < 2"))))
      $censoP='and censoP = 1';
    list($nomE)=mysql_fetch_row(mysql_query("select nomElec from eVotMes,eVotElecs where idE = $idE and mesaElec = idM and est < 4 $censoP"));
    if ($nomE) {
      echo '<html><head><title>'.__('Censo de la elección ').'</title>'.$css.'</head><body id=ifrBody';
      if ($_REQUEST['fr'])
	echo ' onload="try {frameElement.parentNode.style.height=Math.min(500,document.body.scrollHeight+document.body.style.marginTop+document.body.style.paddingTop)+\'px\';} catch(e) {}">';
      else
	echo '><h4>'.__('Censo de la elección ').'</h4>';
      $q=mysql_query("select nom,info from eVotPart,eVotPob where partElec = idP and elecPart = $idE order by nom");
      while (list($nom,$info)=mysql_fetch_row($q))
	if ($info)
	  echo "<font color=red>$nom</font><br>";
	else
	  echo "$nom<br>";
      echo '</body>';
    }
    else {
      if (!$_REQUEST['fr'])
	echo "$htcab<body>$htban";
      else
	echo "<html><head>$css</head><body id=ifrBody>";
      echo __('No disponible');
    }
    die();
  }
  if ($idE=intval($_REQUEST['vBallot'])) {
    header('Content-type: text/html; charset=utf-8');
    $v=mysql_fetch_assoc(mysql_query("select idE,nomElec,ayupap,pie, est from eVotMes,eVotElecs where mesaElec = idM and idE = $idE and est < 4"));
    if ($v['est'] >1) {
      header("Pragma:");
      header("Cache-control: max-age=600, public");
      header('Expires: '.date("r",$now+600));
    }
    if ($v) {
      echo '<html><head><title>'.__('Papeleta de la elección ').$v['nomElec'].'</title>'.$css.'</head><body id=ifrBody';
      if ($_REQUEST['fr'])
	echo ' onload="try {frameElement.parentNode.style.height=Math.min(500,document.body.scrollHeight+document.body.style.marginTop+document.body.style.paddingTop)+\'px\';} catch(e) {}"';
      echo '>';
      dispElec($v);
    }
    else {
      if (!$_REQUEST['fr'])
	echo "$htcab<body>$htban";
      else
	echo "<html><head>$css</head><body id=ifrBody>";
      echo __('No disponible');
    }
    die();
  }
  // }}}
  if ($idM=intval($_REQUEST['comu'])) { // {{{
    header('Content-type: text/html; charset=utf-8');
    if ($idM < 0) {
      echo "$htcab<body>$htban";
      $vlvr=' <form><input class=btVolv type=submit value="'.__('Volver').'"></form>';
    }
    else
      echo $css;
    echo '<body id=ifrBody onload="frameElement.parentNode.style.height=document.body.scrollHeight+document.body.style.marginTop+document.body.style.paddingTop+\'px\';"><div id=comm><h4>'.__('Formulario de contacto con la mesa').'</h4><form method=post>';
    if ($idP=$iAm=$_SESSION[$secr]['iAm'])
      $us=mysql_fetch_assoc(mysql_query("select * from eVotPob where idP = $idP"));
    else {
      $dni=mysql_real_escape_string($idni=enti($_REQUEST['dni']));
      echo '<p class=pnolg><span id=commdni>'.__('DNI').'</span> <input size=15 class=commdnip name=dni value="'.$dni.'"><br>';
      if ($dni and $us=mysql_fetch_assoc(mysql_query("select * from eVotPob where DNI like '$dni'")))
	$idP=$us['idP'];
    }
    if ($idP) {
      $org=dirmail($us);
      if ($idM > 0)
	$slmes="and idM = $idM";
      if ($idE=intval($_REQUEST['el']))
	list($ele)=mysql_fetch_row(mysql_query("select idE from eVotMes,eVotElecs,eVotPart where mesaElec = idM and elecPart = idE and partElec = $idP and idE = $idE $slmes and est < 4"));
      else {
	$iele=$_REQUEST['ele'];
	echo '<span class=commel>'.__('Elección').'</span> <select name=ele>';
	$q=mysql_query("select idE,nomElec,mesaElec from eVotMes,eVotElecs,eVotPart where mesaElec = idM and elecPart = idE and partElec = $idP $slmes and est < 4 order by fin, posE, nomElec");
	while ($el=mysql_fetch_assoc($q)) {
	  echo '<option value='.$el['idE'];
	  if ($iele == $el['idE']) {
	    echo ' selected';
	    $ele=$iele; $idM=$el['mesaElec'];
	  }
	  echo '>'.$el['nomElec'];
	}
	echo '</select><br>';
      }
    }
    if ($ele) {
      if ($mie=intval($_REQUEST['mi']))
	$mie=array(mysql_fetch_assoc(mysql_query("select eVotPob.* from eVotMiem,eVotPob where miembMes = idP and mesMiemb = $idM and idP = $mie and correo != ''")));
      else {
	$imi=array_flip(explode(',',$_REQUEST['mie'])); $sto=count($imi) > 1 ? ' selected' : '';
	$q=mysql_query("select eVotPob.* from eVotMiem,eVotPob,eVotMes where miembMes = idP and mesMiemb = idM and idM = $idM and correo != '' and (est < 2 or (est < 4 and pres) or presf)");
	echo '<span class=commie>',__('Miembro').'</span> <select name=mie>'; $to=''; $c=0; $mie=array();
	while ($mi=mysql_fetch_assoc($q)) {
	  echo '<option value='.($idi=$mi['idP']);
	  $to.=",$idi"; $c++;
	  if (isset($imi[$idi])) {
	    $mie[]=$mi;
	    if (!$sto)
	      echo ' selected';
	  }
	  echo '>'.$mi['nom'];
	}
	if ($c>1)
	  echo "<option value=\"$to\"$sto>".__('Todos');
	echo '</select><br>';
      }
    }
    if ($mie) {
      $imsg=enti($_REQUEST['msg']);
      echo '<div class=commem>',__('Mensaje').'</div> <textarea cols=60 name=msg'.filcol($imsg,"\n",5);
      if ($iAm and (($nmens=&$_SESSION['nmens']) < 4))
	$capok=true;
      else {
	$_SESSION['mmCaptchaFontFile']='/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf';
	echo '<div class=comnum><span class=comnums>'.__('Números de la imagen').
		'</span> <img onclick="src+=\'&0\'" src="mmCaptcha.php?n=1&l=3&h=30&w=48&'.$now.
		'"> <input name=cap size=3> </div>';
	if ($nmens == 4)
	  $capok=true;
	else
	  $capok=($_REQUEST['cap'] and ($_REQUEST['cap'] == $_SESSION['mmCaptchaTxt']));
	$_SESSION['mmCaptchaTxt']=$_SESSION['mmCaptchaTry']='';
      }
      if ($imsg and $capok) {
	list($cab,$cue)=explode("\n\n",haz_related($imsg),2);
	$cab="$cab\nFrom: $org\n";
	foreach($mie as $usu)
	  mail(dirmail($usu),__('Mensaje de un votante',$usu['idio']),$cue,$cab);
	mail($org,__('Mensaje enviado a la mesa'),$cue,$cab);
	$nmens++;
	echo __('Mensaje enviado').'<br>';
      }
    }
    die('<input type=submit id=comproc value="'.__('Proceder').'"></form>'.$vlvr.'</div>');
  } // }}}
  if ($monit=$_REQUEST['monit']) { // {{{
    header('Content-type: text/html; charset=utf-8');
    if ($monit == 'Sal') {
      unset($_SESSION['monit']);
      header("Location: $hst$escr");
      die();
    }
    if ($monit=&$_SESSION['monit']) {
      $mes=mysql_fetch_assoc(mysql_query("select eVotMes.* from eVotMes,eVotElecs where idM=mesaElec and idE=$monit[0]"));
      if ($xml=$_SESSION['xml']) {
	header('Content-type: text/xml; charset=utf-8');
	echo '<?xml version="1.0" encoding="UTF-8"?><monitor>';
      }
      else
	echo "$htcab<meta http-equiv=refresh content=120><body>$htban<h3 class=timon>".__('Monitor').'</h3>';
      $mes['now']=$now;
      foreach(array('ini'=> array(__('Inicio'),'start'),'now'=>array(__('Hora&nbsp;actual'),'now'),'fin'=>array(__('Fin'),'end')) as $q=>$tx)
	if ($xml)
	  echo "<$tx[1]>{$mes[$q]}</$tx[1]>";
	else
	  echo "<span class=labmon>$tx[0]</span>: <span class=valmon>".strftime(__("%d/%b/%Y %H:%M"),$mes[$q]).'</span><br>';
      if ($xml)
	echo '<status>'.$estas[$est=$mes['est']].'</status>';
      else {
	echo '<span class=labmon>'.__('Estado').'</span>: <span class=valmon>'.$estas[$est=$mes['est']].'</span>';
        if ($mes['fin']-300 < $now and $now < $mes['fin'])
	  echo '&nbsp;&nbsp;<marquee class=marquee width=50%><font color=red>'.__('Quedan menos de 5 minutos para el cierre').'</font></marquee>';
      }
      if ($est > 1) {
	if ($xml)
	  echo '<elections>';
	foreach($monit as $idE) {
	  $ele=mysql_fetch_assoc(mysql_query("select * from eVotElecs where idE=$idE"));
	  if ($xml)
	    echo "<election><name>{$ele['nomElec']}</name><part>";
	  else
	    echo '<h3 class=nomElec>'."{$ele['nomElec']}</h3><span class=labmon>".__('Participación hasta el momento').'</span>: <span class=valmon>';
	  $ini=max($mes['ini'],$mes['cons']);
	  if (($tiem=$mes['fin']-$ini) > 8*3600)
	    $tiem=$ini+2*3600;
	  else
	    $tiem=$ini+floor($tiem/4);
	  if ($_SESSION['norestric'] or ($tiem < $now)) {
	    list($sPart)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE and acude = 1"));
	    list($sPop)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE"));
	    if ($_SESSION['norestric'] or ($sPart > 10 and $sPart > 0.02*$sPop)) {
	      if ($ele['abie'])
		echo $sPart;
	      else
		echo floor(100*$sPart/$sPop).'%';
	    }
	    else
	      echo __('Datos no disponibles');
	  }
	  else
	    echo strftime(__('Datos disponibles el %d de %B a las %H:%M'),$tiem);
	  if ($xml)
	    echo '</part></election>';
	  else
	    echo '</span>';
	}
	if ($xml)
	  echo '</elections>';
      }
      if ($xml)
	die('</monitor>');
      die('<p><a class=salir href="?monit=Sal">Salir</a>');
    }
    if ($idmonit=limp($_REQUEST['idmonit'])) {
      $elecs=array();
      list($idM)=mysql_fetch_row($q=mysql_query("select idM from eVotMes where monmkey = '$idmonit'"));
      if ($idM) {
	$q=mysql_query("select idE from eVotElecs where mesaElec = $idM");
	while (list($idE)=mysql_fetch_row($q))
	  $elecs[]=$idE;
      }
      else {
	list($idE)=mysql_fetch_row(mysql_query("select idE from eVotElecs where monekey = '$idmonit'"));
	if ($idE)
	  $elecs[]=$idE;
      }
    }
    if ($elecs) {
      $_SESSION['monit']=$elecs;
      $_SESSION['norestric']=$_REQUEST['norestric'];
      $_SESSION['xml']=$_REQUEST['xml'];
      header("Location: $hst$escr?monit=on");
      die();
    }
    die("$htcab<body>$htban<form method=post action=\"$escr?monit=on\">".__('Introduzca la clave de monitorización').': <input name=idmonit size=10> <input name=restric type=submit value="'.__('Iniciar con restricciones').'"> <input name=norestric type=submit value="'.__('Iniciar sin restricciones').'"></form>');
  } // }}}
  // }}}

  // auth {{{
  $aupar=&$_SESSION[$secr];
  $rmIP=ip2long($_SERVER['REMOTE_ADDR']);
  if ($rpar=$_GET['reto_auth']) {
    $ra=$aupar['reto_auth'];
    if (!$ra)
      die('Hack');
    session_write_close();
    $da=unserialize(pillaURL("$ra$rpar")) or die("$htcab<body>$htban".sprintf(__('Error inesperado, %sContinuar%s'),'<a href=/>','</a>'));
    session_start();
    if ($da['login'])
      $_SESSION['login']=limp($da['login']);
    else {
      $elustmp=limp($da['x509_info']['DNI']);
      list($elustmp)=mysql_fetch_row(mysql_query("select us from eVotPob where DNI = '$elustmp'"));
      $_SESSION['login']=$elustmp;
    }
    // limpia la URL
    if ($_SESSION['login'])
      header("Location: $hst$escr?amth={$_GET['amth']}");
    else
      printf("$htcab<body>$htban".__('El proceso falló, no se encontró usuario, %sContinuar%s'),'<a href=/>','</a>');
    die();
  }
  $mth=intval($_REQUEST['amth']);
  if (!$aupar) {
    $aupar=array();
    // prim mira la IP
    if (mysql_num_rows(mysql_query("select * from eVotMetAut where idH = 2 and disp = 1")))
      list($idP,$miusu)=mysql_fetch_row(mysql_query("select idP,us from eVotPob where oIP = $rmIP"));
    if ($idP) {
      $aupar['iAm']=$idP;
      $aupar['authLv']++;
      $aupar['mth'][2]=true;
      $aupar['mius']=$miusu;
      $aupar['mante']=$mante;
    }
    else {
      if ($_SESSION['njmpau'])
	$jmpau=false;
      else
	list($jmpau)=mysql_fetch_row(mysql_query("select jmpau from eVotDat"));
      if ($jmpau and !$mth and !count($_GET)) { // no auth, toma el meto def si no hay query_string (importante por captcha, exit, etc)
	$_SESSION['njmpau']=true;
        $mth=$dAuth;
      }
    }
  }
  if ($mth) { // {{{
    header('Content-type: text/html; charset=utf-8');
    if ($aupar['mth'][$mth]) { // ya esta autenticado con este metodo
      header("Location: $hst$escr");
      die();
    }
    list($mth,$nomA)=mysql_fetch_row(mysql_query("select idH,nomA from eVotMetAut where idH = $mth and disp = 1"));
    if (!$mth) {
      die(__('Método de autenticación incorrecto'));
    }
    $volver=" <a href=\"$escr\">".__('Volver').'</a>';
    switch ($mth) {
      case 1: // {{{ // 33 lineas de codigo de depuracion eliminadas por mkInstaller
	$capok=($_REQUEST['msg'] and ($_REQUEST['msg'] == $_SESSION['mmCaptchaTxt']));
	$_SESSION['mmCaptchaTxt']=$_SESSION['mmCaptchaTry']='';
	if ($dni=mysql_real_escape_string($_REQUEST['dni'])) {
	  if (!$capok)
	    $error=__('Los números de la imagen no son correctos');
	  else {
	    $pwd=$_REQUEST['passw'];
	    $usu=mysql_fetch_assoc(mysql_query("select * from eVotPob where (us = '$dni' or DNI = '$dni')"));
	    if ($idP=$usu['idP']) {
	      if ($aupar['iAm'] and ($aupar['iAm'] != $idP))
			die("$htcab<body>$htban".sprintf(__('Debe <a href="?amth=%s">autenticarse</a> con el usuario %s o <a href="?">volver</a>'),$mth,$aupar['mius']));
	      if (substr($cpw=$usu['pwd'],0,1) == '!') {
		$pwd1=2;
		$cpw=substr($cpw,1);
	      }
	      else if ($_REQUEST['nwpwd'])
		$pwd1=1;
	      else
		$pwd1=0;
	      if (substr($cpw,0,1) == '%') // en claro
		$cpw=substr($cpw,1);
	      else
		$pwd=genPwd($pwd,substr($cpw,0,10));
	      if ($pwd != $cpw)
		$error=true;
	      else if (($pwd1 > 1) and ($usu['cadPw'] < $now))
		$error=__('Contraseña inicial caducada');
	      else {
		if ($oIP=$usu['oIP'])
		  if ($oIP == -1) {
		    $oIP=$rmIP; // toma la IP y la establece forever
		    mysql_query("update eVotPob set oIP=$oIP where idP = $idP");
		  }
		if ($clId=$usu['clId'] and $oclId=$_REQUEST['clId']) {
		  $oclId=md5($oclId);
		  if ($clId == -1) {
		    $clId=$oclId;
	            mysql_query("update eVotPob set clId='$clId' where idP = $idP");
		  }
		} else $oclId='No hay';
		if (($pwd1 > 1) and ($mth != $dAuth) and !$aupar['mth'][$dAuth]) {
		  $q=mysql_query("select idH from eVotMetAut where idH != 1 and disp=1"); $s='';
		  while (list($idH)=mysql_fetch_row($q))
		    $s.=",$idH";
		  $s=substr($s,1);
		  die("$htcab<body>$htban".sprintf(__('Lo sentimos, pero para el primer acceso es necesario estar previamente autenticado con otro método.<br>%sAutentique ahora%s.'),"<a href=?incauth=$s>",'</a>'));
		}
		$aupar['iAm']=$idP;
		list($authextra)=mysql_fetch_row(mysql_query("select authextra from eVotDat"));
		if ($authextra)
		  $_SESSION['authextra']=true;
		$aupar['authLv']+=($authextra+1+intval($oIP == $rmIP)+intval($clId == $oclId));
		$aupar['mth'][$mth]=true;
		$aupar['mante']=$mante;
		if ($pwd1 > 0) {
		  $pwd='';
		  for ($i=0; $i<10; $i++)
		    $pwd.=((rand(1,100)%2) ? chr(rand(65,90)) : chr(rand(48,57)));
		  echo "$htcab<body>$htban<span id=nwInt>".__('Su nueva contraseña es')."</span><h4 id=nwpwdint>$pwd</h4><span id=anoint>".
			  sprintf(__('Anótela o %sno podrá volver a entrar%s. %sContinuar%s'),
				  '<span id=anointb>','</span>',"</span><a id=contint href=\"$hst$escr\">",'</a>');
		  $pwd=genPwd($pwd);
		  mysql_query("update eVotPob set pwd='$pwd',cadPw=0 where idP = $idP");
		  $_SESSION['rediIn']=false;
		  die();
		}
		break;
	      }
	    }
	    $error=__('Usuario/contraseña incorrectos');
	  }
	}
	if ($_SESSION['rediIn'])
	  $redi='<h5 id=cmbint>'.__('Es necesario cambiar ahora su contraseña. La nueva contraseña será generada por el sistema. Por ello, antes de proceder, prepare un lugar donde anotarla').'</h5>';
	$_SESSION['mmCaptchaFontFile']='/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf';
	die("$htcab<body>$htban<form id=authint method=post name=formu>$redi<table id=tauthint><tr id=dniint><td class=lab> ".
		__('Usuario o DNI').': <td colspan=2> <input name=dni value="'.enti($aupar['mius']).'"> <tr id=pwdint><td class=lab> '.
		__('Contraseña').': <td colspan=2> <input type=password autocomplete=off name=passw> <tr id=captint><td class=lab> '.
		__('Números de la imagen').': <td> <input name=msg autocomplete=off size=5> <td> <img onclick="src+=\'&0\'; document.formu.msg.focus()" src="mmCaptcha.php?n=1&h=30&l=3&w=48&'.$now.'"> </table><input type=submit id=btEntrarInt name=login value="'.
		__('Entrar').'"><input id=clId name=clId type=hidden> <span id=lab></span><br><input type=checkbox name=nwpwd><span id=genint>'.__('Generar nueva contraseña').
		'</span><span id=errint>'."$error</span></form><form id=btsint><input type=submit id=btVolInt value=\"".__('Volver').'">'.(($aupar['mius']) ? " <input type=submit id=btSalInt class=salir name=exit value=\"".__('Salir').'">' : '').'
			<script>
			  try {
			    Clauer = new ActiveXObject("CryptoNisu.Clauer");
			  } catch(e) { try { var Clauer = new clauerReq(); } catch(e) {} }
			  if (Clauer) {
			    tryCl();
			  }
			  function tryCl() {
			    try {
			      if (Clauer.setClauerActive("",false)) {
				if (clId=Clauer.getClauerId()) {
				  document.getElementById("clId").value=clId;
				  document.getElementById("lab").innerHTML="'.__('Identificador del Clauer leído').'";
				}
			      }
			      else setTimeout("tryCl();",500);
			    } catch(e) { setTimeout("tryCl();",500); }
			  }
			</script>');

	break;
	// }}}

      case 10: // {{{
	require_once('storkAuth.php');
	list($urla)=mysql_fetch_row(mysql_query("select urlA from eVotMetAut where idH = $mth and disp=1"));
	list($keyS,$certS,$cPEPS,$provName,$provId,$provCountry,$uPru,$dtPru) = mysql_fetch_row(mysql_query("select keyyS,certS,cPEPS,provName,provId,provCountry,uPru,dtPru from eVotDat"));
	if ($uPru)
	  list($keyS,$certS,$urla,$cPEPS,$provName,$provId,$provCountry)=explode("#####",$dtPru);
	if (!$urla or !$cPEPS)
	  die("$htcab<body>$htban".__('<h4>STORK no configurado</h4>').$volver);
	if ($_REQUEST['getAP']) {
	  $dni='';
	  if ($resp=$_REQUEST['SAMLResponse']) {
	    $resp=base64_decode($resp);
	    try {
	      $stork = new storkAuth();
	      $stork->setResponseVerificationCert($cPEPS);
	      $stork->parseResponseXML($resp, false);
	      $errInfo = "";
	      if (!$stork->isSuccess($errInfo))
		$errInfo=$errInfo['StatusMessage'];
	      else {
	        $ass=$stork->getAssertions();
		list($dum,$dumm,$dni)=explode('/',$ass['eIdentifier'],3);
	      }
	    } catch(Exception $e) { $errInfo=$e->getMessage(); }
	  }
	  if ($dni === '')
	    die("$htcab<body>$htban".__('Error en el proceso STORK').": $errInfo $volver");
	  list($idP,$pwd)=mysql_fetch_row(mysql_query("select idP,pwd from eVotPob where DNI = '$dni'"));
	  if ($aupar['iAm'] and ($aupar['iAm'] != $idP))
	    die("$htcab<body>$htban".sprintf(__('Debe <a href="?amth=%s">autenticarse</a> con el usuario %s o <a href="?">volver</a>'),$mth,$aupar['mius']));
	  if ($idP) {
	    $aupar['iAm']=$idP;
	    $aupar['authLv']++;
	    $aupar['mth'][$mth]=true;
	    $aupar['mante']=$mante;
	    break;
	  }
	  else
	    die("$htcab<body>$htban".__('Usted no forma parte de la población de este sistema de voto telemático').$volver);
	}
	if ($cod=$_REQUEST['stork']) {
	  try {
	    $stork= new storkAuth();
	    $stork->setCertParams($certS,$keyS);
	    $stork->setC14NParams (false, false);
	    //!
	    $organizacion='';
	    //!
	    $proposito='';
	    $stork->setServiceProviderParams($provName,"$hst$escr?amth=$mth&getAP=1",$provId,$provCountry);
	    $stork->setSTORKParams($urla,1,$cod);
	    $stork->addRequestAttribute ("givenName", false);
	    $stork->addRequestAttribute ("surname", false);
	    $stork->addRequestAttribute ("eIdentifier", false);
	    $req = base64_encode($stork->generateRequest(true));
	    die("<html><body id=ifrBody onload=\"document.forms[0].submit();\">
		<h4>".__('Realizando la petición, espere unos segundos')."</h4>
		<form name=\"redirectForm\" method=\"post\" action=\"$urla\">
		  <input type=\"hidden\" name=\"country\" value=\"$cod\" />
		  <input type=\"hidden\" autocomplete=off name=\"SAMLRequest\" value=\"$req\" />
		  </form></body></html>");
	  }
	  catch (Exception $e) {
	    die("$htcab<body>$htban<h4>".__('Se produjo un error interno')."</h4>$volver<p>".$e->getMessage());
	  }
	}
	$q=mysql_query("select * from eVotPais where peps=1");
	if (($cume=mysql_num_rows($q)) > 1) {
	  echo "$htcab<body>$htban".__('<h4>Autenticación STORK</h4>Seleccione el país que ha emitido su identificación').':<dl>';
	  while ($p=mysql_fetch_assoc($q)) {
	    if ($p['imgY'])
	      echo "<dt>&nbsp;</dt><dd><a href=\"?amth=$mth&stork={$p['cod']}\"><img title=\"{$p['cod']} - {$p['nomY']}\" border=0 src=\"data:image/gif;base64,".
			base64_encode($p['imgY']).'" align=absmiddle> '.$p['nomY'].'</a></dd>';
	  }
	  die("<p>$volver");
	}
	else if ($cume) {
	  $p=mysql_fetch_assoc($q);
	  header("Location: $hst$escr?amth=$mth&stork={$p['cod']}");
	  die();
	}
	else
	  die("$htcab<body>$htban".__('<h4>STORK no configurado</h4>'));
	break;
	// }}}


      default: // {{{
	list($tipEx,$urla)=mysql_fetch_row(mysql_query("select tipEx,urlA from eVotMetAut where idH = $mth and disp=1"));
	if (!$urla)
	  die("$htcab<body>$htban".__('Método de autenticación incorrecto').$volver);
	if (!$us=$_SESSION['login']) { // establecido por la pasarela
	  switch ($tipEx) {
	    case 1:
	      $aupar['reto_auth']=$urla;
	      $ret=urlencode("$hst$escr?amth=$mth&");
	      header("Location: $urla?reto=$ret");
	      break;
	    default:
	      echo __('Error');
	  }
	  die();
	}
	// ha funcionado ?
	if ($us=mysql_real_escape_string($us)) {
	  $_SESSION['login']='';
	  list($idP,$pwd)=mysql_fetch_row(mysql_query("select idP,pwd from eVotPob where us = '$us'"));
	  if ($aupar['iAm'] and ($aupar['iAm'] != $idP))
	    die("$htcab<body>$htban<iframe style=\"width:0 ; height:0; visibility: hidden; \" src=\"$urla?exit=$hst\"></iframe>".
		sprintf(__('Debe <a href="?amth=%s">autenticarse</a> con el usuario %s o <a href="?">volver</a>'),$mth,$aupar['mius']));
	  if (!$idP and $DNI=mysql_real_escape_string($_SESSION['DNI'])) { // no está en la población, si tengo datos lo inserto
	    $nom=mysql_real_escape_string($_SESSION['nom']);
	    $corr=mysql_real_escape_string($_SESSION['mail']);
	    if (@mysql_query("insert into eVotPob (us,DNI,nom,correo) values ('$login','$DNI','$nom','$corr')"))
	      $idP=mysql_insert_id();
	  }
	  if ($idP) {
	    $aupar['iAm']=$idP;
	    $aupar['authLv']++;
	    $aupar['mth'][$mth]=true;
	    $aupar['mante']=$mante;
	  }
	  else
	    die("$htcab<body>$htban".__('Usted no forma parte de la población de este sistema de voto telemático').$volver);
	}
	// }}}
    }
    $_SESSION['njmpau']=false;
    if (substr($pwd,0,1) == '!')
      $_SESSION['rediIn']=true;
    header("Location: $hst$escr");
    die();
  }
  // }}}
  if ($exit=$_REQUEST['exit'] or $inca=$_REQUEST['incauth']) {
    $desco='';
    if ($exit) {
      if ($aupar['mth'])
	foreach($aupar['mth'] as $mt => $dumm) {
	  list($urla)=mysql_fetch_row(mysql_query("select urlA from eVotMetAut where idH = $mt"));
	  if ($urla)
	    $desco.="<iframe style=\"width:0 ; height:0; visibility: hidden; \" src=\"$urla?exit=$hst\"></iframe>";
	}
      // el regenerate_id es necesario por si la extension eSurvey de firefox mantiene la sesion y regenera aupar
      session_unset(); session_destroy(); session_regenerate_id(); session_start();
      forceLangSession($whichLang);
      $aupar=array();
      $inca='t';
    }
    if ($inca != 't')
      $incs=array_fill_keys(explode(',',$inca),true);
    $q=mysql_query("select * from eVotMetAut where disp=1 and idH != 2");
    $ipout="$htcab<body>$htban<h4 class=hlstAut>".__('Métodos de autenticación').'</h4><div id=mths>';
    $nops=0; $pout=$amth=$pri='';
    while ($m=mysql_fetch_assoc($q))
      if (!$aupar['mth'][$idH=$m['idH']] and ($inca == 't' or $incs[$idH])) {
	if ($idH == $dAuth)
	  $cls='df';
	else
	  $cls='';
	if ($imgA=$m['imgA'])
	  $un="<img src=\"?getim=$imgA\" alt={$m['nomA']} title={$m['nomA']} class={$cls}imlstAut border=0>";
	else
	  $un=$m['nomA'];
	$amth="?amth=$idH";
	$un="<div class={$cls}lstAut><a href=\"$amth\">$un</a></div>";
	if ($idH == $dAuth)
	  $pri=$un;
	else
	  $pout.=$un;
	$nops++;
      }
    if ($_SESSION['njmpau'])
      $jmpau=false;
    else
      list($jmpau)=mysql_fetch_row(mysql_query("select jmpau from eVotDat"));
    if ($nops == 0)
      header("Location: $hst$escr?acc[myOpt]=1");
    else if ($nops < 2 and !$exit and $jmpau) {
      $_SESSION['njmpau']=true;
      header("Location: $hst$escr$amth");
    }
    else {
      header('Content-type: text/html; charset=utf-8');
      echo "$ipout$pri$pout$desco<div id=pieauth class=lstAut>";
      if ($aupar['iAm'])
	echo '<a href="?acc[myOpt]=1">'.__('Opciones').'</a> - <a href="?">'.__('Volver');
      else
	echo '<a href="?comu=-1">'.__('Reportar un problema');
    }
    die('</a></div></div>');
  }
  if (!$iAm=$aupar['iAm']) {
    header("Location: $hst$escr?incauth=t");
    die();
  }
  if ($mante != $aupar['mante']) {
    // esto es necesario al menos por el gestor de imagenes
    die("<meta http-equiv=refresh content=\"0;url=$hst$escr?exit=1\">");
  }
  if ($lg) {
    mysql_query("update eVotPob set idio='$whichLang' where idP = $iAm");
    header("Location: $hst$escr");
    die();
  }
  list($jf,$mius,$minom,$idio)=mysql_fetch_row(mysql_query("select rol,us,nom,idio from eVotPob where idP = $iAm"));
  $aupar['mius']=$mius;
  if ($_SESSION['rediIn']) {
    header("Location: $hst$escr?amth=1");
    die();
  }
  if ($idio and $idio != $whichLang) {
    header("Location: $hst$escr?lang=$idio");
    die();
  }
  if ($jf > ($authLv=$aupar['authLv'])) {
    $jf=$authLv;
    $minom.='<br><font color=red>'.__('Pulse en su nombre para alcanzar su nivel de acceso').'</font>';
  }
  // }}}

  if ($_GET['dwCen']) {
    if ($jf<3 or $mante <1)
      die('');
    header('Content-type: application/octet-stream');
    header('Content-Disposition: attachment; filename="popullation.csv";');
    $q=mysql_query("select us,DNI,nom,correo from eVotPob order by nom");
    while ($per=mysql_fetch_row($q))
      echo implode(';',$per)."\n";
    die();
  }

  // más init {{{
  $vcgs=array('p'=>__('Presidente/a'), 'pa' => __('Presidente/a'), 'pf' => __('Presidente/a en funciones'), 'pg'=> __('Gestor/a de la mesa'), 's'=>__('Secretario/a'), 'v'=>__('Vocal'),
		'i'=>__('Interventor/a'), 'a'=>__('Apoderado/a'), '2p'=>__('Presidente/a suplente'), '2s'=>__('Secretario/a suplente'),
		'2v'=>__('Vocal suplente'), '2i'=>__('Interventor/a suplente'), '2a'=>__('Apoderado/a suplente'), 'jp' => __('Presidente/a'));
  //$segs=array(-1 =>__('Directo a la urna'), 0=>__('Directo a la urna con firma ciega'), 1=>__('Vía LCN 1 servidor'),3=>__('Vía LCN 3 servidores'));
  $segs=array(-2 =>__('Directo a la urna'), 1=>__('Vía LCN 1 servidor'),3=>__('Vía LCN 3 servidores'));
  // }}} // 172 lineas de codigo de depuracion eliminadas por mkInstaller

  // gestor {{{

  // init {{{
  header('Content-type: text/html; charset=utf-8');
  echo $htcab.'<body onload="window.scrollBy(0,'.intval($_REQUEST['elscroll']).
	'); autocoff();"><form id=dfm><input id=btexit type=submit name=exit value="'.
	__('Salir')."\"> <input id=btini type=submit value=\"".
	__('Inicio').'"> <a href="?incauth=t">'.$minom.'</a></form>'.$htban;
  $jefm='<div id=jefm class=sect><div class=cab>'.__('Operaciones como administrador/a del site').'</div>';
  $jefe='<div id=jefe class=sect><div class=cab>'.__('Operaciones como administrador/a de mesas').'</div>';
  $jefp='<div id=jefp class=sect><div class=cab>'.__('Operaciones como operador/a del registro').'</div>';
  $miem='<div id=miem class=sect><div class=cab>'.__('Operaciones como miembro de mesa').'</div>';
  $scro1='cubre(); scroll_top = function() { if(window.pageYOffset) return window.pageYOffset; else return Math.max(document.body.scrollTop,document.documentElement.scrollTop); }; if (elscroll.value==0) elscroll.value=scroll_top();';
  $scro2='<input type=hidden name=elscroll>';
  $scro='onsubmit="'.$scro1.'">'.$scro2;
  $pacien=' onclick="pthis=this; setTimeout(\'pthis.value=\\\''.str_replace('\\','\\\\\\',jsesc(__('Paciencia, puede tardar bastante'))).'\\\';\',3000)" ';
  // }}}

  $aacc=$_REQUEST['acc'];
  $acc=strval(@key($aacc));
  switch($acc) {
    case 'myOpt': // {{{
	if ($opEsvy=intval($_REQUEST['usEs']))
	  mysql_query("update eVotPob set opEsvy=$opEsvy where idP = $iAm");
	else
	  list($opEsvy)=mysql_fetch_row(mysql_query("select opEsvy from eVotPob where idP = $iAm"));
	echo '<div id=opts><div class=cab>'.__('Sus opciones').'</div><form method=post onsubmit="cubre()"><table><tr id=isellg><td class=lab>',__('Idioma'),': <td class=opt>',
		__('Para elegir idioma de forma permanante, basta con pinchar la bandera'),'<tr id=selesy><td class=lab>'.__('Uso de eSurvey'),
		': <td class=opt><select name=usEs>';
	foreach(array('0'=>__('El uso que proponga la mesa electoral'),
		'-2'=>__('No usar nunca'),'1'=>__('Usar siempre 1 nodo'),
		'11'=>__('Usar al menos 1 nodo'),'3'=>__('Usar 3 nodos')) as $val => $opt)
	  echo '<option'.(($opEsvy == $val) ? ' selected' : '')." value=$val>$opt";
	echo '</select></table><input type=submit name="acc[myOpt]" value="'.__('Actualizar opciones').'"></form></div>';
	break;
	// }}}

    case 'regPw': // {{{
	if ($jf<1)
	  die('auth');
	if ($aupar['authLv'] <2)
	  die($jefp.__('Necesita un mayor nivel de autenticación, pruebe clicando en su nombre'));
	foreach (array('us','id','pwd','nap','ema') as $q)
	  $$q=mysql_real_escape_string($_REQUEST[$q]);
	function mscmp($us,$nap,$ema) {
	  return '<tr id=rgUs><td class=lab>'.__('Usuario').': <td> <input name=us value="'.enti($us).
		'"> <tr id=rgAp><td class=lab> '.__('Apellidos, Nombre').': <td> <input name=nap value="'.enti($nap).
		'"> <tr id=rgMail><td class=lab> '.__('Correo').': <td> <input name=ema value="'.enti($ema).'">';
	}
	if ($id)
	  if ($pwd) {
	    $cpwd='!'.genPwd($pwd); $cadPw=$now+48*3600;
	    if ($us and $nap)
	      if (@mysql_query("insert into eVotPob (us,DNI,nom,pwd,cadPw,correo,regId,regMod) values ('$us','$id','$nap','$cpwd',$cadPw,'$ema',$iAm,$now)")) {
		$n=enti($nap);
		$pie="<h4 class=rgH4>$id - $n - ".__('añadido')."</h4>";
		$id=$pwd=$mscp='';
	      }
	      else {
		if ($ema)
		  $iema=", correo='$ema'";
		else
		  $iema='';
		mysql_query("update eVotPob set pwd='$cpwd', cadPw = $cadPw, regId=$iAm, regMod=$now $iema where DNI='$id' and us = '$us'");
		if (mysql_affected_rows()>0) {
		  list($idP)=mysql_fetch_row(mysql_query("select idP from eVotPob where DNI='$id'"));
		  if (intocable($idP)) {
		    alerta(__('Se pudo establecer la contraseña, pero no actualizar el nombre, puede ser normal'));
		    $id=$pwd=$mscp='';
		    $pie="<h4 class=rgH4>$id - $n - ".__('parcialmente actualizado')."</h4>";
		  }
		  else {
		    mysql_query("update eVotPob set nom='$nap', regId=$iAm, regMod=$now where DNI='$id'");
		    $n=enti($nap);
		    $pie="<h4 class=rgH4>$id - $n - ".__('actualizado')."</h4>";
		    $id=$pwd=$mscp='';
		  }
		}
		else {
		  alerta(__('No se pudo añadir ni actualizar, revise los datos'));
		  $mscp=mscmp($us,$nap,$ema);
		}
	      }
	    else {
	      mysql_query("update eVotPob set pwd='$cpwd', cadPw = $cadPw, regId=$iAm, regMod=$now where DNI='$id'");
	      if (mysql_affected_rows()>0) {
		list($n)=mysql_fetch_row(mysql_query("select nom from eVotPob where DNI='$id'"));
		$n=enti($n);
		$pie="<h4 class=rgH4>$id - $n - ".__('actualizado')."</h4>";
		$id=$pwd=$mscp='';
	      }
	      else {
		alerta(__('Error al actualizar, revise los datos\nQuizá deba añadir un usuario el sistema'));
		$mscp=mscmp($us,$nap,$ema);
	      }
	    }
	  }
	  else {
	    if (list($us,$nap,$ema,$regId,$regMod)=mysql_fetch_row(mysql_query("select us,nom,correo,regId,regMod from eVotPob where DNI='$id'"))) {
	      $mscp=mscmp($us,$nap,$ema);
	      if ($regId) {
		list($rgN)=mysql_fetch_row(mysql_query("select nom from eVotPob where idP = $regId"));
		$pie=sprintf(strftime(__('Última modificación %H:%M %d %b %Y por %%s'),$regMod),$rgN);
	      }
	    }
	  }
	else
	  $pie= __('Para consultar, introduzca sólo el DNI');
	die($jefp.'<form method=post id=formReg onsubmit="cubre()" name=frm><table width="100%"><tr id=rgDNI><td class=lab>'.__('DNI').': <td> <input name=id value="'.enti($id).
		'"><tr id=rgPwd><td class=lab>'.__('Contraseña').': <td> <input name=pwd value="'.enti($pwd).
		'">'.$mscp.'<tr id=rgAct><td><td><input type=submit name="acc[regPw]" value="'.__('Actualizar').'"><tr id=rgPie><td><td>'.$pie.
		'</table></form><script>document.frm.id.focus();</script>');
	// }}}

    case 'nueMes': // {{{
	if ($jf<2)
	  die($jefe.'auth');
	if (strftime("%H") < 12)
	  $ini=strtotime("12:00");
	else
	  $ini=strtotime("tomorrow 12:00");
	$fin=$ini+3600*8;
	$nom=__('Nueva'); $mkey=substr(md5(uniqid('',true)),0,20);
	mysql_query("insert into eVotMes (nomMes,ini,fin,est,adm,monmkey) values ('$nom',$ini,$fin,0,$iAm,'$mkey')");
	$idM=mysql_insert_id();
	bckup();
	die("$jefe<form method=post onsubmit=\"cubre()\"><input name=lames value=$idM type=hidden>".__('Creada').' <input type=submit name="acc[edMesC]" value="'.__('Editar').'"></form></div>');
	// }}}

    case 'imgModMes': // {{{
	modmes();
	$orgscr=intval($_REQUEST['elscroll'])+1;
    case 'imgMod':
	echo '<script>window.onload=function () {window.scrollBy(0,10000000); }</script>';
    case 'imgMgr':
	if ($jf<2)
	  die($jefe.'auth');
	$nuim=array(); // {{{ Nuevas
	if ($ni=current($_FILES))
	  $nuim[]=array($ni['name'],$ni['tmp_name'],file_get_contents);
	if ($ni=$_REQUEST['wimg'])
	  $nuim[]=array(basename($ni),$ni,pillaURL);
	foreach($nuim as $uno) {
	  list($ni,$fil,$func)=$uno;
	  list($x,$y,$tip)=@getimagesize($fil);
	  if (!$x)
	    continue;
	  $nx=$x; $ny=$y;
	  if ($x > 5*$y) {
	    if ($x >375) {
	      $nx=375; $ny=$y*375/$x;
	    }
	  }
	  else if ($y >75) {
	    $ny=75; $nx=$x*75/$y;
	  }
	  $im=@$func($fil);
	  if (($nx != $x and !($jf >= 3 and $mante)) or $tip < 1 or $tip > 3) { // resize y no jefe en mante, o no tipo conocido
	    ob_start();
	    $im=@imagecreatefromstring($im);
	    if (!$im)
	      continue;
	    if ($nx != $x) {
	      $im2=imagecreatetruecolor($nx,$ny);
	      imagecopyresampled($im2,$im,0,0,0,0,$nx,$ny,$x,$y);
	      imagegif($im2);
	    }
	    else
	      imagegif($im);
	    $im=ob_get_clean();
	  }
	  $im=mysql_real_escape_string($im); $try=0;
	  while (true) {
	    $idI=rand(100,2147483647);
	    if (mysql_query("insert into eVotImgs (idI,nomImg,img,tipo,prop) values ($idI,'$ni','$im','$tip',$iAm)")) break;
	    if ($try++ > 20) break;
	  }
	  $iins=$idI;
	} // }}}
	$aacc=current($aacc);
	$que=@key($aacc);
	$key=intval(@key(current($aacc)));
	if ($idM=intval($_REQUEST['lames'])) {
	  list($est)=mysql_fetch_row(mysql_query("select est from eVotMes where idM = $idM and ( adm = 0 or adm = $iAm )"));
	  if (!isset($est))
	    die(__('Error interno'));
	  $ok=($est<2 or $mante);
	  switch($que) {
	    case 'lst': $tab='eVotOpcs'; $nimg='imgO';
	      list($eim)=mysql_fetch_row(mysql_query("select $nimg from eVotMes,eVotElecs,eVotVots,eVotOpcs where mesaElec = idM and elecVot = idE and votOpc = idV and idO = '$key' and idM = '$idM'"));
	      $id='idO'; break;
	    case 'sep': $tab='eVotOpcs'; $nimg='imgS';
	      list($eim)=mysql_fetch_row(mysql_query("select $nimg from eVotMes,eVotElecs,eVotVots,eVotOpcs where mesaElec = idM and elecVot = idE and votOpc = idV and idO = '$key' and idM = '$idM'"));
	      $id='idO'; break;
	    case 'can': $tab='eVotCan';   $nimg='imgC';
	      list($eim,$opcCan)=mysql_fetch_row(mysql_query("select imgC,idO from eVotMes,eVotElecs,eVotVots,eVotOpcs,eVotCan where opcCan = idO and mesaElec = idM and elecVot = idE and votOpc = idV and canOpc = '$key' and idM = '$idM'"));
	      $id="opcCan = $opcCan and canOpc"; break;
	    case 'mie': $tab='eVotMiem';  $nimg='imgM';
	      list($eim)=mysql_fetch_row(mysql_query("select $nimg from eVotMiem where mesMiemb = $idM and miembMes = $key"));
	      $id="mesMiemb = '$idM' and miembMes"; break;
	    default:
	      die($jefe.__('Error interno'));
	  }
	  $retn='edMesC';
	}
	else {
	  if ($jf<3)
	    die($jefe.'auth');
	  switch($que) {
	    case 'error': $tab='eVotDat'; $nimg='imgErr';
	      list($eim)=mysql_fetch_row(mysql_query("select $nimg from $tab"));
	      $id="1"; $retn=''; break;
	    case 'auth': $tab='eVotMetAut'; $nimg='imgA';
	      list($eim)=mysql_fetch_row(mysql_query("select $nimg from $tab where idH = $key"));
	      $id='idH'; $retn='gesAut'; break;
	    default:
	      die($jefe.__('Error interno'));
	  }
	  $ok=true;
	}
	if (!isset($eim))
	  die($jefe.__('Error interno'));
	isset($orgscr) or $orgscr=intval($_REQUEST['orgscr']);
	$cga=($_REQUEST['cga']) ? 'enctype="multipart/form-data"' :'';
	echo "$jefe<form name=formu method=post $cga $scro<input type=hidden name=orgscr value=$orgscr><input type=hidden name=lames value=\"$idM\">".
		__('Marque la que quiere seleccionar y las que quiere eliminar (eliminará para todo el sistema)');
	if (isset($_REQUEST['coj']) and $ok) {
	  $eim=intval($_REQUEST['coj']);
	  mysql_query("update $tab set $nimg = $eim where $id = $key");
	}
	$sup=($jf >= 3 and $mante) ? 1 : 0;
	if ($nmi=$_REQUEST['nmi'])
	  foreach($nmi as $idI => $nom) {
	    $idI=intval($idI);
	    $nom=mysql_real_escape_string($nom);
	    if (!$nom and $idI > 10) {
	      $esta=false;
	      foreach(array('imgO'=>'eVotOpcs','imgS'=>'eVotOpcs','imgC'=>'eVotCan','imgM'=>'eVotMiem','imgErr'=>'eVotDat','imgA'=>'eVotMetAut') as $inimg => $itab)
		if (mysql_num_rows(mysql_query("select * from $itab where $inimg = $idI"))) {
		  $esta=true;
		  break;
		}
	      if (!$esta)
		mysql_query("delete from eVotImgs where idI = '$idI' and ocu=0 and (prop = $iAm or $sup = 1)");
	    }
	    else {
	      $pub=($_REQUEST['pub'][$idI]) ? 1 : 0;
	      mysql_query("update eVotImgs set nomImg = '$nom' , pub = $pub where idI = '$idI' and ocu=0 and (prop = $iAm or $sup = 1)");
	      if ($sup == 1) {
	        $ocu=($_REQUEST['ocu'][$idI]) ? 1 : 0;
		mysql_query("update eVotImgs set ocu=$ocu where idI = '$idI'");
	      }
	    }
	  }
	list($vocu)=mysql_fetch_row(mysql_query("select ocu from eVotImgs where IdI=$eim"));
	bckup();
	if ($vocu or $vocu=$_REQUEST['vocu'])
	  $svocu='';
	else
	  $svocu="where ocu = 0";
	echo '<table id=tbimgs><tr><th>'.__('Seleccionar').'<th>'.__('Nombre').'<th>'.__('Imagen').'<th>'.__('Pública').(($vocu) ? '<th>'.__('Oculta') : '');
	$q=mysql_query("select * from eVotImgs $svocu order by nomImg"); $ult=''; $subi='';
	while ($im=mysql_fetch_assoc($q)) {
	  $idI=$im['idI'];
	  $sel=($idI == $eim) ? 'checked': '';
	  $una="<tr><td><input type=radio name=coj value=$idI id=coj_$idI $sel><td>".
		(($im['prop'] == $iAm or $sup == 1) ? "<input id=nmImg name=\"nmi[$idI]\" value=\"".enti($im['nomImg']).'">' : enti($im['nomImg'])).
		"<td><label for=coj_$idI><img align=absmiddle src=\"?getim=$idI\" title=\"$idI\"></label>";
	  $pub=(($im['pub']) ? 'checked': '').' '.(($im['prop'] != $iAm and ! $sup) ? 'disabled' : '');
	  $ocu=(($im['ocu']) ? 'checked': '').' '.(($sup) ? '' : 'disabled');
	  $una.="<td><input type=checkbox name=\"pub[$idI]\" $pub> ".(($vocu) ? "<td><input type=checkbox name=\"ocu[$idI]\" $ocu> " : '');
	  if ($sel)
	    $ult=$una;
	  else if ($idI == $iins)
	    $subi=$una;
	  else
	    echo $una;
	}
	$sel=(!$eim) ? 'checked': '';
	echo "<tr><td><input type=radio name=coj id=coj_0 value=0 $sel><td><label for=coj_0>".__('Ninguna').'</label>'.
		"$ult$subi</table><p><input type=checkbox name=cga id=cgach><label for=cgach> ".__('Subir imagen').'</lable>'.
		(($cga) ? ': <input type="hidden" name="APC_UPLOAD_PROGRESS" value="'.($upid=uniqid('')).'"><input id=ldfil type=file name=nimg>' : '').
		'<p>'.__('Cargar de Web').": <input id=wimg size=80 name=wimg><p><input id=btimgMgr type=submit".(($cga) ? ' onclick="moni(this)"' : '').
			" name=\"acc[imgMgr][$que][$key]\" value=\"".__('Actualizar').(($ok) ? '"' : '" disabled').
		'> <input id=btvedMesC onclick="elscroll.value='.(($idM) ? 'orgscr.value' : '1')."\" type=submit name=\"acc[$retn]\" value=\"".__('Volver').
		'"><input type=checkbox id=vocu name=vocu '.(($vocu) ? 'checked': '').'><label for=vocu>'.
		__('Ver imágenes ocultas').'</label></form></div>';
	if ($cga) moniac($upid);
	break; // }}}

    case 'partModMes': // {{{
	modmes();
	$orgscr=intval($_REQUEST['elscroll']);
	echo '<script>window.onload=function () {window.scrollBy(0,10000000); }</script>';
    case 'partMgr':
	if ($jf<2)
	  die($jefe.'auth');
	$idM=intval($_REQUEST['lames']) or die(__('Selección incorrecta'));
	$idE=intval(@key($extra=current($aacc)));
	if (!$esta=mysql_fetch_row(mysql_query("select est from eVotMes,eVotElecs where mesaElec = idM and idE = '$idE' and idM = '$idM'")))
	  die(__('Error interno'));
	$cga=($_REQUEST['cga']) ? 'enctype="multipart/form-data"' :'';
	if (isset($orgscr))
	  $_SESSION['censo'][$idE]=array();
	else
	  $orgscr=intval($_REQUEST['orgscr']);
	echo "$jefe<form name=formu method=post $cga $scro<input type=hidden name=orgscr value=$orgscr><input type=hidden name=lames value=$idM>",
		'<input type="hidden" name="APC_UPLOAD_PROGRESS" value="'.($monid=uniqid('')).'">';
	moniac($monid);
	if (@key(current($extra)) == 'borr') {
	  mysql_query("delete eVotPart from eVotPart,eVotPob where partElec = idP and elecPart = '$idE' and acude = 0");
	  mysql_query("optimize table eVotPart");
	}
	$err='';
	$info=intval($esta>1);
	$ky=$_POST['APC_UPLOAD_PROGRESS'];
	if ($cgv=current($_FILES)) {
	  $err=''; $c=0; $_SESSION['censo'][$idE]=array();
	  ini_set('max_execution_time',10000);
	  $fp=fopen($tmpn=$cgv['tmp_name'],'r');
	  apc_store("t$ky",$t=filesize($tmpn),100000);
	  while ($uno=fgets($fp)) {
	    $c+=strlen($uno)+1;
	    apc_store("c$ky",$c,100000);
	    if ($uno)
	      if (list($idP)=parsea($uno))
		mysql_query("insert into eVotPart (partElec,elecPart,info) values ($idP,'$idE',$info)");
	      else
		$err.=$uno;
	  }
	}
	if ($msv=$_REQUEST['msv']) {
	  foreach(explode("\r\n",$msv) as $uno)
	    if ($uno)
	      if (list($idP)=parsea($uno))
		mysql_query("insert into eVotPart (partElec,elecPart,info) values ($idP,'$idE',$info)");
	      else
		$err.="$uno\n";
	}
	if ($err)
	  die(__('Se produjo un error al cargar algunos votantes').'<textarea name=msv'.filcol($err,"\n").'</textarea>'.
		"<p><input id=btelpartMgr onclick=\"moni(this)\" type=submit name=\"acc[partMgr][$idE]\" value=\"".__('Actualizar').'"> '.
		'<input id=btvedMesC onclick="elscroll.value=orgscr.value" type=submit name="acc[edMesC]" value="'.__('Volver').'"></form></div>');
	if ($bop=$_REQUEST['bop'])
	  foreach($bop as $idP => $dum) {
	    $idP=intval($idP);
	    mysql_query("delete from eVotPart where elecPart = '$idE' and partElec = '$idP' and acude = 0");
	  }
	$np=100;
	list($tpa)=mysql_fetch_row(mysql_query("select count(idP) from eVotPart,eVotPob where partElec = idP and elecPart = '$idE'"));
	if ($tpa/$np < 100)
	  $np=intval(($tpa-1)/100)+1;
	$cua=intval(ceil($tpa/$np));
	if ($np > 1) {
	  $pqs=array('nom'=>__('Nombre'),'us'=>__('Usuario'),'DNI'=>__('DNI'));
	  $pri=$_REQUEST['pri'];
	  if ($pqs[$pri]) {
	    $pq=$pri;
	    $pri=0;
	  }
	  else {
	    $pri=intval($pri);
	    if (!$pqs[$pq=$_REQUEST['pq']]) $pq='nom';
	  }
	  $sel=''; foreach($pqs as $q=>$v) $sel.="<option value=$q".(($pq == $q) ? ' selected' : '').">$v";
	  if (!$ky or $msv or $cgv) {
	    printf(__('Hay %d censados'),$tpa);
	    die("<p><input id=btelpartMgr onclick=\"moni(this)\" type=submit name=\"acc[partMgr][$idE]\" value=\"".__('Inspeccionar').'"> '.__(' por ').
		"<select name=pq>$sel</select>".
		" <input id=btibopartMgr type=submit $pacien name=\"acc[partMgr][$idE][borr]\" value=\"".__('Vaciar el censo').
		'"> <input id=btvedMesC onclick="elscroll.value=orgscr.value" type=submit name="acc[edMesC]" value="'.__('Volver').'">');
	  }
	  apc_store("l$ky",$tpa,100000);
	  apc_delete("t$ky");
	  printf('<p>'.__('%sActualizar y saltar%s cerca de'),"<input type=submit onclick=\"moni(this)\" id=btelpartMgr2 name=\"acc[partMgr][$idE]\" value=\"",'">');
	  echo "<input type=hidden name=pq value=$pq> <select name=\"pri\">";
	  foreach($pqs as $q=>$v)
	    echo "<option value=$q>".__('Clasificar por ').$v;
          for ($i=0,$ipg=0; $i<$tpa; $i+=$cua,$ipg++) {
            echo '<option'.(($i == $pri) ? ' selected' : '')." value=$i>";
	    if (!$nom=$_SESSION['censo'][$idE][$pq][$ipg]) {
	      list($nom)=mysql_fetch_row(mysql_query("select $pq from eVotPart,eVotPob where partElec = idP and elecPart = '$idE' order by $pq limit $i,1"));
	      $_SESSION['censo'][$idE][$pq][$ipg]=$nom;
	      apc_store("c$ky",$i,100000);
	    }
	    echo $nom;
          }
          echo '</select><p>';
	  apc_store("c$ky",$tpa,100000);
        }
	else { $pq='nom'; $pri=0; }
	$q=mysql_query("select * from eVotPart,eVotPob where partElec = idP and elecPart = '$idE' order by $pq limit $pri,$cua");
	echo (($hay=mysql_num_rows($q)) ? __('Marque los que quiere eliminar') : '').'<p><table>';
	while ($pt=mysql_fetch_assoc($q)) {
	  $idP=$pt['idP'];
	  echo '<tr><td>'.(($pt['acude']) ? '' : "<input class=bopr type=checkbox id=bop_$idP name=\"bop[$idP]\">")." <td><label for=bop_$idP>{$pt['DNI']} {$pt['nom']}</label>";
	}
	echo '</table><p><input type=checkbox id=cgach name=cga><label for=cgach> '.__('Cargar de un archivo').'</label>'.
		(($cga) ? ' <input id=fiVot type=file name="fich">' : '').'<br>'.
		"<input id=btelpartMgr onclick=\"moni(this)\" type=submit name=\"acc[partMgr][$idE]\" value=\"".__('Actualizar').'"> '.
		'<input id=btvedMesC onclick="elscroll.value=orgscr.value" type=submit name="acc[edMesC]" value="'.__('Volver').'"></form></div>';
	bckup();
	break; // }}}

    case 'clonMes': // {{{
	if ($jf<2)
	  die($jefe.'auth');
	$idM=intval($_REQUEST['lames']) or die(__('Selección incorrecta'));
	$cur=mysql_fetch_assoc(mysql_query("select nomMes,adm,prc,exclu from eVotMes where idm = $idM"));
	if (strftime("%H") < 12)
	  $ini=strtotime("12:00");
	else
	  $ini=strtotime("tomorrow 12:00");
	$fin=$ini+3600*8;
	function cpyRec($r,$e='') {
	  $cmps=''; $vals='';
	  foreach($r as $cmp => $val) {
	    if ($cmp == $e)
	      continue;
	    $cmps.=",$cmp";
	    $vals.=",'".mysql_real_escape_string($val)."'";
	  }
	  return array($cmps,$vals);
	}
	list($cmps,$vals)=cpyRec($cur);
	$mkey=substr(md5(uniqid('',true)),0,20);
	mysql_query("insert into eVotMes (ini,fin,monmkey,est$cmps) values ($ini,$fin,'$mkey',0$vals)");
	$nidM=mysql_insert_id();
	if ($per=(@key(current($aacc)) == 'p')) {
	  $qM=mysql_query("select pes, imgM, miembMes from eVotMiem where mesMiemb = $idM");
	  while ($mi=mysql_fetch_assoc($qM)) {
	    list($cmps,$vals)=cpyRec($mi);
	    mysql_query("insert into eVotMiem (mesMiemb,carg$cmps) values ($nidM,'v'$vals)");
	  }
	}
	$qE=mysql_query("select idE,nomElec,lev,tAuth,posE,abie,vlog,audit,clien,pie,censoP,ayupap,anulable,sCertS,sKeyS,sModS,sExpS from eVotElecs where mesaElec = $idM");
	while ($el=mysql_fetch_assoc($qE)) {
	  $idE=$el['idE'];
	  // reescribo los campos de las llaves
	  list($sCertS,$sKeyS,$sModS,$sExpS)=newKCEM('',($klng/8-11)*8);
	  list($keyS)=mysql_fetch_row(mysql_query("select keyyS from eVotDat"));
	  $k=openssl_pkey_get_private($keyS);
	  if (!openssl_private_encrypt(base64_decode($sModS),$msf,$k))
	    die(openssl_error_string());
	  $sModS=base64_encode($msf);
	  $monekey=substr(md5(uniqid('',true)),0,20);
	  foreach(array('sKeyS','sModS','sExpS','sCertS','monekey') as $q)
	    $el[$q]=$$q;
	  list($cmps,$vals)=cpyRec($el,'idE');
	  mysql_query("insert into eVotElecs (mesaElec$cmps) values ($nidM$vals)");
	  $nidE=mysql_insert_id();
	  if ($per) {
	    $qP=mysql_query("select partElec from eVotPart where elecPart = $idE");
	    while (list($pp)=mysql_fetch_row($qP))
	      mysql_query("insert into eVotPart (elecPart,partElec) values ($nidE,$pp)");
	  }
	  $qV=mysql_query("select idV, nomVot, minOps, maxOps, posV, nulo from eVotVots where elecVot = $idE");
	  while ($vo=mysql_fetch_assoc($qV)) {
	    $idV=$vo['idV'];
	    list($cmps,$vals)=cpyRec($vo,'idV');
	    mysql_query("insert into eVotVots (elecVot$cmps) values ($nidE$vals)");
	    $nidV=mysql_insert_id();
	    $trad=array();
	    $qO=mysql_query("select idO, sepa, nomOpc, imgO, imgS, posO from eVotOpcs where votOpc = '$idV'");
	    while ($op=mysql_fetch_assoc($qO)) {
	      $idO=$op['idO'];
	      list($cmps,$vals)=cpyRec($op,'idO');
	      mysql_query("insert into eVotOpcs (votOpc$cmps) values ($nidV$vals)");
	      $nidO=mysql_insert_id();
	      $trad[$idO]=$nidO;
	      if ($per) {
		$qC=mysql_query("select canOpc, posC, imgC from eVotCan where opcCan = '$idO'");
		while ($cn=mysql_fetch_assoc($qC)) {
		  list($cmps,$vals)=cpyRec($cn);
		  mysql_query("insert into eVotCan (opcCan$cmps) values ($nidO$vals)");
		}
		$qS=mysql_query("select supOpc, posS from eVotSup where opcSup = '$idO'");
		while ($sp=mysql_fetch_assoc($qS)) {
		  list($cmps,$vals)=cpyRec($sp);
		  mysql_query("insert into eVotSup (opcSup$cmps) values ($nidO$vals)");
		}
	      }
	    }
	    $qP=mysql_query("select nomPL, preVot from eVotPreLd where votPre = '$idV'");
	    while ($pL=mysql_fetch_assoc($qP)) {
	      $preVot=unserialize($pL['preVot']); $aux=array();
	      foreach($preVot as $uno => $dum)
		$aux[$trad[$uno]]=true;
	      $preVot=$aux;
	      $pL['preVot']=serialize($preVot);
	      list($cmps,$vals)=cpyRec($pL);
	      mysql_query("insert into eVotPreLd (votPre$cmps) values ($nidV$vals)");
	    }
	  }
	}
	bckup();
	die("$jefe<form method=post onsubmit=\"cubre()\"><input type=hidden name=lames value=$nidM>".
		__('Clonada').' <input id=btedMesC type=submit name="acc[edMesC]" value="'.__('Editar').'"></form></div>');
	break; // }}}

    case 'notiMMes': // {{{
	modmes();
	$orgscr=intval($_REQUEST['elscroll']);
    case 'notiMes':
	if ($jf<2)
	  die($jefe.'auth');
	$idM=intval($_REQUEST['lames']) or die(__('Selección incorrecta'));
	$mes=mysql_fetch_assoc(mysql_query("select * from eVotMes where idM = '$idM' and ( adm = 0 or adm = $iAm or $jf > 2 )"));
	if (!$mes)
	  die($jefe.__('Error interno'));
	$msgm=$_REQUEST['msgm'];
	$msgv=$_REQUEST['msgv'];
	$msga=$_REQUEST['msga'];
	$org=dirmail(NULL,$iAm);
	if ($msgm or $msgv or $msga) {
	  echo __('Espere').'<p>'; flush();
	  $s=haz_subj(__('Notificación del Sistema de Voto Telemático'));
	  $as=__('Notificacion');
	  if ($msgm) {
	    $q=mysql_query("select eVotPob.* from eVotPob,eVotMiem where miembMes = idP and mesMiemb = $idM");
	    $md=array();
	    while ($us=mysql_fetch_assoc($q))
	      $md[]=dirmail($us);
	    enviMail($org,$md,haz_alter(str_replace("\r\n",'<br>',$msgm)),$s,$as);
	    echo __('Mensaje enviado a la mesa').'<br>';
	  }
	  if ($msgv) {
	    $md=array();
	    $qE=mysql_query("select idE from eVotElecs where mesaElec = $idM");
	    while (list($idE)=mysql_fetch_row($qE)) {
	      $q=mysql_query("select eVotPob.* from eVotPob,eVotPart where partElec = idP and elecPart = $idE");
	      while ($us=mysql_fetch_assoc($q))
		$md[]=dirmail($us);
	    }
	    enviMail($org,$md,haz_alter(str_replace("\r\n",'<br>',$msgv)),$s,$as);
	    echo __('Mensaje enviado al censo').'<br>';
	  }
	  if ($msga) {
	    $md=array();
	    $qE=mysql_query("select idE from eVotElecs where mesaElec = $idM");
	    while (list($idE)=mysql_fetch_row($qE)) {
	      $q=mysql_query("select eVotPob.* from eVotPob,eVotPart where partElec = idP and elecPart = $idE and (pwd = '' or (cadPw > 0 and cadPw < $now))");
	      while ($us=mysql_fetch_assoc($q))
		$md[]=dirmail($us);
	    }
	    list($mxpe)=mysql_fetch_row(mysql_query("select count(idH) from eVotMetAut where disp = 1"));
	    $q=mysql_query("select eVotPob.* from eVotPob,eVotMiem where miembMes = idP and mesMiemb = $idM and pes > $mxpe and (pwd = '' or (cadPw > 0 and cadPw < $now))");
	    while ($us=mysql_fetch_assoc($q))
	      $md[]=dirmail($us);
	    enviMail($org,$md,haz_alter(str_replace("\r\n",'<br>',$msga)),$s,$as);
	    echo __('Mensaje enviado a las personas sin autenticación correcta').'<br>';
	  }
	}
	else {
	  $eeum=__("Este es un mensaje del Sistema de Voto Telemático\n");
	  $msgm or $msgm=$eeum.strftime(__("Le informamos que ha sido nombrado miembro de una mesa electoral para el día %d de %B de %Y a las %H:%M.\nPor favor acceda cuanto antes al [Sistema]"),$mes['ini']);
	  $msgv or $msgv=$eeum.strftime(__("El día %d de %B de %Y a las %H:%M comienzan unas elecciones en las que puede participar accediendo al [Sistema]"),$mes['ini']);
	  if (!$msga) {
	    $req=false;
	    $qE=mysql_query("select idE,tAuth from eVotElecs where mesaElec = $idM");
	    while (list($idE,$tAuth)=mysql_fetch_row($qE))
	      foreach(explode(';',$tAuth) as $unos)
		foreach(explode(',',$unos) as $uno)
		  if ($uno == 1)
		    $req=true;
	    if ($req) {
	      if (!list($ayu)=mysql_fetch_row(mysql_query("select infUrl from eVotDat")))
		$ayu="$hst$escr";
	      $msga=$eeum.sprintf(strftime(__("Usted no dispone de la capacidad de autenticación necesaria para las elecciones del día %d de %B.\nConsulte la ayuda del [Sistema][%%s]"),$mes['ini']),$ayu);
	    }
	  }
	}
	isset($orgscr) or $orgscr=intval($_REQUEST['orgscr']);
	echo "$jefe<form id=formNotif name=formu method=post $scro<input type=hidden name=orgscr value=$orgscr><input type=hidden name=lames value=$idM><div id=menmm>".
		__('Mensaje para los miembros de la mesa').'</div>'.'<textarea name=msgm'.filcol($msgm,"\n",4).'<br><div id=mence>'.
		__('Mensaje para el censo').'</div>'.'<textarea name=msgv'.filcol($msgv,"\n",4).'<br><div id=menac>'.
		(($msga) ? __('Mensaje para las personas sin autenticación correcta').'</div>'.'<textarea name=msga'.filcol($msga,"\n",4).'<br><br>' : '').
		'<input id=btnotiMes type=submit name="acc[notiMes]" value="'.__('Enviar').'"> <span id=menres>'.__('los mensajes. Debería hacerlo sólo una vez').
		'</span><p><input id=btvedMesC onclick="elscroll.value=orgscr.value" type=submit name="acc[edMesC]" value="'.__('Volver').'"></form>';
	break;
	// }}}

    case 'modMes':
	modmes();
    case 'edMesC': // {{{
        $idM or $idM=intval($_REQUEST['lames']) or die(__('Selección incorrecta'));
    case 'edMesJ':
        $idM or $idM=intval(@key(current($aacc))) or die(__('Selección incorrecta'));
    case 'edMesV':
	$idM or $idM=intval($_REQUEST['eidMV']) or die(__('Selección incorrecta'));
    case 'edMes':
	$idM or $idM=intval($_REQUEST['eidM']) or die(__('Selección incorrecta'));
	if ($jf<2)
	  die($jefe.'auth');
	$cmb='<input id=btcmmodMes name="acc[modMes]" type=submit tabindex=1 value="'.__('Cambiar').'">';
	echo '<script>var aval,curo; function copia(o) { curo=o; aval=o.value; } function vacio(o) { if ((o.value.replace(/^\s+|\s+$/g,"") == "") && !confirm("'.
		jsesc(__('Al dejar un nombre en blanco, borrará el objeto y TODOS los que derivan de él. ¿Está seguro?')).'")) { o.value=aval; setTimeout("curo.focus();",0); return false; } curo=false; return true; }</script>';
	$cuida=' onfocus="copia(this)" onblur="vacio(this)" ';
	$mesa=mysql_fetch_assoc(mysql_query("select * from eVotMes where idM = '$idM' and ( adm = 0 or adm = $iAm or $jf > 2 )"));
	if (!$mesa)
	  die($jefe.__('Error interno'));
	$est=$mesa['est'];
	$disa=($est > 0 and !$mante) ? 'disabled' : '';
	$scro=str_replace(';">','; if (curo) return vacio(curo);">',$scro); // protege de Intro
	echo "$jefe<form method=post $scro<table id=tbedmes border=0 width=100%>";
	echo "<tr><tr><td><td colspan=10>$cmb<tr><td class=lab>".__('Identificador')." <td colspan=10>$idM ".__('Clave de monitorización').": {$mesa['monmkey']}<input type=hidden name=lames value=$idM><tr><td class=lab>";
	if ($est)
	  echo '<input type=submit name="acc[gesMes]['.$idM.'][g]" value="';
	echo __('Estado');
	if ($est)
	  echo '">';
	echo " <td colspan=10>";
	if ($est < 2)
	  echo "<select name=ponest><option value=0>{$estas[0]}<option value=1".(($est) ? ' selected' : '').">{$estas[1]}</select>";
	else
	  echo $estas[$est];
	if ($est == 1)
	  echo ' <input type=submit name="acc[notiMMes]" value="'.__('Notificar').'">';
	echo '<tr><td class=lab><input name=adm id=admedMes type=checkbox'.
		(($mesa['adm']) ? ' checked' : '' )."> <td colspan=4><label for=admedMes>".__('Editada sólo por mí').
		'</label> <td colspan=6 width="40%"><input name=exclu id=exclu type=checkbox '.$disa.
		(($mesa['exclu']) ? ' checked' : '' )." value=1> <label for=exclu>".__('Elecciones excluyentes').
		'<tr><td class=lab>'.__('Nombre').' <td colspan=10 ><input name=nomMes id=nomMes value="'.enti($mesa['nomMes'])."\" $cuida>".
		'<tr><td class=lab>'.__('Hora actual').' <td colspan=10>'.strftime(__('%d/%b/%Y %H:%M'));
	foreach(array('ini'=> __('Inicio'),'fin'=>__('Fin')) as $q=>$tx)
	  if (($now < $mesa[$q] and $est < 3) or !$disa) {
	    echo "<tr><td class=lab>$tx <td colspan=10>".lee_f_h($q,$mesa[$q],strftime("%Y")-1,strftime("%Y")+10);
	    if ($est < 2 and $now + 1800 > $mesa[$q])
	      echo '&nbsp;&nbsp;&nbsp;<font color=red>'.__('¡Ojo!').'</font>';
	  }
	  else
	    echo "<tr><td class=lab>$tx <td colspan=10>".strftime(__('%d/%b/%Y %H:%M'),$mesa[$q]);
	// miembros {{{
	$pesos=array();
	$q=mysql_query("select * from eVotMiem,eVotPob where mesMiemb = '$idM' and miembMes = idP order by carg, nom");
	while ($mi=mysql_fetch_assoc($q)) {
	  $idP=$mi['idP'];
	  $pes=$mi['pes']; $pesos[]=$pes;
	  echo '<tr><td class=lab>'.__('Miembro')." <td colspan=4>{$mi['DNI']} - {$mi['nom']} <td class=lab>".__('cargo')." <td><select $disa name=\"carg[$idP]\">";
	  unset($vcgs['pf']); unset($vcgs['pa']); unset($vcgs['pg']); unset($vcgs['jp']);
	  foreach($vcgs as $cgi => $dum) {
	    echo "<option value=$cgi";
	    if ($mi['carg'] == $cgi) {
	      echo ' selected';
	    }
	    echo ">{$vcgs[$cgi]}";
	  } 
	  echo '</select> <td class=lab>'.__('nivel').": <td><input $disa size=4 name=\"pes[$idP]\" $disa value=\"$pes\"> <td> ";
	  if ($imgM=$mi['imgM'])
	    echo "<input tabindex=100 class=imimgModMes type=image align=absmiddle name=\"acc[imgModMes][mie][$idP]\" src=\"?getim=$imgM\"><td>$cmb";
	  else
	    echo "<input type=submit class=btimgModMes name=\"acc[imgModMes][mie][$idP]\" value=\"".__('Imagen')."\"><td>$cmb";
	}
	if (!$disa)
	  echo '<tr><td class=lab>'.__('Más miembros').' <td colspan=9><textarea id=txtmiem title="'."\" name=mim".filcol($masp['m'],"\n",2)."<td>$cmb";
	// }}}
	// pesos {{{
	if (!$disa) {
	  if ($cps=count($pesos)) {
	    // mas de 15 el alg se dispara
	    $pesos=array_slice($pesos,0,15);
	    function comb($l,$n) {
	      $r=array();
	      if ($n == 1) {
		foreach($l as $e)
        	  $r[]=array($e);
		return $r;
	      }
	      for ($i=0; $i<count($l); $i++) {
		$l1=comb(array_slice($l,$i+1),$n-1);
		foreach($l1 as $e)
        	  $r[]=array_merge(array($l[$i]),$e);
	      }
	      return $r;
	    }
	    $ps=array();
	    for ($i=0; $i<=$cps; $i++) {
	      $u=comb($pesos,$i);
	      foreach($u as $e)
		$ps[array_sum($e)]=1;
	    }
	    ksort($ps);
	    $ps=array_keys($ps);
	    $f=100/$ps[count($ps)-1];
	    foreach($ps as $i=>$e)
	      $ps[$i]=floor($e*$f);
	  }
	  else
	    $ps=array(100);
	  $prc=intval($mesa['prc']); $prcs=''; $sled=false;
	  foreach($ps as $i) {
	    if (!$sled and $i >= $prc) {
	      $prcs.="<option selected value=$i>$i%";
	      $sled=$i;
	    }
	    else
	      $prcs.="<option value=$i>$i%";
	  } // 5 lineas de codigo de depuracion eliminadas por mkInstaller
	}
	else
	  echo "<tr><td class=lab>".__('Apertura')." <td colspan=10>{$mesa['prc']} ";
	// }}}
	// elecciones {{{
	// para el PL
	echo "<script>var opcs=false; function mxctrlg(t,e,v,l) { if (!opcs) { t.checked=false; return; } if (t.checked) { var c=0; for (var o in opcs[e][v].o) { p=document.getElementsByName('prLd['+e+']['+v+']['+l+']['+o+']')[0]; if (p.checked) c++; } if (c > opcs[e][v].m) t.checked=false; } } </script>"; $sOpPL='{';
	$tip=__('Ponga un - para que sea invisible, ¡ojo!: si la deja en blanco la borrará');
	$posAu=array();
	$qAu=mysql_query("select * from eVotMetAut where disp=1");
	while ($pAu=mysql_fetch_assoc($qAu))
	  $posAu[$pAu['idH']]=$pAu['nomA'];
	$qe=mysql_query("select * from eVotElecs where mesaElec = $idM order by posE, nomElec"); $posE=0;
	while ($el=mysql_fetch_assoc($qe)) {
	  $idE=$el['idE']; $sOpPL.="$idE:{";
	  // este textarea no puede llevar $disa para añadir votantes
	  echo "<tr><td class=lab>".__('Elección')." <td colspan=5><textarea $disa class=txtnomE title=\"$tip\" $cuida name=\"nomE[$idE]\"".
		filcol($el['nomElec']).
		' <td width="1%" class=lab>'.__('posi')." <td colspan=4 width=\"1%\"><input class=posE name=\"posE[$idE]\" $disa value=\"".($posE+=10).'">'.
		'<tr><td class=lab colspan=1>'.__('Seguridad')." <td colspan=2>";
	  if (!$disa) {
	    echo "<select name=\"lev[$idE]\">";
	    foreach($segs as $lev => $s)
	      echo "<option value=$lev".(($el['lev'] == $lev) ? ' selected' : '').">$s";
	    echo "</select> ";
	  }
	  else
	    echo "{$segs[$el['lev']]} ";
	  echo "<td colspan=8><input type=checkbox $disa name=\"vlog[$idE]\" id=vlog$idE value=1 ".(($el['vlog']) ? 'checked' : '').
		"> <label for=vlog$idE>".__('Ver logs')."</label> <input type=checkbox $disa name=\"audit[$idE]\" id=audit$idE value=1 ".(($el['audit']) ? 'checked' : '').
		" <label for=audit$idE>".__('Auditable')."</label> <input type=checkbox $disa name=\"clien[$idE]\" id=clien$idE value=1 ".(($el['clien']) ? 'checked' : '').
		" <label for=clien$idE>".__('Cliente remoto')."</label> <input type=checkbox $disa name=\"ayupap[$idE]\" id=ayupap$idE value=1 ".(($el['ayupap']) ? 'checked' : '').
		" <label for=ayupap$idE>".__('Ayuda en papeleta')."</label> <tr><td colspan=3><td colspan=8><input type=checkbox $disa name=\"censoP[$idE]\" id=censoP$idE value=1 ".(($el['censoP']) ? 'checked>' : '>').
		" <label for=censoP$idE>".__('Censo público').'</label>';
	  if (!$mesa['exclu'])
	    echo "&nbsp;&nbsp;<input id=abie_$idE $disa name=\"abie[$idE]\" type=checkbox".(($el['abie']) ? ' checked' : '' ).
		" value=1> <label for=abie_$idE>".__('Abierta')."</label>";
	  echo "<input type=checkbox $disa name=\"anulable[$idE]\" id=anulable$idE value=1 ".(($el['anulable']) ? 'checked>' : '>').
		 " <label for=anulable$idE>".__('Papeleta anulable').'</label>';
	  echo "<tr><td class=lab>".__('Autenticación')." <td colspan=10>";
	  if ($tAuth=$el['tAuth'])
	    $altAu=explode(';',$tAuth);
	  else
	    $altAu=array($dAuth);
	  foreach($altAu as $i=>$au1) {
	    $altAu[$i]=array_fill_keys(explode(',',$au1),true);
	    foreach($posAu as $idH => $nomA)
	      echo "<input type=checkbox $disa name=\"altAu[$idE][$i][$idH]\" value=1 ".(($altAu[$i][$idH]) ? 'checked' : '')."> $nomA ";
	    echo '<br>';
	  }
	  if (count($posAu) > 1) {
	    $i++;
	    foreach($posAu as $idH => $nomA)
	      echo "<input type=checkbox $disa name=\"altAu[$idE][$i][$idH]\" value=1 > $nomA ";
	  }
	  if (!$sPop=$el['totPob'])
	    list($sPop)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = '$idE'"));
	  list($sPart)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = '$idE' and acude = 1"));
	  list($sBBx)=mysql_fetch_row(mysql_query("select count(eleccion) from eVotBBx where eleccion = '$idE'"));
	  echo '<tr><td class=lab colspan=2>'.__('Posibles votantes').' <td colspan=9>'.$sPop.__(', han votado ').$sPart.__(', votos en la urna ').$sBBx.__(', clave de monitorización ').$el['monekey'];
	  // votaciones {{{
	  $qv=mysql_query("select * from eVotVots where elecVot = $idE order by posV, nomVot"); $posV=0;
	  while ($vo=mysql_fetch_assoc($qv)) {
	    $idV=$vo['idV']; $maxOps=$vo['maxOps']; if (!$maxOps) $maxOps=1; $sOpPL.="$idV:{'m':$maxOps,'o':{";
	    echo '<tr><td class=lab colspan=2>'.__('Votación').
		" <td colspan=5><textarea class=txtnomV $disa title=\"$tip\" $cuida name=\"nomV[$idE][$idV]\"".filcol($vo['nomVot']).
		' <td width="1%" class=lab>'.__('posi')." <td colspan=2><input $disa size=3 class=posV name=\"posV[$idE][$idV]\" value=\"".($posV+=10).'"><td>'.$cmb.
		'<tr><td class=lab colspan=3>'.__('Nº opciones').' <td colspan=8>'.__('Mín').
		" <input $disa size=3 class=minOps name=\"minOps[$idE][$idV]\" value=\"{$vo['minOps']}\"> ".__('Máx').
		" <input $disa size=3 class=maxOps name=\"maxOps[$idE][$idV]\" value=\"$maxOps\"> ".
		"&nbsp;&nbsp;<input $disa name=\"nulo[$idE][$idV]\" id=nulo_$idE_$idV type=checkbox".(($vo['nulo']) ? ' checked' : '' ).
		" value=1><label for=nulo_$idE_$idV>".__('Admite nulos')."</label>";
	    // opciones {{{
	    $lOpc=array(); // para la precarga
	    $ql=mysql_query("select * from eVotOpcs where votOpc = $idV order by posO, nomOpc"); $posO=0;
	    while ($lis=mysql_fetch_assoc($ql)) {
	      $idO=$lis['idO']; $lOpc[$idO]=$lis['sepa'].' '.$lis['nomOpc']; $sOpPL.="$idO:1,";
	      echo '<tr><td class=lab colspan=3>'.('Opción').
		" <td colspan=4><textarea $disa class=txtnomO title=\"$tip\" $cuida name=\"nomO[$idE][$idV][$idO]\"".filcol($lis['nomOpc']).
		' <td class=lab>'.__('posi')." <td><input $disa size=3 class=posO name=\"posO[$idE][$idV][$idO]\" value=\"".($posO+=10).'"> <td>';
	      if ($imgO=$lis['imgO'])
		echo "<input tabindex=100 class=imimgModMes type=image align=absmiddle name=\"acc[imgModMes][lst][$idO]\" src=\"?getim=$imgO\"><td>$cmb";
	      else
		echo "<input type=submit class=btimgModMes name=\"acc[imgModMes][lst][$idO]\" value=\"".__('Imagen')."\"><td>$cmb";
	      if (strpos($lis['nomOpc'],'<br/>'))
	        echo '<tr><td colspan=3> <td colspan=8><font color=red>'.__('Precaución con la visualización de opciones multilínea').'</font>';
	      echo '<tr><td class=lab colspan=4>'.__('Separador').
		" <td colspan=5><textarea $disa class=txtsepa name=\"sepa[$idE][$idV][$idO]\"".filcol($lis['sepa'])."<td>";
	      if ($imgS=$lis['imgS'])
		echo "<input tabindex=100 type=image class=imimgModMes align=absmiddle name=\"acc[imgModMes][sep][$idO]\" src=\"?getim=$imgS\"><td>$cmb";
	      else
		echo "<input type=submit class=btimgModMes name=\"acc[imgModMes][sep][$idO]\" value=\"".__('Imagen')."\"><td>$cmb";
	      // candidatos {{{
	      $qc=mysql_query("select * from eVotCan,eVotPob where opcCan = '$idO' and canOpc = idP order by posC, nom"); $posC=0;
	      while ($ci=mysql_fetch_assoc($qc)) {
		$idC=$ci['idP'];
		$lOpc[$idO].=" - {$ci['DNI']}";
		echo '<tr><td class=lab colspan=4>'.__('Candidato/a')." <td colspan=4> {$ci['DNI']} - {$ci['nom']}".
			' <td class=lab>'.__('posi')." <td><input $disa class=posC size=4 name=\"posC[$idE][$idV][$idO][$idC]\" value=\"".($posC+=10).'"> ';
		if ($imgC=$ci['imgC'])
		  echo "<input tabindex=100 type=image class=imimgModMes align=absmiddle name=\"acc[imgModMes][can][$idC]\" src=\"?getim=$imgC\"><td>$cmb";
		else
		  echo "<input type=submit class=btimgModMes name=\"acc[imgModMes][can][$idC]\" value=\"".__('Imagen')."\"><td>$cmb";
	      }
	      if (!$disa)
	        echo '<tr><td class=lab colspan=4>'.__('Más candidatos/as').' <td colspan=6><textarea class=txtcan title="'.
			"\" name=\"can[$idE][$idV][$idO]\"".filcol($masp['c'][$idE][$idV][$idO],"\n",2)."<td>$cmb";
	      // }}}
	      // suplentes {{{
	      $qS=mysql_query("select * from eVotSup,eVotPob where opcSup = '$idO' and supOpc = idP order by posS, nom"); $posS=0;
	      while ($si=mysql_fetch_assoc($qS)) {
		$idS=$si['idP'];
		echo '<tr><td class=lab colspan=4>'.__('Suplente')." <td colspan=4> {$si['DNI']} - {$si['nom']}".
			' <td class=lab>'.__('posi')." <td><input $disa size=4 class=posS name=\"posS[$idE][$idV][$idO][$idS]\" value=\"".($posS+=10).'"> ';
	      }
	      if (!$disa)
		echo '<tr><td class=lab colspan=4>'.__('Más suplentes').' <td colspan=6><textarea class=txtsup title="'.
			"\" name=\"sup[$idE][$idV][$idO]\"".filcol($masp['s'][$idE][$idV][$idO],"n",2)."<td>$cmb";
	      // }}}
	    }
	    $sOpPL.='}},';
	    if (!$disa)
	      echo '<tr><td class=lab colspan=3>'.__('Más opciones').
		   " <td colspan=7><textarea class=txtnomO name=\"nomO[$idE][$idV][n]\" rows=2></textarea> <td>$cmb";
	    $qP=mysql_query("select * from eVotPreLd where votPre = $idV order by nomPL");
	    while ($prLd=mysql_fetch_assoc($qP)) {
	      $idPL=$prLd['idPL'];
	      echo '<tr><td class=lab colspan=3>'.__('Papeleta pre-marcada').
		   " <td colspan=7><textarea $disa class=txtPreLoad name=\"nomP[$idE][$idV][$idPL]\"".filcol($prLd['nomPL'])."<td>$cmb";
	      $prLds=unserialize($prLd['preVot']); $tche=0;
	      foreach($lOpc as $idO => $n) {
		$che='';
		if ($prLds[$idO]) {
		  $tche++;
		  if ($tche <= $maxOps)
		    $che=' checked';
		}
		echo "<tr><td class=lab colspan=4><td colspan=6><input type=checkbox onclick=\"mxctrlg(this,$idE,$idV,$idPL)\" name=\"prLd[$idE][$idV][$idPL][$idO]\"$che>$n";
	      }
	      if ($tche > $maxOps)
		alerta(sprintf(__('He alterado las opciones pre-marcadas en %s'),limp($prLd['nomPL'])));
	    }
	    if (!$disa)
	      echo '<tr><td class=lab colspan=3>'.__('Papeleta pre-marcada').
		   " <td colspan=7><textarea class=txtPreLoad name=\"nomP[$idE][$idV][n]\" rows=2></textarea> <td>$cmb";
	    // }}}
	  }
	  $sOpPL.='},';
	  if (!$disa)
	    echo '<tr><td class=lab colspan=2>'.
		 __('Votación')." <td colspan=8><input $disa class=txtnomV name=\"nomV[$idE][n]\"><td>$cmb";
	  // }}}
	  if (!$el['abie'])
	    echo "<tr><td class=lab colspan=2>".__('Añadir votantes').
		" <td colspan=8><textarea class=txtmasv name=\"masv[$idE]\"".filcol($masp['v'][$idE],"\n",2).
		"<td colspan=2><input type=submit class=btVotantes name=\"acc[partModMes][$idE]\" value=\"".__('Votantes').'">';
	  echo '<tr><td class=lab colspan=2>'.__('Pié')." <td colspan=9><textarea $disa class=txtpie name=\"pie[$idE]\"".filcol($el['pie']);
	  echo "<tr><td colspan=11><hr>";
	}
	$sOpPL.='},';
	if (!$disa)
	  echo "<tr><td class=lab>".__('Elección')." <td colspan=10><input $disa class=txtnomE name=\"nomE[n]\">";
	// }}}
	echo '<script>opcs='.substr(str_replace(',}','}',$sOpPL),0,-1).';</script>';
	echo '</table><input type=submit class=btclonMes name="acc[clonMes][e]" value="'.__('Clonar estructura').
		'"><input type=submit class=btclonMes name="acc[clonMes][p]" value="'.__('Clonar todo')."\">$cmb</form> <br>".
		__('Para eliminar elección, votación u opción, deje el nombre vacío; para eliminar miembro, peso cero; candidato/a, posición 0').'<br>'.
		__('Para añadir personas, una por línea, formato: usuario!DNI!Apellidos, Nombre!correo').'<br>'.
		sprintf(__('Si la dirección de correo es usuario@%s , puede escribir simplemente @ , en general puede escribir direcciones parciales'),$domdef).'</div>'.
		'<div id=vota class=sect><div class=cab><h2>'.__('Previsualización').'</h2></div>';
	$q=mysql_query("select * from eVotMes,eVotElecs where mesaElec = idM and idM = $idM order by posE");
	while ($el=mysql_fetch_assoc($q)) {
	  dispElec($el,true);
	  echo '</form><hr>';
	}
	echo '</div>';
/* deberia haber un mecanismo para regenerarla desde el inicio => desactivarla y borrar todo rastro => eVotPart poner acude a cero y limpiar eVotTickets Y TB listar los que ya han participado, para avisarles */

	break; // }}}

    case 'actMes': // {{{
        $cmp=1;
    case 'actYaMes':
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM,true);
	echo $miem;
	list($esta,$ini)=mysql_fetch_row(mysql_query("select est,ini from eVotMes where idM = '$idM'"));
	if ($esta > 1 or $ini > $now+1800)
	  die(__('Error en secuencia')." $esta $ini $now");
	echo "<form onsubmit=\"cubre()\" method=post><input name=wrkf type=hidden value=\"$wrkf\">";
	if ($inci=$_REQUEST['inci']) {
	  $swrkf['inci']=$inci;
	  $inci=enti($inci);
	  $inci='<b>'.__('Incidencias, diligencias y/o observaciones reflejadas por los miembros de la mesa').'</b><br><br>'.str_replace("\r\n","<br>",$inci).'<br>';
	}
	$vlver=' <input type=submit name="acc[gesMes]" value="'.__('Volver').'"></form></div>';
	$presy=intval($_REQUEST['pres'] != '');
	mysql_query("update eVotMiem set pres=$presy where mesMiemb = '$idM' and miembMes = '$iAm'");
	$qM=mysql_query("select * from eVotMiem,eVotPob where mesMiemb = $idM and miembMes = idP order by carg,nom");
	$haysec=false;
	while ($per=mysql_fetch_assoc($qM))
	  if ($per['carg'][0] == 's')
	    $haysec=true;
	$pres=$rech=$sust=array(); $ermoti=$ermesa=false;
	mysql_data_seek($qM,0);
	while ($per=mysql_fetch_assoc($qM)) {
	  $suid=$per['nom'].','.__(' con DNI ').$per['DNI']; $cg=$per['carg'];
	  if ($per['pres']) {
	    if ($cg[0] == '2') {
	      $cg=$cg[1];
	      if ($cg == 's' and $haysec)
		$cg='v';
	      if ($cg == 'p')
		$cg='v';
	      $sust[]=$suid.__(' se incorpora a la mesa como ').$vcgs[$cg];
	    }
	    else if ($cg == 'pa') {
	      $sust[]=$suid.__(' asume el rol de presidente/a ');
	    } 
	    $pres[]=$suid.__(', actuando como ').$vcgs[$cg];
	  }
	  else {
	    $idP=$per['idP'];
	    if ($cg[0] == '2')
	      $swrkf['moti'][$idP]='---';
	    else {
	      if (!$rz=$_REQUEST['moti'][$idP] and $idP != $iAm)
		$ermoti=true;
	      $rech[]=$suid.', '.__('motivo')." '".enti($rz)."'";
	      $swrkf['moti'][$idP]=$rz;
	    }
	  }
	}
	if (!$presy)
	  die(__('¿Usted no ha revisado los censos y las papeletas?').$vlver);
	if ($ermoti)
	  die(__('Para cada miembro que no ha colaborado, debe explicar un motivo').$vlver);
	if ($ermesa)
	  die(__('Error en la composición de la mesa').$vlver); // 12 lineas de codigo de depuracion eliminadas por mkInstaller
	$ul='<ul style="margin: 0px 0px 0px 0px; padding: 0px 0px 0px 2em; list-style-type:circle;">';
	ob_start();
	echo '<b>'.__('Acta de constitución de la mesa').'</b><br><br>'.__('Reunidos los miembos de la mesa').$ul;
	foreach($pres as $uno)
	    echo "<li>$uno</li>";
	echo '</ul>'.__('se procede a constituir la mesa encargada de las elecciones').$ul;
	$qE=mysql_query("select * from eVotElecs where mesaElec = $idM");
	while ($el=mysql_fetch_assoc($qE))
	  echo '<li>'.$el['nomElec'].'</li>';
	echo "</ul><!--$wrkf-->".strftime(__('con fecha %d de %B de %Y a las %H:%M.'),$now)."<!--$wrkf--><br>";
	if ($ini < $now) {
	  echo '<br><b>'.strftime(__('El inicio estaba previsto el %d de %B de %Y a las %H:%M.'),$ini).'</b><br><br>';
	  $swrkf['dela']=true;
	}
	if ($rech) {
	  echo '<b>'.__('Los siguientes miembros han sido excluidos de la mesa')."</b>$ul";
	  foreach($rech as $uno)
	    echo "<li>$uno</li>";
	  echo '</ul>';
	}
	if ($sust) {
	  echo '<b>'.__('Se han producido las siguientes sustituciones o incorporaciones')."</b>$ul";
	  foreach($sust as $uno)
	    echo "<li>$uno</li>";
	  echo '</ul>';
	}
        echo $inci;
	$swrkf['acta']=$act=ob_get_clean();
	echo $act;
	echo "<p><input type=hidden name=wrkf value=\"$wrkf\">".'<input type=submit id=btactApMes name="acc[actApMes]" value="'.
		__('Proceder').'">'.$vlver;
	break; // }}}

    case 'actApMes': // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM,true);
	echo "$miem<form name=formu onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	$acta=$swrkf['acta'];
	list($adm,$esta,$ini,$fin)=mysql_fetch_row(mysql_query("select adm,est,ini,fin from eVotMes where idM = '$idM'"));
	$rein=' <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Reintentar').'"></form></div>';
	if ($esta > 1 or $ini > $now+1800 or $fin < $now)
	  die(__('Error en secuencia')." $esta $ini $fin $now $rein");
	if ($ini < $now and !$swrkf['dela'])
	  die(__('Error en los tiempos').",$rein");
	$acta=preg_replace('/'.preg_quote("<!--$wrkf-->").'.*?'.preg_quote("<!--$wrkf-->").'/',strftime(__('con fecha %d de %B de %Y a las %H:%M.'),$now),$acta);
	$subj=haz_subj(__('Acta de constitución de mesa electoral celebrada %s'),$now);
	$acta="$subj\n".haz_related($acta,'Acta');
	$q=mysql_query("select * from eVotMiem where mesMiemb = $idM");
	while ($mi=mysql_fetch_assoc($q))
	  if (!($mi['pres'] xor $swrkf['moti'][$mi['miembMes']])) // han podido (des) marcar durante el workflow
	      die(__('Cambios en la mesa').",$rein");
	mysql_query("update eVotMes set est=2,cons=$now,actap='".mysql_real_escape_string($acta)."' where idM = '$idM' and est=1");
	if (mysql_affected_rows()>0) {
	  // borra posibles votantes puestos por error si es abierta
	  mysql_query("delete eVotPart from eVotPart,eVotElecs where elecPart = idE and mesaElec = '$idM' and abie=1");
	  unset($swrkf['inci']); unset($swrkf['moti']);
	  mysql_query("update eVotMiem set inci='' where mesMiemb = $idM");
	  printf(__('Activada, %sVolver%s para firmar'),'<input type=submit id=btgesMes name="acc[gesMes]" value="','">').'</form></div>';
	  // avisar por mail a los miembros para que firmen?
	  enviAct(dirAdmos($adm),$acta);
	  $swrkf=array('idM'=>$idM);
	}
	else
	  echo __('Error en secuencia').",$rein";
	break; // }}} // 37 lineas de codigo de depuracion eliminadas por mkInstaller

    case 'aAbrUrnI':
	$asum=true;
    case 'abrUrnI': // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	$mes=mysql_fetch_assoc(mysql_query("select * from eVotMes where idM = $idM"));
	$fin=$mes['fin'];
	if ($mes['est'] != 2)
	  die(__('No está activa'));
	if ($asum and $swrkf['asumible'] and $mes['cierre'] < $now) {
	  mysql_query("update eVotMiem set carg = 'pf' where mesMiemb = '$idM' and miembMes = '$iAm'");
	  mysql_query("update eVotMiem set carg = 'jp' where mesMiemb = '$idM' and (carg = 'p' or carg = 'pa')");
	}
	auth($idM,true);
	echo $miem;
	$q=mysql_query("select * from eVotElecs where mesaElec = $idM"); $lv=100; $pabr=!$mes['lcn'];
	while ($el=mysql_fetch_assoc($q)) {
	  $idE=$el['idE']; $lv=min($lv,$el['lev']);
	  list($sPart)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE and acude = 1"));
	  list($sBBx)=mysql_fetch_row(mysql_query("select count(eleccion) from eVotBBx where eleccion = $idE"));
	  if ($sPart > $sBBx and $now < $fin+3600)
	    die(strftime(__('Lo sentimos, pero debido a la discrepancia de votos, la apertura se retrasa hasta las %H horas %M minutos.'),$fin+3600));
	  if ($sPart != $sBBx and $authLv < 2)
	    die(__('Debido a la discrepancia de votos, debe <a href="?incauth=t">aumentar su autenticación</a>.'));
	  if ($pabr) {
	    list($sPop)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE"));
	    if ($sPart != $sPop or $el['abie'])
	      $pabr=false;
	  }
	}
	if ($lv>0)
	  $fin+=intval(2*(600+max(1,$lv)*120));
	if ($fin > $now and !$pabr)
	  die('Error en secuencia');
	function nwInci($m1,$m2) {
	  global $incid,$pap;
	  for($i=0; $i<count($pap); $i++)
	    unset($pap[$i][0]);
	  $incid[]=array(enti(str_replace('Array','',print_r($pap,true)))."<b>$m1</b>",$m2);
	}
	$ul='<ul style="margin: 0px 0px 0px 0px; padding: 0px 0px 0px 1em; list-style-type:circle;">';
	// {{{
	ignore_user_abort(true);
	ini_set('max_execution_time',10000);
	$qE=mysql_query("select * from eVotElecs where mesaElec = $idM order by posE");
	while ($el=mysql_fetch_assoc($qE)) {
	  // {{{ Construye $def
	  $idE=$el['idE']; $nomE=$el['nomElec'];
	  $def=array();
	  $qV=mysql_query("select * from eVotVots where elecVot = $idE order by posV");
	  while ($vo=mysql_fetch_assoc($qV)) {
	    $def[$n=$vo['nomVot']]=array( 'min' => $vo['minOps'], 'max' => $vo['maxOps'], 'blks' => 0,
					'incid' => 0, 'nult' => ($vo['nulo']) ? array() : false, 'ops' => array());
	    $d=&$def[$n];
	    $qO=mysql_query("select * from eVotOpcs where votOpc = '{$vo['idV']}'");
	    while ($op=mysql_fetch_assoc($qO)) {
	      $n=$op['nomOpc'];
	      if ($n == '-')
		$n='';
	      $tn=$n;
	      $idO=$op['idO'];
	      $qC=mysql_query("select * from eVotCan,eVotPob where canOpc = idP and opcCan = $idO order by posC limit 2");
	      $cn=mysql_fetch_assoc($qC);
	      if ($cn['idP']) {
	        if ($n !== '') {
		  $n.="\n";
		  $tn.=": ";
		}
	        $n.=$cn['nom'];
		if (mysql_num_rows($qC) > 1)
		  $tn.=__('Lista encabezada por ');
		$tn.=$cn['nom'];
	      }
	      // la x me asegura que un multisort no lo toma como numérico
	      $d['ops']['x'.$n]=0;
	      $d['tops']['x'.$n]=str_replace('<br/>',' / ',$tn); // solo son textos para el acta
	    }
	  }
	  // }}}
	  $incid=array(); // {{{ proc votos
	  list($vBBx)=mysql_fetch_row(mysql_query("select count(eleccion) from eVotBBx where eleccion = $idE"));
	  $monid=$_REQUEST['monid'];
	  apc_store("t$monid",$vBBx,100000);
	  for ($prim=0; $prim < $vBBx; $prim+=100000) {
	    $qB=mysql_query("select voto from eVotBBx where eleccion = $idE limit $prim,100000");
	    while (list($pap)=mysql_fetch_row($qB)) {
	      if (!preg_match_all('%<question>\s*<name>(.*?)</name>\s*<response>(.*?)</response>\s*</question>%',$pap ,$pap, PREG_SET_ORDER)) {
		nwInci('',__('No es una papeleta válida'));
	        continue 1;
	      } 
	      $p=&$pap[0];
	      if ($p[1] != 'E') {
		nwInci('',__('No es una papeleta válida'));
		continue 1;
	      }
	      if (($no=urldecode($p[2])) != $nomE and $nomE != '-') {
		nwInci($no,__('Elección desconocida'));
		continue 1;
	      }
	      $iv=0; $pa=array();
	      for ($i=1; $i<count($pap); $i++) {
		$p=&$pap[$i];
		if ($p[1] == "V".($iv+1) and $def[$no=urldecode($p[2])] ) { // {{{
		  $d=&$def[$no]; // no puede hacerse en el if, define si no esta
		  if ($pa[$no]) {
		    nwInci($no,__('Votación duplicada'));
		    continue 2;
		  }
		  $pa[$no]=array('vd'=>array());
	          $cur=&$pa[$no];
		  $iv++;
		} // }}}
		else if ($p[1] == "O$iv") { // {{{
		  if (!$iv) // opcion antes de votacion
		    continue;
		  if ($cur['nulo']) // ya es nulo, este if no hace falta
		    continue;
		  list($on)=explode("\n ",urldecode($p[2]));
		  if ($on[0] == '*' and $on[strlen($on)-1] == '*') {
		    if (!is_array($d['nult'])) {
		      nwInci($on,__('Nulos no permitidos'));
		      continue 2; 
		    }
		    $cur['nulo']=true;
		  }
		  else if ($on[0] == '_' and $on[strlen($on)-1] == '_') {
		    continue;
		  }
	          else if (!isset($d['ops']["x$on"])) {
		    nwInci($on,__('Opción desconocida'));
		    continue 2;
		  }
		  else if ($cur['vd']["x$on"]) {
		    nwInci($on,__('Opción duplicada'));
		    continue 2;
		  }
		  else
		    $cur['vd']["x$on"]=true;
		} // }}}
		else if ($p[1] == "gO$iv") { // {{{
		  if (!$iv)
		    continue;
		  if ($cur['nulo'])
		    continue;
		  $on=urldecode($p[2]);
		  if ($on[0] == '*' and $on[strlen($on)-1] == '*') {
                    if (!is_array($d['nult'])) {
                      nwInci($on,__('Nulos no permitidos'));
		      continue 2; 
		    }
                    $cur['nulo']=true;
		  }
		} // }}}
		else if ($p[1] == "NT$iv") { // {{{
		  if (!$iv)
		    continue;
		  $nt=urldecode($p[2]);
		  if ($nt === '')
		    continue;
		  if (!is_array($d['nult'])) {
		    nwInci($on,__('Nulos no permitidos'));
		    continue 2;
		  }
		  $cur['nulo']=$nt;
		} // }}}
		else {
		  nwInci($p[1].' '.$p[2],__('Inesperado'));
		  continue 2; 
		}
	      }
	      // llega aqui si la papeleta no ha producido incidencia+nulo
	      foreach($def as $v => $dt) {
		if (!($p=&$pa[$v])) {
		  nwInci($v,__('Falta esa votación'));
		  continue 2;
		}
		$cv=count($p['vd']); 
		if ($cv > $dt['max'] or $cv < $dt['min']) {
		  nwInci("$v - $cv",__('Número de opciones incorrecto'));
		  continue 2;
		}
	      }
	      foreach($pa as $v => $pp) {
		$d=&$def[$v];
		if ($nu=$pp['nulo']) {
		  if (is_bool($nu))
		    $d['nult'][]=__('Papeleta marcada como nula');
		  else
		    $d['nult'][]=$nu;
		}
		else {
		  if (count($pp['vd']))
		    foreach($pp['vd'] as $o => $dum)
		      $d['ops'][$o]++;
		  else
		    $d['blks']++;
		}
	      }
	    }
	    apc_store("c$monid",$prim,100000);
	  } // }}}
	  @mysql_free_result($qB);
	  ob_start();
	  echo '<b>'.__('Procesamiento de votos').'</b><br><br>';
	  if (!$el['abie']) {
	    list($pVo)=mysql_fetch_row(mysql_query("select count(*) from eVotPart where elecPart = $idE"));
	    echo __('Posibles votantes').": $pVo<br>";
	  }
	  list($vEm)=mysql_fetch_row(mysql_query("select count(*) from eVotPart where elecPart = $idE and acude = 1"));
	  $vVal=$vBBx; if ($vInc=count($incid)) $vVal-=$vInc;
	  echo __('Votos emitidos').": $vEm<br>".__('Votos escrutados').": $vBBx<br>".__('Votos válidos').": $vVal<br>".
		(($vInc) ? __('Votos incidentados').": $vInc<br>" : '');
	  if ($vEm != $vBBx)
	    $incid[]=array("$vBBx vs $vEm",__('El número de votos escrutados no coincide con el de emitidos'));
	  if (count($incid)) {
	    echo '<br><b>'.__('Incidencias en el proceso').'</b><ul>';
	    foreach($incid as $inc)
	      echo "<li>$inc[1] ($inc[0])";
	    echo '</ul>';
	  }
	  if ($nomE and $nomE != '-')
	    echo '<br><b>',__('Resultados de'),':',$nomEP=((strpos($nomE,'<br/>') === false) ? " $nomE</b><br><br>" : "<blockquote>$nomE</blockquote></b>");
	  else
	    echo '<br><b>'.__('Resultados'),'</b><br><br>';
	  foreach($def as $nv => $v) { // {{{
	    if ($nv != '-')
	      echo "<b>$nv</b><br><br>";
	    $aux=array();
	    foreach($v['ops'] as $op => $c)
	      $aux[$op]=$op;
	    array_multisort($v['ops'],SORT_NUMERIC,SORT_DESC,$aux,SORT_STRING);
	    echo $ul;
	    // antes hacia arsort($v['ops'],SORT_NUMERIC);
	    foreach($v['ops'] as $op => $c) {
	      echo '<li>'.__('Votos para ')."{$v['tops'][$op]}: <b>$c</b>";
	    }
	    echo '<li>'.__('Votos en blanco').": <b>{$v['blks']}</b><li>".__('Votos nulos por incidencia').": <b>$vInc</b>";
	    if (is_array($v['nult'])) {
	      $vnl=count($v['nult']);
	      echo '<li>'.__('Votos expresamente nulos').": <b>$vnl</b><!--LVN-->";
	      if ($vnl) {
		echo '<font color=grey><ul>';
		foreach($v['nult'] as $t)
		  if ($t)
		    echo '<li>'.enti($t).'</li>';
		echo '</ul></font><!--LVN-->';
	      }
	    }
	    echo '</ul>';
	  } // }}}
	  if ($el['anulable']) {
	    $anulds='';
	    $q=mysql_query("select v.nom vnom, v.dni vdni, m.nom mnom, m.dni mdni, momAn from eVotAnLog, eVotPob as v, eVotPob as m where eleAn = $idE and miemAn = m.idP and persAn = v.idP");
	    while ($anu1=mysql_fetch_assoc($q)) {
	      $anulds.=sprintf(__('La papeleta de "%s (%s)" fue anulada por "%s (%s)" %s').'<br>',$anu1['vnom'],$anu1['vdni'],$anu1['mnom'],$anu1['mdni'],strftime('el %d/%m/%Y a las %H:%M:%S',$anu1['momAn']));
	    }
	    if ($anulds)
	      echo '<br><hr><br>',__('Se realizaron las siguientes anulaciones de papeletas:'),'<br>',$anulds;
	  }
	  echo '<br><hr><br><br><b>'.__('Papeleta mostrada al votante:').'</b><br><br>';
	  dispElec($el); echo '</form>';
	  $record=ob_get_clean();
	  echo __('Acta').':<br><br>'.$record;
	  $record=mysql_real_escape_string($record);
	  mysql_query("update eVotElecs set record='$record' where idE = $idE");

	  $voters="update eVotElecs set voters='".mysql_real_escape_string("<b>");
	  if ($nomE and $nomE != '-')
	    $voters.=mysql_real_escape_string(sprintf(__('Han participado en: %s'),$nomEP));
	  else
	    $voters.=mysql_real_escape_string(__('Han participado').'</b><br><br>');
	  mysql_query("create temporary table TeVotPart as select info,nom from eVotPart,eVotPob where partElec=idP and elecPart = $idE and acude = 1 order by nom");
	  $sPart=mysql_affected_rows();
	  apc_store("t$monid",$sPart,100000);
	  for ($prim=0; $prim < $sPart; $prim+=100000) {
	    $qP=mysql_query("select * from TeVotPart limit $prim,100000");
	    $s='';
	    while ($pe=mysql_fetch_assoc($qP))
	      if ($pe['info'])
		$s.="<font color=red>{$pe['nom']}</font><br>";
	      else
		$s.="{$pe['nom']}<br>";
	    $voters.=mysql_real_escape_string($s);
	    apc_store("c$monid",$prim,100000);
	    mysql_free_result($qP);
	  }
	  mysql_query("drop table TeVotPart");
	  $s='';
	  $voters.="' where idE = $idE";
	  mysql_query($voters);
	  $voters='';

	  // tokens
	  $tokens="update eVotElecs set tokens='".mysql_real_escape_string("<b>");
	  if ($nomE and $nomE != '-')
	    $tokens.=mysql_real_escape_string(__('Tokens de auditoría de').':'.$nomEP);
	  else
	    $tokens.=mysql_real_escape_string(__('Tokens de auditoría').'</b><br><br>');
	  list($sHas)=mysql_fetch_row(mysql_query("select count(eleccion) from eVotBBx where eleccion = $idE"));
	  apc_store("t$monid",$sHas,100000);
	  for ($prim=0; $prim < $sHas; $prim+=100000) {
	    $qH=mysql_query("select voto from eVotBBx where eleccion = $idE limit $prim,100000");
	    $s=array();
	    while (list($vto)=mysql_fetch_row($qH)) {
	      preg_match('%<chk>.*</chk>%',$vto,$mat);
	      $s[]=$mat[0];
	    }
	    sort($s); // en bloques de 100000
	    $tokens.=mysql_real_escape_string(implode('<br>',$s).'<br>');
	    apc_store("c$monid",$prim,100000);
	    mysql_free_result($qH);
	  }
	  mysql_query("drop table TeVotBBx");
	  $s='';
	  $tokens.="' where idE = $idE";
	  mysql_query($tokens);
	  $tokens='';
	} // }}}
	mysql_query("update eVotMes set est = 3 where idM = $idM");
	$qM=mysql_query("select * from eVotMiem,eVotPob where miembMes = idP and mesMiemb = $idM and pres > 0 and idP != $iAm");
	$md=array();
	while ($per=mysql_fetch_assoc($qM))
	  $md[]=dirmail($per);
	enviMail(dirmail(NULL,$iAm),$md,haz_alter(__("Este es un mensaje automático del Sistema de Voto Telemático\n").__('La urna de la mesa electoral de la que usted forma parte ha sido abierta, por favor conéctese al [Sistema]')),__('Urna abierta'),__('Urna abierta'));
	echo "<p><form name=formu onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">".
		'<p><input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Continuar').'">';
	break; // }}}

    case 'cerMes': // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM,true);
	$mes=mysql_fetch_assoc(mysql_query("select * from eVotMes where idM = $idM"));
	$vlver=' <input type=submit name="acc[gesMes]" value="'.__('Volver').'"></form></div>';
	$form="<form name=formu onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	if ($inci=$_REQUEST['inci']) {
	  $swrkf['inci']=$inci;
	  $inci=enti($inci);
	  $inci='<br><b>'.__('Incidencias, diligencias y/o observaciones reflejadas por los miembros de la mesa').'</b><br><br>'.str_replace("\r\n","<br>",$inci).'<br>';
	}
	$pres=intval($_REQUEST['pres'] != '');
	mysql_query("update eVotMiem set presf=$pres where mesMiemb = '$idM' and miembMes = '$iAm'");
	$presf=''; $ermoti=false; $nup=0;
	$qM=mysql_query("select * from eVotMiem,eVotPob where miembMes = idP and mesMiemb = $idM and pres > 0 order by carg, nom");
	$haysec=false;
	while ($per=mysql_fetch_assoc($qM))
	  if ($per['carg'][0] == 's')
	    $haysec=true;
	mysql_data_seek($qM,0);
	while ($per=mysql_fetch_assoc($qM)) {
	  $cg=$per['carg'];
	  if ($cg == 'pg') {
	    $inci.='<br><b>'.sprintf(__('La mesa ha sido intervenida por %s, debido a la ausencia de sus miembros'),$per['nom']).'</b><br><br>'; 
	    $presf='<li>'.__('Todos los miembros están ausentes');
	    break;
	  }
	  if ($cg[0] == '2') {
	    $cg=$cg[1];
	    if ($cg == 's' and $haysec)
	      $cg='v';
	    if ($cg == 'p')
	      $cg='v';
	  }
	  $presf.='<li>'.$per['nom'].','.__(' con DNI ').$per['DNI'].__(', actuando como ').$vcgs[$cg];
	  if ($per['presf']) {
	    if ($cg == 'pf')
	      $presf.=' <b>'.__('(asume el rol)').'</b>';
	  }
	  else {
	    $idP=$per['idP'];
	    if ($rz=$swrkf['moti'][$idP]=$_REQUEST['moti'][$idP] and $idP != $iAm)
	      $presf.=__(', pero <b>ausente al abrir la urna</b> debido a ')." '".enti($rz)."'";
	    else
	      $ermoti=true;
	  }
	  $presf.='</li>';
	}
	if (!$pres)
	  die($form.__('¿Usted no ha revisado los resultados?').$vlver);
	if ($ermoti)
	  die($form.__('Para cada miembro que no ha colaborado, debe explicar un motivo').$vlver);
	ob_start();
	$ul='<ul style="margin: 0px 0px 0px 0px; padding: 0px 0px 0px 2em; list-style-type:circle;">';
	echo '<b>'.__('Mesa electoral').'</b><br><br>';
	echo "<!--$wrkf-->".strftime(__('Con fecha %d de %B de %Y a las %H horas %M minutos'),$now)."<!--$wrkf-->".
		strftime(__(' se cierra la mesa del proceso electoral iniciado el día %d de %B de %Y a las %H horas %M minutos y'),max($mes['cons'],$mes['ini'])).
		strftime(__(' concluído el día %d de %B de %Y a las %H horas %M minutos'),$mes['fin']),
		__(', estando la mesa compuesta por los siguientes miembros:')."$ul$presf</ul>";
	echo $inci;
	$swrkf['actMe']=$actMe=ob_get_clean();
	echo "$miem$actMe$form".'<p><input type=submit class=btcarYaMes name="acc[cerYaMes]" value="'.__('Proceder').'">'.
		' <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Volver').'">';
	break;
	// }}}

    case 'cerYaMes': // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM,true);
	mysql_query("update eVotMes set est = 4, cierre = $now where idM = $idM and est = 3");
	if (!mysql_affected_rows()>0)
	  die(__('Error en secuencia'));
	echo __('Mesa cerrada');
	list($fin,$adm)=mysql_fetch_row(mysql_query("select fin,adm from eVotMes where idM = $idM"));
	$mail=dirAdmos($adm);
	$actMe=preg_replace('/'.preg_quote("<!--$wrkf-->").'.*?'.preg_quote("<!--$wrkf-->").'/',strftime(__('Con fecha %d de %B de %Y a las %H horas %M minutos'),$now),$swrkf['actMe']);
	$qE=mysql_query("select idE from eVotElecs where mesaElec = $idM order by posE, nomElec");
	while (list($idE)=mysql_fetch_row($qE)) {
	  foreach(array('record','voters','tokens') as $idAc) {
	    list($acta)=mysql_fetch_row(mysql_query("select $idAc from eVotElecs where idE = $idE")); // una query por acta, pueden ser grandes
	    $subj=haz_subj(sprintf(__('Acta de la elección %sconcluida %%s'),($nomE and $nomE != '-') ? "'".str_replace('<br/>',' ',$nomE)."' " : ''),$fin);
	    if ($idAc == 'record')
	      $acta=preg_replace('/<!--LVN-->.*?<!--LVN-->/','',$acta);
	    $acta="$subj\n".haz_related("$actMe<br><br>$acta",'Acta');
	    enviAct($mail,$acta);
	    mysql_query("update eVotElecs set $idAc='".mysql_real_escape_string($acta)."' where idE = $idE");
	  }
	  list($totPob) = mysql_fetch_row(mysql_query("select count(*) from eVotPart where elecPart  = $idE"));
	  mysql_query("update eVotElecs set totPob=$totPob where idE = $idE");
	}
	mysql_query("delete eVotRecvr from eVotElecs,eVotRecvr where svy = idE and mesaElec = $idM");
	mysql_query("delete eVotCache from eVotElecs,eVotCache where elecCh = idE and mesaElec = $idM");
	$swrkf=array('idM'=>$idM); // para el envio de actas
	mysql_query("update eVotMiem set inci='' where mesMiemb = $idM");
	$qM=mysql_query("select * from eVotMiem,eVotPob where miembMes = idP and mesMiemb = $idM and presf > 0 and fmdof = 0 and idP != $iAm");
	$md=array();
	while ($per=mysql_fetch_assoc($qM))
	  $md[]=dirmail($per);
	enviMail(dirmail(NULL,$iAm),$md,haz_alter(__("Este es un mensaje automático del Sistema de Voto Telemático\n").__('Si dispone de firma digital, puede firmar las actas de la mesa electoral accediendo al [Sistema]')),__('Mesa cerrada'),__('Mesa cerrada'));
	bckup(true);
	// }}}

    case 'envAct': // {{{
	if (!$idM) {
	  $wrkf=$_POST['wrkf'];
	  $swrkf=&$_SESSION[$wrkf];
	  $idM=$swrkf['idM'];
	}
	auth($idM);
	echo $miem;
	if (!mysql_num_rows(mysql_query("select * from eVotMiem where miembMes = $iAm and mesMiemb = $idM and presf")))
	  die('No autorizado');
	$dom=$_REQUEST['dom'];
	if ($dirs=$_REQUEST['dirs']) {
	  $dirss=array();
	  foreach(explode("\r\n",$dirs) as $dir) {
	    if (!$dir)
	      continue;
	    if (strrpos($dir,'@') === false)
	      $dir.="@$dom";
	    if (!$dirss[$dir]) {
	      echo sprintf(__('Enviando a %s'),$dir).'<br>';
	      $dirss[$dir]=1;
	    }
	  }
	  $dirss=array_keys($dirss);
	  if ($_REQUEST["actap"] and list($acta)=mysql_fetch_row(mysql_query("select actap from eVotMes where idM = $idM")))
	    enviAct($dirss,$acta);
	  $qE=mysql_query("select idE from eVotElecs where mesaElec = $idM");
	  while (list($idE)=mysql_fetch_row($qE))
	    foreach(array('record','tokens','voters') as $idAc)
	      if ($_REQUEST["e$idAc"][$idE]) {
		list($acta)=mysql_fetch_row(mysql_query("select $idAc from eVotElecs where idE = $idE"));
		enviAct($dirss,$acta);
	      }	
	}
	if (!$dom)
	  $dom=$domdef;
	echo '<br>'.__('Envío de actas').'<form onsubmit="cubre()" method=post>'.__('Dominio por defecto').': <input id=dom name=dom value="'.enti($dom).
		'"<br>'.__('Direcciones (una por línea)').
		':<br><textarea id=dirs name=dirs></textarea><p>';
	$qE=mysql_query("select idE,audit,nomElec from eVotElecs where mesaElec = $idM");
	echo '<input type=checkbox checked name="actap"> '.__('Enviar el acta de constitución').'<br>';
	while ($el=mysql_fetch_assoc($qE)) {
	  $che='checked';
	  $lact=array('record'=>__('resultados'),'voters'=>__('lista de votantes'));
	  if ($el['audit'])
	    $lact['tokens']=__('códigos de auditoría');
	  foreach($lact as $idAc => $q) {
	    echo sprintf('<input type=checkbox %s name="e%s[%s]"> '.__('Enviar el acta de %s de la elección %s'),
		$che,$idAc,$el['idE'],$q,$el['nomElec']).'<br>';
	    $che='';
	  }
	}
	echo '<p><input type=submit id=btenvAct name="acc[envAct]" value="'.__('Proceder').'"><p>'."<input type=hidden name=wrkf value=$wrkf>".
	     __('Volver a la').' <input type=submit id=btgesMes name="acc[gesMes]['.$idM.']" value="'.__('gestión').'"></form></div>';
	break; // }}}

    case 'recActJ': // {{{
	$idM=intval(@key($dum=&$aacc[$acc]));
	list($adm,$acta)=mysql_fetch_row(mysql_query("select adm,actap from eVotMes where idM = $idM and ( adm = 0 or adm = $iAm or $jf > 2 )"));
	$vlvr=' <input type=submit class=btedMesJ name="acc[edMesJ]['.$idM.']" value="'.__('Volver').'">';
	echo "$jefe<form onsubmit=\"cubre()\" method=post>";
	if (!$adm)
	  die(__('No es posible, debe marcar la mesa como exclusiva de usted').$vlvr);
	if ($acta) {
	  enviAct($mail=dirmail('',$adm),$acta);
	  list($r,$v,$t)=mysql_fetch_row(mysql_query("select record,voters,tokens from eVotElecs where mesaElec = $idM"));
	  if ($r) {
	    enviAct($mail,$r);
	    enviAct($mail,$v);
	    enviAct($mail,$t);
	  }
	}
	echo __('Enviadas').$vlvr;
	break;
	// }}}

    case 'aGmModMes': // {{{
	$anyado=true;
    case 'amModMes':
	$asum=true;
    case 'mModMes':
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	if ($anyado and $swrkf['gesmes']) {
	  mysql_query("update eVotMiem set presf=0 where mesMiemb = '$idM'");
	  mysql_query("update eVotMiem set carg = 'jp' where mesMiemb = '$idM' and substr(carg,1,1) = 'p'");
	  if (!mysql_query("insert into eVotMiem (mesMiemb,miembMes,carg,pres,presf) values ($idM,$iAm,'pg',1,1)"))
	    mysql_query("update eVotMiem set carg = 'pg',pres=1,presf=1 where mesMiemb = '$idM' and miembMes = '$iAm'");
	  unset($swrkf['gesmes']);
	}
	auth($idM);
	list($ini,$est,$fin,$cie)=mysql_fetch_row(mysql_query("select ini,est,fin,cierre from eVotMes where idM = '$idM'"));
	$swrkf['moti']=$moti=$_REQUEST['moti'];
	$swrkf['inci']=$inci=$_REQUEST['inci'];
	$pres=intval($_REQUEST['pres'] != '');
	if ($est == 1) {
	  mysql_query("update eVotMiem set pres=$pres where mesMiemb = '$idM' and miembMes = '$iAm' and carg != 'jp'");
	  if ($asum and $swrkf['asumible'] and $cie < $now) {
	    mysql_query("update eVotMiem set carg = 'jp',pres=0 where mesMiemb = '$idM' and substr(carg,1,1) = 'p'");
	    if (mysql_affected_rows()>0)
	      mysql_query("update eVotMiem set carg = 'pa' where mesMiemb = '$idM' and miembMes = '$iAm'");
	  }
	}
	else if ($est == 3)
	  mysql_query("update eVotMiem set presf=$pres where mesMiemb = '$idM' and miembMes = '$iAm' and carg != 'jp'");
	if ($est == 1 or $est == 3)
	  mysql_query("update eVotMiem set inci='".mysql_real_escape_string($inci)."' where mesMiemb = '$idM' and miembMes = '$iAm'");
	if (intval($idE=@key($aacc[$acc]))) {
	  if (!mysql_fetch_row(mysql_query("select idE from eVotElecs where idE = $idE and mesaElec = $idM")))
	    die('Hack');
	  if (intval($idP=@key($aacc[$acc][$idE]))) {
	    mysql_query("delete from eVotBBx where votante = $idP and eleccion = $idE");
	    if (mysql_affected_rows() > 0) {
	      mysql_query("update eVotPart set acude = 0 where acude = 1 and partElec = $idP and elecPart = $idE");
	      if (mysql_affected_rows() > 0)
		mysql_query("insert into eVotAnLog (miemAn,eleAn,persAn,momAn) values($iAm,$idE,$idP,$now)");
	    }
	  }
	  $lista='<p>';
	  list($anul)=mysql_fetch_row(mysql_query("select anulable from eVotElecs where idE = $idE"));
	  if ($anul)
	    $q=mysql_query("select * from eVotPart join eVotPob on partElec=idP left join eVotBBx on votante = idP and elecPart=eleccion where elecPart = $idE order by nom");
	  else
	    $q=mysql_query("select * from eVotPart,eVotPob where elecPart = $idE and partElec = idP order by nom");
	  while ($p=mysql_fetch_assoc($q))
	    $lista.=(($p['votante'] and $fin < $now) ? "<input type=submit name=\"acc[mModMes][$idE][${p['idP']}]\" value=\"".__('Anular').'" onclick="this.form.submited=this.nextSibling.innerHTML;">' : '').(($p['info']) ? '* ' : '').'<font color='.(($p['acude']) ? 'green' : 'red').">{$p['nom']}</font><br>";
	}
	echo $miem;
	// }}}
	
    case 'vmModMes':
    case 'gesMes': // {{{
	$ronly=false;
	if (!$idM) {
	  if ($wrkf=$_POST['wrkf']) {
	    $swrkf=&$_SESSION[$wrkf];
	    $idM=$swrkf['idM'];
	    if ($swrkf['gesmes']) {
	      echo $jefe;
	      $ronly=true;
	    }
	    else {
	      auth($idM);
	      echo $miem;
	    }
	  } else {
	    $idM=intval(@key($dum=&$aacc[$acc])) or $idM=intval($_REQUEST['lames']);
	    if (is_array(current($dum))) {// admin de elecciones
	      echo $jefe;
	      if ($jf < 2 or !mysql_fetch_assoc(mysql_query("select * from eVotMes where idM = $idM and ( adm = 0 or adm = $iAm or $jf > 2 )")))
		die(__('No autorizado.'));
	      $ronly=true;
	    }
	    else {
	      auth($idM);
	      echo $miem;
	    }
            $wrkf=uniqid("wrkf",true); // unico para este workflow 
	    $swrkf=&$_SESSION[$wrkf];
	    $swrkf['idM']=$idM;
	    if ($ronly)
	      $swrkf['gesmes']=true;
	  }
	}
	if ($acc == 'vmModMes') {
	  if ($ronly) {
	    mysql_query("delete eVotPart from eVotPart,eVotElecs where elecPart = idE and mesaElec = $idM");
	    mysql_query("delete eVotBBx from eVotBBx,eVotElecs where eleccion = idE and mesaElec = $idM");
	    mysql_query("optimize table eVotPart,eVotElecs");
	  }
	}
    #Here, form of the poll officer. Adding code to confirm deletion of votes
    $votDelConfirm="if (this.submited != null && this.submited != '' ){ if (this.submited == -1) { var dodeletevote=confirm('\\n-== AVISO ==-\\n\\n'+'¿Está seguro de que desea abrir la urna?\\nEsta acción no se puede deshacer y si lo hace ya no podrá anular papeletas.\\n\\n');} else { var dodeletevote=confirm('\\n-== '+this.submited+' ==-\\n\\n'+'¿Está seguro de que desea borrar la participación de este votante?\\nEsta acción no se puede deshacer.\\n\\n');} if (!dodeletevote){this.submited = ''; return false;}this.submited = '';}";
	echo "<form name=formu method=post ".'onsubmit="'.$votDelConfirm.$scro1.'">'.$scro2."<table style=\"height: 80%;  width: 100%\"><tr><td><input name=wrkf type=hidden value=\"$wrkf\"><table border=0>";
	$mesa=mysql_fetch_assoc(mysql_query("select * from eVotMes where idM = '$idM'")); $est=$mesa['est'];
	echo '<tr><td class=lab width="25%">'.__('Mesa').' <td colspan=6 width="75%">'.$mesa['nomMes'];
	$mesa['now']=$now;
	if ($est > 1 and $mesa['actap'])
	  $ap=" <a target=act href=\"?vCRec=$idM\">".__('Acta').'</a>';
	foreach(array('now'=>__('Hora actual'),'ini'=> __('Inicio'),'fin'=>__('Fin')) as $q=>$tx)
	  echo "<tr><td class=lab>$tx <td colspan=6>".strftime(__("%d/%b/%Y %H:%M"),$mesa[$q]).(($q == 'ini') ? $ap : '');
	if ($mesa['modIU'])
	  echo "<tr><td class=lab>".__('Apertura')." <td colspan=6>{$mesa['prc']}%";
	$actas=array(); $pabr=!$mesa['lcn'];
	$qE=mysql_query("select idE,nomElec,lev,audit,totPob,abie from eVotElecs where mesaElec = $idM order by posE, nomElec"); $tlev=0; $mlev=1000; $disc=false;
	while ($el=mysql_fetch_assoc($qE)) {
	  $idE=$el['idE'];
	  echo "<tr><td class=lab>".__('Elección').'<td colspan=6>'.((($n=$el['nomElec']) != '-') ? $n : __('Descripción no especificada'));
	  if ($est)
	    echo "<tr><td colspan=2 class=lab width=\"35%\"><a target=act href=\"?vRoll=$idE&fr=1\">".__('Censo').
		"</a> <td colspan=5><a target=act href=\"?vBallot=$idE&fr=1\">".__('Papeleta').'</a>';
	  $qV=mysql_query("select * from eVotVots where elecVot = $idE");
	  while ($vo=mysql_fetch_assoc($qV)) {
	    echo "<tr><td colspan=2 class=lab>".__('Votación').'<td colspan=5>'.((($n=$vo['nomVot']) != '-') ? $n : __('Descripción no especificada'));
	  }
	  echo "<tr><td colspan=2 class=lab>".__('Seguridad')." <td colspan=5>{$segs[$el['lev']]}";
	  if ($est == 4) {
	    echo "<tr><td colspan=2 class=lab><a target=act href=\"?vRecord=$idE\">".__('Ver acta').'</a><td colspan=5>'.__('Estos enlaces son públicos, puede').
		"<tr><td colspan=2 class=lab><a target=act href=\"?record=$idE\">".__('Recibir acta').'</a><td colspan=5>'.__('hacerlos llegar a los votantes').
		(($el['audit']) ? "<tr><td colspan=2 class=lab><a target=act href=\"?hash=$idE\">".__('Recibir recibos').'</a>' : '');
	  }
	  if ($est > 1) {
	    if (!$sPop=$el['totPob'])
	      list($sPop)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE"));
	    list($sPart)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE and acude = 1"));
	    list($sBBx)=mysql_fetch_row(mysql_query("select count(eleccion) from eVotBBx where eleccion = $idE"));
	    if (!$ronly)
	      echo "<tr><td colspan=2 class=lab>".__('Posibles votantes')." <td colspan=5><input type=submit name=\"acc[mModMes][$idE]\" value=$sPop>";
	    echo "<tr><td colspan=2 class=lab>".__('Han votado')." <td colspan=5>$sPart".
		"<tr><td colspan=2 class=lab>".__('En la urna')." <td colspan=5>$sBBx";
	    if ($sPart > $sPop or $sBBx > $sPart)
	      echo ' <font color=red>'.__('¡Posible inyección de votos, fraude!').'</font>';
	    else if ($el['abie'] or $sPart != $sPop or $sPop != $sBBx) // abierta y !(han votado todos y estan los votos)
	      $pabr=false;
	  }
	  $tlev=max($tlev,$el['lev']); $mlev=min($mlev,$el['lev']);
	  $disc=($disc or ($sPart > $sBBx));
	}
	if ($est < 1)
	  die('</table><p>'.__('Mesa en edición, datos provisionales, todavía no se puede operar').' <input type=submit name="acc[gesMes]" value="'.__('Refrescar').'">');
	if ($mlev == 1000)
	  die('</table><h3>'.__('Mesa sin elecciones'));
	echo '<tr><td class=lab>'.__('Miembro').'<td align=center colspan=2>'.__('Cargo');
	if ($est > 0) {
	  echo '<td>'.__('Mesa revisada');
	  if ($est > 1) {
	    echo '<td>'.__('Acta firmada');
	    if ($est > 2) {
	      echo '<td>'.__('Conforme');
	      if ($est > 3)
		echo '<td>'.__('Actas firmadas');
	    }
	  }
	  if ($est < 4)
	    echo '<td>'.__('Comentario o incidencia');
	}
       	$preyo=$unfdo=$unfdof=$ause=$unco=false;
	$q1=mysql_query("select * from eVotMiem,eVotPob where mesMiemb = '$idM' and miembMes = idP and idP = $iAm");
	$q2=mysql_query("select * from eVotMiem,eVotPob where mesMiemb = '$idM' and miembMes = idP and idP != $iAm order by carg, nom");
	while ($mi=mysql_fetch_assoc($q1) or $mi=mysql_fetch_assoc($q2)) {
	  $pres=$mi['pres']; $presf=$mi['presf']; $fmdo=$mi['fmdo']; $fmdof=$mi['fmdof']; $cg=$mi['carg']; $miyo=(($idP=$mi['miembMes']) == $iAm);
	  if ($co=$mi['correo'] and !$miyo) $unco=true;
	  echo "<tr><td class=lab".(($im=$mi['imgM']) ? " onmouseover=\"document.getElementById('act').src='?getim='+$im\">" : '>').
		(($co=(!$miyo and $mi['correo'] and $est<4)) ? "<a href=\"?comu=$idM&mi={$mi['idP']}\" target=act>" : '').$mi['nom'].(($co) ? '</a>' : '').
		"<td align=center colspan=2>{$vcgs[$cg]} <td> ";
	  if ($miyo) {
	    if ($cg[0] == 'p') {
	      $preyo=true;
	      // uso cierre como un bloqueo de presidente
	      mysql_query("update eVotMes set cierre=".($now+600)." where idM = $idM and est < 4");
	    }
	    $levyo=$mi['pes'];
	    $cgyo=$cg;
	    $fmdoyo=$fmdo;
	    $fmdofyo=$fmdof;
	    $presfyo=$presf;
	    $inci=$mi['inci'];
	    if ($est == 0)
	      continue;
	    if ($est == 1)
	      if ($cg[0] == 'j')
		echo __('Excluido de la mesa');
	      else
	        echo '<input type=checkbox name="pres"'.(($pres) ? ' checked>' : '> <font color=red>'.__('¡Ojo!').'</font>');
	    else {
	      if ($pres) {
		echo __('Sí').'<td>'.(($fmdo) ? __('Sí') : __('No'));
		if ($est == 3)
		  echo '<td><input type=checkbox name="pres"'.(($presf) ? ' checked>' : '> <font color=red>'.__('¡Ojo!').'</font>').
			(($cg == 'jp') ? ' '.__('Excluido de la mesa') : '');
		else if ($est > 3) {
		  if ($presf)
		    echo '<td>'.__('Sí').'<td>'.(($fmdof) ? __('Sí') : __('No'));
		  else
		    echo '<td>'.__('Incidentado');
		}
	      }
	      else
		echo __('Excluido de la mesa');
	    }
	  }
	  else {
	    if ($pres) {
	      echo __('Sí');
	      if ($est > 1) {
		echo '<td>'.(($fmdo) ? __('Sí') : __('No')).'<td>';
		if ($est > 2) {
		  if ($cg[0] == 'j')
		    echo __('Excluido de la mesa');
		  else {
		    echo (($presf) ? __('Sí') : __('No'));
		    if ($est == 3 and $preyo and !$presf) {
		      $ause=true;
		      echo ', '.__('motivo').": <textarea cols=60 name=\"moti[$idP]\"".filcol($swrkf['moti'][$idP],"\n",3);
		    }
		    if ($est > 3)
		      echo '<td>'.(($fmdof) ? __('Sí') : __('No'));
		  }
		}
	      }
	    }
	    else
	      if ($est < 2) {
		if ($cg[0] != '2' or ($cgyo == 'pa' and $cg == 'ps')) {
		  echo '<b><big>'.__('No').'</big></b>';
		  if ($preyo) {
		    $ause=true;
		    echo ', '.__('motivo').": <textarea cols=60 name=\"moti[$idP]\"".filcol($swrkf['moti'][$idP],"\n",3);
		  }
		}
	      }
	      else
		echo __('Excluido de la mesa');
	  }
	  if ($in=$mi['inci'] and !$miyo)
	    echo '<td>'.enti($in);
	  if ($fmdo) $unfdo=true;
	  if ($fmdof) $unfdof=true;
	}
	echo '</table><td style="width: 50%; height: 100%; "><iframe id=act name=act style="height: 100%; width: 100%; border: 0px; " frameborder="0"></iframe></table><p>',
		(($unco and $est <4) ? __('Pulse en el nombre de un miembro para contactar con él').'<p>' : '');
	if ($ronly) {
	  if ($est > 3) {
	    list($vts)=mysql_fetch_row(mysql_query("select count(eleccion) from eVotBBx,eVotElecs where eleccion = idE and mesaElec = '$idM'"));
	    if ($vts)
	      echo '<input type="submit" name="acc[vmModMes]" value="'.__('Vaciar censos y urna').'"> ';
	  }
	  else if ($mesa['fin']+24*3600 < $now and $est > 1 and !$preyo) {
	    echo '<input type="submit" name="acc[aGmModMes]" value="'.__('Asumir').'"> '.__('el cargo de presidente/a').'<p>';
	    $swrkf['asumible']=true;
	  }
	  else
	    $swrkf=array(); // anula el workflow
	  die('<input type=submit class=btrecAct name="acc[recActJ]['.$idM.']" value="'.__('Recibir las actas por correo').
		'"> <input type=submit class=btedMesJ name="acc[edMesJ]['.$idM.']" value="'.__('Volver').'">');
	}
	if ($aupar['authLv'] < $levyo) {
	  $swrkf=array();
	  die(__('Necesita un mayor nivel de autenticación, pruebe clicando en su nombre'));
	}
	if ($est == 1) {
	  echo '<input type="submit" id=btmModMes name="acc[mModMes]" value="'.__('Actualizar').'"><p>';
	  if ($preyo)
	    if ($mesa['fin'] < $now)
	      echo __('La mesa ya no puede activarse, ha caducado');
	    else if ($mesa['ini']-1800 < $now) {
	      if ($ause)
		echo '<p><font color=red>'.__('Puede que algunos miembros no hayan tenido tiempo de revisar la mesa. Active la mesa sin contar con ellos sólo si está seguro').'</font></p>';
	      echo __('Explique aquí las incidencias u observaciones que quiera hacer constar en el acta').
			':<br><textarea name=inci id=txtinci'.filcol($swrkf['inci'],"\n",4). // 5 lineas de codigo de depuracion eliminadas por mkInstaller
			'<br><input name="acc[actYaMes]" type=submit id=btactYaMes value="'.__('Activar la mesa').'">';
	    }
	    else
	      echo __('Todavía no puede activar la mesa, prodrá hacerlo cuando falte menos de media hora para el inicio de la votación');
	  else {
	    if (($cgyo == '2p' or ($mesa['ini'] < $now-3600 and ($cgyo == 'v' or $cgyo == '2v' or $cgyo == 's' or $cgyo == '2s'))) and mysql_num_rows(mysql_query("select idM from eVotMes where idM = $idM and cierre < $now"))) {
	      $swrkf['asumible']=true;
	      echo __('Por posible ausencia').' <input type="submit" name="acc[amModMes]" value="'.__('Asumir').'"> '.
			__('el cargo de presidente/a').'<p>';
	    }
	    else $swrkf['asumible']=false;
	    echo __('Explique aquí las incidencias, diligencias u observaciones que quiera hacer llegar al presidente/a').
			':<br><textarea name=inci id=txtinci'.filcol($swrkf['inci'],"\n",4);
	  }
	}
	else if ($est == 2) {
	  $cie=$mesa['fin'];
	  $tlev=max(3*$mesa['lcn'],$tlev); // supone que la extension ha metido nivel 3;
	  if ($tlev)
	    $cie+=intval(2*(600+max(1,$tlev)*120));
	  if ($cie >= $now and !$pabr) {
	    if ($preyo)
	      echo strftime(__('Todavía no se puede abrir la urna (%H: %M)'),$cie).' <input id=btgesMes name="acc[gesMes]" value="'.__('Reintentar').'" type="submit">';
	    else
	      echo strftime(__('La urna no se abre hasta las %H:%M'),$cie).' <input id=btgesMes type="submit" name="acc[gesMes]" value="'.__('Refrescar').'">';
	  }
	  else
	    if ($preyo) {
	      $acci=(($mesa['modIU']) ? 'abrUrn' : 'abrUrnI');
	      if (!$disc or $now > $cie+3600)
		$monid=uniqid('');
	      if ($disc)
		echo '<font color=red>'.__('Atención: el número de votos emitidos no coincide con el de presentes en la urna').
			(($monid) ? '' : __(' (puede ser normal, esperamos una hora)')).
			'</font> <input type=submit id=btmModMes name="acc[gesMes]" value="'.__('Refrescar').'">';
	      if ($monid) {
              if (mysql_fetch_row(mysql_query("select idM from eVotMes, eVotElecs where mesaElec = idM and anulable = 1 and idM = $idM"))){
                  echo '<font color=red>',__('Atención al haber una elección de papeleta anulable, la urna no debe abrirse hasta que se haya cerrado el perido de anulaciones'),'</font>';
                  $btabrUrnConfirm="this.form.submited=-1;"
              }
		echo '<p><input id=btabrUrn name="acc['.$acci.']" type=submit value="'.__('Abrir la urna').
			'" onclick="'.$btabrUrnConfirm.'moni(this)"><input type=hidden name=monid value="'.$monid.'">';
		moniac($monid);
	      }
	    }
	    else {
	      if ($cie < $now-3600 and ($cgyo == 'v' or $cgyo == '2v' or $cgyo == 's' or $cgyo == '2s')
			and mysql_num_rows(mysql_query("select idM from eVotMes where idM = $idM and cierre < $now"))) {
		$swrkf['asumible']=true;
	        echo __('Por posible ausencia').' <input type="submit" name="acc[aAbrUrnI]" value="'.__('Asumir las funciones de presidente/a y abrir la urna').'"><p>';
	      }
	      else {
		$swrkf['asumible']=false;
		echo '<input id=btgesMes type="submit" name="acc[gesMes]" value="'.__('Refrescar').'">';
	      }
	    }
	}
	else if ($est == 3) {
	  echo '<input type=submit id=btmModMes name="acc[mModMes]" value="'.__('Actualizar').'"><p>';
	  if ($preyo) {
	    if (!$mesa['modIU'])
	      echo '<p>'.__('Explique aquí las incidencias, diligencias u observaciones que quiera hacer constar en el acta').
		':<br><textarea name=inci id=txtinci'.filcol($swrkf['inci'],"\n",4);
	    echo '<p><input name="acc[cerMes]" type=submit id=btcerMes value="'.__('Cerrar la mesa').'">';
	  }
	  else
	    echo __('Explique aquí las incidencias, diligencias u observaciones que quiera hacer llegar al presidente/a').
			':<br><textarea name=inci id=txtinci'.filcol($swrkf['inci'],"\n",4);
	  echo '<p>';
	  $qE=mysql_query("select record from eVotElecs where mesaElec = $idM order by posE, nomElec");
	  while (list($acta)=mysql_fetch_row($qE))
	    echo "$acta<hr>";
	}
	else if ($est == 4 and $presfyo)
	  echo sprintf(__('Mesa ya cerrada, volver al %senvío de actas%s'),'<input id=btenvAct name="acc[envAct]" type=submit value="','">');
	$swrkf['unfdo']=$unfdo; $swrkf['unfdof']=$unfdof;
	$frdoyo=(($est == 2 or $est > 3) and !$fmdoyo);
	$frdofyo=($est > 3 and $presfyo and !$fmdofyo);
	if ($frdoyo or $frdofyo)
	  echo '<div id=aviso style="visibility: hidden; height: 0px; color: red;">'.
		sprintf(__('Para poder firmar actas, se necesita %sJava%s o Internet Explorer con %sCAPICOM%s o Firefox.'),
			'<a target=_blank href=http://www.java.com/es/download/>','</a>',
			'<a target=_blank href=http://dwnl.nisu.org/dwnl/setup-clauer.exe>','</a>').'</div>'.
			'<script type="text/javascript" src="aps/deployJava.js"></script>',
			'<script> okPF={"":false,"j":false}; if (deployJava.getJREs().length > 0) okPF["j"]=true; if (window.crypto) okPF[""]=true; else try { new ActiveXObject("CAPICOM.Settings"); okPF[""]=true; } catch (e) {} ;'.
		'if (!okPF["j"] && !okPF[""]) { var p=document.getElementById("aviso").style; p.visibility="visible"; p.height="auto"; }</script>';
   	if ($frdoyo)
	  printf(__('%sFirmar con CryptoApplet%s o %sfirmar con el navegador%s el acta de constitución de la mesa'),
			'<p><input id=btpreFirmConj name="acc[preFirmConj]" disabled type=submit value="','">','<input id=btpreFirmCon name="acc[preFirmCon]" disabled type=submit value="','">');
	else if ($frdofyo) {
	  list($tam)=mysql_fetch_row(mysql_query("select sum(length(record)+length(voters)+length(tokens)) from eVotElecs where mesaElec = $idM"));
	  if ($tam > 500000)
	    echo '<script language="javascript">okPF[""]=false;</script>';
	  printf(__('%sFirmar con CryptoApplet%s o %sfirmar con el navegador%s las actas de cada elección'),
			'<p><input id=btpreFirmCiej name="acc[preFirmCiej]" disabled type=submit value="','">','<input id=btpreFirmCie name="acc[preFirmCie]" disabled type=submit value="','">');
	}
	if ($frdoyo or $frdofyo)
	  echo '<br>'.__('Texto opcional a incluir en la firma').'<br><textarea class=txtFirm name=txt'.filcol($swrkf['txt'],"\n",4).
		'<script language="javascript">for (i in okPF) if (okPF[i]) document.formu["acc['.(($frdoyo) ? 'preFirmCon' : 'preFirmCie').'"+i+"]"].disabled=false;</script>';
	echo "$lista</form></div>";
	break; // }}}

    case 'preFirmConj':  // {{{
	$java=true;
    case 'preFirmCon':
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM);
	list($actap)=mysql_fetch_row(mysql_query("select actap from eVotMes where idM = $idM"));
	$swrkf['md5']['actap']=md5($actap);
	$actap="Subject:\n$actap";
	$bou=md5(uniqid('',true)); $now+=10;
	$afirmar=strftime(__('Firmada aproximadamente el %d de %B de %Y a las %H:%M'),$now).'<br>';
	if ($txt=str_replace("\r\n",'<br>',$swrkf['txt']=enti($_REQUEST['txt'])))
	  $afirmar.="$txt<br>";
	$afirmar.=($swrkf['unfdo']) ? __('Se adjunta cadena de firmas') : __('Se adjunta el acta original');
	echo "$miem$afirmar<form name=formu onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	$afirmar="Content-type: multipart/mixed; boundary=$bou\n\n--$bou\nContent-type: text/html; charset=\"UTF-8\"\nContent-transfer-encoding: base64\nX-SigT: $now\n\n".
		chunk_split(base64_encode($afirmar),76,"\n").
		"\n--$bou\nContent-type: message/rfc822; name=\"C-$idE.eml\"\nContent-transfer-encoding: 7bit\nContent-disposition: attachment; filename=\"C-$idE.eml\"\n\n$actap\n--$bou--\n";
	$afirmar=str_replace("\n","\r\n",$swrkf['afirmarc']=$afirmar);
	if ($java) {
	  ponJsJFir('firmCon','firmac');
	  echo '<script language="javascript">function hfirmaC(o) { if (firmado) return true; else { cubre(); elfirmar("'.sha1($afirmar).'"); return false; } } resuls[0]="1"</script>';
	}
	else {
	  ponJsFir();
	  echo '<script language="javascript">function hfirmaC(o) { cubre(); try { f=elfirmar(unescape("'.rawurlencode($afirmar).'")); } catch(e) { descubre(); return false; } if (f.length <200) { alert(f); descubre(); return false; } document.formu["firmac[1]"].value=f; return true; } </script>';
	}
	echo '<p><input id=btfirmCon name="acc[firmCon]" type=submit onclick="return hfirmaC(this);" value="'.__('Firmar').
		(($java) ? '" disabled' : '"').'> <input type=hidden name=firmac[1]><input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Volver').'"></form></div>';
	break; // }}}

    case 'firmCon':  // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM);
	echo "$miem<form name=formu onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	preg_match('/X-SigT: ([0-9]*)\n/',$swrkf['afirmarc'],$mtc);
	if (abs($mtc[1]-$now)>300)
	  die(__('Ha tardado demasiado en firmar').', <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Reintentar').'"></form></div>');
	list($est,$cons)=mysql_fetch_row(mysql_query("select est,cons from eVotMes where idM = '$idM'"));
	$swrkf['firmante']='';
	$swrkf['actap']=haz_subj(__('Acta de constitución de mesa electoral celebrada %s'),$cons)."\n".vfFirma($swrkf['afirmarc'],$_REQUEST['firmac'][1]);
	$swrkf['afirmarc']='';
	if ($swrkf['firmante'])
	  echo ' <input type=submit id=btfirmConOK name="acc[firmConOK]" value="'.__('Correcto').'"> ';
	echo '<p><input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Volver').'"></form></div>';
	break; // }}}

    case 'firmConOK': // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM);
	if (!$fm=$swrkf['firmante'])
	  die('?');
	list($est,$acta)=mysql_fetch_row(mysql_query("select est,actap from eVotMes where idM = '$idM'"));
	echo "$miem<form name=formu onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	// el md5 sirve para saber que no se ha modif el acta porque firma otro
	mysql_query("update eVotMes,eVotMiem set actap='".mysql_real_escape_string($swrkf['actap']).
		"',fmdo=1 where mesMiemb = $idM and miembMes = $iAm and fmdo=0 and idM = $idM and md5(actap) = '{$swrkf['md5']['actap']}'");
	if (mysql_affected_rows() != 2)
	  die(__('Otra persona esta firmado').', <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Reintentar').'"></form></div>');
	if ($m=dirmail('',$iAm))
	  enviAct($m,$swrkf['actap']);
	if (preg_match('/<(.*?)>/',$fm,$ma) and preg_match('/<(.*?)>/',$m,$ma2) and strtolower($ma[1]) != strtolower($m2[1]))
	  enviAct($fm,$swrkf['actap']);
	$swrkf=array('idM'=>$idM);
	echo __('Firma almacenada').', <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Volver').'"></form></div>';
	break; // }}}

    case 'preFirmCiej':  // {{{
	$java=true;
    case 'preFirmCie': 
	$wrkf=$_REQUEST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM);
	echo "$miem<form name=formu action=$escr onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	$qE=mysql_query("select idE,record,voters,tokens from eVotElecs where mesaElec = $idM");
	$bou=md5(uniqid('',true)); $now+=10;
	$js='<script language="javascript">with (document.getElementById("espero").style) { visibility="hidden"; height="0px"; } function hfirma(o) { '; $js2='';
	if ($java) {
	  ponJsJFir('firmCie','firma');
	  $js.='if (firmado) return true; cubre(); elfirmar("';
	}
	else {
	  ponJsFir();
	  $js.='cubre(); ';
	}
	$cua=3*mysql_num_rows($qE); $espe=true;
	while ($actas=mysql_fetch_assoc($qE)) {
	  $idE=$actas['idE'];
	  unset($actas['idE']);
	  foreach($actas as $q => $act) {
	    $swrkf['md5'][$idE][$q]=md5($act);
	    $act="Subject:\n$act";
	    $afirmar=strftime(__('Firmada aproximadamente el %d de %B de %Y a las %H:%M'),$now).'<br>';
	    if ($q == 'record' and $txt=str_replace("\r\n",'<br>',$swrkf['txt']=enti($_REQUEST['txt'])))
	      $afirmar.="$txt<br>";
	    $afirmar.=($swrkf['unfdof']) ? __('Se adjunta cadena de firmas') : __('Se adjunta el acta original');
	    if ($espe) {
	      echo "$afirmar<div id=espero><font color=red>",__('Espere mientras se cargan las actas'),'</font></div>';
	      $espe=false;
	    }
	    $afirmar="Content-type: multipart/mixed; boundary=$bou\n\n--$bou\nContent-type: text/html; charset=\"UTF-8\"\nContent-transfer-encoding: base64\nX-SigT: $now\n\n".
		chunk_split(base64_encode($afirmar),76,"\n").
		"\n--$bou\nContent-type: message/rfc822; name=\"$q-$idE.eml\"\nContent-transfer-encoding: 7bit\nContent-disposition: attachment; filename=\"$q-$idE.eml\"\n\n$act\n--$bou--\n";
	    $afirmar=str_replace("\n","\r\n",$swrkf['afirmar'][$idE][$q]=$afirmar);
	    if ($java) {
	      $js.=sha1($afirmar)."|";
	      $js2.="resuls.push('$idE][$q'); ";
	    }
	    else {
	      $afirmar=rawurlencode($afirmar);
	      $js.="try { f=elfirmar(unescape('$afirmar')); } catch(e) { descubre(); return false; }".
		"if (f.length < 200) { alert(f); descubre(); return false; } document.formu['firma[$idE][$q]'].value=f; f=''; document.getElementById('firCua').innerHTML--; ";
	      $js2.="";
	    }
	    echo "<input type=hidden name=\"firma[$idE][$q]\">";
	  }
	}
	if ($java)
	  $js=substr($js,0,-1).'"); return false; } ';
	else
	  $js.=' return true; }';
	echo '<p><input id=btfirmCie name="acc[firmCie]" type=submit onclick="if (hfirma(this)) return true; else { document.getElementById(\'cua\').innerHTML='.
		$cua.'; return false; }" value="'.__('Firmar').(($java) ? '" disabled>' : '">').
		' <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Volver').'"></form><p id=firCua>'.
		sprintf(__('Actas por firmar: %s'),"<span id=cuaFirm>$cua</span>")."$js$js2</script></div>";
	break; // }}}

    case 'firmCie':  // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM);
	echo "$miem<form name=formu action=$escr onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	list($fin)=mysql_fetch_row(mysql_query("select fin from eVotMes where idM = $idM"));
	$swrkf['firmante']='';
	foreach($swrkf['afirmar'] as $idE => $unas) {
	  $subj=haz_subj(sprintf(__('Acta de la elección %sconcluida %%s'),($nomE and $nomE != '-') ? "'".str_replace('<br/>',' ',$nomE)."' " : ''),$fin);
	  foreach($unas as $q => $act) {
	    preg_match('/X-SigT: ([0-9]*)\n/',$act,$mtc);
	    if (abs($mtc[1]-$now)>300)
	      die('<span id=firmRes>'.__('Ha tardado demasiado en firmar').'</span>, <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Reintentar').'"></form></div>');
	    $swrkf['actas'][$idE][$q]="$subj\n".vfFirma($swrkf['afirmar'][$idE][$q],$_REQUEST['firma'][$idE][$q]);
	    $swrkf['afirmar'][$idE][$q]='';
	    if (!$swrkf['firmante'])
	      break 2;
	  }
	}
	if ($swrkf['firmante'])
	  echo ' <input type=submit id=btfirmCieOK name="acc[firmCieOK]" value="'.__('Correcto').'"><p>';
	echo '<p><input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Volver').'"></form></div>';
	break; // }}}

    case 'firmCieOK': // {{{
	$wrkf=$_POST['wrkf'];
	$swrkf=&$_SESSION[$wrkf];
	$idM=$swrkf['idM'];
	auth($idM);
	if (!$fm=$swrkf['firmante'])
	  die('?');
	list($est)=mysql_fetch_row(mysql_query("select est from eVotMes where idM = '$idM'"));
	echo "$miem<form name=formu onsubmit=\"cubre()\" method=post><input type=hidden name=wrkf value=\"$wrkf\">";
	if (!mysql_num_rows(mysql_query("select * from eVotMiem where mesMiemb = $idM and miembMes = $iAm and fmdof=0")))
	  die('<span id=firmRes>'.__('Error en secuencia').'</span>, <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Reintentar').'"></form></div>');
	mysql_query("LOCK TABLES");
	foreach($swrkf['actas'] as $idE => $unas) {
	  foreach($unas as $q => $act) {
	    mysql_query("update eVotElecs set $q='".mysql_real_escape_string($act).
			"' where mesaElec = $idM and md5($q) = '{$swrkf['md5'][$idE][$q]}'"); echo mysql_error();
	    if (mysql_affected_rows() != 1)
	      die('<span id=firmRes>'.__('Otra persona esta firmado').'</span>, <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Reintentar').'"></form></div>');
	    if ($m=dirmail('',$iAm))
	      enviAct($m,$act);
	    if (preg_match('/<(.*?)>/',$fm,$ma) and preg_match('/<(.*?)>/',$m,$ma2) and strtolower($ma[1]) != strtolower($m2[1]))
	      enviAct($fm,$act);
	  }
	}
	mysql_query("update eVotMiem set fmdof=1 where mesMiemb = $idM and miembMes = $iAm and fmdof=0");
	$swrkf=array('idM'=>$idM);
	echo '<span id=firmRes>'.__('Firma almacenada').'</span>, <input type=submit id=btgesMes name="acc[gesMes]" value="'.__('Volver').'"></form></div>';
	break; // }}}

    case 'edPob': // {{{
	if ($jf<3)
	  die('auth');
	if ($mante <1)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),1));
	if (($let=@key(current($aacc))) == 'dwCen') {
	  $let='';
	  echo "<iframe height=0 width=0 border=0 frameborder=0 src=\"?dwCen=1\"></iframe>";
	}
	echo $jefm;
	$cga=($_REQUEST['cga']) ? 'enctype="multipart/form-data"' :'';
	if ($let == 'elNCen') {
	  $let=''; // esta query seria mas facil con claves ajenas
	  mysql_query("delete eVotPob from eVotPob left join eVotPart on partElec = idP left join eVotSup on supOpc = idP left join eVotCan on canOpc = idP left join eVotMiem on miembMes = idP where partElec is NULL and supOpc is NULL and canOpc is NULL and miembMes is NULL and rol = 0");
	  printf(__('%s personas eliminadas').'<p>',mysql_affected_rows());
	  mysql_query("optimize table eVotPob");
	}
	if (!$ky=$_POST['APC_UPLOAD_PROGRESS'])
	  $_SESSION['pobl']=array();
	$monid=uniqid('');
	echo "<form name=formu method=post $cga $scro".'<input type="hidden" name="APC_UPLOAD_PROGRESS" value="'.$monid.'">';
	if ($cgv=current($_FILES)) {
	  $error=''; $c=0;
	  ini_set('max_execution_time',10000);
	  $fp=fopen($tmpn=$cgv['tmp_name'],'r');
	  apc_store("t$ky",$t=filesize($tmpn),100000);
	  while ($uno=fgets($fp)) {
	    if (function_exists('apc_store')) {
	      $c+=strlen($uno)+1;
	      apc_store("c$ky",$c,10000);
	    }
	    if ($uno and !list($idP)=parsea($uno))
	      $error.=$uno;
	  }
	  if ($error)
	    alerta(__('Se produjo un error al cargar algunos votantes'));
	}
	if ($msv=$_REQUEST['msv']) {
	  $error='';
	  foreach(explode("\r\n",$msv) as $uno)
	    if ($uno and !list($idP)=parsea($uno))
	      $error.="$uno\n";
	  if ($error)
	    alerta(__('Se produjo un error al cargar algunos votantes'));
	}
	if ($let) {
	  if ($vals=$_REQUEST['vals']) {
	    $err='';
	    foreach($vals as $idx => $fil) {
	      $idx=intval($idx); $up="";
	      foreach (array('us','DNI','nom','correo','rol','clId') as $col) {
		if ($val=limp($fil[$col])) {
		  if ($col == 'nom' and intocable($idx)) {
		    $err.=limp($fil[$col])."\n";
		    continue;
		  }
		  $up.=", `$col` = '$val'";
		}
	      }
	      if ($up) {
		if (!($oIP=$fil['oIP']) or $oIP == -1)
		  $up.=", `oIP` = ".intval($oIP);
		else if (!preg_match('/^-?[0-9]*$/',$oIP))
		  $up.=", `oIP` = ".intval(ip2long($oIP));
		if ($pwd=$fil['pwd']) {
		  if (!preg_match('/^!?[0-9a-fA-F]{42}$/',$pwd)) {
		    $pwd='!'.genPwd($pwd);
		    $up.=", cadPw = ".($now+48*3600);
		  }
		  $up.=", pwd = '$pwd'";
		}
		mysql_query("update eVotPob set".substr($up,1)." where idP = '$idx'");
	      }
	      else {
		if (!intocable($idx))
		  mysql_query("delete from eVotPob where idP = '$idx'");
	      }
	    }
	    if ($err)
	      alerta(__('No se pudo cambiar el nombre de las siguientes personas')."\n$err");
	  }
	}
        echo __('Inicial del apellido').': ';
	echo '<table style="text-align:right">'; $nf=1;
	foreach(array(array(Q,W,E,R,T,Y,U,I,O,P),
		array(A,S,D,F,G,H,J,K,L,Ñ),
		array(Z,X,C,V,B,N,M,'-')) as $f) {
	  echo '<tr>'; $nc=1;
	  foreach($f as $l) {
	    if ($l=='-')
	      echo "<td colspan=6>";
	    else if ($nc++==1)
	      echo "<td colspan=$nf>";
	    else
	      echo "<td colspan=3>";
	    if ($l=='-') {
	      list($n)=mysql_fetch_row(mysql_query("select count(idP) from eVotPob"));
	      echo "<input onclick=\"moni(this)\" type=submit class=btedPob name=\"acc[edPob][$l]\" value=\"".__('Todos')." $n\">";
	     }
	    else {
	      list($n)=mysql_fetch_row(mysql_query("select count(idP) from eVotPob where nom like '$l%'"));
	      echo "<input onclick=\"moni(this)\" type=submit class=btedPob name=\"acc[edPob][$l]\" value=\"$l $n\">";
	    }
	    if ($l == $let)
	      $tlet=$n;
	  }
	  $nf++;
	}
	echo '</table>';
	if ($let and $tlet) {
	  if ($let == '-')
	    $blet='';
	  else
	    $blet="where nom like '$let%'";
	  $cmps=array('idP'=>0,'us'=>10,'DNI'=>12,'nom'=>40,'correo'=>20,'rol'=>1,'pwd'=>13,'oIP'=>14,'clId'=>13);
	  $np=100;
	  if ($tlet/$np < 100)
	    $np=intval(($tlet-1)/100)+1;
	  $cua=intval(ceil($tlet/$np));
	  if ($np > 1) {
	    $pqs=array('nom'=>__('Nombre'),'us'=>__('Usuario'),'DNI'=>__('DNI'));
	    $pri=$_REQUEST['pri'][$let]; // [] para no mezclar letras
	    if ($pqs[$pri]) {
	      $pq=$pri;
	      $pri=0;
	    }
	    else {
	      $pri=intval($pri);
	      if (!$pqs[$pq=$_REQUEST['pq']]) $pq='nom';
	    }
	    $sel=''; foreach($pqs as $q=>$v) $sel.="<option value=$q".(($pq == $q) ? ' selected' : '').">$v";
	    apc_store("l$ky",$tlet,100000);
	    printf('<p>'.__('%sActualizar y saltar%s cerca de'),"<input type=submit onclick=\"moni(this)\" class=btedPob name=\"acc[edPob][$let]\" value=\"",'">');
	    echo "<input type=hidden name=pq value=$pq> <select name=\"pri[$let]\">";
	    foreach($pqs as $q=>$v)
	      echo "<option value=$q>".__('Clasificar por ').$v;
	    for ($i=0,$ipg=0; $i<$tlet; $i+=$cua,$ipg++) {
	      echo '<option'.(($i == $pri) ? ' selected' : '')." value=$i>";
	      if (!$nom=$_SESSION['pobl'][$let][$pq][$ipg]) {
		apc_store("c$ky",$i,100000);
	        list($nom)=mysql_fetch_row(mysql_query("select $pq from eVotPob $blet order by $pq limit $i,1"));
		$_SESSION['pobl'][$let][$pq][$ipg]=$nom;
	      }
	      echo $nom;
	    }
	    echo '</select>';
	  }
	  else { $pq='nom'; $pri=0; }
	  apc_store("c$ky",$tlet,100000);
	  $qu=mysql_query("select * from eVotPob $blet order by $pq limit $pri,$cua");
	  echo '<p><table id=tbpob><tr><th>Id<th>'.__('Usuario').'<th>'.__('DNI').'<th>'.__('Apellidos, Nombre').'<th>'.
		__('Correo').'<th>'.__('Rol').'<th>'.__('Contraseña').'<th>'.__('IP').'<th>'.__('clId');
	  while ($fi=mysql_fetch_assoc($qu)) {
	    $idx=$fi['idP']; echo '<tr>';
	    foreach ($cmps as $col => $sz) {
	      if ($sz) {
		if ($sz == 13)
		  $fi[$col]='';
		else
		  $disa=($col == 'nom' and intocable($idx)) ? 'disabled' : '';
	        echo " <td><input size=$sz $disa class=inppob name=\"vals[$idx][$col]\" value=\"".enti($fi[$col])."\">\n";
	      }
	      else
		echo ' <td>'.$fi[$col];
	    }
	  }
	  echo '</table></form><form onsubmit="cubre()" method=post><p>',
		sprintf(__('Deje todos los campos en blanco para eliminar, clique cualquier inicial para actualizar, u opte por %sdescartar%s'),
			'<input type="hidden" name="APC_UPLOAD_PROGRESS" value="'.$monid.'"><input type=submit id=btedPob name="acc[edPob]" value="','">'),
		'<p>'.__('Para cambiar la contraseña local, escríbala tal cual en el campo correspondiente; para que la IP o el clId se establezcan en la primera autenticación, escriba el valor -1');
	}
	else {
	  echo '<p>'.__('Añadir personas, una por línea, formato: usuario!DNI!Apellidos, Nombre').'<br>'.__('Opcionalmente puede añadir al final !correo').
		'<br><textarea class=txtnomV name=msv'.filcol($error,"\n",4).'<p><input type=submit onclick="moni(this)" id=btedPob name="acc[edPob]" value="'.__('Añadir').'"> '.
		'<input type=checkbox id=cgach name=cga><label for=cgach> '.__('Cargar de un archivo').'</label>'.
		(($cga) ? ' <input id=fiVot type=file name="fich">' : '').'<p>'.
		sprintf(__('%sDescargar%s el censo'),'<input type=submit id=btdwCen name="acc[edPob][dwCen]" value="','">').'<p>'.
		sprintf(__('%sEliminar%s personas que actualmente no están censadas en ninguna elección'),'<input type=submit id=btelNCen name="acc[edPob][elNCen]" value="',"\"$pacien>");
	}
	echo '</form></div>'; moniac($monid);
	bckup();
        break;
	// }}}

    case 'dwMant': // {{{ // 6 lineas de codigo de depuracion eliminadas por mkInstaller
	if ($jf<3)
	  die('auth');
	if ($mante <1)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),1));
	mysql_query("update eVotDat set mante=mante-1 where mante>0");
        die('<meta http-equiv=refresh content=0>');
	// }}}

    case 'opMesVac': // {{{
	if ($jf<3)
	  die('auth');
	if ($mante <1)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),1));
	$idM=intval(@key(current($aacc)));
	// no intentes una sola query
	mysql_query("delete eVotPart from eVotPart,eVotElecs where elecPart = idE and mesaElec = $idM");
	mysql_query("delete eVotBBx from eVotBBx,eVotElecs where eleccion = idE and mesaElec = $idM");
	mysql_query("optimize table eVotPart,eVotElecs");
	// }}}

    case 'edjMes': // {{{
	echo $jefm;
	if ($jf<3)
	  die('auth');
	if ($mante <1)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),1));
	if (!$idM)
	  mysql_query("optimize table eVotElecs,eVotPart,eVotMes,eVotCan,eVotSup,eVotOpcs,eVotPreLd,eVotVots,eVotMiem,eVotImgs,eVotPob");
	$lim=$now-30*24*3600;
	echo "<form method=post $scro<table id=tbmesas>";
	echo '<table>';
	$q=mysql_query("select * from eVotMes where (fin < $lim or est > 3) order by fin desc");
	while ($mes=mysql_fetch_assoc($q)) {
	  $est=$mes['est']; $idM=$mes['idM'];
	  echo '<tr><td><input type=submit class=btedMesJ name="acc[edMesJ]['.$idM.']" value="'.__('Editar').'"> ';
	  if ($mes['est'] > 2) {
	    $q2=mysql_query("select idE,record from eVotElecs where mesaElec = $idM"); $cv=0; $ok=true;
	    while ($e=mysql_fetch_assoc($q2)) {
	      $idE=$e['idE'];
	      list($cen)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE"));
	      list($vts)=mysql_fetch_row(mysql_query("select count(ticket) from eVotBBx where eleccion = $idE"));
	      $cv+=$cen+$vts;
	      if ($mes['est'] == 4) {
	        if ($e['record'])
		  echo "<a href=?vRecord=$idE target=vRecord><input class=btvRec type=button value=\"".__('Acta').'"></a> ';
		else {
		  echo __('Sin acta').' ';
		  $ok=false;
		}
	      }
	    }
	    if ($cv and $ok)
	      echo '<input type=submit class=btopMesVac'.$pacien.'name="acc[opMesVac]['.$idM.']" value="'.__('Vaciar censos y urna').'"> ';
	  }
	  echo ' <td>'.$estas[$mes['est']].' <td>'.$mes['nomMes'].' <td>'.enti(dirmail('',$mes['adm']));
	}
	echo '</table></form></div>';
	break;
	// }}} // 21 lineas de codigo de depuracion eliminadas por mkInstaller
    case 'infUrl': // {{{
        if ($jf<3)
          die($jefm.'auth');
	echo "$jefm<form method=post $scro";
	if (preg_match('%^https?://%',$iinfUrl=limp($_REQUEST['infUrl']))) {
	  mysql_query("update eVotDat set infUrl='$iinfUrl'");
	  bckup();
	  die('<meta http-equiv=refresh content=0>');
	}
	list($infUrl)=mysql_fetch_row(mysql_query("select infUrl from eVotDat"));
	echo __('URL').': <input id=infUrl name="infUrl" size=80 value="'.enti($infUrl).
		'"><input type=submit name="acc[infUrl]" value="'.__('Actualizar').'"></form><p></div>';
	break;
	// }}}

    case 'domDef': // {{{
        if ($jf<3)
          die($jefm.'auth');
	if ($mante <1)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),1));
	echo "$jefm<form method=post $scro";
	if ($idomdef=limp($_REQUEST['domdef'])) {
	  mysql_query("update eVotDat set domdef = '$idomdef'");
	  bckup();
	  die('<meta http-equiv=refresh content=0>');
	}
	list($domdef)=mysql_fetch_row(mysql_query("select domdef from eVotDat"));
	if (!$domdef) {
	  preg_match('/([^\.]+\.[^\.]+)(:[0-9]+)?$/',$_SERVER['HTTP_HOST'],$ma);
	  $domdef=$ma[1];
	}
	echo _('Domino por defecto para el correo').': <input id=domdef name=domdef size=80 value="'.enti($domdef).
		'"><input type=submit name="acc[domDef]" value="'.__('Actualizar').'"></form><p></div>';
	break;
	// }}}

    case 'pasSMS': // {{{
        if ($jf<3)
          die($jefm.'auth');
	echo "$jefm<form method=post $scro";
	if (isset($_REQUEST['pasSMS'])) {
	  $ipasSMS=mysql_real_escape_string($pasSMS=$_REQUEST['pasSMS']);
	  mysql_query("update eVotDat set pasSMS = '$ipasSMS'");
	  bckup();
	  die('<meta http-equiv=refresh content=0>');
	}
	list($pasSMS)=mysql_fetch_row(mysql_query("select pasSMS from eVotDat"));
	echo _('Pasarela de SMS').': <input id=pasSMS name=pasSMS size=80 value="'.enti($pasSMS).
		'"><input type=submit name="acc[pasSMS]" value="'.__('Actualizar').'"></form><p></div>';
	break;
	// }}}

    case 'eSurvey': // {{{
	    /*   comporbar que no hay votaciones en estado 2 y fin > now */
	echo $jefm;
	if ($jf<3)
	  die('auth');
	$prcon=$_SESSION['prcon'];
	if ($prcon < $now and 
		pillaURL('https://eSurvey.nisu.org/eSurvey.js') != file_get_contents('eSurvey.js'))
	  echo __('El cliente local y el original son diferentes').'<p>';
	list($eCrtS,$tkd)=mysql_fetch_row(mysql_query("select eCrtS,tkD from eVotDat"));
	echo "<form onsubmit=\"cubre()\" method=post>";
	if ($mante >= 2) {
	  $ac=mysql_num_rows(mysql_query("select * from eVotMes where est = 2"));
	  if ($_REQUEST['urna']) {
	    if ($ac)
	      die(__('Hay votaciones activas, este proceso las estropearía'));
	    list($dum,$keyyU,$modU,$expU)=newKCEM('',$klng);
	    foreach(array('keyyU','modU','expU') as $q)
	      mysql_query("update eVotDat set $q='".mysql_real_escape_string($$q)."'");
	    bckup();
	  }
	  if ($_REQUEST['firm']) {
	    if ($ac)
	      die(__('Hay votaciones activas, este proceso las estropearía'));
	    list($certS,$keyyS,$modS,$expS)=newKCEM($tkd,$klng); $eCrtS='';
	    foreach(array('eCrtS','certS','keyyS','modS','expS') as $q)
	      mysql_query("update eVotDat set $q='".mysql_real_escape_string($$q)."'");
	    mysql_query("insert into eVotLog (logmsg,fechi,ref,sIP) values ('Key updated',$now,$iAm,0)");
	    bckup();
	  }
	}
	if ($prcon < $now) {
	  // se hace con frecuencia, para actualizar IPs
	  $z=pillaURL("https://esurvey.nisu.org/sites?status=".urlencode($tkd));
	  $_SESSION['prcon']=$now+60;
	}
	if (!$eCrtS) { // se hace después de ver los REQUEST
	  list($ust,$sst,$eCrtS)=explode("\n",$z);
	  if ($sst == 'ok') {
	    mysql_query("update eVotDat set eCrtS='".mysql_real_escape_string($eCrtS)."'");
	    mysql_query("insert into eVotLog (logmsg,fechi,ref,sIP) values ('Cert updated',$now,$iAm,0)");
	    bckup();
	  }
	  else
	    echo '<font color=red>'.__('El servidor de firma está sin autenticación, el certificado no está listo todavía').'</font><br>';
	}
	$aacc=current($aacc); $ref='';
	if ($que=@key($aacc)) {
	  if ($mante >= 1 and $que == 'clear') {
	    mysql_query("delete from eVotLog");
	    mysql_query("optimize table eVotLog");
	    $que=0;
	  }
	  if ($que == 'clearV') {
	    list($min)=mysql_fetch_row(mysql_query("select min(ini) from eVotMes where est<4"));
	    if ($min)
	      $min=$now;
	    mysql_query("delete from eVotLog where fechi < $min");
	    mysql_query("optimize table eVotLog");
	    $que=0;
	  }
	  $key=intval(@key(current($aacc)));
	  if ($key) {
	    if ($que != 'ref' and $que != 'sIP' and $que != 'idEy')
	      die("$que?");
	    $ref="where $que = $key";
	  }
	}
	if (!$_REQUEST['tds']) {
	  list($culg)=mysql_fetch_row(mysql_query("select count(*) from eVotLog $ref"));
	  if ($culg > 1000) {
	    printf(__('Hay muchos logs %s mostrar todos'),'<input type=checkbox name=tds>');
	    echo " <input type=submit class=bteRefrSvy name=\"acc[eSurvey][$que][$key]\" value=\"".__('Refrescar').'">';
	    $ref.=' limit '.($culg-1000).",$culg";
	  }
	}
	$q=mysql_query("select * from eVotLog $ref");
	if (mysql_num_rows($q)) {
	  if ($mante >= 1)
	    echo '<p><input type=submit class=btLogCl name="acc[eSurvey][clear]" value="'.__('Borrar logs')."\"$pacien><br>";
	  else
	    echo '<p><input type=submit class=btLogCl name="acc[eSurvey][clearV]" value="'.__('Borrar logs antiguos')."\"$pacien><br>";
	}
	else
	  echo __('No hay logs');
	$nsvys=array(0=>'-');
	while ($log=mysql_fetch_assoc($q)) {
	  if (!$nsvys[$idEy=$log['idEy']])
	    list($nsvys[$idEy])=mysql_fetch_row(mysql_query("select nomElec from eVotElecs where idE='$idEy'"));
	  echo '<br><input type=submit class=btLogRef name="acc[eSurvey][ref]['.$log['ref'].']" value="'.$log['ref'].
		 '"><input type=submit class=btLogSIP name="acc[eSurvey][sIP]['.$log['sIP'].']" value="'.long2ip($log['sIP']).
		 '"><input type=submit class=btLogSvy name="acc[eSurvey][idEy]['.$log['idEy'].']" value="'.$nsvys[$idEy].
		 '"> '.strftime("%c",$log['fechi']).' '.enti($log['logmsg']);
	}
	echo '<br>';
	if ($key)
	  echo '<input type=submit class=btTodoSvy name="acc[eSurvey]" value="'.__('Todo').'"> ';
	echo "<input type=submit class=bteRefrSvy name=\"acc[eSurvey][$que][$key]\" value=\"".__('Refrescar').'">';
	if ($nca=mysql_num_rows(mysql_query("select * from eVotCache")))
	  echo sprintf('<p>'.__('Hay %s votos en la cola del proxy'),$nca);
	if ($nca=mysql_num_rows(mysql_query("select * from eVotRecvr where sgnd != ''")))
	  echo sprintf('<p>'.__('Hay %s códigos de recuperación por errores'),$nca);
	if ($mante >= 2)
	  echo '<p><input type=checkbox id=urna name=urna> <label for=urna>'.__('Regenerar la llave de urna').
		 '</label><br><input type=checkbox id=firm name=firm> <label for=firm>'.__('Regenerar la llave de firma y el certificado').
		 '</label><br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.
		 __('El servidor de firma quedará sin autenticación hasta que se firme el certificado, aunque estará operativo').
		 '<br> <input type=submit id=bteSurvey name="acc[eSurvey]" value="'.__('Proceder').
		 '"><p><a href="https://esurvey.nisu.org/sites.php" target=eSurveySites>'.__('Visitar eSurveySites').
		 '</a><!-- iframe id=eSurveySites name=eSurveySites></iframe -->';
	//else
	//  echo __('Mantenimiento realizado');
	break;
	// }}}

    case 'hUpdPrg': // {{{
	$nisuCert='
-----BEGIN CERTIFICATE-----
		MIIFDzCCA/egAwIBAgIJAIWcWIpHeKlBMA0GCSqGSIb3DQEBBQUAMIG1MQswCQYD
		VQQGEwJFUzEdMBsGA1UECBMUQ29tdW5pdGF0IFZhbGVuY2lhbmExETAPBgNVBAcT
		CENhc3RlbGxvMRQwEgYDVQQKEwtOaXN1IGF0IFVKSTEdMBsGA1UECxMUU29mdHdh
		cmUgZGV2ZWxvcG1lbnQxGjAYBgNVBAMTEU5pc3UgY29kZSBzaWduaW5nMSMwIQYJ
		KoZIhvcNAQkBFhRtbS5jb2Rlc2lnbkBuaXN1Lm9yZzAeFw0wNzExMjcxNjQ0Mzha
		Fw0yNzExMjcxNjQ0MzhaMIG1MQswCQYDVQQGEwJFUzEdMBsGA1UECBMUQ29tdW5p
		dGF0IFZhbGVuY2lhbmExETAPBgNVBAcTCENhc3RlbGxvMRQwEgYDVQQKEwtOaXN1
		IGF0IFVKSTEdMBsGA1UECxMUU29mdHdhcmUgZGV2ZWxvcG1lbnQxGjAYBgNVBAMT
		EU5pc3UgY29kZSBzaWduaW5nMSMwIQYJKoZIhvcNAQkBFhRtbS5jb2Rlc2lnbkBu
		aXN1Lm9yZzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALqt9HT16BKx
		MKkhw2ZVS1cRYqZ9tRpCBh/2lSsmzIIqM/GyEpTAn+/UzPpYf/9JagaSwVrxOR6Q
		4WHPgPB+AFo31m5TpiwN1huQiiaOEya5ksCrkzLQ5ETOxtjVKLnCFGIIW76+aOVg
		oR+4IHphhvJAwSEpbrlY7OMUG7Qxk2+XWqSgNF2f9zmkL5wJhqXDjEgxRSDv7xWf
		SUgPTeKGeXQQrH+lMt/1UHO2fqA9QVEEilBYB7E1O7zfH/8XqnvyhcR7wEBoPC2q
		IDFsS3LmYnNqf+tRAY0VnxXbJ49U62PoTm0dy/0x+BmznLpXS1gzoWDwdovlYb4A
		PzZItJSDu9cCAwEAAaOCAR4wggEaMB0GA1UdDgQWBBSM7HEuv9nEqlviaRLn74M1
		/Czc9zCB6gYDVR0jBIHiMIHfgBSM7HEuv9nEqlviaRLn74M1/Czc96GBu6SBuDCB
		tTELMAkGA1UEBhMCRVMxHTAbBgNVBAgTFENvbXVuaXRhdCBWYWxlbmNpYW5hMREw
		DwYDVQQHEwhDYXN0ZWxsbzEUMBIGA1UEChMLTmlzdSBhdCBVSkkxHTAbBgNVBAsT
		FFNvZnR3YXJlIGRldmVsb3BtZW50MRowGAYDVQQDExFOaXN1IGNvZGUgc2lnbmlu
		ZzEjMCEGCSqGSIb3DQEJARYUbW0uY29kZXNpZ25AbmlzdS5vcmeCCQCFnFiKR3ip
		QTAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IBAQCZoT3EqbUbgXdw9R9E
		lIXdjTh/4pSrlhYHOOmjNAhAmnEwZWEXnmiDxf3SXhJIbISfcm0tSWW3w6ybaLpH
		pSbwtCMDW3j+AJ1SjvufMg/DAzHLmpVVMVdUHyUM1pP0su8bPQSg5j+I02p9VyFJ
		DwCkQGPWw2/F+zQ5oM5C1BrSZHaPd+vHXDhcw3giYTVOzMPYitqsAFvvJ+0LMQvF
		XBdKTnO0M7imH1xtjZRPj/rEqm3Gx6KlLkhJWh2bBbr7J6sZM/0CYk34Gm3eYgOE
		G0zDXR4pBPG31iD2OAsU0dvt+pfvGfLbUWhu1qKeSYcsEcW6tEr5YviOQdUyNtXO
		Evtp
-----END CERTIFICATE-----
';
	echo $jefm;
	if ($jf<3)
	  die('auth');
	if ($mante <2)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),2));
	echo "<form onsubmit=\"cubre()\" method=post>";
	$nv=pillaURL('http://vot.nisu.org/v.php?cur='.urlencode($ver));
	$nf=dechex(crc32($secr));
	if ($nv and $nw=pillaURL($nv) and $sg=pillaURL("$nv/sig") and @fwrite(@fopen("$nf.p",'w'),$nw)) {
	  if (!openssl_public_decrypt(base64_decode($sg),$hash,openssl_pkey_get_public($nisuCert)))
	    die(__('Fallo en firma ').openssl_error_string());
	  $hash=unserialize($hash);
	  if (sha1($nw) != $hash['hash'])
	    die(__('Fallo en contenido'));
	  @unlink("$nf.php");
	  rename("$nf.p","$nf.php") or die(__('Error'));
	  die("<a target=_top href=\"$nf.php\">".__('Proceder').'</a>');
	}
	die(__('Error'));
	break;

    case 'updPrg':
	echo $jefm;
	if ($jf<3)
	  die('auth');
	if ($mante <2)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),2));
	echo "<form onsubmit=\"cubre()\" method=post>";
	if (!$ver or !$nv=pillaURL('http://vot.nisu.org/v.php') or $nv == $ver)
	  die(__('Ya actualizado'));
	echo sprintf(__('Versión actual %s, nueva versión %s'),$ver,$nv).' <input type=submit id=bthUpdPrg name="acc[hUpdPrg]" value="'.__('Continuar').'">';
	break;
	// }}}

    case 'css': // {{{
	echo $jefm;
	if ($jf<3)
	  die('auth');
	if ($mante <1)
	  die(sprintf(__('Se requiere mantenimiento nivel %d'),1));
	echo "<form onsubmit=\"cubre()\" method=post>";
	if ($mcss=mysql_real_escape_string($css=strtr($_REQUEST['css'],'<'," "))) {
	  mysql_query("update eVotDat set css = '$mcss'");
	  bckup();
	}
	else 
	  list($css)=mysql_fetch_row(mysql_query("select css from eVotDat"));
	echo "<style>$css</style>"; // produce cambios ya;
	echo __('CSS').'<p><textarea id=txtcss name=css'.filcol($css,"\n").'</textarea><p><input type=submit name="acc[css]" value="'.
	     __('Actualizar').'"><input type=button value="'.__('Probar').
	     '" onclick="document.getElementById(\'tstcss\').innerHTML=\'<style>\'+css.value+\'</style>\';"><div id=tstcss></div>';
	break;
	// }}}

    case 'gesAut': // {{{
	echo $jefm;
	if ($jf<3)
          die('auth');
        if ($mante <1)
          die(sprintf(__('Se requiere mantenimiento nivel %d'),1));
	if ($nomA=$_POST['nomA']) {
	  $okA=false; $udi=0;
	  $dAuth=intval($_POST['dAuth']);
	  foreach($nomA as $i => $no) {
	    $i=intval($i);
	    if ($_POST['disp'][$i] and $no) {
	      if ($dAuth == $i)
		$okA=true;
	      $disp=1;
	      $udi=$i;
	    }
	    else $disp=0;
	    mysql_query("update eVotMetAut set disp=$disp, nomA='".mysql_real_escape_string($no)."', tipEx='".intval($_POST['tipEx'][$i]).
		"', urlA='".mysql_real_escape_string($_POST['urlA'][$i])."' where idH=$i");
	  }
	  if ($nomY=$_POST['nomY'])
	    foreach($nomY as $i => $no) {
	      $i=intval($i);
	      mysql_query("update eVotPais set nomY='".mysql_real_escape_string($no)."' where idY=$i");
	    }
	  if (!$okA)
	    $dAuth=$udi; // fuerza el último
	  foreach(array('provName','provId','provCountry','cPEPS') as $q)
	    $$q=mysql_real_escape_string($_POST[$q]);
	  $uPru=($_POST['uPru']) ? 1 : 0;
	  mysql_query("update eVotDat set dAuth=$dAuth,cPEPS='$cPEPS',provName='$provName',provId='$provId',provCountry='$provCountry',uPru=$uPru");
	  mysql_query("update eVotPais set peps=0");
	  if ($stork=$_POST['stork'])
	    foreach($stork as $idY => $dum) {
	      $idY=intval($idY);
	      mysql_query("update eVotPais set peps=1 where idY=$idY");
	    }
	  $jmpau=($_POST['jmpau']) ? 1 : 0;
	  mysql_query("update eVotDat set jmpau=$jmpau");
	}
	else
	  list($jmpau)=mysql_fetch_row(mysql_query("select jmpau from eVotDat"));
	echo '<form onsubmit="cubre()" method=post><input tabindex=1 type=submit name="acc[gesAut]" value="'.__('Actualizar').'"><p><table><tr><th>'.
		__('Método').'<th>'.__('Nombre para mostrar').'<th>'.__('Imagen').'<th>'.__('Disponible').
		'<th>'.__('Por defecto').'<th>'.__('Tipo').'<th>'.__('URL');
	foreach(array(1=>__('Interna'), 2=>__('IP'), 10=>__('STORK')) as $i => $qu) {
	  $m=mysql_fetch_assoc(mysql_query("select * from eVotMetAut where idH = $i"));
	  echo "<tr><td>$qu <td> <input name=\"nomA[$i]\" size=20 value=\"".enti($m['nomA']).
		"\"> <td> <input tabindex=\"100\" class=\"imimgModAut\" name=\"acc[imgMod][auth][$i]\" src=\"?getim={$m['imgA']}\" type=\"image\" align=\"absmiddle\"><td> <input type=checkbox name=\"disp[$i]\" ".
		(($m['disp']) ? 'checked' : '').'> <td> <input name=dAuth type=radio '.(($dAuth == $i) ? 'checked' : '')." value=$i>";
	}
	for ($i=11; $i<21; $i++) {
	  $m=mysql_fetch_assoc(mysql_query("select * from eVotMetAut where idH = $i"));
	  echo "<tr><td>".__('Externa ').($i-10).
		" <td> <input name=\"nomA[$i]\" size=20 value=\"".enti($m['nomA']).
		"\"> <td> <input tabindex=\"100\" class=\"imimgModAut\" name=\"acc[imgMod][auth][$i]\" src=\"?getim={$m['imgA']}\" type=\"image\" align=\"absmiddle\"> <td> <input type=checkbox name=\"disp[$i]\" ".
                (($m['disp']) ? 'checked' : '').'> <td> <input name=dAuth type=radio '.(($dAuth == $i) ? 'checked' : '').
		" value=$i> <td> <input name=\"tipEx[$i]\" size=1 value=\"{$m['tipEx']}\"> <td> <input name=\"urlA[$i]\" size=40 value=\"".
		enti($m['urlA']).'">';
	}
	echo '</table><br><input type=checkbox id=jmpau name=jmpau '.(($jmpau) ? 'checked' : '').
		'><label for=jmpau>'.__('Saltar a la autenticación por defecto si no está autenticado o si sólo hay/queda un método')
		.'</label><p><table od=confstork><tr><th>'.__('Paises con STORK').'<th>'.__('Sus datos y los de su PEPS').'<tr><td><table id=lispais>';
	list($certS,$cPEPS,$provName,$provId,$provCountry,$uPru)=mysql_fetch_row(mysql_query("select certS,cPEPS,provName,provId,provCountry,uPru from eVotDat"));
	$m=mysql_fetch_assoc(mysql_query("select * from eVotMetAut where idH = 10"));
	$q=mysql_query("select * from eVotPais order by peps desc, idY");
	while ($p=mysql_fetch_assoc($q))
	  echo "<tr> <td> <input type=checkbox name=\"stork[{$p['idY']}]\"".(($p['peps']) ? ' checked' : '').
		'> <td> <img width=22 height=15 src="data:image/gif;base64,'.base64_encode($p['imgY'])."\"> <td> {$p['nomYE']} | ".
		(($p['peps']) ? "<input name=nomY[{$p['idY']}] value=\"".enti($p['nomY']).'">' : $p['nomY']);
	foreach(array('certS','cPEPS') as $q) {
	  $t=openssl_x509_parse($$q);
	  unset($t['purposes']);
	  unset($t['extensions']);
	  ${'t'.$q}=enti(wordwrap(str_replace("Array\n",'',print_r($t,true)),64,"\n",true));
	}
	echo '</table><td valign=top><input type=checkbox name=uPru'.(($uPru) ? ' checked>' : '>').__('Usar PEPS de prueba').
		'<br><br>'.__('Su nombre de proveedor').':<br><input size=40 name="provName" value="'.enti($provName).
		'"><br><br>'.__('Su ID de proveedor').':<br><input size=40 name="provId" value="'.enti($provId).
		'"><br><br>'.__('Su pais (como proveedor)').':<br><input size=3 name="provCountry" value="'.enti($provCountry).
		'"><br><br>'.__('URL del PEPS').':<br><input name="urlA[10]" size=40 value="'.enti($m['urlA']).
		'"><br><br>'.__('Certificado del PEPS')."<pre>$tcPEPS</pre><textarea id=cPEPS name=cPEPS".filcol($cPEPS,"\n").
		'<br><br><input type=submit name="acc[gesAut]" value="'.__('Actualizar').'"><br><br>'.__('Certificado para enviar al PEPS').
		"<pre>$tcertS$certS</pre></table></form>";
	break;
	// }}}

    case 'elij': // {{{
	$elij=intval($_REQUEST['elij']);
	list($idM)=mysql_fetch_row(mysql_query("select idM from eVotMes,eVotElecs,eVotPart where mesaElec = idM and idE = $elij and idE = elecPart and partElec = '$iAm'"));
	if (!$idM)
	  die('Error en secuencia');
	mysql_query("delete eVotPart from eVotPart,eVotMes,eVotElecs where elecPart = idE and partElec = '$iAm' and mesaElec = idM and idM = $idM and elecPart != $elij");
	echo "<script>window.location.href='$hst$escr';</script>", __('Pulse inicio'); // es preciso huir del POST
	break;
	// }}}

    default: // {{{
	if ($jf > 2) { // {{{ botonera del jefe
	  if ($_SESSION['authextra']) {
	    mysql_query("update eVotDat set authextra=0");
	    $_SESSION['authextra']=false;
	  }
	  list($backup)=mysql_fetch_row(mysql_query("select backup from eVotDat"));
	  if ($backup > 0)
	    $penbck='<p id=back>'.__('Sistema pendiente de backup');
	  $disa1=($mante<1) ? '" disabled' : '"';
	  $disa2=($mante<2) ? '" disabled' : '';
	  echo $jefm.'<form onsubmit="cubre()" method=post><input type=submit id=btedPob name="acc[edPob]" value="'.__('Población').$disa1.
		'> <input type=submit id=btMes'.$pacien.'name="acc[edjMes]" value="'.__('Mesas').$disa1.
		'> <input type=submit id=btinfUrl name="acc[infUrl]" value="'.__('URL de ayuda').'"'.
		'> <input type=submit id=btselImgErr name="acc[imgMod][error][1]" value="'.__('Imagen de error').'"'.
		'> <input type=submit id=btdomDef name="acc[domDef]" value="'.__('Dominio por defecto').$disa1.
		// '> <input type=submit id=btpasSMS name="acc[pasSMS]" value="'.__('SMS').$disa1.
		'> <input type=submit id=bteSurvey name="acc[eSurvey]" value="'.__('eSurvey').'"'.
		(($disa2) ? '' :
		'> <input type=submit id=btupdPrg name="acc[updPrg]" value="'.__('Actualizar el software').'"').
		'> <input type=submit id=btcss name="acc[css]" value="'.__('CSS').$disa1.
		'> <input type=submit id=btcss name="acc[gesAut]" value="'.__('Gestionar autenticación').$disa1.
		'>'.(($mante) ? ' <input type=submit id=btdwMant name="acc[dwMant]" value="'.__('Disminuir mantenimiento').'">': ''). // 3 lineas de codigo de depuracion eliminadas por mkInstaller
		"</form>$penbck</div>";
	} // }}}
	if ($jf > 1) { // {{{ gestor de votaciones
	  echo $jefe.'<form onsubmit="cubre()" method=post><table id=admm>';
	  $q=mysql_query("select * from eVotMes where est < 3 and ( adm = 0 or adm = $iAm) order by est, fin desc");
	  if (mysql_num_rows($q)) {
	    echo '<tr id=vproc><td class=lab>'.__('Votación en proceso').' <td class=selm><select name="eidM">';
	    while ($f=mysql_fetch_assoc($q))
	      echo "<option value={$f['idM']}>{$f['nomMes']} ({$f['idM']}) (".strftime(__('%d/%b/%Y'),$f['ini']).") ({$estas[$f['est']]})";
	    echo '</select> <td class=edem><input type=submit id=btedMes name="acc[edMes]" value="'.__('Editar').'">';
	  }
	  $q=mysql_query("select * from eVotMes where est >= 3 and ( adm = 0 or adm = $iAm) order by fin desc");
	  if (mysql_num_rows($q)) {
	    echo '<tr id=vhist><td class=lab>'.__('Histórico').' <td class=selm><select name="eidMV">';
	    while ($f=mysql_fetch_assoc($q))
	      echo "<option value={$f['idM']}>{$f['nomMes']} ({$f['idM']}) (".strftime(__('%d/%b/%Y'),$f['ini']).") ({$estas[$f['est']]})";
	    echo '</select> <td class=edem><input type=submit id=btedMesV name="acc[edMesV]" value="'.__('Ver').'">';
	  }
	  echo '</table><div id=nuev><input type=submit id=btnueMes name="acc[nueMes]" value="'.__('Nueva').'"></div></form></div>';
	} // }}}
	if ($jf > 0) 
	  echo $jefp.'<form onsubmit="cubre()" method=post><p><input type=submit id=btregPw name="acc[regPw]" value="'.__('Iniciar').'"></p></form></div>';
	$q=mysql_query("select * from eVotMes,eVotMiem where mesMiemb = idM and miembMes = '$iAm' and ((est < 2) or ((est > 1) and pres)) order by est, fin, nomMes");
	$hay1=''; $hay2='';
	while ($m=mysql_fetch_assoc($q))
	  if ((($est=$m['est']) < 5) and ($est < 4 or (!$m['fmdof'] and ($now-$m['fin']) < 24*7*3600)))
	    $hay1.=strftime("<tr><td class=nomm>{$m['nomMes']} <td class=inim>".__('%d/ %H:%M'),$m['ini']).strftime(" <td class=finm> - ".__('%d/%b/%Y %H:%M'),$m['fin']).
		"<td class=estam>".$estas[$est]."<td class=gesm><input type=submit id=btgesMes name=\"acc[gesMes][{$m['idM']}]\" value=\"".__('Gestionar').'"><br>';
	  else
	    $hay2.="<option value={$m['idM']}>{$m['nomMes']} ({$m['idM']}) (".strftime(__('%d/%b/%Y'),$m['ini']).")";
	if ("$hay1$hay2") {
	  echo $miem.'<form onsubmit="cubre()" method=post>';
	  if ($hay1)
	    echo '<table id=mesas>'.$hay1.'</table>';
	  if ($hay2)
	    echo '<p class=histm>'.__('Histórico').': <select name="lames">'.$hay2.'</select> <input type=submit ass=btgesMes name="acc[gesMes]" value="'.__('Gestionar').'">';
	  echo '</form></div>';
	}
	// sólo una votación
	if (list($idE)=mysql_fetch_row(mysql_query("select idE from (eVotMes,eVotElecs) left join eVotPart on elecPart = idE and partElec = '$iAm' where mesaElec = idM and abie = 1 and acude is NULL and est = 2 and ini < $now and fin > $now"))) // añade votante en votación abierta
	  mysql_query("insert into eVotPart (partElec,elecPart,acude) values ($iAm,$idE,0)");
	$unesu=false; $pend=false;
	// excluyentes
	$qM=mysql_query("select * from eVotMes,eVotElecs,eVotPart where exclu = 1 and mesaElec = idM and elecPart = idE and acude = 0 and partElec = '$iAm' and est = 2 and ini < $now and fin > $now");
	if (mysql_num_rows($qM)) {
	  $reps=array();
	  while ($vot=mysql_fetch_assoc($qM)) {
	    $reps[$vot['idM']]++;
	  }
	  asort($reps); reset($reps); $idM=@key($reps);
	  if (current($reps) > 1) { // si es 1 , ya puedo votar a esa, si no elige
	    echo '<div id=vota class=sect><div class=cab>'.__('Usted sólo puede participar en <b>una</b> de las siguientes elecciones, debe decidir en cuál participar, la decisión es irreversible').'</div><form id=exclFrm onsubmit="cubre()" method=post>',
		'<script>function epo() { var o=document.getElementById("vota"), c=0; if (o.offsetParent) do { c += o.offsetTop } while (o=o.offsetParent); window.scrollBy(0,c-10); } window.onload=epo;</script>'; 
	    $qX=mysql_query("select * from eVotElecs,eVotPart where mesaElec = $idM and elecPart = idE and acude = 0 and partElec = '$iAm' order by posE, nomElec");
	    while ($vot=mysql_fetch_assoc($qX)) {
	      $idE=$vot['idE'];
	      echo "<span onclick=\"window.sele=true; document.getElementById('act').src='?vBallot=$idE&fr=1'\" onmouseover=\"if (!window.sele) document.getElementById('act').src='?vBallot=$idE&fr=1'\"><input type=radio name=elij id=bt$idE value=$idE><label for=bt$idE> {$vot['nomElec']}</label></span><br>";
	    }
	    die('<p><input type=submit id=btelij name=acc[elij] value="'.__('Elegir').
		    '"></form><br><div style="height: 30em"><iframe frameborder=0 style="border: 0; height: 100%; width: 100%;" name=act id=act></iframe></div></div>');
	  }
	}
	// recover
	$qM1=mysql_query("select * from eVotMes,eVotElecs,eVotPart,eVotRecvr where mesaElec = idM and elecPart = idE and acude = 1 and partElec = '$iAm' and est = 2 and ini < $now and fin > $now and idpR = partElec and sgnd != '' and svy = idE order by fin asc, posE, nomElec");
	$qM2=mysql_query("select * from eVotMes,eVotElecs,eVotPart where mesaElec = idM and elecPart = idE and acude = 0 and partElec = '$iAm' and est = 2 and ini < $now and fin > $now order by fin asc, posE, nomElec");
	while ($vot=mysql_fetch_assoc($qM1) or $vot=mysql_fetch_assoc($qM2)) {
	  $pend=true;
	  $idE=$vot['idE'];
	  if ($_SESSION['saltar'][$idE])
	    continue;
	  $unesu=true;
	  echo '<script id=cgESvy language="JavaScript" type="text/javascript" charset="UTF-8" src="'.(($vot['clien']) ? 'https://esurvey.nisu.org/' : '').'eSurvey.js"></script>',
		"<script language=\"JavaScript\" type=\"text/javascript\">if (typeof eSurvey == 'undefined') document.write('<script language=\"JavaScript\" type=\"text/javascript\" charset=\"UTF-8\" src=\"eSurvey.js\"><\/script>');</script>",
		'<div id=vota class=sect><div class=cab>'.__('Votación pendiente (puede haber más)').'</div>',
		'<script>function epo() { var o=document.getElementById("vota"), c=0; if (o.offsetParent) do { c += o.offsetTop } while (o=o.offsetParent); window.scrollBy(0,c); } window.onload=epo; </script>';
	  if ($vot['acude']) {
	    echo '<p></p><div id=recover>'.__('Se le muestra esta elección en la que ya ha participado porque se registraron problemas en el envío. Debe marcar la papeleta igual que lo hizo anteriormente.').'</div><p></p>';
	  }
	  $enom='eV'.preg_replace('/[^a-zA-Z_0-9]/','',$vot['nomElec']);
	  dispPart($vot,false);
	  $eExcl='';
	  foreach (dispElec($vot,true) as $unEl)
	    // eExcl es vacío si no hay listas premarcadas
	    $eExcl.="<skip>$unEl</skip>";
	  $cual=$idE;
	  // suficiente auth?
	  $altAu=explode(';',$vot['tAuth']);
	  foreach($altAu as $i=>$au1)
	    $altAu[$i]=explode(',',$au1);
	  $cuAuth=array_keys($aupar['mth']); $ok=false;
	  foreach($altAu as $mth)
	    if (! $faltan=array_diff($mth,array_intersect($cuAuth,$mth))) {
	      $ok=true;
	      break;
	    }
	  if (!$ok) {
	    if (count($altAu) >1)
	      $inca='t';
	    else
	      $inca=implode(',',$faltan);
	    printf('<big>'.__('Para poder participar en esta elección debe <a href="%s">aumentar</a> su autenticación o <a href="%s">comprobar</a> si hay más votaciones pendientes').'</big>',"?incauth=$inca","?abs=$idE");
	    break;
	  }
	  $fin=$vot['fin']; $cie=$fin+intval(2*(600+max(1,($lev=$vot['lev']))*120)); // no lo uso
	  list($opEsvy)=mysql_fetch_row(mysql_query("select opEsvy from eVotPob where idP = $iAm"));
	  if ($opEsvy)
	    if ($opEsvy > 10)
	      $lev=max($opEsvy-10,$lev);
	    else
	      $lev=$opEsvy;
	  list($eCrtS,$modS,$expS,$modU,$expU,$keyyS)=mysql_fetch_row(mysql_query("select eCrtS, modS, expS, modU, expU, keyyS from eVotDat"));
	  list($sModS,$sExpS)=mysql_fetch_row(mysql_query("select sModS,sExpS from eVotElecs where idE = '$idE'"));
	  if (!$eCrtS) $eCrtS=$modS;
	  if ($vot['modIU']) $urni="<bBxIMod>{$vot['modIU']}</bBxIMod>	
		  <bBxIExp>{$vot['expIU']}</bBxIExp>	
";
	  $eSPars="<eSurveyParameters>	
		  <name>$enom</name>	
		  <idSvy>{$vot['idE']}</idSvy>	
		  <lang>$whichLang</lang>	
		  <svrUrl>$dir/wserv.php</svrUrl>	
		  <svrAuth>".session_id()."</svrAuth>	
		  <svrCert>$eCrtS</svrCert>	
		  <svrExp>$expS</svrExp>	
		  <svrSCert>$sModS</svrSCert>	
		  <svrSExp>$sExpS</svrSExp>	
		  <keepA>true</keepA>		
		  <rouLen>$lev</rouLen>	
		  <bBxUrl>$dir/wserv.php</bBxUrl>	
		  <bBxMod>$modU</bBxMod>	
		  $urni<bBxExp>$expU</bBxExp>	
		  <endD>{$fin}000</endD>	
		  <cloD>0</cloD>	
		  <sButt>bot</sButt>		
		  <areaLog>tlo</areaLog>	".(($vot['audit']) ? "
		  <areaHash>tha</areaHash>	
		  <urlVer>$hst$escr?vHash={$vot['idE']}</urlVer>	" : '')."
		  <eVot>true</eVot>		".(($vot['acude']) ? "
		  <recover>true</recover>	" : '')."
		  <skip>abstene</skip>$eExcl	".(($eExcl) ? "
		  <pauseIfExt>true</pauseIfExt>	" : '')."
		  <refresh>true</refresh>	
		  <minVer>2011040401</minVer>	
		</eSurveyParameters>";
	  if ($_SERVER['HTTPS'])
	    $sgPrs='null';
	  else {
	    openssl_sign($eSPars,$sgPrs,$keyyS,OPENSSL_ALGO_MD5);
	    $sgPrs="'<eSurveyPrsSignature>".base64_encode($sgPrs)."</eSurveyPrsSignature>'";
	  }
	  $eSPars=str_replace("\n",'\n',$eSPars);
	  if (!$vot['anulable'])
	    // firefox?
	    echo "<script>if ((typeof(window.navigator.mozIsLocallyAvailable) == 'function') && (typeof(eSurveyExtensionLauncher) != 'function')) document.write('".
		sprintf(jsesc(__('Si está usando Firefox, le interesa instalar la %sextensión <i>eSurvey</i>%s')),'<a href="http://eSurvey.NiSu.org/eSurvey.xpi">','</a>')."');</script>";
	  echo "<script language=\"JavaScript\" charset=\"UTF-8\">
	    encu = new eSurvey('$eSPars',$sgPrs);
	    encu.prevChS=encu.chStage;
	    encu.chStage = function (st) {
	      if ((st == 'quik') || (st == 'sndg'))
	        encu.formu.abstene.disabled=true;
	      this.prevChS(st);
	    }
	    encu.prevErr=encu.error;
	    encu.error = function (m,c) {
	      encu.tlog.style.height='30em';
	      encu.prevErr(m,c);
	    }
	    encu.prevWar=encu.warning;
	    encu.warning = function (m) {
	      encu.tlog.style.height='30em';
	      encu.prevWar(m);
	    }
	    encu.prevCan=encu.cancelV;
	    encu.cancelV  = function () {
	      encu.prevCan();
	      encu.formu.abstene.disabled=false;
	    }
	  </script>",
	  '<input type=button value="..." disabled id=btbotey name=bot onClick="if (encu.extLaun) { this.disabled=true; this.value=\''.jsesc(__('Use la extensión')).
	  '\'; encu.iterate(); } else if (!encu.send()) location.href=\''.$hst.$escr.'\';" onmouseover="if (!encu.extLaun) tout=setTimeout(\'colores.visibility=\\\'visible\\\'\',100);"'.
	  ' onmouseout="try {clearTimeout(tout); colores.visibility=\'hidden\'; } catch (e) {}">',
	  " <a href=\"$escr?abs=$idE\"><input type=button id=btabs value=\"".__('Abstenerse')."\" name=abstene onclick=\"location.href='$escr?abs=$idE';\"></a><br>".
	  (($vot['audit']) ? '<textarea id=txthaey name=tha cols=50 rows=5></textarea>' : '').
	  '<textarea cols=60 rows=30 name=tlo '.(($vot['vlog'])? 'id=txtlogey' : 'style="visibility: hidden; height: 1px;"').'></textarea></form>',
	  '<div style="padding: 3em; background-color: #ff6; visibility: hidden; position:  fixed; bottom: 2em; left: 20em;" id="colores" '.
	  'onmouseout="try {colores.visibility=\'hidden\'; clearTimeout(tout); } catch(e) {}">',
	  __('<h4>Botón de envío</h4>En <font color="black">negro</font>: eSurvey está trabajando, pero puede enviar<br>En <font color="green">verde</font>: Ya puede enviar la papeleta si es correcta<br>En <font color="cyan">cyan</font>: eSurvey está preparando el envío<br>En <font color="magenta">magenta</font>: <b>Esperando el primer envío</b><br>En <font color="darkorange">naranja</font>: Todo va bien, espere<br>En <font color="blue">azul</font>: Perfecto<br>').
	  '</div><script>var colores=document.getElementById(\'colores\').style; if (encu.extLaun) { p=document.getElementById("btbotey"); if ("'.$eExcl.'") { p.value="'.jsesc(__('Iniciar después de marcar')).'"; p.disabled=false; } else p.value="'.jsesc(__('Marque la papeleta y use la extensión')).'"; } </script>';
	  break;
	}
	if (!$pend)
	  echo '<div id=vota class=sect><div class=cab>'.__('No tiene votaciones pendientes').'</div>';
	else if (!$unesu) {
	  unset($_SESSION['saltar']);
	  echo '<div id=vota class=sect><div class=cab>'.__('Hay votaciones pendientes').'</div><form action="'.$escr.'"><input type=submit id=btVotaC value="'.__('Continuar').'"></form>';
	}
	echo '</div>';
	$q=mysql_query("select * from eVotMes,eVotElecs,eVotPart where mesaElec = idM and elecPart = idE and partElec = '$iAm' and est > 0 and est < 3 and fin >= $now and idE != '$cual' order by fin, posE, nomElec");
	if ($ioec=mysql_num_rows($q))
	  echo '<div id=info class=sect><div class=cab>'.__('Información de otras elecciones en curso').'</div>';
	while ($vot=mysql_fetch_assoc($q))
	  dispPart($vot);
	if ($ioec)
	  echo '</div>';
	$q=mysql_query("select idE,nomElec,fin,est,idM,acude,audit from eVotMes,eVotElecs,eVotPart where mesaElec = idM and elecPart = idE and partElec = '$iAm' and est != 99 and fin < $now and fin > $now-31104000 order by fin desc, posE, nomElec");
	if ($ioea=mysql_num_rows($q))
	  echo '<div id=hist class=sect><div class=cab>'.__('Información de elecciones anteriores').'</div>';
	while ($vot=mysql_fetch_assoc($q)) {
	  $idE=$vot['idE'];
	  echo '<div class=hist class=sect><h3 class=nomElec>'.$vot['nomElec'].'</h3><table width="100%"><tr class=fin height=3><td class=lab>'.__('Fin').': <td>'.strftime(__("%d/%b/%Y %H:%M"),$vot['fin']).
		"<td width=\"50%\" rowspan=3 style=\"height: 3em;\" class=fram><iframe name=act$idE id=act$idE frameborder=0 style=\"border: 0px; height: 100%; width: 100%\"></iframe><tr class=actcom height=3>".(($vot['est'] == 4) ?
		  '<td class=lab>'.__('Acta').": <td><a target=\"act$idE\" href=\"?vRecord=$idE\">".__('Ver').
			"</a> - <a target=\"act$idE\" href=\"?record=$idE\">".__('Recibir').'</a>' .
		  	(($vot['audit']) ? " - <a target=\"act$idE\" href=\"?vHash=$idE\">".__('Recibos').'</a>' : '') :	
		  "<td colspan=2 class=comm><a target=\"act$idE\" href=\"?comu={$vot['idM']}&el=$idE\">".__('Comunicar con los miembros de la mesa').'</a>' ).
		'<tr class=supa><td class=lab>'.__('Su participación').': <td>'.(($vot['acude']) ? __('Ha participado') : __('No ha participado') ).
		'</table></div>';
	}
	if ($ioea)
	  echo '</div>';
	// }}}
  }
  // }}}

  // funcs {{{

  function moniac($id) { // {{{
    echo "
<script>
  function moni2() {
    client.open('GET', '?upmon=$id', false);
    client.send();
    if (resp=client.responseText)
      obj.value=msg[resp.substr(0,1)]+resp.substr(1);
    setTimeout('moni2()',1000);
  }
  function moni(o) {
    obj=o;
    document.getElementById('cubre').style.display='block';
    setTimeout('moni2()',3000);
  }
  function nwHttpClient () {
    var client=null;
    if (window.XMLHttpRequest)
      client=new XMLHttpRequest();
    else if (window.ActiveXObject)
      client=new ActiveXObject('Microsoft.XMLHTTP');
    return client;
  }
  var client = nwHttpClient();
  var msg={'p':'".jsesc(__('Procesando '))."','c':'".jsesc(__('Cargando '))."','l':'".jsesc(__('Clasificando '))."','e':'".jsesc(__('Espere'))."'};
</script>";
  } // }}}

  function jsesc($msg) { // {{{
    return str_replace(array("'","\n"),array("\\'",'\n'),$msg);
  } // }}}

  function alerta($msg) { // {{{
    if ($msg)
      echo "<script>alert('".jsesc($msg)."');</script>";
  } // }}}

  function genPwd($pwd,$sal='') { // {{{
    if (!$sal)
      $sal=substr(md5(uniqid('',true)),0,10);
    for ($i=0; $i<5; $i++)
      $pwd=md5($sal.$pwd);
    return $sal.$pwd;
  } // }}}

  function filcol($txt,$se='<br/>',$m=1) { // {{{
     $rw=max(count(explode($se,$txt)),$m);
     return " rows=$rw>".enti(str_replace('<br/>',"\n",$txt)).'</textarea>';
  } // }}}

  function ponJsJFir($bot,$resuls) { // {{{
    global $whichLang;
echo '<applet id="CryptoApplet" code="es.uji.security.ui.applet.SignatureApplet" width="0" height="0" codebase="aps" archive="uji-ui-applet-2.1.1-signed.jar, uji-config-2.1.1-signed.jar, uji-utils-2.1.1-signed.jar, uji-crypto-core-2.1.1-signed.jar, uji-keystore-2.1.1-signed.jar, lib/jakarta-log4j-1.2.6.jar, uji-crypto-cms-2.1.1-signed.jar, lib/bcmail-jdk15-143.jar, lib/bcprov-jdk15-143.jar" mayscript></applet><script languaje="javascript">
  firmado=false;
  var nopu=50;
  function nopuedo() {
    if (nopu < 0)
      return;
    if (nopu == 0) {
      document.formu["acc['.$bot.']"].value=\''.enti(__('Error')).'\';
      alert(\''.jsesc(__('Parece que el applet no puede iniciarse, por favor, asegurese de que la instalación del plugin de java es correcta.')).'\');
      return;
    }
    nopu--;
    document.formu["acc['.$bot.']"].value=\''.enti(__('Cargando ')).'\'+nopu;
    setTimeout("nopuedo();",1000);
  }
  setTimeout("nopuedo();",1000);

  function onInitOk() {
    with (document.formu["acc['.$bot.']"]) {
      value=\''.enti(__('Firmar')).'\';
      disabled=false;
    }
    nopu=-1;
  }
  function elfirmar(h) {
    try {
      var cp= document.getElementById("CryptoApplet");
      cp.setLanguage("'.strtoupper($whichLang).'_'.$whichLang.'");
      cp.setSignatureOutputFormat("CMS_HASH");
      cp.setOutputDataEncoding("BASE64");
      cp.setInputDataEncoding("HEX");
      cp.signDataParamToFunc(h,"onSignOk");
    } catch(e) { alert(e); onSignError(); }
  }
  idx=0, max=0; resuls=new Array();
  function onSignOk(res) {
    document.formu["'.$resuls.'["+resuls[idx]+"]"].value=res;
    if (++idx == resuls.length) {
      firmado=true;
      document.formu["acc['.$bot.']"].click();
    }
  }
  function onSignCancel() {
    descubre();
  }
  function onSignError() {
    alert(\''.jsesc(__('Por favor, reinicie su navegador, parece que hubo un problema en la aplicacion, si ya lo ha hecho pongase en contacto con un administrador.')).'\');
    descubre();
  }
  function descubre() {
    document.getElementById("cubre").style.display="none";
  }
</script>';
  } // }}}

  function ponJsFir() { // {{{

echo '<script language="vbs">
Function MyStrConv(Ustr)
  Dim i
  Dim ch
  MyStrConv = ""
  m  = ""
  m2 = ""
  For i = 1 to Len(Ustr)
    ch = Mid(Ustr, i, 1)
    m = m & ChrB(AscB(ch))
    if (i mod 1000) = 0 Then
      m2 = m2 & m
      m = ""
      if (i mod 100000) = 0 Then
        MyStrConv = MyStrConv & m2
        m2 = ""
      end if
    end if
  Next
  MyStrConv = MyStrConv & m2 & m
End Function

Const CAPICOM_CURRENT_USER_STORE                        = 2
Const CAPICOM_CERTIFICATE_FIND_ISSUER_NAME              = 2
Const CAPICOM_CERTIFICATE_FIND_EXTENDED_PROPERTY        = 6
Const CAPICOM_CERTIFICATE_FIND_KEY_USAGE 		= 12
Const CAPICOM_DIGITAL_SIGNATURE_KEY_USAGE 		= 128
Const CAPICOM_AUTHENTICATED_ATTRIBUTE_SIGNING_TIME      = 0
Const CAPICOM_CERTIFICATE_INCLUDE_CHAIN_EXCEPT_ROOT     = 0
Const CAPICOM_PROPID_KEY_PROV_INFO                      = 2
Const CAPICOM_ENCODE_BASE64                             = 0

Set Conf = CreateObject("CAPICOM.Settings")
Set Attri = CreateObject("CAPICOM.Attribute")
Set Store = CreateObject("CAPICOM.Store")
Set Util = CreateObject("CAPICOM.Utilities")
Set Signer = CreateObject("CAPICOM.Signer")
Store.Open CAPICOM_CURRENT_USER_STORE, "MY"
Set Certificates = Store.Certificates

Function firmacapi(txt)

  Set Cosa = CreateObject("CAPICOM.SignedData")
  Set Certificates = Certificates.Find(CAPICOM_CERTIFICATE_FIND_KEY_USAGE,CAPICOM_DIGITAL_SIGNATURE_KEY_USAGE,True)
  Count=Certificates.Count
  If Count = 0 Then
    MsgBox "'.__('No hay ningún certificado válido').'"
    Exit Function
  End If
  If Count > 1 Then
    Set Certificates = Certificates.Select("Elija Cert", "Elija Certificado", False)
    If Certificates.Count = 0 Then
      MsgBox "'.__('No ha seleccionado ninguno').'"
      Exit Function
    End If
  End If
  Signer.Certificate = Certificates(1)
  Attri.Name = CAPICOM_AUTHENTICATED_ATTRIBUTE_SIGNING_TIME
  Attri.Value = Util.LocalTimeToUTCTime("'.strftime("%Y-%m-%d %H:%M:%S").'")
  Signer.AuthenticatedAttributes.Add Attri
  Signer.Options = CAPICOM_CERTIFICATE_INCLUDE_CHAIN_EXCEPT_ROOT
  Cosa.Content = MyStrConv(txt)
  firmacapi=Cosa.Sign(Signer, True, CAPICOM_ENCODE_BASE64)

End Function
</script>
<script language="javascript">
   function elfirmar(txt) {
     if (window.crypto)
       return crypto.signText(txt,"auto")
     else return firmacapi(txt);
   }
  function descubre() {  
    document.getElementById("cubre").style.display="none";
  }
</script>';

  } // }}}

  function haz_subj($txt,$fec=0) { // {{{
    return '    =?UTF-8?Q?'.trim(wordwrap(str_replace(array('%20','%'),array(' ','='),rawurlencode(
		(($fec) ? sprintf($txt,strftime(__('el %d de %B de %Y a las %H:%M'),$fec)) : $txt))).
		'?=',72,"?=\n    =?UTF-8?Q? "));
  } // }}}

  function vfFirma($afir,$firma) { // {{{
    global $swrkf;
    $bou=md5(uniqid('',true));
    $cab="MIME-Version: 1.0\n".
		"Content-type: multipart/signed;\n    protocol=application/x-pkcs7-signature; micalg=sha1;\n    boundary=$bou";
    $firm=str_replace("\r\n","",$firma);
    $firm=chunk_split($firm,76,"\n");
    if (strlen($firm) < 200)
      die(__('La firma es incorrecta'));
    $cue="SMIME message builded by mm AT nisu.org\n\n".
		"--$bou\n$afir\n--$bou\n".
		"Content-Type: application/x-pkcs7-signature; name=smime.p7s\n".
		"Content-Transfer-Encoding: base64\n".
		"Content-Disposition: attachment; filename=smime.p7s\n".
		"Content-Description: S/MIME Cryptographic Signature\n\n$firm\n--$bou--\n";
    @fwrite($h=fopen($fma=tempnam('/tmp','smime-'),'w'),"$cab\n$cue"); fclose($h);
    $vffir=openssl_pkcs7_verify($fma,PKCS7_NOVERIFY,$fcer=tempnam('/tmp','smime-'));
    $ficer=openssl_x509_parse(file_get_contents($fcer),true);
    @unlink($fma); @unlink($fcer);
    if ($vffir !== true) {
      echo '<p>'.__('Problemas en la verificación del acta firmada');
      echo '<br>'.openssl_error_string().'<p>';
      $swrkf['firmante']='';
      return;
    }
    $pers=trim(preg_replace('/[^0-9A-Za-z ]/','',$ficer['subject']['CN']));
    $fmai=$ficer['extensions']['subjectAltName'];
    if (preg_match("/email:([^@]*@[A-Za-z-\.]*)/i",$fmai,$ma))
      $fmai=$ma[1];
    else
      $fmai=$ficer['subject']['emailAddress'];
    if ($fmai)
      $pers.=" <$fmai>";
    if ($swrkf['firmante']) {
      if ($swrkf['firmante'] != $pers) {
	echo __('Deben firmarse todas las actas con el mismo certificado').'<br>';
	$swrkf['firmante']='';
      }
    }
    else {
      $swrkf['firmante']= $pers;
      echo '<span id=firmRes>'.__('Firmante').': '.enti($pers);
      if (!$fmai)
	echo '<font color=red>'.__('Convendría que empleara un certificado con dirección de e-mail').'</font>';
      echo '</span>';
    }
    $pers=trim(wordwrap($pers,72,"\n    "));
    $cab="From: $pers\n$cab";
    return trim("$cab\n\n$cue");
  } // }}}

  function pillaURL($url,$tol=false) { // {{{
    $ca=true;
    while (true) {
      $ch=curl_init();
      curl_setopt($ch, CURLOPT_URL, $url);
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
      #curl_setopt($ch, CURLOPT_TIMEOUT, 15);
      @curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
      if (!$ca)
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
      $result = curl_exec($ch);
      $err=curl_errno($ch);
      curl_close($ch);
      if ($err == 60 and $tol) {
	$ca=false;
        continue;
      }
      if ($err != 28)
        break;
    }
    if ($err)
      return false;
    return $result;
  } // }}}

  function enti($s) { // {{{
    return htmlentities($s,ENT_QUOTES,'UTF-8');
  } // }}}

  function limp($s) { // {{{
    return mysql_real_escape_string(str_replace("\r\n",'<br/>',strtr(trim($s),'<"'," '")));
  } // }}}
  
  function getModExp($privateKey){
    $privDetails = openssl_pkey_get_details($privateKey);
    if($privDetails == NULL)
        return 'ERR\nError parsing the private key on getModExp';
    return 'OK'."\n"
        .base64_encode($privDetails['rsa']['e'])."\n"
        .base64_encode($privDetails['rsa']['n']);
  }
  
  function newKCEM($tkd,$lng) { // {{{
    echo '<div class=genEspere>'.__('Espere')."</div>\n"; flush();
    if (!$csr=openssl_csr_new(
		  array("commonName" => '-',
			"emailAddress" => '-',
			"countryName" => 'XX',
			"localityName" => '-',
			"stateOrProvinceName" => '-',
			"organizationName" => '-',
		       ),$priv,
		  array("private_key_bits" => intval($lng))))
      die('<div class=genError>'.__('Error al generar el cert y la llave').'</div>');
    openssl_csr_export($csr,$r);
    if ($tkd){
      $pet='rreq='.urlencode($r).'&tkd='.urlencode($tkd);
      list($rs,$e,$m)=explode("\n",$z=@pillaURL("https://esurvey.nisu.org/sites?$pet"));
    }
    else
        //$pet='parsereq='.urlencode($r);
        list($rs,$e,$m)=explode("\n",$z=getModExp($priv));
    if ($rs != 'OK')
      die('<div class=genError>'.__('Error al parsear con eSurveySites')." $rs</div>");
    openssl_x509_export(openssl_csr_sign($csr,null,$priv,7305),$c);
    openssl_pkey_export($priv,$k);
    echo '<div class=genHecho>'.__('Hecho').'</div>';
    return array($c,$k,$m,$e);
  } // }}}

  function modmes() { // {{{
    global $iAm, $jf, $jefe, $now, $mante, $klng, $dAuth, $masp;
    if ($jf<2)
      die($jefe.'auth');
    $idM=intval($_REQUEST['lames']) or die(__('Selección incorrecta'));
    $mes=mysql_fetch_assoc(mysql_query("select * from eVotMes where idM = $idM and ( adm = 0 or adm = $iAm)"));
    if (!$mes)
      die($jefe.__('Error interno'));
    $est=$mes['est'];
    if (!$nm=limp($_REQUEST['nomMes'])) {
      if ($_REQUEST['cfm']) {
	$q=mysql_query("select * from eVotMes,eVotElecs where mesaElec = idM and idM = $idM and est != 99");
	while ($e=mysql_fetch_assoc($q)) {
	  $idE=$e['idE'];
	  list($totPob) = mysql_fetch_row(mysql_query("select count(*) from eVotPart where elecPart  = $idE"));
	  mysql_query("update eVotElecs set totPob='$totPob' where idE = $idE");
	  mysql_query("delete from eVotPart where elecPart = $idE and acude=0");
	}
	mysql_query("update eVotMes set est=99 where idM = $idM and est != 99");
	mysql_query("delete eVotRecvr from eVotElecs,eVotRecvr where svy = idE and mesaElec = $idM");
	mysql_query("optimize table eVotElecs,eVotRecv,eVotPart,eVotMes");
      }
      else { 
	if ($est > 1)
	  die("$jefe<form onsubmit=\"cubre()\" method=post>".__('La votación ya no puede borrarse, sólo marcarse como errónea')."<input name=lames value=$idM type=hidden>".
	    ' <input type=hidden name=cfm value=1><input type=submit id=btconfErr name="acc[modMes]" value="'.__('Confirmo errónea')."\"$pacien></form>");
	mysql_query("delete eVotSup from eVotElecs,eVotVots,eVotOpcs,eVotSup where mesaElec = $idM and elecVot = idE and votOpc = idV and opcSup = idO");
	mysql_query("delete eVotCan from eVotElecs,eVotVots,eVotOpcs,eVotCan where mesaElec = $idM and elecVot = idE and votOpc = idV and opcCan = idO");
	mysql_query("delete eVotOpcs from eVotElecs,eVotVots,eVotOpcs where mesaElec = $idM and elecVot = idE and votOpc = idV");
	mysql_query("delete eVotPreLd from eVotElecs,eVotVots,eVotPreLd where mesaElec = $idM and elecVot = idE and votPre = idV");
	mysql_query("delete eVotPart from eVotElecs,eVotPart where mesaElec = $idM and elecPart = idE");
	mysql_query("delete eVotVots from eVotElecs,eVotVots where mesaElec = $idM and elecVot = idE");
	mysql_query("delete from eVotElecs where mesaElec = $idM");
	mysql_query("delete from eVotMiem where mesMiemb = $idM");
	mysql_query("delete from eVotMes where idM = $idM");
	mysql_query("optimize table eVotElecs,eVotPart,eVotMes,eVotCan,eVotSup,eVotOpcs,eVotPreLd,eVotVots,eVotMiem");
	bckup();
	die($jefe.__('Eliminada'));
      }
    }
    $error='';
    if ($_REQUEST['adm'])
      $upd="adm=$iAm";
    else
      $upd="adm=0";
    $upd.=",nomMes='$nm'";
    if (isset($_REQUEST['ponest']) and ($ponest=intval($_REQUEST['ponest'])) < 2 and $est < 2) {
      if ($ponest) {
	list($tmie)=mysql_fetch_row(mysql_query("select count(*) from eVotMiem where mesMiemb = $idM"));
	$qE=mysql_query("select idE from eVotElecs where mesaElec = $idM ");
	$tele=mysql_num_rows($qE); $ok=true;
	while ($ele=mysql_fetch_row($qE)) {
	  list($tvts)=mysql_fetch_row(mysql_query("select count(*) from eVotVots where elecVot = {$ele[0]}"));
	  if (!$tvts) {
	    $ok=false;
	    break;
	  }
	}
	if ($tmie and $tele and $ok)
	  $upd.=",est=$ponest";
	else
	  $error.=__('Una mesa debe tener miembros, al menos una elección y cada elección al menos una votación')."\n";
      }
      else {
	$md=array();
	$q=mysql_query("select * from eVotPob,eVotMiem where miembMes = idP and mesMiemb = $idM and pres > 0");
	while ($us=mysql_fetch_assoc($q))
	  $md[$us['idP']]=dirmail($us);
	if (count($md)) {
	  $org=dirmail(NULL,$iAm);
	  $s=haz_subj(__('Notificación del Sistema de Voto Telemático'));
	  $as=__('Notificacion');
	  enviMail($org,$md,haz_alter(__('Por una actualización de la mesa electoral, su revisión ha sido anulada, por favor vuelva a revisarla accediendo al [Sistema].')),$s,$as);
	  $error.=__('Se ha anulado la intervención de los miembros')."\n".__('Mensaje enviado a la mesa')."\n";
	  mysql_query("update eVotMiem set pres=0 where mesMiemb = $idM and pres > 0");
	}
	$upd.=",est=$ponest";
      }
    }
    foreach(array('ini','fin') as $q)
      if ($_REQUEST["m_$q"])
	${"n$q"}=strtotime($_REQUEST["m_$q"].'/'.$_REQUEST["d_$q"].'/'.$_REQUEST["a_$q"].' '.$_REQUEST["h_$q"].':'.$_REQUEST["i_$q"].':00');
      else
	${"n$q"}=$mes[$q];
    if ($est < 3) {
      if ($nini > $nfin) {
	$nini=$nfin;
	$error.=__('Las fechas se han corregido automáticamente')."\n";
      }
      // de momento sólo actualiza fin si > fin_actual, es decir alarga la votacion
      if ($nfin > $mes['fin'] or $est < 1 or $mante)
	$upd.=",fin=$nfin";
    }
    if (!$est or ($est < 2 and $mante)) {
      // en este caso actualiza tb ini
      if ($nini)
	$upd.=",ini=$nini";
      foreach(array('prc') as $q)
	if ($v=mysql_real_escape_string($_REQUEST[$q]))
	  $upd.=",$q='$v'";
    }
    // hago el update
    mysql_query("update eVotMes set $upd where idM='$idM'");
    // mas votantes {{{
    if ($masv=$_REQUEST['masv'] and ($mes['fin'] > $now or $mante) and $est < 3) {
      $info=intval($est >1);
      foreach($masv as $idE => $unos) {
	$idE=intval($idE);
	if (!list($dum,$nomE)=mysql_fetch_row(mysql_query("select idE,nomElec from eVotElecs where mesaElec = $idM and idE=$idE and abie=0")))
	  continue; //no existe o no es abierta
	if ($unos == '__ALL POP__') {
	  mysql_query("insert into eVotPart (partElec,elecPart,info) select idP,'$idE',$info from eVotPob");
	  continue;
	}
	$error2='';
	foreach(explode("\r\n",$unos) as $uno)
	  if (list($idP)=parsea($uno))
	    mysql_query("insert into eVotPart (partElec,elecPart,info) values ($idP,'$idE',$info)");
	  else if ($uno)
	    $error2.="$uno\n";
	if ($error2) {
	  $error.=sprintf(__('Se produjo un error al cargar algunos votantes en %s'),$nomE)."\n";
	  $masp['v'][$idE]=$error2;
	}
      }
    }
    // }}}
    // resto de cosas sólo si en edición o mantenimiento
    if ($est < 1 or $mante) {
      $exclu=intval($_REQUEST['exclu']);
      mysql_query("update eVotMes set exclu=$exclu where idM='$idM'");
      if ($pes=$_REQUEST['pes']) {
	list($mxpe)=mysql_fetch_row(mysql_query("select count(idH) from eVotMetAut where disp = 1")); // incopatible definitiv con el componente
	foreach ($pes as $i => $pe) {
	  $i=intval($i);
	  if ($pe=intval($pe)) {
	    if ($pe > $mxpe) {
	      $pe=$mxpe;
	      $error.=sprintf(__('El nivel de autenticación requerido debe ser menor de %s'),$mxpe)."\n";
	    }
	    mysql_query("update eVotMiem set carg='".mysql_real_escape_string($_REQUEST['carg'][$i])."', pes='$pe' where miembMes = '$i' and mesMiemb = $idM");
	  }
	  else
	    mysql_query("delete from eVotMiem where miembMes = '$i' and mesMiemb = $idM");
	}
      }
      $error2='';
      list($cgi)=mysql_fetch_row(mysql_query("select count(*) from eVotMiem where carg = 'p' and mesMiemb = $idM"));
      $cgi=($cgi) ? 'v' : 'p';
      foreach(explode("\r\n",$_REQUEST['mim']) as $uno) {
	list($i,$g)=parsea($uno);
	if ($i) {
	  mysql_query("insert into eVotMiem (miembMes,mesMiemb,carg,pes,imgM) values ($i,'$idM','$cgi',1,$g)");
	  $cgi='v';
	}
	else if ($uno)
	  $error2.="$uno\n";
      }
      list($tmie)=mysql_fetch_row(mysql_query("select count(*) from eVotMiem where mesMiemb = $idM"));
      if ($tmie) {
	list($nupdt)=mysql_fetch_row(mysql_query("select count(*) from eVotMiem where carg = 'p' and mesMiemb = $idM"));
	if ($nupdt != 1) {
	  $error.=__('Debe haber un presidente/a y sólo uno/a')."\n";
	  if ($nupdt > 1)
	    mysql_query("update eVotMiem set carg='v' where carg = 'p' and mesMiemb = $idM limit ".($nupdt-1));
	  else
	    mysql_query("update eVotMiem set carg='p' where mesMiemb = $idM limit 1");
	}
      }
      if ($error2) {
        $error.=__('Se produjo un error al cargar algunos miembros').":\n".$error2."\n";
	$masp['m']=$error2;
      }
      // elecs {{{
      if ($eles=$_REQUEST['nomE'])
	foreach($eles as $idE => $n) {
	  $n=limp($n);
	  if ($idE == 'n') {
	    if ($n !== '') {
	      if ($pr=mysql_fetch_row(mysql_query("select lev,tAuth,abie,vlog,audit,clien,censoP,ayupap,anulable from eVotElecs where mesaElec = $idM order by posE desc limit 1")))
		list($lev,$tAuth,$abie,$vlog,$audit,$clien,$censoP,$ayupap,$anulable)=$pr;
	      else {
		$lev=$abie=$vlog=$audit=$clien=$censoP=$ayupap=$anulable=0;
		$tAuth=$dAuth;
	      }
	      if ($exclu)
	        $abie=0;
	      list($certSS,$keySS,$modSS,$expSS)=newKCEM('',($klng/8-11)*8);
	      list($keyS)=mysql_fetch_row(mysql_query("select keyyS from eVotDat"));
	      $k=openssl_pkey_get_private($keyS);
	      if (!openssl_private_encrypt(base64_decode($modSS),$msf,$k))
		die(openssl_error_string());
	      $modSS=base64_encode($msf);
	      foreach(array('certSS','keySS','modSS','expSS') as $q)
		$$q=mysql_real_escape_string($$q);
	      $monekey=substr(md5(uniqid('',true)),0,20);
	      mysql_query("insert into eVotElecs (mesaElec,nomElec,posE,lev,tAuth,abie,vlog,audit,clien,censoP,ayupap,anulable,sKeyS,sModS,sExpS,sCertS,monekey) ".
			  "values ($idM,'$n',10000,$lev,'$tAuth',$abie,$vlog,$audit,$clien,$censoP,$ayupap,$anulable,'$keySS','$modSS','$expSS','$certSS','$monekey')"); echo mysql_error();
	      continue;
	    }
	    continue;
	  }
	  $idE=intval($idE);
	  if (!mysql_num_rows(mysql_query("select idE from eVotElecs where idE = '$idE' and mesaElec = $idM"))) // mesaElec para evitar hackeo entre admos, que friki
	    die($jefe.__('Error interno'));
	  if ($n === '') {
	    mysql_query("delete from eVotElecs where idE = '$idE'");
	    mysql_query("delete from eVotVots where elecVot = '$idE'");
	    mysql_query("delete eVotOpcs from eVotVots,eVotOpcs where elecVot = '$idE' and votOpc = idV");
	    mysql_query("delete eVotPreLd from eVotVots,eVotPreLd where elecVot = '$idE' and votPre = idV");
	    mysql_query("delete eVotCan from eVotVots,eVotOpcs,eVotCan where elecVot = '$idE' and votOpc = idV and opcCan = idO");
	    mysql_query("delete eVotPart from eVotPart where elecPart = '$idE'");
	    continue;
	  }
	  $upd='';
	  if ($exclu)
	    $_REQUEST['abie'][$idE]=0;
	  if ($_REQUEST['anulable'][$idE])
	    $_REQUEST['lev'][$idE]=-2;
	  foreach(array('vlog','audit','clien','abie','lev','posE','pie','censoP','ayupap','anulable') as $que)
	    $upd.=", $que='".limp($_REQUEST[$que][$idE])."'"; //limp por el pie
	  $altAu=&$_REQUEST['altAu'][$idE];
	  // simplificación
	  foreach($altAu as $iAu=> $unAu) {
	    $altAu[$iAu]=$unAu=array_keys($unAu);
	    for ($j=$iAu-1;$j>=0;$j--) {
	      $s=array_intersect($unAu,$altAu[$j]);
	      if (!array_diff($unAu,$s))
		$altAu[$iAu]=array();
	      else if (!array_diff($altAu[$j],$s))
		$altAu[$j]=array();
	    }
	  }
	  foreach($altAu as $iAu=> $unAu)
	    if ($unAu)
	      $altAu[$iAu]=implode(',',$unAu);
	    else
	      unset($altAu[$iAu]);
	  if (!$tAuth=implode(';',$altAu))
	    $tAuth=$dAuth;
	  $upd.=", tAuth='$tAuth'";
	  mysql_query("update eVotElecs set nomElec='$n' $upd where idE = '$idE'");
	  //echo '<xmp>'; print_r($_REQUEST['nomV']); echo '</xmp>';
	  // votas {{{
	  if ($vots=$_REQUEST['nomV'][$idE])
	    foreach($vots as $idV => $n) {
	      $n=limp($n);
	      if ($idV == 'n') {
		if ($n !== '') {
		  if ($pr=mysql_fetch_row(mysql_query("select minOps, maxOps, nulo from eVotVots where elecVot = $idE order by posV desc limit 1")))
		    list($minOps,$maxOps,$nulo)=$pr;
		  else {
		    $minOps=0; $maxOps=1; $nulo=0;
		  }
		  mysql_query("insert into eVotVots (elecVot,nomVot,posV,minOps,maxOps,nulo) values ($idE,'$n',10000,$minOps,$maxOps,$nulo)");
		  continue;
		}
		continue;
	      }
	      $idV=intval($idV);
	      if (!mysql_num_rows(mysql_query("select * from eVotVots where idV = '$idV' and elecVot = $idE")))
		die($jefe.__('Error interno'));
	      if ($n === '') {
		mysql_query("delete from eVotVots where idV = '$idV'");
		mysql_query("delete from eVotOpcs where votOpc = '$idV'");
		mysql_query("delete from eVotPreLd where votPre = '$idV'");
		mysql_query("delete eVotCan from eVotOpcs,eVotCan where votOpc = '$idV' and opcCan = idO");
		continue;
	      }
	      $minOps=abs(intval($_REQUEST['minOps'][$idE][$idV]));
	      $maxOps=abs(intval($_REQUEST['maxOps'][$idE][$idV]));
	      $posV=intval($_REQUEST['posV'][$idE][$idV]); $nulo=intval($_REQUEST['nulo'][$idE][$idV]); $nomV=$n;
	      $cans=array(); $nuOpc=0;
	      // opciones {{{
	      if ($opcs=$_REQUEST['nomO'][$idE][$idV])
		foreach($opcs as $idO => $n) {
		  $fP=10000;
		  if ($idO == 'n') {
		    if ($n !== '')
		      foreach(explode("\r\n",$n) as $n) {
			$n=limp($n);
			if ($n === '')
			  continue;
			if ($n[0]=='!' or $n[strlen($n)-1]=='!') {
			  list($uncan,$g)=parsea($n);
			  if (!$uncan)
			    $error.=__('Se produjo un error al cargar el candidato/a').":\n$n\n";
			  else
			    if ($cans[$uncan]) {
			      // debería o puede ?  $uncan='';
			      $error.=__('Un candidato/a o suplente sólo debería aparecer una vez por votación')."\n";
			    }
			  $n='-';
		        }
		        else
			  $uncan='';
			$fP++;
			mysql_query("insert into eVotOpcs (nomOpc,votOpc,posO) values ('$n',$idV,$fP)"); $idO=mysql_insert_id();
			if ($uncan) {
			  $cans[$uncan]=true;
			  mysql_query("insert into eVotCan (canOpc,opcCan,posC,imgC) values ($uncan,'$idO',10,$g)");
			}
			$nuOpc++;
		      }
		    continue;
		  }
		  $idO=intval($idO);
		  if (!mysql_num_rows(mysql_query("select * from eVotOpcs where idO = '$idO' and votOpc = $idV")))
		    die($jefe.__('Error interno'));
		  if ($n === '') {
		    mysql_query("delete from eVotOpcs where idO = '$idO'");
		    mysql_query("delete from eVotCan where opcCan = '$idO'");
		    continue;
		  }
		  $n=limp($n);
		  if (preg_match('/^([*_]).*\1$/',$n))
		    $n[strlen($n)-1]='-';
		  $sepa=limp($_REQUEST['sepa'][$idE][$idV][$idO]); $posO=intval($_REQUEST['posO'][$idE][$idV][$idO]);
		  mysql_query("update eVotOpcs set nomOpc='$n', sepa='$sepa', posO='$posO' where idO = '$idO'");
		  $nuOpc++;
		  $pom=0;
		  $error2='';
		  if ($pos=$_REQUEST['posC'][$idE][$idV][$idO]) {
		    // las operaciones sobre candidatos son seguras con where opcCan = '$idO'
		    foreach($pos as $i => $po) {
		      $i=intval($i); $po=intval($po);
		      if ($po) {
			// deberia o puede ?
			/*
		        if ($cans[$i]) { // detecta errores no detectados previamente
			  $error.=__('Un candidato/a o suplente sólo debería aparecer una vez por votación');
			  mysql_query("delete from eVotCan where canOpc = '$i' and opcCan = '$idO'");
			} else {
			  mysql_query("update eVotCan set posC='$po' where canOpc = '$i' and opcCan = '$idO'");
			  $pom=max($pom,$po);
			  $cans[$i]=true;
			}
			*/
		        if ($cans[$i]) // detecta errores no detectados previamente
			  $error.=__('Un candidato/a o suplente sólo debería aparecer una vez por votación')."\n";
			mysql_query("update eVotCan set posC='$po' where canOpc = '$i' and opcCan = '$idO'");
			$pom=max($pom,$po);
			$cans[$i]=true;
		      }
		      else
			mysql_query("delete from eVotCan where canOpc = '$i' and opcCan = '$idO'");
		    }
		  }
		  foreach(explode("\r\n",$_REQUEST['can'][$idE][$idV][$idO]) as $uno) {
		    list($i,$g)=parsea($uno);
		    if ($i) {
		      if ($cans[$i])
			$error.=__('Un candidato/a o suplente sólo debería aparecer una vez por votación')."\n";
		      // deberia o puede ? else {
		      mysql_query("insert into eVotCan (canOpc,opcCan,posC,imgC) values ($i,'$idO',".($pom+=10).",$g)");
		      $cans[$i]=true;
		      // }
		    }
		    else if ($uno)
		      $error2.="$uno\n";
		  }
		  if ($error2) {
		    $error.=__('Se produjo un error al cargar algunos candidatos/as')."\n$error2\n";
		    $masp['c'][$idE][$idV][$idO]=$error2;
		  }
		  $pom=0;
		  $error2='';
		  if ($pos=$_REQUEST['posS'][$idE][$idV][$idO]) {
		    foreach($pos as $i => $po) {
		      $i=intval($i); $po=intval($po);
		      if ($po) {
			if ($cans[$i])
			  $error2.=__('Un candidato/a o suplente sólo debería aparecer una vez por votación')."\n";
			mysql_query("update eVotSup set posS='$po' where supOpc = '$i' and opcSup = '$idO'");
			$pom=max($pom,$po);
			$cans[$i]=true;
		      }
		      else
		        mysql_query("delete from eVotSup where supOpc = '$i' and opcSup = '$idO'");
		    }
		  }
		  foreach(explode("\r\n",$_REQUEST['sup'][$idE][$idV][$idO]) as $uno) {
		    list($i,$g)=parsea($uno);
		    if ($i) {
		      if ($cans[$i])
			$error2.=__('Un candidato/a o suplente sólo debería aparecer una vez por votación')."\n";
		      mysql_query("insert into eVotSup (supOpc,opcSup,posS) values ($i,'$idO',".($pom+=10).")");
		      $cans[$i]=true;
		    }
		    else if ($uno)
		      $error2.="$uno\n";
		  }
		  if ($error2) {
		    $error.=__('Se produjo un error al cargar algunos suplentes')."\n$error2\n";
		    $masp['s'][$idE][$idV][$idO]=$error2;
		  }
		}
	      // }}}
	      if ($maxOps > $nuOpc)
		$maxOps=$nuOpc;
	      if ($minOps > $maxOps)
		$minOps=$maxOps;
	      mysql_query("update eVotVots set nomVot='$nomV', minOps=$minOps, maxOps=$maxOps, posV='$posV', nulo='$nulo' where idV = '$idV'");
	      // preCargas {{{
	      if ($prlds=$_REQUEST['nomP'][$idE][$idV])
		foreach($prlds as $idPL => $n) {
		  if ($idPL == 'n') {
		    if ($n !== '')
		      foreach(explode("\r\n",$n) as $n) {
			$n=limp($n);
			if ($n === '')
			  continue;
			mysql_query("insert into eVotPreLd (nomPL,votPre) values ('$n',$idV)"); $idPL=mysql_insert_id();
		      }
		    continue;
		  }
		  $idPL=intval($idPL);
		  if (!mysql_num_rows(mysql_query("select * from eVotPreLd where idPL = '$idPL' and votPre  = $idV")))
		    die($jefe.__('Error interno'));
		  if ($n === '') {
		    mysql_query("delete from eVotPreLd where idPL = '$idPL'");
		    continue;
		  }
		  $n=limp($n); $ser=array();
		  foreach ($_REQUEST['prLd'][$idE][$idV][$idPL] as $idO => $dum)
		    $ser[$idO]=true;
		  $ser=mysql_real_escape_string(serialize($ser));
		  mysql_query("update eVotPreLd set nomPL='$n', preVot='$ser' where idPL = '$idPL'");
		}
	      // }}}
	    }
	  // }}}
	} // }}}
    }
    alerta($error);
    bckup();
  }
  // }}}

  function intocable($idP) { // {{{
    list($n)=mysql_fetch_row(mysql_query("select count(idM) from eVotMes,eVotMiem where mesMiemb = idM and miembMes = $idP  and est<3"));
    if ($n) return true;
    list($n)=mysql_fetch_row(mysql_query("select count(idM) from eVotMes,eVotElecs,eVotVots,eVotOpcs,eVotCan where opcCan = idO and canOpc = $idP and votOpc=idV and elecVot=idE and mesaElec=idM and est<3"));
    if ($n) return true;
    list($n)=mysql_fetch_row(mysql_query("select count(idM) from eVotMes,eVotElecs,eVotVots,eVotOpcs,eVotSup where opcSup = idO and supOpc = $idP and votOpc=idV and elecVot=idE and mesaElec=idM and est<3"));
    if ($n) return true;
    return false;
  } // }}}

  function parsea($in) { // {{{
    global $mante, $jf;
    list($ius,$idni,$inom,$icorreo,$ipwd)=array_map('limp',explode('!',$in));
    if ($ius)
      list($idP1)=mysql_fetch_row(mysql_query("select idP from eVotPob where us = '$ius'"));
    if ($idni)
      list($idP2)=mysql_fetch_row(mysql_query("select idP from eVotPob where DNI = '$idni'"));
    if (($idP=$idP1) and $idP2) {
      if ($idP1 != $idP2) // conflicto gordo tiene que ser con el edPob
	return array();
    }
    else if ($idP=$idP1 or $idP=$idP2) {
      if (!$idP1 and $ius) {
	//if (!$mante) // sólo en mantenimiento puede (intentar) cambiar un user dado un DNI
	//  return array();
	mysql_query("update eVotPob set us = '$ius' where ipP=$idP2");
	if (mysql_affected_rows() == -1) // intenta poner un us existente
	  return array();
      }
      else if (!$idP2 and $idni) {
	if (!$mante) // sólo en mantenimiento puede (intentar) cambiar un DNI dado un user
	  return array();
	mysql_query("update eVotPob set DNI = '$idni' where ipP=$idP1");
	if (mysql_affected_rows() == -1) // intenta poner un DNI existente
	  return array();  
      }
    }
    if ($idP) { // idP1 o idP2 o (ambos e iguales)
      if ($inom and !intocable($idP))
	mysql_query("update eVotPob set nom = '$inom' where idP = $idP");
      if ($icorreo)
	mysql_query("update eVotPob set correo = '$icorreo' where idP = $idP");
      list($im)=mysql_fetch_row(mysql_query("select imgC from eVotCan where canOpc = $idP and imgC != 0 order by opcCan desc limit 1")) or
      list($im)=mysql_fetch_row(mysql_query("select imgM from eVotMiem where miembMes = $idP and imGM != 0 order by mesMiemb desc limit 1")) or $im=0;
    }
    else { // añadir
      $cc=''; $dd='';
      foreach(array('ius'=>'us','idni'=>'DNI','inom'=>'nom','icorreo'=>'correo') as $q=>$cm) {
        if (!$$q and $q != 'icorreo') // tiene que estar todos los campos (menos correo) para insertar
	  return array();
	$cc.=",$cm"; $dd.=",'".$$q."'";
      }
      mysql_query("insert into eVotPob (".substr($cc,1).") values (".substr($dd,1).")");
      $idP=mysql_insert_id(); $im=0;
    }
    if ($ipwd and $mante and $jf > 2) {
      mysql_query("update eVotPob set pwd='".genPwd($ipwd)."', clId='-1', oIP=-1, cadPw=0 where idP = $idP");
    }
    return array($idP,$im);
  } // }}}

  function dispPart($vot,$pnEl=true) { // {{{
    global $now, $vcgs, $estas;
    $idE=$vot['idE'];
    echo '<div class=part>';
    if ($pnEl)
      echo '<h3 class=nomElec>'."{$vot['nomElec']}</h3>";
    echo '<table border=0>';
    $vot['now']=$now;
    echo '<tr class=esta><td class=lab>'.__('Estado').': <td>'.$estas[$est=$vot['est']].'<td style="height: 5em;" rowspan=5><iframe name=acta'.$idE.' style="height: 100%; width: 100%; border: 0px; " frameborder="0"></iframe>';
    if ($pnEl)
      echo '<tr class=part><td class=lab>'.__('Su participación').': <td>'.(($vot['acude']) ? __('Ha participado') :
	    (($est < 2) ? __('Todavía no puede participar') : (($est == 2) ? '<b>'.__('Todavía no ha participado').'</b>' : __('No ha participado'))));
    foreach(array('ini'=> __('Inicio'),'now'=>__('Hora&nbsp;actual'),'fin'=>__('Fin')) as $q=>$tx)
      echo "<tr class=$q><td class=lab>$tx: <td>".strftime(__("%d/%b/%Y %H:%M"),$vot[$q]);
    if ($vot['fin']-300 < $now and $now < $vot['fin'] and !$vot['acude'])
      echo '&nbsp;&nbsp;<marquee class=marquee width=50%><font color=red>'.__('Quedan menos de 5 minutos para el cierre').'</font></marquee>';
    if ($est > 1) {
      $ini=max($vot['ini'],$vot['cons']);
      if (($tiem=$vot['fin']-$ini) > 8*3600)
	$tiem=$ini+2*3600;
      else
	$tiem=$ini+floor($tiem/4);
      echo "<tr class=tpart><td class=lab>".__('Participación hasta el momento').': <td>';
      if ($tiem < $now) {
	list($sPart)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE and acude = 1"));
	list($sPop)=mysql_fetch_row(mysql_query("select count(partElec) from eVotPart where elecPart = $idE"));
	// muestra sólo si han votado más de 10 y si la participación es mayor del 2%
	if ($sPart > 10 and $sPart > 0.02*$sPop) {
	  if ($vot['abie'])
	    echo $sPart;
	  else
	    echo floor(100*$sPart/$sPop).'%';
	}
	else
	  echo __('Datos no disponibles');
      }
      else
	echo strftime(__('Datos disponibles el %d de %B a las %H:%M'),$tiem);
    }
    $idM=$vot['idM'];
    $q=mysql_query("select * from eVotMiem,eVotPob where miembMes = idP and mesMiemb = $idM order by carg");
    $dis=true; $rows=mysql_num_rows($q)+1;
    while ($mi=mysql_fetch_assoc($q)) {
      echo "<tr class=miemb><td class=lab>".(($dis) ? __('Miembros de la mesa').': ' : '').$vcgs[$mi['carg']].': <td'.
		(($im=$mi['imgM']) ? " onmouseover=\"ponim($im,$idE)\">" : '>').
		(($co=$mi['correo']) ? "<a href=\"?comu=$idM&el=$idE&mi={$mi['idP']}\" target=acta$idE>" : '').$mi['nom'].(($co) ? '</a>' : '').
		(($dis) ? "<td rowspan=$rows><img id=imgM$idE".' alt="" style="width:0px">' : '');
      $dis=false;
    }
    if ($est > 0 and ($vot['censoP'] or $pnEl)) {
      echo '<tr class=vercp><td class=lab>';
      if ($vot['censoP'])
	echo "<a target=acta$idE href=\"?vRoll=$idE&fr=1\">".__('Ver el censo').'</a>';
      if ($pnEl)
	echo "<td><a target=acta$idE href=\"?vBallot=$idE&fr=1\">".__('Ver la papeleta').'</a>';
    }
    echo "<tr class=comm><td class=lab><td><a href=\"?comu=$idM&el=$idE\" target=acta$idE>".__('Comunicar con los miembros de la mesa').
	'</a></table></div><script>function ponim(i,e) { with(document.getElementById("imgM"+e)) {style.width=""; src="?getim="+i}}</script>';
  }
  // }}}

  function dispElec($vot,$scri=false) { // {{{
    global $now, $enom;
    if ($scri)
      echo '<div id=pape>';
    $idE=$vot['idE'];
    $n=$vot['nomElec'];
    if ($n == '-')
     $n='';
    echo "<table class=tpape><tr><td valign=top id=ctele><form name=\"$enom\"><input type=hidden name=E value=\"".enti($n)."\"><h4 class=telec>$n</h4>";
    $iv=0;  $algbla=false; $algvinc=false; $excl=array();
    $qV=mysql_query("select * from eVotVots where elecVot = $idE order by posV"); $mxMins=0;
    while ($vo=mysql_fetch_assoc($qV)) {
      $idV=$vo['idV']; $iv++;
      $nulo=$vo['nulo']; $nps='';
      $qL=mysql_query("select * from eVotOpcs where votOpc = $idV order by posO");
      $mxOp=mysql_num_rows($qL);
      $minOps=min($vo['minOps'],$mxOp); $mxMins=max($mxMins,$minOps);
      $maxOps=min($vo['maxOps'],$mxOp);
      if ($maxOps < 2 and $maxOps < $mxOp+$nulo) {
	$tip='radio'; $g=''; $jsmx='';
	if ($minOps > 0 and $vot['ayupap'])
	  $nps='<p>'.__('Debe marcar una opción');
	$algbla=true;
      }
      else {
        if ($vot['ayupap'])
	  if ($minOps == $maxOps) // and $minOps > 1
	    $nps='<p>'.sprintf(__('Debe elegir %d opciones'),$minOps);
	  else if ($minOps >= 1)
	    $nps='<p>'.sprintf(__('Puede elegir de %d a %d opciones'),$minOps,$maxOps);
	  else if ($maxOps < $mxOp)
	    $nps='<p>'.sprintf(__('Puede elegir hasta %d opciones'),$maxOps);
	  else if ($mxOp > 1)
	    $nps='<p>'.__('Puede elegir las opciones que desee');
	$tip='checkbox';
	if ($scri) {
	  echo "<script>function mxctrl(t) { if (t.checked) { p=document.getElementsByName(t.name); var c=0; for (var i=0; i<p.length; i++) if (p[i].checked) c++; if (c > $maxOps) t.checked=false; } } </script>";
	  $jsmx=' onclick="mxctrl(this)"';
	}
	if ($nulo)
	  $g='g';
      }
      $n=$vo['nomVot'];
      echo "<input type=hidden name=V$iv value=\"".enti($n).'">';
      if ($n == '-')
	$n='';
      echo "<h4 class=nomVot>$n$nps</h4><blockquote class=blvot>";
      $tdPL=array();
      $qP=mysql_query("select * from eVotPreLd where votPre = $idV order by nomPL");
      if ($vinc=mysql_num_rows($qP)) {
	$algvinc=true;
	echo '<blockquote class=blpre>'.__('Puede seleccionar alguna de las papeletas pre-marcadas').':<ul>';
	if (!function_exists('egBtn')) {
	  function egBtn($idV,$idPL,$scri) {
	    $disa=($scri) ? '' : 'disabled';
	    return " <input name=\"preL[$idV][$idPL]\" type=button $disa value=\"".__('Elegir')."\" onclick=\"return selePL($idV,$idPL);\">";
	  }
	  if ($scri)
	    echo '<script language="JavaScript">
		  function selePL(iv,il) {
		    for (ii in clean[iv])
		      document.getElementById("O"+ii).checked=false;
		    for (ii in setPL[iv][il])
		      document.getElementById("O"+ii).checked=true;
		    return false;
		  }
		  clean=new Array();
		  setPL=new Array();
		</script>';
	}
	while ($preL=mysql_fetch_assoc($qP)) {
	  $idPL=$preL['idPL'];
	  $tdPL[$idPL]=unserialize($preL['preVot']);
	  echo '<li>'.$preL['nomPL'].egBtn($idV,$idPL,$scri);
	  $excl[]="preL[$idV][$idPL]";
	}
	$excl[]="preL[$idV][0]";
	echo '<li class=papori>'.__('Papeleta original').egBtn($idV,0,$scri);
	echo '</ul></blockquote>';
      }
      if ($g)
	echo "<table border=0 class=tpart><tr><td><input id=gO$iv class=vtgO name=gO$iv type=radio value=\"\"><td>".__('Participa').'</table><blockquote class=blcan>';
      $opcis=$opPL=$rnl=array(); $ase=$ptd='';
      while ($lis=mysql_fetch_assoc($qL)) {
	$im=$lis['imgS']; $idO=$lis['idO']; $opPL[$idO]=0;
	if ($se=$lis['sepa']) {
	  if ($ptd) {
	    $irnl=mt_rand();
	    while ($rnl[$irnl]) $irnl=mt_rand();
	    $rnl[$irnl]=array(preg_replace('/[^a-zA-Z0-9]/','',$ase),$ptd);
	    $ptd='';
	  }
	  $ase=$se;
	}
	if ($se or ($im > 1)) {
	  if ($se == '-')
	    $se = '';
	  $ptd.="<table class=tsep><tr><td><label for=gO$iv>".(($im) ? '<img class=imgvtsep alt="['.sprintf(__('Imagen del separador %s'),$se)."]\" align=absmiddle src=\"?getim=$im\"> ":'')."<b>$se</b></label></table>";
	}
	$htop="<table class=tcan><tr class=trcan><td class=plab><label for=gO$iv><input class=vtO id=O$idO name=O$iv value=\"%%%;%%%\" type=$tip$jsmx></label>";
	$im=$lis['imgO'];
	$n=$lis['nomOpc'];
	if ($n == '-')
	  $n='';
	if ($n !== '' or $im > 1)
	  $htop.="<td><label for=O$idO>".(($im) ? '<img class=imgvtO alt="['.sprintf(__('Imagen de la opción %s'),$n).
		"]\" align=absmiddle src=\"?getim=$im\"> ":'')."<b>$n</b></label><tr><td>";
	$qC=mysql_query("select * from eVotCan,eVotPob where canOpc = idP and opcCan = $idO order by posC"); $cc=mysql_num_rows($qC);
	while ($cn=mysql_fetch_assoc($qC)) {
	  if ($htop) {
	    if ($n !== '')
	      $n.="\n";
	    $n.=$cn['nom'];
	    if ($cc > 1)
	      $n.="\n ".__('y otros candidatos/as');
	    $ptd.=str_replace('%%%;%%%',enti($n),$htop);
	    $htop='';
	  }
	  $nc=$cn['nom'];
	  $im=($im=$cn['imgC']) ? ' <img alt="['.sprintf(__('Imagen del candidato/a %s'),$nc)."]\" class=imgvtcan align=absmiddle src=\"?getim=$im\"> ":'';
	  $ptd.="<td class=dcan><label for=O$idO>$nc$im</label><tr><td>";
	}
	if ($htop)
	  $ptd.=str_replace('%%%;%%%',enti($n),$htop);
	if ($opcis[$n])
	  $ptd.='<h1 class=perr>'.__('Papeleta errónea, hay opciones iguales').'</h1>';
	$opcis[$n]=true;
	$qS=mysql_query("select * from eVotSup,eVotPob where supOpc = idP and opcSup =$idO order by posS");
	if (mysql_num_rows($qS)) {
	  $ptd.='<td class=dsup>'.(($n)?'':'<br>').'<span class=lssup>'.__('Suplentes').'</span><tr><td>';
	  while ($cn=mysql_fetch_assoc($qS))
	    $ptd.="<td class=lsup>{$cn['nom']}<tr><td>";
	}
	$ptd.='</table>';
	if (($n and $cc >0) or $cc>1)
	  $ptd.='<p class=sepp>';
      }
      if ($ptd) {
	$irnl=mt_rand();
	while ($rnl[$irnl]) $irnl=mt_rand();
	$rnl[$irnl]=array($ase,$ptd);
      }
      if (true) { // poner opcion de si se quiere random
	ksort($rnl);
      }
      if ($crnl=count($rnl)) { // if opciontabla
	echo '<table class="tseps"><tr>';
	foreach($rnl as $ptd)
	  echo '<td width="',round(100/$crnl),"%\" class=\"tdsep\" id=\"tdsep{$ptd[0]}\">{$ptd[1]}</td>";
	echo '</tr></table>';
      }
      else
	echo $rnl[0][1];
      if ($g)
        echo '</blockquote>';
/*      if ($iv > 1) {
        echo "<table border=0><td><input id={$g}elect_a_$idV name={$g}elect_$idV type=radio value=\"----".__('Abstención')."\" checked> <td><label for={$g}elect_a_$idV>".
		__('Abstención').'</label></table>';
      }*/
      if ($tip == 'radio' and $minOps < 1)
        echo "<table class=tbla><tr><td><input id={$g}B$iv class=vt{$g}O name={$g}O$iv type=radio value=\"_".__('Blanco').
		"_\" checked> <td><label for={$g}B$iv>".__('Vota en blanco').'</label></table>';
      if ($nulo) {
        $algnul=true;
	echo "<table class=tnull><tr><td><input id={$g}N$iv class=vt{$g}O name={$g}O$iv type=radio value=\"*".__('Nulo')."*\"> <td><label for={$g}N$iv>".
		__('Emite voto nulo, con el texto').":</label> <input name=NT$iv></table>";
      }
      echo '</blockquote>';
      if ($vinc and $scri) {
	echo "<script language=\"JavaScript\">clean[$idV]=";
	$sClean='';
	foreach($opPL as $ii => $v)
	  $sClean.=",$ii:0";
	echo '{'.substr($sClean,1).'}; ';
	echo "setPL[$idV]=new Array(); ";
	foreach($tdPL as $ii => $v) {
	  $sPL='';
	  foreach($v as $oo => $vv)
	    $sPL.=",$oo:1";
	  echo "setPL[$idV][$ii]={".substr($sPL,1).'}; ';
	}
	echo '</script>';
      }
    }
    echo '<div class=dpie>'.$vot['pie'],'</div><td id=vtayu>';
    if ($vot['ayupap']) {
      echo __('Este sistema le permite participar en procesos electorales por medios electrónicos con garantías de anonimato e irrastreabilidad.'),'<p>';
      if ($iv > 1)
	echo sprintf(__('Esta papeleta contiene %d votaciones distintas, por lo que no puede abstenerse en una votación individual, es decir, si decide participar, lo hará en todas las votaciones.'),$iv),'<p>';
      if ($algnul)
	echo __('Una papeleta se considera nula tanto si marca la opción nulo, como si escribe texo nulo en la casilla correspondiente.'),'<p>';
      if ($algbla)
	echo __('Una papeleta se considera en blanco si no tiene ninguna opción marcada o tiene marcada la opción \'Blanco\'.'),'<p>';
      else if ($mxMins == 0)
	echo __('Una papeleta se considera en blanco si no tiene ninguna opción marcada'),'<p>';
      echo __('Una vez haya votado pulse \'Continuar\' por si hubiera más elecciones en las que participar. Si decide abstenerse en esta elección, pulse \'Abstenerse\' por si hubiera más elecciones.'),'<p>';
      echo __('Cualquier manipulación de la papeleta supondrá un voto nulo que quedará registrado como incidencia (siempre anónima).'),'<p>';
      echo __('Recuerde pulsar \'Salir\' cuando haya terminado.'),'<p>';
    }
    echo '</table>';
    if ($scri)
      echo '</div>';
    return $excl;
  } // }}}

  function enviMail($o,$ma,$m,$s,$as) { // {{{
    if (!$ma or !$m)
      return;
    list($cab,$cue)=explode("\n\n",$m,2);
    if ($s)
      $s.="\n";
    $cab=" $s$cab\nFrom: $o";
    if (ini_get("mail.add_x_header")) {
      $cab="Subject:\n$cab";
      $su=$as;
    }
    else
      $su='';
    if (!is_array($ma))
      mail($ma,$su,$cue,$cab);
    else {
      $d=implode("\nBcc: ",$ma);
      mail('',$su,$cue,"$cab\nBcc: $d\n");
    }
   } // }}}

  function enviAct($ma,$ac) { // {{{
    global $iAm;
    list($cab,$cue)=explode("\n\n",$ac,2);
    if (ini_get("mail.add_x_header")) {
      $subj=__('Acta');
      $cab="Subject:\n$cab";
    }
    else
      $subj='';
    if (!preg_match('/^From: /m',$cab)) {
      $org=dirmail('',$iAm);
      $cab="$cab\nFrom: $org";
    }
    if (!is_array($ma))
      $ma=array($ma);
    foreach($ma as $m)
      if ($m)
	mail($m,$subj,$cue,$cab);
  } // }}}

  function envSMS($u,$i,$m) { // {{{
    global $pasSMS;
    if (!$u)
      list($u)=mysql_fetch_row(mysql_query("select usu from eVotPob where idP = $i"));
    return pillaURL("$pasSMS?us=$u&txt=".urlencode($m));
  } // }}}

  function haz_alter($html) { // {{{
    global $hst,$escr;
    $txt=strip_tags(str_replace('<br>','\n',$html));
    $html=preg_replace('%\[(.*?)\]\[(.*?)\]%',"<a href=\"\\2\">\\1</a>",$html);
    $txt=preg_replace('%\[(.*?)\]\[(.*?)\]%',"\\1 (\\2)",$txt);
    $html=preg_replace('%\[(.*?)\]%',"<a href=\"$hst$escr\">\\1</a>",$html);
    $txt=preg_replace('%\[(.*?)\]%',"\\1 ($hst$escr)",$txt);
    $bou=md5(uniqid('',true));
    return "MIME-Version: 1.0\nContent-type: multipart/alternative; boundary=$bou\n\n--$bou\nContent-type: text/plain; charset=\"UTF-8\"\nContent-transfer-encoding: base64\n\n".
		chunk_split(base64_encode($txt),76,"\n")."\n--$bou\nContent-Type: text/html; charset=\"UTF-8\"\nContent-transfer-encoding: base64\n\n".
		chunk_split(base64_encode('<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"><HTML><HEAD><META http-equiv="Content-Type" content="text/html; charset=UTF-8"></HEAD><BODY>'.$html.'</BODY></HTML>'),76,"\n")."\n--$bou--\n";
  } // }}}

  function haz_related($html,$des='') { // {{{
    global $tips;
    $bou=md5(uniqid('',true));
    $cab="MIME-Version: 1.0\nContent-type: multipart/related; boundary=$bou";
    preg_match_all('/<img[^>]*src="\?getim=([0-9]+)"/',$html,$mat);
    $nimgs=array_unique($mat[1]); 
    $mimeim='';
    foreach($nimgs as $nim) {
      $html=preg_replace("/(<img[^>]*src=\")\?getim=$nim\"/","\\1cid:$bou-$nim\"",$html);
      list($laim,$tip)=@mysql_fetch_row(mysql_query("select img,tipo from eVotImgs where idI = $nim"));
      $mimeim.="--$bou\nContent-type: image/{$tips[$tip]}\nContent-transfer-encoding: base64\nContent-ID: <$bou-$nim>\n\n".
		chunk_split(base64_encode($laim),76,"\n")."\n";
    }
    $des=($des) ? "\nContent-Description: $des" : '';
    return "$cab\n\n--$bou\nContent-type: text/html; charset=\"UTF-8\"\nContent-transfer-encoding: base64$des\n\n".chunk_split(base64_encode($html),76,"\n").
 			"\n$mimeim--$bou--";
  } // }}}
  
  function dirmail($us=array(),$idP=0) { // {{{
    global $domdef;
    if (!$us) {
      if (!$idP)
	return '';
      $us=mysql_fetch_assoc(mysql_query("select * from eVotPob where idP = $idP"));
    }
    $ma=$us['correo'];
    if ($ma === '')
      return '';
    list($u,$d)=explode('@',$ma);
    if (!$u)
      $u=$us['us'];
    if (!$d)
      $d=$domdef;
    $us=str_replace(',',' ',$us['nom']);
    return "$us <$u@$d>";
  } // }}}

  function dirAdmos($a) { // {{{
    if ($a)
      return array(dirmail('',$a));
    $m=array();
    $q=mysql_query("select us,nom,correo from eVotPob where rol = 2"); 
    while ($us=mysql_fetch_assoc($q))
      $m[dirmail($us)]=true;
    unset($m['']);
    return array_keys($m);
  } // }}}

  function auth($idM,$presi=false,$xml=false) { // {{{
    global $authLv, $iAm, $swrkf;
    if (!mysql_num_rows(mysql_query("select * from eVotMes,eVotMiem where mesMiemb = idM and idM = '$idM' and miembMes = $iAm and ((est < 2) or ((est > 1) and pres))".(($presi) ? "and substr(carg,1,1) = 'p'" : ''))))
      if ($xml) die('<error>auth</error>');
      else die(__('No autorizado.'));
  } // }}}

  function bckup($inm=false) { // {{{
    //if (mysql_num_rows(mysql_query("select * from eVotMes where est = 2")))
    //  return;
    $d=time();
    if (!$inm)
      $d+=600; // 10 mins
    mysql_query("update eVotDat set backup = $d where backup >= 0");
  } // }}}

  function lee_f_h($nom,$fec,$min,$max) { // {{{
    $di=strftime("%d",$fec);
    $sel="<select name=\"d_$nom\">";
    for ($i=1; $i < 32; $i++) {
      $d=sprintf("%02d",$i);
      if ($d == $di)
	$sel.="<option selected>$d";
      else
	$sel.="<option>$d";
    }
    $sel.="</select>";
    $mi=strftime("%m",$fec);
    $sel.="<select name=\"m_$nom\">";
    for ($m=1; $m < 13; $m++) {
      $mm=strftime("%b",strtotime("Jan 1 +".($m-1)." month"));
      if ($m == $mi)
	$sel.="<option selected value=$m>$mm";
      else
	$sel.="<option value=$m>$mm";
    }
    $sel.="</select>";
    if (!$fec)
      $ai=$min;
    else if ($fec < 3000)
      $ai=$fec;
    else
      $ai=strftime("%Y",$fec);
    if (($min == $max) or (($ai < $min) and ($ai > $max)))
      $sel.=$sel."<input size=4 name=\"a_$nom\" value=\"$ai\">";
    else {
      $s='';
      for($i= $min; $i <= $max; $i++)
	if ($i == $ai)
	  $s.='<option selected>'.$i;
	else
	  $s.='<option>'.$i;
      $sel.="<select name=\"a_$nom\">$s</select>";
    }
    $hi=strftime("%H",$fec);
    $sel.="<select name=\"h_$nom\">";
    for($h=0; $h<24; $h++)
      if ($h == $hi)
	$sel.="<option selected>$h";
      else
	$sel.="<option>$h";
    $sel.="</select>";
    $ii=strftime("%M",$fec);
    $sel.="<select name=\"i_$nom\">";
    for($i=0; $i<60; $i++)
      if ($i == $ii)
	$sel.="<option selected>$i";
      else
	$sel.="<option>$i";
    $sel.="</select>";
    return $sel;
  } // }}}
  // }}}

  // mmGetText {{{

  /* mmGetText start */
  
  function mmIniStr($my) {
    global $lang_lang, $myLang;
    // use mmGettext.php to obtain an editable version
    $lang_lang=unserialize(gzinflate(base64_decode(
      '3b3bbh1XkiZ8PX6KtAE2XQAlcfNM2aVqWpLb6rEObcouGD2NQXLvRe6Ucmdu54EUPfADzCvMlX3V'.
      'VRdGY6ouBig0MEDxxSa+iFinzJWkXGX8Fz/QXaZ2rhUr1jlWHL7IH+7P9h7+j/bh7vHDj7KP171Z'.
      'mKw1TVbVzSovtzLTrk2Tr+o266s8W9ZN/puPPskf7qDOzsOP5vlHn1DlPa5cd+OqZkUVbT2uYir8'.
      'sb+LKt2yaDP6v7J4a8rrrKuzZb5em2oruzLZVVGW2VVedNl53WQ5qPQNUfmBGtym2nnbr0xmyqyp'.
      'y4zYXjemLRam6syDPEswucN1UKl4l6rGtQIWdw5dI93ScPH6PJsv84L6V2XMCEZtXlfZkxfPEk3i'.
      'a746068BaXy4Krpl9uyJ0DnYFkLzsr/5eVGDvcXNz3m2sQCLG5/x/36b5VmZt9nGFzyg9MfzbFVU'.
      'fVe347b3D4jieVHlZdF9n3egOCZmLDH6o3Dk2ngYjhxrC7PIiBRRIFJEYeOLhxvPmf99KrOmWUrw'.
      'gS+mifuP9XJ2LV2fbaPvrcnmhWka9DBbmTYnJkuam3puWgyHmXfU5TIrqmJe5H/DCGXXifnBDFPX'.
      'u7yajxu++WM7apjHcVHYZicH0w1lVsQTj1lZ0rag3tMSX5h5mTeyvuZl3fb0N60x/HNdl2VRXWRt'.
      'l3dFjcVfLvBvfGOu6McWX5uOZoUKECv4trHgUd05lkEtqnnd0Mzkme/gvF7ViZniiW43J2pkebwq'.
      'MGlv6oJ4QKtndd7Q2mjdrthYPLDLI7Ergq/xrgg+EJ0j/mHj7MHGt2My0ceACn4/kwUq62vPF5xi'.
      'KVUmIMmfz0aLfocKbLRY3W1d5VgsBU16vsgT2zEqa3xZE2+22aEWq9cllkdpaHblyGMCJ/Oupx39'.
      'fd5k11mblzT9VHxumjnWbfrQc7U6VCt8NVrka64Vziu62n69XuSdoTN3kb3pV2sqW5m8CTr9xLTz'.
      'vLlgMrQj5qZq60Snd33ZxkSlR0cMlauvqrLOFxutboB1X5a8+LnhQx6apzJuTTju3/XEKndxhdOf'.
      'LiDa1N3NTxW3hPnITJVVtHtwh2HzzIubP1djfg+3k02YYRPaQm4bMNzAPF874vFdJ93jyfSTO+9p'.
      'TKqOrr2KLk5T0T3T5NjLRUUDf+02uewoHsnPcfM0fOE8bq7XXX2yJkod0ayzjfbcf6VBrvJLGvFF'.
      'rWNOzGOF4GvbFV3PI4AfdIsn9sT2LGgT19h0m/g6aLPcTDUZtOjP1ngHbB+g2dPiopIrcthqQ822'.
      '7isfPk19RYKHrpvG0Pm1yM4bOrPCg3Rdtx0OslXRGWKqMX5pHe3/PaOLCwd9bbmztNxuW2JHe3/X'.
      'oBpuyoybio/Aw19jCFsZQ3NpmsFqxHn4cSh+JWRCnGQfD8StWASc7TsqKl+JcDejBbAlu62ii37i'.
      'tpodoZTbl3JFxVLGbEcJYfrt3QSpbosuWxpVDOKqrgpahHSiyo5IHGL7WqEPy3dSIW6PGbclqM23'.
      '5lqkI/7AJwZ1KLhUSd6mH1lyots/oznpCxxhLUkPZkWT0j4cM7R37Kh1EbGaaZmSaqMyUWnNxc1/'.
      'EkGQCdcHD8yZsfLExBZhknQgkayCUudUqr6SckH5+vy8oAsITWDydkF6SUfjZd1BTkvM3E5YpBvM'.
      'mdan2aGv1DhT3ePJptO4zj49e5T3LZ/zJJXlZ03RYBD6pso/fXD2iOborKBmUy8AUCEaN39iImcg'.
      'wlXo7K6FzmZA5qLvhgtqn5bCGf3sqmeLvrGDeJbT8HQkCb3LanrC0M9CiFZoV6uoyzNH/ar5wlC2'.
      'U0N0qAWl3KYWG1yZW9pmiytjwIKca1T80+Xeo5O+I2aLua7x09cvv/qvnz6gD6dyfNAVhx26zm9+'.
      'lqtuSQcLLQIMZNtn/Doqzm39xKF2kGgn2UyfaOfmDzhDqbdtR0Jn3Fi8bLUZJpzlPXUZjeFY4mZe'.
      'lSZv8XzFWSUydd1XHZ1eV8tivqSHZkvv2+yanpFBM+5U28M9Dfqf1Z1ejqa6vPm5ZuJPq+zT87rC'.
      '/ijr5rcfnZX5/O1Hjypz0VABfHn0MDOnfXNprkX8yKg7Z/kb7Hldu/K8JqJF3nx61oxoXjSGevqI'.
      'DtyFcTS/zaN6GKp1voYwkdOBgecLHdZ0Ynd5iuT8OieK+N8JJun5u84bPphoarTDCUKr/IJGLP/o'.
      'kf7hyNFmeMpKAiWxbgqSZNzQnT1KUVvkzVu6+qsLQ0OI5t94gq9rInSZZ2cFFAGiRUjROCt7qp1/'.
      '35eu6ivTnEOoQPHE/o8mOLNDuuJz4PYpNqnRy2mGDfYcHcQ8w3SyrFmWe48JdgT/OQ8q2dltdHbx'.
      'Bv07pvdHN710U2z63v5t89vF02tH7u4ZpudGHc9wxxN880c7v/30BNMs9MMJNjLBoUbhUOf21NCj'.
      '5bO+6/RQeJaeVP7PaMyKNruqm7d0dtPZSgc9HRX0xIYeak7XFZ34CzQ8JKmzyv9xJFHVVgoP56q+'.
      '2hI1FC4OlDovqqJd0sF0Xsi1WnSpVm6Z6qLVeUZtejQWENlSNG6b5BOo2kCAxE+61h0Znd8hqXB+'.
      '5b+O2FPU65bclTa7qFX8Mu/WmLrFFiv1UjTthPdmOOEy36rX8HdABfGwOiexqSFZg+c7rddIV+m0'.
      'RrCOoFmUO0tLd664WWhxPEYffnRC51PTJR5OdEu9PJNPscrr5dpUTkg6CSWXtJD0MhBKYiHpWIgN'.
      'Ln2hPQPtli7iict6th0WGLy97Ccv6rufSMRLKBh8c0Vzr411CYfyKS+EFI3LCWsqkrqcx83NHxbF'.
      'QPe4Dwp138n9jPqpAXcfgprU2Ff8inHKk5Nf/ALenaVrRZXCKXaN/qLX5/5tzMUv5WxOf541ePht'.
      'pHS+e3cyPEkrHLvtX9oPSwsCO4hhowaDVwZP4pS0exwU3bQlB/LuruNJFaT2RSqi7u7BRHMbreiu'.
      'C/QzNWi7u8nWtV7darXwjDic5GXDK8o3dCBmdnr5Wb+Y2OtxicGDSBvDk121gW7IoImqqNEOE3k/'.
      'QXvfF+ya+mxE3q9ZnHXnJDBLC8cHyRYyKtxDPmX53as+vM5tUbRregKfQVexzCEloSR9H6n4E+we'.
      'b4/Y5SaJP3o7cJNOBeKUcGGL59BIa4NDzf790Wti2HO0hbczCTjdkp6mVhGSQ1OX5Zd5UebUTEav'.
      'iqJM7AtaLvQPpyM54aHRWU0sPS1jbJmhMnjPctiGc7+zbSlDbyDKoofJ80BLGlZkRiUHl4lthR6q'.
      'aOih3cSyBorL9C1nP8XHLv9qwmOXCi3yLaL5TV1espIJIqnyM7khXa3XdeO0sZmvFh4Ox7YGixcb'.
      '7Vemo0tzw3VIZmTflmpu0XqmCg1GyzbFC0DUH3JB7Y3qZn1r30WsTqlYcbFg5UZCYb63O6ZgVmsr'.
      'ezsSSmF0+yQ4Iw6shoJq4E9HxV/wzqowccF7+8FwtsVS4CwDgX2C+G3r8+6K9k5aqRZaJcTkdtHk'.
      'NLWxxQwTcqp0st63phNhW6vXrF9IbTIa0yc0kLZMOyKv1o7WdBif4NRe4JbLqr5MGVh54BYr06HA'.
      '2IpDgivVxreSNVmtP1Vhdn5D/PQVnTxQ1EHJQw8SOmXp2UGvvbyhhzkNSX32xtAKvs5ev3zy8pRV'.
      'hDjaFqahWWbx4OaP5f3sr//3KT/lW0NSav27xKlKrf5LzzWKd3SOSsOu1a2s3TQtN0w3IBqlMyMr'.
      'qNXXpxnUia5RqrHYzL+D1vJ+9oIqdUSNm/3dQJCkrfD7JXRXJr9k+Z+beptV9GjcEtM+HXd0xItu'.
      'URplg9PJl18GP7VyEEvrdEiv6HV0PzuhMeO3GUnlvxOBHMu0uvlzZ2jfsJaQLoB1vcBIXvKxQywY'.
      'XGINXjT3s0/zbNmY899+REfdo8d0vRVVj2954gWBt+UX1FPqO10VeXNv0AZ96viQ+gVtRKNFzH9L'.
      '3Vn1dIlcNVh0tHQW9dXZVlbTWDRXBV2e1B76fLWJF9OZyfgmouVR1hdsM7ogQXu6XSPN/iCr82Rt'.
      '6N5a1O1W9oKXYFoqeVxf0EKRQiOp5BTvEszmC/pfa68lwg2dvWkZn59F/DF+JbwUfal/v9CgGrzo'.
      'HkxJS1KgezASZ/jKhEsHnrfuIuKL0BOldbMucRJPXJkBdVs0vm9w0Jedof53sJaM2sMuxws/cZ5i'.
      '8Fv9Nrg42VjinwRciEWs876S023k5nIda8ATT4Jt1x6LTkoqpkSEikgFHj/CLIm0Hwz2bD3xGMVr'.
      '+sQ+RR9ms+3tDRXM1k2/mJiBY1/HV4EiTOuM9OC/zxssHy1ctCzPucKqBw/YgFHt5i8raGT1Jm6t'.
      'ursV/UBBReUNxf4eMlRimPF6+8TcHoasoxk53qUVNGLauIninTXz+UYCnf/IauO6+rxoV3k3X9JB'.
      '0F0ZHf2qZ9EVs0OCt1w7PD/WTiAm7PIaXjzitvHOOmyc9PT6xpGSdNgIvsYOG8EHK/RGxob0fRyV'.
      'GW3gE2j2qy7UzUNcuO5Tjyd8edMPjoE9nNfl2h93qIthtZrztMmFCdlijenGZwuo4rCVAXWqoJv/'.
      'nS9Smx27+txcDPY6BmAhsvzhjqvt/Bm22NWObYI3P1eGZOBzeNR19UOS5ej+KOoPn7x49uF7HOEH'.
      'e7Z958mgxI0QLxxxS5tJTx77BywVLdSFgS6nyjCtBkpNT8jwxfAh/ni2+HB8T+DRaXsNG2DVJQU3'.
      'z70UGghZ28ILVnnjniufsRiVXCb8aahewo9v3cXzGQtfuFEnBMmnIibZIiE7M4iZcPHQb3rtBCRp'.
      'K3bFRZ8SJlEyos1l52NZVZuoy4Vvhvh6fHqaeEjp7/HS459k3T6ms6dICf38jQ0Sw0vqeb0ozsWq'.
      'DQs8U3DWzIknlaUWFwu5orF7Da+4DPcp3SzVhXFGzeCBhTEmSouC5PW0bLDtCzyI2zj2X4w98x7D'.
      'halKG6mZEnstVQMTNXX7yzpnZzynzWVKDQ7x35uz9KtSqflCA3EKNEXfdoWvunw8YRLa82a+LC4T'.
      'q3t2HNLf5KLvin50fPk2zgs9soWziwRRTNvNj7A9DRfBSz8lqJ52/tqTL6M9+wp+Xf5kx6uRKbyP'.
      'ovBIysaqutEeearauM0WwkrpbiZpZn3zl7OySJ0RM2XFFhm/6Xr8LJ5pgWMaajVNUrVH315DBTW4'.
      'n2gMH5fwrQh4k60/uYn2lNKEWsJSHG4ZXkMkdbOpe1Gzc+urp68SpwWvIVuyCwoOmsGP8DjUgqrp'.
      'mcXNsIJHTZr5VItRpU7VO8NK4TER9qXjt88Znu20QelPKW73I4nNXGxid++ERcb7+7RuOr+/94PC'.
      'zYSb87DQ0ONZiTqvZzwhHk84IaUdKR+/jwfSHk7okf+RjAh7FtGtMYfHXXpEUMSWCMnu4OiYw2bA'.
      'RdyyL+tqatm7b6Nl73TYtlQDPW7Tz9Pvxoligz3PdDP7PbgupGZXL1IbftcWuLesqUz8tDi2VHM9'.
      'Q3gWahi9IYRldSYyPP1Pgu2osC178wcpHD5gtrkcu5XSyrIkdVsd8se+4kWF5wh0QNY37HbjVVRV'.
      'HhneMUxqdjmdY7HgjCGriWd1oBl6oauzl/h7ywXA/FfZuaF7+++IV4BX2wlxSfezkPnlgQrEyRMx'.
      'QY0DFHgVwZDbrOj92TS0zczUYpNihov9qRrOFy22Z2ITbqCMwnuTCtI6qfvWakFAgqThhEhO9J9s'.
      '5mKYjJUgz7IcHgRONrHqouR7LPgaHzJW2+M3AFtuWkPidlq5awtU1/mQ2Ku8ba+sDXXnKCKmARHw'.
      'jFj08+QpENYg6okaA53K03fromEPaHqM53AUC9vfidpviQyk10lve98yXKRYmk152z9maXPh2tKX'.
      'xB4TuDTVokGUCTSgZkVvHtxrfeXvP3ZQhQmqsWIL3IrurfIiccgeCFuXBVEthOg5nF8QNnVZNBHh'.
      'jvdsvmjMzb/nJNNZmoPX2LMuu6p7eg2cQdNvzvsSdyFYremVH97T4uwrZIguEW6D9couRokj0n8c'.
      'xAmQFPhf7aOLS6QlyBPpwPDZZZ5zZ7R6Y5LrJ/gUbxX8auMiZjA0P+7z8ru+oINplVcFpLPQuu/d'.
      '5fp1XbFKuGfn05p1+zwP9P8LVruTDF3AEdF6HvszPvu4LWCMQVwEES9W+W9SBlcsqn8hflpzWZcR'.
      'PwE7jWWnpUZ/VHbATcjMj46ZTt2bg0uEuHHM/ImZGUjaeKpX11YjZ/ngU7yg5VFANeTME6JlZ7U8'.
      'HfXX2rDBZoSJt7LD0GUf5+VVfo3f6up6RWfeb+wb9MmLZ8k3KP8eSwFfs2ZAjGYzPrVxmwVm3DBa'.
      'zV4iycgdqY4IjET1TKubNhHUAz3jE1w23qzrY9t8jM+2Za+qwybST3jhZFgynJYjbRQqStewbEO2'.
      'U9E2dtr73+Wrbvlb6PBzqy9rWtbjW82k6oMyDhzw9T56JCaPtDXjaE+sGYl2Fpu+pXuXdctt4Rwq'.
      'N6WpcUti+BjZNI5Dk0a6R1bHJz1yoQhWfZRJpELYVsNmXWfI2LEjRrsbWqKNxS1mQBRmGw69Gxq8'.
      'MFzpcSwSGG+XfKyqMzEX7qQwFu22trzMoXCl7TvQyrc3f6aDpa+SWoo9+uuLAs7Pi014uscEWBlf'.
      '1StovPtqoMWAbfw5hpTahmgaa+Gr8hq/xoOzyps5Gxtz7m/6fbHnBmdUfCT9uGmdL2u8OKl1GRuR'.
      'B/el3UoN9XiS1gjB8r4iunhXRUvna3CTJrR2dJZ+IZZOoXaPyUGt7f1AVIG+opVUvAtuvPjOYcNr'.
      'GYW3rHQgxbfCr8AWq2/4wj3e4X5JbAGd4rTD5/C55LPYmhG2EH4Q7mA6NrHSf9thxctjAB71eaQj'.
      'x4JO3SR8hJPo0rfWrUkbvfkxaJUaXUa7OWgT+/lCm/Uu9lHr2nh0dRzwY7W5FidYjWAQa4LvNn29'.
      'Hm/woHH6s2GHfHa4zyOlPk3fpSm1bZZUebm+4cVChy2eOSTfrUW1KLZxVSpodB5CcgpclnN391v5'.
      'ksvlzjdgK+uxQA2/3DfaBYcjcgRk6vbm5ctW8o5NNqUw4vmweooBH/BOspe+YwQlvZfDFh2dYKTn'.
      'DwNOBmfnqenw7pTAm8KU4pwjNnQIeJBsuen5W44WtCIzfRMniS0cnrpDO9wQmDl6tFn3vCP2ipg3'.
      'hZwJYpZbm7nsxZQ0fxjVGFcYCPNalmdbDHL1JR1w/jHxRGRmtmt+HJs8EvFkbHMlYXLuSjsbxm9G'.
      'bZ+IeIui1kRBz1jzG/cU5LY73coTHrgHtphBsbE9Do+MU9pPxcWSFVBD2+duohk++/gogy/cRerd'.
      'Phs3y0ec1uJK4Yt9d4oLOdDOqOPiOpg7xcjuAQ8Bv6PgNk3XL8b++f3sOb336az4h7L7xO1pPBi6'.
      '+uFq9Y9V0fb36+bio0fBP1D9Hy6o/Fnz6IP/cgqxccVnDK0qCNDWrwdaQWrkc3hv5Be0gFKNrOlp'.
      'HDQT/TNs6BldtM15/r2nnsdd+OC/fLp+ZJlZGBZXCxjRrNM8qLjWl123fvjggWn5033HQEab88J0'.
      'v/3vvPEexUN2Pexa3PjndDpUglVAHxNxfLt4ZBJJfhx3Mgvm15+FP8HVx3IqWtZfcw5ufqaFHE2D'.
      'mZyGTTsLf+ckBCNWDLqWngP+FsdA7u7zhS53P5M6u/5Vxv6k72os/L7N2mt03HIokZS/6vqfByMf'.
      '8c+9t+EhJ/xUK7prZehvGvVwpCBsRp0ajHpfLfj3h14SJVmvqPqCH+gIFlhBj5yCDJilCg+9PmCr'.
      'eGJUvKBC+YVZhQ6NT9zzK23ZC7/HGt+T6E3G7dTETCE7fGHO02oSftdxQV6FUi4mPuM78TzvS7h2'.
      'rWxUBDr8FD4U8DXiVwMaWt38nB4bW1QfCGhsVYzuv6fv5mXfFpcA1TFUQ2Zp5ZyTmEraX8F+Cq8Y'.
      '+VWDJGFfUzuAWhOya3ZWbIoLwM1kLevDoNhK2/VxYzkSSqGA46EjwKobpTAICBFLsdZSErlGWDkC'.
      'rLSH301xLkRUxtzhhm+DjaFnP1QtRPZ7enb0gurhpBQ2X4s7pIRkkqRJEm2xhoZ9PqeRNrA3EQf/'.
      'qmfev6XW35GwUUzpuZUJWAHAg/E8CAuMR0GyJnwPIUwOmcCQRCxEwj0t/5cBWgy8hdB2pw3TI7Ko'.
      'xop/Vg2xmxfAmCD401X6r65puCTgEeoiIf7NBb4/VXlYvPXPcrx0L4m1Og1JZKch8SACZtSXm0yM'.
      'aV06WregGwmpcDXvyBJi6Jzsitpr50uz6EtE4OGFMAZ6wTOUulFhQ7EwEcdTN4ZWRFOwdfVM4LNo'.
      '8vi4SIfpHHhyZRboXFiuVmod6wcS1MLdsCddQRVWnKceWe6ZS+PB3rSV8+6fCR8jXzgS3HsE7095'.
      'w1lnufSD/enY700IdlOub5viGDdSbr+OfNqYCM3+92ZhH6O1EWc/cYVzD3gJ9HbQHsQQK9gXMogi'.
      'SEv0cwvH2Wg2twShxqv3bWQLvSCwaKHMuKQTJKFXO7ylqR9hp24HSyduCzHAczxdtcUf6d8lTVpX'.
      'xJcfuoSR6Zqe4RdEZ2EFfG6fBmyeVxiZM+iIzPwt4iI4Ij4wCKinJFTs19m1sdfn0UQ3nIp8PGhB'.
      'oE8rxc1gGLeoRsVWFOw7IlIjpLhLe7Pgir6NheRg+tCfJAvdlh1ez8WPlovYUwawYKfD8eQD8K0x'.
      'awT/YORpFUoYUNG10bCS1GTjdUSBwlUbgyvfddvbd59CjStGCAAy1dWFx90KIHLGrwcchjd/ERin'.
      'ulX593ZwnV1EO7QkLWklD+4xNuzu7Ignjb37IFJcT1zpkJOe+juKitajq5vLgAh7TjkIM2vvfHoL'.
      'Zo7/OrRQPg1haVg+Kr0dDhF8NR01KWXGti+qJc3F0IsUGoCvq7dVfeXvNSdBleLWmfAzfN0k/OYY'.
      'AqPznVWksKRxN/ga272eBHhgMF885fgUZ8jaskd0Z94lZWuchQhYUVvTlj2AUT5eJzuqBEfwurUR'.
      'bfkDViqohflpBRnzlmhjX2DYIYiVzvFfSk7qY47lcyIaGsbzpPs55onDMdKSrn6KLZNP8bKyDi5P'.
      '2WqcdnBx32JJ+dQ5nbsiiQ3jPg7sQyEB9jdFIZYpk5IES7RcpMtGYbwco0ETyOFfdRDS91Q9O5Nj'.
      'MnL6FJY0jvrYFgkxxTasP0kYdZuO69PKCg62MfDkG/YAzZ1a/ATF9dpofVCyD7ttnRfamL0opjod'.
      'bxCzNagTr5D9MUu/JNib/RMZGoUFSdhD0l4oTy3ABgTEeTcZGsp71O4hEG+aOn0u6ZfBcpcfsV63'.
      '9V+MqxRoz1nENqySh99t+9+qf+mL7+kKJ2k3z3L14+4rZ41E5J+8PRILf2ZboadEpBuXZnoW2xfY'.
      'GP+tekXCI91JSwm9Eldw1w7YdM2Ex8qRi+iDX45SNlc8Q/AuIrqmWebrVkLIxM6XLxYwh1Mx2B+x'.
      'X1iqYn2JrK39YHguAIcgqww3Pz2AafWXcOdLLPu9oMfDigUqAlssfsIf2ypSXsI2UR5PXevVx/vJ'.
      'crSGpc3i04ne57RI3tW+I5iBykZg8lUQVQw3ops1tANuxJkkKv+D3jCWdoDfymAaExfSoDi0Glo8'.
      'HJFDW1K9wgWeAxXm1o8l6lhpIdGK98B52JusOAX1sOv4qStFmuI66iTnMVGdE4FvgPZRB0eSZFDp'.
      'UTQiVJIKjn2oXxcrXd3OE9/VahGgP+GTuB2V++7mPxMOiTM+8L8DjaiNXT8DiHyb8J8Oi4zIstYS'.
      'ChpPVjif8MbTjyMfPN0e3uVuhmP5KVBK54j0pTNInMNoWcPzECbXuXcdu599Cc8Xc5mHv0LQp0NN'.
      'dpyaE/xJdj97xf+GlMXxKhKwRct7YeiIEfgddtIve3bCryuxOtA7o0xZl8Dxzf/0LKuLGnEsAAlq'.
      'q517/zlhu76MfmSufwy4jliG/bF4d/Mn4vksrwKeC88zhwNTv+aiwdH41sHc0eS9QIwPm3Ktq5zT'.
      'LEjExuJ+xg92OkNdCX76nBl7jvn3hpysXKMx53VjgEeI/wqD0GJd+GGlfpVQdtOxrHeuqiMhsjCA'.
      'VFpEE2ypoTjz+1xr84nBZTLWR8NHFSgVHBbiHRbSzrVKHMqZDiHcsBMjAqNXFd340ob/OtoGHF2J'.
      'CzV3iM7qkqD2SQ406gLHNUw4Mcj6OsRC2WhQmmjaaggZEwhJi3wh2snc4fZkrEjMtS7Ow4KEBnpc'.
      '9wLUDiBqLIm24L8izeYW6C4lJL0KfDk8HynfhSPo0r9TeEvr8IZu3Pwx7ETr9bxb9v0K3SYVbVkR'.
      'IirO3CIMXYpDQNiXqCu4PeAmEfSlCDWk95bFVrasRaRg70vplPUocXwNXCIAHfkaYPX6wkBPcugb'.
      'oHW0WmYr/7VbViUtS9thgbHTlyAiccS2rbCVFSYrzqWcM9kHylUbMV87nwCN6PSboEs70Min+HWH'.
      '5yj9pmfngaw2XsF0EqyAaPyGdSv16uYn4kCCRgJb6jd4cL6mlanfP5iIPOTpz8SPCd4+bd5dWMI/'.
      'UsUEXSWLrx/EPO/qBBTsjshEctCgq5kVGk4IZwr86RvBuziVo+YDkZBnyd7+8h5CGT3Rw1/Qrf2d'.
      'oFu/tC+zXdsZPfFpCWMTsVYgsAogoFUEsQDQ3gh8zIpOWvszrmHqrDhoXTBq4M3PAmscmM+zoqFz'.
      'ko68/KwoC5LUU9ufobNkdCxvPVuroH5IsRbxZu1a3RtcWsobSQFzcfYS1uDAGliUabdvFsLYG+aM'.
      'VvhgE+/YNaR2WWyhq9YaM0JbRuEVPlCZN3V/sVQ+qDksOjDGMvBFz9wY4obkvtyZWnECQFNI15aw'.
      'o0L7Hk8ZH2O40lo2l9mYNByCOLoTN86RHVCuWeY3/w7AYBzlWpkvgcXgtsOVw12mY+Yt4xhRAyi9'.
      'ZQ8lZ+dk3ZwYMW4JQzuSgjd/aqdEY2d/hA3YreQgJA1x7E/frcV7K/+uv/mZ7xPvaN3CYesMeld7'.
      '0YlTdEEiBN1EUFPy+zy374Y8CQt3uM/t1HhU5nO0YtrAgxoTFjYjrVzWJRU/D5rIVS0Qqx4RDShw'.
      's4ab4KQOYnxQT2n2XlX6diHlAil5lUvIGl0P7F2qb5rGA9Yd7981Rlt075TFxa85YMd3DZi2+V7D'.
      'R7JQcSaBfIFrayzGH989iFuBPPgeIypom/J4X2urMqDHv/KAliUH24bdMyln3/8/DyofBvykS0RE'.
      'HrqPI6W9/Fy6t+vnOIk5hULN/h7JWL3wjcvycHXRD7xCDiTqhzffeV6ULhBwP2hDLEkTSrdAC8Dl'.
      'RopmbxeKGjjmBjrY+gIpOx2YJAVzFY5t4cFVhTjpkn2kHaIc3V6fFyma+D0+9aE+XDioBc42QGtm'.
      'RQs3bXRg/sVWuVrlF3n3vRkDER5EVjG6qNUSsb+rlen5mdPCelfgT0nFcauJPyFU7UyRut3CP1JW'.
      'nYpLN6KoGgD7paz6R9pWEoXm0H0c2ixA2k6JHdy0Mv3zMVLdntR3osDndbPqS9ZYiNYZkZcSUjat'.
      'rtoN6gXVjERqpIBJD2U5hQ4dkrGHRBa+mQsIXUqHgTycOu+fVGM50pek4/1s8b6K1RTQW8RiwswW'.
      '7mKdgbWR/RMs34jNTZqCgq/xy+Y5e4O5GGtXbmCxTisjfeky9soYsS7NDBwu3FkAOnXzIL9dlpoq'.
      'GDa1O5458XdrHHTAF7mXXZMnpwZ3eAF31BvY+jjnQiAEq8Vnmxsg0WEh8AGrvJX8W9UkgCNGEg1y'.
      'JThn0KtmArhxBur0qgaCUUvS+AiwEdEfd/cuLDS4EziCJNUzHMUD6tSpCSDN2bARV3Qg+Y7aolvX'.
      'wWnOtoWMpMZIrmv7edALRuloOSZb4HBMMELXONokE1FSp3xgw404VRQVG1rmj8KkU6YCaIYO0t6e'.
      'NkA1b/68KC4k6pwk1R6ODKJLYk0pbs6kt98sbL1eFCMC/Njj+gNb6K5DhWnYyAj5mJPREBk8/iQu'.
      'Re/h1tlElN8wzca8Ll1et3eJRHBczTLp0m7kiC0Jqw1MkxFzg1QcXAPSW++hUMHYqp8vOb6FBC+q'.
      'tWItr+ATpPSMO5avVV12qWrdWMXo2VohMgT2BqrSLml3WSSDfR2mQJeYM3Roy4lljDPc4K5mmMa1'.
      'yZuk19O+W11epyemvaLfUinHGXY4NrOlfQFf4YFSH65jnnWrSsN4zuu+QbQLZ4tUdQH17Tpr17XA'.
      '8PrratCrNYyjE04rvF0HnKP8yHNl5yDiTE3qlkPZJxxdSOPbMcQgj5uNRYSofo/D6jQTWeqE4W1i'.
      'CXQ8UBqdGFQ3rvrgcn/NK46LwUXKxipi8DZaOdn5iGXyVmxDg7QYkzG7n5sBuCzcmzWykE+xou1u'.
      '/twkYXSO9fOfmgGEDsLBGcHIoxN8UbtQrTQ6QVRgICE/lgxqWVcEuGKo8A/VWbv+ZJJsstTgzlDa'.
      'UsY1QEWevUpK4Pg5XDLyi9rNnrlkM4uUbT5RZGDvs1/11oeEG1XgQwoAMXiYGmQQTQcWTVeCO9PA'.
      'B2gmmDPGJ8uBLd7e1vAatDLws0VRp4z9waf4BfhlTo83K6ahFOejSBNYQacanxRawV2BUp09U9Pe'.
      'D2x8XIlydtOM/CBmzrxdOLqQvDzd0gXPTsoHlj4cWqTsSD7YUZLWQizb1CHmhz3hjCMW6CzdZtCn'.
      'oPiDkR+Qo2ubtUWNa3k3arnllDELjpZMB1IH7caFb2tWSnZa0nY40PpFPgOJhg+0uFWVRE4DI0ns'.
      'mdPD+SvZ+QrADeXZlO7n+kE90P6wou4Nn982V9t7gfAcHscsD3Q9xYOBtkcVgsWCr64RXs/oeQCf'.
      'nWdprQ7N8YOhZqeRsBRnhE3mcXNnsyWcFruDlgfC6pH/4u6LZ5Ukkp6Qeu3ngdS7Df9LmzbGOcw+'.
      'Y2wdj/ARBGjgLU9v6aQgChkvqIqDwHms2noDYerA1eB9miMViYQcILordmHdm405q9miHAeQzEmW'.
      'SZ3OR0Pu6K5uhqEfqBzfy7MUi4wZbROMDvjc4dmQ+GTs31xhRNMat7DknFFBR+8Shfe0EcjWdVJq'.
      'prEl3bf4UD9FREZwMnAh1oU0kEGL+SS2w54vDh1IUHx8Ap9K3AdsN6wUb/KiUkOqnDBCh7bguofM'.
      '6jARpk4kX74ZlA9H6ti2nJ93jFPDaaZGvYVv/V29DVoVP/jp/u6H/cXSGHbZ0krbjvnT9DRBCHtW'.
      'IQh8PqGpGZeI5UH51vlFowrj5KJJKpOtT5EXtvDDJaILmyRE6LhIQPDYsVT7dMdR8duww2cTZUcr'.
      'wYOHF1FrcgrQc2vRfy95S6YSlaZ9UrTuzX/01q/wLsRA4bmFb2EicSl6/2Xuwlgkmzgno0vLBa4s'.
      'NkJYeHA3v44iVmD+ri5zOoVkHUijHMawRBa8RS0OZZcwDeQK48BQGw6Ng1OCKiZG2/vbObGSjgbU'.
      'kedTyMOioAHMoJ8H0Bub+VmruEsL3Mut6d3lHK/pYzW4jvK3W8HZdkWuYe5IL/YZzik6Z3kJMSXR'.
      'hbwXDMp1Hvj4SLYQPI+XuUVWS6Gxbvv6b9SzprO170XVBy+/I5kuzSZi3VjObNMQJ65Nt8UdNALg'.
      'ptf+ITfJAAZefgkSUMmPsHBJOA1fY6w8M27ic8myJg5O5/llzRfCzR/hXGXujLScIUbmbgboT4br'.
      '6zNpPms3qf0a2QrEK8k1XEEU6dkN6ZYQyx0ZsjAjbJWEU2QrGysWWgWhccsEsZYIIFqLLS9nP1dr'.
      'hftX8QP5N2dHsOMsaZZyBN9JSNYtxpbdXTc6qLaJBAASRDVpWTmIOubC7zguVIKhvHnlQM4D73IW'.
      'LltBusayk5hnuTFbI5hr0/iMBzsR0WApawITWcttDdmZad4Tomkwx8PdwW6V5U0CfnWBYCh+4iDk'.
      '5n72rOOPjLFEv3f5xYWAo8Xgj3s8Ga3AYbI3IQIu+SC84PXs3KrEQjaxU9kHHk5pWImufhc4T+Wj'.
      'oPhdVQRJRXabtF5SjPmvp7FV/+wIowVxA+9M5vVC7R8cPcWiNYePSwgeNk/K1w/InWC44EchFHyW'.
      'Dr8nbYxHSGcY9aKc8+u7tarL/CJ0IHGxHkJIrR84zHGJ8tGxql1WYT47OAoV2ji9DQRFe3QKKKzQ'.
      'XXHh9z945Y4gjrNm9XAFdBf2B77jLIJ68+tWWTUrYRT5kHEWYJj4OtQ7hTG8x4watvzbwPGJYOcP'.
      'XpmIzaJHJUELoMEUICQ6bhjwbuoM29k9+tsc02BJwvxBXUrXG50O0BstvFOBV0baPivG4CTWLIKy'.
      'wxXQEvESaGeTQew0Bnxqbk0cm2ivrfFcat1Y3HchhF8WODgRLHpmvree4OlHx5elK7u++fe8tPgn'.
      'o0cSaBLbueBiKK40cLa+ZPeKrljVrSaJXtwNMgaBR/PsZCz+452ZRyf+CHE35aW3DR2wZcBmMM7v'.
      'RhzjLFG2/c38DSAA45tjDNUb++IhXdN7QYyJmozTA2VsOirzaxd5G8D74qUzHku7tTVpMa8GTj/j'.
      'AwU4Elge9eqz4Ay/iu1Kr/ga+wc2mvvATtloNX8J+xJhoDeSw8uQg8Ph1U3sOcLGxP8zSxwJYFm6'.
      '+YMNAXMsKSosVAPE0h+IJTNiCRsw/3QYDLgdj7iDbjszTqOBvDABLCP7/BC7OLAUhwyJgWVL+VZd'.
      'eaQ2/nQjEFeBHyDYAlaBVYiSEeJGXdkLKYkGvYMw2BZn8gVkYVcdakdUh0BhL7RxnPHv6Uq+kNYU'.
      'QKB1di+wBalfzEJej4d7lq8No46Qt6v22JE40NC15uLmP1ndCEJyqnMgdFtPqu/U5EUnHDxRscSt'.
      'zB8ck+Y2X0ossechog708ojbS70B1G/BIupIUXoUjv0BnkNBYICdZOwKsAq4I3xtJPmnD1C4Rtgc'.
      'h4C+o3pt+oUK2Ujq9hEOLkmdHgOZJAVLYiTdUOW3YZwv+9hqzgOtpU4YQGv0bDrnPSN4nqKL4Ki9'.
      'NvxoMf2yj+1fNz/JGYK9H0QDJfDp4HcXdG5O10+pTYv/XthyoSAu9tu4YQUJRMtd3HCorYCJBugO'.
      'siwqnxKhFD2vhCFoPIGXZrOPbVyO/cHesVdL4kf9o3/jHEDsSNbJ0UqH1Godmz4w7udISWV7MWLV'.
      'aoaei6N+MkbsuTreD5VLz0VqcRf7c+fsr4DLadcvaEifO1/+TVc0Znrb0ZeNmUsiImeTso1xPouk'.
      'enU/aIZLDfREO76F1urSd8aUs3z6kNoZtxEWH+76oDWeBQ/yf5RutnVJq1KgINO6ov3jJF/G0uPz'.
      'dIzwkdQnCW8x5+Kpyu4sVvGZM+SFGQKROkexUfdK9pVJHaO7CealdDykB2PGBqljwlVpZZWpVsNV'.
      'qULEuMl936QdhrhF3IBRi3/HJB4MOfpbZ3A25jqevOmp2z0Y9ue9E2Tsjwb0Tnsbwy/HnI79KEUA'.
      '4oKJZt2HgGycUkk3PoP3p7MKuRJdIrcQFNwvVVkX5xh6fgekTKrMwHhifRFfwWL4mBEOOs1ZcXBg'.
      'a3s8kC1BDBDsV1zOiDvachhKqq4SlRAj46QcabdHdLcEICAk2zp4H80vKWqpIcAHIK90cApRJVDt'.
      'rZAQQwRs0SMUN6QHURLcHjuYu8oSYxakp2hcZPAkVDYEnCBI6861Wo1AmrQB2UGRTeaMhCNNu7Zi'.
      'N9LAZmmn7Notti2XLZeeV0Q8QqpIOi5Zlt+45bjls+GWm0wkRrJIoJi5pUTtCh6VrF2ANwDzXQBM'.
      'mgjxQp8acuSlonTly+B5EHrUxqu4dbKGHB9Jd5TnRlItxpKGjHLj5/B9DqDZkSU3HUs188yOjfSH'.
      'LtlT0mDmvg2kIvuzBl88v/mp9c4m7YMpQJLneKTacu2D4asLg41YV+dc0vqtghamLTJ8moF4yp7C'.
      '9UE3dk+wVG9J+22pJrN+71iqAag/H38gai18Kaq7SlXLJK5fkM2dfW8wHNLEu/S1cPPju/i2gRT9'.
      'zk21aCDSUy2qgOGl8tzQrl/4e1IoJBAMnaku5Zmw5+iPsApdvUFyGDajskVvCEm48izteJbaMU9p'.
      'hZsy0g45GV1UJ6lmgzn4OfU+tR8Gc6BIrdBZvYCSpug4B9Aqv6ZX0wQoJO6UHmiQgGhnBCd4uPeK'.
      'jJg2SzJxoq4Z2gUekhW3edkNeyyXFhWVBjr1hmLYCKhIBolbNatFZfAqzJbFxZJdBcE7wlaj0aLz'.
      'G07WwJZnnUQlsA+VTd9KC+4FbKUpQz3nwlzH2n1gR1TOgfJFSriVn+Nxf6EJdmdMgI0ZDWs2Urq2'.
      '3aDMSKUhFFiNtgSN4Bp/EeZqmaS7SOMFz3aU7mVeOMxgvEdeqAzCmmVNCqGJNawVUgxditPLmlU2'.
      'gqbfSi80AbbqqrcsfsGYZkBSEETi43/fa/UZjAB6J9yyTh24siqWoTY+bx1pYzFg3TaW/jIqv9UI'.
      'Xd78VKah9w5df2yFRir8KBUGEsyzznGbyZESJF/GtfPCAnSKQXpyEnkjaZFwEg+iNuYOnHEmjC7v'.
      'Cq+R+VkWUcmBtmDXx9hUXSIW5cA25bVEMGDxLptwhXzBsnO1GVWCkTLefTs7sv28Zdlqh5yjH7d8'.
      'fUvWY9e9cdbj0DWe0ZxtTuI9Rxe9uPlLnDNNVkfqttkOmqO+hPCoskLiY0KKy7q4DJOdwQaLyD/n'.
      'ni/jtRR4JyxR0ejZSAcxbUzdPXvSDvsF2PpdCFkVVI8PPwnIwEcW4jR6ASAE/MKoGEyECerxsW1Z'.
      'XfdQQyi8WlXcismWODb2PMfrGk4uCqDmKU3grsUDfDBEU1OHhAGomvC+H/FuMZhMCAhc5pH63aoe'.
      '3qcDFiFJ6DGxSPFuNQ/x62JHcYTho6ieyF7frnqGOTDgqs0QzMi9aV8Eb9T8rAG0DDtDrtYwcHcW'.
      '5ZiBggFWNFd0Wbh2dTAJplzr4AMGYCaL464vVo7xFkxO14DSV3J//T/lEM3FehzlYh8PvRSc7h5G'.
      'RyFQWsgho0vSNSQ9Phr0WDyEfoU+H277e7HzdFsS+lVPnuq1w0L+/6b7ep4I2NL7xhHJPQGzSn9X'.
      'KJFeFskYIj1p+5ajbat56iaT9dh3haL2rfLYPZPzFWAh960LrngxIXJyc7GYiC1npTxhlbctK9Y0'.
      '5iz9OHyBHCOsAnTFBrcE6FrzxLK+qpyq60Uth/acVXqpZ5wvkQiTtx+dRnBvP65R3QXukzjtd2MS'.
      'tyP6ZKMDc8I7Qr0hAl6PfTvpMOfga/y04w/XVgHyAsHZyQfNi2HcNbpmruxD6EVfpgPA6MNQcXCK'.
      'aLtAUYW6jOgukENpQHheHH0pwhXj/wyB3llAUYhhE4mlfon89S+3vfTdGqc3UvK1D42ohNrkK5IJ'.
      'gq3uoe9dtN5tb2HZ6nFTk4/gff8I9iD2ocIB2p0XKQN5Wt/3JGELH/Xz2cjmDeXyvC9TGvzgU7y6'.
      'vigWC1M5h7aX3NO8FP8IvRhUMIHvJCfd+HA+kQUWdoKQgsV0E3HE17e5bgO8p5gxBDvIPMKfzSEY'.
      'MXbrh0by2kraaotXfGRbTq2bQ/sxXi1HnHyt88fysZS7E1N8dmQLTiOK73lE8SBn4uwwaKJflxMZ'.
      '2GYHvgFfKiQPjHD50rkoUBed8lICrnmR8+szXyBhjSS7VQyCVVqTGlVvNRltuvpQftzTmuK5lbdx'.
      '0FGIZfCePMIWnvSbfD8ebfWQx50hjygS1HXu+TsJDgPnwglDU4ox6+dnEkam24esDnTNeF2MGKol'.
      '0Mp2V3MIT/iEjxhL1x4M2GzIoRa7VjuJDZ6AmQMopirls5AoEQJTEapPWdg7F+gVVhDA2clRiJc7'.
      'tmq9MnjdFpJywWHl7CB7+bzgoAAFVRM8iiY7g5tc2vJ/ENdCXmSpQ++2MUTzZ5CMICp2W0gEj4j0'.
      'Ln/L/hEWn4EJFq0RTL0JGGRs21f5zX/AUwjSfwL+eBsmEsDJIWyQY5e00A+aqF20Lkn3iFeqYRke'.
      '8p95NQomytLIhljuiXHa8VSzCME9np99n6AhVNoAO8G1Zn29t1hX4G/hiz5Pplm2lRtbGU7dW6ow'.
      'cFcyag98jPcD0GDlZkswOtlhVWKckVUquqIPAlY1hl92WdWnYH0hVDjugvKSahuvl3heZ3YaWPEm'.
      'nrDItyCNh+MkcjVwkUrrupLIKbhzFLY/qhKnwMM0ausQycXhL/BiOQyat7m1plavNumLDdbBS5ub'.
      'K1gHO9tBAwFIQlr8cW1EJQfHwasABCFoCSmvX3FWWJVarNphK4sTj25JEEpXP7Ro9h8+efHswxMN'.
      'kqTyIv5NCjvAvWXYZZFurEpC23EpS207thlu5TEHWEobd0tDMEe8rln4ES3GVmZznTaAavYNSD7t'.
      'D3tOuv6hxmtSK/iRxSYXr8FjxGvW3moKKLwUDJWzuuFcPqzQNu9Y0mBI/lWdTuVzsK/DoVTl1ouI'.
      'YlOAbqda7c0h3fjgherkcwDOILNhxV6kmlPHu08G+mwQyxlrF8kCnbzl+yoqqjKGAuf0cluct+rm'.
      'Z1pHMG2XnGlYzSycm1i8WWAZEN3AJ/JQVqfDZ68yVjDOy2cwWUv2s9J8D4lV0GXEBzgfJ6BC4twz'.
      'dgai5wP19d4sJQzu+aHV9BUR5JbSuSz6e8r/dzH/nn1q/RMsnO/6mz+MWd8UzosWmPC3se5bjFmP'.
      'BOBDXrWiZBNDQ86wX3QWX68N7lGaLZkzZJnx+PpuqGmeOSPyJ4JNKBI/WBYXRmZaa6nH8sC6ZesQ'.
      'h+J3DibdvSSg6y2eRbSQCh+NKZFK1DPaq2nxU6djVBvxmFbRp9UH8t5r3mlwzi6qNSK4ocHifj3R'.
      'x5zTzr0SPzE+XgpG12Aka4mdM5CbcDdsiZjDYseaXqhLWR9nebUwTeKEhXZO2O8aSYXiaRNJ01ji'.
      'LO1wfNVcUChX4vkV0A53655ON4NasxmxVOwPTw9vOclkbaetzDUn0M6h67B6yDq5ZCsILestOgeO'.
      'pjcm0DhfAnOz/iTOHW5PN/jkt5yCnkoEeBtbmU8csZ3SSR3YwXIUcbxb1jxnnPBbPZYkqbjqrs9I'.
      'RPxkkElc8KjBNfOVfR+xFXIFpiI12DGPsrjMOh+fLfduAA7E2q99ySIul0DnqrmzE0XQdnZlOKl0'.
      'LuifWsw5NEjB7cymvXB+1zxfeOM3CvkmzkNbbK6y9vON9p/zy3wDeKcSwU20gM9aNwJWSwUen7x6'.
      '9vjlcy7zeQEo9XcJy++xOwalSY4pagR9f8uFetzdJgTvqTZDBSsHzNOILiRLDJqz6P1bCbIsq0d0'.
      'G0s44zhmZQkiqE3jqJbNWTSUMWg2P6S8iM73sUvpu9F+9CjvoWrJG87X2/ZDh486Lg0leFOf2eIF'.
      'y+Ir+MK8pw58tn8cT8Mt7Np7fsDvRcCwz38R+5sk2b4M2BasNBy0dyni90R8GqB+M8SY30BOjIia'.
      'peOUMw9LFnCcacm8mzS9Mbfwcec6MJ9bEwCD/XkfJHkxskVFTSL5GsZBHzpbCPQDottcTPQWvRvM'.
      'BVDwWKWgEogaY7wSfF32JISjxBskT+VXqfjjplwqLCvFOyG4GXDC9ijmg+NtfYx03gojEiOd5CXF'.
      'CvuWpXyDkYvxGb1PjFkpMjFHygsndBaJzQ6pNHyw9BbdWG+BA6C4x9yCNigIcsRv6SxCxkGOvrKL'.
      'IamLD76GC2kWfNFn/274W5ggE9lYkdg3qVs+GlTSiDpbJX667YatYs1JRFxVO9X+q+Lmj0nV/qsB'.
      'RjyQamv/6oMgUJ+VU5bw4+BzPBBcMXI2h7vJK05oSVfbPS8dtwYLAh637Mzy15/qN/WHD7GBGabx'.
      'Dfv64paa1yxYcGD3zU+J1xa32YrD1D0nwtKhHDVA81KB36ANuYy1FSgwNHx8ODaYSY4euIfTfonU'.
      'KEV3P3tMO556+eEW7fX8koMT7b0qmTrksix8lsRXt6YPV+ExmTec+vjZNT4hdbhaCo+FoG5+2qPY'.
      'jIYdzPJLcwEF3pa1zHKkcX9WY4xwysM2pWJ8zi+tuUgGBdyAOdcLHdAksWWci1SSx0TIxH0V61VT'.
      'h4cVh4ccMmLYiEs9YsTWLxJzN2J303KLK4S4pWWimVzOgT9hUZB7vsoTPEan/7ZFSd9i9ByAPvBJ'.
      'TlLhVQspqIgOndyyQqOzZmQGK6viKHIvC83hYn2YSVAiOs5lwuIry5URapfve30IroZao7MV1GRC'.
      'AWeaIJDbwpOMTFBP5ImTR2UBM6IC9pG0yZpW62AyTJnmAwK2sMTYY0RPNUXpgDZsEaF0XPamvMwz'.
      '6wDfYLWlU6Qn3fkOpYMBW4peM8GWlxgsd2BOwjBzVb0xg+6mgo86I34og/cch4P86YOlwzjoo9Dl'.
      '3MarZ/1apGOeZfWScb5Xc4RUlgGuhxYAtMMF6yk4ulZTdoYx6/e9Tk6WR2vVgBNW11c637bcQP45'.
      'RAJJKO0BCCpaP/WnP2Q12jzvbQAQHxU0RoPF4XS1KzqXCtGfpd14PDkLUa7U3Jw6Y6qjNUSHnbG+'.
      'fU6HxTmMxS4VbQPprhHlj9ZG/vrIsXuHWbglSQOfvxMJFY4QnZizQcLrygNqjITdV5ORGrsR6aD0'.
      '2IH+ZC4uKVFzs0Fz0/hTsFSGTSXRp45C9KmopZlMfDzRE2vLFUthStkC6mYAMZIfF0kD9CsW4GNV'.
      'PTwo2s6FqLzSW8CiMl/SfMfeHZy2VexKKTcIT8OkaCjCU0QjZOdAzEz2CmizK7YasHuhBZdU+J4g'.
      'hQtroyU/YNoso4n4xkPHII4Of4v/3eYa3m1BICZ05OJeqNE2AtYwWmXf1A7g2eWWkA3ADeF4ntoh'.
      'Qp1oj0VgRy/zYmRTXzR5ek6G34eCpHxyUecYB379qOJrwagfjIMy7RjCxhj2NRCd1qjS2NXxW3Up'.
      'EB9ZiezdYPXHxiI6U5h2yJEI+Lfyw/acgB9FzJhiZzZip1+nONkfcBJhT0OsWtCzMOX/dRCzE2JO'.
      'a7WiuximT9wbcZW3AjRuQadzSamF6jY9CqvxmEeGzCjh1RyEabIt4DqvMkn+oulRs4Wxd7O98e9n'.
      'J+yf7SSAtlDZVDPflqVkxSqhmVG3cH6QJtOV8i0JOa/xfPkYUOaKeOJEM5KI9RaWes8Th+RBN9HZ'.
      'vLolO0CxXkLYYjwAYmugx6NFdSp+qgoDAZvyMmfXVEaEABI11sDcRf0P/PSVHVZneNRHSRtAoioO'.
      '21K0y1ZWbeSlLHf/np2nEK2AxyW3zrvWwz/GNU9c/Lt2eU3QMq11/heMdItxPjp8B+utrb0n73pk'.
      '72udJ/KrvpTHS+R/zIn6xLa1Vl0/hHJdQDd/TFg4mVhd4t3S1meNVS8LNoCatNZW9a/EdNrjvgBX'.
      'PNRzW59kKzwCaVXeWPxOWBaCa8+aQNsZF0Mk7OcljQw8QfG7C0WapxGUDw7GHfEBQ9qHvG3rsmjC'.
      'bxKJhOjNEdIyzOquTy5MSJKb5fOlvnUEhYnVYl4i4x4VE+CjmgEJrBYjEFIrrsGJ3mKR4kaVRHgT'.
      'XhDuY6z6eMXp8Jw3zb/QSso5L6Sor/YtfpKPzy9Mk3KnxYsXtQ3Xvg5rtzZgnwNkx8Btuwygxk/N'.
      'ytbhhKTnDBrAobDOt/UrAXipOMsAEe5sqLWRTLZ8tOJwqZIOmUDW+UqBXxCw4UlYClCmMIXhjbTH'.
      'yiN2qV75xLWc4WEru0JiWxKg6DHTkhBULVyM6ldmXpwV6Zz0X5lENC1VMC4IZ8cRmMhaJyWwmhN5'.
      '+uBwp+RC2QyvXkvVpfnlx+uUXR8mH23F5vblSeXyA9eg/WGbLfzPcVCpqX2275tv8N+psFhpsTH0'.
      '0BzH3QRtmGLdxeOdoihdGJI6UkqWwp6Q7k2zgK9nibtu85QWTLPJgHcLuazpQmxgtkqG4+0KDVhJ'.
      'etxQTONp8Q40vuvhsglwtT5+WUOp9RWJ6NWZmFbWvMM3n74ruk2I3Eg4VBXt0izuW4XtV+acCk05'.
      'TwdfhwsMH5bOv5Uewpq2irZDaRF3Bcn2WjA5XOjS1I4KKFjcXSFQRAQGO//IV+2M9WAD/C5b3Xwt'.
      '47yR0rz2SdTknWHfhLPNfoijLEvW8REAl1okYAjlXxlGheqSQQCD7+HTHV+65trpuL4ytNM6MXha'.
      'DV/6PZMuOdoHKORVdAG/bIdPHoPH7vNgOxzaDz4ow9PJUqlZZaMqrWwx1t4qPbrjnXXgK9NXDDHm'.
      '4EruQivZ1krITXQ3UAkuit9bFcnKGPWOuQP1H32tEwKQ/T1cufqT1Dp9fpqsxb/HtfgniVqYcIf0'.
      'X+JF5D0e8Q8cSMm6fMwM9Qk4ROTQ2OO6mth16HvDV4Bq6SGpVy60NMAE5C/yxqCD8AFkT4kHnwrQ'.
      'B0zXqSR9HOaV4ztEtf6+QdOHiH/SHjwu2LwZNjiO+j+mIf7nfrW26kM1G6TD8PEGqOpugPqHNCjn'.
      '6hlZtPJYgGdZGLqPcBB4SL/pq459u4wI9XzkTTx9Tzdt+XJYZeg0PhtChENRxca7vCPReGmSbFhF'.
      '0LSvIuPhezY2B8UHLJxoW2iXAdasD2MgSbByiMNKRQdei7FTIL69Hr2+DQADF8jpppLgCLchEVZy'.
      'peAxDjS81BZW4NRBlGOAKjjQQzvPv1MBKmbjy7zQDFZBnGbbt13R9apVqCXohXZLPqXs2D+WTlXe'.
      'oBNHa7b9mSM5ojjo5c4QJzFX066P8GvMGvm0V0YzLztygR6YeYIEl60gtDb50I9CdIPQBVzng8Bv'.
      'HA1iu7TO7nlT+1vJZqMRxJz72ZM45N+FxbNnshjFYU78vna5Rzi4JmULORCue5v2zaWOtXw7toky'.
      'jGJRrkdnFIUhIK8885Z1VYluOpie+9kXQ3QBD9Xo2F8i6lqzEgc9GEjftDt+LwF/kmY9dK8QyxqW'.
      'pLWXKT4+IxDRex5GA0F3pNlmmHSngWXXgZKk36YqLu5n347gCyxCpOqiikWAcuoe1adGFucbto1y'.
      'fDPDquXNhVVV1Hdi40Bncjo0XBqXqTgHcreldguAzt6OjaRH6HpuScCzgdU7UHoMwWQO3rcLt5w9'.
      'x7+E+9QRtLd9N+NxKoPD92X7FiAehMm/P99JtJ799xjxaSCf9x77aSvdLxv7lBVPULpv70Jo2tv5'.
      'pUxPpSvc3/8bWE8kL9x1mdcSPGc+NxpeabdzHmdMSwz20XtxHGVS+yXrPEqsFkonI575rk6iekyv'.
      'B6kTv9loBZ5oOhEIJVKwnnPaJzVB6RkHMAZ1P+fU9ZGzu0Jlk+TpASa8ytTGTkFHXsHHOCFVHTq+'.
      'GaZB3cXH/ugCgO0b6nxLEmwVNhJe/+zsJNmhefBb+HvA+M66xhC8QYzvC80VKtpz+Gs4TJJTdbM0'.
      'kmMgAE4W7elGAoEHzghPW1F1sa/KKgBRXjj96MZitLQlSzSXE5/ADRYmY0dP3pRzXK90iSat0/tB'.
      'iQc3Pw4zpx77z9fOZhySvC1n0e6I9ntkLWqj5rj9i76hpZ8YPeGuR/lRnjj+UHTXzgZ56k0FaRtk'.
      'VCDW5PKnLhgAJ9bdmrZoOyg6lbNoduhjuVsrv/i+awbEib67r8Mp03SIzmBxasSrpqrVuZJjx4Qd'.
      'lg63xMDEj8S1mYtGasLn4hTWWOrRFLEpWuEFeahk6mAI2W8Smd54m0W6BDwllZb1qcS0FAqfFSjV'.
      'FvSQ6uC2I4eLuol7TWwyW8+E+1Bi1Pd9q63pU82yXco26xS6tzQ78AmKJxNZu8SahsBu145/v6on'.
      'MVIWw188ha9lNcWTDkCi3j3irolSohdjvbqTwxVRbgPwr/62fAhvtB6VPfu0eGROe3orXn/6oHiU'.
      'utv51rBWSrNaN7ATuEb61jbiWsGTtRGoT9tOoplw58/cgOEh13N3XQv08yY8fHKBTFYvXcn00cZ0'.
      'Peq7zbC+I8xz5orGu8erXp9RyiSu7x832syuPwm4KhA8ACQmgTn4xwyQspkoRcthSaUujvH0TirS'.
      '0aozGCDAz2Yqnk9A0JgfZYfXJTcCrYdnZ8RNXBDE556TYeqHfR5uBka4JzAJi0WjMFQ2PPAfkYnM'.
      'Iipww9fZVVPoQBSuaV9IvvJLE9uEKap0zKu0mjLY8InL2NApc83v1WYdKFlwAQfwK4w81HkAF0gZ'.
      '5wrAN7q794dVtSYjtwQVw5ubFbolf5DSjOWigEECju8lPCXuoiPQzFk+f9uvJ/RPQQUVIGzxULrD'.
      'OhbUGPlqAwZkmWOAewSHLYzgQJrk/YPb/al43AZlb/5jlGNarOyNACEjfuPZE+eAdNoH5vPbGttz'.
      'jSk811RrR8PWHLQkiyNUH3g2UUTmlH/Pl87vMxA1qX2JKYiHdFubrcwVog5Fniw00HuPG17ntCU+'.
      '5gBv19NEsodd6arax9f5zc9SS4wQ2uc4V8OOHeI5x/FfZx/nrRuA3zgHvNNAdzOFg7obdjsqPTHM'.
      'YaCAlzl7nGNTgDNioX+TN0mgmR2AwuHlEyTM5iU5JWYeuo+3SJXx8+nY00tdUu7reJITFH00/2mv'.
      'kHlI/yFGl7bPXj19lbJg7Elms5ZkdwXH09QdC/Vjl3oDqZ8HvQiz8lYLcYRA8c1gBm4FMD60jfdm'.
      'AsV4V9tqQ7wa7KCbn9PmGPwem2O+NcEDm20aOYwROdsccDXnaeS3tDbjhfg4eRLE+XluU7sk8N1G'.
      'CpmTc9QV2FlxUuo8eqKvXUCPjZ/6NnCVlA60Tr1bZbPt7UQAp2BiWuA91qoaW3awOl+CC3wRRymH'.
      'XCYwX++6WmcGNyCE5LIvGtXHsniZGKd9qekrutCHxSYo1LjRIxIDw57FQJIAacFU46aRJSjwR2XR'.
      '04YDvS7W6Ry/9KEfaPTox+u1Nzm/DuD670JD5RvHAfHfgoh6OImIinSi+iDcixuPIAmtqM5AyAtk'.
      '6lnmc9PQAlAvhXMo77wnz8ogcR6ydTlXHnE+UrH/FvRPTmX6dJheYMwHscHRKM29ZS1+Dt8xx84f'.
      'aFV0bywPEja9yTwMWIhXIeNKueyr6eSrnEhUc/qI2ELdqq0LoK6J2YMdartvfApzm8PCXBRVNTYR'.
      'O1+Z8ST4+M40StpotMIK4TrghNKaa0FA4gbBdPA6ep1KGMFgnBg2TmH68cYXD7ON56nL+ijBTi2V'.
      'Nwd1w10QJzuFM0QiKQScvn113WpJKzB3oxuevyeK9bIv1VJaYq7XTlXc1QbbOPMJvxArCSFKXqAQ'.
      'nkA38iaA6q6SAKHhvcpxA2WQf6zRHKO2sDp3vK7fkmwvgOicqZOmLY2VZktuasGBVgs35Am+0Cp9'.
      'aywez266haRjxs4s1cjIQ2M/bse5aZCM89WXyXnk3+Pp4J/0Xqe/mbvrPun5PtMSm/mbIT4cjcoX'.
      'plxnY2rlhIgyLhGTw2+OHCBjvq5CPTmcC1TIUpcGhJLziOYSPigxWJfme/aNuOWQPDiMiHvK4rtA'.
      '79WmMEK1eOfIXtiUmcmzD6nAX1aBHJexzn8k3uFi7ssFPJwNncjqsiDJ6/gwq/UwAz7B1zazKkfN'.
      'd3jWun2zxfG2fGWEiA4VCYsMYON/iMrdMixHh0GLS36EQnfc2D2HFuV+CBskMTNqLyqUHCo4fjy9'.
      'NIBgk7ti1bfX4jSOlmi7Ig4W4arw+qmChLr5agE0neY6+CksGF4GsoICe7aENSLkqAmjdsWVRWB0'.
      'BcU8txAd2STKE/T8X4eQ8AKbNiBuad/8kfHBhWqWAoQC8OSJPb8LTwu2ZQ7VVRf4Bb0cxXLswxjU'.
      'iezoV+tuZr/bf5e+yOZnTGYzYf0/Pvy7x0QciPDNNb2pJaThzZE289ZRu1oamOQnhw5gBHZo1WUf'.
      'twa39XYzGl9I2NPjC4cauEyLLxYzH44afa63BIyNXxrQzGFzvWNwtlpF6HneFmWZD7GaUo4Ws9lt'.
      'Y62+OcxQwI8dSvrMzDheehHP6XfPiYk4Gb2GoRmbGPqKgx6DkXeeDvxlPPKineOPzEfhwpWbet0U'.
      '7OZZv1Ntkp6KOOXZtxcnDFxe2EV/8zFNclH1ebPJdwBwNvqzAmPCECE+T5V0VKKHvLx3P4My3swL'.
      'ltlaPnA1MCPyvtmy7Z24Qnc1mJpFaP+/9ncLvGEYY4ONFXizR/0xzQA3xKXS4s5wBBUSw2nCjVSv'.
      'kGCbOS4aBr2gekMPHd/2iS3JnZtufRB0DCSFl7jQXAptmMhhgBEnae0S0QS2CPbiqm7ClNk0/VfL'.
      'QgIyQhH7fqaK+KV4EmOWON4NXWKfuxEoijZ5IgWmWrzvBRiI2DnmL6kNnmkJzig9Nrt95sVvEbc9'.
      'XXiV79K5Nwk8/bXDSediw9RSaJnWm/v2gzz5mS7LTazC7M3ZhNnwKWwjYdEh1jbzoPlpSQjvVEJT'.
      'SZnbcWLEjDuSVhn7fkjxay0+EGSPpTX55O7wuF8tQusaM93cbthcGxQ2o66dlFf5NVsQXIkffKfv'.
      'SAYMHcznd6f9DYcwTvHLWMqSuEMtQikcgYcf3fwviP+uyEB/pr9D0aV6zBmnvEAuHlypgemSj3Do'.
      'WRf5Ql4fkeuwTSme+7yawckI+XwBsXqD6258dv+Dx4ITx4T5rcCFnInxXzc22oRxc6YpCkLrpuMM'.
      'aAfDHF2CfyWWfZ+l0x9zzFmRYqyH2erNFGOR+UBjVRe1j1RcGpfS/Hrofgxuz7DIAGfbJVCYwqNr'.
      'aUpG29j4TGyAnG1z41sscE4Af/+DVxZL4VwiRwKzKWqvLcsQYHeDyVXQPGrcTvDaId/wumrZK3vS'.
      '8JTGu3whhNULc0gY88O3w4BwYJaKxhYUvxVDKcaWSTotjUXbkV/gpnyLtWoGW5j0XZ56Q00Obq5P'.
      'zx6R8Prpg7NHNt4zcAL261khQOX+Ew+q/uanMiC2JTg7c0UKgeacxB56ZrQTmbZYOY+Xotg2b2Ur'.
      'ciR2S1mY6kOuvuuLKp/iasxUdDjsuoGXB6VmJUisV+KOBoW5G/leu3UcoIkpHKJcyFRzS13154X4'.
      'WgzZkriur8VwnYzrkm9DLS4dnI2LYtHq9BpI4lfKjYoitkSo/VFiErBKVx7D2kIFrXbC3Zlr4EFo'.
      'tvPJFCZUUFLpQWi88/kUBiqoQ8/EA2e/gyqOHXPcvfpNDlwyyaMMK89EbBRglfpi4UsWWTIuim75'.
      '7jprasRww5Aj4rmTnfddg9O5m3FVaVsmlbV527aSSNhMM/dNCkEC7Zp+CMwOy7ozx31jbouZ5NpT'.
      'MZNERcM7nRFe6tzazV1LNdVL8XNTsrWFuJ4J0YJOVDgYtFnNCSlSIST7jmfsW7ZKavGhYAfjIFzO'.
      'l5zGQmyUrZ8uE7nkp0VHbck/BieHKISZVuLpRGrbjuowi9qx8uuzpzEHjRyd4i2ZwT9D7OKX9kvK'.
      'ewf6YK0a1ax9xZETLhLwwmuUHrZchP1ut9hO7v/t91cBNM3GSl2nRTor0mTJwUz9U40TNS4iCvFv'.
      'gMKcXvnyJbwmJZeuPe/2tMxtaDm7gzIDkSa0I6886QPUQobk5Dn8mhMfD8/hz/L5W+fi+I3mV85S'.
      '+PGzmaWhBeJV8pVNhhz0sgsUUVO9DMrEJ8+uRVcATLLqd4IFfSyVp1Sb/mustXVJi93bw1G5Nb9J'.
      'QHAqw4lAMZT2s0uguB22YSqb1i8NkuQa0YJDTxEGUlL/vIKLXODNK1vzKGzJe/18LNLUMkf0MtQU'.
      'CUvU3ixo2/r/fAwmapxTkJube8uCVQGxMYoBcOKkYdnHmnMCgUb09P6NO4ImAw4O7cd2uHe+8UEC'.
      'M/nnHYKurr0pqXUWZcESWTRcs1CTTOeMkmFCkVG2KNR/1rZDvA/FNRLtyx17oU3vBbTKKkpJRBWN'.
      'RcsqvX4illj75AoloNZO8aGokHo2IL/jB+MdtCri5cvay9SJumOb4cKK8kSF29GePrUevSXJrZVL'.
      'ruV8x6RRErQYKmyiVwfanCuWwCB4pt8EZS5ws5EWuCesw1MiaTTDfW0JfeE3KpdOARruRrnCOKuf'.
      '0DXB+erQOiYuYclEluUDFCv5BI8V4newWDVf6QRMAzMv2UnHKqZvJDepH38cQNAEfPn4RTYT/UfS'.
      'n44nqhiXG0xBXERvKZarbCO7rnLSz+jY0/Alx0s4LuNOC+BBBdCRyQy5VOafQxzHwVULA6xGAGr8'.
      'hpvM2+n6AiOixHBIi4ZSUn+k6NAgcrqOgTcS/Uri48JKI4gzSmdfn9/8iPfK8EwVnw3rFIC0BEnj'.
      'vnyIBQb5TQVB4BKdm/nSq2j4f7/NRMkkOpA0BgdQiJCdNVHT+JqDhx5DK7JVdeMMFak8l3RuVvOb'.
      'Py+Ki/puIz8zvyhusfFjBtn2Pncq2EOnlEsOdkqRF/4MHmlFS6zNxGilQ6+SVYyrMtgO0D4lhmeP'.
      '6fBaEZ3wbbCTOPhQWtZPVH4QfIZNqg8nqBgi3EZa2/S86dIy2qH7ODrsVi44SZYa/aQeVG1WlhK/'.
      'x04l0xGMeJLD3Qml8gZJS6CiTscq4uymB/4Cj6aV1dIFwYkY1LJoO6sQuwXatByUGx+6TDdDMe/e'.
      'yP4x9CrN35hWArTZz8F6jYlOTJ0dEq+OGeYKHjZ08+LpeT/7Iu+JggaYiNOXgrx534Z4Z+/KLK5w'.
      'ezMJzlyrzgvQp0HV/KZnw/vcJXCdSq6zL59GaN5BphsqwtFpyUNP4taGh15LL37jFrNGFIhgcutp'.
      'jPkNSk8f94dcDkEDZXzgo7m6LZKnpHyIT0n57QdZzc3tYC/NFNhLE4C9AB+gVWxMnG1sgAVGQdH4'.
      'wKCKA04XDg/PK0UnFk3ryCB2MKLTGEcp1MkPtioN7JVyReKjQ77VrDxLHm3VOzoPjrM6b1hR7py1'.
      'gJS4JNYTWbCdjtLJDtdZ3TV3x76jaMEZ+swtoe14nEFzVrPxeuCTTevwrz+9fFN/mJy2E4vcHhGk'.
      'E+/3eQNHiw/dm+yvPykuMnX0Ogj8YbTUrey8oXvGJBrZ3fVQyVT1jfrbKHiqVIxbj2pYYz0qinmU'.
      'WxK+EKT+1//rzA1LizUNeA0MrtVQRrCKv0sDhLwQqHMh0LHXntNbRlCKv4u3yUHkZyuwvGbhtHCi'.
      '0/R6LFS3IzrNud9sCW53jpPcuh0YM4iX7SSDsjd/547wm/9VdsUKme0WAQIwX798FZ/hNsZzYyOl'.
      'GtvbTVMYETBKIGRzH0EXQJjgimYxuP3xFuE6P/zw/wA='.
      '')));
    $idios[$my]=true;
    $myLang=$my;
    foreach($lang_lang as $st =>$tra)
      foreach($tra as $la => $kk)
        $idios[$la]=true;
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
  }
  
  function forceLangSession($lang) {
    global $whichLang;
    if ($lang)
      $_SESSION["whichLang"]=$lang;
    if ($lang=$_SESSION["whichLang"])
      $whichLang=$lang;
  }
  
  function __($mes,$lang="") {
    global $lang_lang, $whichLang, $altLang, $myLang;
    $idi=$lang or $idi=$whichLang;
    $hash=4000;
    if ($idi == $myLang)
      return $mes;
    if (strlen($mes) > $hash) {
      for($i=$hash-12; ; $i++) {
        $imes=substr($mes,0,$i);
        if (ord(substr($imes,-1)) <128 or $imes == $mes) break;
      }
      $imes="$imes-".sprintf("%u",crc32($mes));
    }
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
  // }}}

  /* vim600: ts=8 fdm=marker cms=//%s
   */

