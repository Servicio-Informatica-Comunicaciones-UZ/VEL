#!/bin/bash


. /usr/local/bin/common.sh 

. /usr/local/bin/privileged-common.sh

. /usr/local/bin/firewall.sh

# TODO extinguir WWWMODE. Siempre ssl (aunque sea snakeoil)




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















#List all of the partitions for a give device
#1 -> drive path
#Stdout: list of partitions
#Return: number of partitions
getPartitionsForDrive () {
    
    [ "$1" == "" ] && return 0
    
    local parts=$($fdisk -l "$1" 2>>$LOGFILE | grep -Ee "^$1" | cut -d " " -f 1)
    local nparts=0
    
    for part in $parts ; do
        nparts=$((nparts+1))
    done
    
    echo "$parts"
    return $nparts
}


#Check if a partition can be mounted and files written on it
#1 -> partition path
isFilesystemWritable () {
    local part="$1"

    mkdir -p /media/testpart   >>$LOGFILE 2>>$LOGFILE   
    
    #Try to mount
    mount "$part" /media/testpart >>$LOGFILE 2>>$LOGFILE
    [ $? -ne 0 ] && return 1

    #Try to write a file
    echo "a" > /media/testpart/testwritability 2>/dev/null
    [ $? -ne 0 ] && return 1
    
    #Clean and unmount
    rm -f /media/testpart/testwritability
    umount /media/testpart >>$LOGFILE 2>>$LOGFILE
    rmdir /media/testpart >>$LOGFILE 2>>$LOGFILE 
    
    return 0
}

#Guess in which filesystem is a partition formatted
#1 -> partition path
#Stdout: filesystem name
guessFS () {
    local part="$1"
    
    mkdir -p /media/testpart   >>$LOGFILE 2>>$LOGFILE   
    mount "$part" /media/testpart >>$LOGFILE 2>>$LOGFILE
    
    #Get partition FS
    local partFS=$(cat /etc/mtab  | grep "$part" | cut -d " " -f3 | uniq) 
	   
    umount /media/testpart   >>$LOGFILE 2>>$LOGFILE
    rmdir /media/testpart >>$LOGFILE 2>>$LOGFILE 
    
    [ "$partFS" == "" ] && return 1
    echo "$partFS"
    return 0
}


#Guess the size of a partition
#1 -> partition path
#Stdout: size of the partition in bytes
guessPartitionSize () {
    [ "$1" == "" ] && return 1
    
    local drive=$(echo $part | sed -re 's/[0-9]+$//g')
    [ "$drive" == "" ] && return 1 
    
    local nblocks=$($fdisk -l "$drive" 2>>$LOGFILE | grep "$1" | sed -re "s/[ ]+/ /g" | cut -d " " -f4 | grep -oEe '[0-9]+' )
    [ "$nblocks" == "" ] && return 1
     
    local blocksize=$($fdisk -l "$drive" 2>>$LOGFILE | grep -Eoe "[*][ ]+[0-9]+[ ]+=" | sed -re "s/[^0-9]//g" )
	   [ "$blocksize" == "" ] && return 1
    
	   [ "$blocksize" -lt 1024 ] && blocksize=1024
	   local thissize=$(($blocksize*$nblocks))      

    echo $thissize
    return 0
}

#Converts byte value to a human friendly magnitude, will attach
#corresponding unit indicator
#1 -> original byte value
#Stdout: readable value with unit
humanReadable () {
    python -c "
num=$1
units=['B','KB','MB','GB','TB']
multiplier=0
while num >= 1024 and multiplier<len(units):
  #print 'Num ',num
  #print 'Mul ',multiplier
  num/=1024.0
  multiplier+=1
#print 'Num ',round(num,1)
#print 'Mul ',multiplier

print str(round(num,2))+units[multiplier]
" 
}


#Will list all hard drive partitions available
#1 -> 'all': (default) Show all partitions
#     'wfs': Show only partitions with a filesystem that can be mounted and written
#2 ->  'list': (default) show only the list
#    'fsinfo': Will add partition info (filesystem and size)
#Returns: number of partitions found
#Stdout: list of partitions
listHDDPartitions () {
    
    #Get all HDDs
    local drives=$(listHDDs)
    
    #Get all RAID devices (in wfs mode, hdds forming a raid array will
    #never be listed, as they cannot be mounted, but on all mode they
    #must be listed (although the array will be destroyed)
    for mdid in $(seq 0 99) ; do
	       drives="$drives /dev/md$mdid"
    done
    
    echo "ATA Drives found: $drives"  >>$LOGFILE 2>>$LOGFILE

    
    #For each drive
    local partitions=""
    local npartitions=0
    for drive in $drives
    do
        echo "Checking: $drive"  >>$LOGFILE 2>>$LOGFILE
        
        #Get this drive's partitions
        local thisDriveParts=$(getPartitionsForDrive)
        local thisDriveNParts=$?
        if [ "$thisDriveNParts" -gt 0 ] 
	       then
            #If all partitions are to be returned, add them
            if [ "$1" == "all" ] ; then
                partitions="$partitions $thisDriveParts"
                npartitions=$((npartitions+thisDriveNParts))
                
            #Show only writable partitions
            elif [ "$1" == "wfs" ] ; then
	               for part in $thisDriveParts
		              do
		                  if isFilesystemWritable $part
		                  then
                        partitions="$partitions $part"
                        npartitions=$((npartitions+1))
                    fi
	               done
	           else
                echo "list hdd partitions: Bad parameter $1"  >>$LOGFILE 2>>$LOGFILE
                return 255
	           fi
        fi
    done
    echo "Partitions: "$partitions  >>$LOGFILE 2>>$LOGFILE
    
    #If only the list of partitios was requested, return it now
    if [ "$2" != "fsinfo" ] ; then
        echo "$partitions"
        return $npartitions
    fi
    
    #For each partition to be returned, get partition info (filesystem, size)
    local partitionsWithInfo=""
    for part in $partitions
    do
        #Guess filesystem
	       local thisfs=$(guessFS "$part")
        [ $? -ne 0 ] && thisfs="?"
        
        #Guess size of partition (and make it readable)
        local thissize=$(guessPartitionSize "$part")
        if [ $? -ne 0 ] ; then thissize="?"
        else
            thissize=$(humanReadable "$thissize")
        fi
        #Add the return line fields: partition and info
        partitionsWithInfo="$partitionsWithInfo $part $thisfs|$thissize"
    done
    echo "Partitions with info: $partitionsWithInfo"  >>$LOGFILE 2>>$LOGFILE
    
    echo "$partitionsWithInfo"
    return $npartitions
}





















####################### Gesti�n de variables ############################


if [ "$1" == "vars" ]  # TODO revisar todas las llamadas, tb cambiar por disk, mem, usb y slot
    then

 #Para que el wizard le pase los valores de las variables definidas por el usuario en la inst.
 # 3-> destino c (clauer) d (disco) r (memoria) s (slot activo)
 # 4-> var name
 # 5-> var value
 if [ "$2" == "setVar" ] 
     then
     
     #////implementar limitaci�n  de escritura a ciertas variables cuando running?

     checkParameterOrDie "$4" "$5" 0  # TODO Te�ricamente todos los params est�n en checkparameter. asegurarme.

     setVar "$4" "$5" "$3"

     exit 0
 fi



 #Para que el wizard reciba los valores de ciertas variables durante el reset.
 # 3-> origen c (clauer) d (disco) r (memoria) s (slot activo)
 # 4-> var name
 if [ "$2" == "getVar" ]
     then

     if [ "$3" != "c" -a "$3" != "d" -a "$3" != "r" -a "$3" != "s" ]
	 then
	 echo "getVar: bad data source: $3" >>$LOGFILE 2>>$LOGFILE
	 exit 1
     fi

# TODO quitar esta restricci�n. O si hace falta leer alguna var sin autorizaci�n de la comisi�n, marcar s�lo las excepciones
# Asegurarme de que $SITESCOUNTRY $SITESORGSERV $SITESEMAIL est�n en alg�n fichero de variables      
     if [ "$4" != "WWWMODE" -a "$4" != "SSHBAKPORT" -a "$4" != "SSHBAKSERVER" -a "$4" != "DOMNAME"   -a "$4" != "copyOnRAM"  -a "$4" != "SHARES" -a "$4" != "SITESCOUNTRY" -a "$4" != "SITESORGSERV" -a "$4" != "SITESEMAIL" -a "$4" != "ADMINNAME" ]  # TODO: sacar esta comprobaci�n a una func.
	 then
	 echo "getVar: no permission to read var $4" >>$LOGFILE 2>>$LOGFILE
	 exit 1
     fi

     getVar "$3" "$4" aux

     echo -n $aux

     exit 0
 fi

fi
















######################## Operations #######################



#Launch a root shell for maintenance purposes
if [ "$1" == "rootShell" ] 
then
    export TERM=linux        
    exec /bin/bash
    exit 1
fi




# Lists usb drives or mountable partitions, returns either list of drives/partitions or the number of them
#2 -> mode: 'devs' to list devices or 'parts' to list mountable partitions
#3 -> operation: 'list' to get list of devs/partitions and 'count' to get the number of them
if [ "$1" == "listUSBDrives" ] 
then
    
    if [ "$2" == "devs" ] ; then
        mode='devs'
    elif [ "$3" == "parts" ] ; then
        mode='valid'
    else
        echo "listUSBDrives: bad mode: $2" >>$LOGFILE 2>>$LOGFILE
        exit 1
    fi
    
    usbs=$(listUSBS $mode)
    nusbs=$?
    
    if [ "$3" == "list" ] ; then
        echo $usbs
    elif [ "$3" == "count" ] ; then
        echo $nusbs
    else
        echo "listUSBDrives: bad op: $3" >>$LOGFILE 2>>$LOGFILE
        exit 1
    fi
    
    exit 0
fi


#Lists hard drive partitions.
#2 -> 'all': (default) Show all partitions
#     'wfs': Show only partitions with a filesystem that can be mounted and written
#3 -> 'list': (default) show only the list
#     'fsinfo': return a field with filesystem and size info
#Returns: number of partitions found
#Stdout: list of partitions
if [ "$1" == "listHDDPartitions" ] 
then
    listHDDPartitions "$2" "$3"
    exit $?
fi

















#Handles mounting or umounting of USB drive partitions
#2 -> 'mount' or 'umount'
#3 -> [on mount only] partition path (will be checked against the list of valid ones)
if [ "$1" == "mountUSB" ] 
then
    
    #Umount doesn't need parameters
    if [ "$2" == "umount" ] ; then
        sync
        umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	       if [ "$?" -ne "0" ] ; then
            echo "mountUSB: Partition '$3' umount error" >>$LOGFILE 2>>$LOGFILE
            exit 1
        fi
        exit 0
    fi
    
    #Check if dev to mount is appropiate
    if [ "$3" == "" ] ; then
        echo "mountUSB: Missing partition path" >>$LOGFILE 2>>$LOGFILE
        exit 1
    fi   
    usbs=$(listUSBS valid)
    found=0
    for part in $usbs ; do
        [ $part == "$3" ] && found=1 && break
    done
    if [ "$found" -eq 0 ] ; then
        echo "mountUSB: Partition path '$3' not valid" >>$LOGFILE 2>>$LOGFILE
        exit 1
    fi

    #Do the mount
    if [ "$2" == "mount" ] ; then
        mount  "$3" /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	       if [ "$?" -ne "0" ] ; then
            echo "mountUSB: Partition '$3' mount error" >>$LOGFILE 2>>$LOGFILE
            exit 1
        fi
    else
        echo "mountUSB: Bad op code: $2" >>$LOGFILE 2>>$LOGFILE  
        exit 1
    fi
    
    exit 0
fi
















































#//// verif en mant: no

if [ "$1" == "shutdownServer" ] 
    then

# 2-> h --> halt r --> reboot default--> halt
shutdownServer(){
    
    
    echo "System $HOSTNM is going down on $(date)" | mail -s "System $HOSTNM shutdown" root
    sleep 3
    
    
    #Apagar el mysql y el apache (porque bloquean el acceso a la partici�n)
    /etc/init.d/apache2 stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/postfix stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/mysql   stop  >>$LOGFILE 2>>$LOGFILE  

    
    getVar usb DRIVEMODE
    getVar mem CRYPTDEV
    umountCryptoPart "$DRIVEMODE" "$MOUNTPATH" "$MAPNAME" "$DATAPATH" "$CRYPTDEV"

    rm -rf /tmp/*
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



# TODO  Hacer que los keyscan y el almacenamiento de claves sea op de root sin verif. asegurarme de que s�lo es el root quien ejecuta los backups. --> PARA PODER ACEPTAR ESTO, NO DEBE RECIBIR PARAMS VARIABLES. HACER ESTA OP GENERALISTA CON VERIF Y HACER OTRA QUE ACCEDA A LOS VALORES DE SSHBAK A LAS VARIABLES. cambiar las invocaciones por las de la sin params (y si no, hacer esta sin params y basta. ver tb el fichero backup.sh ).

#Scans a ssh server key and trusts it
#2 -> SSH server address
#3 -> SSH server port
if [ "$1" == "trustSSHServer" ] 
then
    
    sshScanAndTrust "$2" "$3"
    ret=$?
    
    echo "Keyscan returned: $ret" >>$LOGFILE 2>>$LOGFILE
    exit $ret
fi













    












#Formats or loads an encrypted drive, for persistent data
#storage. Either a physical drive partition or a loopback filesystem
# 2 -> either formatting a new system ('new') or just reloading it ('reset')
if [ "$1" == "configureCryptoPartition" ] 
then
    
    if [ "$2" != 'new' -a "$2" != 'reset' ]
    then 
        echo "configureCryptoPartition: param ERR: 2=$2"   >>$LOGFILE 2>>$LOGFILE
        exit 1
    fi

    #Load needed configuration variables
    getVar usb DRIVEMODE
    
    getVar usb DRIVELOCALPATH
    
    getVar usb FILEPATH    
    getVar usb FILEFILESIZE
    getVar usb CRYPTFILENAME
    
    configureCryptoPartition  "$2" "$DRIVEMODE" "$FILEPATH" "$CRYPTFILENAME" "$MOUNTPATH" "$DRIVELOCALPATH" "$MAPNAME" "$DATAPATH" 
    [ $? -ne 0 ] && exit $?
    
    #If everything went well, store a memory variable referencing the final mounted device
    setVar CRYPTDEV "$CRYPTDEV" mem
    
    #Setup permissions on the ciphered partition
    chmod 751  $DATAPATH  >>$LOGFILE 2>>$LOGFILE
    
    #If new,setup cryptoFS directories, with proper owners and permissions # TODO add here any new directories to persist
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
    
    exit 0
fi






#Umounts persistent data unit
#All parameters are either on the usb, memory or are constants  # TODO I think this op was meant for the inner key change, since we are dropping it, I believe it is not needed anymore (function is called only on the shutdown). At the end, review and if not used, delete
if [ "$1" == "umountCryptoPart" ] 
then
    
    getVar usb DRIVEMODE
    getVar mem CRYPTDEV
    
    umountCryptoPart "$DRIVEMODE" "$MOUNTPATH" "$MAPNAME" "$DATAPATH" "$CRYPTDEV"
    
    #Reset memory variable
    setVar CRYPTDEV "" mem
    
    exit 0
fi











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
    # TODO revisar esta func. Ya no son clauers, ya no hace falta dos aprts. Ve ris merge con la que particiona la unidad de datos
    
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

        # TODO  con HOSTNM Y DOMNAME los dos construir el fqdn y usarlo en el mailer

       #////borrar
       #checkParameterOrDie FQDN "${3}"  # TODO ver este fqdn de d�nde lo saco ahora. lopido en el form de mail? $HOSTNM + $DOMNAME
       #checkParameterOrDie MAILRELAY "${4}"


       getVar usb FQDN
       
       getVar disk MAILRELAY
       
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
              
       getVar disk MAILRELAY
       
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

       #Generar la contrase�a del usuario de la BD y guardarla en disco
       
       DBPWD=$(randomPassword 15)
       setVar DBPWD "$DBPWD" disk
       
       
       #Cambiar pwd del root por uno aleatorio y largo (solo al crearlo, que luego es persistente)
       MYSQLROOTPWD=$(randomPassword 20)
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
       

       getVar disk DBPWD
       getVar disk KEYSIZE
       getVar disk SITESORGSERV
       getVar disk SITESNAMEPURP

       #getVar disk EXCLUDEDNODE #Actualmente no se guarda
       

   
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
    pw=$(randomPassword)
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
      getVar disk WWWMODE
       
      
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

      setVar WWWMODE "ssl" disk # TODO extinguir esta variable



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
	mkdir -p /media/usbdrive  >>$LOGFILE 2>>$LOGFILE  # TODO now it is created once on boot. modify
	while [ "$pk10copied" -eq 0 ]
	  do
	  umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE # Lo desmontamos por si se ha quedado montado

	  insertUSB $"Inserte un dispositivo USB para almacenar la petici�n de certificado y pulse INTRO.\n(Puede ser uno de los Clauer que acaban de emplear)" "none"

	  #intentar montar la part 1 del DEV. # TODO ahora devuelve directamente la partici�n, hay que mirar el ret de la func para ver si es part o dev (en cuyo caso debe dar error porque seria un dev sin particiones montables)
	  part="$DEV""1"
	  #echo "DEv: $DEV"
	  mount  $part /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	  ret=$?
	  if [ "$ret" -ne "0" ]
	      then
	      $dlg --yes-label $"Otro" --no-label $"Formatear"  --yesno $"Este dispositivo no es v�lido. �Desea insertar otro o prefiere formatear este?" 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      $dlg --yes-label $"Otro" --no-label $"Formatear" --yesno $"�Seguro que desea formatear? Todos los datos SE PERDER�N." 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE  # Lo desmontamos antes de formatearlo
	      $dlg --infobox $"Formateando dispositivo..." 0 0 
	      ret=$($PVOPS formatearUSB "$DEV")
	      [ "$ret" -ne 0 ] && continue
	      mount  $part /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	  fi
	  echo "a" > /media/usbdrive/testwritability 2>/dev/null
	  ret=$?
	  if [ "$ret" -ne "0" ]
	      then
	      $dlg --yes-label $"Otro" --no-label $"Formatear"  --yesno $"Este dispositivo es de s�lo lectura. �Desea insertar otro o prefiere formatear este?" 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      $dlg --yes-label $"Otro" --no-label $"Formatear" --yesno $"�Seguro que desea formatear? Todos los datos SE PERDER�N." 0 0
	      ret=$?
	      [ $ret -eq 0 ] && continue # Elegir otro
	      umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE  # Lo desmontamos antes de formatearlo
	      $dlg --infobox $"Formateando dispositivo..." 0 0 
	      ret=$($PVOPS formatearUSB "$DEV")
	      [ "$ret" -ne 0 ] && continue
	      mount  $part /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	  else
	      rm -f /media/usbdrive/testwritability
	  fi
	  
	  #Es correcta. Escribimos el pk10
	  $dlg --infobox $"Escribiendo petici�n de certificado..." 0 0 
	  tries=10
	  while  [ $pk10copied -eq 0 ]
	    do
	    cp -f "$1" /media/usbdrive/server.csr  >>$LOGFILE 2>>$LOGFILE
	    
	    #A�adimos, junto a la CSR, un Readme indicando las instrucciones
	    cp -f /usr/share/doc/eLectionLiveCD-README.txt.$LANGUAGE  /media/usbdrive/VTUJI-README.txt
	    
	    if [ -s  "/media/usbdrive/server.csr" ] 
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
	  
	  umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE

	  #TODO get these messages out of here or decide on how to handle i18n
	  detectUsbExtraction $DEV $"Petici�n de certificado escrita con �xito.\nRetire el dispositivo y pulse INTRO." $"No lo ha retirado. H�galo y pulse INTRO."

	done
	rmdir /media/usbdrive  >>$LOGFILE 2>>$LOGFILE




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




#Operations related to the usb secure storage system and the
#management of the shared keys and configuration info.
if [ "$1" == "storops" ]
then

    if [ "$2" == "" ] ; then
	       echo "ERROR storops: No op code provided"  >>$LOGFILE 2>>$LOGFILE
	       exit 1
    fi
    echo "Called store operation $2..." >>$LOGFILE 2>>$LOGFILE
    
    
    
    
    #Init persistent key slot management data
    if [ "$2" == "init" ] 
	   then
        #Start on slot 1
	       for i in $(seq $SHAREMAXSLOTS)
	       do
	  	    	   mkdir -p "$ROOTTMP/slot$i"  >>$LOGFILE 2>>$LOGFILE
	           chmod 600 "$ROOTTMP/slot$i"  >>$LOGFILE 2>>$LOGFILE
	           resetSlot "$i"
        done
	       
	       CURRENTSLOT=1
	       setVar CURRENTSLOT "$CURRENTSLOT" mem
	       
	       exit 0
    fi
    
    
    
    
    #Reset currently active slot. 
    if [ "$2" == "resetSlot" ] 
	   then
        getVar mem CURRENTSLOT
	       
	       resetSlot $CURRENTSLOT
        exit $?
    fi
    
    
    
    
    #Reset all slots. 
    if [ "$2" == "resetAllSlots" ] 
	   then
        for i in $(seq $SHAREMAXSLOTS)
	       do
	          resetSlot "$i"
	       done
	       
	       exit 0
    fi
    
    
    
    
    
    
    #Check if the key in the active slot matches the drive's ciphering
    #password (so, those who added their shares are part of the
    #legitimate key holding commission)
    if [ "$2" == "checkClearance" ] 
	   then
	       getVar mem CURRENTSLOT
        
	       checkClearance $CURRENTSLOT #TODO revisar
	       ret="$?"
	       
	       exit $ret
    fi
    
    
    
    
    
    
    #Switch active slot
    #3-> which will be the new active slot
    if [ "$2" == "switchSlot" ] 
	   then
	       
	       checkParameterOrDie INT "${3}" "0"
	       if [ "$3" -gt $SHAREMAXSLOTS -o  "$3" -le 0 ]
	       then
	           echo "switchSlot: Bad slot number: $3"  >>$LOGFILE 2>>$LOGFILE
	           exit 1
	       fi
        
	       setVar CURRENTSLOT "$3" mem
	       exit 0
    fi
    
    
    
    
    
    
    #Tries to rebuild a key with the available shares on the current
    #slot, single attempt
    if [ "$2" == "rebuildKey" ] 
	   then
	       getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
                
	       numreadshares=$(ls $slotPath | grep -Ee "^keyshare[0-9]+$" | wc -w)
        
        #Rebuild key and store it (it expects a set of files named
        #keyshare[0-9]+, starting from zero until the specified
        #number - 1)
	       $OPSEXE retrieve $numreadshares $slotPath  2>>$LOGFILE > $slotPath/key
	       exit $? 
	   fi
    
    
    
    
    
    
    #Tries to rebuild a key with the available shares on the current
    #slot, will try all available combinations
    if [ "$2" == "rebuildKeyAllCombs" ] 
	   then
		      getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/

        getVar usb THRESHOLD	
	       numreadshares=$(ls $slotPath | grep -Ee "^keyshare[0-9]+$" | wc -w)
        
        echo "rebuildKeyAllCombs:"  >>$LOGFILE 2>>$LOGFILE
	       echo "Threshold:     $THRESHOLD"  >>$LOGFILE 2>>$LOGFILE
	       echo "numreadshares: $numreadshares"  >>$LOGFILE 2>>$LOGFILE
	       
        #If no threshold, something must be very wrong on the cinfig 
        [ "$THRESHOLD" == "" ] && exit 10
        
        #If not enough read shares, can't go on
        [ "$THRESHOLD" -gt "$numreadshares" ] && exit 11
        
        
        #Create temporary dir for the combinations
	       mkdir -p $slotPath/testcombdir  >>$LOGFILE 2>>$LOGFILE
	       
	       #Calculate all possible combinations
	       combs=$(/usr/local/bin/combs.py $THRESHOLD $numreadshares)
        echo "Number of combinations: "$(echo $combs | wc -w)  >>$LOGFILE 2>>$LOGFILE
        
        #Try to rebuild with each combination
	       gotit=0
	       for comb in $combs
	       do
            
            #The rebuild tool needs the shares to be named
            #sequentially, so we copy each share of the combination to
            #a temp location and name them as needed
	           poslist=$(echo "$comb" | sed "s/-/ /g")
	           offset=0
	           for pos in $poslist
	           do
                echo "copying keyshare$pos to $slotPath/testcombdir named keyshare$offset"  >>$LOGFILE 2>>$LOGFILE
	               cp -f $slotPath/keyshare$pos $slotPath/testcombdir/keyshare$offset
	               offset=$((offset+1))
            done
	           
            #Try to rebuild key and store it
	           $OPSEXE retrieve $THRESHOLD $slotPath/testcombdir  2>>$LOGFILE > $slotPath/key
	           stat=$? 
	           
	           #Clean temp dir
	           rm -f $slotPath/testcombdir/*  >>$LOGFILE 2>>$LOGFILE
	           
            #If successful, we are done
	           [ $stat -eq 0 ] && gotit=1 && break 
	       done
        
        #Delete temp dir
	       rm -rf  $slotPath/testcombdir  >>$LOGFILE 2>>$LOGFILE
	       
        #If no combination was successful, return error.
        [ $gotit -ne 1 ] && return 1
        
	       return 0	
    fi
    
    
    
    
    
    
    
    
    #Check if any share is corrupt. We rebuild key with N sets of
    #THRESHOLD shares, so the set of all the shares is covered. Every
    #rebuilt key is compared with the previous one to grant they are
    #the same.
    if [ "$2" == "testForDeadShares" ] 
	   then
    	   getVar mem CURRENTSLOT
        getVar usb THRESHOLD
        
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
        [ "$THRESHOLD" == "" ] && exit 2
        [ "$CURRENTSLOT" == "" ] && exit 2
        
        #Get list of shares on the active slot
        echo "testForDeadShares: Available shares: "$(ls -l  $slotPath 2>>$LOGFILE )   >>$LOGFILE 2>>$LOGFILE    
        sharefiles=$(ls "$slotPath/" | grep -Ee "^keyshare[0-9]+$")
        numsharefiles=$(echo $sharefiles 2>>$LOGFILE | wc -w)
        
        #If no shares
        if [ "$sharefiles" == ""  ] ; then
            echo "Error. No shares found" >>$LOGFILE 2>>$LOGFILE
            exit 1
        fi
        
        #If not enough shares
        [ "$THRESHOLD" -gt "$numsharefiles" ] && exit 3

        
        mkdir -p $ROOTTMP/testdir >>$LOGFILE 2>>$LOGFILE
        LASTKEY=""
        CURRKEY=""
        count=0
        failed=0
        #For each share
        while [ "$count" -lt "$numsharefiles"  ]
        do
            #Clean test dir
            rm -f $ROOTTMP/testdir/* >>$LOGFILE 2>>$LOGFILE
            
            #Calculate which share numbers to use
            offset=0
            while [ "$offset" -lt "$THRESHOLD" ]
	           do
	               pos=$(( (count+offset)%numsharefiles ))

                #Copy keyshare to the test dir [rename it so they are correlative]
                echo "copying keyshare$pos to $ROOTTMP/testdir named $ROOTTMP/testdir/keyshare$offset"  >>$LOGFILE 2>>$LOGFILE
	               cp $slotPath/keyshare$pos $ROOTTMP/testdir/keyshare$offset   >>$LOGFILE 2>>$LOGFILE
	                   
	               offset=$((offset+1))
            done
            echo "Shares copied to test directory: "$(ls -l  $ROOTTMP/testdir)   >>$LOGFILE 2>>$LOGFILE
            
            #Rebuild cipher key and store it on the var. 
            CURRKEY=$($OPSEXE retrieve $THRESHOLD $ROOTTMP/testdir  2>>$LOGFILE)
            #If failed, exit.
            [ $? -ne 0 ] && failed=1 && break
            
            echo "Could rebuild key"  >>$LOGFILE 2>>$LOGFILE
            
            #If key not matching the previous one, exit      
            [ "$LASTKEY" != "" -a "$LASTKEY" != "$CURRKEY"   ] && failed=1 && break
            
            echo "Matches previous"  >>$LOGFILE 2>>$LOGFILE
            
            #Shift current key
            LASTKEY="$CURRKEY"
            
            #Next rebuild will start from the next to the last used now
            count=$(( count + THRESHOLD ))
        done
        
        #Remove directory, to avoid leaving sensitive data behind
        rm -rf $ROOTTMP/testdir >>$LOGFILE 2>>$LOGFILE
        
        echo "found deadshares? $failed" >>$LOGFILE 2>>$LOGFILE
        
        exit $failed
    fi
    







#SEGUIR revisando desde aqu�





    #//// Esta op no estar� disponible en standby (la config solo se lee en new y reset). Ver qu� ops no debo permitir ejecutar y marcarlas..


    
    #Compare last read config with the one considered the correct one  # TODO move to setup instead of ops? readnextusb 'b' or 'c' is only called on startup/format 
    if [ "$2" == "compareConfigs" ] 
	   then
        
        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
	       NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	       lastConfigRead=$((NEXTCONFIGNUM-1))
        echo "***** #### NEXTCONFIGNUM:  $NEXTCONFIGNUM" >>$LOGFILE 2>>$LOGFILE
	       echo "***** #### lastConfigRead: $lastConfigRead" >>$LOGFILE 2>>$LOGFILE
        
	       keepCurrent=0
        
	       if [ "$lastConfigRead" -lt 0 ] ; then
	           echo "compareConfigs: No config files read yet" >>$LOGFILE 2>>$LOGFILE
	           exit 1;
	       fi
        
        #Only one has been read or this is the first comparison
	       if [ "$lastConfigRead" -eq 0 -o ! -s $slotPath/config.raw ] ; then
            #Set the first read config as the proper one
            parseConfigFile "$slotPath/config0" 2>>$LOGFILE > $slotPath/config
            #We also store a raw version of the read config block for comparison
		          cat $slotPath/config0 2>>$LOGFILE > $slotPath/config.raw
	       fi
        
        #Get the file differences
	       df=$( diff $slotPath/config$lastConfigRead  $slotPath/config.raw )
        #<DEBUG>
	       echo "***** diff for config files $lastConfigRead - config: $df" >>$LOGFILE 2>>$LOGFILE
        #</DEBUG>

        #Show differences to the user and let him decide
	       if [ "$df" != "" ]
		      then
		          echo -ne $"Current configuration:""\n"      > $slotPath/buff
		          echo -ne $"--------------------- \n\n"      >> $slotPath/buff
		          cat $slotPath/config.raw                    >> $slotPath/buff
		          echo -ne "\n\n\n"$"New Configuration:""\n"  >> $slotPath/buff
		          echo -ne $"--------------------- \n\n"      >> $slotPath/buff
		          cat  $slotPath/config$lastConfigRead        >> $slotPath/buff
		          echo -ne "\n\n\n"$"Differences:""\n"        >> $slotPath/buff
		          echo -ne $"--------------------- \n\n"      >> $slotPath/buff
            
		          $dlg --msgbox $"Found differences between the last configuration file and the previous ones. This is unexpected and should be carefully examined for tampering or corrution" 0 0
            
            $dlg --textbox $slotPath/buff 0 0
            
            $dlg --yes-label $"Current"  --no-label $"New"  --yesno  $"Do you wish to use the current one or the new one?" 0 0
            
            #Decide to keep current one
            [ "$?" -eq  0 ] && keepCurrent=1
		          echo "Keep current config?: $keepCurrent" >>$LOGFILE 2>>$LOGFILE
            
		          rm $slotPath/buff >>$LOGFILE 2>>$LOGFILE
	       fi
        
        #If user decided to use new one, update raw and parsed configuration files
	       if [ "$keepCurrent" -eq 0 ]
        then
	           #Store raw block for comparison
	           cat $slotPath/config$lastConfigRead 2>>$LOGFILE > $slotPath/config.raw
            
            #Parse and store the configuration
	           parseConfigFile "$slotPath/config$lastConfigRead" 2>>$LOGFILE > $slotPath/config
        fi
        exit 0
    fi
    
    
    
    
    
    #Validate structure of the last read config file
    if [ "$2" == "parseConfig" ] 
	   then
                
        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
	       NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	       lastConfigRead=$((NEXTCONFIGNUM-1))
	       echo "***** #### NEXTCONFIGNUM:  $NEXTCONFIGNUM" >>$LOGFILE 2>>$LOGFILE
	       echo "***** #### lastConfigRead: $lastConfigRead" >>$LOGFILE 2>>$LOGFILE
        
	       if [ "$NEXTCONFIGNUM" -eq 0 ]
	       then
	           echo "parseConfig: no configuration file read yet!"  >>$LOGFILE 2>>$LOGFILE
	           exit 1
	       fi
        
	       config=$(parseConfigFile "$slotPath/config$lastConfigRead" 2>>$LOGFILE)
	       
	       if [ "$config" == "" ]
	       then
	           echo "parseConfig: Configuration tampered or corrupted"  >>$LOGFILE 2>>$LOGFILE
	           exit 2
	       fi
	       
	       exit 0
    fi
    
    
    
    
    #Sets the configuration file from the slot as the working configuration file
    if [ "$2" == "settleConfig" ] 
	   then
                
        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
        #Move it to the root home
	       parseConfigFile "$slotPath/config" > $ROOTTMP/config
        
	       if [ ! -s "$ROOTTMP/config" ] ; then
	           echo "settleConfig: esurveyconfiguration parse error. Possible tampering or corruption"  >>$LOGFILE 2>>$LOGFILE
	           exit 1
	       fi
        exit 0
    fi
    

    

    

    #SEGUIR
    

 

    #Check if password is valid for a store
    #3-> dev
    #4-> password    
    if [ "$2" == "checkPwd" ] 
	   then
        checkParameterOrDie DEV "${3}" "0"
        checkParameterOrDie DEVPWD "${4}" "0"
        
        $OPSEXE checkPwd -d "$3"  -p "$4"    2>>$LOGFILE #0 ok  1 bad pwd  #////PROBAR
	       exit $?
    fi
    
    
    
    #Reads a configuration block from the usb store
    #3-> dev
    #4-> password    
    if [ "$2" == "readConfigShare" ] 
	   then
        checkParameterOrDie DEV "${3}" "0"
        checkParameterOrDie DEVPWD "${4}" "0"              
        
        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
	       NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	       
	       $OPSEXE readConfig -d "$3"  -p "$4" >$slotPath/config$NEXTCONFIGNUM  2>>$LOGFILE	
	       ret=$?
        
        #If properly read, increment config copy number
	       if [ -s $slotPath/config$NEXTCONFIGNUM ] ; then
	           NEXTCONFIGNUM=$(($NEXTCONFIGNUM+1))
	           echo -n "$NEXTCONFIGNUM" > "$slotPath/NEXTCONFIGNUM"
        else
	           exit 42
	       fi
        
	       exit $ret
    fi
    
    
    #Read a key share block from the usb store
    #3-> dev
    #4-> password
    if [ "$2" == "readKeyShare" ] 
	   then
        checkParameterOrDie DEV "${3}" "0"
        checkParameterOrDie DEVPWD "${4}" "0"
        
        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
        NEXTSHARENUM=$(cat "$slotPath/NEXTSHARENUM")
        
	       $OPSEXE readKeyShare -d "$3" -p "$4" >$slotPath/keyshare$NEXTSHARENUM  2>>$LOGFILE
	       ret=$?
        
        #If properly read, increment share number
	       if [ -s $slotPath/keyshare$NEXTSHARENUM ] ; then
	           NEXTSHARENUM=$(($NEXTSHARENUM+1))
	           echo -n "$NEXTSHARENUM" > "$slotPath/NEXTSHARENUM"
	       else
	           exit 42
	       fi
        
	       exit $ret
    fi
    


    #3-> dev
    #4-> password   
    # 5 -> El n�mero de share que debe escribir:
    if [ "$2" == "writeKeyShare" ] 
	   then
	       
	       getVar usb SHARES
        checkParameterOrDie DEV "${3}" "0"
        checkParameterOrDie DEVPWD "${4}" "0"
	       
	       # $5 debe ser un int
	       checkParameterOrDie INT "${5}" "0"


        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
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




    # TODO revisar
    #Writes the usb config file (the one settled and being edited
    #during operation, not one from a slot) to a device
    #3-> dev
    #4-> password      
    if [ "$2" == "writeConfig" ] 
	   then

        checkParameterOrDie DEV "${3}" "0"
        checkParameterOrDie DEVPWD "${4}" "0"
        
	       file="$ROOTTMP/config"	
		      
	       if [ -s "$file" ]
	       then
	           :
	       else
	           echo "writeConfig: No config to write!"  >>$LOGFILE 2>>$LOGFILE
	           exit 1
	       fi

	       config=$(cat "$file" 2>>$LOGFILE)  ## TODO ???


	       echo -e "CHECK1: cfg:  --" >>$LOGFILE 2>>$LOGFILE  # TODO Only in debug
        #<DEBUG>
	       cat "$file" >>$LOGFILE 2>>$LOGFILE #*-*- verificar que lo que imprimia era por esto. quitar este cat en prod.
        #</DEBUG>
	       echo "--" >>$LOGFILE 2>>$LOGFILE

	       #Escribimos las vars de config que deben guardarse en el clauer
	       cat "$file" | $OPSEXE writeConfig -d "$3"  -p "$4" 2>>$LOGFILE
	       ret=$?

	       exit $ret
    fi
    




    # *-*-
    #Comprueba si la clave reconstruida en el slot activo es la correcta. # TODO esto no estaba ya m�s arriba? verificar si ya existem si se llama de otro modo o si es que falta c�digo. --> est� checkClearance, pero no s� si el uso de ambas es el mismo. buscar las llamadas a ambas
    if [ "$2" == "validateKey" ] 
	then
	    :
             getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
    fi



    # TODO falta operaci�n para cambiar password del store. revisar todas antes a ver
    # TODO puede faltar tb una func para formatear?

#readConfig(Share) --> devuelve el estado, pero el contenido lo vuelca  en un directorio inaccesible

#readKeyShare --> devuelve el estado, pero el contenido lo vuelca  en un directorio inaccesible

#getConfig  -> Devuelve la cadena de configuraci�n si todas las piezas le�das son coherentes. (las variables cr�ticas no las devuelve? ver d�nde las uso y si lo puedo encapsular todo en la parte d eservidor usando ficheros)


#//// Hacer interfaz de clops, de gesti�n de llaves y de gesti�n de variables.

#//// Cron para el tema de las claves que permanecen: Borrarlas autom�ticamente no es buena idea, porque a priori no conocemos la duraci�n de las sesiones de mantenimiento. Poner un cron que revise los slots de shares y avise al admin con un e-mail si llevan ah� m�s de 1 hora. Avisarle cada X horas hasta que se borren. Poner una entrada en el men� de standby que las borre.

#//// El programa de standby se matar� y arrancar� cada vez, empezando en el punto del men� (establecer las variables que necesite.


# //// Construir fichero de persistencia de variables en el tmp del root, para guardar valores entre invocaciones a privOps. El fichero de variables que se guarda en la part cifrada, ponerlo en el dir de root y gestionarlo desde priv ops (no devolver las variables cr�ticas.).


fi



#Generate a large cipher key and divide it in shares using Shamir's
#algorithm
#2 -> Number of total shares
#3 -> Minimum amount of them needed to rebuild
if [ "$1" == "genNfragKey" ] 
then
    
    #Chedck input parameters
    checkParameterOrDie SHARES "$2"
    checkParameterOrDie THRESHOLD "$3"
    if [ "$SHARES" -lt 2 -o "$SHARES" -lt "$THRESHOLD" ] ; then
        echo "Bad number of shares ($SHARES) or threshold ($THRESHOLD)"  >>$LOGFILE 2>>$LOGFILE
        exit 1
    fi
    
    #Get reference to the currently active slot, there we will fragment the key
    getVar mem CURRENTSLOT
    slotPath=$ROOTTMP/slot$CURRENTSLOT/
    
    #Generate a large (91 char) true random password (entropy source: randomsound)
	   PARTPWD=$(randomPassword)
	   
    #We used to clean the slot, but not anymore, as it might already
    #contain a ready to use configuration file.
	
    #Fragment the password
	   echo -n "$PARTPWD" >$slotPath/key
	   $OPSEXE share $SHARES $THRESHOLD  $slotPath <$slotPath/key >>$LOGFILE 2>>$LOGFILE 
	   ret=$?
	   echo "$OPSEXE share $SHARES $THRESHOLD  $slotPath <$slotPath/key" >>$LOGFILE 2>>$LOGFILE
	   
    exit $ret
fi




#Grant or remove privileged admin access to webapp
#2-> 'grant' or 'remove'
if [ "$1" == "grantAdminPrivileges" ] 
    then
    
    getVar disk DBPWD

    privilege=0 
    if [ "$2" == "grant" ] ; then
        # TODO el grant Con verificaci�n de llave
        privilege=1
    fi
    
    echo "giving/removing webapp privileges ($2)."  >>$LOGFILE 2>>$LOGFILE
    mysql -f -u election -p"$DBPWD" eLection 2>>/tmp/mysqlerr  <<EOF
update eVotDat set mante=$privilege;
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
    
    getVar mem copyOnRAM
    
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





#Create admin users, substitute admin user or update admin user credentials
# 2-> Operation: 'new', 'update' or 'replace'
# 3-> Username
# 4-> Web application password
# 5-> Full Name
# 6-> Personal ID number
# 7-> IP address
# 8-> Mail address
# 9-> Local password
if [ "$1" == "resetAdmin" ]
then
    if [ "$2" != "new" -a "$2" != "update" -a "$2" != "replace" ]
    then
	       echo "resetAdmin: Bad operation parameter $2" >>$LOGFILE 2>>$LOGFILE
	       exit 1
    fi
    
    checkParameterOrDie ADMINNAME   "${3}"
    checkParameterOrDie MGRPWD      "${4}"
    checkParameterOrDie ADMREALNAME "${5}"
    checkParameterOrDie ADMIDNUM    "${6}"
    checkParameterOrDie ADMINIP     "${7}"
    checkParameterOrDie MGREMAIL    "${8}"
    checkParameterOrDie LOCALPWD    "${9}"
    
    #Get database password
    getVar disk DBPWD
    
    #Get stored value for the admin username
    getVar disk ADMINNAME
    oldADMINNAME="$ADMINNAME"
    
    #Hash passwords for storage, for security reasons
	   MGRPWDSUM=$(/usr/local/bin/genPwd.php "$MGRPWD" 2>>$LOGFILE)
    
    #In any of the operations above, update local manager password (if any)
    if [ "$LOCALPWD" != "" ] ; then
        LOCALPWDSUM=$(/usr/local/bin/genPwd.php "$LOCALPWD" 2>>$LOGFILE)
        setVar disk LOCALPWDSUM "$LOCALPWDSUM"
    fi
    
    #Reset credentials of current admin (web app password and IP address)
    if [ "$2" == "reset" ]
	   then
        newIP= # TODO needed method to turn ip into number
        [ "$ADMINIP" == "" ] && 
        
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
