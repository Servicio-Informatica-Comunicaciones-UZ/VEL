#!/bin/bash
# Methods and global variables only common to all privileged scripts go here



###############
#  Constants  #
###############

OPSEXE=/usr/local/bin/eLectionOps

#Temp dirs for the privileged operations
ROOTTMP="/root/"
ROOTFILETMP=$ROOTTMP"/filetmp"
ROOTSSLTMP=$ROOTTMP"/ssltmp"






#############
#  Methods  #
#############


# TODO try to extinguish. Should be a simple exit and movce all of the interface to the wizard. Split the operations.
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
    
    #Trim value # TODO: warning, this deletes all the spaces. If there's a freetext string, we are screwed-> changed to trim the ends of the string. see if anything unexpected si happening
    local val=$(echo "$2"  | sed -r -e "s/^\s+//g" -e "s/\s+$//g")
    
    #We accept an empty parameter
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
    
    return 0
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


#Will change the aliases database so root e-mails are redirected to
#the passed e-mail address
#1 -> e-mail address where notifications must be received
setNotifcationEmail () {
    sed -i -re "/^root:/ d" /etc/aliases
	   echo -e "root: $1" >> /etc/aliases 2>>$LOGFILE
	   /usr/bin/newaliases    >>$LOGFILE 2>>$LOGFILE
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
#Return: 0 if OK, != 0 if error
#Will set CRYPTDEV global variable.
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
        return 1
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
    
    #Return final encrypted device path (needed if using loopback to delete the loopback)
    CRYPTDEV="$cryptdev"
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






#Sets up the network configuration. Expects global variables with configuration:
# IPMODE
# IPADDR
# MASK
# GATEWAY
# DNS1
# DNS2
configureNetwork () {
    
    #If parameters are empty, read them from config
    if [ "$IPMODE" == "" ]
	   then
	       echo "configureNetwork: Reading params from usb config file..." >>$LOGFILE 2>>$LOGFILE
	       getVar usb IPMODE
	       getVar usb IPADDR
	       getVar usb MASK
	       getVar usb GATEWAY
	       getVar usb DNS1
	       getVar usb DNS2
   fi
    
    checkParameterOrDie IPMODE  "$IPMODE"  "0"
    checkParameterOrDie IPADDR  "$IPADDR"  "0"
    checkParameterOrDie MASK    "$MASK"    "0"
    checkParameterOrDie GATEWAY "$GATEWAY" "0"
    checkParameterOrDie DNS1    "$DNS1"    "0"
    checkParameterOrDie DNS2    "$DNS2"    "0"

    echo "ipmode: $IPMODE" >>$LOGFILE 2>>$LOGFILE
    echo "ipad: $IPADDR" >>$LOGFILE 2>>$LOGFILE
    echo "mask: $MASK" >>$LOGFILE 2>>$LOGFILE
    echo "gatw: $GATEWAY" >>$LOGFILE 2>>$LOGFILE
    echo "dns : $DNS1" >>$LOGFILE 2>>$LOGFILE
    echo "dns2: $DNS2" >>$LOGFILE 2>>$LOGFILE

    if [ "$IPMODE" == "static" ]
	   then
	       killall dhclient3 dhclient  >>$LOGFILE 2>>$LOGFILE 
	       
	       local interfacelist=$(cat /etc/network/interfaces | grep  -Ee "^[^#]*iface" | sed -re 's/^.*iface\s+([^\t ]+).*$/\1/g')
        #Switch all interfaces (except lo) to manual
	       for intfc in $interfacelist ; do
	           if [ "$intfc" != "lo" ] ; then
	               sed  -i -re "s/^([^#]*iface\s+$intfc\s+\w+\s+).+$/\1manual/g" /etc/network/interfaces
	           fi
	       done
	       
        #List eth interfaces (sometimes kernel may not set first interface to eth0)
	       local interfaces=$(/sbin/ifconfig -s  2>>$LOGFILE  | cut -d " " -f1 | grep -oEe "eth[0-9]+")
	       
	       if [ "$interfaces" == "" ] ; then
	           echo "Error: no eth interfaces available."  >>$LOGFILE 2>>$LOGFILE 
	           return 11
	       fi
        
        #For each available eth interface, configure and check connectivity
	       local settledaninterface=0
	       for interface in $interfaces; do
            
	           #Set IP and netmask.
	           echo "/sbin/ifconfig $interface $IPADDR netmask $MASK" >>$LOGFILE 2>>$LOGFILE
            /sbin/ifconfig "$interface" "$IPADDR" netmask "$MASK"  >>$LOGFILE 2>>$LOGFILE 
            
            #Set default gateway
	           echo "/sbin/route add default gw $GATEWAY">>$LOGFILE 2>>$LOGFILE
            /sbin/route del default
            /sbin/route add default gw "$GATEWAY"  >>$LOGFILE 2>>$LOGFILE 
	           
            #Set NameServers
	           echo -e "nameserver $DNS1\nnameserver $DNS2" > /etc/resolv.conf
	           
	           #Check interface connectivity. If found, settle
	           echo "Checking connectivity on $interface..."  >>$LOGFILE 2>>$LOGFILE
	           ping -w 5 -q $GATEWAY  >>$LOGFILE 2>>$LOGFILE 
	           if [ $? -eq 0 ] ; then
                echo "found conectivity on interface $interface" >>$LOGFILE 2>>$LOGFILE
                settledaninterface=1
                break
            fi
            #If no connectivity, disable (otherwise, there will be collisions)
	           /sbin/ifconfig "$interface" down  >>$LOGFILE 2>>$LOGFILE 
	           /sbin/ifconfig "$interface" 0.0.0.0  >>$LOGFILE 2>>$LOGFILE 
	       done
	       
	       if [ "$settledaninterface" -eq 0 ] ; then
	           echo "Error: couldn't find any interface with connection to gateway"  >>$LOGFILE 2>>$LOGFILE 
	           return 12
	       fi
        
	       
    else #IPMODE == dhcp
        
        #If there is not a dhcp established connection yet
        if !(ps aux | grep dhclient | grep -v grep >/dev/null) ; then
            
            #Perform DHCP negotiation
            dhclient >>$LOGFILE 2>>$LOGFILE
            if [ "$?" -ne 0 ]  ; then
	               echo "Dhclient error."  >>$LOGFILE 2>>$LOGFILE 
	               return 13
	           fi
            GATEWAY=$(/sbin/ip route | awk '/default/ { print $3 }')
        fi
    fi
    
    #Check gateway connectivity
	   ping -w 5 -q $GATEWAY  >>$LOGFILE 2>>$LOGFILE 
	   if [ $? -eq 0 ] ; then
    	   echo "Error: couldn't ping gateway ($GATEWAY) through any interface. Check connectivity"  >>$LOGFILE 2>>$LOGFILE
        return 14
    fi

    return 0
}



#Sets up the hostname, domain and hosts file parameters
# IPADDR
# HOSTNM
# DOMNAME
configureHostDomain () {
    
    #If parameters are empty, read them from config
    if [ "$HOSTNM" == "" ]
	   then
	       echo "configureHostDomain: Reading params from usb config file..." >>$LOGFILE 2>>$LOGFILE
	       getVar usb IPADDR
	       getVar usb HOSTNM
 	      getVar usb DOMNAME
    fi
    
    checkParameterOrDie IPADDR  "$IPADDR"  "0"
    checkParameterOrDie HOSTNM  "$HOSTNM"  "0"
    checkParameterOrDie DOMNAME "$DOMNAME" "0"

    #If no IP param (due to being set through DHCP), guess it
    if [ "$IPADDR" == "" ] ; then
        IPADDR=$(ifconfig | grep -Ee "eth[0-9]+" -A 1 \
                        | grep -oEe "inet addr[^a-zA-Z]+" \
                        | grep -oEe "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
    fi
    
    echo "ipadd:  $IPADDR" >>$LOGFILE 2>>$LOGFILE
    echo "host:   $HOSTNM" >>$LOGFILE 2>>$LOGFILE
    echo "domain: $DOMNAME" >>$LOGFILE 2>>$LOGFILE
    
    
    #Set the static, transient and pretty hostname
    hostnamectl set-hostname "$HOSTNM.$DOMNAME"

    #Set hostname
    hostname "$HOSTNM"
    echo "$HOSTNM" > /etc/hostname

    #Set domain
    nisdomainname "$DOMNAME"

    #Set host alias and FQDN
    if (cat /etc/hosts | grep "$IPADDR" 2>>$LOGFILE) ; then
        #If already there, substitute line
        sed -i -re "s/^$IPADDR.*$/$IPADDR $HOSTNM$DOMNAME $HOSTNM/g" /etc/hosts
 	  else
        #Add new line at the top
        echo "$IPADDR $HOSTNM$DOMNAME $HOSTNM" >  /tmp/hosts.tmp
	       cat  /etc/hosts                        >> /tmp/hosts.tmp
	       mv   /tmp/hosts.tmp /etc/hosts
	   fi
    
    #Add IP to whitelist
    echo "$IPADDR" >> /etc/whitelist
    
    return 0
}

