<?php

// jue 10 mar 2016 14:14:11 CET
// built with mkinstaller 2012041901 by Manuel Mollar (mm AT nisu.org) http://mkInstaller.nisu.org/
// do not remove this Copyright

$ilic='
Copyright (c) 2006-2009 Manuel Mollar
mm AT nisu.org http://mkInstaller.nisu.org/
This software is released under a MIT License.
http://www.opensource.org/licenses/mit-license.php
';

error_reporting(E_ALL ^ E_NOTICE);
ini_set(track_errors,true);
session_start();
$lg=detLang($_REQUEST["lang"],"es");
$_SESSION["lang"]=$lg;
foreach(array("gzdeflate"=>"zlib", ) as $f => $p)
  if (!function_exists($f))
    salir(sprintf(st("Lfne"),$f,$p));
$hhost=$_SERVER["HTTP_HOST"];
if ($exsfn=$_REQUEST["scfn"])
  $sfn=$exsfn;
else if ($hhost)
  $sfn=$_SERVER["SCRIPT_FILENAME"];
else
  $sfn=$argv[0];
$fin=@fopen($sfn,"rb") or
  salir(st("Eali"));
$pidi=strpos(fread($fin,69685),"\n?>")+3;

if ($i=$_GET["img"]) {
  $imgs=unserialize(tkInBuff(22020));
  header("Content-type: image/".$imgs[$i]["t"]);
  exit(tkInBuff($imgs[$i]["i"]));
}
$pidd=$pidi+36036;
$files=unserialize(tkInBuff(22692));
$dsdb=unserialize(tkInBuff(23712));
$dvars=unserialize(tkInBuff(27524));
$plans=array('es'=>19724,'ca'=>20344,'en'=>20920,);
$lics=array('es'=>9960,'ca'=>10152,'en'=>10344,);
$css=21484;
$uniq="mkI56e17322f3081";
header('Content-type: text/html; charset=ISO-8859-1');
if ($j=$_REQUEST["jmp"]) {
  foreach($files as $fic)
    if ($fic["j"] == $j)
      $simu or eval("?>".trim(tkInBuff($fic["po"])));
  die();
}
if ($info) {
  $imgs=unserialize(tkInBuff(22020));
  $dopt=unserialize(tkInBuff(35764));
}
if ($info)
  return;

$simu or $simu=$_REQUEST["simu"];
$tby=$twr=$taa=0; $ma=""; $smo=0.5; $buf=false;


loadPi();
if ($argv[1]) {
  $cml=true;
  $brk="\n";
  $vo=array();
  foreach($dvars as $var => $def) {
    if (isset($def["vl"]))
      $val=$def["vl"];
    else {
      $d=$def["df"];
      if ($def["ml"] and is_array($d))
	if($dlg=$d[$lg])
	  $d=$dlg;
	else
	  $d=current($d);
      if (is_array($d)) {
        if ($se=$def["se"]) {
	  $d=array_keys($d);
	  $se=$d[$se-1];
	}
	else
          $se=key($d);
        eval('$val='."$se;");
      }
      else
        eval('$val='.$d.";");
    }
    $vo[$var]=$val;
  }
  for($i=1; $i<$argc; $i++) {
    list($var,$val)=explode("=",$argv[$i]);
    if ($val)
      $vo[dechex(crc32($var))]=$val;
    else
      $o[$var]=true;
  }
  $ve=$v=$vo;
  if (!$simu)
    foreach($dvars as $var => $def) {
      $val=$v[$var];
      if ($def["ev"]) {
        if (@eval('$val='.$val.";") === false)
          salir(st("ExIn")."\n".$val."\n".$php_errormsg);
        $ve[$var]=$val;
      }
      if (!$ve[$var] && $o["intc"]) {
        echo $def["va"],": ";
	$ve[$var]=substr(fgets(STDIN),0,-1);
      }
    }
  $v=$ve;
  foreach($dvars as $var => $def) {
    if ((($val=$v[$var]) === "") and ($em=$def["em"]))
      $v[$var]=$val=$v[$em];
    if ($def["st"])
      $v[$var]=var_export($val,true);
  }
  $doit=true;
}
else if ($_REQUEST["doit"]) {
  $brk="<br>";
  $cml=(!$_REQUEST["jsav"]);
  if (!$cml) {
    ob_start(); $buf=true;
  }
  $o=&$_REQUEST;
  if ($vo=$_REQUEST["v"])
    foreach($vo as $var => $val) {
      if (get_magic_quotes_gpc())
        $vo[$var]=stripslashes($val);
    }
  $ve=$v=$vo;
  if (!$simu)
    foreach($dvars as $var => $def) {
      $val=$v[$var];
      if ($def["ev"]) {
        if (@eval('$val='.$val.";") === false)
          salir(st("ExIn")."<br>".$val."<br>".$php_errormsg,true);
        $ve[$var]=$val;
      }
    }
  $v=$ve;
  foreach($dvars as $var => $def) {
    if ((($val=$v[$var]) === "") and ($em=$def["em"]))
      $v[$var]=$val=$v[$em];
    $_SESSION["ve"][$var]=$val;
    if ($def["st"])
      $v[$var]=var_export($val,true);
  }
  $doit=true;
}
else
  $doit=false;

if ($doit) {
  if (!$o["acli"])
    salir(st("Ddal"));
  $time=time();
  if (!$cml) {
    header("Pragma: no-cache"); header("Cache-control: no-cache");
    echo str_replace("{CSS}",tkInBuff($css),tkInBuff(22340));
    echo "<script> try { parent.chStep('2'); } catch(e) {} </script>";
    echo "<tr><td id=ftd>\n";
  }
  $simu and loge(st("Sosi"));
  if (!$o["nrun"])
    foreach($files as $fic) {
      if ($fic["x"] == "f") {
	$nf=$fic["n"];
	loge(sprintf(st("Pefs"),$nf));
        loge(sprintf(st("Eefs"),$nf));
	$f=trim(tkInBuff($fic["po"]));
	parsea($f);
        $simu or eval("?>$f");
      }
    }
  foreach($files as $if => $fic)
    if ($fic["j"] or $fic["x"] == "f")
      unset($files[$if]);
  @ob_end_flush(); $buf=false;
  if (!$cml)
    echo "<tr><td id=gtd>\n";
  dataOpen($sfn);
  $prt=true; $run=array();
  foreach($files as $if => $fic) {
    $nf=$fic["n"];
    if ($cnd=$fic["c"]) {
      $vv=dechex(crc32($cnd["v"]));
      $vv=$v[$vv];
      if (function_exists("preg_match"))
        $ndc=!preg_match("/".$cnd["e"]."/",$vv);
      else
        $ndc=true;
    }
    else
      $ndc=false;
    $ndo=($ndc or $simu);
    if ($l=$fic["l"]) {
      if (!$ndo) {
        @unlink($nf);
        symlink($l,$nf);
      }
    }
    else if ($fic["d"])
      $ndo or crd("$nf/.",$fic["a"][0]);
    else {
      if ($fic["p"]) {
	$f=tkBuff();
	if ($fic["x"])
	  $ndc or loge(sprintf(st("Pefs"),$nf));
        else
	  $ndc or loge(sprintf(st("Pyce"),$nf));
	parsea($f);
	if (function_exists("preg_replace"))
	  $f=preg_replace(array("#^([ \t]*//[ \t]+)%$lg%:[ \t]+#m","#^[ \t]*//[ \t]+%..%:[ \t].*\n#m"),array("\\1",""),$f);
        $prt=false; ob_start();
        if (!@eval("return true; function $uniq$if() {?> $f <?php }") and
            !@eval("return true; function $uniq$if() {?> $f }"))
          salir(sprintf(st("Epds"),$nf)."<xmp>$f</xmp>".ob_get_clean(),true);
	ob_end_clean();
	if ($fic["x"])
	  $run[$nf]=$f;
	else if (!$ndo) {
          crd($nf);
	  $h=@fopen($nf,"wb") or salir(sprintf(st("Npcf"),$nf).$brk.$php_errormsg,true);
	  (@fwrite($h,$f) !== false) or salir(sprintf(st("Npef"),$nf).$brk.$php_errormsg,true);
          fclose($h);
	  @chmod($nf,$fic["a"][0]);
	  @touch($nf,$fic["a"][1]);
        }
      }
      else if (!$fic["x"]) {
        $ndo or crd($nf);
        $ndo or $h=@fopen($nf,"wb") or salir(sprintf(st("Npcf"),$nf).$brk.$php_errormsg,true);
        $ta=$fic["ta"];
        $ndc or loge(sprintf(st("Cefs"),$nf));
        while (true) {
          $bf=tkBuff();
          $ndo or (@fwrite($h,$bf) !== false) or salir(sprintf(st("Npef"),$nf).$brk.$php_errormsg,true);
          $ta-=strlen($bf);
	  if (!$ta)
	    break;
        }
        if (!$ndo) {
	  fclose($h);
	  @chmod($nf,$fic["a"][0]);
	  @touch($nf,$fic["a"][1]);
	}
      }
    }
  }
  if (!$o["skdb"]) {
    foreach($dsdb as $idb => $sbd) {
      if ($alt=$sbd["alt"]) {
        $vv=dechex(crc32($alt));
        $vv=$v[$vv];
        if ($vv != $idb) {
          foreach($sbd as $ibd => $n)
            if (is_array($n))
              for($icr=0; $icr < $n["no"]; $icr++)
                tkBuff();
          continue;
        }
      }
      foreach(array("ho","pt","us","pw") as $n)
        if ($nv=$sbd["v$n"]) {
	  $vv=dechex(crc32($nv));
	  $vv=$v[$vv];
          if (!$vv)
            salir(sprintf(st("Lvsu"),$nv,$idb));
          $simu or eval('$vv='.$vv.";"); // usually due to var_export
          $con[$n]=$vv;
        }
        else
          $con[$n]=$sbd[$n];
      if (!$o["dmdb"] and ($ty=$sbd["ty"]) == "mysql")
	if (!$simu) {
	  if (!function_exists("mysql_connect"))
	    loge(sprintf(st("Lfne"),"mysql_connect","mysql"));
	  if ($con["pt"])
	    $con["ho"].=":".$con["pt"];
	  @mysql_connect($con["ho"],$con["us"],$con["pw"]) or
	  salir(sprintf(st("Npcs"),$php_errormsg.@mysql_error()),true);
	}
      foreach($sbd as $ibd => $n)
        if (is_array($n)) {
          if ($nv=$n["vdb"]) {
	    $vv=dechex(crc32($nv));
	    $vv=$v[$vv];
            if (!$vv)
              salir(sprintf(st("Lvsu"),$nv,$ibd));
            $simu or eval('$vv='.$vv.";");
            $nbd=$vv;
          }
          else
            $nbd=$n["db"];
	  if ($o["dmdb"]) {
	    if (file_exists("$nbd.dump"))
	      salir(sprintf(st("Npev"),"$nbd.dump"));
	    $simu or $hm=fopen("$nbd.dump","w");
	    $wtg=st("Escr");
	  }
	  else {
	    $wtg=st("Oper");
            if (!$simu and $ty == "pgsql") {
	      if (!function_exists("pg_connect"))
	        loge(sprintf(st("Lfne"),"pg_connect","PostgreSQL"));
              if (!@pg_connect("host='${con['ho']}' port='${con['pt']}' user='${con['us']}' password='${con['pw']}' dbname='$nbd'")) {
                $h=@pg_connect("host='${con['ho']}' port='${con['pt']}' user='${con['us']}' password='${con['pw']}' dbname=template1") or 
	          salir(sprintf(st("Npcs"),$php_errormsg.@pg_last_error()),true);
	        @pg_query("create database \"$nbd\"") or
	          salir(st("Npcb").$php_errormsg.@pg_last_error(),true);
	        loge(sprintf(st("Clbd"),$nbd));
	        @pg_close($h);
	        @pg_connect("host='${con['ho']}' port='${con['pt']}' user='${con['us']}' password='${con['pw']}' dbname='$nbd'")
	          or salir(sprintf(st("Npsb"),$nbd).$php_errormsg.@pg_last_error(),true);
	      }
	    }
	    else
              if (!$simu and !@mysql_select_db($nbd)) {
                @mysql_query("create database `$nbd`") or
                  salir(st("Npcb").$php_errormsg.@mysql_error(),true);
                loge(sprintf(st("Clbd"),$nbd));
                @mysql_select_db($nbd) or
                  salir(sprintf(st("Npsb"),$nbd).$php_errormsg.@mysql_error(),true);
              }
	  }
          loge(sprintf(st("Slbd"),$nbd));
          for($icr=0; $icr < $n["no"]; $icr++) {
            $cr=tkBuff();
	    loge(sprintf($wtg,substr($cr,0,strpos("$cr(","("))));
	    if (!$simu)
	      if ($o["dmdb"])
	        fwrite($hm,$cr);
	      else if ($ty == "mysql")
                @mysql_query($cr) or loge(sprintf(st("Esae"),@mysql_error(),true));
	      else
	        @pg_query($cr) or loge(sprintf(st("Esae"),@pg_last_error(),true));
          }
        }
    }
  }
  else
    loge(st("Bdnp"));
  $tby=3292460; $twr=52;
  loge(st("Inco"));
  if (!$cml)
    echo "<tr><td class=rtd>\n";
  if (!$o["nrun"])
    foreach($run as $nf => $f) {
      loge(sprintf(st("Eefs"),basename($nf)));
      $simu or eval("?>$f");
    }
  loge(sprintf(st("Tito"),time()-$time));
  $simu or savePi();
  if (!$cml)
    echo"</table>\n<script>try { parent.chStep('3'); } catch(e) {} </script></body>\n</html>";
}
else if($hhost) {
  header("Pragma: no-cache"); header("Cache-control: no-cache");
  if ($_REQUEST["wk"]) {
    ob_start(); $buf=true;
    echo str_replace("{CSS}",tkInBuff($css),tkInBuff(22340));
    echo "<script> try { parent.chStep('1'); } catch(e) {} </script>";
    $cml=false; 
    $cver='1.2 beta rel 20160310141407';
    if (!$exsfn and function_exists("file_get_contents"))
      $ver=trim(@file_get_contents("http://voto.nisu.org/v?cur=".urlencode($cver)));
    if ($ver and ($ver != $cver) and function_exists(preg_match)) {
      if ($_REQUEST["unv"]) {
	$cont=htmlentities(st("Cont"),ENT_COMPAT,"ISO-8859-1");
        if ($nv=@file_get_contents($ver) and @fwrite(@fopen("$sfn","w"),$nv))
	  die("<tr><td id=wvr><a target=_top href=\"?\">$cont</a>");
	else
	  echo "<tr><td id=wvr>".htmlentities(st("Nspu"),ENT_COMPAT,"ISO-8859-1");
      }
      else {
	echo "<tr><td id=wvr>".htmlentities(st("Aeuv"),ENT_COMPAT,"ISO-8859-1");
	if (preg_match("%^https?://%",$ver) and $nv=@file_get_contents($ver))
	  echo "<tr><td id=wvr><a href=\"?{$_SERVER['QUERY_STRING']}&unv=1\">".htmlentities(st("Dyul"),ENT_COMPAT,"ISO-8859-1")."</a>";
      }
    }
    echo "<tr><td id=ftd>\n";
    $simu and loge(st("Sosi"));
    if (!$simu and ini_get("safe_mode")) {
      loge(st("Einp"));
      sleep(2);
    }
    if (!@touch($tmf=uniqid("mktest"))) {
      loge(sprintf(st("Anpc"),getcwd()),true);
      loge($php_errormsg);
    }
    @unlink($tmf);
    foreach($files as $if => $fic) {
      if ($fic["x"] == "l")
	$simu or eval("?>".trim(tkInBuff($fic["po"])));
    }
    @ob_end_flush(); $buf=false;
    echo "<tr><td id=gtd>\n".
      "<form method=post id=for>\n".
      "<script>document.write('<input type=hidden name=jsav value=1>');</script>\n";
    echo "<table id=tab>\n";
    foreach($dvars as $id => $def) {
      $mg=&$def["lg"][$lg];
      if (!$mg)
        $mg=&$def["lg"]["es"];
      $ty=strtolower($def["ty"]);
      if ($sp=&$def["sp"][$lg])
        echo "  <tr><td id=sp$id class=sep colspan=2>$sp";
     if ($ty != "hidden")
        echo "  <tr><td id=td$id class=lab>$mg: ";
      $sz=$def["sz"]; $vs=$def["vs"]; $d=$def["df"];
      if ($def["ml"] and is_array($d))
        if($dlg=$d[$lg])
          $d=$dlg;
        else
          $d=current($d);
      if (is_array($d)) {
	if ($def["mp"])
          echo "<td id=ti$id class=tse><select id=in$id size=\"$sz\" multiple name=\"v[$id][]\" class=sel>";
	else
          echo "<td id=ti$id class=tse><select id=in$id size=\"$sz\" name=\"v[$id]\" class=sel>";
        $vse=$def["vl"] or $se=$def["se"]; $c=1;
        foreach($d as $v=>$t) {
	  $ok=false;
	  eval('$val='.$v.';$ok=true;');
	  if (!$ok)
            echo "<xmp>$v</xmp>";
	  if (!$t)
	    $t=$val;
	  $val=htmlspecialchars($val,ENT_COMPAT);
	  $sel=(($vse == $val or $se == $c) ? " selected" : "");
	  $c++;
          echo "<option$sel value=\"$val\">$t";
        }
        echo "</select>\n";
      }
      else {
        if ($ty != "hidden")
          if ($vs)
	    echo "<td id=ti$id class=ttx>";
	  else
            echo "<td id=ti$id class=tin>";
        switch ($ty) {
	  case "text":
	  case "checkbox":
	  case "password":
	  case "hidden": $ty=" type=$ty"; break;
	  case "readonly": $ty=" type=text readonly"; break;
	}
	$ok=false;
	if (isset($def["vl"]))
	  $val=$def["vl"]; 
	else {
	  eval('$val='.$d.';$ok=true;');
	  if (!$ok)
	    echo "<xmp>$d</xmp>";
	}
	$val=htmlspecialchars($val,ENT_COMPAT);
	if ($vs)
	  echo "<textarea id=in$id rows=$vs cols=$sz class=txt name=\"v[$id]\">$val</textarea>\n";
	else {
	  if ($sz)
	    $sz=" size=$sz";
	  echo "<input id=in$id class=inp name=\"v[$id]\" value=\"$val\"$ty$sz>\n";
	}
      }
    }
    echo "  <tr><td id=tidoit colspan=2 class=tsu><input id=indoit class=sub type=submit name=doit value=\"".htmlentities(st("Inst"),ENT_COMPAT,"ISO-8859-1")."\">\n";
    if (!$li=$lics[$lg])
      $li=$lics["es"];
    echo "  <tr><td colspan=2 id=tdacli>\n  <input id=inacli name=\"acli\" type=checkbox class=che>".htmlentities(st("Alli"),ENT_COMPAT,"ISO-8859-1")."<br>\n";
    echo "  <textarea cols=50 rows=5 id=inlic>".htmlentities(trim(tkInBuff($li)."\n\n".st("Atli")."\n\n$ilic"),ENT_COMPAT,"ISO-8859-1")."</textarea>\n</tbody>\n</table>\n";
    echo "</table>";
    echo "</form>\n<script>mv(100,3292460,52);</script>\n</table>\n</body></html>";
  }
  else {
    if (!$p=$plans[$lg])
      $p=$plans["es"];
    echo str_replace("{CONT}",str_replace(array("{NOFR}","{QSTR}"),
		array(st("Papc"),$_SERVER["QUERY_STRING"]),tkInBuff(22176)),tkInBuff($p));
  }
}
else {
  $cml=true;
  foreach($files as $if => $fic) {
    if ($fic["x"] == "l")
      $simu or eval("?>".trim(tkInBuff($fic["po"])));
  }
  salir(st("Dppa"));
}
die();

function tkInBuff($po) {
  global $fin, $simu, $pidi;
  if (@fseek($fin,$po+$pidi) !== 0)
    salir(st("Eali"));
  if ((strlen($l=@fread($fin,12)) != 12) or
      (trim($l) !== strval(intval($l))))
    salir(st("Eali"));
  if (strlen($b=@fread($fin,$l)) != $l)
    salir(st("Eali"));
  $b=@gzinflate(base64_decode($b));
  if ($b === false)
    salir(st("Eali"));
  if ($simu)
    usleep($simu);
  return $b;
}
function tkBuff() {
  global $fdd, $tby, $twr, $simu;
  if ((strlen($l=fread($fdd,12)) != 12) or
      (trim($l) !== strval(intval($l))))
    salir(st("Eale"));
  if (strlen($b=fread($fdd,$l)) != $l)
    salir(st("Eale"));
  $b=@gzinflate(base64_decode($b));
  if ($b === false)
    salir(st("Eale"));
  $tby+=12+strlen($b);
  $twr++;
  if ($simu)
    usleep($simu);
  return $b;
}
function dataOpen($f) {
  global $fdd, $pidd;
  $fdd=@fopen($f,"rb") or salir(sprintf(st("Npae"),$f));
  fseek($fdd,$pidd);
  return true;
}


function parsea(&$f) {
  global $dvars, $v, $uniq;
  foreach($dvars as $var => $va) {
    $val=$v[$var];
    if (!$va["prt"]) {
      if ($va["ty"] == "password")
        loge($va["va"]."=********");
      else {
        $nlval=explode("\n",$val);
        loge($va["va"]."=".$nlval[0]);
      }
      $dvars[$var]["prt"]=true;
    }
    $f=str_replace("$uniq.$".$va["va"].".$uniq",$val,$f);
  }
}
function &gDfVar($n) {
  global $dvars;
  return $dvars[dechex(crc32($n))];
}
function gValVar($n) {
  global $v;
  return $v[dechex(crc32($n))];
}
function sValVar($n,$vl) {
  global $v;
  $v[dechex(crc32($n))]=$vl;
}
function loge($m,$lit=false) {
  global $cml, $tby, $twr, $brk, $ma, $taa, $buf, $smo;
  $ta=floor(100*($tby/3292460*$smo+$twr/52*(1-$smo)));
  if (($ma != $m) or ($taa != $ta))
    if ($cml) {
      if (function_exists("preg_replace"))
        $m=preg_replace("/<[^>]*>/","",$m);
      echo "$m ($ta%,$tby,$twr)$brk";
    }
    else {
      $sc="";
      if ($ma != $m) {
        if ($lit)
	  echo "$m<br>";
	else
          echo htmlentities($m,ENT_COMPAT,"ISO-8859-1")."<br>";
	$sc.="sc();";
      }
      if ($taa != $ta)
        $sc.="mv($ta,$tby,$twr);";
      echo "<script>$sc</script>\n";
    }
  $ma=$m;
  $taa=$ta;
  $buf or flush();
  return true;
}
function salir($m,$lit=false) {
  loge("\n      $m",$lit);
  echo "\n";
  die(intval($m != ""));
}

function mkdr($dir, $mode = 0755) {
  if (is_dir($dir) || (@mkdir($dir) && @chmod($dir,$mode))) return true;
  if (!mkdr(dirname($dir),$mode)) return false;
  return (@mkdir($dir) && @chmod($dir,$mode));
}

function crd($f, $m = 0755) {
  if (!mkdr($d=dirname($f),$m))
    salir(sprintf(st("Npce"),$d));
  return true;
}

function st($id) {
  global $mg,$lg;
  if (is_array($id))
    $p=$id;
  else {
    if (!is_array($mg))
      $mg=unserialize('a:1:{s:4:"Lfne";a:3:{s:2:"es";s:57:"La funci�n %s no est� disponible, revisa el modulo php %s";s:2:"ca";s:55:"La funcio %s no esta disponible, revisa el m�dul php %s";s:2:"en";s:65:"The %s function is not available, please review the php module %s";}}');
    if (!$mg[$id]) {
      $mg=array_merge(unserialize(gzinflate(base64_decode('Tc1BCoAwDATAr5T+QCsI8exDgl2kEFpIexP/biwWvIQN7CRME12VFvI7S/IbU3j3mTyq3yoFS7tqUcfiBFAnpbrIzWbKDZpL71nt4A6WPxCcyQheEjEIBkHuYR1EwTHl86vZAXtkV+/7AQ=='))),$mg);
      $mg=array_merge(unserialize(tkInBuff(6952)),$mg); 
    }
    $p=&$mg[$id];
  }
  if (!$lg)
    $lg="es";
  if ($m=&$p[$lg])
    return $m;
  else if ($m=&$p["es"])
    return $m;
  else
    return $p["en"];
}
function detLang($re,$df) {
  global $dvars;
  if ($re)
    return $re;
  if ($l=$_SESSION["lang"])
    return $l;
  $lgs=array('es'=>true,'ca'=>true,'en'=>true,'00'=>true,);
  list($acp)=explode(";",strtolower($_SERVER["HTTP_ACCEPT_LANGUAGE"]));
  foreach(explode(",",$acp) as $la)
    if ($lgs[$la])
      return $la;
  if (!$la)
    $la=substr(setlocale(LC_ALL,""),0,2);
  if ($la)
    return $la;
  else
    return $df;
}
function loadPi() {
  global $dvars, $reInst, $iip;
  if (!$c=@file_get_contents("_mkI_last_inst_83b3412d.php"))
    return false;
  if (substr($c,0,10) != "<?php //!!")
    return false;
  $reInst=true;
  @eval("?>$c<?php ");
  if (!$pdv)
    return false;
  if ($_REQUEST["nsav"])
    return false;
  foreach($dvars as $v => $vv)
    if (is_array($pd=$pdv[$v]))
      $dvars[$v]["vl"]=$pd["vl"];
  return true;
}
function savePi() {
  global $dvars, $vo, $o;
  if ($_REQUEST["nsav"] or $o["nsav"])
    return false;
  $pdv=array();
  foreach($dvars as $vv => $vvv)
    if (!$vvv["ns"])
      $pdv[$vv]["vl"]=$vo[$vv];
  $h=@fopen($fPi="_mkI_last_inst_83b3412d.php","w");
  @fwrite($h,"<?php //!!\n\$pdv=".var_export($pdv,true).";\n?>");
  @fclose($h);
  @chmod($fPi,0600);
  return true;
}