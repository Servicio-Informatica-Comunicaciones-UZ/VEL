#!/bin/bash


#This script contains all the actions that need to be executed by root
#during setup or during operation. They are invoked through
#calls. During setup they need no authorisation, but after that, they
#need to find a rebuilt key in order to be executed.



#### INCLUDES ####

#System firewall functions
. /usr/local/bin/firewall.sh

#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh




#Log function
log () {
    echo "["$(date --rfc-3339=ns)"][privileged-ops]: "$*  >>$LOGFILE 2>>$LOGFILE
}




#Make an entry on the operations log (also on the main log)
opLog () {
    echo "["$(date --rfc-3339=ns)"] $1." >>$OPLOG 2>>$OPLOG
    log "$1"
}




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
    log "Partitions for drive $1 ($nparts): $parts"  
    
    #Return
    echo -n "$parts"
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
    #must be listed (although the array will be destroyed). Also, 256
    #is the max range for the minor number
    for mdid in $(seq 0 256) ; do
        if [ -e /dev/md$mdid ] ; then
	           drives="$drives /dev/md$mdid"
        fi
    done
    
    log "ATA Drives found: $drives" 
        
    #For each drive
    local partitions=""
    local npartitions=0

    for drive in $drives
    do
        log "Checking: $drive" 
        
        #Get this drive's partitions
        local thisDriveParts='' # Local declaration sets the $? to 0 always, separate declaration from setting
        thisDriveParts=$(getPartitionsForDrive $drive)
        local thisDriveNParts=$?
        log "this drive $drive ($thisDriveNParts): $thisDriveParts" 
        
        
        #If any partitions found
        if [ "$thisDriveNParts" -gt 0 ] 
	       then
            #If all partitions are to be returned, add them
            if [ "$1" == "all" ] ; then
                partitions="$partitions $thisDriveParts"
                npartitions=$((npartitions+thisDriveNParts))
                log "Add all. Resulting partitions ($npartitions): $partitions" 
                
            #Show only writable partitions
            elif [ "$1" == "wfs" ] ; then
	               for part in $thisDriveParts
		              do
		                  if isFilesystemWritable $part
		                  then
                        partitions="$partitions $part"
                        npartitions=$((npartitions+1))
                        log "Add wfs. Resulting partitions ($npartitions): $partitions" 
                    fi
	               done
	           else
                log "list hdd partitions: Bad parameter $1" 
                return 255
	           fi
        fi
    done
    log "Partitions: "$partitions 
    
    #If only the list of partitios was requested, return it now
    if [ "$2" != "fsinfo" ] ; then
        echo "$partitions"
        return $npartitions
    fi
    
    #For each partition to be returned, get partition info (filesystem, size)
    local partitionsWithInfo=""
    local thisfs=''
    local thissize=''
    for part in $partitions
    do
        #Guess filesystem
	       thisfs=$(guessFS "$part")
        [ $? -ne 0 ] && thisfs="?"
        
        #Guess size of partition (and make it readable)
        thissize=$(guessPartitionSize "$part")
        if [ $? -ne 0 ] ; then thissize="?"
        else
            thissize=$(humanReadable "$thissize")
        fi
        #Add the return line fields: partition and info
        partitionsWithInfo="$partitionsWithInfo $part $thisfs|$thissize"
    done
    log "Partitions with info: $partitionsWithInfo" 
    
    echo "$partitionsWithInfo"
    return $npartitions
}





#Checks that there is a rebuilt key in the slot and checks if it
#matches the one used to cipher the disk drive
#1 -> Slot to check
#RETURN:  0: Key is valid
#         1: Key is non-existing or non-valid
checkClearance () {
    
    #Get the known key
    local base=$(cat $ROOTTMP/dataBackupPassword 2>>$LOGFILE)
    
    
    #Get the challenging key
    if [ ! -s $ROOTTMP/slot$1/key ] ; then
        log "checkClearance: No rebuilt key in slot"
	       return 1
    fi
    
    local chal=$(cat $ROOTTMP/slot$1/key 2>>$LOGFILE)
    
    if [ "$chal" == ""  ] ; then
        log "checkClearance: Empty key in slot"
	       return 1
    fi
    
    #Compare keys with the actual one
    if [ "$chal" != "$base"  ] ; then
        log "checkClearance: slot doesn't match actual key"
	       return 1
    fi
    
    return 0
}
# TODO see if it can be the same as verifykey, I guess on the other one we need to do a check all shares, like on the startup.











######################
##   Main program   ##
######################

opLog "Called operation $1"




##### Check if operations are locked or not #####

#If lock file does not exist, disallow
if [ ! -f "$LOCKOPSFILE" ] ; then
    log "ERROR: $LOCKOPSFILE file does not exist."  
    exit 1
fi

lockvalue=$(cat "$LOCKOPSFILE")
if [ "$lockvalue" -eq 0 ] 2>>$LOGFILE ; then
    opLog "Executing operation $1 without verification."
else
    
    #TODO Aquí implementar verificación de clauer. (llamar a checkClearance. cuando ejecute una innerkey reset es posible que deba comprobar ambos slots. implementar entonces si eso)  Si no existe un fichero que contenga la llave reconstruida (verificar llave frente a la part? puede ser muy costoso. en la func que la reconstruye, probarla, y si falla borrar el fichero).

    # TODO implementar tb la verificación de ops por passwd local del admin

    #TODO hay ops que nunca necesian verificación. listarlas y saltarse la comprobación.

    # TODO si hay ops que sólo se llaman durante el setup, mover al privileged-setup

    # TODO *************** Es emjor hacer esto o llamamos a la verificación concreta antes de cada op? en ese caso, la validación del lock pasaría a la función que comprueba el clearance
    log "["$(date --rfc-3339=ns)"] Checking clearance for operation $1."
fi



















#Set the value of the variable on the specified variable storage. Only
#some variables are allowed, the rest are for internal privileged
#script use only.
# $2 -> Destination: 'disk' persistent disk;
#                    'mem'  (default) or nothing if we want it in ram;
#                    'usb'  if we want it on the usb config file;
#                    'slot' in the active slot configuration
# $3 -> variable
# $4 -> value
if [ "$1" == "setVarSafe" ] 
then
    
    checkParameterOrDie "$3" "$4" 0  # TODO make sure that in all calls to this op, the var is in checkParameter.
    
    allowedVars=""     # TODO Define a list of variables that will be writable, once clearance is obtained
    
    if (! contains "$allowedVars" "$3") ; then
        log "Set access denied to variable $3. Not during operation, even with clearance"
        exit 1
    fi
    
    
    setVar "$3" "$4" "$2"
    exit 0
fi





#Get the value of the variable on the specified variable storage. Only
#some variables are allowed, the rest are for internal privileged
#script use only.
# $2 -> Destination: 'disk' persistent disk;
#                    'mem'  (default) or nothing if we want it in ram;
#                    'usb'  if we want it on the usb config file;
#                    'slot' in the active slot configuration
# $3 -> variable
if [ "$1" == "getVarSafe" ]
then
    
    allowedVars=""     # TODO Define a list of variables that will be writable, once clearance is obtained
    
    if (! contains "$allowedVars" "$3") ; then
        log "Get access denied to variable $3. Not during operation, even with clearance"
        exit 1
    fi
    
    
    getVar "$2" "$3" aux
    echo -n $aux
    exit 0
fi





#Get the value of the variable on the specified variable storage, but
#only for a closed list of variables that can be read on
#unprivileged situations.
# $2 -> Destination: 'disk' persistent disk;
#                    'mem'  (default) or nothing if we want it in ram;
#                    'usb'  if we want it on the usb config file;
#                    'slot' in the active slot configuration
# $3 -> variable
if [ "$1" == "getPubVar" ]
then
    # TODO Define list of public variables
    allowedVars="SSLCERTSTATE "
    
    if (! contains "$allowedVars" "$3") ; then
        log "Access denied to variable $3. Clearance needed."
        exit 1
    fi
    
    getVar "$2" "$3" aux
    echo -n $aux
    exit 0
fi  # TODO make this a free-op # TODO do we need a setPubVar? # TODO remember to implement the locking mechanism and the clearance mech.





#Launch a root shell for maintenance purposes
if [ "$1" == "rootShell" ] 
then
    export TERM=linux        
    exec /bin/bash
    exit 1 #Should not reach
fi





#Get size of a certain filesystem
#2 -> name of the FS
#STDOUT: size of the filesystem (in MB)
if [ "$1" == "getFilesystemSize" ] 
then
    getFilesystemSize "$2"
fi




# Lists usb drives or mountable partitions, returns either list of drives/partitions or the number of them
#2 -> mode: 'devs' to list devices or 'parts' to list mountable partitions
#3 -> operation: 'list' to get list of devs/partitions and 'count' to get the number of them
if [ "$1" == "listUSBDrives" ] 
then
    
    if [ "$2" == "devs" ] ; then
        mode='devs'
    elif [ "$2" == "parts" ] ; then
        mode='valid'
    else
        log "listUSBDrives: bad mode: $2"
        exit 1
    fi
    
    usbs=$(listUSBs $mode)
    nusbs=$?
    
    if [ "$3" == "list" ] ; then
        echo $usbs
    elif [ "$3" == "count" ] ; then
        echo $nusbs
    else
        log "listUSBDrives: bad op: $3"
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
    log "called listHDDPartitions '$2' '$3'"
    listHDDPartitions "$2" "$3"
    exit $?
fi





#Handles mounting or umounting of USB drive partitions
#2 -> 'mount' or 'umount'
#3 -> [on mount only] partition path (will be checked against the list of valid ones)
#Return: None. Mount path is a constant
if [ "$1" == "mountUSB" ] 
then
    
    #Umount doesn't need parameters
    if [ "$2" == "umount" ] ; then
        sync
        umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	       if [ "$?" -ne "0" ] ; then
            log "mountUSB: Partition '$3' umount error"
            exit 1
        fi
        exit 0
    fi
    
    #Check if dev to mount is appropiate
    if [ "$3" == "" ] ; then
        log "mountUSB: Missing partition path"
        exit 1
    fi   
    usbs=$(listUSBs valid)
    found=0
    for part in $usbs ; do
        [ $part == "$3" ] && found=1 && break
    done
    if [ "$found" -eq 0 ] ; then
        log "mountUSB: Partition path '$3' not valid"
        exit 1
    fi

    #Do the mount
    if [ "$2" == "mount" ] ; then
        mount  "$3" /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	       if [ "$?" -ne "0" ] ; then
            #Maybe the path is already mounted. Umount and retry
            umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	           if [ "$?" -ne "0" ] ; then
                log "mountUSB: Partition '$3' preemptive umount error device must be in use"
                exit 1
            fi
            #Try a second and last mount
            mount  "$3" /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
            if [ "$?" -ne "0" ] ; then
                log "mountUSB: Partition '$3' mount error"
                exit 1
            fi
        fi
    else
        log "mountUSB: Bad op code: $2"  
        exit 1
    fi
    
    exit 0
fi





#Configure network parameters
if [ "$1" == "configureNetwork" ] 
then
    IPMODE="$2"
    IPADDR="$3"
    MASK="$4"
    GATEWAY="$5"
    DNS1="$6"
    DNS2="$7"
    
    configureNetwork
    exit $?
fi





#Configure everything related to the hostname and domain name
if [ "$1" == "configureHostDomain" ] 
then
    IPADDR="$2"
    HOSTNM="$3"
    DOMNAME="$4"
    
    configureHostDomain
    exit $?
fi






#Halt or reboot system
if [ "$1" == "shutdownServer" ] 
then
    
    #Try to send an email notification
    getVar disk HOSTNM
    echo "System $HOSTNM is going down at $(date)" | mail -s "System $HOSTNM shutdown" root
    sleep 3
    
    #Stop services to unlock the data drive
    stopServers
    
    #Umount drive
    getVar usb DRIVEMODE
    getVar mem CRYPTDEV
    umountCryptoPart "$DRIVEMODE" "$MOUNTPATH" "$MAPNAME" "$DATAPATH" "$CRYPTDEV"
    
    #Clear temp directory
    rm -rf /tmp/*
    clear
    
    if [ "$2" == "h" ] ; then
	       halt
	       exit 1 #Should not reach
        
    elif [ "$2" == "r" ] ; then
	       reboot
	       exit 1 #Should not reach
    fi
    
    halt  #Should not reach
    exit 42  #Should not reach
fi





#TODO Esta No debe necesitar verif llave
#Suspend machine
if [ "$1" == "suspend" ]
then
    getVar mem copyOnRAM
    
    #If not copied on RAM, system could be tampered
    if [ "$copyOnRAM" -eq 0 ]
	   then
	       log "Cannot suspend if disc is not in ram"
	       exit 1 
    fi
    
    #Suspend
    pm-suspend
    
    #On waking, adjust time
    forceTimeAdjust
    
    exit 0
fi





#Stop all services
if [ "$1" == "stopServers" ] 
then
    stopServers 
    exit 0
fi





#Scans a ssh server key and trusts it
#2 -> SSH server address
#3 -> SSH server port
if [ "$1" == "trustSSHServer" ] 
then
    
    sshScanAndTrust "$2" "$3"
    ret=$?
    
    log "Keyscan returned: $ret"
    exit $ret
fi





#Formats or loads an encrypted drive, for persistent data
#storage. Either a physical drive partition or a loopback filesystem
# 2 -> either formatting a new system ('new') or just reloading it ('reset')
if [ "$1" == "configureCryptoPartition" ] 
then
    
    if [ "$2" != 'new' -a "$2" != 'reset' ]
    then 
        log "configureCryptoPartition: param ERR: 2=$2"  
        exit 1
    fi

    #Load needed configuration variables
    getVar usb DRIVEMODE
    
    getVar usb DRIVELOCALPATH
    
    getVar usb FILEPATH    
    getVar usb FILEFILESIZE
    getVar usb CRYPTFILENAME

    log "exec config part..  '$2' '$DRIVEMODE' '$FILEPATH' '$CRYPTFILENAME' '$FILEFILESIZE' '$MOUNTPATH' '$DRIVELOCALPATH' '$MAPNAME' '$DATAPATH'"  
    configureCryptoPartition  "$2" "$DRIVEMODE" "$FILEPATH" "$CRYPTFILENAME" "$FILEFILESIZE" "$MOUNTPATH" "$DRIVELOCALPATH" "$MAPNAME" "$DATAPATH" 
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





#Umounts persistent data unit. All parameters are either on the usb,
#memory or are constants
if [ "$1" == "umountCryptoPart" ] 
then
    
    getVar usb DRIVEMODE
    getVar mem CRYPTDEV
    
    umountCryptoPart "$DRIVEMODE" "$MOUNTPATH" "$MAPNAME" "$DATAPATH" "$CRYPTDEV"
    
    #Reset memory variable
    setVar CRYPTDEV "" mem
    
    exit 0
fi # TODO I think this op was meant for the inner key change, since we are dropping it, I believe it is not needed anymore (function is called only on the shutdown). At the end, review and if not used, delete





#Operations regarding the mail service
if [ "$1" == "mailServer" ] 
then
    
    #Configure the local domain
    #3 -> Host name
    #4 -> Domain name 
    if [ "$2" == "domain" ] 
    then
        checkParameterOrDie HOSTNM "${3}"
        checkParameterOrDie DOMNAME "${4}"
        
        #Join the parameters to form the fully qualified domain name
        FQDN="$HOSTNM.$DOMNAME"
        
        #Set and substitute any previous value
	       sed -i -re "s|^(myhostname = ).*$|\1$FQDN|g" /etc/postfix/main.cf
        
        exit 0
    fi
    
    
    
    #Configure a mail relay server to route mails through (or if
    #empty, remove relay)
    #3 -> Relay server address 
    if [ "$2" == "relay" ] 
    then
        checkParameterOrDie MAILRELAY "${3}"
        
        #Remove relay configuration
        if [ "$MAILRELAY" == "" ] 
	       then
	           sed -i -re "s/^(relayhost = ).*$/\1/g" /etc/postfix/main.cf 
        else
	           #Set relay host (brackets are for direct delivery, without NS MX lookup
	           sed -i -re "s|^\s*#?\s*(relayhost = ).*$|\1[$MAILRELAY]|g" /etc/postfix/main.cf
	       fi
        exit 0
    fi
    
    
    
    # Start or Reload mail server
    if [ "$2" == "reload" ] 
    then
        #Launch mail server
        /etc/init.d/postfix stop >>$LOGFILE 2>>$LOGFILE 
        /etc/init.d/postfix start >>$LOGFILE 2>>$LOGFILE
        exit "$?"            
    fi
fi




    
#Enable backup cron and database mark
if [ "$1" == "enableBackup" ]
then
    #Write cron to check every minute for a pending backup
    aux=$(cat /etc/crontab | grep backup.sh)
    if [ "$aux" == "" ]
    then
        echo -e "* * * * * root  /usr/local/bin/backup.sh\n\n" >> /etc/crontab  2>>$LOGFILE	    # TODO review this script
    fi
    
    #Set base backup value on the database
	   dbQuery "update  eVotDat set backup=0;"
	   if [ $? -ne 0 ] ; then
        log "enable backup failed: database server not running."
        exit 1
    fi
    
    exit 0
fi        





#Disable backup cron and database mark
if [ "$1" == "disableBackup" ]
then
    #Delete backup cron line (if it exists)
    sed -i -re "/backup.sh/d" /etc/crontab
    
    #Indicate to the webapp that backups are not being used
	   dbQuery "update  eVotDat set backup=-1;"
	   if [ $? -ne 0 ] ; then
        log "disable backup failed: database server not running."
        exit 1
    fi
    
    exit 0
fi





#Checks if backup is enabled or not         #TODO make this a free-op
#RETURN 0: enabled, 1: disabled or error
if [ "$1" == "isBackupEnabled" ]
then
    backupState=$(dbQuery "select backup from eVotDat;")
    if [ $? != 0 ] ; then
        log "isBackupEnabled: database access error"
        exit 1
    fi
    
    #If enabled (not -1), return 0
    if [ "$backupState" -ge 0 ] ; then
        log "backup is enabled"
        exit 0
    fi
    
    #Disabled
    log "backup is disabled"
    exit 1
fi





#Mark system to force a backup
if [ "$1" == "forceBackup" ]
then

    #If backup is not enabled, error
    backupState=$(dbQuery "select backup from eVotDat;")
    [ $? != 0 ] && exit 1
    if [ "$backupState" -lt 0 ] ; then
        log "backup is disabled, cannot force."
        exit 1
    fi
    
    
    #Backup cron reads database for next backup date. Set date to now.
    dbQuery "update eVotDat set backup="$(date +%s)";"
    
    # TODO launch the bak script here or wait for the cron?
    exit $?
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
        log "Bad number of shares ($SHARES) or threshold ($THRESHOLD)" 
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
    log "executing: $OPSEXE share $SHARES $THRESHOLD  $slotPath <$slotPath/key"
	   echo -ne "$PARTPWD\0" >$slotPath/key #Write the string term to avoid trash input from leaking in
	   $OPSEXE share $SHARES $THRESHOLD  $slotPath <$slotPath/key >>$LOGFILE 2>>$LOGFILE 
	   ret=$?
    
	   exit $ret
fi





#Grant or remove privileged admin access to webapp
#2-> 'grant' or 'remove'
if [ "$1" == "grantAdminPrivileges" ] 
then
    
    privilege=0 
    if [ "$2" == "grant" ] ; then
        # TODO el grant Con verificación de llave
        privilege=1
    fi
    
    log "giving/removing webapp privileges ($2)."
    
    dbQuery "update eVotDat set mante=$privilege;"
    exit $?
fi





#Check the current status of admin privileges # TODO make this a free-access op
#Return : 0 if privileges are disabled, 1 otherwise
if [ "$1" == "adminPrivilegeStatus" ] 
then
    mante=$(dbQuery "select mante from eVotDat;" | cut -f "1" | tr -d "\n")
    #If error, return no-privilege
    [ $? -ne 0 ] && return 0
    
    #Else, return retrioeved value
    return $mante
fi





#Authenticate administrator locally against the stored password
#2 -> challenge password
#RETURN 0: successful authentication 1: authentication failed
if [ "$1" == "authAdmin" ] 
then
    
    #Syntax check challenge password and calculate the sum
    checkParameterOrDie LOCALPWD "${2}" 0
    chalPwdSum=$(/usr/local/bin/genPwd.php "${2}" 2>>$LOGFILE)
    [ "$chalPwdSum" == "" ] && return 1
    
    
    #Get the actual admin local password sum
    getVar disk LOCALPWDSUM
    [ "$LOCALPWDSUM" == "" ] && return 1
    
    
    #If password sums coincide
    if [ "$chalPwdSum" == "$LOCALPWDSUM" ] ; then
        log "Successful admin local authentication"
        return 0
    fi
    
    log "Failed admin local authentication"
    return 1
fi





#Create admin user, substitute admin user or update admin user credentials
# 2-> Operation: 'new': add a new administrator, (existing user or new) and withdraw
#                       role to the former one. If existing, username and id must match.
#             'reset': update the two passwords and the IP for the current admin
# 3-> Username
# 4-> Web application password
# 5-> Full Name
# 6-> Personal ID number
# 7-> IP address
# 8-> Mail address
# 9-> Local password
if [ "$1" == "setAdmin" ]
then
    if [ "$2" != "new" -a "$2" != "reset" ]
    then
	       log "setAdmin: Bad operation parameter $2"
	       exit 1
    fi
    
    checkParameterOrDie ADMINNAME   "${3}"
    checkParameterOrDie MGRPWD      "${4}"
    checkParameterOrDie ADMREALNAME "${5}"
    checkParameterOrDie ADMIDNUM    "${6}"
    checkParameterOrDie ADMINIP     "${7}"
    checkParameterOrDie MGREMAIL    "${8}"
    checkParameterOrDie LOCALPWD    "${9}"
    
    #Get stored value for the admin username
    getVar disk ADMINNAME
    oldADMINNAME="$ADMINNAME"
    oldAdmName=$($addslashes "$oldADMINNAME" 2>>$LOGFILE)

    #Encode IP into long integer
    newIP=$(ip2long "$ADMINIP")
    [ "$newIP" == "" ] && newIP="-1" #If empty or bad format, default
    
    #Hash passwords for storage, for security reasons
	   MGRPWDSUM=$(/usr/local/bin/genPwd.php "$MGRPWD" 2>>$LOGFILE)
    
    
    
    #In any case, update local manager password (if any)
    if [ "$LOCALPWD" != "" ] ; then
        LOCALPWDSUM=$(/usr/local/bin/genPwd.php "$LOCALPWD" 2>>$LOGFILE)
        setVar LOCALPWDSUM "$LOCALPWDSUM" disk
    fi
    
    #Update other data
    setVar ADMREALNAME "$ADMREALNAME" disk
	   setVar MGREMAIL "$MGREMAIL" disk
    setVar ADMINIP "$ADMINIP" disk
    
    #Reset credentials of current admin (web app password and IP address)
    if [ "$2" == "reset" ]
	   then
	       dbQuery "update eVotPob set clId=-1,oIP=$newIP,pwd='$MGRPWDSUM' where us='$oldAdmName';"
        exit $?
    fi        
    
    ### If adding a new admin (or replacing a former one)
    
    #Escape input data
	   adminname=$($addslashes "$ADMINNAME" 2>>$LOGFILE)
	   admidnum=$($addslashes "$ADMIDNUM" 2>>$LOGFILE)
	   adminrealname=$($addslashes "$ADMREALNAME" 2>>$LOGFILE)
	   mgremail=$($addslashes "$MGREMAIL" 2>>$LOGFILE)
	       
	   #Insert new admin user (if existing, will fail)
	   dbQuery "insert into eVotPob (us,DNI,nom,rol,pwd,clId,oIP,correo)" \
            "values ('$adminname','$admidnum','$adminrealname',3,'$MGRPWDSUM',-1,$newIP,'$mgremail');"
	   
	   #Update new admin user (if already existing, insert will have
	   #failed and this will update some parameters plus role)
	   dbQuery "update eVotPob set clId=-1,oIP=$newIP,pwd='$MGRPWDSUM',"\
            "nom='$adminrealname',correo='$mgremail',rol=3 where us='$adminname';"
    
    
    #If there was a previous admin name and it is different from the new one
    if [ "$oldADMINNAME" != "" -a "$oldADMINNAME" != "$ADMINNAME" ] ; then
        
        #Reduce role for the former admin
        dbQuery "update eVotPob set rol=0 where us='$oldAdmName';"
        
        #New admin's e-mail will be the new notification e-mail recipient
	       dbQuery "update eVotDat set email='$mgremail';"        
        
        #Also, update mail aliases
        setNotifcationEmail "$MGREMAIL"
    fi
    
    #Store the new admin name and ID
    setVar ADMINNAME "$ADMINNAME" disk
    setVar ADMIDNUM "$ADMIDNUM" disk
    
    #Add administrator's IP to the whitelist
    getVar disk ADMINIP
    echo "$ADMINIP" >> /etc/whitelist
    
    exit 0
fi









#Store the certificate and auth token to communicate with the
#anonymity network
#2 -> authentication token
#3 -> private key (PEM)
#4 -> self-signed certificate (B64), later to be signed by the anonyimity central authority
#5 -> public exponent (B64)
#6 -> modulus (B64)
if [ "$1" == "storeLcnCreds" ]
then
    checkParameterOrDie SITESTOKEN "${2}"
    checkParameterOrDie SITESPRIVK "${3}"
    checkParameterOrDie SITESCERT "${4}"
    checkParameterOrDie SITESEXP "${5}"
    checkParameterOrDie SITESMOD "${6}"
    
    
    #Insert keys and the self-signed certificate sent to eSurveySites.
    # keyyS -> service private ley (PEM)
    # certS -> self-signed service certificate (B64)
    # expS  -> public exponent of the certificate (B64)
    # modS  -> modulus of the certificate (B64)
	   dbQuery "update eVotDat set keyyS='$SITESPRIVK', "\
            "certS='$SITESCERT', expS='$SITESEXP', modS='$SITESMOD';"
	   
    #Insert authentication token used to communicate with eSurveySites
	   dbQuery "update eVotDat set tkD='$SITESTOKEN';"
fi





#Will generate a RSA keypair and then a certificate request to be
#signed by a CA, with the specified Subject
#2 -> 'new': will generate the keys and the csr
#   'renew': only a new csr will be generated
#3 -> SERVERCN
#4 -> COMPANY
#5 -> DEPARTMENT
#6 -> COUNTRY
#7 -> STATE
#8 -> LOC
#9 -> SERVEREMAIL
if [ "$1" == "generateCSR" ] 
then
    
    checkParameterOrDie SERVERCN    "${3}"
    checkParameterOrDie COMPANY     "${4}"
    checkParameterOrDie DEPARTMENT  "${5}"
    checkParameterOrDie COUNTRY     "${6}"
    checkParameterOrDie STATE       "${7}"
    checkParameterOrDie LOC         "${8}"
    checkParameterOrDie SERVEREMAIL "${9}"
    
    
    #Path where all the ssl data can eb found in the encrypted drive
    sslpath="$DATAPATH/webserver"
    #If this is a cert renewal, create a secondary directory for the
    #new request
    if [ "$2" == "renew" ] ; then
	       sslpath="$DATAPATH/webserver/newcsr"  
        
	       mkdir -p $sslpath            >>$LOGFILE 2>>$LOGFILE
	       chown root:www-data $sslpath >>$LOGFILE 2>>$LOGFILE
	       chmod 755  $sslpath          >>$LOGFILE 2>>$LOGFILE
    fi
    
    #Destination file
    OUTFILE="$sslpath/server.csr"
    
    #Build the subject (email goes at the beginning, for compatibility reasons)    
    SUBJECT="/O=$COMPANY/C=$COUNTRY/CN=$SERVERCN"
    [ "$DEPARTMENT" != "" ]  && SUBJECT="/OU=$DEPARTMENT"$SUBJECT
    [ "$STATE" != "" ]       && SUBJECT="/ST=$STATE"$SUBJECT
    [ "$LOC" != "" ]         && SUBJECT="/L=$LOC"$SUBJECT
    [ "$SERVEREMAIL" != "" ] && SUBJECT="/emailAddress=$SERVEREMAIL"$SUBJECT
    
    
    #Generate the request
    log "Generating CSR in $OUTFILE with subject: $SUBJECT"
    openssl req -new -sha256 -newkey rsa:2048 -nodes -keyout "${sslpath}/server.key" -out $OUTFILE -subj "$SUBJECT" >>$LOGFILE 2>>$LOGFILE
    ret=$?
    if [ $ret -ne 0 ] ; then
	       log  "Error $ret while generating CSR." 
	       exit $ret
    fi
    
    #Set proper permissions for the generated files
    chown root:www-data $OUTFILE  >>$LOGFILE 2>>$LOGFILE
    chmod 444           $OUTFILE  >>$LOGFILE 2>>$LOGFILE
    chown root:root $sslpath/server.key  >>$LOGFILE 2>>$LOGFILE
    chmod 400       $sslpath/server.key  >>$LOGFILE 2>>$LOGFILE 
    
    exit 0
fi





#Set the certificate and key on the path expected by apache and
#postfix
if [ "$1" == "setupSSLcertificate" ] 
then
    
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
    exit 0
fi





#Launch the apache web server
if [ "$1" == "startApache" ] 
then
    #Launch web server
    /etc/init.d/apache2 stop >>$LOGFILE 2>>$LOGFILE 
    /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE
    exit "$?"            
fi





#Set configuration variables on the web app's PHP scripts. All scripts
#have been pre-processed during build to include placeholders for the
#values.
if [ "$1" == "processPHPScripts" ]
then
    getVar disk DBPWD
    getVar disk KEYSIZE
    getVar disk SITESORGSERV
    getVar disk SITESNAMEPURP
    
    #Set database access parameters
    sed -i  -e "s|###\*\*\*myHost\*\*\*###||g" /var/www/*.php # Host empty to use system sockets
    sed -i  -e "s|###\*\*\*myUser\*\*\*###|election|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*myPass\*\*\*###|$DBPWD|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*myDb\*\*\*###|eLection|g" /var/www/*.php
    
    #Nodes from the anonymity network to be excluded
    sed -i  -e "s|###\*\*\*exclnd\*\*\*###||g" /var/www/*.php
    
    #Key lenght to use on the application (ballot box, and election keys)
    sed -i  -e "s|###\*\*\*klng\*\*\*###|$KEYSIZE|g" /var/www/*.php
    
    #Stork organisation and service identifiers # TODO still use them?
    sed -i  -e "s|###\*\*\*organizacion\*\*\*###|$SITESORGSERV|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*proposito\*\*\*###|$SITESNAMEPURP|g" /var/www/*.php
    
    #App ID, to avoid cross-app sessions. Since we don't host any more
    #apps, just set a random value
    pw=$(randomPassword 12)
    sed -i  -e "s|###\*\*\*secr\*\*\*###|$pw|g" /var/www/*.php
    pw=''
    
    #Leave the app version empty to block remote updates
    sed -i  -e "s|###\*\*\*ver\*\*\*###||g" /var/www/*.php
    
    exit 0
fi





#Will write the certificate request and the instructions on the
#mounted usb drive
if [ "$1" == "fetchCSR" ] 
then
    
    getVar mem LANGUAGE
    getVar disk SSLCERTSTATE
    
    sslpath="$DATAPATH/webserver"
    if [ "$SSLCERTSTATE" == "renew" ] ; then
	       sslpath="$DATAPATH/webserver/newcsr"	
    fi
    
    #Bundle (on a zip) the CSR and a README files
    rm -rf /tmp/server-csr-*.zip  >>$LOGFILE 2>>$LOGFILE
    mkdir /tmp/server-csr  >>$LOGFILE 2>>$LOGFILE
    pushd /tmp  >>$LOGFILE 2>>$LOGFILE
    
    cp -f "$sslpath/server.csr" server-csr/server.csr  >>$LOGFILE 2>>$LOGFILE
    cp -f /usr/share/doc/sslcsr-README.txt.$LANGUAGE  server-csr/README.txt  >>$LOGFILE 2>>$LOGFILE
    
    zip server-csr-$(date +%s).zip server-csr/*  >>$LOGFILE 2>>$LOGFILE
    
    popd >>$LOGFILE 2>>$LOGFILE
    rm -rf /tmp/server-csr  >>$LOGFILE 2>>$LOGFILE
    
    #Copy the file to the usb
    bundle=$(ls /tmp/server-csr-*.zip)
	   cp "$bundle" /media/usbdrive/
    
    if (compareFiles "$bundle" /media/usbdrive/$(basename $bundle)) ; then
        ret=0 #Properly copied
    else
        ret=1 #Copy error
    fi
    
	   #Delete the bundle
	   rm -rf /tmp/server-csr-*.zip  >>$LOGFILE 2>>$LOGFILE
    
	   exit $ret
fi









  



##### SEGUIR: faltan por revisar










   

   
   
   
   
 


### TODO respecto a la gestión de cert ssl:
# TODO op de releer el csr, siempre activa, si dummy o ok, lee la actual, si renew, lee la candidata
# TODO op de instalar cert. recibe un cert. si dummy/renew, mira si el actual/candidato son autofirmados, si el nuevo valida y si coincide con la llave. si ok (se habrá renovado el cert sin cambiar la llave, luego se habrá refirmado la csr que ya tenemos), mirar que el actual valida, que le falta menos de X para caducar (o dejamos siempre y punto?), que el nuevo valida y si coincide con la llave.
# TODO op que lance un proceso de renew de clave (si en modo ok). genera csr nuevo, etc [hacer además que esté disponible siempre, sin tener en cuenta el modo y se pueda machacar el renew con otro? MEjor que sea machacable, así si hubiese algún error que requirese reiniciar el proceso antes de instalar un cert firmado, se podría hacer]

# TODO Reiniciar apache y postfix, ambos lo usan

#TODO añadir cron que avise por e-mail cuando falte X para caducar el cert

	
     


#//// sin verif condicionada a verifcert
# 4-> certChain o serverCert
## TODO cambiar numeración de params, será 1 o 2 ahora
if [ "$3" == "checkCertificate" ] 
then

	   if [ "$4" != "serverCert" -a "$4" != "certChain" ]
	   then
	       log "checkCertificate: bad param 4: $4"
	       exit 1
	   fi

	   #El nombre con que se guardará si se acepta 
	   destfilename="ca_chain.pem"

	   keyfile=''
	   #Si estamos verificando el cert de serv, necesitamos la privkey
	   if [ "$4" == "serverCert" ]
	   then

	       #El nombre con que se guardará si se acepta 
	       destfilename="server.crt"

	       crtstate=$(cat $DATAPATH/root/sslcertstate.txt 2>>$LOGFILE)
	       
	       if [ "$crtstate" == "RENEW" ]
		      then
		          #Buscamos la llave en el subdirectorio (porque la del principal está en uso y e sválida)
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

	   #Si no existe el temp específico de ssl, crearlo
	   if [ -e $ROOTSSLTMP ]
	   then
	       :
	   else
	       mkdir -p  $ROOTSSLTMP >>$LOGFILE 2>>$LOGFILE
	       chmod 750 $ROOTSSLTMP >>$LOGFILE 2>>$LOGFILE
	   fi
	   
	   #Movemos el fichero al temporal específico (al destino se copiará cuando estén verificados la chain y el cert)	  
	   mv -f $ROOTFILETMP/usbrreadfile $ROOTSSLTMP/$destfilename  >>$LOGFILE  2>>$LOGFILE
	   
	   
	   rm -rf $ROOTFILETMP/* >>$LOGFILE  2>>$LOGFILE #Vaciamos el temp de lectura de ficheros
	   exit 0
fi




      

#//// sin verif condicionada a verifcert?

## TODO cambiar numeración de params, será 1 o 2 ahora
if [ "$3" == "installSSLCert" ] 
then
	   
	   #Verificamos el certificado frente a la cadena.
	   verifyCert $ROOTSSLTMP/server.crt $ROOTSSLTMP/ca_chain.pem
	   if [ "$?" -ne 0 ] 
	   then
 	      #No ha verificado. Avisamos y salimos (borramos el cert y la chain en temp)
	       log "Cert not properly verified against chain" 
	       rm -rf $ROOTSSLTMP/*  >>$LOGFILE  2>>$LOGFILE
	       exit 1
	   fi
	   
	   #Según si estamos instalando el primer cert o uno renovado, elegimos el dir.
	   crtstate=$(cat $DATAPATH/root/sslcertstate.txt 2>>$LOGFILE)
	   if [ "$crtstate" == "RENEW" ]
	   then
	       basepath="$DATAPATH/webserver/newcsr/"
	   else #DUMMY y  OK
	       basepath="$DATAPATH/webserver/"
	   fi


    #Si todo ha ido bien, copiamos la chain a su ubicación 
	   mv -f $ROOTSSLTMP/ca_chain.pem  $basepath/ca_chain.pem >>$LOGFILE  2>>$LOGFILE
    
    #Si todo ha ido bien, copiamos el cert a su ubicación
	   mv -f $ROOTSSLTMP/server.crt  $basepath/server.crt >>$LOGFILE  2>>$LOGFILE
	   

	   /etc/init.d/apache2 stop  >>$LOGFILE  2>>$LOGFILE


	   #Si es renew, sustituye el cert activo por el nuevo.
	   if [ "$crtstate" == "RENEW" ]
	   then
	       mv -f  "$DATAPATH/webserver/newcsr/server.csr"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       mv -f  "$DATAPATH/webserver/newcsr/server.crt"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       mv -f  "$DATAPATH/webserver/newcsr/server.key"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       mv -f  "$DATAPATH/webserver/newcsr/ca_chain.pem" "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       rm -rf "$DATAPATH/webserver/newcsr/"                           >>$LOGFILE  2>>$LOGFILE
	   fi

	   
    #Cambiar estado de SSL
	   echo -n "OK" > $DATAPATH/root/sslcertstate.txt


	   #enlazar el csr en el directorio web. (borrar cualquier enlace anterior)
	   rm /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	   cp -f $DATAPATH/webserver/server.csr /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	   chmod 444 /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	   
	   
	   /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE
	   if [ "$ret" -ne 0 ]; then
	       log "Error restarting web server!" 
	       exit 2
	   fi
	   
	   exit 0
fi

    



























#Operations related to the usb secure storage system and the
#management of the shared keys and configuration info.
if [ "$1" == "storops" ]
then

    if [ "$2" == "" ] ; then
	       log "ERROR storops: No op code provided" 
	       exit 1
    fi
    log "Called store operation $2..."
    
    
    
    
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
        
	       checkClearance $CURRENTSLOT
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
	           log "switchSlot: Bad slot number: $3" 
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
        
        log "rebuildKeyAllCombs:" 
	       log "Threshold:     $THRESHOLD" 
	       log "numreadshares: $numreadshares" 
	       
        #If no threshold, something must be very wrong on the cinfig 
        [ "$THRESHOLD" == "" ] && exit 10
        
        #If not enough read shares, can't go on
        [ "$THRESHOLD" -gt "$numreadshares" ] && exit 11
        
        
        #Create temporary dir for the combinations
	       mkdir -p $slotPath/testcombdir  >>$LOGFILE 2>>$LOGFILE
	       
	       #Calculate all possible combinations
	       combs=$(/usr/local/bin/combs.py $THRESHOLD $numreadshares)
        log "Number of combinations: "$(echo $combs | wc -w) 
        
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
                log "copying keyshare$pos to $slotPath/testcombdir named keyshare$offset" 
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
        [ $gotit -ne 1 ] && exit 1
        
	       exit 0	
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
        log "testForDeadShares: Available shares: "$(ls -l  $slotPath 2>>$LOGFILE )      
        sharefiles=$(ls "$slotPath/" | grep -Ee "^keyshare[0-9]+$")
        numsharefiles=$(echo $sharefiles 2>>$LOGFILE | wc -w)
        
        #If no shares
        if [ "$sharefiles" == ""  ] ; then
            log "Error. No shares found"
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
                log "copying keyshare$pos to $ROOTTMP/testdir named $ROOTTMP/testdir/keyshare$offset" 
	               cp $slotPath/keyshare$pos $ROOTTMP/testdir/keyshare$offset   >>$LOGFILE 2>>$LOGFILE
	                   
	               offset=$((offset+1))
            done
            log "Shares copied to test directory: "$(ls -l  $ROOTTMP/testdir)  
            
            #Rebuild cipher key and store it on the var. 
            CURRKEY=$($OPSEXE retrieve $THRESHOLD $ROOTTMP/testdir  2>>$LOGFILE)
            #If failed, exit.
            [ $? -ne 0 ] && failed=1 && break
            
            log "Could rebuild key" 
            
            #If key not matching the previous one, exit      
            [ "$LASTKEY" != "" -a "$LASTKEY" != "$CURRKEY"   ] && failed=1 && break
            
            log "Matches previous" 
            
            #Shift current key
            LASTKEY="$CURRKEY"
            
            #Next rebuild will start from the next to the last used now
            count=$(( count + THRESHOLD ))
        done
        
        #Remove directory, to avoid leaving sensitive data behind
        rm -rf $ROOTTMP/testdir >>$LOGFILE 2>>$LOGFILE
        
        log "found deadshares? $failed"
        
        exit $failed
    fi
    
    
    
    
    #Compare last read config with the one considered to be the
    #correct one
    #Return: 0 if no conflicts, 1 if conflicts
    if [ "$2" == "compareConfigs" ]
	   then
        
        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
	       NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	       lastConfigRead=$((NEXTCONFIGNUM-1))
        log "***** #### NEXTCONFIGNUM:  $NEXTCONFIGNUM"
	       log "***** #### lastConfigRead: $lastConfigRead"

        #If none read, no conflicts
	       if [ "$lastConfigRead" -lt 0 ] ; then
	           log "compareConfigs: No config files read yet"
	           exit 0;
	       fi
        
        #No reference configuration settled (only one has been read or
        #this is the first comparison)
	       if [ ! -s $slotPath/config.raw ] ; then
            #Set the first read config as the proper one
            parseConfigFile "$slotPath/config0" 2>>$LOGFILE > $slotPath/config
            #We also store a raw version of the read config block for comparison
		          cat $slotPath/config0 2>>$LOGFILE > $slotPath/config.raw
	       fi
        
        #Get the file differences (on the first read, it will compare with itself)
	       differences=$( diff $slotPath/config$lastConfigRead  $slotPath/config.raw )
        #<DEBUG>
	       log "***** diff for config files $lastConfigRead - config: $differences"
        #</DEBUG>
        
        #If there are differences, print them to the user and return conflict
	       if [ "$differences" != "" ]
		      then
            #Build the diferences report so the user can decide
            report=$"Current configuration:""\n"
		          report="$report""--------------------- \n\n"
            report="$report"$(cat $slotPath/config.raw)
            report="$report""\n\n\n"
            report="$report"$"New Configuration:""\n"
            report="$report""--------------------- \n\n"
            report="$report"$(cat $slotPath/config$lastConfigRead)
            report="$report""\n\n\n"
            report="$report"$"Differences:""\n"
            report="$report""--------------------- \n\n"
            report="$report""$differences"
            
            #Send to the user and return 'conflict'
            echo -ne "$report"
            exit 1
        fi
        
        exit 0
		  fi
    
    
    
    
    #The user will command, in case of configuration conflict, to use
    #the last read configuration as the correct one, substituting the
    #one previously settled as the correct.
    if [ "$2" == "resolveConfigConflict" ]
	   then
        
	       #Store raw block for comparison
	       cat $slotPath/config$lastConfigRead 2>>$LOGFILE > $slotPath/config.raw
        
        #Parse and store the configuration
	       parseConfigFile "$slotPath/config$lastConfigRead" 2>>$LOGFILE > $slotPath/config
        
        exit 0
    fi
    
    
    
    
    #Validate structure of the last read config file
    if [ "$2" == "parseConfig" ] 
	   then
                
        getVar mem CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        
	       NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	       lastConfigRead=$((NEXTCONFIGNUM-1))
	       log "*****NEXTCONFIGNUM:  $NEXTCONFIGNUM"
	       log "*****lastConfigRead: $lastConfigRead"
        
	       if [ "$NEXTCONFIGNUM" -eq 0 ]
	       then
	           log "parseConfig: no configuration file read yet!" 
	           exit 1
	       fi
        
	       config=$(parseConfigFile "$slotPath/config$lastConfigRead" 2>>$LOGFILE)
	       
	       if [ "$config" == "" ]
	       then
	           log "parseConfig: Configuration tampered or corrupted" 
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
	           log "settleConfig: esurveyconfiguration parse error. Possible tampering or corruption" 
	           exit 1
	       fi
        exit 0
    fi
    
    
    
    
    #Check if password is valid for a store
    #3-> dev
    #4-> password    
    if [ "$2" == "checkPwd" ] 
	   then
        checkParameterOrDie PATH   "${3}" "0"
        checkParameterOrDie DEVPWD "${4}" "0"
        
        $OPSEXE checkPwd -d "$3"  -p "$4"    2>>$LOGFILE #0 ok  1 bad pwd
	       exit $?
    fi
    
    
    
    
    #Reads a configuration block from the usb store
    #3-> dev
    #4-> password    
    if [ "$2" == "readConfigShare" ] 
	   then
        checkParameterOrDie PATH   "${3}" "0"
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
        checkParameterOrDie PATH   "${3}" "0"
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
    
    
    
    
    #Creates and inits a ciphered key store file on the device
    #3 -> Device path
    #4 -> New device password
    if [ "$2" == "formatKeyStore" ] 
	   then
        checkParameterOrDie PATH   "${3}" "0" #Used to be a dev, now it's a mount path
        checkParameterOrDie DEVPWD "${4}" "0"

        #Write an empty store file on the usb
        $OPSEXE format -d "$3"  -p "$4" 2>>$LOGFILE
	       ret=$?
        
        exit $ret
    fi
    
    
    
    
    #Writes the indicated share on the store at the indicated path
    #3 -> Device path
    #4 -> New device password
    #5 -> The number id of the share to be written (from the ones at the slot)
    #Return: 0: succesully written,  1: write error
    if [ "$2" == "writeKeyShare" ] 
	   then
	       checkParameterOrDie PATH   "${3}" 0
        checkParameterOrDie DEVPWD "${4}" 0
        
	       getVar usb SHARES
	       checkParameterOrDie INT    "${5}" 0
        
        getVar mem CURRENTSLOT
        
	       #Check that the indicated share is in range (0,SHARES-1)
	       if [ "$5" -lt 0 -o "$5" -ge "$SHARES" ] ; then
	           log "writeKeyShare: bad share num $5 (not between 0 and $SHARES)" 
	           exit 1
	       fi
        
        #Get the path to the indicated share file
	       shareFilePath="$ROOTTMP/slot$CURRENTSLOT/keyshare$5"
        
	       #Check that file exists and has size
	       if [ ! -s "$shareFilePath" ] ; then
	           log "writeKeyShare: nonexisting or empty share $5 (of $SHARES)" 
	           exit 1
	       fi
        
        #Write the share to the store
	       $OPSEXE writeKeyShare -d "$3"  -p "$4" <"$shareFilePath" 2>>$LOGFILE
	       ret=$?
        
	       exit $ret
    fi
    
    
    
    
    #Writes the usb config file (the one settled and being edited
    #during operation, not one from a slot) to a device
    #3 -> Device path
    #4 -> New device password
    if [ "$2" == "writeConfigBlock" ] 
	   then
        checkParameterOrDie PATH   "${3}" 0
        checkParameterOrDie DEVPWD "${4}" 0
        
        #Get the path to the configuration file
	       configFilePath="$ROOTTMP/config"	
        
        #Check that the file exists and has size
	       if [ ! -s "$configFilePath" ] ; then
	           log "writeConfigBlock: No config file to write!" 
	           exit 1
	       fi
        
	       #Write the config block to the store
	       cat "$configFilePath" | $OPSEXE writeConfig -d "$3"  -p "$4" 2>>$LOGFILE
	       ret=$?
        
	       exit $ret
    fi
    
    
fi #End of storops group of operations






#  TODO implement
if [ "$1" == "freezeSystem" ] 
then


    # TODO disbale servers (well, the web server, others are hidden), for security reasons, or disable the apps only and put a static front page?

    # inform of the remaining downtime and schedule the unfreeze op (if not executed by the user before)

    exit 0
fi

if [ "$1" == "unfreezeSystem" ] 
then




    exit 0
fi








    
# SEGUIR REVISANDO




    
    





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























if [ "$1" == "launchTerminal" ] 
then

    
    #Si no existe el directorio de logs del terminal, lo crea
    [ -d "$DATAPATH/terminalLogs" ] || mkdir  "$DATAPATH/terminalLogs"  >>$LOGFILE  2>>$LOGFILE
	   
    #Guarda el bash_history actual si existe (no debería ocurrir, pero por si acaso)
    if [ -s /root/.bash_history  ] ; then
	       mv /root/.bash_history  $DATAPATH/terminalLogs/bash_history_$(date +before-%Y%m%d-%H%M%S)  >>$LOGFILE  2>>$LOGFILE
	   fi
	   
	   #El history de esta sesión, se escribirá directamente en la zona de datos
	   export HISTFILE=$DATAPATH/terminalLogs/bash_history_$(date +%Y%m%d-%H%M%S) #//// probar que se guardan.

	   echo $"ESCRIBA exit PARA VOLVER AL MENÚ DE ESPERA."
	   /bin/bash
	   
	   #Enviar el bash_history a todos los interesados
	   mailsubject=$"Registro de la sesión de mantenimiento sobre el servidor de voto vtUJI del $(date +%d/%m/%Y-%H:%M)"
	   mailbody=$"Usted ha proporcionado su dirección como interesado en recibir una copia de la secuencia de comandos introducida por el técnico designado sobre el terminal del servidor de voto. Esta se encuentra en el fichero adjunto. Puede emplear este fichero para realizar o encargar personalmente una auditoría de la seguridad del mismo."
	   
    #Enviar correo a los interesados
	   echo "$mailbody" | mutt -s "$mailsubject"  -a $HISTFILE --  $emaillist

	   exit 0

    # TODO: recordarb que existe la op 'rootShell'
fi







#////revisar
if [ "$1" == "getFile" ] 
then
    
    # 3-> Dev
    if [ "$2" == "mountDev" ] 
	   then
	       
	       checkParameterOrDie DEV "${3}"
	       
        #//// Verificar los permisos con que se monta (por lo de las umask).
	       
	       #Montamos el directorio para que sólo el root puda leer y escribir 
	       # los ficheros y modificar los dirs, pero vtuji pueda recorrer y 
	       # listar el árbol de dirs. (las máscaras son umask, hace el XOR 
	       # entre estas y la default del proceso, que debería ser 755)
	       mkdir -p /media/USB >>$LOGFILE 2>>$LOGFILE
	       mount "$DEV""1" /media/USB -o dmask=022,fmask=027 >>$LOGFILE 2>>$LOGFILE
	       ret=$?
	       
	       if [ "$ret" -ne 0 ] 
	       then
	           log "getFile mountDev: El dispositivo no pudo ser accedido." 
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
	           echo "Ruta inválida. Debe ser subdirectorio de /media/USB/"  >>$LOGFILE 2>>$LOGFILE
	           exit 31
	       fi

	       aux=$(echo "$3" | grep -Ee "/\.\.(/| |$)")
	       if [ "$aux" != "" ] 
	       then
	           echo "Ruta inválida. No puede acceder a directorios superiores."  >>$LOGFILE 2>>$LOGFILE 
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
    
    log "getFile: bad subopcode."
    exit 1
fi

























log "Operation '$1' not found."  
exit 42




# TODO !
    # #Comprueba si la clave reconstruida en el slot activo es la correcta. # TODO esto no estaba ya más arriba? verificar si ya existem si se llama de otro modo o si es que falta código. --> está checkClearance, pero no sé si el uso de ambas es el mismo. buscar las llamadas a ambas -> no se usa en ningún lado, y no creo que tenga razón de ser en ninguna de las op de mant que faltan, creoq que es equivalente al checkclearance --> creo que es la op de mantenimiento de verifiar la llave actual, luego es equivalente. Quizá cambiarnombre del checkclearance para que se vea más genérico y usar en ambos sitios --> quizá no sean compatibles. una mira si hay llave y si coincide. la otra además ha de verificar todas las shares. OJO!! --> se puede implementar con llamadas a varias pvops, no implementar
    # # DENTRO de storops
    # if [ "$2" == "validateKey" ] 
	   # then
	   #     :
    #     getVar mem CURRENTSLOT
    #     slotPath=$ROOTTMP/slot$CURRENTSLOT/
    # fi



    # TODO falta operación storops para cambiar password del store (opsexe changePassword). Añadir op de mant al respecto.
    #    3 -> Device path -d 
    # 4 -> Former device password -p
    # 5 -> New device password -n

    # TODO opsexe checkdev no usada, usarla?  -d dev and [ -p pwd ] (not eneded, ignored if provided) --> no vale la pena, s ehace un checkdev antes de cada op, y no veo ningún sitio donde convenga usarla por sí sola.




#//// implementar verifycert  SIN VERIF!! (porque se usa para discernir si la instalación del cert requiere autorización o no  ---> Las ops que se ejecutan durante la instal del cert deben hacerse sin verif, pero sólo cuando falle verifycert!!!  --> ver cuáles son.)






#Trazar en la aplicación cuándo aparecen y desaparecen los datos críticos de memoria (pwd de la part, pwd de root de la bd, etc...). Limitar su tiempo de vida al máximo. 

#Antes del standby, borrar todos los datos, y si son necesarios luego, pasar esas ops a privado y que se carguen esos datos de la zona privada.


#Aislar el Pwd de la bd (no solo el de root, sino el de vtuji) y hacer que los ficheros de /var/www no sean legibles para vtuji (solo root y www-data)

#Cuando se invoque a las ops privilegiadas, si existen fragmentos de llave, estos se harán ilegibles poara el no priv.



#Decidir dónde activo la verificación de clave (lo más adecuado sería hacerlo en cuanto se crea/monta la partición, pero puede ser molesto verificar en cada op que haga. Mejor lo hago justo cuando el sistema queda en standby.) . El paso de la contraseña/piezas será por fichero/llamada a OP y funcionará como sesión. El cliente será el encargado de invalidar la contraseña (o piezas) cuando acabe de operar (o lo hago al acabar cada operación desde privops? es más seguro pero más molesto. Ver si es factible.)



#////$DATAPATH/webserver/newcsr --> revisar el control de este directiro (cuándo se crea, se borra, etc. Tengo que hacerlo aquí)




#////+++++ falta, en wizard, privops y privsetup, revisar todas las apariciones de DATAPATH o /media/eLectionCryptoFS o /media/crypStorage y ver que los ficheros que accede/escribe están en el path adecuado.





#//// En el standby, borrar wizardlog y dblog, o guardarlos sólo para root.




#//// Quizá, en vez de tener operaciones con o sin contraseña (alguna deberá ser necesariamente sin contraseña. Estudiar.), hacerlo dependiente del momento: durante el setup, todas sin contraseña. Cuando acabe el setup, guiardar un flag en /root y que pida siempre la contraseña. Securizar /root como toca.



#////Revisar todos los params y toda interacción con el usuario, para ver que no pueda crearse una vulnerabilidad. (por ejemplo, los params, pasarles la función que asegura el tipo y el contenido adecuados. Ver cómo puedo hacer que el usuario sólo pueda ejecutarlos en el momento adecuado -> por ejemplo, separar las ops que puedan usarse en standby de las de la inst y config. Al acabar la inst, quitar el permiso de ejecución a estas.







#//// Antes de ejecutar cualquier op, reconstruir la clave.  --> En vez de reconstruir, pedir el pwd de cifrado de la part y ver cómo puedo testear este pwd con cryptsetup frente a la partición.




#//// revisar todos los parámetros a fondo!!! Revisar cuando se invoque desde el standby. Asegurarme de que se pueda invocar verificando el pwd de la partición (lo digo sobretodo pensando en la func de cambiar partición de datos).  --> Alternativamente, hacer funciones de más alto nivel que integren las operaciones que provocarían un impass (ej, la de cambiar la part de datos) --> Otra forma sería implementar 2 formas  de autorización


#//// Para los script que ejecuta vtuji, evitar confiar en el PATH: poner rutas absolutas a todo (un atacante podría alterar la var PATH)


    #//// los pwd al menos, leerlos de los dirs de config




# TODO when installing a ssl cert, extract cert expiration date, store it on a var, and create an at job (or a cron) to remind of expiration

# TODO Revisar todas las ops y ver cuáles deben estar bloqueadas en mant (ej, clops init)





#//// Hay ops que no requieren reconstruir la clave.  --> Hay algunas que son sólo para el setup separarlas y al acabar el setup ya no se podrán ejecutar (revisar qué ops sólo se ejecutan en el setup). Las otras, ponerlas antes d ela verificación de clave.






# TODO remove all dialogs from privileged scripts. At least from the ops and common, setup will be fine



