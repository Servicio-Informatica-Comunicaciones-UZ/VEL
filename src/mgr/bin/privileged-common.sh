#!/bin/bash





###### Constants ########


OPSEXE=/usr/local/bin/eLectionOps  # //// Ver si alguna operación es crítica, y hacerlo sólo root y cambiar esta var para que invoque al sudo --> Porque resulta absurdo que la func encargada de leer clauers y reconstruir claves pida la clave, claro. Si todo es legal para vtuji y este puede usarla, darle permisos de ejecución sin necesidad de que sea root.# //// Probar opsexe desde un terminal vtuji para asegurarme de que puede hacerlo todo siendo un usuario no privilegiado.  #--> Sólo accesible por el root (cambiar permisos) verificar que al final en setup no se usa o defihnir esta var en ambos sitios.


ROOTTMP="/root/"

ROOTFILETMP=$ROOTTMP"/filetmp"
ROOTSSLTMP=$ROOTTMP"/ssltmp"

#Cuántos directorios para escribir fragmentos de llave hay en el sistema
SHAREMAXSLOTS=2


###### Methods ########





#1 -> Modo de acceso a la partición cifrada "$DRIVEMODE"
#2 -> Ruta donde se monta el dev que contiene el fichero de loopback "$MOUNTPATH" (puede ser cadena vacía)
#3 -> Nombre del mapper device donde se monta el sistema cifrado "$MAPNAME"
#4 -> Path donde se monta la partición final "$DATAPATH"
#5 -> Ruta al dev loop que contiene la part cifrada "$CRYPTDEV"  (puede ser cadena vacía)
#6 -> iscsitarget   (puede ser cadena vacía)
#7 -> iscsiserver   (puede ser cadena vacía)
#8 -> iscsiport     (puede ser cadena vacía)
umountCryptoPart () {


    iscsitarget=$6
    iscsiserver=$7   
    iscsiport=$8


    umount  "$4"  #Desmontamos la ruta final
    cryptsetup luksClose /dev/mapper/$3 >>$LOGFILE 2>>$LOGFILE #Desmontamos el sistema de ficheros cifrado


    case "$1" in
	"local" )
        :
	;;
	
	"iscsi" )
	iscsiadm -m node -T "$iscsitarget" -p "$iscsiserver:$iscsiport" -u  >>$LOGFILE 2>>$LOGFILE
        ;;
	
	"nfs" )
	losetup -d $5
	umount $2   #Desmonta el directorio montado por NFS
        ;;
	
	"samba" )
	losetup -d $5
	umount $2   #Desmonta el directorio montado por SMB
        ;;
	
	"file" )
	losetup -d $5
	umount $2   #Desmonta la partición que contiene el fichero de loopback
        ;;
	
    esac


}



#$1 -> Ruta base
#$2 -> Octal perms for files
#$3 -> Octal perms for dirs

setPerm () {
    local directorios="$1 "$(ls -R $1/* | grep -oEe "^.*:$" | sed -re "s/^(.*):$/\1/")
    
    echo -e "Directorios:\n $directorios"  >>$LOGFILE 2>>$LOGFILE

    for direct in $directorios
      do
      
      local pfiles=$(ls -p $direct | grep -oEe "^.*[^/]$")
      local pds=$(ls -p $direct | grep -oEe "^.*[/]$")
      
      echo -e "=== Dir $direct files: ===\n$pfiles"  >>$LOGFILE 2>>$LOGFILE
      echo -e "=== Dir $direct dirs : ===\n$pds"  >>$LOGFILE 2>>$LOGFILE
      
      for pf in $pfiles
	do
	echo "chmod $2 $direct/$pf"  >>$LOGFILE 2>>$LOGFILE
	chmod $2 $direct/$pf  >>$LOGFILE 2>>$LOGFILE
      done

      for pd in $pds
	do
	echo "chmod $3 $direct/$pd"  >>$LOGFILE 2>>$LOGFILE
	chmod $3 $direct/$pd  >>$LOGFILE 2>>$LOGFILE
      done
    done
}



listHDDs () {
    
    drives=""
    
    usbs=''
#$$$$1    usbs=$(listUSBs)  #La llamada a sginfo -l peta totalmente mi sistema (debian etch stable), pero por suerte no la ubuntu lucid.

    for n in a b c d e f g h i j k l m n o p q r s t u v w x y z 
      do
      
      drivename=/dev/hd$n
      
      [ -e $drivename ] && drives="$drives $drivename"
      
      drivename=/dev/sd$n

      for usb in $usbs
	do
	#Si el drive name es un usb, pasa de él.
	[ "$drivename" == "$usb" ]   && continue 2
      done

      
      [ -e $drivename ] && drives="$drives $drivename"
      
    done
    
    
    echo "$drives"
    
}






setupRAIDs () {
    
    mdadm --examine --scan --config=partitions >/tmp/mdadm.conf                  2>>$LOGFILE
    
    ret=0
    ret2=0
    if [ "$(cat /tmp/mdadm.conf)" != "" ] 
	then
	
        #Quito --run y pongo --no-degraded para evitar que intente cargar arrays degradados
	mdadm --assemble --scan --no-degraded --config=/tmp/mdadm.conf --auto=yes >>$LOGFILE 2>>$LOGFILE
	ret=$?
	
        #Comprobamos el estado del raid
	mdadm --detail --scan --config=/tmp/mdadm.conf >>$LOGFILE 2>>$LOGFILE
	ret2=$?
    fi
    
    if [ "$ret" -ne 0 -o "$ret2" -ne 0 ]
	then
        #Si el raid está degradado o faltan discos o se produce cualquier error
	systemPanic $"Error: no se activaron las unidades RAID debido a errores o inconsistencias. Solucione el problema antes de continuar."
    fi
    
    #No lo borro. Ahora me sirve para el monitor
    #rm /tmp/mdadm.conf >>$LOGFILE 2>>$LOGFILE
    
    
    #Crear un RAID (create añade un superbloque en cada disco)
    # mdadm --create /dev/md0 --level=raid1 --raid-devices=2 /dev/hda1 /dev/hdc1
    # Crear tabla de particiones:  $fdisk /dev/md0  c(dos compatibility off) u(units to sectors) o (new table) n (new partition) w

    #Consultar estado del raid o de sus unidades en particular
    #mdadm --detail /dev/md0
    #mdadm --examine /dev/sda
    #cat /proc/mdstat and instead of the string [UU] you will see [U_] if you have a degraded RAID1 array.


    #Consultar estado de las operaciones:
    # cat /proc/mdstat
    
    #Reconstruir un raid si se ha degradado:
    # mdadm --fail /dev/md0 /dev/hdc1    #Marca el disco como malo
    # mdadm --remove /dev/md0 /dev/hdc1  #Elimina el disco malo del array
    #Apagar y sustituir el disco
    # mdadm --zero-superblock /dev/hdc1  #Por si el disco nuevo viene de otro RAID, machacamos la info del superbloque
    # mdadm --add /dev/md0 /dev/hdc1     #Añadimos el disco al array
}




#$1 -> variable (variable is uniquely recognized to belong to a data type)
#$2 -> value    to set in the variable if fits the data type
#$3 -> 0: don't set the variable value, just check if it fits. 1(default): set the variable with the value.
checkParameterOrDie () {
    
    local val=$(echo "$2" | sed -re "s/\s+//g")

    if [ "$val" == "" ]
	then
	return 0
    fi

    if checkParameter "$1" "$val"
	then
	echo "param OK: $1=$2"   >>$LOGFILE 2>>$LOGFILE  #////Borrar el valor del param del echo, que no se loguee
	if [ "$3" != "0" ]
	    then
	    export "$1"="$val"
	fi
    else
	echo "param ERR (exiting 1): $1=$2"   >>$LOGFILE 2>>$LOGFILE
	exit 1
    fi
}




#//// Esta debería desaparecer, si todos los params se gestionan en root. --> poner esta func en root y cargar todas las variables con esto y punto (primero del clauer y después de vars.conf del hd y después de vars.conf del root.) Revisar todos los params y los que sea imprescindible tener en el wizard, crear servicio que los devuelva.



# $1 --> file to read vars from 
setVariablesFromFile () {
    
    [ "$1" == ""  ] && return 1

    #Para cada par variable=valor
    BAKIFS=$IFS
    IFS=$(echo -en "\n\b")
    exec 5<&0
    exec 0<"$1"  #Escribe el fichero en la entrada estàndar
    while read -r couple
      do
      
      #echo "Linea: " $couple
      
      #Sacamos la var y el valor
      var=$(echo "$couple" | grep -Eoe "^[^=]+");
      val=$(echo "$couple" | grep -Eoe "=.+$" | sed "s/=//" | sed 's/^"//' | sed 's/".*$//g');


      #Verificar el formato de cada uno de ellos con el parser del form.
      #En la función parseInput, para el modo 'ipaddr', requiere que IFS tenga su valor original, o no verifica correctamente. Lo restauramos temporalmente.
      IFS=$BAKIFS

      checkParameter "$var" "$val"
      chkret=$?
      
      if [ "$chkret" -eq 1 ] 
	  then
	  echo "ERROR setVariablesFromFile: bad param or value: $var = $val" >>$LOGFILE  2>>$LOGFILE
	  systemPanic $"Uno de los parámetros está corrupto o manipulado." 
      fi
      
      BAKIFS=$IFS
      IFS=$(echo -en "\n\b")
      
      #Ejecutar cada instancia
      #echo "Setting: $var=$val"
      export $var=$val
      
    done
    exec 0<&5
    
    # restore $IFS which was used to determine what the field separators are
    IFS=$BAKIFS
    
    return 0
}



# //// ++++ llamara  esta desde las ops.

#Establece las variables de config de la app, para las ops que las 
# necesitan, con la precedencia adecuada por si alguna está redefinida
# en otro fichero (redefinida quiere decir que la variable aparece y 
# si está vacía ese es su valor, si no aparece se quedará el valor anterior)
setAllConfigVariables () {
    
    getPrivVar r CURRENTSLOT   #////probar
    
    setVariablesFromFile "$ROOTTMP/slot$CURRENTSLOT/config"x
    
    setVariablesFromFile "$DATAPATH/root/vars.conf"
    
    setVariablesFromFile "$ROOTTMP/vars.conf"
    
}





#//// Esta func probablemente sea inútil, porque ahora las vars las escribiré directamente en un fichero usando una op priv. --> convertirla en una función setConfig que llame a la privop cada vez que toque.


#Pasa las variables de configuración empleadas en este caso a una cadena separada por saltos de linea para volcarlo a un clauer
serializeConfig () {
    
    cfg=''
    
    cfg="$cfg\nIPMODE=\"$IPMODE\""
    
    if [ "$IPMODE" == "user"  ] #si es 'dhcp' no hacen falta
	then
	cfg="$cfg\nIPADDR=\"$IPADDR\""
	cfg="$cfg\nMASK=\"$MASK\""
	cfg="$cfg\nGATEWAY=\"$GATEWAY\""
	cfg="$cfg\nDNS1=\"$DNS1\""
	cfg="$cfg\nDNS2=\"$DNS2\""
	cfg="$cfg\nFQDN=\"$FQDN\""
    fi
    
    if [ "$FQDN" != ""  ]
	then
	cfg="$cfg\nFQDN=\"$FQDN\""
    fi
    
    cfg="$cfg\nDRIVEMODE=\"$DRIVEMODE\""
    
    case "$DRIVEMODE" in
	
	"local" )
        cfg="$cfg\nDRIVELOCALPATH=\"$DRIVELOCALPATH\""
	;;
	
    	"nfs" )
	cfg="$cfg\nNFSSERVER=\"$NFSSERVER\""
	cfg="$cfg\nNFSPORT=\"$NFSPORT\""
	cfg="$cfg\nNFSPATH=\"$NFSPATH\""
	cfg="$cfg\nNFSFILESIZE=\"$NFSFILESIZE\""
        cfg="$cfg\nCRYPTFILENAME=\"$CRYPTFILENAME\""
    	;;
	
    	"samba" )
	cfg="$cfg\nSMBSERVER=\"$SMBSERVER\""
	cfg="$cfg\nSMBPORT=\"$SMBPORT\""
	cfg="$cfg\nSMBPATH=\"$SMBPATH\""
	cfg="$cfg\nSMBUSER=\"$SMBUSER\""
	cfg="$cfg\nSMBPWD=\"$SMBPWD\""
	cfg="$cfg\nSMBFILESIZE=\"$SMBFILESIZE\""
        cfg="$cfg\nCRYPTFILENAME=\"$CRYPTFILENAME\""
    	;;
	
    	"iscsi" )
	cfg="$cfg\nISCSISERVER=\"$ISCSISERVER\""
	cfg="$cfg\nISCSIPORT=\"$ISCSIPORT\""
	cfg="$cfg\nISCSITARGET=\"$ISCSITARGET\""
    	;;
	
    	"file" )
	cfg="$cfg\nFILEPATH=\"$FILEPATH\""
	cfg="$cfg\nFILEFILESIZE=\"$FILEFILESIZE\""
        cfg="$cfg\nCRYPTFILENAME=\"$CRYPTFILENAME\""
    	;;
	
    esac

    cfg="$cfg\nUSINGSSHBAK=\"$USINGSSHBAK\""
    
    if [ "$USINGSSHBAK" -eq 1 ] ; then
	cfg="$cfg\nSSHBAKSERVER=\"$SSHBAKSERVER\""
	cfg="$cfg\nSSHBAKPORT=\"$SSHBAKPORT\""
	cfg="$cfg\nSSHBAKUSER=\"$SSHBAKUSER\""
	cfg="$cfg\nSSHBAKPASSWD=\"$SSHBAKPASSWD\""
    fi


    cfg="$cfg\nSHARES=\"$SHARES\""
    cfg="$cfg\nTHRESHOLD=\"$THRESHOLD\""

    #echo -e "CONFIG:: $cfg"
    #Al pasarlo a un fichero hay que hacer echo -e o no interpretará los \n
}


parseConfigFile () {
    
    cat "$1" | grep -oEe '^[a-zA-Z][_a-zA-Z0-9]*?=("([^"$]|[\]")*?"|""|[^ "$]+)'
    
}




#Sets a config variable to be shared among invocations of privilegedOps
# $1 -> variable
# $2 -> value
# $3 (opcional) -> 'd' si queremos que se guarde en disco, 'r' o nada si queremos que se guarde en RAM 'c' si queremos ponerla en el fichero de config del clauer (el establecido) , 's' del slot activo
setPrivVar () {


    local file="$ROOTTMP/vars.conf"
    if [ "$3" == "d" ]
	then
	file="$DATAPATH/root/vars.conf"
    fi
    if [ "$3" == "c" ]
	then
	file="$ROOTTMP/config"
    fi
    if [ "$3" == "s" ] #*-*-
	then
	getPrivVar r CURRENTSLOT
	slotPath=$ROOTTMP/slot$CURRENTSLOT/
	file="$slotPath/config"
    fi

    echo "****setting var on file $file: '$1'='$2'" >>$LOGFILE 2>>$LOGFILE #////Borrar

    touch $file
    chmod 600 $file  >>$LOGFILE 2>>$LOGFILE


    #Verificamos si la variable está definida en el fichero
    local isvardefined=$(cat $file | grep -Ee "^$1")

    echo "isvardef: $1? $isvardefined" >>$LOGFILE 2>>$LOGFILE

    #Si no lo está, append
    if [ "$isvardefined" == "" ] ; then
	echo "$1=\"$2\"" >> $file
    else
    #Si lo está, sustitución.
	sed -i -re "s/^$1=.*$/$1=\"$2\"/g" $file
    fi
    
}


		
# $1 -> 'd' si queremos leer de disco, 'r' si queremos leer de RAM, 'c' si queremos leer de la config leida del clauer y establecida, 's' del slot activo
# $2 -> var name (to be read)
# $3 -> (optional) name of the destination variable
#Si la var no está definida en el fichero, no cambia su valor actual (si lo tuviese).
getPrivVar () {

    local file="$ROOTTMP/vars.conf"
    if [ "$1" == "d" ]
	then
	file="$DATAPATH/root/vars.conf"
    fi
    if [ "$1" == "c" ]
	then
	file="$ROOTTMP/config"
    fi
    if [ "$1" == "s" ] #*-*-
	then
	getPrivVar r CURRENTSLOT
	slotPath=$ROOTTMP/slot$CURRENTSLOT/
	file="$slotPath/config"
    fi

    [ -f "$file" ] || return 1
        
    local destvar=$2
    [ "$3" != "" ] && destvar=$3

    if (parseConfigFile $file | grep -e "^$2" >>$LOGFILE 2>>$LOGFILE)
	then #//// El >> LOGFILE de arriba debo cambiarlo por dev/null,  por seguridad
	:
	else
	echo "****variable '$2' not found in file '$file'." >>$LOGFILE 2>>$LOGFILE  #////QUITAR
	return 1
    fi
    
    
    value=$(cat $file 2>>$LOGFILE  | grep -e "$2" 2>>$LOGFILE | sed -re "s/$2=\"(.*)\"\s*$/\1/g" 2>>$LOGFILE)
    
    export $destvar=$value

#////Verificar que si no existe, no pasa nada.

    echo "****getting var from file '$file': '$2' on var '$3' = $value" >>$LOGFILE 2>>$LOGFILE  #//// QUITAR

    return 0 
}




#//// Quitar toda interactividad... en todo caso que devuelva el mensaje en un buffer y un errcode alto. revisar en wizard los sitios en que se llame y si devuelve ese error, que lea el buffer y haga un syspanic con dicho mensaje --> de aquí se podría eliminar el systemisrunning
#1-> El mensaje de panic
#2-> 'f' -> fuerza el modo panic aunque esté activado el flag de volver al menu idle.
systemPanic () {
    
    $dlg --msgbox "$1" 0 0

    getPrivVar r SYSTEMISRUNNING

    #Si el sistema ya está en marcha (se estaba ejecutando alguna acción de mantenimiento), 
    # el panic no tiene por qué apagar el equipo. A no ser que se fuerce a ello.
    # En este caso, vuelve al menú de standby.
    if [ "$SYSTEMISRUNNING" -eq 1 -a "$2" != "f" ]
	then
	exit 1
    fi
    
    
    #Destruimos variables sensibles
    keyyU=''
    keyyS=''
    MYSQLROOTPWD=''


    exec 4>&1 
    selec=$($dlg --no-cancel  --menu $"Elija una opción." 0 0  3  \
	1 $"Apagar el sistema." \
	2 $"Reiniciar el sistema." \
	3 $"Lanzar terminal de acceso total al sistema." \
	2>&1 >&4)
    
    
    case "$selec" in
	
	"1" )
        #Apagar el sistema
        shutdownServer "h"
	
        ;;

	"2" )
	#Reiniciar sistema
        shutdownServer "r"
        ;;
	
	"3" )
	$dlg --yes-label $"Sí" --no-label $"No"  --yesno  $"ATENCIÓN:\n\nHa elegido lanzar un terminal. Esto otorga al manipulador del equipo acceso a datos sensibles hasta que este sea reiniciado. Asegúrese de que no sea operado sin supervisión técnica para verificar que no se realiza ninguna acción ilícita. ¿Desea continuar?" 0 0
	[ "$?" -eq 0 ] && exec $PVOPS rootShell
        ;;	
	* )
	echo "systemPanic: Bad selection"  >>$LOGFILE 2>>$LOGFILE
	$dlg --msgbox "BAD SELECTION" 0 0
	shutdownServer "h"
	;;
	
    esac
    
    shutdownServer "h"
        
}




#1 -> path del fichero con el cert / los cert a probar
#2 -> modo: 'serverCert' para verificar el certificado ssl, 'certChain' para verificar la cadena de certificación
#3 -> path de la llave (modo serverCert)
checkCertificate () {

    [ "$1" == "" ] && echo "checkCertificate: no param 1" >>$LOGFILE  2>>$LOGFILE  && return 11
    [ "$2" == "" ] && echo "checkCertificate: no param 2" >>$LOGFILE  2>>$LOGFILE  && return 12
    [ "$2" == "serverCert" -a "$3" == "" ] && echo "checkCertificate: no param 3 at mode serverCert" >>$LOGFILE  2>>$LOGFILE  && return 13

    #Verificamos que no sea vacio
    if [ -s "$1" ] 
	then
	:
    else
	echo "Error: el fichero esta vacio." >>$LOGFILE  2>>$LOGFILE 
	return 14
    fi

    
    #Para pasar un cert de der a pem
    #openssl x509 -inform DER -outform PEM -in "$1" -out /tmp/cert.pem
    
    #Separamos los certificados del fichero en distintos ficheros, para probarlos todos
    /usr/local/bin/separateCerts.py  "$1"
    ret=$?
	      
    if [ "$ret" -eq 3 ] 
	then
	echo "Error de lectura." >>$LOGFILE  2>>$LOGFILE 
	return 15
    fi
    if [ "$ret" -eq 5 ]  
	then
	echo "Error: el fichero no contiene certificados PEM." >>$LOGFILE  2>>$LOGFILE 
	return 16
    fi
    #[ "$ret" -eq 6 ]  && $dlg --msgbox $"Error: el fichero debe contener al menos el certificado y una CA." 0 0 && return 1
    if [ "$ret" -ne 0 ]  
	then
	echo "Error procesando el fichero de certificado." >>$LOGFILE  2>>$LOGFILE 
	return 17
    fi
    
    certlist=$(ls "$1".[0-9]*)
    certlistlen=$(echo $certlist | wc -w)

    #Si estamos procesando el fichero con el cert ssl del servidor, debe estar él solo
    if [ "$2" == "serverCert" -a  "$certlistlen" -ne 1 ]
	then
	echo "El fichero sólo debe contener el certificado de servidor." >>$LOGFILE  2>>$LOGFILE 
	return 18
    fi
    
    
    #Para cada uno de ellos
    for c in $certlist
      do
      
      #Verificamos que sea un certificado
      openssl x509 -text < $c  >>$LOGFILE  2>>$LOGFILE
      ret=$?
      if [ "$ret" -ne 0  ] 
	  then 
	  echo "Error: certificado no válido." >>$LOGFILE  2>>$LOGFILE
	  return 19
      fi
      
      
#     #Verificamos confianza con el cert
#     validated=0
#     for cacert in $(find /usr/share/ca-certificates/ -iname "*.crt")
#	  do
#	  iserror=$(openssl verify -CAfile "$cacert" -purpose sslserver "$c"|grep -ioe "error")	
#	  #Si no ha salido una cadena de error, es que se ha verificado
#         [ "$iserror" == ""  ] && validated=1 && break
#     done
#        
#     if [ $validated -eq 0 ] 
#	  then
#         $dlg --msgbox $"Error: certificado firmado por una entidad no confiable." 0 0 
#	  return 1
#     fi
      
      #Si estamos procesando el fichero con el cert ssl del servidor, verificamos que coincida con la llave
      if  [ "$2" == "serverCert" ] ; then
          #verificar que la llave corresponde al cert: (si ambos comandos dan el mismo resultado)
	  aa=$(openssl x509 -noout -modulus -in $c | openssl sha1)
	  bb=$(openssl rsa  -noout -modulus -in $3 | openssl sha1)
	  
	  #echo -e "aa:$aa\nbb:$bb\n-----------"
  	  #ls -l  $c
	  #echo "------------"
	  #ls -l $3
	  #echo "------------"
	  
	  #Si coinciden, es que uno de los certs es el asociado a esta llave
	  if [ "$aa" != "$bb" ]
	      then
	      echo "Error: el certificado no corresponde con la llave." >>$LOGFILE  2>>$LOGFILE
	      return 20
	  fi
      fi
      
    done
    
    return 0
}  





# $1 -> Certificate to verify
# $2 -> (optional) CA chain
# RET: 0: ok  1: error
verifyCert () {
    
    [ "$1" == "" ] && return 1
    
    if [ "$2" != "" ]
	then
	chain=" -untrusted $2 "
    fi
    
    
    iserror=$(openssl verify -purpose sslserver -CApath /etc/ssl/certs/ $chain  "$1" 2>&1  | grep -ie "error")
    
    echo $iserror  >>$LOGFILE 2>>$LOGFILE
    
    #Si no ha salido una cadena de error, es que se ha verificado
    [ "$iserror" != ""  ] && return 1
    
    return 0
    
}

