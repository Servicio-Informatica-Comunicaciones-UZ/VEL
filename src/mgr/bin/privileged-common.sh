#!/bin/bash
# Methods and global variables only common to all privileged scripts go here



###############
#  Constants  #
###############

OPSEXE=/usr/local/bin/eLectionOps  # TODO Ver si alguna operación es crítica, y hacerlo sólo root y cambiar esta var para que invoque al sudo --> Porque resulta absurdo que la func encargada de leer clauers y reconstruir claves pida la clave, claro. Si todo es legal para vtuji y este puede usarla, darle permisos de ejecución sin necesidad de que sea root.# //// Probar opsexe desde un terminal vtuji para asegurarme de que puede hacerlo todo siendo un usuario no privilegiado.  #--> Sólo accesible por el root (cambiar permisos) verificar que al final en setup no se usa o defihnir esta var en ambos sitios.

#Temp dirs for the privileged operations
ROOTTMP="/root/"
ROOTFILETMP=$ROOTTMP"/filetmp"
ROOTSSLTMP=$ROOTTMP"/ssltmp"






#############
#  Methods  #
#############



#Fatal error function. It is redefined on each script with the
#expected behaviour, for security reasons.
#$1 -> error message
systemPanic () {

    #Show error message to the user # TODO See if this dialog can be deleted. We would need an error message passback system to let the invoker script handle this. Leave for later
    $dlg --msgbox "$1" 0 0  # TODO should pass the message and let the panic be held 
    
    # TODO check if any privvars need to be destroyed after an operation, and add them here as well (as a failed peration may leave an unconsistent state)
    
    #Exit immediately the privileged operations script and return
    #control back to the user script
    exit 99
}


# TODO remove all dialogs from privileged scripts. At least from the ops and common, setup will be fine




#Remove everything from a slot and reset counters
#1 -> slot number
resetSlot () {
    
    [ "$1" -lt 1 -o "$1" -gt $SHAREMAXSLOTS ] && return 1
    
    rm -rf "$ROOTTMP/slot$1/*"  >>$LOGFILE 2>>$LOGFILE
	   echo -n "0" > "$ROOTTMP/slot$1/NEXTSHARENUM"
	   echo -n "0" > "$ROOTTMP/slot$1/NEXTCONFIGNUM"
    
    return 0
}
    





#Sets a config variable to be shared among invocations of privilegedOps
# $1 -> variable
# $2 -> value
# $3 (optional) -> Destination: 'disk' persistent disk;
#                               'mem' (default) or nothing if we want it in ram;
#                               'usb' if we want it on the usb config file;
#                               'slot' in the active slot configuration
setVar () {
    
    #Vars written on the ramdisk
    local file="$ROOTTMP/vars.conf" #mem   
    if [ "$3" == "disk" ]
	   then
        #Vars written on the encrypted drive
	       file="$DATAPATH/root/vars.conf"
    elif [ "$3" == "usb" ]
	   then
        #Vars written on the keysharing stores (the file being used for operation)
	       file="$ROOTTMP/config"
    elif [ "$3" == "slot" ]
	   then
        #Vars written on the keysharing stores (the file loaded on the currently active keybuilding slot)
	       getVar mem CURRENTSLOT
	       slotPath=$ROOTTMP/slot$CURRENTSLOT/
	       file="$slotPath/config"
    fi
    
    echo "****setting var on file $file: '$1'" >>$LOGFILE 2>>$LOGFILE
    #<DEBUG>
    echo "****setting var on file $file: '$1'='$2'" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    touch $file
    chmod 600 $file  >>$LOGFILE 2>>$LOGFILE


    #Check if var is defined in file
    local isvardefined=$(cat $file | grep -Ee "^$1")
    echo "isvardef: $1? $isvardefined" >>$LOGFILE 2>>$LOGFILE

    #If not, append
    if [ "$isvardefined" == "" ] ; then
	       echo "$1=\"$2\"" >> $file
    else
        #Else, substitute.
	       sed -i -re "s/^$1=.*$/$1=\"$2\"/g" $file
    fi
}


		
# $1 -> Where to read the var from 'disk' disk;
#                                  'mem' or nothing if we want it from volatile memory;
#                                  'usb' if we want it from the usb config file;
#                                  'slot' from the active slot's configuration
# $2 -> var name (to be read)
# $3 -> (optional) name of the destination variable
# if var is not found in file, the current value (if any) of the destination var is not modified.
getVar () {

    local file="$ROOTTMP/vars.conf" # mem
    if [ "$1" == "disk" ]
	   then
	       file="$DATAPATH/root/vars.conf"
    elif [ "$1" == "usb" ]
	   then
	       file="$ROOTTMP/config"
    elif [ "$1" == "slot" ]
	   then
	       getVar mem CURRENTSLOT
	       slotPath=$ROOTTMP/slot$CURRENTSLOT/
	       file="$slotPath/config"
    fi
    
    [ -f "$file" ] || return 1
    
    local destvar=$2
    [ "$3" != "" ] && destvar=$3
    
    if (parseConfigFile $file | grep -e "^$2" >>/dev/null 2>>$LOGFILE)
	   then
	       :
	   else
        #<DEBUG>
	       echo "****variable '$2' not found in file '$file'." >>$LOGFILE 2>>$LOGFILE
        #</DEBUG>
	       return 1
    fi
    
    value=$(cat $file 2>>$LOGFILE  | grep -e "$2" 2>>$LOGFILE | sed -re "s/$2=\"(.*)\"\s*$/\1/g" 2>>$LOGFILE)
    export $destvar=$value
    #TODO Verificar que si no existe, no pasa nada.
    #<DEBUG>
    echo "****getting var from file '$file': '$2' on var '$3' = $value" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    return 0 
}






#Check if a parameter fits the expected syntax or kill the process
#$1 -> variable: variable is uniquely recognized to belong to a data type
#$2 -> value:    to set in the variable if fits the data type
#$3 -> 0:           don't set the variable value, just check if it fits.
#      1 (default): set the variable with the value.
checkParameterOrDie () {
    
    local val=$(echo "$2" | sed -re "s/\s+//g")
    if [ "$val" == "" ]
	   then
	       return 0
    fi
    
    if checkParameter "$1" "$val"
	   then
        echo "param OK: $1"   >>$LOGFILE 2>>$LOGFILE
        #<DEBUG>
	       echo "param OK: $1=$2"   >>$LOGFILE 2>>$LOGFILE
        #</DEBUG>
	       if [ "$3" != "0" ]
	       then
	           export "$1"="$val"
	       fi
    else
        echo "param ERR (exiting 1): $1"   >>$LOGFILE 2>>$LOGFILE
        #<DEBUG>
	       echo "param ERR (exiting 1): $1=$2"   >>$LOGFILE 2>>$LOGFILE
        #</DEBUG>
	       exit 1
    fi
}





#Parse a configuration file, to ensure syntax is adequate
#1 -> filename
#STDOUT: the file, parsed and trimmed of forbidden lines. Empty string
#        if no line followed the allowed syntax
parseConfigFile () {    
    cat "$1" | grep -oEe '^[a-zA-Z][_a-zA-Z0-9]*?=("([^"$]|[\]")*?"|""|[^ "$]+)'
}








#Recursively set a different mask for files and directories
#$1 -> Base route
#$2 -> Octal perms for files
#$3 -> Octal perms for dirs
setPerm () {
    local directorios="$1 "$(ls -R $1/* | grep -oEe "^.*:$" | sed -re "s/^(.*):$/\1/")
    
    echo -e "Directories:\n $directorios"  >>$LOGFILE 2>>$LOGFILE

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












#Forces a time adjust based on the ntp server time
forceTimeAdjust () {
    
    #Force time adjust, system and hardware clocks
    /etc/init.d/openntpd stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/openntpd start >>$LOGFILE 2>>$LOGFILE
    ntpdate-debian  >>$LOGFILE 2>>$LOGFILE
    hwclock -w >>$LOGFILE 2>>$LOGFILE
}










#List of usb connected storage devices ( printed on stdout) and the number (return value)
#$1 -> 'devs'  : show all usb storage devices, not partitions (default)
#      'valid' : show partitions from usb devices that can be mounted
listUSBs  () {
    
    local USBDEVS=""
    local devs=$(ls /dev/disk/by-id/ | grep usb 2>>$LOGFILE)
    local count=0
    if [ "$1" == 'valid' ] ; then
        #Check all devices and partitions to be mountable
        for f in $devs
        do
            local currdev=$(realpath /dev/disk/by-id/$f)
            mount $currdev /mnt  >>$LOGFILE 2>>$LOGFILE
            if [ "$?" -eq 0 ] ; then
                USBDEVS="$USBDEVS $currdev"
                count=$((count+1))
                umount /mnt >>$LOGFILE 2>>$LOGFILE
            fi
        done
    else
        #Show only the devices, not partitions
        for f in $devs
        do
            local currdev=$(realpath /dev/disk/by-id/$f)
            if [ $(echo "$currdev" | grep -Ee "/dev/[a-z]+[0-9]+") ] ; then :
            else
                USBDEVS="$USBDEVS $currdev"
                count=$((count+1))
            fi
        done
    fi
    echo -n "$USBDEVS"
    return $count
}


#Lists all serial and parallel devices that are not usb
listHDDs () {   
    local drives=""
    
    local usbs=''
    usbs=$(listUSBs devs)

    for n in a b c d e f g h i j k l m n o p q r s t u v w x y z 
      do
      #All existing PATA drives are added
      drivename=/dev/hd$n 
      [ -e $drivename ] && drives="$drives $drivename"

      #All existing serial drives not conneted through USB are added
      drivename=/dev/sd$n
      for usb in $usbs
	     do
	         #If drive among usbs, ignore
	         [ "$drivename" == "$usb" ]   && continue 2
      done
      [ -e $drivename ] && drives="$drives $drivename"     
    done

    echo "$drives"
}


#If any RAID array, do an online check for health
checkRAIDs () {
    
    #Check if there are RAID volumes.
    mdadm --examine --scan --config=partitions >/tmp/mdadm.conf  2>>$LOGFILE
    
    if [ "$(cat /tmp/mdadm.conf)" != "" ] 
	   then
	       #Check RAID status
	       mdadm --detail --scan --config=/tmp/mdadm.conf >>$LOGFILE 2>>$LOGFILE
	       local ret=$?
        if ["$ret" -ne 0 ]
	       then
            #Raid degraded, etc.
            return $ret
        fi
    fi
    
    return 0
}












#Umount encrypted partition in any of the supported modes
#1 -> Partition acces mode "$DRIVEMODE"
#2 -> [May be empty string] Path where the dev containing the loopback file is mounted "$MOUNTPATH"
#3 -> Name of the mapper device where the encrypted fs is mounted "$MAPNAME"
#4 -> Path where the final partition is mounted "$DATAPATH"
#5 -> [May be empty string] Path to the loop dev containing the ciphered partition "$CRYPTDEV"
umountCryptoPart () {

    #Umount final route
    umount  "$4"

    #Umount encrypted filesystem
    cryptsetup luksClose /dev/mapper/$3 >>$LOGFILE 2>>$LOGFILE
    
    case "$1" in
        #If we were using a physical drive, nothing else to be done
	       "local" )
            :
	           ;;

		      #If using a loopback file filesystem
	       "file" )
	           losetup -d $5
	           umount $2   #Desmonta la partición que contiene el fichero de loopback
            ;;
	   esac
}








# SEGUIR, las de abajo quedan por revisar


#1 -> Path to the file containing the cert(s) to be checked
#2 -> mode: 'serverCert' verify a single ssl server cert (by itself and towards the priv key)
#           'certChain' verify a number of certificates (individually, not whether they form a valid cert chain)
#3 -> path to the private key (in serverCert mode)
checkCertificate () {

    [ "$1" == "" ] && echo "checkCertificate: no param 1" >>$LOGFILE  2>>$LOGFILE  && return 11
    [ "$2" == "" ] && echo "checkCertificate: no param 2" >>$LOGFILE  2>>$LOGFILE  && return 12
    [ "$2" == "serverCert" -a "$3" == "" ] && echo "checkCertificate: no param 3 at mode serverCert" >>$LOGFILE  2>>$LOGFILE  && return 13

    #Validate non-empty file
    if [ -s "$1" ] 
	   then
	       :
    else
	       echo "Error: empty file." >>$LOGFILE  2>>$LOGFILE 
	       return 14
    fi
    
    #Separate certs in different files for testing
    /usr/local/bin/separateCerts.py  "$1"
    ret=$?
	   
    if [ "$ret" -eq 3 ] 
	   then
	       echo "Read error." >>$LOGFILE  2>>$LOGFILE 
	       return 15
    fi
    if [ "$ret" -eq 5 ]  
	   then
	       echo "Error: file contains no PEM certificates." >>$LOGFILE  2>>$LOGFILE 
	       return 16
    fi
    if [ "$ret" -ne 0 ]  
	   then
	       echo "Error processing cert file." >>$LOGFILE  2>>$LOGFILE 
	       return 17
    fi
    
    certlist=$(ls "$1".[0-9]*)
    certlistlen=$(echo $certlist | wc -w)
    
    #If processing a server cert file, it must be alone
    if [ "$2" == "serverCert" -a  "$certlistlen" -ne 1 ]
	   then
	       echo "File should contain server cert only." >>$LOGFILE  2>>$LOGFILE 
	       return 18
    fi
    
    #For each cert
    for c in $certlist
    do      
        #Check it is a x509 cert
        openssl x509 -text < $c  >>$LOGFILE  2>>$LOGFILE
        ret=$?
        if [ "$ret" -ne 0  ] 
	       then 
	           echo "Error: certificate not valid." >>$LOGFILE  2>>$LOGFILE
	           return 19
        fi
        
        #If processing a server cert file, it must match with the private key
        if  [ "$2" == "serverCert" ] ; then
            #Compare modulus on the cert and on the priv key
	           aa=$(openssl x509 -noout -modulus -in $c | openssl sha1)
	           bb=$(openssl rsa  -noout -modulus -in $3 | openssl sha1)
            
	           #If not matching, the cert doesn't belong to the priv key
	           if [ "$aa" != "$bb" ]
	           then
	               echo "Error: no cert-key match." >>$LOGFILE  2>>$LOGFILE
	               return 20
	           fi
        fi
        
    done
    
    return 0
}




#Check purpose of a certificate (and trust if chain is supplied)
# $1 -> Certificate to verify
# $2 -> (optional) CA chain (to see if matching towards it)
# RET: 0: ok  1: error
verifyCert () {
    
    [ "$1" == "" ] && return 1
    
    if [ "$2" != "" ]
	   then
	       chain=" -untrusted $2 "
    fi
    
    iserror=$(openssl verify -purpose sslserver -CApath /etc/ssl/certs/ $chain  "$1" 2>&1  | grep -ie "error")
    
    echo $iserror  >>$LOGFILE 2>>$LOGFILE
    
    #If no error string, validated
    [ "$iserror" != ""  ] && return 1
    
    return 0
    
}





#1 -> 'new': setup new loopback device
#     'reset': load existing loopback device
#2 -> path where the loopback filesystem is/will be allocated
#3 -> size of the loopback file system (in MB)
#Return: (stdout) Path of the loopback device (/dev/loopX) where the fs has been mounted
manageLoopbackFS () {
    
    #If creating the device, fill FS with zeroes
    if [ "$1" == 'new' ]
	   then
	       echo "Preparing storage space..."  >>$LOGFILE 2>>$LOGFILE
        #Calculate number of 512 byte blocks will the fs have
	       local FILEBLOCKS=$(($3 * 1024 * 1024 / 512))
	       dd if=/dev/zero of=$2 bs=512 count=$FILEBLOCKS  >>$LOGFILE 2>>$LOGFILE
    fi
    
    #Choose a free loopback device where to mount the file
    local LOOPDEV=''
    for l in 0 1 2 3 4 5 6 7
    do
        losetup /dev/loop$l  >>$LOGFILE 2>>$LOGFILE
        [ $? -ne 0 ] && LOOPDEV=loop$l && break 
    done
    if [ "$LOOPDEV" == '' ]  ; then
        echo "Error: no free loopback device"  >>$LOGFILE 2>>$LOGFILE
        return 1
    fi
    
    #Mount the file
    losetup /dev/${LOOPDEV}  $2  >>$LOGFILE 2>>$LOGFILE
    if [ $? -ne 0 ]  ; then
        echo "Error: error $? returned while mounting loopback device"  >>$LOGFILE 2>>$LOGFILE
        return 1
    fi
    
    echo /dev/${LOOPDEV}
    return 0
}





#Configure access to ciphered data
#1 -> 'new': setup new ciphered device
#     'reset': load existing ciphered device
#2 -> drive mode, which method must be used to access the partition (local drive or loopback fs)
#3 -> filedev, dev to be mounted where the loopback file can be found
#4 -> filename, of the loopback file (if any)
#5 -> size of the loopback filesystem (in MB)
#6 -> mountpath, mount point of the partition where the loopback file can be located ($MOUNTPATH)
#7 -> localdev, partition to be encrypted on local mode
#8 -> mapperName, name of the mapped device over which the cryptsetup will be mounted  (any name)
#9 -> exposedpath, the final path of the device, where data can be accesed ($DATAPATH)
configureCryptoPartition () {
    
    local cryptdev=""

    local drivemode="$2"
    local filedev="$3"
    local loopbackFilename="$4"
    local filefilesize="$5"
    local mountpath="$6"
    
    local localdev="$7"
    
    local mapperName="$8"
    local exposedpath="$9"    
    [ "$mountpath" == "" ] &&  echo "No param 2"  >>$LOGFILE 2>>$LOGFILE  && return 1
    [ "$mapperName" == "" ] &&  echo "No param 3"  >>$LOGFILE 2>>$LOGFILE  && return 1
    [ "$exposedpath" == "" ] &&  echo "No param 4"  >>$LOGFILE 2>>$LOGFILE  && return 1
    
    
    #Get the partition encryption password (which is the shared key in the active slot)
    getVar mem CURRENTSLOT
    local keyfile="$ROOTTMP/slot$CURRENTSLOT/key"
    if [ -s  "$keyfile" ] 
    then
        :
    else
        echo "Error: No rebuilt key in active slot!! ($CURRENTSLOT)"  >>$LOGFILE 2>>$LOGFILE
        exit 1
    fi
    local PARTPWD=$(cat "$keyfile")
    
    
    #Create mount point
    mkdir -p $mountpath
    
    case "$drivemode" in 
        
	       "local" ) 
            #If encrypted device is a partition, just set it
            cryptdev="$localdev"
            ;;
        
        "file" ) 
	           #Mount the partition where the loopback file can be found
            mount $filedev $mountpath
	           [ $? -ne "0" ] &&  return 2            
	           cryptdev=$( manageLoopbackFS $1 "$mountpath/$loopbackFilename" $filefilesize )
	           [ $? -ne 0 ] && return 3
            ;;
        
        * )
            #Unknown mode
	           return 4
            ;;        
    esac
    
    #Once the base partition is available as a dev,we build/mount the encrypted fs
    if [ "$1" == 'new' ]
	   then
	       echo "Encrypting storage area..."  >>$LOGFILE 2>>$LOGFILE
	     	 cryptsetup luksFormat $cryptdev   >>$LOGFILE 2>>$LOGFILE  <<-EOF
$PARTPWD
EOF
        [ $? -ne 0 ] &&  return 5 #Error formatting encr part
    fi
    
    #Map the cryptoFS
    cryptsetup luksOpen $cryptdev $mapperName   >>$LOGFILE 2>>$LOGFILE <<-EOF
$PARTPWD
EOF
    [ $? -ne 0 ] &&  return 6 #Error mapping the encr part
    
    #Setup the filesystem inside the encrypted drive
    if [ "$1" == 'new' ]
	   then
	       echo "Creating filesystem..." >>$LOGFILE 2>>$LOGFILE
	       mkfs.ext4 /dev/mapper/$mapperName >>$LOGFILE 2>>$LOGFILE
	       [ $? -ne 0 ] &&  return 7
    fi
    
    #Mount cryptoFS (exposed as a mapped device) to a system mount path.
    mkdir -p $exposedpath 2>>$LOGFILE
    mount  /dev/mapper/$mapperName $exposedpath
    [ $? -ne 0 ] &&  return 8
    
    #If everything went fine, leave a copy of the password in a RAM file, so backups and op authorisation can be executed
    echo -n "$PARTPWD" > $ROOTTMP/dataBackupPassword
    chmod 400  $ROOTTMP/dataBackupPassword   >>$LOGFILE 2>>$LOGFILE
    
    #Return device path
    echo -n $cryptdev

    return 0
}
