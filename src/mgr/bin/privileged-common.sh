#!/bin/bash
# Methods and global variables only common to all privileged scripts go here



###############
#  Constants  #
###############

OPSEXE=/usr/local/bin/ssOperations

#The base non-persistent directory for Root operation
ROOTTMP="/root"


#############
#  Globals  #
#############

#All root executed scripts will not give other permissions
umask 027  # TODO verificar cuando vuelva ainstalar de cero que los ficheros creados, tipo los logs, no tienen o+r


#############
#  Methods  #
#############





#Stop all system services (not handled by the init process)
stopServers () {
    /etc/init.d/apache2 stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/postfix stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/mysql   stop  >>$LOGFILE 2>>$LOGFILE  
}


#Performs a database query
#1 -> The query line
# Will read the DBPWD config variable
#STDOUT: If select, will print the results
#         * one row per line (so it always ends in \n)
#         * fields separated with tabs (\t)
#To separate fields (and remove terminator newlines) | cut -f "1" | tr -d "\n"
#Return 1 if error, 0 if OK
dbQuery () {
    
    
    if [ $# -le 0 -o "$1" == "" ] ; then
        log "dbQuery ERROR: empty query"
        return 1
    fi
    
    #Get the database password
    getVar disk DBPWD
    if [ "$DBPWD" == "" ] ; then
        log "dbQuery ERROR: empty database password"
        return 1
    fi
    
    #Clean the output and error buffers
    local response=''
    rm -f /root/dbQueryError   >>$LOGFILE 2>>$LOGFILE
    
    #Execute the query
    response=$(echo "$*" | mysql -f -u election -p"$DBPWD" eLection 2>/root/dbQueryError)
    local ret=$?
    
    #If there is error output, log it and mark error return
    local err=$(cat /root/dbQueryError)
    rm -f /root/dbQueryError   >>$LOGFILE 2>>$LOGFILE
    if [ "$err" != "" ] ; then
        log "Database Query error: $err"
        ret=1
    fi
    
    #<DEBUG>
    log "Query: $*"
    log "Response: $response"
    log "Return code: $ret"
    #</DEBUG>
    
    #Return result (delete the column headers line)
    echo "$response" | tail -n +2
    return $ret
}




#Get size of a certain filesystem
#1 -> name of the FS (see list below)
#STDOUT: size of the filesystem (in MB)
getFilesystemSize () {
    
    local size=""
    
    if [ "$1" == "aufsFreeSize" ] ; then
        size=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)
        
    elif [ "$1" == "cdfsSize" ] ; then
        size=$(du -s /lib/live/mount/rootfs/ | cut -f 1)
    fi
    
    echo -n $size
    return 0
}





#Remove everything from a slot and reset counters
#1 -> slot number
resetSlot () {
    
    log "Resetting slot $1"
    
    [ "$1" -lt 1 -o "$1" -gt $SHAREMAXSLOTS ] && return 1
    
    rm -rf $ROOTTMP/slot$1/*  >>$LOGFILE 2>>$LOGFILE  # TODO check that unquoting the path worked
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
    
    log "****setting var on file $file: '$1'"
    #<DEBUG>
    log "****setting var on file $file: '$1'='$2'"
    #</DEBUG>
    touch $file
    chmod 600 $file  >>$LOGFILE 2>>$LOGFILE


    #Check if var is defined in file
    local isvardefined=$(cat $file | grep -Ee "^$1")
    log "isvardef: $1? $isvardefined"

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
	       log "****variable '$2' not found in file '$file'."
        #</DEBUG>
	       return 1
    fi
    
    value=$(cat $file 2>>$LOGFILE  | grep -Ee "^\s*$2" 2>>$LOGFILE | sed -re "s/^.*$2=\"([^\"]*)\".*$/\1/g" 2>>$LOGFILE)
    export $destvar=$value
    #TODO Verificar que si no existe, no pasa nada.
    #<DEBUG>
    log "****getting var '$2' from file '$file': writing on var '$3' = $value"
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
        log "param OK: $1"  
        #<DEBUG>
	       log "param OK: $1=$2"  
        #</DEBUG>
	       if [ "$3" != "0" ]
	       then
	           export "$1"="$val"
	       fi
    else
        log "param ERR (exiting 1): $1"  
        #<DEBUG>
	       log "param ERR (exiting 1): $1=$2"  
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
    
    log "Directories:"
    log "$directorios"
    
    for direct in $directorios
    do
        
        local pfiles=$(ls -p $direct | grep -oEe "^.*[^/]$")
        local pds=$(ls -p $direct | grep -oEe "^.*[/]$")
        
        log "=== Dir $direct files: ==="
        log "$pfiles"
        log "=== Dir $direct dirs : ==="
        log "$pds"
        
        for pf in $pfiles
	       do
	           log "chmod $2 $direct/$pf" 
	           chmod $2 $direct/$pf  >>$LOGFILE 2>>$LOGFILE
        done
        
        for pd in $pds
	       do
	           log "chmod $3 $direct/$pd" 
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
#      'valid' : show partitions from usb devices that can be mounted and written
listUSBs  () {
    
    #List all usb drives
    # Sometimes, the device link on the 'by-id' can be left behind
    # after disconection. Double check if the device still exists on
    # the main path
    local devs1=$(ls /dev/disk/by-id/ | grep usb 2>>$LOGFILE)
    local devs2=''
    for f in $devs1 ; do
        #Get the device indicator
        local dv=$(realpath /dev/disk/by-id/$f)

        #If the device still exists [sometimes the ID links are
        #broken]
        if [ -e "$dv" ] ; then
            devs2="$devs2\n$dv"
        fi
    done
    
    #Also, two of these ID links may point to the same dev (the
    #formerly connected one and the current one) and generate
    #duplicates, so we delete them.
    local devs=$(echo -e $devs2 | sort | uniq | tr "\n" " ")
    
    #If we only want valid partitions
    local USBDEVS=""
    local count=0
    if [ "$1" == 'valid' ] ; then
        #Check all devices and partitions to be mountable
        for currdev in $devs
        do
            #Umount previous
            umount /mnt >>$LOGFILE 2>>$LOGFILE

            #Try to mount
            mount $currdev /mnt  >>$LOGFILE 2>>$LOGFILE
            [ $? -ne 0 ] && continue # Can't be mounted
            
            #Try to write a file
	           local testfile=testfile$(randomPassword 32)
            echo "test writability" > /mnt/$testfile 2>/dev/null
            [ $? -ne 0 ] && continue # Can't write
	           rm -f /mnt/$testfile
            
            #Mountable and writable, add to the list
            USBDEVS="$USBDEVS $currdev"
            count=$((count+1))
        done
        
        #Umount last
        umount /mnt >>$LOGFILE 2>>$LOGFILE
        
    else
        #Show only the devices, not partitions
        for currdev in $devs
        do
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
        if [ "$ret" -ne 0 ] ; then
            #Raid degraded, etc.
            return $ret
        fi
    fi
    
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
	       log "Preparing storage space..." 
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
        log "Error: no free loopback device" 
        return 1
    fi
    
    #Mount the file
    losetup /dev/${LOOPDEV}  $2  >>$LOGFILE 2>>$LOGFILE
    if [ $? -ne 0 ]  ; then
        log "Error: error $? returned while mounting loopback device" 
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
    [ "$mountpath" == "" ] &&  log "No param 6"   && return 1
    [ "$mapperName" == "" ] &&  log "No param 8"   && return 1
    [ "$exposedpath" == "" ] &&  log "No param 9"   && return 1
    
    
    #Get the partition encryption password (which is the shared key in the active slot)
    getVar mem CURRENTSLOT
    local keyfile="$ROOTTMP/slot$CURRENTSLOT/key"
    if [ -s  "$keyfile" ] 
    then
        :
    else
        log "Error: No rebuilt key in active slot!! ($CURRENTSLOT)" 
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
	       log "Encrypting storage area..." 
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
	       log "Creating filesystem..."
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
	       log "configureNetwork: Reading params from usb config file..."
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

    log "ipmode: $IPMODE"
    log "ipad: $IPADDR"
    log "mask: $MASK"
    log "gatw: $GATEWAY"
    log "dns : $DNS1"
    log "dns2: $DNS2"

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
	           log "Error: no eth interfaces available."  
	           return 11
	       fi
        
        #For each available eth interface, configure and check connectivity
	       local settledaninterface=0
	       for interface in $interfaces; do
            
	           #Set IP and netmask.
	           log "/sbin/ifconfig $interface $IPADDR netmask $MASK"
            /sbin/ifconfig "$interface" "$IPADDR" netmask "$MASK"  >>$LOGFILE 2>>$LOGFILE 
            
            #Set default gateway
	           log "/sbin/route add default gw $GATEWAY"
            /sbin/route del default                    >>$LOGFILE 2>>$LOGFILE
            /sbin/route add default gw "$GATEWAY"      >>$LOGFILE 2>>$LOGFILE 
	           
            #Set NameServers
	           echo -e "nameserver $DNS1\nnameserver $DNS2" > /etc/resolv.conf
	           
	           #Check interface connectivity. If found, settle
	           log "Checking connectivity on $interface..." 
	           ping -w 5 -q $GATEWAY  >>$LOGFILE 2>>$LOGFILE 
	           if [ $? -eq 0 ] ; then
                log "found conectivity on interface $interface"
                settledaninterface=1
                break
            fi
            #If no connectivity, disable (otherwise, there will be collisions)
	           /sbin/ifconfig "$interface" down  >>$LOGFILE 2>>$LOGFILE 
	           /sbin/ifconfig "$interface" 0.0.0.0  >>$LOGFILE 2>>$LOGFILE 
	       done
	       
	       if [ "$settledaninterface" -eq 0 ] ; then
	           log "Error: couldn't find any interface with connection to gateway"  
	           return 12
	       fi
        
	       
    else #IPMODE == dhcp
        
        #If there is not a dhcp established connection yet
        if !(ps aux | grep dhclient | grep -v grep >/dev/null) ; then
            
            #Perform DHCP negotiation
            dhclient >>$LOGFILE 2>>$LOGFILE
            if [ "$?" -ne 0 ]  ; then
	               log "Dhclient error."  
	               return 13
	           fi
        fi
        
        #Guess gateway address
        GATEWAY=$(/sbin/ip route | awk '/default/ { print $3 }')
    fi
    
    #Check gateway connectivity
    log "Trying ping on $GATEWAY"  
	   ping -w 5 -q $GATEWAY  >>$LOGFILE 2>>$LOGFILE 
	   if [ $? -ne 0 ] ; then
    	   log "Error: couldn't ping gateway ($GATEWAY) through any interface. Check connectivity" 
        return 14
    fi
    
    #Check Internet connectivity
    log "Trying ping on 8.8.8.8"  
	   ping -w 5 -q 8.8.8.8  >>$LOGFILE 2>>$LOGFILE 
	   if [ $? -ne 0 ] ; then
        return 15
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
	       log "configureHostDomain: Reading params from usb config file..."
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
    
    log "ipadd:  $IPADDR"
    log "host:   $HOSTNM"
    log "domain: $DOMNAME"
    
    
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
        #echo "$IPADDR $HOSTNM$DOMNAME $HOSTNM" >  /tmp/hosts.tmp  ## TODO aliasing to localhost, see if there's any problem
        echo "127.0.0.1 $HOSTNM$DOMNAME $HOSTNM" >  /tmp/hosts.tmp  
	       cat  /etc/hosts                        >> /tmp/hosts.tmp
	       mv   /tmp/hosts.tmp /etc/hosts
	   fi
    
    #Add IP to whitelist
    echo "$IPADDR" >> /etc/whitelist
    
    return 0
}





#Read a file and parse its contents as e-mails
#1 -> file path
#RETURN: 0 if OK 1 if error
#STDOUT: list of e-mails
parseEmailFile () {
    
    if [ ! -s "$1" ] ; then
        log "parse email file: File $1 not found or empty."
        return 1
    fi
    
    local emaillist=$(cat "$1")
	   for eml in $emaillist; do 
	       parseInput email "$eml"
	       if [ $? -ne 0 ] ; then
		          log "Bad e-mail address found: $eml. Aborting"
		          return 1
	       fi
	   done
    
    echo -n "$emaillist"
    return 0
}





#Performs the operations to configure the SSL certificate on Apache
#and Postfix
setupSSLcertificate () {
    
    #Set the permissions and ownership (yes, every time, just in case)
    chown root:ssl-cert $DATAPATH/webserver/server.key   >>$LOGFILE 2>>$LOGFILE
    chown root:root     $DATAPATH/webserver/server.crt   >>$LOGFILE 2>>$LOGFILE
    chown root:root     $DATAPATH/webserver/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
    chmod 640 $DATAPATH/webserver/server.key    >>$LOGFILE 2>>$LOGFILE
    chmod 644 $DATAPATH/webserver/server.crt    >>$LOGFILE 2>>$LOGFILE
    chmod 644 $DATAPATH/webserver/ca_chain.pem  >>$LOGFILE 2>>$LOGFILE
    
    #Link the files from the data drive to the system path
	   ln -s  $DATAPATH/webserver/server.key    /etc/ssl/private/server.key >>$LOGFILE 2>>$LOGFILE
	   ln -s  $DATAPATH/webserver/server.crt    /etc/ssl/certs/server.crt   >>$LOGFILE 2>>$LOGFILE
	   ln -s  $DATAPATH/webserver/ca_chain.pem  /etc/ssl/ca_chain.pem       >>$LOGFILE 2>>$LOGFILE
    
    #Postfix SMTP client requires CAs to be on the same file, se we create a special
    cp -f $DATAPATH/webserver/server.crt /etc/ssl/certs/server_postfix.crt    >>$LOGFILE 2>>$LOGFILE
    cat $DATAPATH/webserver/ca_chain.pem >> /etc/ssl/certs/server_postfix.crt 2>>$LOGFILE
    chmod 644 /etc/ssl/certs/server_postfix.crt                               >>$LOGFILE 2>>$LOGFILE
}





#Check if file contains one or more valid x509 certificates
#1 -> Path to the file containing the certificate(s) to be checked [no spaces]
#2 -> Set to 1 if only 1 certificate must be expected in the file (will fail if more than 1 found)
# RETURN: 0: Valid 1: Not valid
checkCertificate () {
    
    local ret=0
    
    local certFile="$1"
    if [ "$certFile" == "" -o ! -s "$certFile" ] ; then
        log "check certificate: can't find certificate file: $certFile"
        return 1
    fi
    
    #Separate certs in different files to test them separately
    #Writes the original path tailed by a sequence number [0-9]+
    /usr/local/bin/separateCerts.py "$certFile"
    ret=$?
	   [ $ret -eq 3 ] && log "Read error."
    [ $ret -eq 5 ] && log "Error: file contains no PEM certificates."
    if [ $ret -ne 0 ] ; then
	       log "Error processing certificate file." 
	       return 1
    fi
    local certlist=$(ls "$certFile".[0-9]*)
    local certlistlen=$(echo $certlist | wc -w)
    
    
    #If needed, check if there's a single certificate
    if [ "$2" != ""  -a  "$2" -eq 1 ] ; then
        
        if [ "$certlistlen" -ne 1 ] ; then
            log "Certificate file contains more than one certificate ($certlistlen)"
            rm -f $certlist  >>$LOGFILE 2>>$LOGFILE
            return 1
        fi
    fi
    
    
    #For each cert
    ret=0
    for cert in $certlist
    do
        #Check it is a x509 cert
        openssl x509 -text < "$cert"  >>$LOGFILE 2>>$LOGFILE
        if [ $? -ne 0 ] ; then 
	           log "Error: certificate $cert not a valid x509."
	           ret=1
        fi
        
        #Delete the test file
        rm -f "$cert"  >>$LOGFILE 2>>$LOGFILE
    done
    
    return $ret
}





getX509Subject () {
    openssl x509 -subject -in "$1" |
        head -n 1 | grep subject | sed -re "s/^subject= //g"
}


getX509Issuer () {
    openssl x509 -issuer -in "$1" |
        head -n 1 | grep issuer | sed -re "s/^issuer= //g"
}


getX509Fingerprint () {
    openssl x509 -sha256 -fingerprint -in "$1" |
        head -n 1 | grep Fingerprint | sed -re "s/^SHA256 Fingerprint=//g"
}





#Checks if a certificate is self-signed or not
#1 -> certificate path
#RETURN 1: self-signed 2: error 0:signed by other
isSelfSigned () {
    
    local subject=$(getX509Subject "$1")
    local issuer=$(getX509Issuer   "$1")
    
    if [ "$subject" == "" -o "$issuer" == "" ] ; then
        log "error extracting subject or issuer. certificate not right"
        return 2
    fi
    
    #If subject and issuer match, it must be self-signed
    if [ "$subject" == "$issuer" ] ; then
        return 1
    fi
    return 0
}





#Check whether a certificate belongs to a certain private key
#1 -> certificate path
#2 -> key path
# RETURN 0: They match  1: they don't
doCertAndKeyMatch () {
    
    #Compare modulus on the cert and on the priv key
	   local aa=$(openssl x509 -noout -modulus -in "$1" | openssl sha1)
	   local bb=$(openssl rsa  -noout -modulus -in "$2" | openssl sha1)
    
	   #If empty or not matching, the cert doesn't belong to the priv key
	   if [ "$aa" == "" -o "$aa" != "$bb" ] ; then
        return 1
	   fi
    
    return 0
}




#Check if a certificate is correct and if it has ssl purpose. If chain
#is supplied it also checks the trust chain.
# $1 -> Path to the certificate to verify
# $2 -> (optional) Path to the CA chain (to see if matching towards it)
#RETURN: 0: if valid  1: if not valid
verifyCert () {
    
    [ "$1" == "" ] && return 1
    
    local chain=""
    if [ "$2" != "" ] ; then
	       chain=" -untrusted $2 "
    fi
    
    local output=$(openssl verify -purpose sslserver \
                           -CApath /etc/ssl/certs/ \
                           $chain \
                           "$1" 2>&1  | grep -ie "error")
    
    log "openssl verify cert error output $output "
    
    #If no error string returned, it was validated
    [ "$output" != ""  ] && return 1
    
    return 0
    
}
