#!/bin/bash


. /usr/local/bin/common.sh 

. /usr/local/bin/privileged-common.sh

. /usr/local/bin/firewall.sh






# //// Revisar todas las ops y ver cu�les deben estar bloqueadas en mant (ej, clops init)

#//// Todas las ops y las de psetup, acabarlas con un exit 0, revisar el resto de exits y returns y ser coherente con los retornos de error.




#//// Hay ops que no requieren reconstruir la clave.  --> Hay algunas que son s�lo para el setup separarlas y al acabar el setup ya no se podr�n ejecutar (revisar qu� ops s�lo se ejecutan en el setup). Las otras, ponerlas antes d ela verificaci�n de clave.



#Comprueba si la llave en el slot coincide con la de cifrado de la part.
# 1-> Slot en el que buscar
# Ret: 0: Llave correcta !0 -> Error 1(no se pudo reconstruir) 2(llave vacia) 3 (llave incorrecta)
checkClearance () {
    
    local base=$(cat $ROOTTMP/dataBackupPassword 2>>$LOGFILE)
    
    if [ -s $ROOTTMP/slot$1/key ]
	then
	:
    else
	return 1
    fi
    
    local chal=$(cat $ROOTTMP/slot$1/key 2>>$LOGFILE)

    if [ "$chal" == ""  ]
    	then
	return 2
    fi
    
    if [ "$chal" != "$base"  ]
	then
	return 3
    fi
    
    return 0
}






############## Verificaci�n de llave ##############
#Pasado este punto, todas las operaciones verificar�n si pueden reconstruir la llave antes de autorizar a ser ejecutadas.


if [ -f "$LOCKOPSFILE" ]
    then
    :
else
    echo "ERROR: El fichero $LOCKOPSFILE no exise, y debe existir siempre, y solo puede contener 0 o 1"   >>$LOGFILE 2>>$LOGFILE
    exit 1
fi


lockvalue=$(cat "$LOCKOPSFILE")

if [ "$lockvalue" -eq 0 ] 2>>$LOGFILE
    then
    echo "privilegedOps: Esta op se ejecuta sin pedir permiso"   >>$LOGFILE 2>>$LOGFILE
else



#//// Aqu� implementar verificaci�n de clauer. (llamar a checkClearance. cuando ejecute una innerkey reset es posible que deba comprobar ambos slots. implementar entonces si eso)  Si no existe un fichero que contenga la llave reconstruida (verificar llave frente a la part? puede ser muy costoso. en la func que la reconstruye, probarla, y si falla borrar el fichero).

:


fi


#//// hay ops que nunca necesian verificaci�n. listarlas y saltarse la comprobaci�n.
#//// antes de la verificaci�n (y obviamente de ver si se necesita verif o no)listar todos los c�digos de operaci�n existentes en este fichero y filtrar los que NO se pueden llamar si no estamos en setup, aparte de si necesitan verificaci�n o no








####################### Gesti�n de variables ############################


if [ "$1" == "vars" ] 
    then

 #Para que el wizard le pase los valores de las variables definidas por el usuario en la inst.
 # 3-> destino c (clauer) d (disco) r (memoria) s (slot activo)
 # 4-> var name
 # 5-> var value
 if [ "$2" == "setVar" ] 
     then
     
     #////implementar limitaci�n  de escritura a ciertas variables cuando running?

     checkParameterOrDie "$4" "$5" 0  #//// Te�ricamente todos los params est�n en checkparameter. probar esto.

     setPrivVar "$4" "$5" "$3"

     exit 0
 fi



 #Para que el wizard reciba los valores de ciertas variables durante el reset.
 # 3-> origen c (clauer) d (disco) r (memoria) s (slot activo)
 # 4-> var name
 if [ "$2" == "getVar" ]  #//// probar
     then

     if [ "$3" != "c" -a "$3" != "d" -a "$3" != "r" -a "$3" != "s" ]
	 then
	 echo "getVar: bad data source: $3" >>$LOGFILE 2>>$LOGFILE
	 exit 1
     fi


# Asegurarme de que $SITESCOUNTRY $SITESORGSERV $SITESEMAIL est�n en alg�n fichero de variables      
     if [ "$4" != "WWWMODE" -a "$4" != "SSHBAKPORT" -a "$4" != "SSHBAKSERVER" -a "$4" != "FQDN"  -a "$4" != "USINGSSHBAK" -a "$4" != "copyOnRAM"  -a "$4" != "SHARES" -a "$4" != "SITESCOUNTRY" -a "$4" != "SITESORGSERV" -a "$4" != "SITESEMAIL" -a "$4" != "ADMINNAME" ]  #//// SEGUIR: sacar esta comprobaci�n a una func.
	 then
	 echo "getVar: no permission to read var $4" >>$LOGFILE 2>>$LOGFILE
	 exit 1
     fi

     getPrivVar "$3" "$4" aux

     echo -n $aux

     exit 0
 fi

fi
















######################## Operaciones #######################


#//// verif en mant: indiferente

if [ "$1" == "listDevs" ] 
    then
    
#Retorno
DEVS=''
NDEVS=0

listDevs () { 

    #Listar dispositivos usb
    
    #echo "ld: 1"
    CLAUERS=$(clls -l | grep -ioEe "/dev/[a-z]+?" 2>/dev/null)
    #echo "ld: 2"
    DEVS="" 
    #echo "ld: 3"
    NDEVS=0 
    #echo "ld: 4"

    usbs=$(ls /proc/scsi/usb-storage/ 2>/dev/null) 

    #echo "USBS: $usbs"

    for f in $usbs  #Sustituyo el ; por un  &&  porque un fallo en el cd es fatal, ya que har� el ls del dir actual que puede contener cualquier cosa.
      do
      #echo "ld: 4.1"
      currdev=$(sginfo -l | sed -ne "s/.*=\([^ ]*\).*$f.*/\1/p") #Lista los discos serie que son usb, no los sata ni iscsi
      #echo "ld: 4.2"

      #Comprobamos si el device es accesible o tiene fallos
      iotest=$(head -c 1 $currdev 2>/dev/null | wc -c)
      [ $iotest -eq 0 ] && continue
      

      dup=0
      for C in $CLAUERS
	do
	#echo "ld: 4.2.1"
	if [ "$currdev" == ""  -o  $C == "$currdev" ]  #Si no tenemos un dev (por error en el for) o este aparece entre los clauers
	    then
	    #echo "ld: 4.2.1.1"
	    dup=1
	    break
	fi
	#echo "ld: 4.2.2"
      done
      #echo "ld: 4.3"
      # Si este dev no consta entre los clauers
      if [ $dup -ne 1 ]
	  then
	  #echo "ld: 4.3.1"
	  DEVS=$DEVS" $currdev -" #Si toco el '-' que indica que no es clauer, cambiar tb el grep de insertclauerdev 
	  #echo "ld: 4.3.2"
	  NDEVS=$(($NDEVS + 1 )) 
	  #echo "ld: 4.3.3 NDEVS = $NDEVS"
      fi
      #echo "ld: 4.4"
    done
    #echo "ld: 5"
}


  listDevs

  if [ "$2" == "list" ]
      then
      echo $DEVS
      exit 0
  elif [ "$2" == "count" ]
      then
      echo $NDEVS
      exit 0
  else
      exit 1
  fi


  exit 0
fi







#//// verif en mant: indiferente

if [ "$1" == "listClauers" ] 
    then


#Retorno:
CLS=''
NCLS=0

listClauers () {
    #echo "lc: 1"
    ##aux=$(strace clls -l 2>/dev/tty2 ) # 2>/dev/null)   
    aux=$(clls -l 2>/dev/null)
    #echo "aux1: $aux"
    
    #Workaround que te cagas: A veces, al hacer un clls -l no detecta un dev que si es clauer. Y no lo detecta hasta que se hace un clls a pelo (alg�n bug de la impl., probablemente relacionado con el refresco de cache). As� que haremos eso: un clls+clls -l si falla el primer clls -l
    #echo "lc: 2"
    nul=$(clls 2>&1 >/dev/null)
    #echo "lc: 3"
    aux=$(clls -l 2>/dev/null)
    #echo "aux1.5: $aux"
    #echo "lc: 4"    
    aux=$(echo $aux | grep -ioEe "/dev/[a-z]+?")
    #echo "aux2: $aux"
    #echo "lc: 5"
    NCLS=$(echo $aux | wc -w)
    #echo "lc: 6"
    CLS=''
    #echo "lc: 7"
    count=0
    for d in $aux
      do
      #echo "lc: 7.1"
      CLS=$CLS" $d "$"Clauer"
      #echo "lc: 7.2"
      count=$(($count + 1 ))
      #echo "lc: 7.3 count: $count"
    done
    #echo "lc: 8"
}


listClauers


  if [ "$2" == "list" ]
      then
      echo $CLS
      exit 0
  elif [ "$2" == "count" ]
      then
      echo $NCLS
      exit 0
  else
      exit 1
  fi


  exit 0
fi







#//// verif en mant: si

#2 -> Modo de acceso a la partici�n cifrada "$DRIVEMODE"
#3 -> Ruta donde se monta el dev que contiene el fichero de loopback "$MOUNTPATH" (puede ser cadena vac�a)
#4 -> Nombre del mapper device donde se monta el sistema cifrado "$MAPNAME"
#5 -> Path donde se monta la partici�n final "$DATAPATH"
#6 -> Ruta al dev loop que contiene la part cifrada "$CRYPTDEV"  (puede ser cadena vac�a)
#7 -> iscsitarget   (puede ser cadena vac�a)
#8 -> iscsiserver   (puede ser cadena vac�a)
#9 -> iscsiport     (puede ser cadena vac�a)
if [ "$1" == "umountCryptoPart" ] 
    then

    #*-*- revisar qu� par�metros cojo de los ficheros (ver si lo llamo antes de que haya ficheros)

    umountCryptoPart "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
    
    exit 0
fi





#//// verif en mant: no

if [ "$1" == "shutdownServer" ] 
    then

# 2-> h --> halt r --> reboot default--> halt
shutdownServer(){
    
    
    echo "System $FQDN is going down on $(date)" | mail -s "System $FQDN shutdown" root
    sleep 3
    
    
    #Apagar el mysql y el apache (porque bloquean el acceso a la partici�n)
    /etc/init.d/apache2 stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/postfix stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/mysql   stop  >>$LOGFILE 2>>$LOGFILE  
    
    umountCryptoPart "$DRIVEMODE"  "$MOUNTPATH"  "$MAPNAME"  "$DATAPATH" "$CRYPTDEV"  "$ISCSITARGET" "$ISCSISERVER" "$ISCSIPORT"

    rm -rf $TMPDIR/*
    clear
    
    if [ "$2" == "h" ] 
	then
	halt
	return 0
    fi

    if [ "$2" == "r" ] 
	then
	reboot
	return 0
    fi
    
    halt
}

shutdownServer "" "$2"

exit $?

fi


#//// verif en mant: ?


if [ "$1" == "stopServers" ] 
    then
    /etc/init.d/apache2 stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/mysql   stop  >>$LOGFILE 2>>$LOGFILE  
    /etc/init.d/postfix stop  >>$LOGFILE 2>>$LOGFILE 

    exit 0

fi


#//// verif en mant: si

if [ "$1" == "rootShell" ] 
    then

    exec /bin/bash

    exit 1
fi


#//// verif en mant: no


# ////. Hacer que los keyscan y el almacenamiento de claves sea op de root sin verif. asegurarme de que s�lo es el root quien ejecuta los backups. --> PARA PODER ACEPTAR ESTO, NO DEBE RECIBIR PARAMS VARIABLES. HACER ESTA OP GENERALISTA CON VERIF Y HACER OTRA QUE ACCEDA A LOS VALORES DE SSHBAK A LAS VARIABLES. cambiar las invocaciones por las de la sin params (y si no, hacer esta sin params y basta. ver tb el fichero backup.sh ).

if [ "$1" == "sshKeyscan" ] 
    then

#-->2 SSHBAKPORT
#-->3 SSHBAKSERVER
    
    mkdir -p /root/.ssh/  >>$LOGFILE 2>>$LOGFILE
    chmod 755 /root/.ssh/  >>$LOGFILE 2>>$LOGFILE
    touch /root/.ssh/known_hosts  >>$LOGFILE 2>>$LOGFILE
    chmod 644 /root/.ssh/known_hosts  >>$LOGFILE 2>>$LOGFILE

    mkdir -p /home/vtuji/.ssh/  >>$LOGFILE 2>>$LOGFILE
    chmod 755 /home/vtuji/.ssh/  >>$LOGFILE 2>>$LOGFILE
    chown vtuji:vtuji /home/vtuji/.ssh/  >>$LOGFILE 2>>$LOGFILE


    ssh-keyscan -p "$2" -t rsa1,rsa,dsa "$3" > /root/.ssh/known_hosts  2>>$LOGFILE
    ret="$?"
    
    cp /root/.ssh/known_hosts /home/vtuji/.ssh/known_hosts  >>$LOGFILE 2>>$LOGFILE
    chmod 644 /home/vtuji/.ssh/known_hosts  >>$LOGFILE 2>>$LOGFILE
    chown vtuji:vtuji /home/vtuji/.ssh/known_hosts  >>$LOGFILE 2>>$LOGFILE

    echo $ret
    echo "retorno de sshKeyscan: $ret" >>$LOGFILE 2>>$LOGFILE
    exit $ret
fi





#//// verif en mant: si


if [ "$1" == "configureNetwork" ] 
    then

    # 2-> 'noPanic' o ''
    DOFORMAT="$3"
    

    IPMODE="$4"
    IPADDR="$5"
    MASK="$6"
    GATEWAY="$7"
    DNS1="$8"
    DNS2="$9"
    FQDN="${10}"
    
    
    #////probar

    #Si alguna variable estaba vac�a (probablemente todas o ninguna, son todas obligatorias) la lee de disco
    if [ "$IPMODE" == "" ]
	then
	echo "configureNetwork: Reading vars from disk file..." >>$LOGFILE 2>>$LOGFILE
	getPrivVar c IPMODE
	getPrivVar c IPADDR
	getPrivVar c MASK
	getPrivVar c GATEWAY
	getPrivVar c DNS1
	getPrivVar c DNS2
	getPrivVar c FQDN
    fi
    
    checkParameterOrDie IPMODE  "$IPMODE"  "0"
    checkParameterOrDie IPADDR  "$IPADDR"  "0"
    checkParameterOrDie MASK    "$MASK"    "0"
    checkParameterOrDie GATEWAY "$GATEWAY" "0"
    checkParameterOrDie DNS1    "$DNS1"    "0"
    checkParameterOrDie DNS2    "$DNS2"    "0"
    checkParameterOrDie FQDN    "$FQDN"    "0"


configureNetwork () {

    exec 4>&1 
    
    ######### Configurar acceso a internet ##########
    sleep 1


    if [ "$IPMODE" == "user" ]
	then
	
	killall dhclient3 dhclient  >>$LOGFILE 2>>$LOGFILE 
	
	
	interfacelist=$(cat /etc/network/interfaces | grep  -Ee "^[^#]*iface" | sed -re 's/^.*iface\s+([^\t ]+).*$/\1/g')
        #Cambiamos la configuraci�n de network/interfaces para marcar todas las ifs menos lo como manual
	for intfc in $interfacelist
	  do
	  
	  if [ "$intfc" != "lo" ] ; then
	      sed  -i -re "s/^([^#]*iface\s+$intfc\s+\w+\s+).+$/\1manual/g" /etc/network/interfaces
	  fi
	  
	done
	
  	
        #list eth interfaces (sometimes kernel may not set fisrt if to eth0)
	interfaces=$(/sbin/ifconfig -s  2>>$LOGFILE  | cut -d " " -f1 | grep -oEe "eth[0-9]+")
	
	if [ "$interfaces" == "" ] ; then
	    echo $"Error: no se encuentran interfaces ethernet accesibles."  >>$LOGFILE 2>>$LOGFILE 
	    return 11
	fi
	
	
        #Por cada interface eth disponible, la configuramos y probamos la conectividad. (puede haber varias y no todas enchufadas)
	settledaninterface=0
	for i in $interfaces; do
	    interface=$i
	    

	    echo "/sbin/ifconfig $interface $IPADDR netmask $MASK" >>$LOGFILE 2>>$LOGFILE
            #Set IP and netmask.
	    /sbin/ifconfig "$interface" "$IPADDR" netmask "$MASK"  >>$LOGFILE 2>>$LOGFILE 

	    echo "/sbin/route add default gw $GATEWAY">>$LOGFILE 2>>$LOGFILE
            #Set default gateway
	    /sbin/route add default gw "$GATEWAY"  >>$LOGFILE 2>>$LOGFILE 
	    
            #Set NameServers
	    echo -e "nameserver $DNS1\nnameserver $DNS2" > /etc/resolv.conf
	    
	    #$dlg --infobox $"Comprobando conectividad..." 0 0
	    echo $"Comprobando conectividad..."  >>$LOGFILE 2>>$LOGFILE
	    ping -w 5 -q $GATEWAY  >>$LOGFILE 2>>$LOGFILE 
	    [ $? -eq 0 ] && echo "found conectivity on interface $interface" >>$LOGFILE 2>>$LOGFILE  && settledaninterface=1 && break

	    #si no tiene conectividad, la deshabilitamos (si no, hay colisiones)
	    /sbin/ifconfig "$interface" down  >>$LOGFILE 2>>$LOGFILE 
	    /sbin/ifconfig "$interface" 0.0.0.0  >>$LOGFILE 2>>$LOGFILE 
	
	done
	
	
	if [ "$settledaninterface" -eq 0 ] ; then
	    echo $"Error: no se pudo comunicar con la puerta de enlace. Revise conectividad."  >>$LOGFILE 2>>$LOGFILE 
	    return 12
	fi

	
    else #Modo dhcp
	
	
	IPADDR=$(dhclient 2>&1 | grep -e "bound to" | grep -oEe "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
	
	if [ "$IPADDR" == "" ]  ; then
	    echo $"Error: no se pudo obtener la configuraci�n IP. Revise conectividad."  >>$LOGFILE 2>>$LOGFILE 
	    return 13
	fi

	aux=$(host $IPADDR  2>>$LOGFILE)
	aux2=$(echo "$aux" | grep -oe "not found")

	if [ "$aux2" != "" ] 
	    then
	    echo "----->No se pudo asociar esta IP a un FQDN. Posible red privada (NAT)"  >>$LOGFILE 2>>$LOGFILE
	    
	    #En este caso, lo pedimos expl�citamente, si estamos en la instalaci�n
	    if [ "$DOFORMAT" -eq 1  ]
		then
		#En vez de mostrar error, pedir� el FQDN y lo guardar� como var.
		return 42
	    fi
	    
	else
	    FQDN=$( echo "$aux" | grep -oEe " [^ ]+$" | sed -re "s/^ (.*)\.$/\1/g")

	    #Se guarda esta variable en el fichero que se escribir� en el clauer (o en reset se usar� y punto)
	    setPrivVar FQDN "$FQDN" c   #////probar
	fi
    fi
    
    
 
    

    return 0
}


echo "panic: $2 (param obsoleto)" >>$LOGFILE 2>>$LOGFILE
echo "ipmode: $IPMODE" >>$LOGFILE 2>>$LOGFILE
echo "ipad: $IPADDR" >>$LOGFILE 2>>$LOGFILE
echo "mask: $MASK" >>$LOGFILE 2>>$LOGFILE
echo "gatw: $GATEWAY" >>$LOGFILE 2>>$LOGFILE
echo "dns : $DNS1" >>$LOGFILE 2>>$LOGFILE
echo "dns2: $DNS2" >>$LOGFILE 2>>$LOGFILE
echo "fqdn: $FQDN" >>$LOGFILE 2>>$LOGFILE
echo "doformat: $DOFORMAT" >>$LOGFILE 2>>$LOGFILE


  configureNetwork $2

  exit "$?"

fi


#Segunda parte de la config de la red. necesita tener el valor de FQDN y la IP.

if [ "$1" == "configureNetwork2" ] 
    then

	getPrivVar c FQDN
	getPrivVar c IPADDR

   if [ "$FQDN" != ""  ]
	then
       
       if [ "$IPADDR" == ""  ]
	   then
           #Al estar en modo dhcp, no tenemos una ip definida. Resolvemos el FQDN
	   IPADDR=$(host "$FQDN" | grep -e "has address" | sed -re "s/^.*address\s+([0-9.]+).*$/\1/g")
       fi

       if [ "$IPADDR" == ""  ]
	   then
	   IPADDR="127.0.0.1"
       fi
       
        #Set Hostname
       hname=$(echo "$FQDN" | grep -oEe "^[^.]+")
       echo "FQDN: $FQDN"  >>$LOGFILE 2>>$LOGFILE
       echo "HOSTNAME: $hname"  >>$LOGFILE 2>>$LOGFILE
       [ "$hname" != "" ] && hostname "$hname"
       
       
       if [ "$IPADDR" != "" ]
	   then
           #Set FQDN
	   if [ "$IPADDR" != "127.0.0.1"  ]  
	       then
	       isfqdnset=$(cat /etc/hosts | grep "$IPADDR") #////probar que ahora me resuelva ambos, localhost y lol.
	   fi
	   if [ "$isfqdnset" == "" ]
	       then
               #Si no aparece nuestra IP en hosts, la a�adimos
	       echo "$IPADDR $FQDN $hname" >  /tmp/hosts.tmp
	       cat /etc/hosts              >> /tmp/hosts.tmp
	       mv /tmp/hosts.tmp /etc/hosts
	   else
     	       #Sino, lo alteramos
	       sed -i -re "s/^$IPADDR.*$/$IPADDR $FQDN $hname/g" /etc/hosts
	   fi
	fi
	
    fi


   exit 0
fi










#//// verif en mant: no


if [ "$1" == "fdiskList" ] 
    then

    checkParameterOrDie DEV "${2}"
    
    $fdisk -l "$DEV" 2>>$LOGFILE
  
    exit 0  
fi





#//// verif en mant: si?


if [ "$1" == "checkforWritableFS"  ]
    then


    checkParameterOrDie DEV "${2}" "0"
    part="$2"

    mkdir -p /media/testpart   >>$LOGFILE 2>>$LOGFILE   

    
    mount "$part" /media/testpart >>$LOGFILE 2>>$LOGFILE
    ret=$?
    if [ "$ret" -ne "0" ]
	then
	echo "1"
	exit 1 #Si no se puede montar, la ignoramos
    fi
    
    echo "a" > /media/testpart/testwritability 2>/dev/null
    ret=$?
    if [ "$ret" -ne "0" ] 
	then
	echo "1"
	exit 1 #Si no se puede escribir, la ignoramos
    fi
    rm -f /media/testpart/testwritability
    umount /media/testpart >>$LOGFILE 2>>$LOGFILE


    rmdir /media/testpart >>$LOGFILE 2>>$LOGFILE 
    
    echo "0"
    exit 0
fi




#//// verif en mant: si?


if [ "$1" == "guessFS"  ]
    then

    checkParameterOrDie DEV "${2}" "0"
    part="$2"
    
    mkdir -p /media/testpart   >>$LOGFILE 2>>$LOGFILE   
    
    mount $part /media/testpart >>$LOGFILE 2>>$LOGFILE

    #Obtenemos el FS de la particion
    thisfs=$(cat /etc/mtab  | grep "$part" | cut -d " " -f3 | uniq) 
	  
    ###   el uniq es por si la part est� montada 2 veces, para
    ###   que no saque 2 veces el tag del Fs y joda la lista de
    ###   datos y con ello la ventana de dialog.
	  
    umount /media/testpart   >>$LOGFILE 2>>$LOGFILE

    rmdir /media/testpart >>$LOGFILE 2>>$LOGFILE 

    echo "$thisfs"
    
    exit 0

fi












#//// verif en mant: si



if [ "$1" == "configureCryptoPartition" ] 
    then

#params: new/reset $mountpath $FILEFILESIZE 
#Retorno: loopbackdev: el /dev/loopX en que queda montado el fs
manageLoopbackFS () {

    realfilepath=$2/$CRYPTFILENAME  
    
    #Si estamos construyendo el sistema, llenamos el fs de ceros.
    if [ "$1" == 'new' ]
	then
	#$dlg --infobox $"Preparando espacio de almacenamiento..." 0 0
	echo $"Preparando espacio de almacenamiento..."  >>$LOGFILE 2>>$LOGFILE
	FILEBLOCKS=$(($3 * 1024 * 1024 / 512))
	dd if=/dev/zero of=$realfilepath bs=512 count=$FILEBLOCKS  >>$LOGFILE 2>>$LOGFILE
    fi
    
    #Elegimos un dispositivo de loopback libre para montar el fichero
    #losetup /dev/loop$X, muestra info del loop y sale con 0 si puede mostrarla (est� ocupado) o con 1 si falla (est� libre)
    LOOPDEV=''
    for l in 0 1 2 3 4 5 6 7
      do
      losetup /dev/loop$l  >>$LOGFILE 2>>$LOGFILE
      [ $? -ne 0 ] && LOOPDEV=loop$l && break 
    done
    [ "$LOOPDEV" == '' ]  &&  systemPanic $"Error grave: no se puede acceder a ning�n dispositivo loopback"
    
    
    #Montamos el fichero
    losetup /dev/${LOOPDEV}  $realfilepath  >>$LOGFILE 2>>$LOGFILE
    
    loopbackdev=/dev/${LOOPDEV}
}




######### Configurar acceso a datos cifrados ##########
#1 -> 'new' or 'reset'
#2 -> mountpath -> punto de montaje de las particiones donde est� el loopback file
#3 -> mapperName -> nombre del disp mapeado sobrwe elq ue montar el cryptsetup
#4 -> exposedpath -> El path definitivo de los datos. Por lo general debe ser $DATAPATH
configureCryptoPartition () {


    #Uso normal:
    #mountpath="/media/localpart"
    #mapperName="eSurveyEncryptedMap"
    #exposedpath="$DATAPATH"
    
    mountpath="$2"
    mapperName="$3"
    exposedpath="$4"
    
    [ "$mountpath" == "" ] &&  echo "No param 2"  >>$LOGFILE 2>>$LOGFILE  && return 1
    [ "$mapperName" == "" ] &&  echo "No param 3"  >>$LOGFILE 2>>$LOGFILE  && return 1
    [ "$exposedpath" == "" ] &&  echo "No param 4"  >>$LOGFILE 2>>$LOGFILE  && return 1
    
    cryptdev=""
    
    mkdir -p $mountpath

    case "$DRIVEMODE" in 
	
	
	"local" ) 
        cryptdev="$DRIVELOCALPATH"
        ;;
	
	
	"iscsi" )
	/etc/init.d/open-iscsi stop >>$LOGFILE 2>>$LOGFILE 
	/etc/init.d/open-iscsi start >>$LOGFILE 2>>$LOGFILE 
        [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el cliente de iSCSI."
	
	#Listar /dev/sd* antes de montar
	devsBefore=$(ls /dev/sd? 2>>$LOGFILE)
	
	echo -e "DevsBefore:\n$devsBefore" >>$LOGFILE
	
	#Workaround: Por alguna raz�n (pinta como algo de cach�s), antes de conectar necesita que se haga un discover
	targets=$(iscsiadm -m discovery  -t st -p "$ISCSISERVER:$ISCSIPORT" 2>>$LOGFILE)

	iscsiadm -m node -T "$ISCSITARGET" -p "$ISCSISERVER:$ISCSIPORT" -l  >>$LOGFILE 2>>$LOGFILE 
        [ $? -ne 0 ] &&  systemPanic $"Error: imposible acceder al target iSCSI."
	
	#Este sleep es pq parece que no le da tiempo a crear los nuevos devs 
	sleep 5

	#Listar /dev/sd* despues de montar
	devsAfter=$(ls /dev/sd? 2>>$LOGFILE)

	echo -e "devsAfter:\n$devsAfter" >>$LOGFILE
	
	#la diferencia, son las Logical Units proporcionadas por el target iscsi
	luns=""
	for lun in $devsAfter
	  do
	  aux=$(echo $devsBefore | grep $lun)
	  [ "$aux" == "" ] && luns=$luns" $lun"
	done
	
	echo -e "LUNs:\n$luns" >>$LOGFILE

	[ "$luns" == "" ] &&  systemPanic $"Error: el target iSCSI no devolvi� ninguna unidad l�gica."
	
	### Usar la primera primera unidad (machacando cualquier tabla
	### de particiones) y ya (nada de pajas mentales, el que monte
	### el target, que lo haga simple)

        cryptdev=$(echo $luns | cut -d " " -f1)
        ;;
	
	
	"nfs" )  

        # mount 127.0.0.1:/home/paco/.bin/nfsexp /mnt/nfsexported/ -w   -o "nolock"
	# mount lab9054.inv.uji.es:/home/paco/.bin/nfsexp /mnt/nfsexported/ -w   -o "nolock"

	#/etc/init.d/nfs-common start  #Esto es del servidor nfs, no del cliente
        #[ $? -ne 0 ] &&  systemPanic $"Error grave: No se pudo activar el cliente de NFS."
	
	
	#Lo de que no da acceso de escritura cuando se es root: http://bugs.debian.org/492970
	#El admin deber� poner no_root_squash para poder acceder, bajo su propio riesgo
	#/etc/exports:
	#
	#/exported/nfs/dir 150.128.49.192/26(rw,sync,no_subtree_check,no_root_squash)
	
	
	#Por alguna raz�n no puedo lanzar el "/sbin/rpc.statd" (probablemente por el firewall, ya que lanza un daemon que escucha el puerto 40084), por lo que debo indicar que mantenga los locks en local (nolock). Esto no es un problema porque el directorio del voto debe ser de uso EXCLUSIVO, y mejor exponer el m�nimo de servidores.
	mount $NFSSERVER:$NFSPATH $mountpath -w -o "port=$NFSPORT"  -o "nolock"   >>$LOGFILE 2>>$LOGFILE 
	ret=$?
	[ "$ret" -ne 0 ] &&  systemPanic $"Error accediendo al directorio compartido." 

	#Hacer touch de un fichero en el dir montado a ver si es rw y se ha montado bien
	touch $mountpath/testwritability
	ret=$?
	rm $mountpath/testwritability
	[ "$ret" -ne 0 ] &&  systemPanic $"Error: el directorio montado no tiene acceso de escritura."
	
	#Crear fichero de fs
	manageLoopbackFS $1 $mountpath $NFSFILESIZE
	cryptdev=$loopbackdev
	;;


	"samba" ) 

	#mount.cifs //lab9054.inv.uji.es/test /mnt/smb/  -o "user=test,password=*****,rw"
	
        #El path: si empieza por [/]+, truncarla, porque no acepta  //
	SMBPATH=$(echo $SMBPATH | sed -re "s|^[/]+||")
	

	#Siempre devuelve 0, aunque el recurso no exista
        mount.cifs //$SMBSERVER/$SMBPATH $mountpath -o "user=$SMBUSER,password=$SMBPWD,port=$SMBPORT,rw"
	ret=$?
	[ "$ret" -ne 0 ] &&  systemPanic $"Error accediendo al recurso compartido." 

	
	#Hacer touch de un fichero en el dir montado a ver si es rw y se ha montado bien
	touch $mountpath/testwritability
	ret=$?
	rm $mountpath/testwritability
	[ "$ret" -ne 0 ] &&  systemPanic $"Error: el recurso compartido es de s�lo lectura."
	
	#Crear fichero de fs
	manageLoopbackFS $1 $mountpath $SMBFILESIZE
	cryptdev=$loopbackdev
	;;




	"file" ) 
	
        #Monta la partici�n en que se halla/va a escribir el fichero de loopback
        mount $FILEPATH $mountpath
	ret=$?
	[ "$ret" -ne "0" ] &&  systemPanic $"No se ha podido montar la partici�n."
	
	manageLoopbackFS $1 $mountpath $FILEFILESIZE
	


	cryptdev=$loopbackdev

        ;;


	
	* ) 
	choice=''
	systemPanic $"No se ha reconocido el modo de acceso a los datos cifrados. Configuraci�n probablemente manipulada."
        ;;

    esac

    ## Una vez tenemos la 'particion' disponible como un dev, construimos o montamos el fs cifrado

    #Si estamos construyendo el sistema, setup del fs cifrado dentro del fich loopback.
    if [ "$1" == 'new' ]
	then
	#$dlg --infobox $"Cifrando zona de almacenamiento..." 0 0
	echo $"Cifrando zona de almacenamiento..."  >>$LOGFILE 2>>$LOGFILE
	#al poner el - delante del EOF, se ignorar�n los TAB al inicio de cada l�nea del fichero (ojo: TAB, no SPC)
	#Los delimitadores del here file no es al subcadena 'EOF', sino TODA la cadena (si tiene espacios o tabs detr�s, los cuenta)
	cryptsetup luksFormat $cryptdev   >>$LOGFILE 2>>$LOGFILE  <<-EOF
		$PARTPWD
		EOF
        [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo cifrar la zona de almacenamiento." 
    fi
    
    #Mapeamos el cryptoFS
    cryptsetup luksOpen $cryptdev $mapperName   >>$LOGFILE 2>>$LOGFILE <<-EOF
		$PARTPWD
		EOF
    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo acceder a la zona de almacenamiento." 

    #Si estamos construyendo el sistema, setup del fs cifrado dentro del fich loopback.
    if [ "$1" == 'new' ]
	then
	#$dlg --infobox $"Creando sistema de ficheros..." 0 0
	echo $"Creando sistema de ficheros..." >>$LOGFILE 2>>$LOGFILE
	
	mkfs.ext2 /dev/mapper/$mapperName   >>$LOGFILE 2>>$LOGFILE
	[ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo dar formato al sistema de ficheros."
    fi
    
    #Montamos el cryptoFS mapeado sobre una ruta del sistema.
    mkdir -p $exposedpath 2>>$LOGFILE
    mount  /dev/mapper/$mapperName $exposedpath
    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo montar el sistema de ficheros."


    #Si todo ha ido bien, dejamos una copia de esta clave en un fichero en RAM, para los backups (y para autorizar el uso de ops priv)
    echo -n "$PARTPWD" > $ROOTTMP/dataBackupPassword
    chmod 400  $ROOTTMP/dataBackupPassword   >>$LOGFILE 2>>$LOGFILE
   
    #Retorno:
    CRYPTDEV=$cryptdev

    return 0
} # end configureCryptoPartition ()



if [ "$2" != 'new' -a "$2" != 'reset' ]
    then 
    echo "configureCryptoPartition: param ERR (exiting 1): 2=$2"   >>$LOGFILE 2>>$LOGFILE
    exit 1
fi

parseInput path "$3"
ret3=$?

parseInput path "$4"
ret4=$?

parseInput path "$5"
ret5=$?

if [ "$ret3" -ne 0 -o "$ret4" -ne 0 -o "$ret5" -ne 0 ]
    then
    echo -e "param ERR (exiting 1): 3=$3\n4=$4\n5=$5"   >>$LOGFILE 2>>$LOGFILE
    exit 1
fi


# //// borrar
#checkParameterOrDie DRIVEMODE "${6}"
#checkParameterOrDie DRIVELOCALPATH "${7}"
#checkParameterOrDie NFSSERVER "${8}"
#checkParameterOrDie NFSPORT "${9}"
#checkParameterOrDie NFSPATH "${10}"
#checkParameterOrDie NFSFILESIZE "${11}"
#checkParameterOrDie SMBSERVER "${12}"
#checkParameterOrDie SMBPORT "${13}"
#checkParameterOrDie SMBPATH "${14}"
#checkParameterOrDie SMBUSER "${15}"
#checkParameterOrDie SMBPWD "${16}"
#checkParameterOrDie SMBFILESIZE "${17}"
#checkParameterOrDie ISCSISERVER "${18}"
#checkParameterOrDie ISCSIPORT "${19}"
#checkParameterOrDie ISCSITARGET "${20}"
#checkParameterOrDie FILEPATH "${21}"
#checkParameterOrDie FILEFILESIZE "${22}"
#checkParameterOrDie PARTPWD "${23}"
#checkParameterOrDie CRYPTFILENAME "${24}"




getPrivVar c DRIVEMODE


getPrivVar c DRIVELOCALPATH

getPrivVar c NFSSERVER  
getPrivVar c NFSPORT    
getPrivVar c NFSPATH    
getPrivVar c NFSFILESIZE

getPrivVar c SMBSERVER  
getPrivVar c SMBPORT    
getPrivVar c SMBPATH    
getPrivVar c SMBUSER    
getPrivVar c SMBPWD     
getPrivVar c SMBFILESIZE

getPrivVar c ISCSISERVER
getPrivVar c ISCSIPORT  
getPrivVar c ISCSITARGET

getPrivVar c FILEPATH    
getPrivVar c FILEFILESIZE


getPrivVar c CRYPTFILENAME



getPrivVar r CURRENTSLOT
keyfile="$ROOTTMP/slot$CURRENTSLOT/key"
if [ -s  "$keyfile" ] 
    then
    :
else
    echo "Error: No existe una clave reconstruida en el slot activo!! ($CURRENTSLOT)"  >>$LOGFILE 2>>$LOGFILE
    exit 1
fi

PARTPWD=$(cat "$keyfile")  #/////probar

configureCryptoPartition "$2" "$3" "$4" "$5" 
[ "$?" -ne 0 ] && exit 1



##Config de seguridad de la part cifrada


chmod 751  $DATAPATH  >>$LOGFILE 2>>$LOGFILE


# //// Aqu�, si new,  configurar las carpetas del cryptoFS (crearlas, propietarios, permisos, etc.)
if [ "$2" == 'new' ]
    then

    

    mkdir -p $DATAPATH/root >>$LOGFILE 2>>$LOGFILE
    chown root:root $DATAPATH/root >>$LOGFILE 2>>$LOGFILE
    chmod 710  $DATAPATH/root  >>$LOGFILE 2>>$LOGFILE

    
    mkdir -p $DATAPATH/webserver >>$LOGFILE 2>>$LOGFILE
    chown root:www-data $DATAPATH/webserver >>$LOGFILE 2>>$LOGFILE
    chmod 755  $DATAPATH/webserver  >>$LOGFILE 2>>$LOGFILE



    mkdir -p $DATAPATH/rrds >>$LOGFILE 2>>$LOGFILE
    chown root:root $DATAPATH/rrds >>$LOGFILE 2>>$LOGFILE
    chmod 755  $DATAPATH/rrds  >>$LOGFILE 2>>$LOGFILE


    mkdir -p $DATAPATH/wizard >>$LOGFILE 2>>$LOGFILE
    chown vtuji:vtuji $DATAPATH/wizard >>$LOGFILE 2>>$LOGFILE
    chmod 750  $DATAPATH/wizard  >>$LOGFILE 2>>$LOGFILE

fi




#Retorno:
doReturn $CRYPTDEV
exit 0
fi #configurecryptopartition











#//// verif en mant: si


if [ "$1" == "formatearClauer"  -o "$1" == "formatearUSB" ] 
    then

#1-> el dev
createPartitionTable () {

    dev="$1"
    echo "Dev a formatear: $dev" >>$LOGFILE 2>>$LOGFILE
    

    if [ "$dev" == "" ]
	then
	echo $"No existe el dispositivo" >>$LOGFILE 2>>$LOGFILE
	return 11
    fi


    #Nos cargamos la tabla de particiones
    dd if=/dev/zero of=$dev count=10 1>/dev/null 2>/dev/null

    #El algoritmo que calcula la geometr�a perfecta es err�neo. Fijando los cilindros al m�ximo (1024), 
    #itera por todas las combinaciones posibles de n�mero de cabezal (1-255) y sector (1-63) y busca 
    #que coincida con el num de bytes real del dev. El problema es que no va almacenando el mejor 
    #resultado parcial y, si no coincide, no saca el �ptimo.
    
    #Bloques del dev (el kernel lo devuelve en bloques de 1024 bytes)
    bloques=$[$($fdisk -s $dev 2>>$LOGFILE)]
    if [ $bloques -eq 0 ]
	then
	echo $"Error durante el particionado: Dispositivo inv�lido." >>$LOGFILE 2>>$LOGFILE
	return 12
    fi

    total=$((bloques *1024 )) #tam del disp en bytes 
    #echo "Tam real en bytes del dev: $total"
    tamB=$[$(LC_ALL=C $fdisk -l $dev 2>>$LOGFILE | grep ", [0-9]* bytes" | sed "s/.*, \([0-9]*\) bytes/\1/g" 2>>$LOGFILE)] #tama�o real en bytes del disco. Como es una flash y la geometr�a CHS es inventada, puede darse el caso de que C*H*S*Blocksize sea distinto a este. El algoritmo intenta optimizar esto.
    #echo "tamB: $tamB"

    if [ $tamB -eq 0 ]
	then
	echo "Error durante el particionado: Dispositivo inv�lido (2)." >>$LOGFILE 2>>$LOGFILE
	return 12
    fi


    tam=$(($tamB/1000/1000))
    #echo "tam: $tam"


    #tam de sector del dev (te�ricamente autodetectado por el kernel)
    BytesPorSector=$[$(LC_ALL=C $fdisk -l $dev 2>>$LOGFILE | grep "\* [0-9]* = [0-9]* bytes" | sed "s/.*\* \([0-9]*\) = [0-9]* bytes/\1/")]
    #echo "BytesPorSector: $BytesPorSector"

   if [ $BytesPorSector -eq 0 ]
	then
	echo "Error durante el particionado: Dispositivo inv�lido (3)." >>$LOGFILE 2>>$LOGFILE
	return 12
    fi


    sectors=1
    headers=1
    cylinders=1024
    found=0
    tt=0
    to=0
    
    while (( $found==0  && $sectors<=64 )); do
	headers=1
        #echo "$BytesPorSector*$headers*$sectors*$cylinders";
	while (($found==0 && $headers<=256)); do 
	    tt=$(($BytesPorSector*$headers*$sectors*$cylinders));
	    if (( $tt>$to && $tt<=$tamB )); then 
		to=$tt;
		ho=$headers;
		so=$sectors;
		if (( $tt == $tamB )); then
		    found=1
		fi
	    fi
	    headers=$((headers + 1));
	done
	sectors=$((sectors + 1));
    done
    
    H=$ho
    S=$so
    #echo "C: $cylinders"
    #echo "H: $H"
    #echo "S: $S"
    
    BytesPorCilindro=$((H*S*$BytesPorSector))
    #echo "BytesPorCilindro: $BytesPorCilindro"
    CilindroFinalDatos=$(( $(($total - $cryptosize*1000*1024))/ $BytesPorCilindro ))
    #echo "CilindroFinalDatos: $CilindroFinalDatos"
    
    
    sync
    
    
    cmd="n\np\n1\n\n""$CilindroFinalDatos""\nn\np\n4\n\n\nt\n1\nc\nt\n4\n69\nw\n";
    echo -ne "$cmd" | $fdisk $dev -C $cylinders -H $H -S $S 1>/dev/null 2>>$LOGFILE
    
    sync 
    umount  ${dev}1 2>/dev/null
    
    sleep 1
 

    x=$(mkfs.vfat -S ${BytesPorSector} ${dev}1 2>&1 )

    if [ $? -ne 0 ]
	then
	echo $"Error durante el particionado" >>$LOGFILE 2>>$LOGFILE
	return 13
    fi
    
    sync
    sleep 1
    
    
    return
}


#1 -> dev
#2 -> pwd
createCryptoPart () {

    sync
    sleep 1
    
    x=$(clmakefs -d "$1"4  -p "$2" 2>&1 ) 

    if [ $? -ne 0 ] 
	then
	echo $"Error durante el formateo"  >>$LOGFILE 2>>$LOGFILE
	return 14
    fi
    
    #echo "Salida de clmakefs: $x" 
    
    sync
    
    #echo "Part datos: $total - $cryptosize*1000*1024"
    totaldatos=$(( $total - $cryptosize*1000*1024 ))
    #echo "Part datos: $totaldatos"

    return
}


checkParameterOrDie DEV "${2}" "0"


if [ "$1" == "formatearUSB" ]
    then
    
    checkParameterOrDie DEVPWD "${3}" "0"
    
fi


createPartitionTable "$2"
ret=$?

if [ "$1" == "formatearUSB" ]
    then
    exit $ret;
fi


if [ "$ret" -eq 0 ]
    then
    
    #$dlg   --infobox $"Formateando Clauer..." 0 0
    echo $"Formateando Clauer..."  >>$LOGFILE 2>>$LOGFILE
    createCryptoPart "$2" "$3"
    ret=$?
else
	echo "Error durante el formateo (2)"  >>$LOGFILE 2>>$LOGFILE
	exit 14
fi

exit $ret;

fi






#//// verif en mant: si


if [ "$1" == "configureServers" ] 
    then





    
   if [ "$2" == "mailServer" ] 
    then


       #////borrar
       #checkParameterOrDie FQDN "${3}"
       #checkParameterOrDie MAILRELAY "${4}"


       getPrivVar c FQDN
       
       getPrivVar d MAILRELAY
       
       #Establecemos la configuraci�n del servidor de correo
       if [ "$FQDN" == "" ] 
	   then
	   sed -i -re "s|^myhostname.*$||g" /etc/postfix/main.cf
	   sed -i -re "s|\#\#\#HOSTNAME\#\#\#,||g" /etc/postfix/main.cf
       else
	   sed -i -re "s|\#\#\#HOSTNAME\#\#\#|$FQDN|g" /etc/postfix/main.cf
       fi
       
       #Relay: nuvol.uji.es
       if [ "$MAILRELAY" == "" ] 
	   then
	   sed -i -re "s|^relayhost.*$||g" /etc/postfix/main.cf
       else
	   sed -i -re "s|\#\#\#RELAYHOST\#\#\#|$MAILRELAY|g" /etc/postfix/main.cf
       fi
       

       #Lanzamos el servidor de correo
       /etc/init.d/postfix stop >>$LOGFILE 2>>$LOGFILE 
       /etc/init.d/postfix start >>$LOGFILE 2>>$LOGFILE 
       exit "$?"
       
   fi


   if [ "$2" == "mailServerM" ] 
    then
              
       getPrivVar d MAILRELAY
       
       if [ "$MAILRELAY" == "" ] 
	   then
	   sed -i -re "/^relayhost.*$/d" /etc/postfix/main.cf 
       else
	   definedrelay=$(cat /etc/postfix/main.cf | grep -oEe "^relayhost")
	   #Si no hab�a, append de la l�nea al final
	   if [ "$definedrelay" == "" ]; then
	       echo -e "\n\nrelayhost = $MAILRELAY\n" >>  /etc/postfix/main.cf  2>>$LOGFILE
	   else
	       #Si hab�a, sustitu�mos el valor
	       sed -i -re "s|^relayhost.*$|relayhost = $MAILRELAY|g" /etc/postfix/main.cf
	   fi
       fi
    

       #Lanzamos el servidor de correo
       /etc/init.d/postfix stop >>$LOGFILE 2>>$LOGFILE 
       /etc/init.d/postfix start >>$LOGFILE 2>>$LOGFILE 
       exit "$?"
       
   fi


    
   if [ "$2" == "dbServer-init" ] 
    then
       

       

       if [ "$3" != 'new' -a "$3" != 'reset' ]
	   then 
	   echo "dbServer-init: param ERR (exiting 1): 3=$3"   >>$LOGFILE 2>>$LOGFILE
	   exit 1
       fi



    #No se carga al inicio, pero por si acaso.
    /etc/init.d/mysql stop  >>$LOGFILE 2>>$LOGFILE
    
    
    if [ "$3" == 'new' ]
	then
	#Movemos la carpeta de datos de la aplic. y no s�lo la de la BD.
	rm -rf $DATAPATH/mysql 2>/dev/null >/dev/null
	cp -rp /var/lib/mysql $DATAPATH/
	res=$?
	
	[ "$res" -ne 0 ] &&  systemPanic $"Error copiando la base de datos al directorio cifrado. Destino inaccesible o espacio insuficiente." 
	
	chown -R mysql:mysql $DATAPATH/mysql/
	
    fi



    #Cambiar el datadir del mysql a la ruta dentro de la partici�n cifrada
    sed -i -re "/datadir/ s|/var/lib/mysql.*|$DATAPATH/mysql|g" /etc/mysql/my.cnf
    
    #Cambiar el directorio de acceso privilegiado para mysql en apparmor (ubuntu lo usa en vez del SELinux)
    sed -i -re "s|/var/lib/mysql/|$DATAPATH/mysql/|g" /etc/apparmor.d/usr.sbin.mysqld
    
    #Reload del apparmor 
    /etc/init.d/apparmor restart >>$LOGFILE 2>>$LOGFILE
    
    #Cargar mysql 
    /etc/init.d/mysql start >>$LOGFILE 2>>$LOGFILE
    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de base de datos." f
    



    if [ "$3" == 'new' ]
	then

       #Generar la contrase�a del usuario de la BD y guardarla entre las vars a escribir en el clauer.
       randomPassword 15
       DBPWD=$pw
       $PVOPS vars setVar d DBPWD "$DBPWD"
       
       
       #Cambiar pwd del root por uno aleatorio y largo (solo al crearlo, que luego es persistente)
       randomPassword 20
       MYSQLROOTPWD=$pw
       mysqladmin -u root -p'a' password "$MYSQLROOTPWD" 2>>/tmp/mysqlerr
       [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de base de datos." f

       [ "$MYSQLROOTPWD" == ""  ] &&  systemPanic $"Error grave: no se pudo activar el servidor de base de datos." f
       [ "$DBPWD" == ""  ] &&  systemPanic $"Error grave: no se pudo activar el servidor de base de datos." f
       
       
       #He quitado el permiso LOCK TABLES, que ya no hace falta, y a�adido el ALTER (para las updates del sw sin renstalar). 
       #A�ado el flush privileges, para que recargue las passwords y los PRIVS
       mysql -u root -p"$MYSQLROOTPWD" mysql 2>>/tmp/mysqlerr  <<-EOF
		CREATE DATABASE eLection;
		CREATE USER 'election'@'localhost' IDENTIFIED BY '$DBPWD';
		GRANT SELECT, INSERT, UPDATE, DELETE, ALTER, CREATE TEMPORARY TABLES, DROP, CREATE ON eLection.* TO election@localhost;
		FLUSH PRIVILEGES;
		EOF

	[ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de base de datos." f


        #Escribimos el password de root en un fichero en la part cifrada, para posibles labores de mantenimiento

       echo -n "$MYSQLROOTPWD" > $DATAPATH/root/DatabaseRootPassword
       
       chmod 600 $DATAPATH/root/DatabaseRootPassword >>$LOGFILE 2>>$LOGFILE
       

    fi

    exit 0

    
   fi

   
   
   if [ "$2" == "alterPhpScripts" ] #//// donde use esto, quitar los params y pasar todo a priv 
       then
       

       getPrivVar d DBPWD
       getPrivVar d KEYSIZE
       getPrivVar d SITESORGSERV
       getPrivVar d SITESNAMEPURP

       #getPrivVar d EXCLUDEDNODE #Actualmente no se guarda
       

   
    #Alteramos los ficheros de la aplicaci�n php con la contrase�a para acceder a la bd. (y dem�s variables)
    sed -i  -e "s|###\*\*\*myHost\*\*\*###||g" /var/www/*.php   #El valor antes era localhost, pero as� se conecta al mysql por tcp/ip que es m�s lento. Si se deja vacia, se conecta por socket del sistema.
    sed -i  -e "s|###\*\*\*myUser\*\*\*###|election|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*myPass\*\*\*###|$DBPWD|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*myDb\*\*\*###|eLection|g" /var/www/*.php

    #Nodos excluidos por ser administrados por este admin (vacio)
    #sed -i  -e "s|###\*\*\*exclnd\*\*\*###|$EXCLUDEDNODE|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*exclnd\*\*\*###||g" /var/www/*.php
    
    #Longitud de la llave
    sed -i  -e "s|###\*\*\*klng\*\*\*###|$KEYSIZE|g" /var/www/*.php

    #Par�metros para STORK
    sed -i  -e "s|###\*\*\*organizacion\*\*\*###|$SITESORGSERV|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*proposito\*\*\*###|$SITESNAMEPURP|g" /var/www/*.php

    ### La var secr s�lo sirve para evitar que un usuario desde otra
    ### aplic. php en este servidor pueda autenticarse falsamente en
    ### esta ya que la variable SESSION es compartida. As� que aqu� no
    ### sirve para nada, ya que no hay m�s apps. Le damos un valor
    ### random
    randomPassword
    sed -i  -e "s|###\*\*\*secr\*\*\*###|$pw|g" /var/www/*.php
    pw=''
    

    ### Al dejar vac�a la cadena de versi�n, se impide la
    ### actualizaci�n del programa, cumpliendo as� con el requisito de
    ### seguridad de que nadie pueda alterar la funcionalidad del
    ### sistema
    sed -i  -e "s|###\*\*\*ver\*\*\*###||g" /var/www/*.php
    
    #//// Si tuviese incoherencias con los permisos del dir web (y ficheros y subdir), aqu� deber�a poner los definitivos
    

    exit 0
       
   fi







  if [ "$2" == "configureWebserver" ] 
       then
      
      
      #Param com�n a las 3 operacuiones de conf del webserver. Es el modo del servidor: con ssl o sin.
      getPrivVar d WWWMODE
       
      
      if [ "$3" == "wsmode" ] 
	  then
	  	  
	  
	  if [ "$WWWMODE" == "ssl" ] ; then
	      #Para el vhost del pto 80: config que redirige las peticiones del 80 al 443
	      cp -f /etc/apache2/sites-available/000-default.sslredirect /etc/apache2/sites-enabled/000-default >>$LOGFILE 2>>$LOGFILE

	      #Modificamos el firewall de nuevo
	      setupFirewall "ssl" >>$LOGFILE 2>>$LOGFILE
	  fi
	  if [ "$WWWMODE" == "plain" ] ; then
	      #Para el vhost del pto 80:acepta las peticiones en el 80
	      cp -f /etc/apache2/sites-available/000-default.noredirect /etc/apache2/sites-enabled/000-default >>$LOGFILE 2>>$LOGFILE
	      
	      #Cerramos el acceso al servidor web a trav�s de ssl
	      setupFirewall "plain" >>$LOGFILE 2>>$LOGFILE
	  fi
	  
	  exit 0
      fi


      


      if [ "$3" == "dummyCert" ] 
	  then

	  
          #Si no hay cert (dummy o bueno), generar un dummy a partir de la csr (ya hay una llave seguro)
	  genDummy=0
	  [ -f $DATAPATH/webserver/server.crt ] || genDummy=1
	  if [ "$genDummy" -eq 1 ]
	      then 
	      
	      openssl x509 -req -days 3650 -in $DATAPATH/webserver/server.csr -signkey $DATAPATH/webserver/server.key -out $DATAPATH/webserver/server.crt   >>$LOGFILE 2>>$LOGFILE

              #Poner como chain el propio certificado
	      cp $DATAPATH/webserver/server.crt $DATAPATH/webserver/ca_chain.pem  >>$LOGFILE 2>>$LOGFILE

              #Poner em modo prueba el fichero de estado del cert (si no estamos en plain)
	      [ "$WWWMODE" != "plain" ] && echo -n "DUMMY" > $DATAPATH/root/sslcertstate.txt
	
	  fi
	  
	  exit 0
      fi




      if [ "$3" == "finalConf" ] 
	  then
	  
	    mkdir -p /etc/apache2/ssl/
    
	    rm     /etc/apache2/ssl/server.key  >>$LOGFILE 2>>$LOGFILE
	    rm     /etc/apache2/ssl/server.crt  >>$LOGFILE 2>>$LOGFILE
	    ln -s  $DATAPATH/webserver/server.key    /etc/apache2/ssl/server.key >>$LOGFILE 2>>$LOGFILE
	    ln -s  $DATAPATH/webserver/server.crt    /etc/apache2/ssl/server.crt >>$LOGFILE 2>>$LOGFILE
	    ln -s  $DATAPATH/webserver/ca_chain.pem  /etc/apache2/ssl/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
	    
	    
            #enlazar el csr en el directorio web. (borrar cualquier enlace anterior)
	    rm -f /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	    cp -f $DATAPATH/webserver/server.csr /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	    chmod 444 /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	    
            #Enable los m�dulos que se necesiten (PHP, MySQL...)
	    a2enmod php5 >>$LOGFILE 2>>$LOGFILE
	    a2enmod ssl  >>$LOGFILE 2>>$LOGFILE

	    #Si estamos en modo ssl, activamos el rewriteengine para que las peticiones plain vayan al ssl
	    [ "$WWWMODE" != "plain" ] && a2enmod rewrite >>$LOGFILE 2>>$LOGFILE

    
            #Lanzar apache
	    /etc/init.d/apache2 stop  >>$LOGFILE  2>>$LOGFILE
	    /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE
	    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor web." f

	    exit 0
      fi


#//// sin verif condicionada a verifcert
      # 4-> certChain o serverCert
      if [ "$3" == "checkCertificate" ] 
	  then

	  if [ "$4" != "serverCert" -a "$4" != "certChain" ]
	      then
	      echo "checkCertificate: bad param 4: $4" >>$LOGFILE 2>>$LOGFILE
	      exit 1
	  fi

	  #El nombre con que se guardar� si se acepta 
	  destfilename="ca_chain.pem"

	  keyfile=''
	  #Si estamos verificando el cert de serv, necesitamos la privkey
	  if [ "$4" == "serverCert" ]
	      then

	      #El nombre con que se guardar� si se acepta 
	      destfilename="server.crt"

	      crtstate=$(cat $DATAPATH/root/sslcertstate.txt 2>>$LOGFILE)
	      
	      if [ "$crtstate" == "RENEW" ]
		  then
		  #Buscamos la llave en el subdirectorio (porque la del principal est� en uso y e sv�lida)
		  keyfile="$DATAPATH/webserver/newcsr/server.key"
	      else #DUMMY y  OK
		  #La buscamos en el dir principal
		  keyfile="$DATAPATH/webserver/server.key"
	      fi
 
	  fi 
	  
	  checkCertificate  $ROOTFILETMP/usbrreadfile "$4" $keyfile
	  ret="$?"

	  if [ "$ret" -ne 0 ] 
	      then
	      rm -rf $ROOTFILETMP/*  >>$LOGFILE  2>>$LOGFILE #Vaciamos el temp de lectura de ficheros
	      exit "$ret" 	  
	  fi



	  #Si no existe el temp espec�fico de ssl, crearlo
	  if [ -e $ROOTSSLTMP ]
	      then
	      :
	  else
	      mkdir -p  $ROOTSSLTMP >>$LOGFILE 2>>$LOGFILE
	      chmod 750 $ROOTSSLTMP >>$LOGFILE 2>>$LOGFILE
	  fi
	  
	  #Movemos el fichero al temporal espec�fico (al destino se copiar� cuando est�n verificados la chain y el cert)	  
	  mv -f $ROOTFILETMP/usbrreadfile $ROOTSSLTMP/$destfilename  >>$LOGFILE  2>>$LOGFILE
	  
	  
	  rm -rf $ROOTFILETMP/* >>$LOGFILE  2>>$LOGFILE #Vaciamos el temp de lectura de ficheros
	  exit 0
      fi
      
#*-*-

#//// sin verif condicionada a verifcert?


      if [ "$3" == "installSSLCert" ] 
	  then
	  
	  #Verificamos el certificado frente a la cadena.
	  verifyCert $ROOTSSLTMP/server.crt $ROOTSSLTMP/ca_chain.pem
	  if [ "$?" -ne 0 ] 
	      then
 	      #No ha verificado. Avisamos y salimos (borramos el cert y la chain en temp)
	      echo "Cert not properly verified against chain"  >>$LOGFILE  2>>$LOGFILE
	      rm -rf $ROOTSSLTMP/*  >>$LOGFILE  2>>$LOGFILE
	      exit 1
	  fi
	  
	  #Seg�n si estamos instalando el primer cert o uno renovado, elegimos el dir.
	  crtstate=$(cat $DATAPATH/root/sslcertstate.txt 2>>$LOGFILE)
	  if [ "$crtstate" == "RENEW" ]
	      then
	      basepath="$DATAPATH/webserver/newcsr/"
	  else #DUMMY y  OK
	      basepath="$DATAPATH/webserver/"
	  fi


          #Si todo ha ido bien, copiamos la chain a su ubicaci�n 
	  mv -f $ROOTSSLTMP/ca_chain.pem  $basepath/ca_chain.pem >>$LOGFILE  2>>$LOGFILE
    
          #Si todo ha ido bien, copiamos el cert a su ubicaci�n
	  mv -f $ROOTSSLTMP/server.crt  $basepath/server.crt >>$LOGFILE  2>>$LOGFILE
	      

	  /etc/init.d/apache2 stop  >>$LOGFILE  2>>$LOGFILE


	  #Si es renew, sustituye el cert activo por el nuevo.
	  if [ "$crtstate" == "RENEW" ]
	      then
	      mv -f  "$DATAPATH/newcsr/server.csr"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	      mv -f  "$DATAPATH/newcsr/server.crt"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	      mv -f  "$DATAPATH/newcsr/server.key"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	      mv -f  "$DATAPATH/newcsr/ca_chain.pem" "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	      rm -rf "$DATAPATH/newcsr/"                           >>$LOGFILE  2>>$LOGFILE
	  fi

	  
          #Cambiar estado de SSL
	  echo -n "OK" > $DATAPATH/root/sslcertstate.txt


	  #enlazar el csr en el directorio web. (borrar cualquier enlace anterior)
	  rm /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	  cp -f $DATAPATH/server.csr /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	  chmod 444 /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	  
	  
	  /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE
	  if [ "$ret" -ne 0 ]; then
	      echo "Error restarting web server!"  >>$LOGFILE 2>>$LOGFILE
	      exit 2
	  fi
	  
	  exit 0
      fi
      
      

      
      exit 1 #Por si acaso. Ninguna op debe llegar aqu�
  fi



  if [ "$2" == "generateDummyCSR" ] 
       then
      
	    #Generamos la petici�n de certificado de pruebas de forma no interactiva
	    OUTFILE="$DATAPATH/webserver/server.csr"
	    openssl req -new  -sha1 -newkey rsa:2048 -nodes\
		-keyout $DATAPATH/webserver/server.key -out $OUTFILE \
		-subj "/CN=dummy"   >>$LOGFILE 2>>$LOGFILE
	    ret=$?
	    
	    if [ "$ret" -ne 0 ] 
		then
		echo "Error $ret generando dummy cert"    >>$LOGFILE 2>>$LOGFILE
		exit "$ret"
	    fi
	    
	    #El modo de cert ssl es 'NOCERT'
	    echo -n "NOCERT" > $DATAPATH/root/sslcertstate.txt	  2>>$LOGFILE   
	    
	    exit 0
  fi




  if [ "$2" == "generateCSR" ] 
       then


      #$3 -> modo: 'new' o 'renew'
      ruta="$DATAPATH/webserver"
      if [ "$3" == "renew" ] 
	  then
	  ruta="$DATAPATH/webserver/newcsr"  

	  mkdir -p $ruta            >>$LOGFILE 2>>$LOGFILE
	  chown root:www-data $ruta >>$LOGFILE 2>>$LOGFILE
	  chmod 755  $ruta          >>$LOGFILE 2>>$LOGFILE
      fi

#//// probar

      
      checkParameterOrDie SERVERCN     "${4}"
      checkParameterOrDie COUNTRY     "${7}"
      checkParameterOrDie SERVEREMAIL "${10}"

      aux=$(echo "${5}" | grep -Ee "[='\"/$]")	  
      if [ "$aux" != "" -o "${5}" == "" ] #Campo obligatorio
	  then
	  echo "PVOPS generateCSR: bad parameter COMPANY: $5" >>$LOGFILE 2>>$LOGFILE
	  exit 1
      fi
      COMPANY="${5}"
      
      aux=$(echo "${6}" | grep -Ee "[='\"/$]")	  
      if [ "$aux" != "" ]
	  then
	  echo "PVOPS generateCSR: bad parameter DEPARTMENT: $6" >>$LOGFILE 2>>$LOGFILE
	  exit 1
      fi
      DEPARTMENT="${6}"
      
      aux=$(echo "${8}" | grep -Ee "[='\"/$]")	  
      if [ "$aux" != "" ]
	  then
	  echo "PVOPS generateCSR: bad parameter STATE: $8" >>$LOGFILE 2>>$LOGFILE
	  exit 1
      fi
      STATE="${8}"

      
      aux=$(echo "${9}" | grep -Ee "[='\"/$]")	  
      if [ "$aux" != "" ]
	  then
	  echo "PVOPS generateCSR: bad parameter LOC: $9" >>$LOGFILE 2>>$LOGFILE
	  exit 1
      fi
      LOC="${9}"

      #Construimos el subject
      #"/emailAddress=lol@uji.es/C=ES/ST=estado/L=pueblo/O=organization/OU=department/CN=lol.uji.es"

      #Los obligatorios
      SUBJECT="/O=$COMPANY/C=$COUNTRY/CN=$SERVERCN"

      if [ "$DEPARTMENT" != "" ]
	  then
	  SUBJECT="/OU=$DEPARTMENT$SUBJECT"
      fi
      
      if [ "$STATE" != "" ]
	  then
	  SUBJECT="/ST=$STATE$SUBJECT"
      fi

      if [ "$LOC" != "" ]
	  then
	  SUBJECT="/L=$LOC$SUBJECT"
      fi
      
      #Este campo va el primero, para que no haya confusi�n al interpretar. por compatibilidad.
      if [ "$SERVEREMAIL" != "" ]
	  then
	  SUBJECT="/emailAddress=$SERVEREMAIL$SUBJECT"
      fi
      
      echo "subject: $SUBJECT" >>$LOGFILE 2>>$LOGFILE
      
      echo "*******############******gCSR ruta: $ruta" >>$LOGFILE 2>>$LOGFILE
      
      #AUTOSIGNED="-x509 -days 1095 " #para pruebas con autofirmado: a�adir $AUTOSIGNED tras -new
      OUTFILE="$ruta/server.csr"   #Para pruebas con autofirmado: $ruta/server.crt EN VEZ DE $ruta/server.csr
      openssl req -new  -sha1 -newkey rsa:2048 -nodes -keyout "${ruta}/server.key" -out $OUTFILE -subj "$SUBJECT" >>$LOGFILE 2>>$LOGFILE
      ret=$?
      
      echo "openssl req -new  -sha1 -newkey rsa:2048 -nodes -keyout $1/server.key -out $OUTFILE -subj '$SUBJECT'" >>$LOGFILE 2>>$LOGFILE
      
      if [ "$ret" -ne 0 ]
	  then
	  echo  "Error $ret en la ejec de openssl req."  >>$LOGFILE 2>>$LOGFILE
	  exit $ret
      fi
      
      #echo "*******############******gCSR: openssl req -new  -sha1 -newkey rsa:2048 -nodes\
#	  -keyout '${ruta}/server.key' -out $OUTFILE -subj '/CN=$SERVERCN'" >>$LOGFILE 2>>$LOGFILE
#      echo "*******############******gCSR ret: $ret" >>$LOGFILE 2>>$LOGFILE


  
      chown root:www-data $OUTFILE    >>$LOGFILE 2>>$LOGFILE
      chmod 444  $OUTFILE             >>$LOGFILE 2>>$LOGFILE
      
      chown root:root $ruta/server.key    >>$LOGFILE 2>>$LOGFILE
      chmod 400 $ruta/server.key              >>$LOGFILE 2>>$LOGFILE 


      #enlazar el csr en el directorio web. (borrar cualquier enlace anterior)
      rm /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
      cp -f $DATAPATH/webserver/server.csr /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
      chmod 444 /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE	  

      #uno de los procesos pesados del apache corre como root. Asumo que es un coordinador y parece ser que carga la llave SSL como root, por lo que puedo protegerla bien con los permisos.
      

      #En modo renew, hay que cambiar el estado aqu�, que no genero dummyCert. 
      if [ "$3" == "renew" ] 
	  then
	  echo -n "RENEW" > $DATAPATH/root/sslcertstate.txt	  
      fi

      $PVOPS vars setVar d WWWMODE "ssl"



      #No hace falta ponerlo aqu� porque si no es renew, se llama a la op dummyCert
#      if [ "$3" == "new" ] 
#	  then
#	  echo -n "DUMMY" > $DATAPATH/root/sslcertstate.txt	  
#      fi
      
      exit 0
  fi






  exit 1
fi #End configureServers op










if [ "$1" == "fetchCSR" ] 
    then


#*-*- seguir revisando y sacando de aqu� los $dlg


# $1 --> el fichero que contiene la CSR
fetchCSR () {


	pk10copied=0
	mkdir -p /media/testusb  >>$LOGFILE 2>>$LOGFILE
	while [ "$pk10copied" -eq 0 ]
	  do
	  umount /media/testusb  >>$LOGFILE 2>>$LOGFILE # Lo desmontamos por si se ha quedado montado

	  insertClauerDev $"Inserte un dispositivo USB para almacenar la petici�n de certificado y pulse INTRO.\n(Puede ser uno de los Clauer que acaban de emplear)" "none"

	  #intentar montar la part 1 del DEV. 
	  part="$DEV""1"
	  #echo "DEv: $DEV"
	  mount  $part /media/testusb  >>$LOGFILE 2>>$LOGFILE
	  ret=$?
	  if [ "$ret" -ne "0" ]
	      then
	      $dlg --yes-label $"Otro" --no-label $"Formatear"  --yesno $"Este dispositivo no es v�lido. �Desea insertar otro o prefiere formatear este?" 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      $dlg --yes-label $"Otro" --no-label $"Formatear" --yesno $"�Seguro que desea formatear? Todos los datos SE PERDER�N." 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      umount /media/testusb  >>$LOGFILE 2>>$LOGFILE  # Lo desmontamos antes de formatearlo
	      $dlg --infobox $"Formateando dispositivo..." 0 0 
	      ret=$($PVOPS formatearUSB "$DEV")
	      [ "$ret" -ne 0 ] && continue
	      mount  $part /media/testusb  >>$LOGFILE 2>>$LOGFILE
	  fi
	  echo "a" > /media/testusb/testwritability 2>/dev/null
	  ret=$?
	  if [ "$ret" -ne "0" ]
	      then
	      $dlg --yes-label $"Otro" --no-label $"Formatear"  --yesno $"Este dispositivo es de s�lo lectura. �Desea insertar otro o prefiere formatear este?" 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      $dlg --yes-label $"Otro" --no-label $"Formatear" --yesno $"�Seguro que desea formatear? Todos los datos SE PERDER�N." 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      umount /media/testusb  >>$LOGFILE 2>>$LOGFILE  # Lo desmontamos antes de formatearlo
	      $dlg --infobox $"Formateando dispositivo..." 0 0 
	      ret=$($PVOPS formatearUSB "$DEV")
	      [ "$ret" -ne 0 ] && continue
	      mount  $part /media/testusb  >>$LOGFILE 2>>$LOGFILE
	  else
	      rm -f /media/testusb/testwritability
	  fi
	  
	  #Es correcta. Escribimos el pk10
	  $dlg --infobox $"Escribiendo petici�n de certificado..." 0 0 
	  tries=10
	  while  [ $pk10copied -eq 0 ]
	    do
	    cp -f "$1" /media/testusb/server.csr  >>$LOGFILE 2>>$LOGFILE
	    
	    #A�adimos, junto a la CSR, un Readme indicando las instrucciones
	    cp -f /usr/share/doc/eLectionLiveCD-README.txt.$LANGUAGE  /media/testusb/VTUJI-README.txt
	    
	    if [ -s  "/media/testusb/server.csr" ] 
		then
		:
	    else 
		tries=$(($tries-1))
		[ "$tries" -eq 0  ] &&  break
		continue
	    fi
	    
	    pk10copied=1
	    
	  done
	  
	  if [ $pk10copied -eq 0 ]
	      then
	      $dlg --msgbox $"Error de escritura. Inserte otro dispositivo" 0 0
	      continue
	  fi
	  
	  umount /media/testusb  >>$LOGFILE 2>>$LOGFILE
	  
	  detectClauerextraction $DEV $"Petici�n de certificado escrita con �xito.\nRetire el dispositivo y pulse INTRO."

	done
	rmdir /media/testusb  >>$LOGFILE 2>>$LOGFILE




}



      #$2 -> modo: 'new' o 'renew'
      ruta="$DATAPATH/webserver"
      if [ "$2" == "renew" ] 
	  then
	  ruta="$DATAPATH/webserver/newcsr"	
      fi
      

      fetchCSR "$ruta/server.csr"

      exit 0
fi





#++++

if [ "$1" == "clops" ] 
    then

    echo "llamando a clops $2 ..."  >>$LOGFILE 2>>$LOGFILE

    if [ "$2" == "" ]
	then
	echo "ERROR clops: No op code defined"  >>$LOGFILE 2>>$LOGFILE
	exit 1
    fi
	    

    
    
    #inicializa los datos persistentes de la gesti�n de piezas
    if [ "$2" == "init" ] 
	then

	#Empieza en 1
	for i in $(seq $SHAREMAXSLOTS)
	  do
	  	  
	  mkdir -p "$ROOTTMP/slot$i"  >>$LOGFILE 2>>$LOGFILE
	  chmod 600 "$ROOTTMP/slot$i"  >>$LOGFILE 2>>$LOGFILE
	  echo -n "0" > "$ROOTTMP/slot$i/NEXTSHARENUM"
  	  echo -n "0" > "$ROOTTMP/slot$i/NEXTCONFIGNUM"

	done
	
	CURRENTSLOT=1
	setPrivVar CURRENTSLOT "$CURRENTSLOT" r   #////probar
	
	exit 0
    fi






    #Variables globales a estas operaciones
    
    getPrivVar r CURRENTSLOT
    slotPath=$ROOTTMP/slot$CURRENTSLOT/




    #Resetea el slot activo. 
    if [ "$2" == "resetSlot" ] 
	then
	
	
	rm -rf "$slotPath/*"  >>$LOGFILE 2>>$LOGFILE
	echo -n "0" > "$slotPath/NEXTSHARENUM"
	echo -n "0" > "$slotPath/NEXTCONFIGNUM"

	exit 0
    fi


    #Resetea el slot activo. 
    if [ "$2" == "resetAllSlots" ] 
	then
	
		
	for i in $(seq $SHAREMAXSLOTS)
	  do
	  rm -rf $ROOTTMP/slot$i/*  >>$LOGFILE 2>>$LOGFILE #No me preguntes por qu� (el *?), pero si la ruta va entre comillas no hace el RM y no saca error.
	  echo -n "0" > "$ROOTTMP/slot$i/NEXTSHARENUM"
	  echo -n "0" > "$ROOTTMP/slot$i/NEXTCONFIGNUM"
	done
	
	exit 0
    fi


    #Verifica la llave obtenida en el slot activo #*-*-
    if [ "$2" == "checkClearance" ] 
	then
	
	checkClearance $CURRENTSLOT
	ret="$?"
	
	exit $ret
    fi


    
    #Cambia el slot activo a $3.
    if [ "$2" == "switchSlot" ] 
	then
	
	checkParameterOrDie INT "${3}" "0"
	
	if [ "$3" -gt $SHAREMAXSLOTS -o  "$3" -le 0 ]
	    then
	    echo "Bad slot number: $3"  >>$LOGFILE 2>>$LOGFILE
	    exit 1
	fi

	setPrivVar CURRENTSLOT "$3" r   #////probar
	
	exit 0
    fi




    #Reconstruye las llaves con las piezas que hay en el slot activo en un intento simple 
    if [ "$2" == "rebuildKey" ] 
	then
		
	numreadshares=$(ls $slotPath | grep -Ee "^keyshare[0-9]+$" | wc -w)
    
        #Reconstruir llave de cifrado y mapearla a su variable. 
	$OPSEXE retrieve $numreadshares $slotPath  2>>$LOGFILE > $slotPath/key
	exit $? 
	
    fi


    #Reconstruye las llaves con las piezas que hay en el slot activo en un intento simple 
    if [ "$2" == "rebuildKeyAllCombs" ] 
	then
		


#1->THRESHOLD
#2->numreadshares
#3->directorio origen de las shares
#Retorno 0 -> ok 1 -> Error
retrieveKeywithAllCombs () {  
    
	echo "Retrievekeyswithallcombs:"  >>$LOGFILE 2>>$LOGFILE
	echo "Threshold:     $1"  >>$LOGFILE 2>>$LOGFILE
	echo "numreadshares: $2"  >>$LOGFILE 2>>$LOGFILE
	
	
	[ "$1" == "" ] && exit 10
    
	[ "$1" -gt "$2" ] && exit 11
	
	mkdir -p $3/testcombdir  >>$LOGFILE 2>>$LOGFILE
	
	
	#Verificamos todas las combinaciones:
	combs=$(/usr/local/bin/combs.py $1 $2)

	echo "Number of combinations: "$(echo $combs | wc -w)  >>$LOGFILE 2>>$LOGFILE

	gotit=0
	for comb in $combs
	  do
	  poslist=$(echo "$comb" | sed "s/-/ /g")
	  offset=0
	  for pos in $poslist
	    do
	    #copiamos keyshare$pos a $3/testcombdir", con el nombre cambiado para que sean secuenciales, por el retrieve
	    echo "copying keyshare$pos to $3/testcombdir named keyshare$offset"  >>$LOGFILE 2>>$LOGFILE
	    cp -f $3/keyshare$pos $3/testcombdir/keyshare$offset

	    offset=$((offset+1))

	  done
	  
          #Reconstruir llave de cifrado y mapearla a su variable. 
	  $OPSEXE retrieve $1 $3/testcombdir  2>>$LOGFILE > $3/key
	  stat=$? 
	  
	  #limpiamos el directorio
	  rm -f $3/testcombdir/*  >>$LOGFILE 2>>$LOGFILE
	  
          #Si logra reconstruir, sale.
	  [ $stat -eq 0 ] && gotit=1 && break 
	  
	done
	
	rm -rf  $3/testcombdir  >>$LOGFILE 2>>$LOGFILE
	
        #Si no se logra con ninguna combinaci�n, error.
        [ $gotit -ne 1 ] && return 1

	return 0	
	
}


        #////probar

        getPrivVar c THRESHOLD	
	numreadshares=$(ls $slotPath | grep -Ee "^keyshare[0-9]+$" | wc -w)
    
	retrieveKeywithAllCombs "$THRESHOLD" "$numreadshares" "$slotPath/"
	exit $? 
	
    fi



    
    if [ "$2" == "testForDeadShares" ] 
	then
    

#1 -> el dir de donde leer las shares a probar.
testForDeadShares () {
    
    sourcesharedir=$1
    
    echo "Available shares: "$(ls -l  $sourcesharedir 2>>$LOGFILE )   >>$LOGFILE 2>>$LOGFILE
    
    sharefiles=$(ls "$sourcesharedir/" | grep -Ee "^keyshare[0-9]+$")
    numsharefiles=$(echo $sharefiles 2>>$LOGFILE | wc -w)

    [ "$sharefiles" == ""  ] && echo "NO SHARES TO TEST!!" >>$LOGFILE 2>>$LOGFILE && return 1
    
    mkdir -p $ROOTTMP/testdir >>$LOGFILE 2>>$LOGFILE

    
    ###  Reconstruimos la clave con N conjuntos de THRESHOLD shares
    ###  tales que cubran todo el conjunto de shares. Si hay un solo
    ###  error, se solicita regenerarla. Cada llave reconstruida se 
    ###  compara con la anterior, para verificar que coinciden.
    
    LASTKEY=""
    CURRKEY=""

    count=0
    deadshares=0
    while [ "$count" -lt "$numsharefiles"  ]
      do
      
      [ "$THRESHOLD" == "" ] && exit 2
      
      [ "$THRESHOLD" -gt "$numsharefiles" ] && exit 3
      
      #Limpiamos el directorio
      rm -f $ROOTTMP/testdir/* >>$LOGFILE 2>>$LOGFILE
      
      
      #Calcular qu� n�meros de pieza usar en esta reconstrucci�n y copiarlos al directorio de prueba
      offset=0
      while [ "$offset" -lt "$THRESHOLD" ]
	do
	
	pos=$(( (count+offset)%numsharefiles ))

        #copiamos keyshare$pos a $ROOTTMP/testdir" renombr�ndola para que sean correlativas empezando desde cero (lo necesita el retrieve)
	echo "copying keyshare$pos to $ROOTTMP/testdir named $ROOTTMP/testdir/keyshare$offset"  >>$LOGFILE 2>>$LOGFILE
	cp $sourcesharedir/keyshare$pos $ROOTTMP/testdir/keyshare$offset   >>$LOGFILE 2>>$LOGFILE
	
	offset=$((offset+1))
      done
      
      echo "Shares copied to test directory: "$(ls -l  $ROOTTMP/testdir)   >>$LOGFILE 2>>$LOGFILE
      
      #Reconstruir llave de cifrado y mapearla a su variable. 
      CURRKEY=$($OPSEXE retrieve $THRESHOLD $ROOTTMP/testdir  2>>$LOGFILE)
      stat=$? 
      
      #limpiamos el directorio
      rm -f $ROOTTMP/testdir/* >>$LOGFILE 2>>$LOGFILE
      
      #Si no logra reconstruir, sale.
      [ $stat -ne 0 ] && deadshares=1 && break 
      
      echo "Could rebuild key"  >>$LOGFILE 2>>$LOGFILE
      
      #Si no coincide con la reconstrucci�n anterior, sale      

      [ "$LASTKEY" != "" -a "$LASTKEY" != "$CURRKEY"   ] && deadshares=1 && break
      LASTKEY="$CURRKEY"
      
      echo "Matches previous"  >>$LOGFILE 2>>$LOGFILE
            
      count=$(( count + THRESHOLD ))
      
    done
    

    rm -rf $ROOTTMP/testdir >>$LOGFILE 2>>$LOGFILE

    echo "deadshares? $deadshares" >>$LOGFILE 2>>$LOGFILE

    return $deadshares
}

    getPrivVar c THRESHOLD

    testForDeadShares "$slotPath"
    [ "$?" -ne 0 ] && exit 1

    exit 0
fi













    #//// Esta op no estar� disponible en standby (la config solo se lee en new y reset). Ver qu� ops no debo permitir ejecutar y marcarlas..


    
    #Compara la �ltima config leida con la que actualmente se acepta como la oficial.
    if [ "$2" == "compareConfigs" ] 
	then
	
	
	NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	lastConfigRead=$((NEXTCONFIGNUM-1))

	echo "***** #### NEXTCONFIGNUM:  $NEXTCONFIGNUM" >>$LOGFILE 2>>$LOGFILE
	echo "***** #### lastConfigRead: $lastConfigRead" >>$LOGFILE 2>>$LOGFILE
	
	if [ "$lastConfigRead" -lt 0 ]
	    then
	    echo "No config files read yet" >>$LOGFILE 2>>$LOGFILE
	    exit 1;
	fi


	#Por defecto asumimos que la nueva va a ser la de referencia
        keepCurrent=0


	#Si hay al menos 2 las compara  #////PROBAR!!
	if [ "$lastConfigRead" -gt 0 ]
	    then
	    
	    if [ -s "$slotPath/configRaw" ]
		then
		:
	    else
		#Establecemos la primera conf le�da como la de referencia
		cat $slotPath/config0 2>>$LOGFILE > $slotPath/configRaw
		parseConfigFile "$slotPath/config0" 2>>$LOGFILE > $slotPath/config
	    fi


	    df=$( diff $slotPath/config$lastConfigRead  $slotPath/configRaw )
	    
	    echo "***** diff config files $lastConfigRead - config: $df" >>$LOGFILE 2>>$LOGFILE #////BORRAR
	    if [ "$df" != "" ]
		then
		echo -ne $"Configuraci�n actual:\n"         >> $slotPath/buff
		echo -ne $"-------------------- \n\n"       >> $slotPath/buff
		cat $slotPath/configRaw                        >> $slotPath/buff
		echo -ne $"\n\n\nConfiguraci�n nueva:\n"    >> $slotPath/buff
		echo -ne $"------------------------- \n\n"  >> $slotPath/buff
		cat  $slotPath/config$lastConfigRead        >> $slotPath/buff
		
		$dlg --msgbox $"Se han encontrado diferencias entre la �ltima configuraci�n leida y la que se est� empleando actualmente.\nVamos a mostrar ambas para su comparaci�n." 0 0
		
		$dlg --textbox $slotPath/buff 0 0
		
		$dlg --yes-label $"Actual"  --no-label $"Nueva"  --yesno  $"�Desea emplear la actual o la nueva?" 0 0   # 0 YES 1 NO
		
		[ "$?" -eq  0 ] && keepCurrent=1
		
		echo "Keep current config?: $keepCurrent" >>$LOGFILE 2>>$LOGFILE

		rm $slotPath/buff >>$LOGFILE 2>>$LOGFILE
	    fi
	    
	fi

	if [ "$keepCurrent" -eq 0 ]
	    then
	    
	    #Esta es la que usamos para comparar con las nuevas.
	    cat $slotPath/config$lastConfigRead 2>>$LOGFILE > $slotPath/configRaw
	    
            #Pasamos la config ya purgada al fichero definitivo, para interpretarla l�nea a l�nea, y permitir los espacios en los valores
	    parseConfigFile "$slotPath/config$lastConfigRead" 2>>$LOGFILE > $slotPath/config #////probar
	fi

	
	exit 0
    fi




    #Verifica la estructura de la �ltima config le�da
    if [ "$2" == "parseConfig" ] 
	then
	NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	lastConfigRead=$((NEXTCONFIGNUM-1))

	echo "***** #### NEXTCONFIGNUM:  $NEXTCONFIGNUM" >>$LOGFILE 2>>$LOGFILE
	echo "***** #### lastConfigRead: $lastConfigRead" >>$LOGFILE 2>>$LOGFILE

	if [ "$NEXTCONFIGNUM" -eq 0 ]
	    then
	    echo "parseConfig: no configuration file read yet!"  >>$LOGFILE 2>>$LOGFILE
	    exit 1
	fi


        # Al filtrar el fichero de configuraci�n, s�lo cogemos el primer
        # elemento de cada l�nea ej: a="aa" "bb" b=123 456 --> a="aa"
        # b=123 para evitar inyecci�n de comandos. Adem�s, no se aceptan
        # $ dentro de una cadena, para evitar el acceso a variables de
        # entorno	
	ESVYCFG=$(parseConfigFile "$slotPath/config$lastConfigRead" 2>>$LOGFILE)
	
	if [ "$ESVYCFG" == "" ]
	    then
	    echo "parseConfig: esurveyconfiguration was manipulated!"  >>$LOGFILE 2>>$LOGFILE
	    exit 1
	fi
	
	exit 0
    fi
    

    #Establece la config elegida del slot activo como la config a usar en adelante.
    if [ "$2" == "settleConfig" ] 
	then
	parseConfigFile "$slotPath/config" > $ROOTTMP/config  #////probar que no fastidie los \n

	if [ -s "$ROOTTMP/config" ]
	    then
	    :
	else
	    echo "settleConfig: esurveyconfiguration was manipulated!"  >>$LOGFILE 2>>$LOGFILE
	    exit 1
	fi

	exit 0
    fi
    
    
    #Comprobaci�n de params comunes a estas ops

    #3-> dev
    checkParameterOrDie DEV "${3}" "0"

    #4-> password
    checkParameterOrDie DEVPWD "${4}" "0"







    if [ "$2" == "checkPwd" ] 
	then

        $OPSEXE checkPwd -d "$3"  -p "$4"    2>>$LOGFILE #0 ok  1 bad pwd  #////PROBAR
	ret=$?
	
	exit "$ret"
    fi




    if [ "$2" == "readConfigShare" ] 
	then
	
	NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")   #////probar
	
	$OPSEXE readConfig -d "$3"  -p "$4" >$slotPath/config$NEXTCONFIGNUM  2>>$LOGFILE	
	ret=$?

        #Si se ha le�do bien la config	
	if [  -s $slotPath/config$NEXTCONFIGNUM   ] 
	    then
	    #aumentamos el num
	    NEXTCONFIGNUM=$(($NEXTCONFIGNUM+1))
	    echo -n "$NEXTCONFIGNUM" > "$slotPath/NEXTCONFIGNUM"

	    


	else
	    ret=42
	fi

	exit $ret
    fi



    if [ "$2" == "readKeyShare" ] 
	then

	NEXTSHARENUM=$(cat "$slotPath/NEXTSHARENUM")   #////probar

	$OPSEXE readKeyShare -d "$3"  -p "$4" >$slotPath/keyshare$NEXTSHARENUM  2>>$LOGFILE
	ret=$?

        #Si se ha le�do bien la keyshare, aumentamos el num
	if [  -s $slotPath/keyshare$NEXTSHARENUM  ] 
	    then
	    NEXTSHARENUM=$(($NEXTSHARENUM+1))
	    echo -n "$NEXTSHARENUM" > "$slotPath/NEXTSHARENUM"
	else
	    ret=42
	fi

	exit $ret
    fi
    


    
    # 5 -> El n�mero de share que debe escribir:
    if [ "$2" == "writeKeyShare" ] 
	then
	
	getPrivVar c SHARES
	
	# $5 debe ser un int
	checkParameterOrDie INT "${5}" "0"


	# $5 debe estar entre 0 y SHARES-1
	if [ "$5" -lt 0 -o "$5" -ge "$SHARES" ]
	    then
	    echo "writeKeyShare: bad share num $5 (not between 0 and $SHARES)"  >>$LOGFILE 2>>$LOGFILE
	    exit 1
	fi

	shareFileToWrite="$slotPath/keyshare$5"

	# Si el fichero de esa share existe y tiene tama�o
	if [ -s "$shareFileToWrite" ]
	    then
	    :
	else
	    echo "writeKeyShare: nonexisting or empty share $5 (of $SHARES)"  >>$LOGFILE 2>>$LOGFILE
	    exit 1
	fi
    	
	
        #echo "***** Written Share$1 ($(ls -l $shareFileToWrite | cut -d \" \" -f 5))*****"
        #hexdump shareFileToWrite
        #echo "******************************"
	$OPSEXE writeKeyShare -d "$3"  -p "$4" <"$shareFileToWrite" 2>>$LOGFILE  #0 succesully set  1 write error
	ret=$?

	exit $ret
    fi
    
    
    if [ "$2" == "writeConfig" ] 
	then

	file="$ROOTTMP/config"	
		
	if [ -s "$file" ]
	    then
	    :
	else
	    echo "writeConfig: No config to write!"  >>$LOGFILE 2>>$LOGFILE
	    exit 1
	fi

	ESVYCFG=$(cat "$file" 2>>$LOGFILE)
	
	echo -e "CHECK1: esvycfg:  --" >>$LOGFILE 2>>$LOGFILE
	cat "$file" >>$LOGFILE 2>>$LOGFILE #*-*- verificar que lo que imprimia era por esto. quitar este cat en prod. 
	echo "--" >>$LOGFILE 2>>$LOGFILE

	#Escribimos las vars de config que deben guardarse en el clauer (en el fichero del slot activo)
	cat "$file" | $OPSEXE writeConfig -d "$3"  -p "$4" 2>>$LOGFILE
	ret=$?

	exit $ret
    fi
    



  #//// SEGUIR++++        

    # *-*-
    #Comprueba si la clave reconstruida en el slot activo es la correcta.
    if [ "$2" == "validateKey" ] 
	then
	:
    fi


    





#readConfig(Share) --> devuelve el estado, pero el contenido lo vuelca  en un directorio inaccesible

#readKeyShare --> devuelve el estado, pero el contenido lo vuelca  en un directorio inaccesible

#getConfig  -> Devuelve la cadena de configuraci�n si todas las piezas le�das son coherentes. (las variables cr�ticas no las devuelve? ver d�nde las uso y si lo puedo encapsular todo en la parte d eservidor usando ficheros)


#//// Hacer interfaz de clops, de gesti�n de llaves y de gesti�n de variables.

#//// Cron para el tema de las claves que permanecen: Borrarlas autom�ticamente no es buena idea, porque a priori no conocemos la duraci�n de las sesiones de mantenimiento. Poner un cron que revise los slots de shares y avise al admin con un e-mail si llevan ah� m�s de 1 hora. Avisarle cada X horas hasta que se borren. Poner una entrada en el men� de standby que las borre.

#//// El programa de standby se matar� y arrancar� cada vez, empezando en el punto del men� (establecer las variables que necesite.


# //// Construir fichero de persistencia de variables en el tmp del root, para guardar valores entre invocaciones a privOps. El fichero de variables que se guarda en la part cifrada, ponerlo en el dir de root y gestionarlo desde priv ops (no devolver las variables cr�ticas.).


fi





if [ "$1" == "genNfragKey" ] 
    then

    genNfragKey () {
	
        #Generamos una contrase�a segura que ser� la clave de cifrado del disco. # fuente entropia: randomsound
	randomPassword
	PARTPWD=$pw
	pw=""
	
	#Limpiamos el slot (por si no han llamado a resetSlot)
	rm -rf $slotPath/*  >>$LOGFILE 2>>$LOGFILE
	
        #Fragmentamos la contrase�a
	echo -n "$PARTPWD" >$slotPath/key
	$OPSEXE share $SHARES $THRESHOLD  $slotPath <$slotPath/key >>$LOGFILE 2>>$LOGFILE 
	local ret=$?
	echo "$OPSEXE share $SHARES $THRESHOLD  $slotPath <$slotPath/key" >>$LOGFILE 2>>$LOGFILE
	
	return $ret
    }
    
    getPrivVar c SHARES
    getPrivVar c THRESHOLD
    
    getPrivVar r CURRENTSLOT   #////probar
    slotPath=$ROOTTMP/slot$CURRENTSLOT/


    genNfragKey
    
    exit $?
fi



#////Con verificaci�n de llave

if [ "$1" == "grantAdminPrivileges" ] 
    then
    
    getPrivVar d DBPWD

    echo "giving privileges."  >>$LOGFILE 2>>$LOGFILE
    mysql -f -u election -p"$DBPWD" eLection 2>>/tmp/mysqlerr  <<EOF
update eVotDat set mante=1;
EOF
    #//// Por qu� mante 1? en todo caso, hablar con manolo lo de las im�genes sin restricci�n (mante 2) 
    exit 0
fi



#////SIN verificaci�n de llave


if [ "$1" == "retireAdminPrivileges" ] 
    then
    
    getPrivVar d DBPWD
    
    echo "retiring privileges."  >>$LOGFILE 2>>$LOGFILE
    mysql -f -u election -p"$DBPWD" eLection 2>>/tmp/mysqlerr  <<EOF
update eVotDat set mante=0;
EOF
    
    exit 0
fi




if [ "$1" == "randomSoundStart" ] 
    then
    /etc/init.d/randomsound start >>$LOGFILE 2>>$LOGFILE
    exit 0
fi

if [ "$1" == "randomSoundStop" ] 
    then
    /etc/init.d/randomsound stop >>$LOGFILE 2>>$LOGFILE
    exit 0
fi


if [ "$1" == "getSslCertState" ] 
    then
    crtstate=$(cat $DATAPATH/root/sslcertstate.txt 2>>$LOGFILE)
    echo -n "$crtstate"  2>>$LOGFILE
    exit 0
fi



#*-*- cuando implemente "sslcert-installcurr" y "sslcert-installnew", pasar internamente la verificaci�n de si necesitan autorizaci�n para ejecutarse (llamar cuando las ops sean estas, hacerlo antes de la verif global, arriba del todo.).


#++++
if [ "$1" == "stats" ] 
    then



    if [ "$2" == "startLog" ] 
	then
	/usr/local/bin/stats.sh startLog >>$LOGFILE 2>>$LOGFILE
	exit 0
    fi

    if [ "$2" == "updateGraphs" ]  #//// No necesita verif de llave
	then
	/usr/local/bin/stats.sh updateGraphs >>$LOGFILE 2>>$LOGFILE
	exit 0
    fi

    if [ "$2" == "installCron" ] 
	then
	/usr/local/bin/stats.sh installCron
	exit 0
    fi

    if [ "$2" == "uninstallCron" ] 
	then
	/usr/local/bin/stats.sh uninstallCron
	exit 0
    fi

    if [ "$2" == "resetLog" ] 
	then

	#Destruimos las RRD anteriores
	rm -f $DATAPATH/rrds/* >>$LOGFILE 2>>$LOGFILE

	/usr/local/bin/stats.sh startLog >>$LOGFILE 2>>$LOGFILE
	
	/usr/local/bin/stats.sh updateGraphs >>$LOGFILE 2>>$LOGFILE

	exit 0
    fi

    #Cuando saca las stats inmediatas en pantalla.  #//// No necesita verif de llave
    if [ "$2" == "" ] 
	then
	/usr/local/bin/stats.sh 2>>$LOGFILE
	exit 0
    fi



fi



#//// No necesita verif llave
if [ "$1" == "suspend" ] #//// probar en entorno real
    then
    
    getPrivVar r copyOnRAM
    
    #Si no est� en RAM, el sistema suspendido puede ser vulnerado.
    if [ "$copyOnRAM" -eq 0 ]
	then
	echo "Cannot suspend if disc is not in ram" >>$LOGFILE 2>>$LOGFILE
	exit 1 
    fi
    
    pm-suspend
    
    #Al volver del suspend, ajustamos el reloj
    ntpdate-debian  >>$LOGFILE 2>>$LOGFILE
    hwclock -w >>$LOGFILE 2>>$LOGFILE

    exit 0
fi





#Resetea las credenciales del admin o, si lleva m�s par�metros, lo sustituye por uno nuevo.
# 2-> password
# 3-> username
# 4-> full name
# 5-> user id num
# 6-> mail addr
if [ "$1" == "resetAdmin" ]
    then
    
    #Guardamos el valor antiguo
    getPrivVar d ADMINNAME
    oldADMINNAME="$ADMINNAME"
    
    checkParameterOrDie MGRPWD "${2}"
    checkParameterOrDie ADMINNAME "${3}"
    checkParameterOrDie ADMREALNAME "${4}"
    checkParameterOrDie ADMIDNUM "${5}"
    checkParameterOrDie MGREMAIL "${6}"
    
    MGRPWDSUM=$(/usr/local/bin/genPwd.php "$MGRPWD" 2>>$LOGFILE)
    
    getPrivVar d DBPWD
       
    # Si no se proporciona un adminname, reseteamos las credenciales del actual
    if [ "$3" == "" ]
	then
	
	#Update del PWD, IP y Clauer s�lo para el usuario admin
	echo "update eVotPob set clId=-1,oIP=-1,pwd='$MGRPWDSUM' where us='$oldADMINNAME';" | mysql -f -u election -p"$DBPWD" eLection 2>>/tmp/mysqlerr
	
    else
	
	#Escapamos los campos que pueden contener caracteres problem�ticos (o los que reciben entrada directa del usuario)
	adminname=$($addslashes "$ADMINNAME" 2>>$LOGFILE)
	admidnum=$($addslashes "$ADMIDNUM" 2>>$LOGFILE)
	adminrealname=$($addslashes "$ADMREALNAME" 2>>$LOGFILE)
	mgremail=$($addslashes "$MGREMAIL" 2>>$LOGFILE)
	
	
        #Inserci�n del usuario administrador (ahora no puede entrar cuando quiera, s�lo cuando se le autorice)
	echo "insert into eVotPob (us,DNI,nom,rol,pwd,clId,oIP,correo) values ('$adminname','$admidnum','$adminrealname',3,'$MGRPWDSUM',-1,-1,'$mgremail');" | mysql -f -u election -p"$DBPWD" eLection 2>>/tmp/mysqlerr
	
	#Por si el usuario ya existia, update 
	echo "update eVotPob set clId=-1,oIP=-1,pwd='$MGRPWDSUM',nom='$adminrealname',correo='$mgremail',rol=3 where us='$adminname';" | mysql -f -u election -p"$DBPWD" eLection 2>>/tmp/mysqlerr  #///probar a hacer admin a un usuario ya existente

	
        #El nuevo admin ser� el que reciba los avisos, en vez del viejo (s�lo puede ser uno, y se asume que el nuevo est� supliendo al antiguo)
	echo "update eVotDat set email='$mgremail';"  | mysql -f -u election -p"$DBPWD" eLection 2>>/tmp/mysqlerr

	setPrivVar MGREMAIL  "$MGREMAIL"  d   #////probar
	setPrivVar ADMINNAME "$ADMINNAME" d
	sed -i -re "/^root:/ d" /etc/aliases
	echo -e "root: $MGREMAIL" >> /etc/aliases   2>>$LOGFILE
	/usr/bin/newaliases    >>$LOGFILE 2>>$LOGFILE
		
    fi

    exit 0
fi






if [ "$1" == "launchTerminal" ] 
    then

        
        #Si no existe el directorio de logs del terminal, lo crea
        [ -d "$DATAPATH/terminalLogs" ] || mkdir  "$DATAPATH/terminalLogs"  >>$LOGFILE  2>>$LOGFILE
	
        #Guarda el bash_history actual si existe (no deber�a ocurrir, pero por si acaso)
        if [ -s /root/.bash_history  ] ; then
	    mv /root/.bash_history  $DATAPATH/terminalLogs/bash_history_$(date +before-%Y%m%d-%H%M%S)  >>$LOGFILE  2>>$LOGFILE
	fi
	
	#El history de esta sesi�n, se escribir� directamente en la zona de datos
	export HISTFILE=$DATAPATH/terminalLogs/bash_history_$(date +%Y%m%d-%H%M%S) #//// probar que se guardan.

	echo $"ESCRIBA exit PARA VOLVER AL MEN� DE ESPERA."
	/bin/bash
	
	#Enviar el bash_history a todos los interesados
	mailsubject=$"Registro de la sesi�n de mantenimiento sobre el servidor de voto vtUJI del $(date +%d/%m/%Y-%H:%M)"
	mailbody=$"Usted ha proporcionado su direcci�n como interesado en recibir una copia de la secuencia de comandos introducida por el t�cnico designado sobre el terminal del servidor de voto. Esta se encuentra en el fichero adjunto. Puede emplear este fichero para realizar o encargar personalmente una auditor�a de la seguridad del mismo."
	
        #Enviar correo a los interesados
	echo "$mailbody" | mutt -s "$mailsubject"  -a $HISTFILE --  $emaillist

	exit 0
fi



#////revisar
if [ "$1" == "getFile" ] 
    then
    
    # 3-> Dev
    if [ "$2" == "mountDev" ] 
	then
	
	checkParameterOrDie DEV "${3}"
	
        #//// Verificar los permisos con que se monta (por lo de las umask).
	
	#Montamos el directorio para que s�lo el root puda leer y escribir 
	# los ficheros y modificar los dirs, pero vtuji pueda recorrer y 
	# listar el �rbol de dirs. (las m�scaras son umask, hace el XOR 
	# entre estas y la default del proceso, que deber�a ser 755)
	mkdir -p /media/USB >>$LOGFILE 2>>$LOGFILE
	mount "$DEV""1" /media/USB -o dmask=022,fmask=027 >>$LOGFILE 2>>$LOGFILE
	ret=$?
	
	if [ "$ret" -ne 0 ] 
	    then
	    echo "getFile mountDev: El dispositivo no pudo ser accedido."  >>$LOGFILE  2>>$LOGFILE
	    umount /media/USB
	    exit 11
	fi
	
	exit 0
    fi

    


    if [ "$2" == "umountDev" ] 
	then
	umount /media/USB >>$LOGFILE 2>>$LOGFILE
	rmdir /media/USB  >>$LOGFILE 2>>$LOGFILE
	exit 0
    fi



    # 3 -> file path to copy to destination
    if [ "$2" == "copyFile" ] 
	then


	checkParameterOrDie FILEPATH  "$3"  "0"
	
	aux=$(echo "$3" | grep -Ee "^/media/USB/.+")
	if [ "$aux" == "" ] 
	    then
	    echo "Ruta inv�lida. Debe ser subdirectorio de /media/USB/"  >>$LOGFILE 2>>$LOGFILE
	    exit 31
	fi

	aux=$(echo "$3" | grep -Ee "/\.\.(/| |$)")
	if [ "$aux" != "" ] 
	    then
	    echo "Ruta inv�lida. No puede acceder a directorios superiores."  >>$LOGFILE 2>>$LOGFILE 
	    exit 32
	fi
	
	rm -rf    $ROOTFILETMP >>$LOGFILE 2>>$LOGFILE
	mkdir -p  $ROOTFILETMP >>$LOGFILE 2>>$LOGFILE
	chmod 750 $ROOTFILETMP >>$LOGFILE 2>>$LOGFILE
	
	destfile=$ROOTFILETMP"/usbrreadfile"
	
	#echo "------->cp $3  $destfile"
        #echo "-------------------"
        #ls -l $3
        #echo "-------------------"
        #ls -l $DATAPATH 
        #echo "-------------------"

	cp -f "$3" "$destfile"  >>$LOGFILE 2>>$LOGFILE
      
	exit 0
    fi
    
    echo "getFile: bad subopcode." >>$LOGFILE 2>>$LOGFILE
    exit 1
fi



#//// implementar verifycert  SIN VERIF!! (porque se usa para discernir si la instalaci�n del cert requiere autorizaci�n o no  ---> Las ops que se ejecutan durante la instal del cert deben hacerse sin verif, pero s�lo cuando falle verifycert!!!  --> ver cu�les son.)








echo "LA OP $1 $2 $3 HA LLEGADO AL FINAL. PUEDE SER UN EXIT OLVIDADO O EL COD/SUBCOD ESTA MAL ESCRITO O UBICADO " >>$LOGFILE 2>>$LOGFILE  
exit 255
#//// asegurarme de que no sale ninguna vez en el log cuando todo vaya bien, pero dejarlo.







#Trazar en la aplicaci�n cu�ndo aparecen y desaparecen los datos cr�ticos de memoria (pwd de la part, pwd de root de la bd, etc...). Limitar su tiempo de vida al m�ximo. 

#Antes del standby, borrar todos los datos, y si son necesarios luego, pasar esas ops a privado y que se carguen esos datos de la zona privada.


#Aislar el Pwd de la bd (no solo el de root, sino el de vtuji) y hacer que los ficheros de /var/www no sean legibles para vtuji (solo root y www-data)

#Cuando se invoque a las ops privilegiadas, si existen fragmentos de llave, estos se har�n ilegibles poara el no priv.

#Quitar la posibilidad de abrir un terminal de root con el panic? o ponerle comprobaci�n de llave a esta func tb para cuando pase en modo mant?


#Decidir d�nde activo la verificaci�n de clave (lo m�s adecuado ser�a hacerlo en cuanto se crea/monta la partici�n, pero puede ser molesto verificar en cada op que haga. Mejor lo hago justo cuando el sistema queda en standby.) . El paso de la contrase�a/piezas ser� por fichero/llamada a OP y funcionar� como sesi�n. El cliente ser� el encargado de invalidar la contrase�a (o piezas) cuando acabe de operar (o lo hago al acabar cada operaci�n desde privops? es m�s seguro pero m�s molesto. Ver si es factible.)



#////$DATAPATH/newcsr --> revisar el control de este directiro (cu�ndo se crea, se borra, etc. Tengo que hacerlo aqu�)

#////Todas las apariciones de $DATAPATH/newcsr $DATAPATH/server.* $DATAPATH/ca... cambiarlas a $DATAPATH/webserver




#////+++++ falta, en wizard, privops y privsetup, revisar todas las apariciones de DATAPATH o /media/eLectionCryptoFS o /media/crypStorage y ver que los ficheros que accede/escribe est�n en el path adecuado.





#//// En el standby, borrar wizardlog y dblog, o guardarlos s�lo para root.




#//// Quiz�, en vez de tener operaciones con o sin contrase�a (alguna deber� ser necesariamente sin contrase�a. Estudiar.), hacerlo dependiente del momento: durante el setup, todas sin contrase�a. Cuando acabe el setup, guiardar un flag en /root y que pida siempre la contrase�a. Securizar /root como toca.



#////Revisar todos los params y toda interacci�n con el usuario, para ver que no pueda crearse una vulnerabilidad. (por ejemplo, los params, pasarles la funci�n que asegura el tipo y el contenido adecuados. Ver c�mo puedo hacer que el usuario s�lo pueda ejecutarlos en el momento adecuado -> por ejemplo, separar las ops que puedan usarse en standby de las de la inst y config. Al acabar la inst, quitar el permiso de ejecuci�n a estas.







#//// Antes de ejecutar cualquier op, reconstruir la clave.  --> En vez de reconstruir, pedir el pwd de cifrado de la part y ver c�mo puedo testear este pwd con cryptsetup frente a la partici�n.




#//// revisar todos los par�metros a fondo!!! Revisar cuando se invoque desde el standby. Asegurarme de que se pueda invocar verificando el pwd de la partici�n (lo digo sobretodo pensando en la func de cambiar partici�n de datos).  --> Alternativamente, hacer funciones de m�s alto nivel que integren las operaciones que provocar�an un impass (ej, la de cambiar la part de datos) --> Otra forma ser�a implementar 2 formas  de autorizaci�n


#//// Para los script que ejecuta vtuji, evitar confiar en el PATH: poner rutas absolutas a todo (un atacante podr�a alterar la var PATH)


    #//// los pwd al menos, leerlos de los dirs de config
