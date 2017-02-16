/*
  eSurvey javascript client
  eSurvey project
  Copyright (c) 2007-2008 Manue Mollar, Universitat Jaume I
  http://proyectostic.uji.es/pr/eSurvey
  Designed by mm AT nisu.org
  http://eSurvey.nisu.org/
  Parts of the code are copyright (c) 2003-2005 Tom Wu
  Parts of the code are copyright (c) 1999-2002 Masanao Izumo
  Distributed under the GNU GPL v3
*/

/*
  eSUrvey main class {{{
  Version 3.1
  Designed by mm AT nisu.org
  Programmed by mm AT nisu.org

  Object: eSurvey
    Constructor:
	eSurvey('<eSurveyParameters ... ', optional base64 rsa-md5 signature): creates the survey

    Public properties:
		     str name: survey name, == form name
		   bool ended: survey sending is ended (== sent, I hope)
	 obj tlog, thash, but: pointers to form elements: textarea-log, textarea-showHash, button-send
		    obj formu: pointer to DOM form element
		      extLaun: pointer to eSurveyExtensionLauncher if exists
    Public methods:
			 send: starts survey sending, --- do not overload this method
     log(str msg, bool smlin): log a message, in a different line if not smlin
     error(str msg, int code): obvious (code allows you to give other messages)
   warning(str msg, int code): obvious, *you shouldnt block javascript*
	   showHash(str hash): obvious
	       sending(int %): obvious
	chStage(string stage): called when change stage, see the code for stages

    Global vars:
	 eSvyGloPoint_<name>: points to the object after instantiation

    XML description:
	<eSurveyParameters>
	  <name>eSurvery name, only chars and numbers</name>
	  <idSvy>eSurvery id, some unique id, to differentiate the survey at ballot box level, please use only letters and numbers</idSvy>
	  <lang>language for messages, two letters</lang>
	  <svrUrl>server URL</svrUrl>
	  <svrAuth>token for authentication and authorization front to server</svrAuth>
	  <svrCert>server certificate, for signature validation, as returned by eSurvey CA, if not ready set the modulus</svrCert>
	  <svrExp>exponent of the public key of the server</svrExp>
	  <svrSCert>single certificate for total blind signature, if not set will use blind signature with 50 challenges</svrSCert>
	  <svrSExp>exponent</svrSExp>
	  <rouLen>route length (recommended 3 ... 6), 0=traceable, used to ballot box verification, -1 no blind signature, -2 no blind + no proxy </rouLen>
	  <bBxUrl>absolute URL of the ballot box (cannot be relative)</bBxUrl>
	  <bBxMod>public key (mod and exp) of the ballot box</bBxMod>
	  <bBxExp></bBxExp>
	  <bBxIMod>optional internal public key of the ballot box, should be present on e-voting</bBxIMod>
	  <bBxIExp></bBxIExp>
	  <endD>datetime (string or miliseconds) of the end of survey</endD>
	  <cloD>datetime of the ballot box recount : cloD-endD >= 600+rouLen*120, set =0 for cloD=endD+2(600+rouLen*120)</cloD>
	  <sButt>name of the send button at form</sButt>
	  <areaLog>name of a textarea to receive log, null if not available (you use your own logging or none)</areaLog>
	  <areaHash>idem for hash</areaHash>
	  <disExt>true to disable the use of browser extension</disExt>
	  <urlExt>URL of a informational page for the extension</urlExt>
	  <pause>optional: true to start eSurvey paused, call the iterate method to start</pause>
	  <pauseIfExt>optional: true to start eSurvey paused when the extension is present, call the iterate method to start</pauseIfExt>
	  <refresh>true if the extension must invite user to reload page</refresh>
	  <urlVer>URL of a page to verify Hash</urlVer>
	  <eVot>true to set eVoting behaviour</eVot>
	  <recover>optional logical, set to true to activate recovery mode</recover>
	  <minVer>min version required, use to avoid problems with old versions</minVer>
	  <skip>name of an element of the form to be skipped</skip>
	  <skip>name of another element of the form to be skipped</skip>
	</eSurveyParameters>
*/

function eSurvey(eSpars,pSig) {  

  thisVersion = 2011040401;

  this.iterate= function() {
    var i, j;
    switch (stat) {
      case 'pre':
        var ia=this.extLaun.isActive();
	switch (ia) {
	  case 0:
	    this.extLaun.activate(eSpars,pSig);
	    stat='err';
	    break;
	  case 2:
	    if(!avsd) {
	      alert(_('Cierre la extensión y se volverá a abrir'));
	      avsd=true;
	    }
	  case 3:
	    alert(_('No se pueden hacer encuestas con múltiples "tabs" en el navegador'));
	    stat='err';
	    break;
	}
	break;
      case 'ini':
	this.log(_('Iniciando'));
	if ((I=parseInt(endD)) == endD)
	  endD=I;
	if ((I=parseInt(cloD)) == cloD)
	  cloD=I;
	try {
	  endD=parseInt(Math.floor((new Date(endD)).getTime()/1000));
	  cloD=parseInt(Math.floor((new Date(cloD)).getTime()/1000));
	  if (isNaN(endD) || isNaN(cloD))
	    throw('');

	} catch(e) {
	  this.error(_('Revise las fechas'),7);
	  this.log('endD='+endD+' cloD='+cloD);
	  stat='err';
	  break;
	}
	rouLen=Math.max(rouLen,this.minRouLen);
	rouN=Math.max(2,Math.round(0.5*rouLen));
	if (rouLen < 0)
	  tstep=5;
	tol=tol*rouLen;
	if (cloD == 0)
	  cloD=endD+2*(sfy+tol);
	if (cloD-endD < sfy+tol) {
	  this.error(_('Encuesta imposible, margen insuficiente para tantos nodos'),1);
	  stat='err';
	  break;
	}
	if (this.forms)
	  var p=this.forms;
	else if (enExt)
	  var p=document.getElementById('content').contentDocument.forms;
	else
	  var p=document.forms;
	var c = 0, i, j, n, pi;
	if (p.length == 1)
	  pi=p[0];
	else {
	  for(i=0; i<p.length; i++)
	    if (p[i].name == name) {
	      pi=p[i];
	      c++;
	    }
	  if (c != 1) {
	    this.error(_('Debe haber un formulario de nombre: ')+name,4);
	    stat='err';
	    break;
	  }
	}
	this.formu=pi;
	if (!enExt) {
	  p=pi.elements;
	  for(i=0; i<p.length; i++) {
	    pi=p[i]; n=pi.name;
	    if (n == areaLog)
	      this.tlog=pi;
	    else if (n == areaHash)
	      this.thash=pi;
	    else if (n == sButt) {
	      this.but=pi;
	      pi.disabled=false;
	    }
	  }
	  if (!this.but) {
	    this.error(_('No se ha encontrado el botón'),6);
	    stat='err';
	    break;
	  }
	}
	chSt(this,'stup');
	if (recover) {
	  arr=reqS('param=rtrv');
	  var rcvr=arr.split('#eSurveyRecover#');
	  if (!rcvr[1]) {
	    this.error(_('Recuperación fallida'),21);
	    this.log(_('La respuesta fue ')+arr);
	    stat='err';
	    break;
	  }
	  while (true) {
	    pwdS=prompt(_('Introduzca el código de recuperación'));
	    if (!pwdS) {
	      stat='err';
	      break;
	    }
	    arr=new eSvyARC4(pwdS).decrypt(new eSvyBigInteger().b642bin(rcvr[0]));
	    opc=arr.split('#eSurveyRecover#');
	    if (opc[2])
	      break;
	    if (!confirm(_('Código incorrecto\n¿Desea intentarlo de nuevo?'))) {
	      stat='err';
	      break;
	    }
	  }
	  if (stat == 'err') {
	    this.but.disabled=true;
	    break;
	  }
	  opc[0]=new eSvyBigInteger(opc[0],256);
	  htkt[0]=new eSvyBigInteger(opc[1],256);
	  tkt[0]=opc[2];
	  rTick=rcvr[1];
	  this.log(_('Credenciales recuperadas'));
	}
	else
	  if ((arr=reqS('param=auth')) != 'AUTH') {
	    this.error(_('Usted no está autorizado a participar'),8);
	    this.log(_('La respuesta fue ')+arr);
	    stat='err';
	    break;
	  }
	rsa.setPublic(nisuMod,'AQAB');
	sMod=rsa.publicDecrypt(svrCert);
	if (sMod) {
	  var i=sMod.indexOf(String.fromCharCode(0));
	  this.log(_('Negociando con ')+sMod.substr(0,i));
	  sMod=sMod.substr(i+1);
	  sMod=new eSvyBigInteger(sMod,256);
	}
	else {
	  if (svrUrl.match(/^https:/)){
	      var nsp=_('No puedo verificar la identidad del servidor, pero es HTTPS');
       this.log(nsp);
   }
	  else {
	    var nsp=_('** ATENCIÓN: No puedo verificar la identidad del servidor')+_('\n\nExiste riesgo de suplantación\n\n¿Desea continuar?');
	    if (!confirm(nsp)) {
	      stat='err';
	      break;
	    }
     this.warning(nsp);
	  }
	  sMod=new eSvyBigInteger(svrCert,64); svrCert=null;
	}
	rsa.setPublic(sMod.toB64String(),svrExp);
	var estm=new Date();
	estm=new Date()-estm;
	nOpc=Math.floor(10000/estm);
	if (nOpc<10) nOpc=10;
	if (nOpc>50) nOpc=50;
	sesKey=rndG.random(21);
	var cry1=rsa.encrypt(sesKey);
	var rchal=reqS('param=vcert&chal='+encodeURIComponent(sMod.bin2b64(cry1)));
	if (des4(rchal) != 'OK vcert') {
	  this.error(_('El certificado/modulo del servidor es incorrecto'),2);
	  stat='err';
	  break;
	}
	if (pSig) {
	  pSig=pSig.replace(/^<[^>]*>(.*)<.*/,'$1');
	  if (rsa.publicDecrypt(pSig) != baseFirma(eSpars,sMod.bitLength()/8,false)) {
	    this.error(_('Firma de parámetros incorrecta'),25);
	    stat='err';
	    break;
	  }
	}
	else {
	  var nsp=_('Parámetros no firmados');
	  if (svrUrl.match(/^https:/))
	    this.log(nsp);
	  else
	    this.warning(nsp);
	}
	if (svrSCert) {
	  var sSMod=rsa.publicDecrypt(svrSCert);
	  if (!sSMod)
	    var erS=true;
	  else {
	    sSMod=new eSvyBigInteger(sSMod,256);
	    rsa.setPublic(sSMod.toB64String(),svrSExp);
	    var chal1=rndG.rndInt32().toString();
	    var cry1=rsa.encrypt(chal1);
	    var rchal=reqS('param=vscert&chal='+encodeURIComponent(sMod.bin2b64(cry1)));
	    if (rchal != chal1)
	      var erS=true;
	  }
	  if (erS) {
	    this.error(_('El certificado de la encuesta es incorrecto'),2);
	    stat='err';
	    break;
	  }
	  sMod=sSMod;
	}
	if ((bBxIMod && ((bBxIMod.length < 150) || (bBxIExp.length < 3)))
		|| ((bBxMod.length < 150) || (bBxExp.length < 3))) {
	  this.error(_('Los parámetros de la(s) urna(s) no parecen correctos'),12);
	  stat='err';
	  break;
	}
	clCor=parseInt(reqS('param=date')-new Date().getTime()/1000);
	if (rouLen <= 0) {
	  if (bBxIMod || eVot || confirm(_('Entrega directa a la urna.\n\n ==== SIN ANONIMATO ====\n\n¿Confirma?')))
	    if (rouLen < 0) {
	      I=0;
	      stat='opc';
	    }
	    else
	      stat='pop';
	  else {
	    stat='err';
	    this.but.value=_('Cancelada');
	    this.log(_('Cancelada'));
	  }
	  break;
	}
	stat='cjl';
	break;

      case 'cjl':
	this.log(_('Cogiendo la lista de nodos'));
	var onds=reqS('param=nodes').split('#eSurveyNds#');
	var sgNds=onds[0]; nds=onds[1];
	rsa.setPublic(nisuMod,'AQAB');
	if (!nds || rsa.publicDecrypt(sgNds) != md5(nds)) {
	  this.error(_('La lista de nodos es falsa o incorrecta, por favor, reintente'),3);
	  stat='err';
	  break;
	}
	var xnds=tkXML(nds);
	nds=new Array(); var pts={'id':'s','url':'s','inf':'s','wgt':'i','mod':'s','exp':'s'};
	for (var q in pts) {
	  var p=xnds.getElementsByTagName(q);
	  if (p.length == 0)
	    break;
	  for (i=0; i<p.length; i++) {
	    if (!nds[i])
	      nds[i]=new Array();
	    pp=p[i].childNodes;
	    if(pp[0])
	      if (pts[q] == 'i')
		nds[i][q]=parseInt(pp[0].nodeValue);
	      else
		nds[i][q]=pp[0].nodeValue;
	  }
	}
	var lnds=nds.length;
	if (!lnds) {
	  this.error(_('No hay nodos'),22);
	  stat='err';
	  break;
	}
	for(i=2; i<onds.length; i++) {
	  j=nds[parseInt(onds[i])];
	  if (j) {
	    j.wgt=0;
	    lnds--;
	  }
	}
	if (rouN > lnds) {
	  this.warning(_('No hay suficientes nodos para esa longitud de ruta'),10);
	  rouN=lnds;
	}
	tstep=rouN*(rouLen+1)+5;
	J=rouLen-1;
	for (i=0; i <rouN; i++) {
	  rus[i]=new Array();
	  rus[i][J]={s:-1}; trys[i]= {s:-1};
	}
	stat='rut';
	break;
      case 'rut':
	var cont=false;
	for (i=0; i <rouN; i++) {
	  if (rus[i][J].s >= 0)
	     continue;
	  if (trys[i].s == -1) {
	    while (true) {
	      var cont2=false;
	      s=rndSv();
	      for (var k=0; k<rouN; k++)
		if (trys[k].s == s) {
		  cont2=true;
		  break;
		}
	      if (!cont2)
		break;
	    }
	    trys[i].s=s;
	    s=nds[s];
	    chal=rnd31();
	    var xml='<cryp></cryp><evky></evky>'+
		    '<URL></URL>'+
		    '<chal>'+chal+'</chal>'+
		    '<pChal>'+chal+'</pChal>'+
		    '<sndD></sndD><cloD></cloD><rejD></rejD>';
	    xml='<paq version="1.1">'+xml+'<chk>'+md5(xml)+'</chk></paq>';
	    paq=phpSeal(xml,s.mod,s.exp);
	    r='param=proxy&destURL='+encodeURIComponent(s.url)+
		'&cryp[1]='+encodeURIComponent(sMod.bin2b64(paq.cryp))+
		'&evky[1]='+encodeURIComponent(sMod.bin2b64(paq.evky));
	    trys[i].rp=null; trys[i].chal=chal;
	    reqC(r,'if (rp == "") rp="error"; trys['+i+'].rp=des4(rp); ');
	    cont=true;
	  }
	  else if (trys[i].rp == null)
	    cont=true;
	  else if (trys[i].rp == '1 1:'+trys[i].chal) {
	    rus[i][J].s=trys[i].s;
	    this.log(_('Encontrado nodo ')+nds[trys[i].s].id);
	  }
	  else {
	    if (--ttry >0) {
	      nds[trys[i].s].wgt/=1000;
	      trys[i].s= -1;
	      cont=true;
	    }
	  }
	}
	if (!cont) {
	  for (i=0 ; i <rouN; i++)
	    if ((j=rus[i][J].s) >= 0)
	      break;
	  if (j < 0) {
	    this.error(_('No encuentro ni un nodo activo'),9);
	    stat='err';
	    break;
	  }
	  for (i=0 ; i <rouN; i++) {
	    if (rus[i][J].s < 0)
	      rus[i][J].s=j;
	    rus[i].esp ={ v:0, a:false, c:false };
	  }
	  stat='rrt';
	  break;
	}
	break;

      case 'rrt':
	for (i=0; i <rouN; i++) {
	  for (j=J-1; j>=0; j--) {// var ccol=0;
	    while (true) {
	      cont=false;
	      var s=rndSv();
	      if (s == rus[i][j+1].s)
		cont=true;
	      if (!cont)
		break;
	    }
	    rus[i][j]={ s: s };
	  }
	}
	stat='pop';
	break;

      case 'pop':
	stat='opc';
	I=0;
	this.log(_('Iniciando anonimato '));
	break;

      case 'opc':
	if (recover) {
	  stat='pes';
	  break;
	}
	itkt[I]=j=sMod.bin2b64(rndG.random(21));
	tkt[I]=j='<ticket>'+
		   '<idTicket>'+j+'</idTicket>'+
		   '<idSurvey>'+idSvy+'</idSurvey>'+
		   '<endTime>'+endD+'</endTime>'+
		   '<closeTime>'+cloD+'</closeTime>'+
		 '</ticket>';
	if (rouLen < 0) {
	  stat='pes';
	  break;
	}
	htkt[I]=j=baseFirma(j,sMod.bitLength()/8,true);
	opc[I]=k=new eSvyBigInteger(rndG.rndInt32()+''+rndG.rndInt32(),10);
	otkt[I]=j.multiply(k.modPowInt(new eSvyBigInteger(svrExp,64),sMod)).mod(sMod);
	if (svrSCert) {
	  stat='pes';
	  break;
	}
	if (I%5 == 0) this.log('.',true);
	if (++I == nOpc) {
	  arr=otkt.join('#');
	  this.log(_('Mostrando intenciones'));
	  stat='cop';
	}
	break;

      case 'cop':
	arr=reqS('param=tickets&hashes='+encodeURIComponent(arr));
	I=parseInt(arr);
	if (isNaN(I) || (I > nOpc-1) || (I < 0)) {
	  this.error(_('No pude negociar el anonimato, paso ')+'1',15);
	  this.log(arr);
	  stat='err';
	  break;
	}
	arr='';
	for (i=0; i<nOpc; i++)
	  if (i != I)
	    arr+='#'+opc[i]+'#'+tkt[i];
	arr=arr.substr(1);
	this.log(_('Solicitando derecho'));
	stat='top';
	break;
	
      case 'top':
	arr=reqS('param=opacities&data='+encodeURIComponent(arr)); 
	if (arr == '' || arr.substr(0,5).toLowerCase() == 'error') {
	  this.error(_('No pude negociar el anonimato, paso ')+'2',16);
	  this.log(arr);
	  stat='err';
	  break;
	}
	stat='pes';
	break;

      case 'pes':
	if (rouLen >= 0 && !recover) {
	  pwdS=sMod.bin2b64(rndG.random(30)).replace(/[^a-zA-Z0-9]/g,'').substr(0,20);
	  arr=des4(reqS('param=store&copc='+
		encodeURIComponent(sMod.bin2b64(
		new eSvyARC4(pwdS).encrypt(opc[I].toByteString()+'#eSurveyRecover#'+htkt[I].toByteString()+'#eSurveyRecover#'+tkt[I])))));
	  if (arr == '' || arr.substr(0,5).toLowerCase() == 'error') {
	    pwdS='';
	    if (eVot)
	      this.warning(_('No he podido almacenar el código de recuperación'));
	  }
	}
	stat='esp';
	avsd=false;
	chSt(this,'redy');
	this.log(_('Listo'));
	break;

      case 'esp':
	var act=false;
	if (rouLen > 0) {
	  var now=new Date().getTime()/1000;
	  for (i=0; i <rouN; i++) {
	    var p=rus[i];
	    if (p.esp.a)
	      act=true;
	    else if (p.esp.v < now) {
	      reqC('param=proxy&destURL='+encodeURIComponent(nds[p[rouLen-1].s].url)+'&extra=%26tst%3D1',
		'var p=rus['+i+'].esp; p.a=false; var n=new Date().getTime()/1000; if (des4(rp).substr(0,1) == "1") { p.c=true; p.v=n+30 } else p.v=n+5');
	      p.esp.a=true;
	      act=true;
	    }
	    else if (!p.esp.c)
	      act=true;
	  }
	}
	else
	  if (vcses++%1000 == 0)
	    reqC('param=date','');
	if (isSending) {
	  if (act) {
	    if (!avsd) {
	      this.log(_('Esperando verificación de frontales'));
	      avsd=true;
	    }
	    break;
	  }
	  stat='vft';
	  chSt(this,'sndg');
	  envd(this);
	}
	if (!act)
	  chSt(this,'redy');
	break;

      case 'vft':
	In= Math.floor(new Date().getTime()/1000+clCor);
	if (In > endD) {
	  this.log('In '+In+' enD '+endD);
	  this.error(_('El momento de participar ha pasado, no se puede enviar'),13);
	  stat='err';
	  break;
	}
	chSt(this,'crit');
	if (recover)
	  arr=rTick;
	else {
	  if (rouLen < 0) {
	    firT='';
	    stat='cur';
	    envd(this);
	    break;
	  }
	  if (svrSCert)
	    arr=reqS('param=ssign&opct='+otkt[I]);
	  else
	    arr=reqS('param=sign'); 
	  if (arr == '' || arr.substr(0,5).toLowerCase() == 'error') {
	    this.error(_('No pude negociar el anonimato, paso ')+'3',17);
	    this.log(arr);
	    stat='err';
	    break;
	  }
	}
	firT=new eSvyBigInteger(arr,10);
	firT=opc[I].modInverse(sMod).multiply(firT).mod(sMod);
	arr=firT.modPowInt(new eSvyBigInteger(svrExp,64),sMod);
	if (pwdS && !recover && this.guarda)
	  document.cookie='recov-'+idSvy+'=Y; expires='+(new Date(1000*endD)).toGMTString()+'; path=/'+pwdS;
	if (arr.toString() == htkt[I].toString()) /**** compareTo ***/
	  if (svrCert)
	    this.log(_('Firma verificada'));
	  else
	    this.log(_('Firma verificada sin certificado'));
	else {
	  this.error(_('Firma incorrecta, esto es muy grave, reclame'),14);
	  if (!recover)
	    this.mosCR(arr,false);
	  stat='err';
	  break;
	}
	firT=firT.toB64String();
	stat='ctm';
	envd(this);
	break;

      case 'ctm':
	var x,ma,an;
	for (i=0; i<rouN; i++) {
	  ma=cloD-tol, an=ma-(endD+sfy);
	  for (j=0; j<rouLen; j++) {
	    x=ma-Math.floor(Math.random()*an);
	    if (j == rouLen-1)
	      if (ma-x < sfy)
		x=ma-sfy;
	    ma=x;
	    if (j == 0)
	      if (ma < (x=sfy+In))
		ma=x;
	    rus[i][j].f=ma;
	    if (j < rouLen-1) {
	      an=ma-In;
	      x=(an-sfy)/(rouLen-j-1);
	      if (x > sfy)
	        x=an/(rouLen-j);
	      an=x;
	    }
	  }
	}
	if (rouLen > 0) {
	  this.log(_('Fechas de llegada')); 
	  for (i=0; i<rouN; i++)
	    this.log((new Date(rus[i][0].f*1000)).toString());
	}
	stat='cur';
	envd(this);
	break;

      case 'cur':
	if (bBxIMod) {
	  this.log(_('Cifrando para la urna interna'));
	  paq=phpSeal(xmlRes,bBxIMod,bBxIExp);
	  xmlRes='<results><cryp>'+sMod.bin2b64(paq.cryp)+'</cryp>'+
		 '<evky>'+sMod.bin2b64(paq.evky)+'</evky></results>';

	}
	this.log(_('Cifrando para la urna'));
	ichal=chal=rnd31();
	var xml='<survey>'+xmlFrm+xmlRes+
		  '<signedTicket>'+tkt[I]+
		    '<signature>'+firT+'</signature>'+
		  '</signedTicket>'+
		'</survey>';
	this.showHash(i=md5hex(xml));
	if (this.thash && this.guarda)
	  document.cookie='hash-'+idSvy+'=Y; expires='+(new Date(1000*(endD+432000))).toGMTString()+'; path=/'+i;
	xml='<paq version="1.0">'+xml+'<chk>'+i+'</chk>'+
		'<chal>'+ichal+'</chal>'+
	    '</paq>';
	paq=paqi=phpSeal(xml,bBxMod,bBxExp);
	if (rouLen <= 0) {
	  prm='cryp[1]='+encodeURIComponent(sMod.bin2b64(paq.cryp))+
		'&evky[1]='+encodeURIComponent(sMod.bin2b64(paq.evky));
	  if (rouLen == -2) {
	    svrUrl=bBxUrl;
	    res=reqS(prm);
	  }
	  else {
	    var extr='';
	    if (rouLen == -1)
	      extr='&extra='+encodeURIComponent(pauth);
	    prm+='&param=proxy&destURL='+encodeURIComponent(bBxUrl)+extr;
	    res=des4(reqS(prm));
	  }
	  var eql=true;
	  stat='rtu';
	  break;
	}
	I=0; J=0;
	stat='cfe';
	envd(this);
	break;
      case 'rtu':
	if (res == '1 1:'+chal) {
	  stat='fin';
	  svrUrl=oSvrUrl;
	  break;
	}
	this.mosCR(res,true);
	if (!cchal)
	  cchal=enc4(chal);
	res=reqS(prm+(eql ? '&chal='+cchal : ''));
	if (res.toLowerCase() == 'queued') {
	  eql=false;
	  this.log(_('Encolado'));
	}
	break;
      case 'cfe':
	var ru=rus[I];
	var sv=ru[J].s;
	if (J == 0)
	  this.log(_('Cifrando'));
	else
	  this.log('.',true);
	sv=nds[sv];
	pchal=rnd31();
	var xml='<cryp>'+paq.cryp+'</cryp>'+
		'<evky>'+paq.evky+'</evky>'+
		'<URL>'+((J == 0) ? bBxUrl : nds[ru[J-1].s].url)+'</URL>'+
		'<chal>'+chal+'</chal>'+
		'<pChal>'+pchal+'</pChal>'+
		'<sndD>'+ru[J].f+'</sndD>'+
		'<cloD>'+cloD+'</cloD>'+
		'<rejD>'+((J==rouLen-1) ? endD+sfy : cloD+86400)+'</rejD>';
	xml='<paq version="1.1">'+xml+'<chk>'+md5(xml)+'</chk></paq>';
	paq=phpSeal(xml,sv.mod,sv.exp);
	chal=pchal;
	J++;
	if (J == rouLen) {
	  this.log(_('Enviando a ')+sv.id);
	  ru.c=chal;
	  ru.r=null;
	  reqC(ru.p1='param=proxy&destURL='+encodeURIComponent(sv.url)+
		'&cryp[1]='+encodeURIComponent(sMod.bin2b64(paq.cryp))+
		'&evky[1]='+encodeURIComponent(sMod.bin2b64(paq.evky)),
	       ru.p2='if (rp == "") rp="error"; \
		 var x=rus['+I+']; \
		 x.r=des4(rp);\
		 if (x.r == "1 1:"+x.c) { \
		   envd('+glo+'); \
		   chSt('+glo+',"1snd"); \
		 } ');
	  I++;
	  J=0;
	  paq=paqi; chal=ichal;
	}
	if (I >= rouN)
	  stat='ver';
	  avsd=false;
	envd(this);
	break;

      case 'ver':
	var cont=false;
	for(i=0; i<rouN; i++) {
	  var x=rus[i];
	  if (x.v) continue;
	  var r=x.r;
	  if (r == '1 1:'+x.c) {
	    x.v=true;
	    continue;
	  }
	  cont=true;
	  if (r == null)
	    continue;
	  if (r.toLowerCase() == 'queued') {
	    this.log(_('Encolado'));
	    x.q=true;
	  }
	  else if (!x.cc)
	    x.cc=enc4(x.c);
	  x.r=null;
	  reqC(x.p1+(x.q ? '' : '&chal='+x.cc),x.p2);
	  this.mosCR(r,true);
	}
	if (!cont)
	  stat='fin';
	break;
      case 'fin':
	chSt(this,'snok');
	this.log(_('Operación completada con éxito'));
	if (pwdS) {
	  reqC('param=clean','');
	  if (this.guarda)
	    document.cookie='recov-'+idSvy+'=Y; expires=Thu, 07 Apr 2011 18:48:05 UTC; path=/'+pwdS;
	}
      case 'err':
	reqC('param=flush','');
	this.ended=true;
	return;
    }
    setTimeout(glo+'.iterate()',1);
  }

  function enc4(x) {
    return sMod.bin2b64(new eSvyARC4(sesKey).encrypt(String(x)));
  }
  function des4(x) {
    return new eSvyARC4(sesKey).decrypt(sMod.b642bin(x));
  }
  function baseFirma(d,l,p) {
    var x='\x30\x20\x30\x0c\x06\x08\x2a\x86\x48\x86\xf7\x0d\x02\x05\x05\x00\x04\x10'+md5(d);
    if (p) x=rsa.pkcs1pad1(x,l);
    return x;
  }
  function trim(s) {
    return s.replace(/^\s+|\s+$/g,'')
  }
  function tkXML(eSpars) {
    if (typeof(DOMParser) == 'undefined')
      DOMParser = function() {
	this.parseFromString = function(str, contentType) {
	  if (typeof(ActiveXObject) != 'undefined') {
            var xmldata = new ActiveXObject('Microsoft.XMLDOM');
            xmldata.async = false;
            xmldata.loadXML(str);
            return xmldata;
	  }
	  return null;
	}
      }
    var parser=new DOMParser();
    return parser.parseFromString(eSpars,"text/xml");
  }
  function rnd31() {
    return Math.floor(Math.random()*2147483648);
  }
  function rndSv() {
    var spe=0;
    for (var k=0; k<nds.length; k++)
      spe+=nds[k].wgt;
    if (spe < 1e-300)
      return Math.floor(Math.random()*nds.length);
    for(var x=Math.random()*spe, s=0, k=0; x >= s ; k++)
      s+=nds[k].wgt;
    k--;
    nds[k].wgt/=1000;
    return k;
  }

  function nwHttpClient () {
    var client=null;
    if (window.XMLHttpRequest)
      client=new XMLHttpRequest();
    else if (window.ActiveXObject)

      client=new ActiveXObject("Microsoft.XMLHTTP");
    return client;
  }
  function reqS (r) {
    var client = nwHttpClient();
    try {
      client.open("POST", svrUrl, false);
      client.setRequestHeader('Content-Type',
	'application/x-www-form-urlencoded');
      var avi=setTimeout(glo+'.mosCR("--",true);',10000);
      client.send(r+pauth);
      clearTimeout(avi);
    } catch (e) { stat='err'; clearTimeout(avi); return 'ERROR reqS' }
    return client.responseText;
  }
  function reqC (r,f) {
    var client = nwHttpClient();
    client.onreadystatechange=function () {
      if (client.readyState!=4)
	return;
      clearTimeout(avi);
      var rp=client.responseText;
      eval(f);
    }
    client.open("POST", svrUrl, true);
    client.setRequestHeader('Content-Type',
	'application/x-www-form-urlencoded');
    var avi=setTimeout(glo+'.mosCR("--",true);',5000);
    client.send(r+pauth);
  }
  var msgs = {
  ', continuar': {
	'ca': ', continuar',
	'en': ', continue'
    },
  ' de tipo ': {
	'ca': ' de tipus ',
	'en': ' of type '
    },
  ' no admite múltiples': {
	'ca': ' no admiteix multiples',
	'en': ' do no admit multiple'
    },
  ' requerido': {
	'ca': ' requerid',
	'en': ' required'
    },
  'Anote el ticket para reclamar:': {
	'ca': 'Anote el ticket per a reclamar:',
	'en': 'Anotate the ticket to claim:'
    },
  'Anote este recibo: ': {
	'ca': 'Anote aquest rebut: ',
	'en': 'Anotate this receipt: '
    },
  '** ATENCIÓN: No puedo verificar la identidad del servidor': {
	'ca': "** ATENCIÓ: No puc verificar l'identitat del servidor",
	'en': '** WARNING: The server identity cannot be verified'
    },
  'Aviso': {
	'ca': 'Avis',
	'en': 'Warning'
    },
  'Cancelada': {
	'ca': 'Cancel.lada',
	'en': 'Cancelled'
    },
  'Cierre la extensión y se volverá a abrir': {
	'ca': "Tanque l'extensió i es tornarà a obrir",
	'en': 'Please close the extension and it will re-open'
    },
  'Cifrando': {
	'ca': 'Xifrant',
	'en': 'Encrypting'
    },
  'Cifrando para la urna': {
	'ca': 'Xifrant per a la urna',
	'en': 'Encrypting for the ballot box'
    },
  'Cifrando para la urna interna': {
	'ca': 'Xifrant per a la urna interna',
	'en': 'Encrypting for the internal ballot box'
    },
  'Código de recuperación ': {
	'ca': 'Codi de recuperació ',
	'en': 'Recovery code '
    },
  'Código incorrecto\n¿Desea intentarlo de nuevo?': {
	'ca': 'Codi incorrecte\nDesitja intentar-ho de nou?',
	'en': 'Invalid code\nTry again?'
    },
  'Cogiendo la lista de nodos': {
	'ca': 'Agafant la llista de nodes',
	'en': 'Fetching the node list'
    },
  'Cópielo y pégelo aparte y manténgalo en secreto': {
	'ca': "Copie'l i pegue'l apart i mantinga'l en secret",
	'en': 'Copy and paste it and keep it in secret'
    },
  'Credenciales recuperadas': {
	'ca': 'Credencials recuperades',
	'en': 'Credentials recovered'
    },
  'Debe haber un formulario de nombre: ': {
	'ca': 'Deu de haver un formulari de nom: ',
	'en': 'A form must exists, with name: '
    },
  'ERROR': {
	'ca': 'ERROR',
	'en': 'ERROR'
    },
  'El certificado/modulo del servidor es incorrecto': {
	'ca': 'El certificat/modul del servidor es incorrecte',
	'en': 'Invalid server module/certificate'
    },
  'El certificado de la encuesta es incorrecto': {
	'ca': "El certificat de l'enquesta es incorrecte",
	'en': 'Invalid survey certificate'
    },
  'El momento de participar ha pasado, no se puede enviar': {
	'ca': 'El moment de participar ha passat, no es pot enviar',
	'en': 'The time for participating is expired, cannot send'
    },
  'Encolado': {
	'ca': 'Encolat',
	'en': 'Queued'
    },
  'Encontrado nodo ': {
	'ca': 'Trobat node ',
	'en': 'Found node '
    },
  'Encuesta imposible, margen insuficiente para tantos nodos': {
	'ca': 'Enqueta imposible, marge insuficient per a tants nodes',
	'en': 'Impossible survey, margin insufficient for so many nodes'
    },
  'Entrega directa a la urna.\n\n ==== SIN ANONIMATO ====\n\n¿Confirma?': {
	'ca': 'Entrega directa a la urna,\n\n ==== SENSE ANONIMAT ====\n\nConfirma?',
	'en': 'Delivery direct to the ballot box.\n\n ==== WITHOUT ANONYMITY ====\n\nDo you confirm?'
    },
  'Enviando a ': {
	'ca': 'Enviant a ',
	'en': 'Sending to '
    },
  'Envío completo': {
	'ca': 'Enviament completat',
	'en': 'Sending completed'
    },
  'Esperando verificación de frontales': {
	'ca': 'Esperant la verificació de frontals',
	'en': 'Waiting for front verification'
    },
  'Espere ... ': {
	'ca': 'Espere ... ',
	'en': 'Wait ... '
    },
  'Espere un segundo': {
	'ca': 'Espere un segon',
	'en': 'Wait a second'
    },
  'Esta es su participación': {
	'ca': 'Aquesta es la seva participació',
	'en': 'This is your participation'
    },
  'Este error no ha debido suceder, reclame': {
	'ca': 'Aquest error no ha degut sucedir, reclame',
	'en': 'This erreor should not happend, claim'
    },
  'Este programa es incompatible con su Navegador/Plataforma': {
	'ca': 'Aquest programa es incompatible amb el seu Navegador/Plataforma',
	'en': 'This program is not compatible with your Browser/Platform'
    },
  '\n\nExiste riesgo de suplantación\n\n¿Desea continuar?': {
	'ca': '\n\nExisteix risc de suplantació\n\nDesitja continuar?',
	'en': '\n\nRisk of impersonation\n\nDo you want to continue?'
    },
  'Fechas de llegada': {
	'ca': 'Dades de arribada',
	'en': 'Arrival dates'
    },
  'Finalizando ... ': {
	'ca': 'Finalitzant ... ',
	'en': 'Ending ... '
    },
  'Firma de parámetros incorrecta': {
        'ca': 'Signatura de paràmetres incorrecta ',
        'en': 'Incorrect parameter signature'
    },
  'Firma incorrecta, esto es muy grave, reclame': {
	'ca': 'Signatura incorrecta, aço es molt greu, reclame',
	'en': 'Incorrect signature, this is very wrong, claim'
    },
  'Firma verificada': {
	'ca': 'Signatura verificada',
	'en': 'Signature verifyed'
    },
  'Firma verificada sin certificado': {
        'ca': 'Signatura verificada sense certificat',
        'en': 'Signature verifyed without certificate'
    },
  'Ignorado elemento de la encuesta ': {
	'ca': "Ignorant element de l'enquesta ",
	'en': 'Ignoring survey element '
    },
  'Iniciando': {
	'ca': 'Iniciant',
	'en': 'Initiating'
    },
  'Iniciando anonimato ': {
	'ca': 'Iniciant anonimat ',
	'en': 'Initiating anonimity '
    },
  'Introduzca el código de recuperación': {
	'ca': 'Intouduiu el codi de recuperació',
	'en': 'Enter the recovey code'
    },
  'La lista de nodos es falsa o incorrecta, por favor, reintente': {
	'ca': 'La llista de nodes es falsa o incorrecta, per favor, reintente',
	'en': 'The node list is fake or incorrect, please, retry'
    },
  'La respuesta fue ': {
	'ca': 'La resposta ha estat ',
	'en': 'The response was '
    },
  'Listo': {
	'ca': 'Enllestit',
	'en': 'Ready'
    },
  'Los parámetros de la(s) urna(s) no parecen correctos': {
	'ca': 'El paràmetres de la/les urna/urnes no pareixen correctes',
	'en': 'The ballot box(es) parameters seem to be wrong'
    },
  'Mostrando intenciones': {
	'ca': 'Mostrant intencions',
	'en': 'Showing intentions'
    },
  'Negociando con ': {
	'ca': 'Negociant amb ',
	'en': 'Negotiating with '
    },
  'No cierre el navegador, seguimos intentando': {
	'ca': 'No tanque el navegador, seguim intentant',
	'en': 'Do not close the browser, we are still trying'
    },
  'No encuentro ni un nodo activo': {
	'ca': 'No trove ni un node actiu',
	'en': 'I can not find either an active node'
    },
  'No hay nodos': {
	'ca': 'No hi ha nodes',
	'en': 'There arent nodes'
    },
  'No hay suficientes nodos para esa longitud de ruta': {
	'ca': 'No hi han prou nodes per a eixa llongitud de ruta',
	'en': 'There arent enough nodes for that route length'
    },
  'No he podido almacenar el código de recuperación': {
	'ca': 'No he pogut enmagatzemar el codi de recuperació',
	'en': 'I couldn\'t store the recovery code'
    },
  'No pude negociar el anonimato, paso ': {
	'ca': "No puc negociar l'anonimat, pas ",
	'en': 'I couldn\'t negotiate the anonimity, pass '
    },
  'No puedo verificar la identidad del servidor, pero es HTTPS': {
	'ca': "No puc verificar l'identitat del servidor, pero es HTTPS",
	'en': 'I cannot verify the server identity, but it is HTTPS'
    },
  'No se pueden hacer encuestas con múltiples "tabs" en el navegador': {
	'ca': 'No es poden fer enquestes amb multiples "tabs" en el navegador',
	'en': 'Surveys with multiple "tabs" in the browser are forbiden'
    },
  'No se ha encontrado el botón': {
	'ca': 'No se ha trovat el botó',
	'en': 'Button not found'
    },
  'Nombre de encuesta incorrecto': {
	'ca': "Nom d\'enquesta incorrecte",
	'en': 'Incorrect survey name'
    },
  'Operación completada con éxito': {
	'ca': 'Operació completada amb exit',
	'en': 'Operation successfully completed'
    },
  'Parámetros no firmados': {
        'ca': 'Paràmetres no signats',
        'en': 'Unsigned parameters'
    },
  'Participar': {
	'ca': 'Participar',
	'en': 'Participate'
    },
  'Primer parámetro: XML': {
	'ca': 'Primer paramete: XML',
	'en': 'First parameter: XML'
    },
  'Recuperación fallida': {
	'ca': 'Recuperació fallida',
	'en': 'Recovey failed'
    },
  'Revise las fechas': {
	'ca': 'Revise les dates',
	'en': 'Review the dates'
    },
  'Se aprecian problemas en la red': {
	'ca': 'Se aprecien problemes en la xarxa',
	'en': 'It seems there are network problems'
    },
  'Se requiere una versión de eSurvey superior a ': {
	'ca': 'Es requereix una versió de eSurvey superior a ',
	'en': 'The required eSurvey version is '
    },
  'Solicitando derecho': {
	'ca': 'Sol.licitant dret',
	'en': 'Requesting right'
    },
  'Usted no está autorizado a participar': {
	'ca': 'Voste no esta autoritzat a participar',
	'en': 'You are not authorized to participate'
    },
  'Votación sin urna interna y sin firma ciega': {
	'ca': 'Votació sense urna interna i sense firma cega',
	'en': 'Polling without internal ballot box and without blind signature'
    },
  'XML mal definido': {
	'ca': 'XML mal definit',
	'en': 'Worng XML'
    },
  'y consúltelo en ': {
      	'ca': "i consulte'l en ",
	'en': 'and review it on '
    }
  };
  function _(m) {
    var mm='';
    if (lang=='es')
      return m;
    if (msgs[m]) {
      mm=msgs[m][lang];
      if (!mm)
	mm=msgs[m].en;
    }
    if (mm)
      return mm;
    else
      return m;
  }
  this._= _;
  this.mosCR = function (r,i) {
    if (avsd)
      return;
    avsd=true;
    if (i) {
      this.warning(_('Se aprecian problemas en la red')+' '+r);
      this.log(_('No cierre el navegador, seguimos intentando'));
    }
    if (pwdS)
      this.log(_('Código de recuperación ')+pwdS+'\n'+_('Cópielo y pégelo aparte y manténgalo en secreto'));
  }
  this.log= function (m,s) {
    if (this.tlog) {
      this.tlog.value+=((!s) ? "\r\n" : '')+m;
      try {
	this.tlog.scrollTop=1000000;
      } catch(e) { }
    }
    else
      try {
	m=m.split('\r\n');
	window.status=m[m.length-1];
      } catch(e) { }
  }
  function ponCol(e,c) {
    if (e.but.style)
      e.but.style.color=c;
  }
  this.warning= function (m,c) {
    if (this.tlog) {
      this.log(
	'_ _ _ ____ ____ _  _ _ _  _ ____\r\n'+
	'| | | |__| |__/ |\\ | | |\\ | | __\r\n'+
	'|_|_| |  | |  \\ | \\| | | \\| |__]\r\n\r\n\r\n'+m);
      if (this.tlog.style)
	this.tlog.style.visibility='visible';
    }
    else
      this.log(m);
    if (this.but) {
      this.but.value=_('Aviso');
      ponCol(this,'red');
    }
  }
  this.error= function (m,c) {
    if (this.tlog) {
      this.log(
	'____ ____ ____ ____ ____\r\n'+
	'|___ |__/ |__/ |  | |__/\r\n'+
	'|___ |  \\ |  \\ |__| |  \\\r\n\r\n\r\n'+m);
      if (this.tlog.style)
	this.tlog.style.visibility='visible';
    }
    else
      this.log(m);
    if (this.but) {
      this.but.value=_('ERROR');
      ponCol(this,'red');
    }
    alert('\r\n\r\n      ***** ERROR *****\r\n\r\n'+m+'\r\n\r\n ');
  }
  this._fatalError= function (m,c) {
    if (c)
      m+='\r\n\r\n'+
	_('Anote el ticket para reclamar:')+
	'\r\n\r\n'+c;
    else
      m+='\r\n\r\n'+
	_('Este error no ha debido suceder, reclame');
    this.error(m,100);
  }
  this.showHash= function (h) {
    if (!urlVer)
      return;
    var s=_('Anote este recibo: ')+'\r\n\r\n'+h+'\r\n\r\n'+_('y consúltelo en ')+urlVer;
    if (this.thash)
      this.thash.value=s;
    else {
      this.log(s);
      if (bBxIExp)
	alert(s);
    }
  }
  this.cancelV= function() {
  }
  this.stage;
  function chSt(t,st) {
    t.stage=st;
    t.chStage(st);
  }
  this.chStage= function(st) {
    switch (st) {
      case 'stup':
	this.but.value=_('Participar');
	ponCol(this,'black');
	break;
      case 'quik':
	this.but.value=_('Espere ... ');
	ponCol(this,'black');
	break;
      case 'redy':
	if (!isSending)
	  this.but.value=_('Participar');
	ponCol(this,'green');
	break;
      case 'sndg':
	ponCol(this,'cyan');
	break;
      case 'crit':
	ponCol(this,'magenta');
	break;
      case '1snd':
	ponCol(this,'darkOrange');
	break;
      case 'snok':
	ponCol(this,'blue');
	this.but.value=_('Envío completo');
	if (this.refresh) {
	  this.but.value+=_(', continuar');
	  this.but.disabled=false;
	}
	break;
      case 'close':
	if (!isSending)
	  stat='err';
	break;
    }
  }
  function envd (t) {
    t.sending(Math.round(cstep++*100/tstep));
  }
  this.sending= function (per) {
    if (this.stage == '1snd')
      this.but.value=_('Finalizando ... ')+per+'%';
    else
      this.but.value=_('Espere ... ')+per+'%';
  }
  this.send= function () {
    if (this.ended)
      return false;
    var p, pi, pp, ppp;
    p=this.formu;
    if (!p) {
      alert(_('Espere un segundo')); 
      return true;
    }
    this.but.disabled=true;
    if (stat != 'esp')
      chSt(this,'quik');
    var c = 0, i, j, v, n;
    var entEnc= new Array();
    xmlFrm='<form>';
    var fatr={ action : window.location.href, method : 'get'};
    for(i in fatr)
      xmlFrm+='<'+i+'>'+encodeURIComponent((p[i]) ? p[i] : fatr[i])+'</'+i+'>';
    xmlFrm+='</form>';
    var txtRes='';
    xmlRes='<results>';
    p=p.elements;
    for(i=0; i<p.length; i++) {
      pp=p[i]; n=pp.name;
      if (!n) continue;
      if (evit[n]) continue;
      switch(pp.type) {
	case 'radio':
	case 'checkbox':
	  if (!pp.checked)
	    break;
	case 'text':
	case 'password':
	case 'hidden':
	case 'submit':
	case 'textarea':
	  entEnc[c++]={ n: n , v: pp.value };
	  break;
	case 'select-one':
	case 'select-multiple':
	  pp=p[i]; n=pp.name;
	  if (!n) continue;
	  pp=pp.options;
	  for(j=0; j<pp.length; j++) {
	    ppp=pp[j];
	    if (!ppp.selected) continue;
	    v=ppp.value;
	    if (v == '')
	      v=ppp.text;
	    entEnc[c++]={ n: n , v: v };
	  }
	  break;
	default:
	  this.log(_('Ignorado elemento de la encuesta ')+n+_(' de tipo ')+pp.type);
      }
    }
    for(i=0; i<entEnc.length; i++) {
      var en=entEnc[i].n, ev=entEnc[i].v;
      xmlRes+='<question><name>'+encodeURIComponent(en)+'</name><response>'+encodeURIComponent(ev)+'</response></question>';
      if (ev != '') {
        ev=ev.replace(/<br\/>/g,'\n');
	var bb='';
	for(l=en.length+2; l>0; l--)
	  bb+=' ';
	ev=ev.replace(/\n/g,'\n'+bb);
        txtRes+="\n"+en+': '+ev;
      }
    }
    xmlRes+='</results>';
    if (eVot) {
      var war='';
      if (!bBxIMod && (rouLen <0))
        war+='\n'+_('Votación sin urna interna y sin firma ciega');
      if (!confirm(_('Esta es su participación')+'\n'+txtRes+war)) {
        this.but.disabled=false;
        this.cancelV();
        return true;
      }
    }
    isSending=true;
    return true;
  }

  function phpSeal(data,n,e) {
    var S=rndG.random(16);
    var rsa = new eSvyRSA();
    rsa.setPublic(n,e);
    var arc=new eSvyARC4(S);
    return { cryp: arc.encrypt(data), evky: rsa.encrypt(S) };
  }

  if (!eSpars) {
    this.error(_('Primer parámetro: XML'),18);
    return;
  }
  var arr, arrr;
  var prs={ 'lang': { d: 'en' },
	    'name': { d: '' },
	   'idSvy': {  },
	  'svrUrl': {  },
	 'svrAuth': {  },
	 'svrCert': {  },
	  'svrExp': {  },
	'svrSCert': { d: null },
	 'svrSExp': { d: null },
	   'keepA': { d: false },
	  'rouLen': { d: 3, i: true },
	    'vNod': { d: false },
	  'bBxUrl': {  },
	  'bBxMod': {  },
	  'bBxExp': {  },
	 'bBxIMod': { d: null },
	 'bBxIExp': { d: null },
	    'eVot': { d: false },
	    'endD': {  },
	    'cloD': {  },
	   'sButt': { d: null },
	 'areaLog': { d: null },
	'areaHash': { d: null },
	    'skip': { m: true, d:null },
	  'urlExt': { d: 'http://eSurvey.nisu.org/' },
	  'urlVer': { d: null },
	  'disExt': { d: false },
	   'pause': { d: false },
      'pauseIfExt': { d: false },
	 'refresh': { d: false },
	  'minVer': { d: 0, i: true },
	 'recover': { d: false } };
  var iPars=tkXML(eSpars);
  var lang='en';
  if (iPars.getElementsByTagName('eSurveyParameters').length == 0) {
    this.error(_('XML mal definido'),19);
    return;
  }
  for (var i in prs) {
    var p=iPars.getElementsByTagName(i);
    var d=prs[i], ll=p.length;
    if (ll == 0) {
      if (typeof(d.d) == 'undefined') { this.error(i+_(' requerido'),20); return; }
      eval ('var '+i+'=d.d');
    }
    else {
      if (ll == 1) {
        p=p[0].childNodes;
	if (!p[0]) { this.error(i+_(' requerido'),20); return; }
	var v=trim(p[0].nodeValue);
	if (d.i)
	  v=parseInt(v);
	eval ('var '+i+'=v');
      }
      else {
	if (!d.m) { this.error(i+_(' no admite múltiples'),20); return; }
	eval ('var '+i+'= new Array()');
	for (var l=0; l<ll; l++) {
	  var pp=p[l].childNodes;
	  if (pp[0]) {
	    var v=trim(pp[0].nodeValue);
	    if (d.i)
	      v=parseInt(v);
	    eval (i+'[l]=v');
	  }
	}
      }
    }
  }
  if ((typeof(minVer) != 'undefined') && (minVer > thisVersion)) {
    this.error(_('Se requiere una versión de eSurvey superior a ')+minVer,24);
    return;
  }
  this.lang=lang;
  this.urlExt=urlExt;
  this.urlVer=urlVer;
  this.refresh=refresh;

  var rndG=eSvyPrng();
  var md5=new eSvyDigester();
  var md5hex=md5.md5hex;
  var md5=md5.md5;

  var glo='eSvyGloPoint_'+name+rndG.rndInt32();
  var sfy=600, tol=120;
  this.name=glo;
  var enExt=false;
  try { enExt=(typeof(document.createElement('menupopup').pack) == 'string'); } catch (e) { }
  if ((typeof(eSurveyExtensionLauncher) == 'function') &&
      (!enExt) && (!disExt)) {
    this.extLaun=new eSurveyExtensionLauncher();
    var stat = 'pre';
  }
  else {
    this.extLaun=null, stat = 'ini';
  }
  var avsd=false;
  var isSending=false;
  this.ended=false;
  var ichal, chal, cchal, pchal;
  var rus=new Array(), nds=null;
  var I,J;
  var opc= new Array(), otkt=new Array(), tkt= new Array(), itkt= new Array(), htkt= new Array(), nOpc;
  var encXml,rouN,tstep,cstep=0; this.minRouLen=-2;
  var In=0;
  var trys=new Array(), ttry=10;
  var paq=null, paqi=null;
  var clCor;
  var sMod=1, firT, pwdS, rTick;
  var vcses=1;
  var nisuMod='uq30dPXoErEwqSHDZlVLVxFipn21GkIGH/aVKybMgioz8bISlMCf79TM+lh//0lqBpLBWvE5HpDhYc+A8H4AWjfWblOmLA3WG5CKJo4TJrmSwKuTMtDkRM7G2NUoucIUYghbvr5o5WChH7ggemGG8kDBISluuVjs4xQbtDGTb5dapKA0XZ/3OaQvnAmGpcOMSDFFIO/vFZ9JSA9N4oZ5dBCsf6Uy3/VQc7Z+oD1BUQSKUFgHsTU7vN8f/xeqe/KFxHvAQGg8LaogMWxLcuZic2p/61EBjRWfFdsnj1TrY+hObR3L/TH4GbOculdLWDOhYPB2i+VhvgA/Nki0lIO71w==';
  if ('2322742424' != new eSvyBigInteger('2322742424',10).toString()) {
    this.error(_('Este programa es incompatible con su Navegador/Plataforma'),23);
    return;
  }
  var rsa=new eSvyRSA();
  var sesKey;
  var evit= new Array();
  for (var i in skip)
    evit[skip[i]]=true;
  evit[sButt]=true;
  if (areaLog)
    evit[areaLog]=true;
  if (areaHash)
    evit[areaHash]=true;
  var pauth='&token='+encodeURIComponent(svrAuth)+'&idsvy='+encodeURIComponent(idSvy);
  var res='',prm='',oSvrUrl=svrUrl;
  var xmlFrm='', xmlRes='';
  this.guarda=true;
  try {
    eval(glo+'=this;');
  } catch(e) { this.error(_('Nombre de encuesta incorrecto'),5); return; }

  if (!pause && !(pauseIfExt && this.extLaun))
    setTimeout(glo+'.iterate()',100);
}



/*
  Crypto library
  Based in the Tom Wu software
  Programmed by paco AT nisu.org

*/







/********* ejemplos de uso  **********************

cc1 = '3q2+7+4=';

cc = new eSvyBigInteger(cc1,64);

cc.toString(16);


dd1 = 'deadbeefee';

dd = new eSvyBigInteger(dd1,16);

dd.toB64String();
dd.toString(64);
dd.toString(256);



*************************************************/



function eSvyBigInteger(a,b){


  /**********  Antigua Clase BigInteger   **************/

  var dbits;

  var canary = 0xdeadbeefcafe;
  var j_lm = ((canary&0xffffff)==0xefcafe);

  function BI(a,b) {
    if(a != null)
      if(b == null && "string" != typeof a) this.fromString(a,256);
      else this.fromString(a,b);
  }

  function nbi() { return new BI(null); }

  
  function am1(i,x,w,j,c,n) {
    while(--n >= 0) {
      var v = x*this[i++]+w[j]+c;
      c = Math.floor(v/0x4000000);
      w[j++] = v&0x3ffffff;
    }
    return c;
  } 
  function am2(i,x,w,j,c,n) {

    var xl = x&0x7fff, xh = x>>15;
    while(--n >= 0) {
      var l = this[i]&0x7fff;
      var h = this[i++]>>15;
      var m = xh*l+h*xl;
      l = xl*l+((m&0x7fff)<<15)+w[j]+(c&0x3fffffff);
      c = (l>>>30)+(m>>>15)+xh*h+(c>>>30);
      w[j++] = l&0x3fffffff;
    }
    return c;
  }
  function am3(i,x,w,j,c,n) {
    var xl = x&0x3fff, xh = x>>14;
    while(--n >= 0) {
      var l = this[i]&0x3fff;
      var h = this[i++]>>14;
      var m = xh*l+h*xl;
      l = xl*l+((m&0x3fff)<<14)+w[j]+c;
      c = (l>>28)+(m>>14)+xh*h;
      w[j++] = l&0xfffffff;
    }
    return c;
  }
  if(j_lm && (navigator.appName == "Microsoft Internet Explorer")) {
    BI.prototype.am = am2;
    dbits = 30;
  }
  else if(j_lm && (navigator.appName != "Netscape")) {
    BI.prototype.am = am1;
    dbits = 26;
  }
  else {
    BI.prototype.am = am3;
    dbits = 28;
  }

  BI.prototype.DB = dbits;
  BI.prototype.DM = ((1<<dbits)-1);
  BI.prototype.DV = (1<<dbits);

  var BI_FP = 52;
  BI.prototype.FV = Math.pow(2,BI_FP);
  BI.prototype.F1 = BI_FP-dbits;
  BI.prototype.F2 = 2*dbits-BI_FP;

  var BI_RM = "0123456789abcdefghijklmnopqrstuvwxyz";
  var BI_RC = new Array();
  var rr,vv;
  rr = "0".charCodeAt(0);
  for(vv = 0; vv <= 9; ++vv) BI_RC[rr++] = vv;
  rr = "a".charCodeAt(0);
  for(vv = 10; vv < 36; ++vv) BI_RC[rr++] = vv;
  rr = "A".charCodeAt(0);
  for(vv = 10; vv < 36; ++vv) BI_RC[rr++] = vv;

  function int2char(n) { return BI_RM.charAt(n); }

  function intAt(s,i) {
    var c = BI_RC[s.charCodeAt(i)];
    return (c==null)?-1:c;
  }
  
  function bnpCopyTo(r) {
    for(var i = this.t-1; i >= 0; --i) r[i] = this[i];
    r.t = this.t;
    r.s = this.s;
  }

  function bnpFromInt(x) {
    this.t = 1;
    this.s = (x<0)?-1:0;
    if(x > 0) this[0] = x;
    else if(x < -1) this[0] = x+DV;
    else this.t = 0;
  }

  function nbv(i) { var r = nbi(); r.fromInt(i); return r; }

  function bnpClamp() {
    var c = this.s&this.DM;
    while(this.t > 0 && this[this.t-1] == c) --this.t;
  }

  function bnToString(b) {
    if(this.s < 0) return "-"+this.negate().toString(b);
    var k;
    if(b == 16) k = 4;
    else if(b == 8) k = 3;
    else if(b == 2) k = 1;
    else if(b == 32) k = 5;
    else if(b == 4) k = 2;
    else return this.toRadix(b);
    var km = (1<<k)-1, d, m = false, r = "", i = this.t;
    var p = this.DB-(i*this.DB)%k;
    if(i-- > 0) {

      if(p < this.DB && (d = this[i]>>p) > 0) { m = true; r = int2char(d); }
      while(i >= 0) {
	if(p < k) {
	  d = (this[i]&((1<<p)-1))<<(k-p);
	  d |= this[--i]>>(p+=this.DB-k);
	}
	else {
	  d = (this[i]>>(p-=k))&km;
	  if(p <= 0) { p += this.DB; --i; }
	}
	if(d > 0) m = true;
	if(m) r += int2char(d);
      }
    }
    return m?r:"0";
  }
  
  function bnNegate() { var r = nbi(); BI.ZERO.subTo(this,r); return r; }

  function bnAbs() { return (this.s<0)?this.negate():this; }

  function bnCompareTo(a) {
    var r = this.s-a.s;
    if(r != 0) return r;
    var i = this.t;
    r = i-a.t;
    if(r != 0) return r;
    while(--i >= 0) if((r=this[i]-a[i]) != 0) return r;
    return 0;

  }

  function nbits(x) {
    var r = 1, t;
    if((t=x>>>16) != 0) { x = t; r += 16; }
    if((t=x>>8) != 0) { x = t; r += 8; }
    if((t=x>>4) != 0) { x = t; r += 4; }
    if((t=x>>2) != 0) { x = t; r += 2; }
    if((t=x>>1) != 0) { x = t; r += 1; }


    return r;
  }
  
  function bnBitLength() {
    if(this.t <= 0) return 0;
    return this.DB*(this.t-1)+nbits(this[this.t-1]^(this.s&this.DM));
  }

  function bnpDLShiftTo(n,r) {
    var i;
    for(i = this.t-1; i >= 0; --i) r[i+n] = this[i];
    for(i = n-1; i >= 0; --i) r[i] = 0;
    r.t = this.t+n;
    r.s = this.s;
  }

  function bnpDRShiftTo(n,r) {
    for(var i = n; i < this.t; ++i) r[i-n] = this[i];
    r.t = Math.max(this.t-n,0);
    r.s = this.s;
  }

  function bnpLShiftTo(n,r) {
    var bs = n%this.DB;
    var cbs = this.DB-bs;
    var bm = (1<<cbs)-1;
    var ds = Math.floor(n/this.DB), c = (this.s<<bs)&this.DM, i;
    for(i = this.t-1; i >= 0; --i) {
      r[i+ds+1] = (this[i]>>cbs)|c;
      c = (this[i]&bm)<<bs;
    }
    for(i = ds-1; i >= 0; --i) r[i] = 0;
    r[ds] = c;
    r.t = this.t+ds+1;
    r.s = this.s;
    r.clamp();
  }

  function bnpRShiftTo(n,r) {
    r.s = this.s;
    var ds = Math.floor(n/this.DB);
    if(ds >= this.t) { r.t = 0; return; }
    var bs = n%this.DB;
    var cbs = this.DB-bs;
    var bm = (1<<bs)-1;
    r[0] = this[ds]>>bs;
    for(var i = ds+1; i < this.t; ++i) {
      r[i-ds-1] |= (this[i]&bm)<<cbs;
      r[i-ds] = this[i]>>bs;
    }
    if(bs > 0) r[this.t-ds-1] |= (this.s&bm)<<cbs;
    r.t = this.t-ds;
    r.clamp();
  }

  function bnpSubTo(a,r) {
    var i = 0, c = 0, m = Math.min(a.t,this.t);
    while(i < m) {
      c += this[i]-a[i];
      r[i++] = c&this.DM;
      c >>= this.DB;
    }
    if(a.t < this.t) {
      c -= a.s;
      while(i < this.t) {
	c += this[i];
	r[i++] = c&this.DM;
	c >>= this.DB;
      }
      c += this.s;
    }
    else {
      c += this.s;
      while(i < a.t) {
	c -= a[i];
	r[i++] = c&this.DM;
	c >>= this.DB;
      }
      c -= a.s;
    }
    r.s = (c<0)?-1:0;
    if(c < -1) r[i++] = this.DV+c;
    else if(c > 0) r[i++] = c;
    r.t = i;
    r.clamp();
  }

  function bnpMultiplyTo(a,r) {
    var x = this.abs(), y = a.abs();
    var i = x.t;
    r.t = i+y.t;
    while(--i >= 0) r[i] = 0;
    for(i = 0; i < y.t; ++i) r[i+x.t] = x.am(0,y[i],r,i,0,x.t);
    r.s = 0;

    r.clamp();
    if(this.s != a.s) BI.ZERO.subTo(r,r);
  }

  function bnpSquareTo(r) {
    var x = this.abs();
    var i = r.t = 2*x.t;
    while(--i >= 0) r[i] = 0;
    for(i = 0; i < x.t-1; ++i) {
      var c = x.am(i,x[i],r,2*i,0,1);
      if((r[i+x.t]+=x.am(i+1,2*x[i],r,2*i+1,c,x.t-i-1)) >= x.DV) {
	r[i+x.t] -= x.DV;
	r[i+x.t+1] = 1;
      }
    }
    if(r.t > 0) r[r.t-1] += x.am(i,x[i],r,2*i,0,1);
    r.s = 0;
    r.clamp();
  }

  function bnpDivRemTo(m,q,r) {

    var pm = m.abs();
    if(pm.t <= 0) return;
    var pt = this.abs();
    if(pt.t < pm.t) {
      if(q != null) q.fromInt(0);
      if(r != null) this.copyTo(r);

      return;
    }
    if(r == null) r = nbi();
    var y = nbi(), ts = this.s, ms = m.s;
    var nsh = this.DB-nbits(pm[pm.t-1]);
    if(nsh > 0) { pm.lShiftTo(nsh,y); pt.lShiftTo(nsh,r); }
    else { pm.copyTo(y); pt.copyTo(r); }
    var ys = y.t;
    var y0 = y[ys-1];
    if(y0 == 0) return;
    var yt = y0*(1<<this.F1)+((ys>1)?y[ys-2]>>this.F2:0);
    var d1 = this.FV/yt, d2 = (1<<this.F1)/yt, e = 1<<this.F2;
    var i = r.t, j = i-ys, t = (q==null)?nbi():q;
    y.dlShiftTo(j,t);
    if(r.compareTo(t) >= 0) {
      r[r.t++] = 1;
      r.subTo(t,r);
    }
    BI.ONE.dlShiftTo(ys,t);
    t.subTo(y,y);
    while(y.t < ys) y[y.t++] = 0;
    while(--j >= 0) {     
      var qd = (r[--i]==y0)?this.DM:Math.floor(r[i]*d1+(r[i-1]+e)*d2);
      if((r[i]+=y.am(0,qd,r,j,0,ys)) < qd) {
	y.dlShiftTo(j,t);
	r.subTo(t,r);
	while(r[i] < --qd) r.subTo(t,r);
      }
    }
    if(q != null) {
      r.drShiftTo(ys,q);
      if(ts != ms) BI.ZERO.subTo(q,q);
    }
    r.t = ys;
    r.clamp();
    if(nsh > 0) r.rShiftTo(nsh,r);
    if(ts < 0) BI.ZERO.subTo(r,r);
  }

  function bnMod(a) {
    var r = nbi();
    this.abs().divRemTo(a,null,r);
    if(this.s < 0 && r.compareTo(BI.ZERO) > 0) a.subTo(r,r);
    return r;
  }

  function Classic(m) { this.m = m; }
  function cConvert(x) {
    if(x.s < 0 || x.compareTo(this.m) >= 0) return x.mod(this.m);
    else return x;
  }
  function cRevert(x) { return x; }
  function cReduce(x) { x.divRemTo(this.m,null,x); }
  function cMulTo(x,y,r) { x.multiplyTo(y,r); this.reduce(r); }
  function cSqrTo(x,r) { x.squareTo(r); this.reduce(r); }

  Classic.prototype.convert = cConvert;
  Classic.prototype.revert = cRevert;
  Classic.prototype.reduce = cReduce;
  Classic.prototype.mulTo = cMulTo;
  Classic.prototype.sqrTo = cSqrTo;

  function bnpInvDigit() {
    if(this.t < 1) return 0;
    var x = this[0];
    if((x&1) == 0) return 0;
    var y = x&3;	
    y = (y*(2-(x&0xf)*y))&0xf;
    y = (y*(2-(x&0xff)*y))&0xff;
    y = (y*(2-(((x&0xffff)*y)&0xffff)))&0xffff;
    y = (y*(2-x*y%this.DV))%this.DV;	
    return (y>0)?this.DV-y:-y;
  }

  function Montgomery(m) {
    this.m = m;
    this.mp = m.invDigit();


    this.mpl = this.mp&0x7fff;
    this.mph = this.mp>>15;
    this.um = (1<<(m.DB-15))-1;
    this.mt2 = 2*m.t;
  }

  function montConvert(x) {
    var r = nbi();
    x.abs().dlShiftTo(this.m.t,r);
    r.divRemTo(this.m,null,r);
    if(x.s < 0 && r.compareTo(BI.ZERO) > 0) this.m.subTo(r,r);
    return r;
  }

  function montRevert(x) {
    var r = nbi();
    x.copyTo(r);
    this.reduce(r);
    return r;
  }

  function montReduce(x) {
    while(x.t <= this.mt2)	
      x[x.t++] = 0;
    for(var i = 0; i < this.m.t; ++i) {      
      var j = x[i]&0x7fff;
      var u0 = (j*this.mpl+(((j*this.mph+(x[i]>>15)*this.mpl)&this.um)<<15))&x.DM;
      j = i+this.m.t;
      x[j] += this.m.am(0,u0,x,i,0,this.m.t);
      while(x[j] >= x.DV) { x[j] -= x.DV; x[++j]++; }     
    }
    x.clamp();
    x.drShiftTo(this.m.t,x);
    if(x.compareTo(this.m) >= 0) x.subTo(this.m,x);
  }

  function montSqrTo(x,r) { x.squareTo(r); this.reduce(r); }

  function montMulTo(x,y,r) { x.multiplyTo(y,r); this.reduce(r); }

  Montgomery.prototype.convert = montConvert;
  Montgomery.prototype.revert = montRevert;
  Montgomery.prototype.reduce = montReduce;
  Montgomery.prototype.mulTo = montMulTo;
  Montgomery.prototype.sqrTo = montSqrTo;

  function bnpIsEven() { return ((this.t>0)?(this[0]&1):this.s) == 0; }

  function bnpExp(e,z) {
    if(e > 0xffffffff || e < 1) return BI.ONE;
    var r = nbi(), r2 = nbi(), g = z.convert(this), i = nbits(e)-1;
    g.copyTo(r);
    while(--i >= 0) {
      z.sqrTo(r,r2);
      if((e&(1<<i)) > 0) z.mulTo(r2,g,r);
      else { var t = r; r = r2; r2 = t; }
    }
    return z.revert(r);
  }

  function bnModPowInt(e,m) {
    var z;
    if(e < 256 || m.isEven()) z = new Classic(m); else z = new Montgomery(m);
    return this.exp(e,z);
  }

  function bnpFromString(s,b) {
    var k;
    if (b == null) k = 8;
    else if(b == 16) k = 4;  
    else if(b == 8) k = 3;
    else if(b == 256) k = 8;
    else if(b == 2) k = 1;
    else if(b == 32) k = 5;
    else if(b == 4) k = 2; 
    else { this.fromRadix(s,b); return; }
    this.t = 0;
    this.s = 0;
    var i = s.length, mi = false, sh = 0, x;
    while(--i >= 0) {  
      if(k==8)
	x = (typeof s == 'string')? s.charCodeAt(i)&0xff:s[i]&0xff;
      else
	x = intAt(s,i);    
      if(x < 0) {
	if(s.charAt(i) == "-") mi = true;  
	continue;
      }
      mi = false;  
      if(sh == 0)  
	this[this.t++] = x;
      else if(sh+k > this.DB) {   
	this[this.t-1] |= (x&((1<<(this.DB-sh))-1))<<sh;
	this[this.t++] = (x>>(this.DB-sh));
      }
      else
	this[this.t-1] |= x<<sh;
      sh += k; 
      if(sh >= this.DB) sh -= this.DB; 
    }
    if(k == 8 && (s[0]&0x80) != 0) {
      this.s = -1;
      if(sh > 0) this[this.t-1] |= ((1<<(this.DB-sh))-1)<<sh;
    }
    this.clamp();
    if(mi) BI.ZERO.subTo(this,this);
  }

  BI.prototype.copyTo = bnpCopyTo;
  BI.prototype.fromInt = bnpFromInt;
  BI.prototype.fromString = bnpFromString;
  BI.prototype.clamp = bnpClamp;
  BI.prototype.dlShiftTo = bnpDLShiftTo;
  BI.prototype.drShiftTo = bnpDRShiftTo;
  BI.prototype.lShiftTo = bnpLShiftTo;
  BI.prototype.rShiftTo = bnpRShiftTo;
  BI.prototype.subTo = bnpSubTo;
  BI.prototype.multiplyTo = bnpMultiplyTo;
  BI.prototype.squareTo = bnpSquareTo;
  BI.prototype.divRemTo = bnpDivRemTo;
  BI.prototype.invDigit = bnpInvDigit;
  BI.prototype.isEven = bnpIsEven;
  BI.prototype.exp = bnpExp;

  BI.prototype.toString = bnToString;
  BI.prototype.negate = bnNegate;
  BI.prototype.abs = bnAbs;
  BI.prototype.compareTo = bnCompareTo;
  BI.prototype.bitLength = bnBitLength;
  BI.prototype.mod = bnMod;
  BI.prototype.modPowInt = bnModPowInt;

  BI.ZERO = nbv(0);
  BI.ONE = nbv(1);



  function bnClone() { var r = nbi(); this.copyTo(r); return r; }

  function bnIntValue() {
    if(this.s < 0) {
      if(this.t == 1) return this[0]-this.DV;
      else if(this.t == 0) return -1;
    }
    else if(this.t == 1) return this[0];
    else if(this.t == 0) return 0;
    return ((this[1]&((1<<(32-this.DB))-1))<<this.DB)|this[0];
  }

  function bnByteValue() { return (this.t==0)?this.s:(this[0]<<24)>>24; }

  function bnShortValue() { return (this.t==0)?this.s:(this[0]<<16)>>16; }

  function bnpChunkSize(r) { return Math.floor(Math.LN2*this.DB/Math.log(r)); }

  function bnSigNum() {
    if(this.s < 0) return -1;
    else if(this.t <= 0 || (this.t == 1 && this[0] <= 0)) return 0;
    else return 1;
  }

  function bnpToRadix(b) {
    if(b == null) b = 10;
    if(this.signum() == 0 || b < 2 || b > 36) return "0";
    var cs = this.chunkSize(b);
    var a = Math.pow(b,cs);
    var d = nbv(a), y = nbi(), z = nbi(), r = "";
    this.divRemTo(d,y,z);
    while(y.signum() > 0) {
      r = (a+z.intValue()).toString(b).substr(1) + r;
      y.divRemTo(d,y,z);
    }
    return z.intValue().toString(b) + r;
  }

  function bnpFromRadix(s,b) {
    this.fromInt(0);
    if(b == null) b = 10;
    var cs = this.chunkSize(b);
    var d = Math.pow(b,cs), mi = false, j = 0, w = 0;
    for(var i = 0; i < s.length; ++i) {
      var x = intAt(s,i);
      if(x < 0) {
	if(s.charAt(i) == "-" && this.signum() == 0) mi = true;
	continue;

      }
      w = b*w+x;
      if(++j >= cs) {
	this.dMultiply(d);
	this.dAddOffset(w,0);
	j = 0;
	w = 0;
      }
    }
    if(j > 0) {
      this.dMultiply(Math.pow(b,j));
      this.dAddOffset(w,0);
    }
    if(mi) BI.ZERO.subTo(this,this);
  }

  function bnToByteArray() { 
    var i = this.t, r = new Array();
    r[0] = this.s;
    var p = this.DB-(i*this.DB)%8, d, k = 0;
    if(i-- > 0) {
      if(p < this.DB && (d = this[i]>>p) != (this.s&this.DM)>>p)

	r[k++] = d|(this.s<<(this.DB-p));
      while(i >= 0) {
	if(p < 8) {
	  d = (this[i]&((1<<p)-1))<<(8-p);
	  d |= this[--i]>>(p+=this.DB-8);
	}
	else {
	  d = (this[i]>>(p-=8))&0xff;
	  if(p <= 0) { p += this.DB; --i; }
	}
	if((d&0x80) != 0) d |= -256;
	if(k == 0 && (this.s&0x80) != (d&0x80)) ++k;
	if(k > 0 || d != this.s) r[k++] = d;
      }
    }
    return r;
  }
  
  function bnEquals(a) { return(this.compareTo(a)==0); }
  function bnMin(a) { return(this.compareTo(a)<0)?this:a; }
  function bnMax(a) { return(this.compareTo(a)>0)?this:a; }

  function bnpBitwiseTo(a,op,r) {
    var i, f, m = Math.min(a.t,this.t);
    for(i = 0; i < m; ++i) r[i] = op(this[i],a[i]);
    if(a.t < this.t) {
      f = a.s&this.DM;
      for(i = m; i < this.t; ++i) r[i] = op(this[i],f);
      r.t = this.t;
    }
    else {
      f = this.s&this.DM;
      for(i = m; i < a.t; ++i) r[i] = op(f,a[i]);
      r.t = a.t;
    }
    r.s = op(this.s,a.s);
    r.clamp();
  }
  
  function op_and(x,y) { return x&y; }
  function bnAnd(a) { var r = nbi(); this.bitwiseTo(a,op_and,r); return r; }

  function op_or(x,y) { return x|y; }
  function bnOr(a) { var r = nbi(); this.bitwiseTo(a,op_or,r); return r; }

  function op_xor(x,y) { return x^y; }
  function bnXor(a) { var r = nbi(); this.bitwiseTo(a,op_xor,r); return r; }

  function op_andnot(x,y) { return x&~y; }
  function bnAndNot(a) { var r = nbi(); this.bitwiseTo(a,op_andnot,r); return r; }

  function bnNot() {
    var r = nbi();
    for(var i = 0; i < this.t; ++i) r[i] = this.DM&~this[i];
    r.t = this.t;
    r.s = ~this.s;
    return r;
  }

  function bnShiftLeft(n) {
    var r = nbi();
    if(n < 0) this.rShiftTo(-n,r); else this.lShiftTo(n,r);
    return r;
  }

  function bnShiftRight(n) {
    var r = nbi();
    if(n < 0) this.lShiftTo(-n,r); else this.rShiftTo(n,r);
    return r;
  }

  function lbit(x) {
    if(x == 0) return -1;
    var r = 0;
    if((x&0xffff) == 0) { x >>= 16; r += 16; }
    if((x&0xff) == 0) { x >>= 8; r += 8; }
    if((x&0xf) == 0) { x >>= 4; r += 4; }
    if((x&3) == 0) { x >>= 2; r += 2; }
    if((x&1) == 0) ++r;
    return r;
  }

  function bnGetLowestSetBit() {
    for(var i = 0; i < this.t; ++i)
      if(this[i] != 0) return i*this.DB+lbit(this[i]);
    if(this.s < 0) return this.t*this.DB;
    return -1;
  }

  function cbit(x) {
    var r = 0;
    while(x != 0) { x &= x-1; ++r; }
    return r;
  }
  
  function bnBitCount() {
    var r = 0, x = this.s&this.DM;
    for(var i = 0; i < this.t; ++i) r += cbit(this[i]^x);
    return r;
  }
  
  function bnTestBit(n) {
    var j = Math.floor(n/this.DB);
    if(j >= this.t) return(this.s!=0);
    return((this[j]&(1<<(n%this.DB)))!=0);
  }
  
  function bnpChangeBit(n,op) {
    var r = BI.ONE.shiftLeft(n);
    this.bitwiseTo(r,op,r);
    return r;
  }

  function bnSetBit(n) { return this.changeBit(n,op_or); }

  function bnClearBit(n) { return this.changeBit(n,op_andnot); }

  function bnFlipBit(n) { return this.changeBit(n,op_xor); }

  function bnpAddTo(a,r) {
    var i = 0, c = 0, m = Math.min(a.t,this.t);
    while(i < m) {
      c += this[i]+a[i];
      r[i++] = c&this.DM;
      c >>= this.DB;
    }
    if(a.t < this.t) {
      c += a.s;
      while(i < this.t) {
	c += this[i];
	r[i++] = c&this.DM;
	c >>= this.DB;
      }
      c += this.s;
    }
    else {
      c += this.s;
      while(i < a.t) {
	c += a[i];
	r[i++] = c&this.DM;
	c >>= this.DB;
      }
      c += a.s;
    }
    r.s = (c<0)?-1:0;
    if(c > 0) r[i++] = c;
    else if(c < -1) r[i++] = this.DV+c;
    r.t = i;
    r.clamp();
  }

  function bnAdd(a) { var r = nbi(); this.addTo(a,r); return r; }

  function bnSubtract(a) { var r = nbi(); this.subTo(a,r); return r; }

  function bnMultiply(a) { var r = nbi(); this.multiplyTo(a,r); return r; }

  function bnDivide(a) { var r = nbi(); this.divRemTo(a,r,null); return r; }

  function bnRemainder(a) { var r = nbi(); this.divRemTo(a,null,r); return r; }

  function bnDivideAndRemainder(a) {
    var q = nbi(), r = nbi();
    this.divRemTo(a,q,r);
    return new Array(q,r);
  }

  function bnpDMultiply(n) {
    this[this.t] = this.am(0,n-1,this,0,0,this.t);
    ++this.t;
    this.clamp();
  }

  function bnpDAddOffset(n,w) {
    while(this.t <= w) this[this.t++] = 0;  
    this[w] += n; 
    while(this[w] >= this.DV) { 
      this[w] -= this.DV;
      if(++w >= this.t) this[this.t++] = 0;
      ++this[w];
    }
  }

  function NullExp() {}
  function nNop(x) { return x; }
  function nMulTo(x,y,r) { x.multiplyTo(y,r); }
  function nSqrTo(x,r) { x.squareTo(r); }

  NullExp.prototype.convert = nNop;
  NullExp.prototype.revert = nNop;
  NullExp.prototype.mulTo = nMulTo;
  NullExp.prototype.sqrTo = nSqrTo;

  function bnPow(e) { return this.exp(e,new NullExp()); }

  function bnpMultiplyLowerTo(a,n,r) {
    var i = Math.min(this.t+a.t,n);
    r.s = 0;
    r.t = i;
    while(i > 0) r[--i] = 0;
    var j;
    for(j = r.t-this.t; i < j; ++i) r[i+this.t] = this.am(0,a[i],r,i,0,this.t);
    for(j = Math.min(a.t,n); i < j; ++i) this.am(0,a[i],r,i,0,n-i);
    r.clamp();
  }

  function bnpMultiplyUpperTo(a,n,r) {
    --n;
    var i = r.t = this.t+a.t-n;
    r.s = 0;
    while(--i >= 0) r[i] = 0;
    for(i = Math.max(n-this.t,0); i < a.t; ++i)
      r[this.t+i-n] = this.am(n-i,a[i],r,0,0,this.t+i-n);
    r.clamp();
    r.drShiftTo(1,r);
  }
  
  function Barrett(m) {
    this.r2 = nbi();
    this.q3 = nbi();
    BI.ONE.dlShiftTo(2*m.t,this.r2);
    this.mu = this.r2.divide(m);
    this.m = m;
  }

  function barrettConvert(x) {
    if(x.s < 0 || x.t > 2*this.m.t) return x.mod(this.m);
    else if(x.compareTo(this.m) < 0) return x;
    else { var r = nbi(); x.copyTo(r); this.reduce(r); return r; }
  }

  function barrettRevert(x) { return x; }

  function barrettReduce(x) {

    x.drShiftTo(this.m.t-1,this.r2);
    if(x.t > this.m.t+1) { x.t = this.m.t+1; x.clamp(); }
    this.mu.multiplyUpperTo(this.r2,this.m.t+1,this.q3);
    this.m.multiplyLowerTo(this.q3,this.m.t+1,this.r2);
    while(x.compareTo(this.r2) < 0) x.dAddOffset(1,this.m.t+1);
    x.subTo(this.r2,x);
    while(x.compareTo(this.m) >= 0) x.subTo(this.m,x);
  }

  function barrettSqrTo(x,r) { x.squareTo(r); this.reduce(r); }

  function barrettMulTo(x,y,r) { x.multiplyTo(y,r); this.reduce(r); }

  Barrett.prototype.convert = barrettConvert;
  Barrett.prototype.revert = barrettRevert;
  Barrett.prototype.reduce = barrettReduce;
  Barrett.prototype.mulTo = barrettMulTo;
  Barrett.prototype.sqrTo = barrettSqrTo;

  function bnModPow(e,m) {
    var i = e.bitLength(), k, r = nbv(1), z;
    if(i <= 0) return r;
    else if(i < 18) k = 1;
    else if(i < 48) k = 3;
    else if(i < 144) k = 4;
    else if(i < 768) k = 5;
    else k = 6;
    if(i < 8)
      z = new Classic(m);
    else if(m.isEven())
      z = new Barrett(m);
    else
      z = new Montgomery(m);

    var g = new Array(), n = 3, k1 = k-1, km = (1<<k)-1;
    g[1] = z.convert(this);
    if(k > 1) {
      var g2 = nbi();
      z.sqrTo(g[1],g2);
      while(n <= km) {
	g[n] = nbi();
	z.mulTo(g2,g[n-2],g[n]);

	n += 2;
      }
    }

    var j = e.t-1, w, is1 = true, r2 = nbi(), t;

    i = nbits(e[j])-1;
    while(j >= 0) {
      if(i >= k1) w = (e[j]>>(i-k1))&km;
      else {
	w = (e[j]&((1<<(i+1))-1))<<(k1-i);
	if(j > 0) w |= e[j-1]>>(this.DB+i-k1);
      }

      n = k;
      while((w&1) == 0) { w >>= 1; --n; }
      if((i -= n) < 0) { i += this.DB; --j; }
      if(is1) {
	g[w].copyTo(r);
	is1 = false;
      }
      else {
	while(n > 1) { z.sqrTo(r,r2); z.sqrTo(r2,r); n -= 2; }
	if(n > 0) z.sqrTo(r,r2); else { t = r; r = r2; r2 = t; }
	z.mulTo(r2,g[w],r);
      }

      while(j >= 0 && (e[j]&(1<<i)) == 0) {
	z.sqrTo(r,r2); t = r; r = r2; r2 = t;
	if(--i < 0) { i = this.DB-1; --j; }
      }
    }
    return z.revert(r);
  }

  function bnGCD(a) {
    var x = (this.s<0)?this.negate():this.clone();
    var y = (a.s<0)?a.negate():a.clone();
    if(x.compareTo(y) < 0) { var t = x; x = y; y = t; }
    var i = x.getLowestSetBit(), g = y.getLowestSetBit();
    if(g < 0) return x;
    if(i < g) g = i;
    if(g > 0) {
      x.rShiftTo(g,x);
      y.rShiftTo(g,y);
    }
    while(x.signum() > 0) {
      if((i = x.getLowestSetBit()) > 0) x.rShiftTo(i,x);
      if((i = y.getLowestSetBit()) > 0) y.rShiftTo(i,y);
      if(x.compareTo(y) >= 0) {
	x.subTo(y,x);
	x.rShiftTo(1,x);
      }
      else {
	y.subTo(x,y);
	y.rShiftTo(1,y);
      }
    }
    if(g > 0) y.lShiftTo(g,y);
    return y;
  }

  function bnpModInt(n) {
    if(n <= 0) return 0;
    var d = this.DV%n, r = (this.s<0)?n-1:0;
    if(this.t > 0)
      if(d == 0) r = this[0]%n;
      else for(var i = this.t-1; i >= 0; --i) r = (d*r+this[i])%n;
    return r;
  }

  function bnModInverse(m) {
    var ac = m.isEven();
    if((this.isEven() && ac) || m.signum() == 0) return BI.ZERO;
    var u = m.clone(), v = this.clone();
    var a = nbv(1), b = nbv(0), c = nbv(0), d = nbv(1);
    while(u.signum() != 0) {
      while(u.isEven()) {
	u.rShiftTo(1,u);
	if(ac) {
	  if(!a.isEven() || !b.isEven()) { a.addTo(this,a); b.subTo(m,b); }
	  a.rShiftTo(1,a);
	}
	else if(!b.isEven()) b.subTo(m,b);
	b.rShiftTo(1,b);
      }
      while(v.isEven()) {
	v.rShiftTo(1,v);
	if(ac) {
	  if(!c.isEven() || !d.isEven()) { c.addTo(this,c); d.subTo(m,d); }
	  c.rShiftTo(1,c);
	}
	else if(!d.isEven()) d.subTo(m,d);
	d.rShiftTo(1,d);
      }
      if(u.compareTo(v) >= 0) {
	u.subTo(v,u);
	if(ac) a.subTo(c,a);
	b.subTo(d,b);
      }
      else {
	v.subTo(u,v);
	if(ac) c.subTo(a,c);
	d.subTo(b,d);
      }
    }
    if(v.compareTo(BI.ONE) != 0) return BI.ZERO;
    if(d.compareTo(m) >= 0) return d.subtract(m);
    if(d.signum() < 0) d.addTo(m,d); else return d;
    if(d.signum() < 0) return d.add(m); else return d;
  }


  function bnToByteString() {
    var ba = this.toByteArray(); 
    var r = '';
    var i = 0;

    
    /*Como se almacena en CA2, si el byte más significativo está lleno
      con datos, se añade otro por delante que contiene solo el signo,
      y no debe tenerse en cuenta a la hora de escribir una cadena,
      porque su longitud sería mayor a la esperada. Si el byte más
      significativo tiene al menos un bit libre, el signo del CA2 se
      representa dentro del número de bytes disponibles.*/
    
    if(ba[0]==0 || ba[0]==-1)  
      i = 1;
    
    while (i < ba.length){ 
      r+= String.fromCharCode(ba[i] & 0xff);
      i++;   
    }
    return r;
  }

  BI.prototype.toByteString = bnToByteString;


  BI.prototype.chunkSize = bnpChunkSize;
  BI.prototype.toRadix = bnpToRadix;
  BI.prototype.fromRadix = bnpFromRadix;
  BI.prototype.bitwiseTo = bnpBitwiseTo;
  BI.prototype.changeBit = bnpChangeBit;
  BI.prototype.addTo = bnpAddTo;
  BI.prototype.dMultiply = bnpDMultiply;
  BI.prototype.dAddOffset = bnpDAddOffset;
  BI.prototype.multiplyLowerTo = bnpMultiplyLowerTo;
  BI.prototype.multiplyUpperTo = bnpMultiplyUpperTo;
  BI.prototype.modInt = bnpModInt;

  BI.prototype.clone = bnClone;
  BI.prototype.intValue = bnIntValue;
  BI.prototype.byteValue = bnByteValue;
  BI.prototype.shortValue = bnShortValue;
  BI.prototype.signum = bnSigNum;
  BI.prototype.toByteArray = bnToByteArray;
  BI.prototype.equals = bnEquals;
  BI.prototype.min = bnMin;
  BI.prototype.max = bnMax;
  BI.prototype.and = bnAnd;
  BI.prototype.or = bnOr;
  BI.prototype.xor = bnXor;
  BI.prototype.andNot = bnAndNot;
  BI.prototype.not = bnNot;
  BI.prototype.shiftLeft = bnShiftLeft;
  BI.prototype.shiftRight = bnShiftRight;
  BI.prototype.getLowestSetBit = bnGetLowestSetBit;
  BI.prototype.bitCount = bnBitCount;
  BI.prototype.testBit = bnTestBit;
  BI.prototype.setBit = bnSetBit;
  BI.prototype.clearBit = bnClearBit;
  BI.prototype.flipBit = bnFlipBit;
  BI.prototype.add = bnAdd;
  BI.prototype.subtract = bnSubtract;
  BI.prototype.multiply = bnMultiply;
  BI.prototype.divide = bnDivide;
  BI.prototype.remainder = bnRemainder;
  BI.prototype.divideAndRemainder = bnDivideAndRemainder;
  BI.prototype.modPow = bnModPow;
  BI.prototype.modInverse = bnModInverse;
  BI.prototype.pow = bnPow;
  BI.prototype.gcd = bnGCD;


  /******** Fin Antigua clase BigInteger   ********/



  /***** Constructor *****/


  
  var b64map="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  var b64pad="=";


 this.bin2b64 = function(bstr) { 
    var i=0;
    var a,b,c,d;
    var ret = "";

    for(i = 0; i+3 <= bstr.length; i+=3) {
      a = (bstr.charCodeAt(i)>>2) & 0x3F;
      b = ( ((bstr.charCodeAt(i) & 0x03) <<4) | ((bstr.charCodeAt(i+1)>>4) & 0x0F) ) & 0x3F;
      c = ( ((bstr.charCodeAt(i+1) & 0x0F) <<2) | ((bstr.charCodeAt(i+2)>>6) & 0x03) ) & 0x3F;
      d = bstr.charCodeAt(i+2) & 0x3F;

      ret += b64map.charAt(a)+b64map.charAt(b)+b64map.charAt(c)+b64map.charAt(d);
    }

    if(i+1 ==  bstr.length) { 
      a = (bstr.charCodeAt(i)>>2) & 0x3F;
      b = ((bstr.charCodeAt(i) & 0x03) <<4) & 0x30;

      ret += b64map.charAt(a)+b64map.charAt(b);
    }
    else if(i+2 ==  bstr.length) { 
      a = (bstr.charCodeAt(i)>>2) & 0x3F;
      b = ( ((bstr.charCodeAt(i) & 0x03) <<4) | ((bstr.charCodeAt(i+1)>>4) & 0x0F) ) & 0x3F;
      c = ((bstr.charCodeAt(i+1) & 0x0F) <<2) & 0x3C;
    
      ret += b64map.charAt(a)+b64map.charAt(b)+b64map.charAt(c);
    }
    while((ret.length & 3) > 0) ret += b64pad; 
    return ret;
  }
  



  this.b642bin =  function(b64s) {
    var ret = "";
    var i;
    var a,b,c,d;
    var p,q,r,s;
    var pad = 0;

    if((b64s.length & 3) !=0) 
      return 0;

    for(i = 0; i < b64s.length; i+=4) {
      p = b64map.indexOf(b64s.charAt(i));
      q = b64map.indexOf(b64s.charAt(i+1));
    
      if(b64s.charAt(i+2) == b64pad){
	r = 0;
	pad++;
      }
      else 
	r = b64map.indexOf(b64s.charAt(i+2));
    
      if(b64s.charAt(i+3) == b64pad){
	s = 0;
	pad++;
      }
      else 
	s = b64map.indexOf(b64s.charAt(i+3));

      a = (((p<<2) & 0xFC) | ((q>>4) & 0x03) ) & 0xFF;
      b = (((q<<4) & 0xF0) | ((r>>2) & 0x0F) ) & 0xFF;
      c = (((r<<6) & 0xC0) | ( s     & 0x3F) ) & 0xFF;

      ret += String.fromCharCode(a);

      
      
      
      
      if(c == 0 && (i+4 >= b64s.length) && pad>0) {  
	if(!b && pad>1);
	else ret += String.fromCharCode(b);   
      }
      else{
	ret += String.fromCharCode(b);
	ret += String.fromCharCode(c); 
      }
    }
    return ret;
  }
  


  
  
  if(b==64)
    this.BN = new BI(this.b642bin(a),256);
  else
    this.BN = new BI(a,b);
  
  this.BNISet = function(bni){
    this.BN = bni;
 
    return this;
  }
  
  
 
  
  
 


  this.toString = function(b){  
    if(b == 64)
      return this.toB64String();
    
    if(b == 256)
      return this.toByteString();


    return this.BN.toString(b)

  };

  this.negate   = function() { return new eSvyBigInteger().BNISet(this.BN.negate());};
  
  this.abs      = function() { return new eSvyBigInteger().BNISet(this.BN.abs());};

  this.compareTo = function(a){ return this.BN.compareTo(a.BN)};

  this.bitLength = function(){ return this.BN.bitLength()};
  
  this.mod = function(a){ return new eSvyBigInteger().BNISet(this.BN.mod(a.BN));};

  this.modPowInt = function(e,m){ return new eSvyBigInteger().BNISet(this.BN.modPowInt(e,m.BN));};

  this.pow = function(e){ return new eSvyBigInteger().BNISet(this.BN.pow(e));};

  this.modPow = function(e,m){ return new eSvyBigInteger().BNISet(this.BN.modPow(e.BN,m.BN));};

  this.isEven = function(){ return this.BN.isEven()};

  this.gcd = function(a){ return new eSvyBigInteger().BNISet(this.BN.gcd(a.BN));};

  this.modInverse = function(m){ return new eSvyBigInteger().BNISet(this.BN.modInverse(m.BN));};

  this.clone = function(){ return new eSvyBigInteger().BNISet(this.BN.clone());};

  this.intValue = function(){ return this.BN.intValue()};

  this.byteValue = function(){ return this.BN.byteValue()};

  this.shortValue = function(){ return this.BN.shortValue()};

  this.signum = function(){ return this.BN.signum()};

  this.toByteArray = function(){ return this.BN.toByteArray()};

  this.equals = function(a){ return this.BN.equals(a.BN)};

  this.min = function(a){ return new eSvyBigInteger().BNISet(this.BN.min(a.BN));};

  this.max = function(a){ return new eSvyBigInteger().BNISet(this.BN.max(a.BN));};

  this.and = function(a){ return new eSvyBigInteger().BNISet(this.BN.and(a.BN));};

  this.or = function(a){ return new eSvyBigInteger().BNISet(this.BN.or(a.BN));};

  this.xor = function(a){ return new eSvyBigInteger().BNISet(this.BN.xor(a.BN));};

  this.andNot = function(a){ return new eSvyBigInteger().BNISet(this.BN.andNot(a.BN));};

  this.not = function(){ return new eSvyBigInteger().BNISet(this.BN.not());};

  this.shiftLeft = function(n){ return new eSvyBigInteger().BNISet(this.BN.shiftLeft(n));};

  this.shiftRight = function(n){ return new eSvyBigInteger().BNISet(this.BN.shiftRight(n));};

  this.getLowestSetBit = function(){ return this.BN.getLowestSetBit()};
  
  this.bitCount = function(){ return this.BN.bitCount()};

  this.testBit = function(n){ return this.BN.testBit(n)};

  this.setBit = function(n){ return new eSvyBigInteger().BNISet(this.BN.setBit(n));};

  this.clearBit = function(n){ return new eSvyBigInteger().BNISet(this.BN.clearBit(n));};

  this.flipBit = function(n){ return new eSvyBigInteger().BNISet(this.BN.flipBit(n));};

  this.add = function(a){     return new eSvyBigInteger().BNISet(this.BN.add(a.BN));};

  this.substract = function(a){ return new eSvyBigInteger().BNISet(this.BN.subtract(a.BN));};  

  this.multiply = function(a){ return new eSvyBigInteger().BNISet(this.BN.multiply(a.BN));};

  this.divide = function(a){ return new eSvyBigInteger().BNISet(this.BN.divide(a.BN));};

  this.remainder = function(a){ return new eSvyBigInteger().BNISet(this.BN.remainder(a.BN));};

  this.divideAndRemainder = function(a){ 
    arr = this.BN.divideAndRemainder(a.BN);
    return [new eSvyBigInteger().BNISet(arr[0]),new eSvyBigInteger().BNISet(arr[1])];
  };

  this.toByteString = function(){ return this.BN.toByteString();}; 
  
  this.toB64String = function(){ return this.bin2b64(this.BN.toByteString());}; 
}





function eSvyErrorList(){

  var list= new Array();
  var count = 0;

  this.add = function(errstr){
    list[count++] = errstr;
  }

  this.clear = function(){
    delete list;
    list = new Array();
    count = 0;
  }
  
  this.get = function(){
    return list;
  }

  this.toString = function(){
    return list.toString();
  }

}


eSvyErrorList = new eSvyErrorList();







function eSvyRSA() {


  this.n = null;
  this.e = 0;
  
  function pkcs1pad2(s,n) {
    if(n < s.length + 11) {
      eSvyErrorList.add("pkcs1pad2: Message too long for RSA");
      return null;
    }
    var ba = new Array();
    var i = s.length - 1;
    
    while(i >= 0 && n > 0) ba[--n] = s.charCodeAt(i--) & 0xff;
    ba[--n] = 0; 
    
    var x=0;
    while(n > 2) {
      x = 0;
      while(x == 0) x = Math.random()*10000 & 0xff; 
      ba[--n] = x; 
    }
    ba[--n] = 2; 
    ba[--n] = 0; 
    return new eSvyBigInteger(ba,256);
  }

  
  this.pkcs1pad1 = function(s,n) {
    if(n < s.length + 11) {
      eSvyErrorList.add("pkcs1pad1: Message too long for RSA");
      return null;
    }
    var ba = new Array();
    var i = s.length - 1;
    
    while(i >= 0 && n > 0) ba[--n] = s.charCodeAt(i--) & 0xff;
    ba[--n] = 0; 
    
    var x=0;
    while(n > 2) {
      ba[--n] = 0xff; 
    }
    ba[--n] = 1; 
    ba[--n] = 0; 
    return new eSvyBigInteger(ba,256);
  }


  this.pkcs1unpad1 = function(d,n) {
    var b = d.toByteArray(); 
    var i = 0;
    var mask = ((1<<9)-1); 
    while(i < b.length && b[i] == 0) ++i;
    if(b.length-i != n-1 || b[i] != 1) return null; 
    ++i;
    while(b[i] != 0){
      if(++i >= b.length) return null;
      if(b[i]& mask != mask) return null;
    }
    var ret = "";
    while(++i < b.length) 
      ret += String.fromCharCode(b[i] & 0xff);  
    return ret;
  }
  


  this.setPublic = function(N,E,base) {
    if(base == null)
      base = 64;
    
    if(N != null && E != null && N.length > 0) {
      
      this.n = new eSvyBigInteger(N, base); 
      
      if(base <=36) this.e = parseInt(E,base);  
      else this.e = parseInt(new eSvyBigInteger(E, base).toString(10),10); 
      
      return true;
    }
    else{
      eSvyErrorList.add("Invalid RSA public key");
      return false;
    }
  }
  
  
  this.encrypt = function(text) {
    var m = pkcs1pad2(text,(this.n.bitLength()+7)>>3); 
    if(m == null) return null;
    var c = m.modPowInt(this.e, this.n); 
    if(c == null) return null;
    
    return c.toByteString(); 
  }
  
  
  this.publicDecrypt = function(sigdata){
    var BNmsg  = new eSvyBigInteger(sigdata,64);  
    return this.pkcs1unpad1(BNmsg.modPowInt(this.e,this.n), (this.n.bitLength()+7)>>3);  
  }
  
}










function eSvyDigester(){

  var MD5_T = new Array(0x00000000, 0xd76aa478, 0xe8c7b756, 0x242070db,
			0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613,
			0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1,
			0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e,
			0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51,
			0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681,
			0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87,
			0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9,
			0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122,
			0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60,
			0xbebfbc70, 0x289b7ec6, 0xeaa127fa, 0xd4ef3085,
			0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8,
			0xc4ac5665, 0xf4292244, 0x432aff97, 0xab9423a7,
			0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d,
			0x85845dd1, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314,
			0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb,
			0xeb86d391);

  var MD5_round1 = new Array(new Array( 0, 7, 1), new Array( 1,12, 2),
			     new Array( 2,17, 3), new Array( 3,22, 4),
			     new Array( 4, 7, 5), new Array( 5,12, 6),
			     new Array( 6,17, 7), new Array( 7,22, 8),
			     new Array( 8, 7, 9), new Array( 9,12,10),
			     new Array(10,17,11), new Array(11,22,12),
			     new Array(12, 7,13), new Array(13,12,14),
			     new Array(14,17,15), new Array(15,22,16));

  var MD5_round2 = new Array(new Array( 1, 5,17), new Array( 6, 9,18),
			     new Array(11,14,19), new Array( 0,20,20),
			     new Array( 5, 5,21), new Array(10, 9,22),
			     new Array(15,14,23), new Array( 4,20,24),
			     new Array( 9, 5,25), new Array(14, 9,26),
			     new Array( 3,14,27), new Array( 8,20,28),
			     new Array(13, 5,29), new Array( 2, 9,30),
			     new Array( 7,14,31), new Array(12,20,32));

  var MD5_round3 = new Array(new Array( 5, 4,33), new Array( 8,11,34),
			     new Array(11,16,35), new Array(14,23,36),
			     new Array( 1, 4,37), new Array( 4,11,38),
			     new Array( 7,16,39), new Array(10,23,40),
			     new Array(13, 4,41), new Array( 0,11,42),
			     new Array( 3,16,43), new Array( 6,23,44),
			     new Array( 9, 4,45), new Array(12,11,46),
			     new Array(15,16,47), new Array( 2,23,48));

  var MD5_round4 = new Array(new Array( 0, 6,49), new Array( 7,10,50),
			     new Array(14,15,51), new Array( 5,21,52),
			     new Array(12, 6,53), new Array( 3,10,54),
			     new Array(10,15,55), new Array( 1,21,56),
			     new Array( 8, 6,57), new Array(15,10,58),
			     new Array( 6,15,59), new Array(13,21,60),
			     new Array( 4, 6,61), new Array(11,10,62),
			     new Array( 2,15,63), new Array( 9,21,64));

  var MD5_F = function (x, y, z) { return (x & y) | (~x & z); }
  var MD5_G = function (x, y, z) { return (x & z) | (y & ~z); }
  var MD5_H = function (x, y, z) { return x ^ y ^ z;          }
  var MD5_I = function (x, y, z) { return y ^ (x | ~z);       }

  var MD5_round = new Array(new Array(MD5_F, MD5_round1),
			    new Array(MD5_G, MD5_round2),
			    new Array(MD5_H, MD5_round3),
			    new Array(MD5_I, MD5_round4));

  var MD5_pack = function(n32) {
    return String.fromCharCode(n32 & 0xff) +
    String.fromCharCode((n32 >>> 8) & 0xff) +
    String.fromCharCode((n32 >>> 16) & 0xff) +
    String.fromCharCode((n32 >>> 24) & 0xff);
  }

  var MD5_unpack = function(s4) {
    return  s4.charCodeAt(0)        |
    (s4.charCodeAt(1) <<  8) |
    (s4.charCodeAt(2) << 16) |
    (s4.charCodeAt(3) << 24);
  }

  var MD5_number = function(n) {
    while (n < 0)
      n += 4294967296;
    while (n > 4294967295)
      n -= 4294967296;
    return n;
  }

  var MD5_apply_round = function(x, s, f, abcd, r) {
    var a, b, c, d;
    var kk, ss, ii;
    var t, u;

    a = abcd[0];
    b = abcd[1];
    c = abcd[2];
    d = abcd[3];
    kk = r[0];
    ss = r[1];
    ii = r[2];

    u = f(s[b], s[c], s[d]);
    t = s[a] + u + x[kk] + MD5_T[ii];
    t = MD5_number(t);
    t = ((t<<ss) | (t>>>(32-ss)));
    t += s[b];
    s[a] = MD5_number(t);
  }

  function md5 (data) {
    var abcd, x, state, s;
    var len, index, padLen, f, r;
    var i, j, k;
    var tmp;

    state = new Array(0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476);
    len = data.length;
    index = len & 0x3f;
    padLen = (index < 56) ? (56 - index) : (120 - index);
    if(padLen > 0) {
      data += "\x80";
      for(i = 0; i < padLen - 1; i++)
	data += "\x00";
    }
    data += MD5_pack(len * 8);
    data += MD5_pack(0);

    len  += padLen + 8;
    abcd = new Array(0, 1, 2, 3);
    x    = new Array(16);
    s    = new Array(4);

    for(k = 0; k < len; k += 64) {
      for(i = 0, j = k; i < 16; i++, j += 4) {
	x[i] = data.charCodeAt(j) |
	  (data.charCodeAt(j + 1) <<  8) |
	  (data.charCodeAt(j + 2) << 16) |
	  (data.charCodeAt(j + 3) << 24);
      }
      for(i = 0; i < 4; i++)
	s[i] = state[i];
      for(i = 0; i < 4; i++) {
	f = MD5_round[i][0];
	r = MD5_round[i][1];
	for(j = 0; j < 16; j++) {
	  MD5_apply_round(x, s, f, abcd, r[j]);
	  tmp = abcd[0];
	  abcd[0] = abcd[3];
	  abcd[3] = abcd[2];
	  abcd[2] = abcd[1];
	  abcd[1] = tmp;
	}
      }

      for(i = 0; i < 4; i++) {
	state[i] += s[i];
	state[i] = MD5_number(state[i]);
      }
    }

    return MD5_pack(state[0]) +
    MD5_pack(state[1]) +
    MD5_pack(state[2]) +
    MD5_pack(state[3]);
  }

  this.md5=md5;

  this.md5hex = function(data) {
    var i, out, c;
    var bit128;

    bit128 = md5(data);
    out = "";
    for(i = 0; i < 16; i++) {
      c = bit128.charCodeAt(i);
      out += "0123456789abcdef".charAt((c>>4) & 0xf);
      out += "0123456789abcdef".charAt(c & 0xf);
    }
    return out;
  }

}


/* RC4
   el constructor toma la key (string) como parámetro
   exporta el metodo encrypt que devuelve cifrado según el parámetro m:
   - si es string lo cifra.
   - si es integer devuelve m bytes del generador rc4
*/

function eSvyARC4(key) {
  var I = 0;
  var J = 0;
  var S = new Array();

  var i, j, t;
  for(i = 0; i < 256; ++i)
    S[i] = i;
  j = 0;
  for(i = 0; i < 256; ++i) {
    j = (j + S[i] + key.charCodeAt(i % key.length)) & 255;
    t = S[i];
    S[i] = S[j];
    S[j] = t;
  }
  I = 0;
  J = 0;
  
  this.encrypt = function (m) { 
    var t, l;
    var b= new Array();
    var res = '';
    if (typeof m == 'number'){
      l=m;
    }
    else{
      l=m.length;
    }
    for (i=0; i<l; i++) {
      I = (I + 1) & 255;
      J = (J + S[I]) & 255;
      t = S[I];
      S[I] = S[J];
      S[J] = t;
      b[i] = S[(t + S[I]) & 255];
    }
    
    if (typeof m == 'string'){
      for (i=0; i<l; i++)
	res+=String.fromCharCode(m.charCodeAt(i)^b[i]);
    }
    else{
      for (i=0; i<l; i++)
        res += String.fromCharCode(b[i]);
    }
    return res;
  }

  this.decrypt = this.encrypt;
  this.random  = this.encrypt;
  this.rndInt32 = function(n,m) {
    var b= this.random(4);
    var r=0;
    for (var i=0; i<4; i++) {
      r=r*256+b.charCodeAt(i);
    }
    if (m)
      return Math.floor((r*(m-n+1)/4294967296)+n);
    else
      return r;
  }

}

function eSvyPrng() {

  function addVariable (obj){
    try{
      return obj.toString();
    } catch(e){
      return '';
    }
  }
  
  var entBuff = '';

  entBuff += Math.random().toString();

  try{ entBuff += addVariable(clientHeight);		   		}catch(e){}
  try{ entBuff += addVariable(clientWidth);				}catch(e){}
  try{ entBuff += addVariable(defaultStatus);				}catch(e){}
  try{ entBuff += addVariable(devicePixelRatio);			}catch(e){}
  try{ entBuff += addVariable(document.applets.length);			}catch(e){}
  try{ entBuff += addVariable(document.characterSet);			}catch(e){}
  try{ entBuff += addVariable(document.charset);			}catch(e){}
  try{ entBuff += addVariable(document.cookie);				}catch(e){}
  try{ entBuff += addVariable(document.height);				}catch(e){}
  try{ entBuff += addVariable(document.lastModified);			}catch(e){}
  try{ entBuff += addVariable(document.location.href);			}catch(e){}

  try{ entBuff += addVariable(document.referrer);			}catch(e){}
  try{ entBuff += addVariable(document.width);				}catch(e){}
  try{ entBuff += addVariable(location.href);				}catch(e){}
  try{ entBuff += addVariable(namespaces.length);			}catch(e){}
  try{ entBuff += addVariable(navigator.appCodeName);			}catch(e){}
  try{ entBuff += addVariable(navigator.appMinorVersion);		}catch(e){}
  try{ entBuff += addVariable(navigator.appName);			}catch(e){}
  try{ entBuff += addVariable(navigator.appVersion);			}catch(e){}
  try{ entBuff += addVariable(navigator.buildID);			}catch(e){}
  try{ entBuff += addVariable(navigator.cpuClass);			}catch(e){}
  try{ entBuff += addVariable(navigator.language);			}catch(e){}

  try{ entBuff += addVariable(navigator.opsProfile);			}catch(e){}
  try{ entBuff += addVariable(navigator.oscpu );			}catch(e){}
  try{ entBuff += addVariable(navigator.platform);			}catch(e){}

  try{ entBuff += addVariable(navigator.product);			}catch(e){}
  try{ entBuff += addVariable(navigator.productSub);			}catch(e){}
  try{ entBuff += addVariable(navigator.systemLanguage);		}catch(e){}
  try{ entBuff += addVariable(navigator.userAgent);			}catch(e){}
  try{ entBuff += addVariable(navigator.userLanguage);			}catch(e){}
  try{ entBuff += addVariable(navigator.userProfile);			}catch(e){}
  try{ entBuff += addVariable(navigator.vendor);			}catch(e){}
  try{ entBuff += addVariable(navigator.vendorSub);			}catch(e){}
  try{ entBuff += addVariable(offscreenBuffering);			}catch(e){}
  try{ entBuff += addVariable(offsetHeight);				}catch(e){}
  try{ entBuff += addVariable(offsetWidth);				}catch(e){}
  try{ entBuff += addVariable(outerHeight);				}catch(e){}
  try{ entBuff += addVariable(screen.availHeight);			}catch(e){}
  try{ entBuff += addVariable(screen.availLeft);			}catch(e){}
  try{ entBuff += addVariable(screen.availTop);				}catch(e){}
  try{ entBuff += addVariable(screen.availWidth);			}catch(e){}
  try{ entBuff += addVariable(screen.colorDepth);			}catch(e){}
  try{ entBuff += addVariable(screen.height);				}catch(e){}
  try{ entBuff += addVariable(screen.pixelDepth);			}catch(e){}
  try{ entBuff += addVariable(screen.width);				}catch(e){}
  try{ entBuff += addVariable(screenLeft);				}catch(e){}
  try{ entBuff += addVariable(screenTop);				}catch(e){}
  try{ entBuff += addVariable(scrollHeight);				}catch(e){}
  try{ entBuff += addVariable(scrollLeft);				}catch(e){}
  try{ entBuff += addVariable(scrollTop);				}catch(e){}
  try{ entBuff += addVariable(scrollWidth);				}catch(e){}
  try{ entBuff += addVariable(window.event.screenX);			}catch(e){}
  try{ entBuff += addVariable(window.event.screenY);			}catch(e){}
  try{ entBuff += addVariable(window.history.length);			}catch(e){}
  try{ entBuff += addVariable(window.innerHeight);			}catch(e){}
  try{ entBuff += addVariable(window.innerWidth);			}catch(e){}
  try{ entBuff += addVariable(window.location.href);			}catch(e){}
  try{ entBuff += addVariable(window.name);				}catch(e){}
  try{ entBuff += addVariable(window.outerHeight);			}catch(e){}
  try{ entBuff += addVariable(window.outerWidth);			}catch(e){}
  try{ entBuff += addVariable(window.pageXOffset);			}catch(e){}
  try{ entBuff += addVariable(window.pageYOffset);			}catch(e){}
  try{ entBuff += addVariable(window.screen.availHeight);		}catch(e){}
  try{ entBuff += addVariable(window.screen.availLeft);			}catch(e){}
  try{ entBuff += addVariable(window.screen.availTop);			}catch(e){}
  try{ entBuff += addVariable(window.screen.availWidth);		}catch(e){}
  try{ entBuff += addVariable(window.screen.colorDepth);		}catch(e){}
  try{ entBuff += addVariable(window.screen.height);			}catch(e){}
  try{ entBuff += addVariable(window.screen.left);			}catch(e){}
  try{ entBuff += addVariable(window.screen.pixelDepth);		}catch(e){}
  try{ entBuff += addVariable(window.screen.top);			}catch(e){}
  try{ entBuff += addVariable(window.screen.width);			}catch(e){}
  try{ entBuff += addVariable(window.screenTop);			}catch(e){}
  try{ entBuff += addVariable(window.screenX);				}catch(e){}
  try{ entBuff += addVariable(window.screenY);				}catch(e){}
  try{ entBuff += addVariable(window.scrollMaxX);			}catch(e){}
  try{ entBuff += addVariable(window.scrollMaxY);			}catch(e){}
  try{ entBuff += addVariable(window.scrollX);				}catch(e){}
  try{ entBuff += addVariable(window.scrollY);				}catch(e){}
  entBuff += Math.random().toString();

  try{ entBuff += addVariable(document.plugins.length);          
       for (var i=0; i<document.plugins.length; i++){
	 try{ if(document.plugins[i].description) entBuff += addVariable(document.plugins[i].description);	}catch(e){}
	 try{ if(document.plugins[i].filename) entBuff += addVariable(document.plugins[i].filename);		}catch(e){}
	 try{ if(document.plugins[i].name) entBuff += addVariable(document.plugins[i].name);			}catch(e){}
       }
  }catch(e){}

  try{ entBuff += addVariable(navigator.mimeTypes.length);  
       for (var i=0; i<navigator.mimeTypes.length; i++){
	 try{ entBuff += addVariable(navigator.mimeTypes[i].description);	}catch(e){}
	 try{ entBuff += addVariable(navigator.mimeTypes[i].enabledPlugin);	}catch(e){}
	 try{ entBuff += addVariable(navigator.mimeTypes[i].suffixes);		}catch(e){}
	 try{ entBuff += addVariable(navigator.mimeTypes[i].type);		}catch(e){}
       }
  }catch(e){}

  try{ entBuff += addVariable(navigator.plugins.length);
       for (var i=0; i<navigator.plugins.length; i++){
	 try{ entBuff += addVariable(navigator.plugins[i].description);		}catch(e){}
	 try{ entBuff += addVariable(navigator.plugins[i].filename);		}catch(e){}
	 try{ entBuff += addVariable(navigator.plugins[i].name);		}catch(e){}
       }
  }catch(e){}

  try{ entBuff += addVariable(document.documentElement.innerHTML);	}catch(e){}


  return new eSvyARC4(new eSvyDigester().md5hex(entBuff));
}







