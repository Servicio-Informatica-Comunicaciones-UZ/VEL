#!/bin/bash
# Methods and global variables common to all management scripts go here

#TODO delete when system is stable enough
# Debugging tool: Every time a command return value is non-zero, it will stop and show the prompt on stderr
trap "read -p 'NON ZERO RETURN DETECTED (check if OK). Press return to go on.'" ERR



# Functions here are used in privileged and unprivileged config scripts.

###############
#  Constants  #
###############

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#Dialog options for all windows
DLGCNF="--shadow --cr-wrap --aspect 60 --insecure"
dlg="dialog $DLGCNF "


#Wizard log file
LOGFILE=/tmp/wizardLog

#Unpriileged user space temp directory for operations
TMPDIR=/home/vtuji/eLectionOperations

#Drive config vars file. These override those read form usbs.
VARFILE="$DATAPATH/root/vars.conf"

#If this file contains a 1, no privileged operation will execute
#unless the valid ciphering key can be rebuilt from the fragments
#stored on the active slot.
LOCKOPSFILE="/root/lockPrivileged"


#Approximate size of FS once it is loaded to RAM
ESTIMATEDCDFSSIZE=760 # TODO recalculate


#Source of random input
RANDFILE=/dev/random
#<DEBUG>
RANDFILE=/dev/urandom
#</DEBUG>

#Persistent drive paths (for encrypted, physical and loopback filesystems)
MOUNTPATH="/media/localpart"
MAPNAME="EncMap"
DATAPATH="/media/crypStorage"

#Encrypted FS parameters
CRYPTFILENAMEBASE="eLectionCryptFS-"
CRYPTDEV=""



#Default SSH port
DEFSSHPORT=22




#Tools aliases
urlenc="/usr/local/bin/urlencode"
addslashes="/usr/local/bin/addslashes"
fdisk="/sbin/fdisk"

PSETUP="sudo /usr/local/bin/privileged-setup.sh"
PVOPS="sudo /usr/local/bin/privileged-ops.sh"





######################
#  Global Variables  #
######################


#Redefine all unhandled dialog return codes to avoid app flow security
#issues
export DIALOG_ESC=1
export DIALOG_ERROR=1
export DIALOG_HELP=1
export DIALOG_ITEM_HELP=1





###############
#  Functions  #
###############



#Wrapper for the privileged  op
# 1-> h: halts the system (default)
#     r: reboots
shutdownServer(){
    $PVOPS shutdownServer "$1"
}


#Check if a string matches the syntax restrictions of some data type
# $1 --> expected data type
# $2 --> input value string
#Returns 0 if matching data type, 1 otherwise.
#STDOUT: If not matching, the allowed charset information for the data
#type is printed in some cases  # TODO: change all calls to expect allwedcharset on stdout
parseInput () {
    
    local ALLOWEDCHARSET=''
    local ret=0
    
    case "$1" in
	       
	       "ipaddr" ) #IP address
            echo "$2" | grep -oiEe "([0-9]{1,3}\.){3}[0-9]{1,3}" 2>&1 >/dev/null
            [ $? -ne 0 ] && return 1
            
	           local parts=$(echo "$2" | sed "s/\./ /g")
	           for p in $parts
	           do
	               [ "$p" -gt "255" ] && return 1
	           done
	       	   ;;



        "ipdn" ) #IP address or domain name
            local notIp=0
            local notDn=0
            
            echo "$2" | grep -oiEe "^([0-9]{1,3}\.){3}[0-9]{1,3}$" 2>&1 >/dev/null
           	[ $? -ne 0 ] && notIp=1
	           if [ "$notIp" -eq 0 ]
	           then
	               local parts=$(echo "$2" | sed "s/\./ /g")
	               for p in $parts
	               do
	                   [ "$p" -gt 255 ] && notIp=1
	               done
	           fi
	
	           echo "$2" | grep -oiEe "^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+$" 2>&1 >/dev/null
		          [ $? -ne 0 ] && notDn=1
            #echo "validating ip or dn Return: $((notIp & notDn))  notIp: $notIp  notDn: $notDn  str: $2"

            #If either of them is 0, returns zero (it is ip or dn), if both are 1 (not ip nor dn) returns 1
	           return $((notIp & notDn))
	           ;;
        
	       
	       "dn" ) #Domain name
	           echo "$2" | grep -oiEe "^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+" 2>&1 >/dev/null
		          [ $? -ne 0 ] && ret=1
	      	    ;;
        
	       "path" ) #System path
	           ALLOWEDCHARSET='- _ . + a-z A-Z 0-9'
	           echo "$2" | grep -oEe "^[/.]?([-_.+a-zA-Z0-9]+/?)*$" 2>&1 >/dev/null   # "^[/.]?(([^ ]|\\ )+/)*([^ ]|\\ )+"
	           [ $? -ne 0 ] && ret=1
	           ;;
	       
	       "user" ) #Valid username
	           ALLOWEDCHARSET='- _ . a-z A-Z 0-9'
	           echo "$2" | grep -oEe "^[-_.a-zA-Z0-9]+$"	2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "pwd" ) #Valid password
	           ALLOWEDCHARSET='-.·+_;:,*@#%|~!?()=& a-z A-Z 0-9'
	           echo "$2" | grep -oEe "^[-.·+_;:,*@#%|~!?()=&a-zA-Z0-9]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "int" ) #Non-zero Integer value string (natural number)
	           echo "$2" | grep -oEe "^[1-9][0-9]*$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "int0" ) #Integer (zero allowed)
	           echo "$2" | grep -oEe "^[0-9][0-9]*$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
	
	       "port" ) #Valid network port
	           echo "$2" | grep -oEe "^[1-9][0-9]*$" 2>&1 >/dev/null
	           if [ $? -ne 0 ] ; then
                ret=1
            elif [ "$2" -lt 1  -o  "$2" -gt 65535 ] ; then
                ret=1
            fi
	           ;;
        
	       "email" ) #Valid e-mail (with some restrictions over the standard)
            #Disallow / to avoid issues with server signature certificate generation process
	           echo "$2" | grep -oEe "^[-A-Za-z0-9_+.]+@[-.a-zA-Z]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
	       
	       "b64" ) #Base 64 string
	           echo "$2" | grep -oEe "^[0-9a-zA-Z/+]+=?=?$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "cc" ) #Two letter country code (no use in checking the whole set)
	           echo "$2" | grep -oEe "^[a-zA-Z][a-zA-Z]$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
	       
	       "freetext" ) #Any string (with limitations)
	           ALLOWEDCHARSET='- _<>=+@|·&!?.,: a-z A-Z 0-9'
            echo "$2" | grep -oEe "^[- _<>=+@|·&!?.,:a-zA-Z0-9]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "dni" ) #ID number
	           ALLOWEDCHARSET='- . a-z A-Z 0-9'
	           echo "$2" | grep -oEe "^[-. 0-9a-zA-Z]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
        "crypfilename" ) #Filename of an encrypted filesystem
	           echo "$2" | grep -oEe "^$CRYPTFILENAMEBASE[0-9]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "dev" ) #Path to a device: /dev/sda, hdb, md0...
	           echo "$2" | grep -oEe "^/dev/[shm][a-z]+[0-9]*$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
        * )
	           echo "parseInput: Wrong type -$1-"  >>$LOGFILE 2>>$LOGFILE
	           return 1
	           ;;	
    esac

    #For those who have one, print the allowed characters to match the
    #parser
    echo -n $ALLOWEDCHARSET
    
    return $ret
}



#Check if a certain variable has a proper value (content type is inferred from the variable name)
# $1 -> Variable name
# $2 -> Actual value
#Ret: 0 Ok, value meets the type syntax;  1 wrong value syntax
checkParameter () {
    
    #These vars can accept an empty value and we ch
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
	               echo "Variable $1 does not accept an empty value."  >>$LOGFILE 2>>$LOGFILE
	               return 1
	               ;;
	       esac	
    fi

    case "$1" in 
	       
	       "IPMODE" )
	           #Closed set value
	           if [ "$2" != "dhcp"   -a   "$2" != "static" ]
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
	#únicos valores aceptables
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
        parseInput freetext "$2"
	ret=$?
	[ $ret -ne 0 ] && return 1
	;;

	"ADMREALNAME" )
        parseInput freetext "$2"
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
	#únicos valores aceptables
	if [ "$2" -ne "1024"   -a   "$2" -ne "1152"  -a   "$2" -ne "1280" ]
	    then
	    return 1
	fi
	;;

	"WWWMODE" )
	#únicos valores aceptables
	if [ "$2" != "plain"   -a   "$2" != "ssl" ]
	    then
	    return 1
	fi
	;;

	"DEV" )  #En realidad no uso ninguna variable DEV (creo), pero lo pongo aquí por comodidad.
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

#Función para retornar datos entre el script privilegiado y el no privilegiado cuando no puede redirigirse la salida del comando (porque en la parte privilegiada saca dialogs)
# $1 -> Cadena a retornar
doReturn () {
    
    rm -f $RETBUFFER     >>$LOGFILE 2>>$LOGFILE
    touch $RETBUFFER >>$LOGFILE 2>>$LOGFILE    
    chmod 644 $RETBUFFER >>$LOGFILE 2>>$LOGFILE
    
    echo -n "$1" > $RETBUFFER

}


# imprime por stdout la cadena devuelta por la última op privilegiada 
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
#CLS=''
#NCLS=0
# TODO change usage of these globals. DEspite, we return the number of devs as the return value and we print the list

#Lists all connected usb drives
#Return value: number of drives
#Prints: list of drives
listUSBDrives () {   
    local devs=""
    local ndevs=0
    devs=$($PVOPS listUSBDrives list 2>>$LOGFILE)
    ndevs=$($PVOPS listUSBDrives count 2>>$LOGFILE)
    
    echo -n "$devs"
    return ndevs
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
      pw=$(echo $pw | sed -e "s/ //g") #Si la var del echo está entrecomillada, no realiza la sustitución correcta
      #Sustituimos: + -> .  / -> -  = -> : (para evitar porblemas de escape)
      pw=$(echo $pw | sed -e "s/\+/./g")
      pw=$(echo $pw | sed -e "s/\//-/g")
      pw=$(echo $pw | sed -e "s/=/:/g")
    done
}



# $1 -> el dev a vigilar
# $2 -> el mensaje a mostrar
# $3 -> "you didn't remove it" message
detectUsbExtraction (){    
    sync
    didnt=""
    
    #While dev is on th list of usbs, refresh and wait
    locdev=$( listUSBDrives | grep -o "$1" )
    while [ "$locdev" != "" ]
    do
        $dlg --msgbox "$2""\n$didnt"  0 0
        
        locdev=$( listUSBDrives | grep -o "$1" )
        didnt=$3
    done
}





#//// esta función se está invocando desde privops. hacer allí lo que sea para sacar esa llamada al wizard,  y pasar esta func al wizard-common.

#Retorno:
DEV=''
ISCLAUER=0

# $1 --> Mensaje de solicitud de disp.
# $2 --> Mensaje para no label --> Si es none, deja un sólo botón
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
        #Cancelada la inserción
	[ $? -ne 0 ]  &&  return 1
    fi
    
    
    DEV=''
    ISCLAUER=0
    
    while true 
      do
      
      listUSBDrives 2>/dev/null
      listDevs    2>/dev/null
      #echo "----->3   $(($NCLS + $NDEVS)) Cl: $CLS  Devs: $DEVS"
      
      while [ $(($NCLS + $NDEVS)) -lt 1 ]
	do
	#echo "----->4 "
	$dlg --msgbox $"No lo ha insertado. Hágalo ahora y pulse INTRO."  0 0
	listUSBDrives 2>/dev/null
	listDevs    2>/dev/null
      done
      
      #Workaround: Dado que a veces no se detecta el clauer como tal pq se ejecuta el clls en un momento crítico, volvemos a listar aquí, una vez ya ha detectado un dispositivo (que puede haber no identificado como clauer)
      sleep 1
      listUSBDrives 2>/dev/null
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
	  #  listUSBDrives 2>/dev/null
	  #  listDevs    2>/dev/null
	  #  sleep 1
	  #done
	  
	  exec 4>&1 
	  dev=$($dlg --cancel-label $"Refrescar"  --menu $"Múltiples dispositivos detectados.\nPor favor, seleccione uno." 0 0 $(($NCLS + $NDEVS)) $CLS $DEVS 2>&1 >&4)

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
