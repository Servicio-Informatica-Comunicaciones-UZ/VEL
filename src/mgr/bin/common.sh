#!/bin/bash


#TODO disable when stable enough
# Debugging tool: Every time a command return value is non-zero, it will stop and show the prompt on stderr
trap "read -p 'NON ZERO RETURN DETECTED (check if OK). Press return to go on.'" ERR



# Functions here are used in privileged and unprivileged config scripts.

###############
#  Constants  #
###############



#Dialog options for all windows
DLGCNF="--shadow --cr-wrap --aspect 60 --insecure"

#Wizard log file
LOGFILE=/tmp/wizardLog

#Unpriileged user space temp directory for operations
TMPDIR=/home/vtuji/eLectionOperations


#Approximate size of FS once it is loaded to RAM
ESTIMATEDCDFSSIZE=760 # TODO recalculate


#Source of random input
RANDFILE=/dev/random
#<DEBUG>
RANDFILE=/dev/urandom
#</DEBUG>


MOUNTPATH="/media/localpart"
MAPNAME="EncMap"
DATAPATH="/media/crypStorage"

#Drive config vars file. These override those read form clauers.
VARFILE="$DATAPATH/root/vars.conf"

CRYPTFILENAMEBASE="eLectionCryptFS-"

CRYPTDEV=""

cryptosize=4 #(MB a dedicar a la part crypto)





urlenc="/usr/local/bin/urlencode"
addslashes="/usr/local/bin/addslashes"




DEFNFSPORT=2049
DEFSMBPORT=139    #y el 445 tb es est�ndar
DEFISCSIPORT=3260 #Confirmado (para portal y target)
DEFSSHPORT=22


#If this file contains a 1, anyone executing one of these OPS, must have previouly put the key shares on a certain dir, so this script rebuilds them and checks if the key is valid.
LOCKOPSFILE="/root/lockPrivileged"








######################
#  Global Variables  #
######################


#Defines del dialog, para evitar inc�modos c�digos de retorno que me fastidien el flujo y la seguridad 

export DIALOG_ESC=1
export DIALOG_ERROR=1
export DIALOG_HELP=1
export DIALOG_ITEM_HELP=1


#La mayor�a de ejecutables, (incluso los del clauer desde que lo compilo dentro). Est�n en usr/local/bin
export PATH=$PATH:/usr/local/bin




###############
#  Functions  #
###############


fdisk=/sbin/fdisk

PSETUP="sudo /usr/local/bin/privileged-setup.sh"
PVOPS="sudo /usr/local/bin/privileged-ops.sh"



dlg="dialog $DLGCNF "


dummyretval() { return $1; }



# 1-> h --> halt r --> reboot default--> halt
shutdownServer(){
    
    $PVOPS shutdownServer "$1"

}










# $1 --> el tipo de datos esperado
# $2 --> la cadena de entrada
#Ret: 0 si pertenece al tipo de datos esperado o 1 si no.
#ALLOWEDCHARSET  --> Si el retorno es 1, indica qu� caracteres son legales, en algunos campos no estructurados.
parseInput () {
    
    ALLOWEDCHARSET=''
    
    case "$1" in
	
	"ipaddr" )

        echo "$2" | grep -oiEe "([0-9]{1,3}\.){3}[0-9]{1,3}" 2>&1 >/dev/null

	[ $? -ne 0 ] && return 1

	parts=$(echo "$2" | sed "s/\./ /g")
	
	for p in $parts
	  do
	  [ "$p" -gt "255" ] && return 1
	done
	
	;;
	
	"dn" )
	      
		
	echo "$2" | grep -oiEe "^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+" 2>&1 >/dev/null
		
	[ $? -ne 0 ] && return 1
	      
	#Valida cualquier dominio
	#  /^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+((a[cdefgilmnoqrstuwxz]|aero|arpa)|(b[abdefghijmnorstvwyz]|biz)|(c[acdfghiklmnorsuvxyz]|cat|com|coop)|d[ejkmoz]|(e[ceghrstu]|edu)|f[ijkmor]|(g[abdefghilmnpqrstuwy]|gov)|h[kmnrtu]|(i[delmnoqrst]|info|int)|(j[emop]|jobs)|k[eghimnprwyz]|l[abcikrstuvy]|(m[acdghklmnopqrstuvwxyz]|mil|mobi|museum)|(n[acefgilopruz]|name|net)|(om|org)|(p[aefghklmnrstwy]|pro)|qa|r[eouw]|s[abcdeghijklmnortvyz]|(t[cdfghjklmnoprtvwz]|travel)|u[agkmsyz]|v[aceginu]|w[fs]|y[etu]|z[amw])$/i
	;;



	"ipdn" ) #Ip o DN
        notIp=0
        notDn=0

        echo "$2" | grep -oiEe "^([0-9]{1,3}\.){3}[0-9]{1,3}$" 2>&1 >/dev/null

	[ $? -ne 0 ] && notIp=1
	
	if [ "$notIp" -eq 0 ]
	    then
	    parts=$(echo "$2" | sed "s/\./ /g")	
	    for p in $parts
	      do
	      [ "$p" -gt 255 ] && notIp=1
	    done
	fi
	
	echo "$2" | grep -oiEe "^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+$" 2>&1 >/dev/null
		
	[ $? -ne 0 ] && notDn=1
        
	#echo "modo ipDN Retornando: $((notIp & notDn))  notIp: $notIp  notDn: $notDn  cadena: $2"
		
	return $((notIp & notDn)) #Si uno de los dos es 0 (o es ip o es DN), ser� 0. si los dos son 1 (no es ip ni dn), ser� 1
	;;
	
	"path" )
	ALLOWEDCHARSET='- _ . + a-z A-Z 0-9'
	echo "$2" | grep -oEe "^[/.]?([-_.+a-zA-Z0-9]+/?)*$" 2>&1 >/dev/null   # "^[/.]?(([^ ]|\\ )+/)*([^ ]|\\ )+"
	[ $? -ne 0 ] && return 1
	;;
	
	"user" )
	ALLOWEDCHARSET='- _ . a-z A-Z 0-9'
	echo "$2" | grep -oEe "^[-_.a-zA-Z0-9]+$"	2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;

	"pwd" ) #Es para el pwd del samba. Debo poder limitar el juego de caracteres porque hago un eval para establecer la variable desde la config. Restringir al menos " y ' y $
	ALLOWEDCHARSET='-.�+_;:,*@#%|~!?()=& a-z A-Z 0-9'
	echo "$2" | grep -oEe "^[-.�+_;:,*@#%|~!?()=&a-zA-Z0-9]+$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;

	"iscsitar" )
	echo "$2" | grep -oEe "(^eui\.[0-9A-Fa-f]+|iqn\.[0-9]{4}-[0-9]{2}\.([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+(:[^ ]*?)?)$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;
	
	"int" )
	echo "$2" | grep -oEe "^[1-9][0-9]*$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;

	"int0" )
	echo "$2" | grep -oEe "^[0-9][0-9]*$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;
	
	"port" )
	echo "$2" | grep -oEe "^[1-9][0-9]*$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	[ "$2" -lt 1 ] && return 1
	[ "$2" -gt 65535 ] && return 1
	;;

	"email" )  #No permitir el /, por la generaci�n del cert de firma del servidor
	#Deprecated e-mail regexp. issues with openssl. "^[-A-Za-z0-9!#%\&\`_=\/$\'*+?^{}|~.]+@[-.a-zA-Z]+$"
	#Demasiado rara. nadie la usa: "^[-A-Za-z0-9!#%\&\`_=$*+?^{}|~.]+@[-.a-zA-Z]+$"
	echo "$2" | grep -oEe "^[-A-Za-z0-9_+.]+@[-.a-zA-Z]+$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;
	
	"b64" )
	echo "$2" | grep -oEe "^[0-9a-zA-Z/+]+=?=?$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;

		
	"cc" )
	echo "$2" | grep -oEe "^[a-zA-Z][a-zA-Z]$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;
	
	"name" ) #No permitir el /, por la generaci�n del cert de firma del servidor
	ALLOWEDCHARSET='- _<>=+@|�&!?.,: a-z A-Z 0-9'
	echo "$2" | grep -oEe "^[- _<>=+@|�&!?.,:a-zA-Z0-9]+$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;

	"completename" )
	ALLOWEDCHARSET='- _<>=+@|�&!?.,: a-z A-Z 0-9'
	echo "$2" | grep -oEe "^[- _<>=+@|�&!?.,:a-zA-Z0-9]+$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;


	"dni" )
	ALLOWEDCHARSET='- . a-z A-Z 0-9'
	echo "$2" | grep -oEe "^[-. 0-9a-zA-Z]+$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;


	"crypfilename" )
	echo "$2" | grep -oEe "^$CRYPTFILENAMEBASE[0-9]+$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;

	"dev" )
	echo "$2" | grep -oEe "^/dev/[shm][a-z]+[0-9]*$" 2>&1 >/dev/null
	[ $? -ne 0 ] && return 1
	;;


	* )
	echo "parseInput: tipo erroneo"  >>$LOGFILE 2>>$LOGFILE
	return 1
	;;	
    esac

    return 0
}


# $1 -> El nombre de la variable (a partir de este, sabremos que tipo de input esperamos)
# $2 -> El valor, que deber� ser comprobado
#Ret: 0 Ok;  1 Bad Format
checkParameter () {
    

    #Comprobamos aquellos par�metros que expl�citamente pueden aceptar un contenido vac�o

    if [ "$2" == "" ]
	then
	
	case "$1" in 
	    
	    "MAILRELAY" )
            return 0
	    ;;

	    "SERVEREMAIL" )
            return 0
	    ;;	    

	    * )
	    echo "Parameter nos accepted with an empty value: $1"  >>$LOGFILE 2>>$LOGFILE
	    return 1
	    ;;
	
        esac	
    fi

    case "$1" in 
	
	"IPMODE" )   
	#�nicos valores aceptables
	if [ "$2" != "dhcp"   -a   "$2" != "user" ]
	    then
	    return 1
	fi
	;;
	
	
	"IPADDR" | "MASK" | "GATEWAY" | "DNS1" | "DNS2"  )
	parseInput ipaddr "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	
	
	"FQDN" | "SERVERCN" )
        parseInput dn "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	

	"USINGSSHBAK" )
	[ "$2" != "0" -a "$2" != "1" ] && return 1
	;;
	
	"DRIVEMODE" )
	#�nicos valores aceptables
	if [ "$2" != "local"   -a   "$2" != "iscsi"   -a   "$2" != "nfs"   -a   "$2" != "samba"   -a   "$2" != "file" ]
	    then
	    return 1
	fi
	;;	
	
	
	"DRIVELOCALPATH" | "NFSPATH" | "SMBPATH" | "FILEPATH" | "CRYPTFILENAME" )
        parseInput path "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	
	"NFSSERVER" | "SMBSERVER" | "ISCSISERVER" | "MAILRELAY" | "SSHBAKSERVER" )
        parseInput ipdn "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	
	"NFSPORT" | "SMBPORT" | "ISCSIPORT" | "SSHBAKPORT" )
        parseInput port "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;	

	"ISCSITARGET" )
        parseInput iscsitar "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	
	
	"SMBUSER" | "SSHBAKUSER" | "ADMINNAME" )
        parseInput user "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	
	
	"SMBPWD" | "DBPWD" | "SSHBAKPASSWD" | "PARTPWD" | "MYSQLROOTPWD" | "DEVPWD" | "MGRPWD" )
        parseInput pwd "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	
	
	"NFSFILESIZE" | "SMBFILESIZE" | "FILEFILESIZE" | "SHARES" | "THRESHOLD" )
        parseInput int "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;

	"INT" )
        parseInput int0 "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;
	
	"CRYPTFILENAME" )
        parseInput crypfilename "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;


	"MGREMAIL" | "SERVEREMAIL" )
        parseInput email "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;


	"SITESORGSERV" | "SITESNAMEPURP" )
        parseInput name "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;

	"ADMREALNAME" )
        parseInput completename "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;

	"ADMIDNUM" )
        parseInput dni "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;

	"SITESCOUNTRY" | "COUNTRY" )
        parseInput cc "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;


	"KEYSIZE" )
	#�nicos valores aceptables
	if [ "$2" -ne "1024"   -a   "$2" -ne "1152"  -a   "$2" -ne "1280" ]
	    then
	    return 1
	fi
	;;

	"WWWMODE" )
	#�nicos valores aceptables
	if [ "$2" != "plain"   -a   "$2" != "ssl" ]
	    then
	    return 1
	fi
	;;

	"DEV" )  #En realidad no uso ninguna variable DEV (creo), pero lo pongo aqu� por comodidad.
        parseInput dev "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;


	* )
	echo "Not Expected Parameter: $1"  >>$LOGFILE 2>>$LOGFILE
	return 1
	;;	
	
    esac
	
    return 0	    
}





RETBUFFER=$TMPDIR/returnBuffer

#Funci�n para retornar datos entre el script privilegiado y el no privilegiado cuando no puede redirigirse la salida del comando (porque en la parte privilegiada saca dialogs)
# $1 -> Cadena a retornar
doReturn () {
    
    rm -f $RETBUFFER     >>$LOGFILE 2>>$LOGFILE
    touch $RETBUFFER >>$LOGFILE 2>>$LOGFILE    
    chmod 644 $RETBUFFER >>$LOGFILE 2>>$LOGFILE
    
    echo -n "$1" > $RETBUFFER

}


# imprime por stdout la cadena devuelta por la �ltima op privilegiada 
getReturn () {
    
    if [ -e "$RETBUFFER" ]
	then
	cat "$RETBUFFER"
    fi
    
    rm -f $RETBUFFER  >>$LOGFILE 2>>$LOGFILE
}












# TODO This function lists usbs that are not clauers (or maybe all usbs, I dn't care). DElete. Now only usbs are detected and if used to know if it contains a keystre or not, make another function. Sanitize all calls and delete
#Retorno
#DEVS=''
#NDEVS=0
#
#listDevs () { 
#
#    DEVS=$($PVOPS listDevs list)
#    NDEVS=$($PVOPS listDevs count)
#
#}

#TODO change listclauers fro list usbs
#Wrapper function for the privileged operation
#Returns:
CLS=''
NCLS=0
listClauers () {   
    CLS=$($PVOPS listClauers list)
    NCLS=$($PVOPS listClauers count)
}






# Checks if a service is running
# $1 -> service name
isRunning () {
    
    [ "$1" == "" ] && return 1
    
    if ps aux | grep -e "$1" | grep -v "grep" >>$LOGFILE 2>>$LOGFILE 
	   then
	       #Running
	       return 0
    else
	       #Not running
	       return 1
    fi
}


# $1 -> Longitud en chars del pwd (opcional)
#Retorno: $pw -> es el password
randomPassword () {
    
    pwlen=91
    
    [ "$1" != "" ] && pwlen="$1"
    

    pw=""

    while [ "$pw" == "" ]
      do
      pw=$(openssl rand -rand $RANDFILE -base64 $pwlen  2>>$LOGFILE)
      pw=$(echo $pw | sed -e "s/ //g") #Si la var del echo est� entrecomillada, no realiza la sustituci�n correcta
      #Sustituimos: + -> .  / -> -  = -> : (para evitar porblemas de escape)
      pw=$(echo $pw | sed -e "s/\+/./g")
      pw=$(echo $pw | sed -e "s/\//-/g")
      pw=$(echo $pw | sed -e "s/=/:/g")
    done
}




### Hay un problema gordo: Si se extrae el clauer justo en el momento
### en que se est� ejecutando el clls, este se queda colgado
### eternamente. (No devuelve error ni nada. s�mplemente no
### termina). Por eso, en vez de implementar bucles de autodetecci�n
### de extracci�n, lo har� con di�logos bloqueantes

# $1 -> el dev a vigilar
# $2 -> el mensaje a mostrar
detectClauerextraction (){

    #echo "----Entrando en detect: 1: $1    2: $2"
    
    sync
    
    didnt=""
    #Mientras el dev aparezca en la lista de clauers o la de devs, refrescarla y esperar
    locdev=$(echo "$CLS $DEVS" | grep -o "$1")
    while [ "$locdev" != "" ]
      do
      $dlg --msgbox "$2""\n$didnt"  0 0
      
      #echo "----detect 3 locdev: $locdev"

      #echo "----detect 3.1"
      listClauers 2>/dev/null
      #echo "----detect 3.2"
      listDevs    2>/dev/null
      #echo "----detect 3.3"
      locdev=$(echo "$CLS $DEVS" | grep -o "$1")
      #echo "----detect 4 locdev: $locdev"

      didnt=$"No lo ha retirado. H�galo y pulse INTRO."
    done
}





#//// esta funci�n se est� invocando desde privops. hacer all� lo que sea para sacar esa llamada al wizard,  y pasar esta func al wizard-common.

#Retorno:
DEV=''
ISCLAUER=0

# $1 --> Mensaje de solicitud de disp.
# $2 --> Mensaje para no label --> Si es none, deja un s�lo bot�n
insertClauerDev () {
    #dlg --infobox $"Inserte un dispositivo"  0 0
    #$dlg --msgbox "$1" 0 0
    
    #echo "----->1"

    if [ "$2" == none ]
	then
	$dlg --msgbox "$1" 0 0
	#echo "----->2.1"
    else
	$dlg --yes-label $"Continuar" --no-label $2  --yesno "$1" 0 0
        #Cancelada la inserci�n
	[ $? -ne 0 ]  &&  return 1
    fi
    
    
    DEV=''
    ISCLAUER=0
    
    while true 
      do
      
      listClauers 2>/dev/null
      listDevs    2>/dev/null
      #echo "----->3   $(($NCLS + $NDEVS)) Cl: $CLS  Devs: $DEVS"
      
      while [ $(($NCLS + $NDEVS)) -lt 1 ]
	do
	#echo "----->4 "
	$dlg --msgbox $"No lo ha insertado. H�galo ahora y pulse INTRO."  0 0
	listClauers 2>/dev/null
	listDevs    2>/dev/null
      done
      
      #Workaround: Dado que a veces no se detecta el clauer como tal pq se ejecuta el clls en un momento cr�tico, volvemos a listar aqu�, una vez ya ha detectado un dispositivo (que puede haber no identificado como clauer)
      sleep 1
      listClauers 2>/dev/null
      listDevs    2>/dev/null
      
      if [ $(($NCLS + $NDEVS)) -eq 1 ]
	  then
	  
	  DEV=$(echo $CLS | grep -oEe "/dev/[a-z]+?")
	  ISCLAUER=1
	  
	  [ "$CLS" == "" ] && DEV=$(echo $DEVS | grep -oEe "/dev/[a-z]+?")
	  [ "$CLS" == "" ] && ISCLAUER=0

	  #echo "Disp insertado:  "$DEV
	  #echo "Es Clauer:       "$ISCLAUER
	  

      fi

 
      
      if [ $(($NCLS + $NDEVS)) -gt 1 ]
	  then
	  #$dlg --infobox $"Multiples dispositivos detectados.\nPor favor, retire todos menos uno."  0 0
	  
	  #while [ $(($NCLS + $NDEVS)) -gt 1 ]
	  #  do
	  #  listClauers 2>/dev/null
	  #  listDevs    2>/dev/null
	  #  sleep 1
	  #done
	  
	  exec 4>&1 
	  dev=$($dlg --cancel-label $"Refrescar"  --menu $"M�ltiples dispositivos detectados.\nPor favor, seleccione uno." 0 0 $(($NCLS + $NDEVS)) $CLS $DEVS 2>&1 >&4)

	  #echo "opId elegida:  "$dev

	  
	  #Si se refresca (cancela), se vuelven a listar los disp y se sigue.
	  [ $? -ne 0 ] && continue
	  
	  iscl=$(echo $CLS" "$DEVS | grep -oEe "$dev (.+?)( |$)" | cut -d ' ' -f 2)


	  ISCLAUER=1
	  [ "$iscl" == '-' ] && ISCLAUER=0
	  
	  DEV=$dev
	  
	  #echo "Disp elegido:  "$DEV
	  #echo "Es Clauer:     "$ISCLAUER
      fi


      
      [ "$DEV" != '' ] && break
      

      #if [ $(($NCLS + $NDEVS)) -eq 1 ]
      #    then 
      #    break;
      #fi
      
      sleep 1
    done
    
    
    return 0
#$dlg --infobox $"Clauers detectados""($NCLS):\n$CLS"  0 0
}






hex2b64 () {  
    python -c "
import sys
import binascii
import base64
import re
p = re.compile('\s+')
hex_string = sys.stdin.read()
hex_string = hex_string.strip()
if len(hex_string)%2 == 1:
  hex_string = '0'+hex_string
hex_string = p.sub('', hex_string)
sys.stdout.write(base64.b64encode(binascii.unhexlify(hex_string)))
    
"
}
