#!/bin/bash


#This script contains all the actions that need to be executed by root
#during setup or during operation. They are invoked through
#calls. During setup they need no authorisation, but after that, they
#need to find a rebuilt key in order to be executed (some of them are
#free to be executed, and some others get clearance by previously
#authenticating with the administrator's local password).

#***** WARNING: When adding any operation, make sure it is listed on
#***** the appropiate clearance list if they need to be authorised
#***** other than by key rebuilding


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





#Checks that there is a rebuilt key in any of the slots and checks if
#it matches the one used to cipher the disk drive. If a slot is
#passed, only that one is checked
#1 -> (optional) Slot number
#RETURN:  0: one of the keys is valid
#         1: Keys are non-existing or non-valid
checkKeyMatch () {
    
    #Get the known key
    local base=$(cat $DATABAKPWDFILE 2>>$LOGFILE)

    #All the slots or the one indicated
    slots=$(seq 1 $SHAREMAXSLOTS)
    if [ "$1" != "" ] ; then
        [ "$1" -ge 1 ] && slots="$1"
    fi
    
    local checked=0
    for num in $slots ; do
        
        #Get the challenging key in the slot
        if [ ! -s $ROOTTMP/slot$num/key ] ; then
            log "checkKeyMatch: No rebuilt key in slot $num"
	           continue
        fi
        
        local chal=$(cat $ROOTTMP/slot$num/key 2>>$LOGFILE)
        
        if [ "$chal" == ""  ] ; then
            log "checkKeyMatch: Empty key in slot $num"
	           continue
        fi
        
        #Compare keys with the actual one
        if [ "$chal" == "$base"  ] ; then
            log "checkKeyMatch: slot $num matched actual key"
            #Matched, leave
            checked=1
            break
        fi
        
        #Didn't match
        log "checkKeyMatch: slot $num doesn't match actual key"
    done
    
    return $checked
}





#Decide, based on the given operation code, which method is required
#to guess if the operation can be executed or not, and try to acquire
#clearance
#There are 3 kinds of operations:
#   free: No authorisation is needed. Can always be executed
#    pwd: Admin's local password will be requested
#    key: The rebuilt shared data ciphering key will be required
#1 -> operation code
#RETURN: 0: if got clearance 1: if not allowed
getClearance () {
    
    #List of operations that can be executed without any authorisation
    local freeOps="getPubVar   isBackupEnabled
                   authAdmin  clearAuthAdmin
                   fetchCSR
                   listUSBDrives   listHDDPartitions   getFilesystemSize   mountUSB
                   storops-resetSlot   storops-resetAllSlots   storops-switchSlot
                   storops-checkKeyClearance   storops-rebuildKey   storops-rebuildKeyAllCombs
                   storops-testForDeadShares   storops-checkPwd   storops-readKeyShare  storops-readConfigShare
                   removeAdminPrivileges    adminPrivilegeStatus
                   stats  readOpLog
                   suspend   shutdownServer"
    
    #List of operations requiring admin password check only
    local pwdOps="raiseAdminAuth  grantAdminPrivileges
                  forceBackup    freezeSystem   unfreezeSystem
                  installSSLCert
                  getComEmails
                  updateUserPassword   userExists
                  stats-setup"
    
    
    #If no operation code, then reject
    if [ "$1" == "" ] ; then
        log "getClearance: No operation code"
        return 1
    fi
    
    
    
    #If lock file does not exist, disallow
    if [ ! -f "$LOCKOPSFILE" ] ; then
        log "ERROR: $LOCKOPSFILE file does not exist."  
        return 1
    fi
    
    #If operations are not currently locked, allow
    lockvalue=$(cat "$LOCKOPSFILE")
    if [ "$lockvalue" -eq 0 ] 2>>$LOGFILE ; then
        opLog "Ops unlocked. Executing operation $1 without verification."
        return 0
    fi
    
    
    #Operations are locked, checking clearance
    log "Checking clearance for operation $1."
    
    
    #If operation needs no authorisation, go on
    if (contains "$freeOps" "$1") ; then
        
        log "getClearance: Operation $1 needs no authorisation. Go on"
        return 0
    fi
    
    
    #If operation needs password authorisation
    if (contains "$pwdOps" "$1") ; then
        
        log "Admin password clearance needed for operation $1"
        
        #Check if the administrator is currently authenticated
        getVar mem LOCALAUTH
        if [ "$LOCALAUTH" -eq 1 ] ; then
            #Authentication successful
            log "Password clearance obtained. Go on."
            return 0
        fi
        
        #Not authenticated
	       log "No password clearance obtained. Aborting."
        return 1
    fi
    
    
    
    #Else, any other operation (by default), will require the highest
    #clearance: the shared ciphering key
    log "Key clearance needed for operation $1"
    checkKeyMatch #Check all slots
    if [ $? -ne 0 ] ; then
	       log "No key clearance obtained. Aborting."
        return 1
	   fi
    
    #Key is valid
    log "Key clearance obtained. Go on."
    return 0
}











######################
##   Main program   ##
######################

opLog "Called operation $*"


#Guess if the operation can be executed, based on the operation code
#and the current status of locking, rebuilt keys and admin authentication
getClearance "$1"
if [ $? -ne 0 ] ; then
    opLog "No clearance to execute operation $1."
    exit 1
fi
opLog "Executing operation $1 after clearance verification."











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
    
    checkParameterOrDie "$3" "$4" 0
    
    allowedVars="SHARES THRESHOLD 
                 SSLCERTSTATE 
                 SERVERCN COMPANY DEPARTMENT COUNTRY STATE LOC SERVEREMAIL
                 SSHBAKSERVER SSHBAKPORT SSHBAKUSER SSHBAKPASSWD
                 IPMODE HOSTNM DOMNAME IPADDR MASK GATEWAY DNS1 DNS2
                 MAILRELAY
                 SITESORGSERV SITESNAMEPURP SITESEMAIL SITESCOUNTRY SITESTOKEN"
    
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
    
    allowedVars="HOSTNM DOMNAME 
                 SERVERCN COMPANY DEPARTMENT COUNTRY STATE LOC SERVEREMAIL
                 ADMINNAME ADMREALNAME ADMIDNUM ADMINIP MGREMAIL
                 SSHBAKSERVER SSHBAKPORT SSHBAKUSER SSHBAKPASSWD
                 IPMODE HOSTNM DOMNAME IPADDR MASK GATEWAY DNS1 DNS2
                 MAILRELAY
                 SITESORGSERV SITESNAMEPURP SITESEMAIL SITESCOUNTRY"
    
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
    #List of public access variables
    allowedVars="SSLCERTSTATE  SYSFROZEN  USINGCERTBOT SHARES THRESHOLD"
    
    if (! contains "$allowedVars" "$3") ; then
        log "Access denied to variable $3. Clearance needed."
        exit 1
    fi
    
    getVar "$2" "$3" aux
    echo -n $aux
    exit 0
fi





#Launch a root shell for maintenance purposes (no logging involved,
#this is for before the persistence unit and the services are loaded)
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

    #Mount options, to allow the user to travel and select files
    mountOpts="dmask=0022,fmask=0027"
    
    #Do the mount
    if [ "$2" == "mount" ] ; then
        mount  "$3" /media/usbdrive -o"$mountOpts"  >>$LOGFILE 2>>$LOGFILE
	       if [ "$?" -ne "0" ] ; then
            #Maybe the path is already mounted. Umount and retry
            umount /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
	           if [ "$?" -ne "0" ] ; then
                log "mountUSB: Partition '$3' preemptive umount error device must be in use"
                exit 1
            fi
            #Try a second and last mount
            mount  "$3" /media/usbdrive -o"$mountOpts"  >>$LOGFILE 2>>$LOGFILE
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
# 2-> 'h' to halt, 'r' to reboot
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
    
    #If new, setup cryptoFS directories, with proper owners and permissions
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






###### Operations regarding the mail service ######

#Configure the local domain
#2 -> Host name
#3 -> Domain name 
if [ "$1" == "mailServer-domain" ] 
then
    checkParameterOrDie HOSTNM "${2}"
    checkParameterOrDie DOMNAME "${3}"
    
    #Join the parameters to form the fully qualified domain name
    FQDN="$HOSTNM.$DOMNAME"
    
    #Set and substitute any previous value
	   sed -i -re "s|^(myhostname = ).*$|\1$FQDN|g" /etc/postfix/main.cf
    
    exit 0
fi



#Configure a mail relay server to route mails through (or if
#empty, remove relay)
#2 -> Relay server address 
if [ "$1" == "mailServer-relay" ] 
then
    checkParameterOrDie MAILRELAY "${2}"
    
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
if [ "$1" == "mailServer-reload" ] 
then
    #Launch mail server
    /etc/init.d/postfix stop >>$LOGFILE 2>>$LOGFILE 
    /etc/init.d/postfix start >>$LOGFILE 2>>$LOGFILE
    exit "$?"            
fi





    
#Enable backup cron and database mark
if [ "$1" == "enableBackup" ]
then
    #Write cron to check every day for a pending backup
    aux=$(cat /etc/crontab | grep backup.sh)
    if [ "$aux" == "" ]
    then
        #Backup at 3 am every day
        echo -e "0 3 * * * root  /usr/local/bin/backup.sh\n\n" >> /etc/crontab  2>>$LOGFILE
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





#Checks if backup is enabled or not
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





#Mark system to force a backup (it will be performed a minute after
#this)
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
    
    #Now that the backup executes only once a day in the night, force
    #it here
    echo "/usr/local/bin/backup.sh" | at now + 2 min  >>$LOGFILE 2>>$LOGFILE  # TODO check that it works
    
    opLog "Backup forced by the system administrator"
    
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





#Generate a large cipher key and divide it in shares using Shamir's
#algorithm
#2 -> Number of total shares
#3 -> Minimum amount of them needed to rebuild
if [ "$1" == "substituteKey" ] 
then
    #Get reference to the currently active slot, there we will fragment the key
    getVar mem CURRENTSLOT
    slotPath=$ROOTTMP/slot$CURRENTSLOT/
    
    #Get the ciphered device
    getVar mem CRYPTDEV
    
    #Get the current data cipher key
    OLDKEY=$(cat $DATABAKPWDFILE 2>>$LOGFILE)
    
    #Read the new data cipher key from the active slot
    PARTPWD=$(cat $slotPath/key 2>>$LOGFILE)
    
    
    #See which slots were already being used (to delete them later)
    slotstokill=$(cryptsetup luksDump $CRYPTDEV 2>&1 | grep ENABLED | grep -oEe "[0-7]")
    if [ $? -ne 0 ] ; then
        log "Error: can't access encrypted drive $CRYPTDEV key slots."
        exit 1
    fi
    
    
    #Add the new key to the cipherkey list
    cryptsetup luksAddKey $CRYPTDEV   >>$LOGFILE 2>>$LOGFILE <<-EOF
$OLDKEY
$PARTPWD
EOF
    ret=$?
    [ $ret -eq 234 ] && log "ERROR: no key slots available at the partition. Should not ever happen!!!"
    if [ $ret -ne 0 ] ; then
        log "Error $ret trying to add new key. Please, check"
        exit 2
    fi
    
    #If successful, put the new key on the memory file used by the
    #backup and keycheck services
    echo -n "$PARTPWD" > $DATABAKPWDFILE
    
    
    #Delete the old key (and any other orphaned ones)
    for slot in $slotstokill
	   do
	       cryptsetup luksKillSlot $CRYPTDEV $slot  >>$LOGFILE 2>>$LOGFILE  <<-EOF
$PARTPWD
EOF
    done
    
    log "Key successfully added."
    exit 0
fi





#Grant privileged admin access to webapp. Logged at the oplog to
#check that the administrator is not trying to cheat.
if [ "$1" == "grantAdminPrivileges" ] 
then
    getVar disk MGREMAIL
    
    log "giving webapp privileges."

    #Log it in the operations log for transparency
    opLog "[PRIVILEGES] ADMINISTRATOR OBTAINED PRIVILEGES on "$(date)"."
    
    
    
    #Mail a warning to all the comission
    emaillist=$(parseEmailFile $DATAPATH/root/keyComEmails)
    if [ $? -ne 0 ] ; then
        log "Error processing e-mail list at $DATAPATH/root/keyComEmails. Aborting."
        exit 1
    fi
    
    #Send mail
    mailsubject=$"System administrator has obtained privileges"
	   mailbody=$"As a member of the key custody comission, you are informed that the system administrator has now privileged access to the web application. If this has happened without your knowledge or without supervision during an election, this could be irregular and a disenfranchisement risk. Please, investigate him. On "" $(date +%d/%m/%Y-%H:%M)"
    export EMAIL="vtUJI administrator <"$MGREMAIL">"
	   echo "$mailbody" | mutt -s "$mailsubject" -- $MGREMAIL $emaillist
    
    
    
    dbQuery "update eVotDat set mante=1;"
    exit $?
fi





#Remove privileged admin access to webapp. Logged at the oplog to
#check that the administrator is not trying to cheat.
if [ "$1" == "removeAdminPrivileges" ]
then
    getVar disk MGREMAIL
    
    log "removing webapp privileges."

    #Log it in the operations log for transparency
    opLog "[PRIVILEGES] ADMINISTRATOR REMOVED PRIVILEGES on "$(date)"."
    
    
    
    #Mail a warning to all the comission
    emaillist=$(parseEmailFile $DATAPATH/root/keyComEmails)
    if [ $? -ne 0 ] ; then
        log "Error processing e-mail list at $DATAPATH/root/keyComEmails. Aborting."
        exit 1
    fi
    
    #Send mail
    mailsubject=$"System administrator has dropped privileges"
	   mailbody=$"As a member of the key custody comission, you are informed that the system administrator has now lost his privileged access to the web application. It is safe now to perform an election without risk of disenfranchisement. On "" $(date +%d/%m/%Y-%H:%M)"
    export EMAIL="vtUJI administrator <"$MGREMAIL">"
	   echo "$mailbody" | mutt -s "$mailsubject" -- $MGREMAIL $emaillist
    
    
    
    dbQuery "update eVotDat set mante=0;"
    exit $?
fi





#Check the current status of admin privileges
#Return : 0 if privileges are disabled, 1 otherwise
if [ "$1" == "adminPrivilegeStatus" ] 
then
    mante=$(dbQuery "select mante from eVotDat;" | cut -f "1" | tr -d "\n")
    #If error, return no-privilege
    [ $? -ne 0 ] && exit 0
    
    #Else, return retrioeved value
    exit $mante
fi





#Mark database to add a one-time additional auth point to
#administrators
if [ "$1" == "raiseAdminAuth" ]
then

    #To prevent lockout on systems deployed behind a NAT, we raise the
    #level by two so the admin IP is not relevant to reach the admin level.
    dbQuery "update  eVotDat set authextra=2;"
	   if [ $? -ne 0 ] ; then
        log "raise admin auth failed: database server not running."
        exit 1
    fi
    
    exit 0
fi





#Authenticate administrator locally against the stored
#password. Status is saved until logged out
#2 -> challenge password
#RETURN 0: successful authentication 1: authentication failed
if [ "$1" == "authAdmin" ]
then
    
    #Syntax check challenge password and calculate the sum
    checkParameterOrDie LOCALPWD "${2}" 0
    chalPwdSum=$(hashPassword "${2}" 2>>$LOGFILE)
    [ "$chalPwdSum" == "" ] && exit 1
    
    
    #Get the actual admin local password sum
    getVar disk LOCALPWDSUM
    [ "$LOCALPWDSUM" == "" ] && exit 1
    
    
    #If password sums coincide
    if [ "$chalPwdSum" == "$LOCALPWDSUM" ] ; then
        log "Successful admin local authentication"
        
        #Store authentication successful status
        setVar LOCALAUTH "1" mem
        
        exit 0
    fi
    
    log "Failed admin local authentication"
    exit 1
fi





#Remove saved status of admin user authentication
if [ "$1" == "clearAuthAdmin" ]
then
    setVar LOCALAUTH "0" mem
    exit 0
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
        LOCALPWDSUM=$(hashPassword "$LOCALPWD" 2>>$LOGFILE)
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





#Update variables with admin info which is also stored on the database
if [ "$1" == "updateAdminVariables" ]
then
    #Read the updated info from the database
    getVar disk ADMINNAME

    err=0
    ADMREALNAME=$(dbQuery "select nom from eVotPob where us='$ADMINNAME';")
    [ $? != 0 ] && err=1
    ADMIDNUM=$(dbQuery "select DNI from eVotPob where us='$ADMINNAME';")
    [ $? != 0 ] && err=2
    ADMINIP=$(dbQuery "select oIP from eVotPob where us='$ADMINNAME';")
    [ $? != 0 ] && err=3
    MGREMAIL=$(dbQuery "select correo from eVotPob where us='$ADMINNAME';")
    [ $? != 0 ] && err=4
    
    if [ $err -ne 0 ] ; then
        log "updAdmVars: database access error: $err"
        exit $err
    fi
    
    #Convert IP from int to string
    ADMINIP=$(long2ip "$ADMINIP")
    
    #Update the file variables
    setVar ADMREALNAME "$ADMREALNAME" disk
    setVar ADMIDNUM "$ADMIDNUM" disk
    setVar ADMINIP "$ADMINIP" disk
    setVar MGREMAIL "$MGREMAIL" disk
    
    exit 0
fi





#Store the certificate to sign votes
#2 -> private key (PEM)
#3 -> self-signed certificate (B64), later to be signed by the anonyimity central authority
#4 -> public exponent (B64)
#5 -> modulus (B64)
if [ "$1" == "storeVotingCert" ]
then
    
    checkParameterOrDie SITESPRIVK "${2}"
    checkParameterOrDie SITESCERT "${3}"
    checkParameterOrDie SITESEXP "${4}"
    checkParameterOrDie SITESMOD "${5}"
    
    
    #Insert keys and the self-signed certificate sent to eSurveySites.
    # keyyS -> service private ley (PEM)
    # certS -> self-signed service certificate (B64)
    # expS  -> public exponent of the certificate (B64)
    # modS  -> modulus of the certificate (B64)
	   dbQuery "update eVotDat set keyyS='$SITESPRIVK', "\
            "certS='$SITESCERT', expS='$SITESEXP', modS='$SITESMOD';"
fi





#Store the auth token to communicate with the anonymity network
#2 -> authentication token
if [ "$1" == "storeLcnCreds" ]
then
    checkParameterOrDie SITESTOKEN "${2}"
    
    
    #Insert authentication token used to communicate with eSurveySites
	   dbQuery "update eVotDat set tkD='$SITESTOKEN';"
fi





#Will generate a RSA keypair and then a certificate request to be
#signed by a CA, with the specified Subject
#2 -> 'new': will generate the keys and the csr on the main directory
#   'renew': will generate the keys and the csr on a secondary directory
#3 -> SERVERCN
#4 -> COMPANY
#5 -> DEPARTMENT
#6 -> COUNTRY
#7 -> STATE
#8 -> LOC
#9 -> SERVEREMAIL
if [ "$1" == "generateCSR" ] 
then
    log "generateCSR \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\""
    
    checkParameterOrDie SERVERCN    "${3}"
    checkParameterOrDie COMPANY     "${4}"
    checkParameterOrDie DEPARTMENT  "${5}"
    checkParameterOrDie COUNTRY     "${6}"
    checkParameterOrDie STATE       "${7}"
    checkParameterOrDie LOC         "${8}"
    checkParameterOrDie SERVEREMAIL "${9}"
    
    
    #Path where all the ssl data can be found in the encrypted drive
    sslpath="$DATAPATH/webserver"
    #If this is a cert renewal, create a secondary directory for the
    #new request
    if [ "$2" == "renew" ] ; then
	       sslpath="$DATAPATH/webserver/newcsr"  
        
	       mkdir -p $sslpath            >>$LOGFILE 2>>$LOGFILE
	       chown root:www-data $sslpath >>$LOGFILE 2>>$LOGFILE
	       chmod 755  $sslpath          >>$LOGFILE 2>>$LOGFILE
    fi
    
    #This operation can be called on any mode and overwrite a previous
    #request or functioning cert. We archive any previous files found here
    archive="$DATAPATH/webserver/archive/ssl"$(date +%s)
    mkdir -p "$archive"           >>$LOGFILE 2>>$LOGFILE
    cp -f $sslpath/* "$archive/"  >>$LOGFILE 2>>$LOGFILE # Only copy the files
    rm -f $sslpath/*              >>$LOGFILE 2>>$LOGFILE # Only remove the files
    
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
    openssl req -new -sha256 -newkey rsa:2048 -nodes \
            -keyout "${sslpath}/server.key" \
            -out $OUTFILE -subj "$SUBJECT" >>$LOGFILE 2>>$LOGFILE
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
    setupSSLcertificate
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
    
    #Stork organisation and service identifiers
    sed -i  -e "s|###\*\*\*organizacion\*\*\*###|$SITESORGSERV|g" /var/www/*.php
    sed -i  -e "s|###\*\*\*proposito\*\*\*###|$SITESNAMEPURP|g" /var/www/*.php
    
    #App ID, to avoid cross-app sessions. Since we don't host any more
    #apps, just set a random value
    pw=$(randomPassword 12)
    sed -i  -e "s|###\*\*\*secr\*\*\*###|$pw|g" /var/www/*.php
    pw=''
    
    #Leave the app version empty to block remote updates
    sed -i  -e "s|###\*\*\*ver\*\*\*###||g" /var/www/*.php
    
    
    #Set the local IP for the protection of the certificate auth
    #script. (It has some problems behind some NAT, because cURL does
    #not check hosts file and does not translate the domain to the
    #localhost IP)
    ownIP=$(getOwnIP)
    sed -i  -e "s|###\*\*\*ownIP\*\*\*###|$ownIP|g" /var/www/auth/certAuth/certAuth.php
    
    exit 0
fi





#Will write the certificate request and the instructions on the
#mounted usb drive (either the current one or the one to renew)
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





#Reads a certificate and ca_chain file and depending on the current
#ssl state, performs some validations and if adequate, gets it
#installed
#2 -> ssl certificate file path candidate for installation
#3 -> ca chain file path for the candidate
if [ "$1" == "installSSLCert" ] 
then
    
    #Since we are just copying a file to the root domains, we don't
    #need any further checks or path limitations
    sslcertpath="$2"
    cachainpath="$3"
    checkParameterOrDie FILEPATH  "$sslcertpath"  "0"
    checkParameterOrDie FILEPATH  "$cachainpath"  "0"
    
    
    getVar disk SSLCERTSTATE
    
    sslpath="$DATAPATH/webserver"
    if [ "$SSLCERTSTATE" == "renew" ] ; then
	       sslpath="$DATAPATH/webserver/newcsr"	
    fi
    
    opLog "[SSL] Attempting certificate installation on "$(date)"."
    opLog "[SSL] Current SSL state: $SSLCERTSTATE"
    opLog "[SSL] Current certificate SHA256 fingerprint: "$(getX509Fingerprint "$DATAPATH/webserver/server.crt")
    opLog "[SSL] Current certificate subject: "$(getX509Subject "$DATAPATH/webserver/server.crt")
    opLog "[SSL] Current certificate issuer: "$(getX509Issuer   "$DATAPATH/webserver/server.crt")
    
    
    #Read the files and put them on a temp
    if [ ! -s "$sslcertpath" ] ; then
        log "SSL cert file $sslcertpath has no size"
    fi
    cp -f "$sslcertpath" $ROOTTMP/tmp/server.crt >>$LOGFILE 2>>$LOGFILE


    if [ ! -s "$cachainpath" ] ; then
        log "SSL cert file $cachainpath has no size"
    fi
    cp -f "$cachainpath" $ROOTTMP/tmp/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
    
    
    #Validate the certificate and chain, depending on the current state
    
    #Candidate is valid? ok
    checkCertificate  $ROOTTMP/tmp/server.crt  "1"
    if [ $? -ne 0  ] ; then
	       log "Error: candidate certificate is not valid x509 pem."
        rm -f $ROOTTMP/tmp/server.crt   >>$LOGFILE 2>>$LOGFILE
        rm -f $ROOTTMP/tmp/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
	       exit 1
    fi
    
    #Candidate is self-signed? reject
    isSelfSigned  $ROOTTMP/tmp/server.crt
    if [ $? -ne 0  ] ; then
	       log "Error: candidate certificate is self signed."
        rm -f $ROOTTMP/tmp/server.crt   >>$LOGFILE 2>>$LOGFILE
        rm -f $ROOTTMP/tmp/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
	       exit 2
    fi
    
    #Candidate matches with the private key? ok
    doCertAndKeyMatch  $ROOTTMP/tmp/server.crt "$sslpath"/server.key
    if [ $? -ne 0  ] ; then
	       log "Error: certificate does not match the private key."
        rm -f $ROOTTMP/tmp/server.crt   >>$LOGFILE 2>>$LOGFILE
        rm -f $ROOTTMP/tmp/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
	       exit 3
    fi
    
    #Each certificate in the chain is valid? ok
    checkCertificate $ROOTTMP/tmp/ca_chain.pem  "0"
    if [ $? -ne 0  ] ; then
	       log "Error: some certificate in the chain is not valid x509."
        rm -f $ROOTTMP/tmp/server.crt   >>$LOGFILE 2>>$LOGFILE
        rm -f $ROOTTMP/tmp/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
	       exit 4
    fi
    
    #Candidate validates with the provided chain? ok
    #Is the root certificate part of the system CA store? ok
	   verifyCert  $ROOTTMP/tmp/server.crt  $ROOTTMP/tmp/ca_chain.pem
    if [ $? -ne 0 ] ; then
	       log "Error: certificate purpose not SSL server or chain trust validation error."
        rm -f $ROOTTMP/tmp/server.crt   >>$LOGFILE 2>>$LOGFILE
        rm -f $ROOTTMP/tmp/ca_chain.pem >>$LOGFILE 2>>$LOGFILE
	       exit 5
	   fi
    
    
    #Since this can be called to renew a working certificate without
    #renewing the key, archive the one being substituted, if any.
    if [ -e "$sslpath/server.crt" ] ; then 
        archive="$DATAPATH/webserver/archive/ssl"$(date +%s)
        mkdir -p "$archive"           >>$LOGFILE 2>>$LOGFILE
        cp -f $sslpath/* "$archive/"  >>$LOGFILE 2>>$LOGFILE # Only copy the files
    fi  
    
    
    /etc/init.d/apache2 stop  >>$LOGFILE  2>>$LOGFILE
    /etc/init.d/postfix stop  >>$LOGFILE  2>>$LOGFILE
    
    
    #Install the certificate and chain to the expected path
    mv -f $ROOTTMP/tmp/server.crt  $sslpath/server.crt      >>$LOGFILE 2>>$LOGFILE
    mv -f $ROOTTMP/tmp/ca_chain.pem  $sslpath/ca_chain.pem  >>$LOGFILE 2>>$LOGFILE
    
    
    #If we are in renew state
    if [ "$SSLCERTSTATE" == "renew" ] ; then
        
        #Archive the base one 
        archive="$DATAPATH/webserver/archive/ssl"$(date +%s)
        mkdir -p "$archive"                      >>$LOGFILE 2>>$LOGFILE
        cp -f $DATAPATH/webserver/* "$archive/"  >>$LOGFILE 2>>$LOGFILE # Only copy the files
        
        #Substitute old certificate with the new certificate
        mv -f $DATAPATH/webserver/newcsr/* $DATAPATH/webserver/  >>$LOGFILE 2>>$LOGFILE
        rmdir $DATAPATH/webserver/newcsr/    >>$LOGFILE 2>>$LOGFILE
    fi
    
    
    #Do the apache and postfix configuration
    setupSSLcertificate
    
    
    #Register the operation for security reasons
    opLog "[SSL] New certificate SHA256 fingerprint: "$(getX509Fingerprint "$DATAPATH/webserver/server.crt")
    opLog "[SSL] New certificate subject: "$(getX509Subject "$DATAPATH/webserver/server.crt")
    opLog "[SSL] New certificate issuer: "$(getX509Issuer   "$DATAPATH/webserver/server.crt")
    
    
    #Reload apache and postfix
    /etc/init.d/apache2 start  >>$LOGFILE  2>>$LOGFILE
    if [ $? -ne 0 ] ; then
	       log "Error restarting apache" 
	       exit 6
	   fi
    /etc/init.d/postfix start  >>$LOGFILE  2>>$LOGFILE
    if [ $? -ne 0 ] ; then
	       log "Error restarting postfix" 
	       exit 7
	   fi
    
    #Switch SSL state to ok
	   setVar SSLCERTSTATE "ok" disk
    
    opLog "[SSL] Certificate installation successful on "$(date)" "
    exit 0
fi





###############################################################
# Operations related to the usb secure storage system and the #
# management of the shared keys and configuration info.       #
###############################################################


#Init persistent key slot management data
if [ "$1" == "storops-init" ] 
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
if [ "$1" == "storops-resetSlot" ] 
then
    getVar mem CURRENTSLOT
	   
	   resetSlot $CURRENTSLOT
    exit $?
fi




#Reset all slots. 
if [ "$1" == "storops-resetAllSlots" ] 
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
if [ "$1" == "storops-checkKeyClearance" ] 
then
	   getVar mem CURRENTSLOT
    
	   checkKeyMatch $CURRENTSLOT
	   ret="$?"
	   
	   exit $ret
fi






#Switch active slot
#2-> which will be the new active slot
if [ "$1" == "storops-switchSlot" ] 
then
	   
	   checkParameterOrDie INT "$2" "0"
	   if [ "$2" -gt $SHAREMAXSLOTS -o  "$2" -le 0 ]
	   then
	       log "switchSlot: Bad slot number: $2" 
	       exit 1
	   fi
    
	   setVar CURRENTSLOT "$2" mem
	   exit 0
fi






#Tries to rebuild a key with the available shares on the current
#slot, single attempt
if [ "$1" == "storops-rebuildKey" ] 
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
if [ "$1" == "storops-rebuildKeyAllCombs" ] 
then
		  getVar mem CURRENTSLOT
    slotPath=$ROOTTMP/slot$CURRENTSLOT/
    
    getVar usb THRESHOLD	
	   numreadshares=$(ls $slotPath | grep -Ee "^keyshare[0-9]+$" | wc -w)
    
    log "rebuildKeyAllCombs:" 
	   log "Threshold:     $THRESHOLD" 
	   log "numreadshares: $numreadshares" 
	   
    #If no threshold, something must be very wrong on the config 
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
        log "** Testing combination: $comb"
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
        log "op retrieve returned $stat"  # TODO test this, load usb 1,2,3,1 and see if this works
        
	       #Clean temp dir
	       rm -f $slotPath/testcombdir/*  >>$LOGFILE 2>>$LOGFILE
	       
        #If successful, we are done
	       if [ $stat -eq 0 ] ; then
            log "combination successful. Exiting"
            gotit=1
            break
        fi
	   done
    
    #Delete temp dir
	   rm -rf  $slotPath/testcombdir  >>$LOGFILE 2>>$LOGFILE
	   
    #If no combination was successful, return error.
    if [ $gotit -ne 1 ] ; then
        log "no combination was successful. Error"
        exit 1
    fi
    
	   exit 0	
fi








#Check if any share is corrupt. We rebuild key with N sets of
#THRESHOLD shares, so the set of all the shares is covered. Every
#rebuilt key is compared with the previous one to grant they are
#the same.
if [ "$1" == "storops-testForDeadShares" ] 
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

    
    mkdir -p $ROOTTMP/tmp/testdir >>$LOGFILE 2>>$LOGFILE
    LASTKEY=""
    CURRKEY=""
    count=0
    failed=0
    #For each share
    while [ "$count" -lt "$numsharefiles"  ]
    do
        #Clean test dir
        rm -f $ROOTTMP/tmp/testdir/* >>$LOGFILE 2>>$LOGFILE
        
        #Calculate which share numbers to use
        offset=0
        while [ "$offset" -lt "$THRESHOLD" ]
	       do
	           pos=$(( (count+offset)%numsharefiles ))

            #Copy keyshare to the test dir [rename it so they are correlative]
            log "copying keyshare$pos to $ROOTTMP/tmp/testdir named $ROOTTMP/tmp/testdir/keyshare$offset" 
	           cp $slotPath/keyshare$pos $ROOTTMP/tmp/testdir/keyshare$offset   >>$LOGFILE 2>>$LOGFILE
	           
	           offset=$((offset+1))
        done
        log "Shares copied to test directory: "$(ls -l  $ROOTTMP/tmp/testdir)  
        
        #Rebuild cipher key and store it on the var. 
        CURRKEY=$($OPSEXE retrieve $THRESHOLD $ROOTTMP/tmp/testdir  2>>$LOGFILE)
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
    rm -rf $ROOTTMP/tmp/testdir >>$LOGFILE 2>>$LOGFILE
    
    log "found deadshares? $failed"
    
    exit $failed
fi




#Compare last read config with the one considered to be the
#correct one
#Return: 0 if no conflicts, 1 if conflicts
if [ "$1" == "storops-compareConfigs" ]
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
if [ "$1" == "storops-resolveConfigConflict" ]
then
    
	   #Store raw block for comparison
	   cat $slotPath/config$lastConfigRead 2>>$LOGFILE > $slotPath/config.raw
    
    #Parse and store the configuration
	   parseConfigFile "$slotPath/config$lastConfigRead" 2>>$LOGFILE > $slotPath/config
    
    exit 0
fi




#Validate structure of the last read config file
if [ "$1" == "storops-parseConfig" ] 
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
if [ "$1" == "storops-settleConfig" ] 
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
#2-> dev
#3-> password    
if [ "$1" == "storops-checkPwd" ] 
then
    checkParameterOrDie PATH   "${2}" "0"
    checkParameterOrDie DEVPWD "${3}" "0"
    
    $OPSEXE checkPwd -d "$2"  -p "$3"    2>>$LOGFILE #0 ok  1 bad pwd
	   exit $?
fi




#Reads a configuration block from the usb store
#2-> dev
#3-> password   
if [ "$1" == "storops-readConfigShare" ] 
then
    checkParameterOrDie PATH   "${2}" "0"
    checkParameterOrDie DEVPWD "${3}" "0"
    
    getVar mem CURRENTSLOT
    slotPath=$ROOTTMP/slot$CURRENTSLOT/
    
	   NEXTCONFIGNUM=$(cat "$slotPath/NEXTCONFIGNUM")
	   
	   $OPSEXE readConfig -d "$2"  -p "$3" >$slotPath/config$NEXTCONFIGNUM  2>>$LOGFILE	
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
#2-> dev
#3-> password 
if [ "$1" == "storops-readKeyShare" ] 
then
    checkParameterOrDie PATH   "${2}" "0"
    checkParameterOrDie DEVPWD "${3}" "0"
    
    getVar mem CURRENTSLOT
    slotPath=$ROOTTMP/slot$CURRENTSLOT/
    
    NEXTSHARENUM=$(cat "$slotPath/NEXTSHARENUM")
    
	   $OPSEXE readKeyShare -d "$2" -p "$3" >$slotPath/keyshare$NEXTSHARENUM  2>>$LOGFILE
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
#2 -> Device path
#3 -> New device password
if [ "$1" == "storops-formatKeyStore" ] 
then
    checkParameterOrDie PATH   "${2}" "0"
    checkParameterOrDie DEVPWD "${3}" "0"
    
    #Write an empty store file on the usb
    $OPSEXE format -d "$2"  -p "$3" 2>>$LOGFILE
	   ret=$?
    
    exit $ret
fi




#Writes the indicated share on the store at the indicated path
#2 -> Device path
#3 -> New device password
#4 -> The number id of the share to be written (from the ones at the slot)
#Return: 0: succesully written,  1: write error
if [ "$1" == "storops-writeKeyShare" ] 
then
    checkParameterOrDie PATH   "${2}" "0"
    checkParameterOrDie DEVPWD "${3}" "0"
    
	   getVar usb SHARES
	   checkParameterOrDie INT    "${4}" 0
    
    getVar mem CURRENTSLOT
    
	   #Check that the indicated share is in range (0,SHARES-1)
	   if [ "$4" -lt 0 -o "$4" -ge "$SHARES" ] ; then
	       log "writeKeyShare: bad share num $4 (not between 0 and $SHARES)" 
	       exit 1
	   fi
    
    #Get the path to the indicated share file
	   shareFilePath="$ROOTTMP/slot$CURRENTSLOT/keyshare$4"
    
	   #Check that file exists and has size
	   if [ ! -s "$shareFilePath" ] ; then
	       log "writeKeyShare: nonexisting or empty share $4 (of $SHARES)" 
	       exit 1
	   fi
    
    #Write the share to the store
	   $OPSEXE writeKeyShare -d "$2"  -p "$3" <"$shareFilePath" 2>>$LOGFILE
	   ret=$?
    
	   exit $ret
fi




#Writes the usb config file (the one settled and being edited
#during operation, not one from a slot) to a device
#2 -> Device path
#3 -> New device password
if [ "$1" == "storops-writeConfigBlock" ] 
then
    checkParameterOrDie PATH   "${2}" "0"
    checkParameterOrDie DEVPWD "${3}" "0"
    
    
    #Get the path to the configuration file
	   configFilePath="$ROOTTMP/config"	
    
    #Check that the file exists and has size
	   if [ ! -s "$configFilePath" ] ; then
	       log "writeConfigBlock: No config file to write!" 
	       exit 1
	   fi
    
	   #Write the config block to the store
	   cat "$configFilePath" | $OPSEXE writeConfig -d "$2"  -p "$3" 2>>$LOGFILE
	   ret=$?
    
	   exit $ret
fi




#Reads a configuration block from the usb store
#2-> dev
#3-> current password
#4-> new password
if [ "$1" == "storops-changePassword" ] 
then
    checkParameterOrDie PATH   "${2}" "0"
    checkParameterOrDie DEVPWD "${3}" "0"
    checkParameterOrDie DEVPWD "${4}" "0"
    
	   $OPSEXE changePassword -d "$2" -p "$3" -n "$4"  >>$LOGFILE  2>>$LOGFILE	
	   ret=$?
    
	   exit $ret
fi




#Launch a root terminal. Log all session commands and send to interested recipients

if [ "$1" == "launchTerminal" ] 
then

    getVar disk MGREMAIL
    if [ "$MGREMAIL" == ""  ] ; then
        log "ERROR: No admin email variable found"
	       exit 1
    fi
    
    emaillist=$(parseEmailFile $DATAPATH/root/keyComEmails)
    if [ $? -ne 0 ] ; then
        log "Error processing e-mail list at $DATAPATH/root/keyComEmails. Aborting."
        exit 1
    fi
    
    #Create terminal logs directory
    [ -d "$DATAPATH/terminalLogs" ] || mkdir  "$DATAPATH/terminalLogs"  >>$LOGFILE  2>>$LOGFILE
	   
    #Store current bash_history if any (shouldn't, but just in case)
    if [ -s /root/.bash_history  ] ; then
	       mv /root/.bash_history  $DATAPATH/terminalLogs/bash_history_$(date +before-%Y%m%d-%H%M%S)  >>$LOGFILE  2>>$LOGFILE
	   fi
	   
	   #This session's history will be written on the data partition
	   #export HISTFILE=$DATAPATH/terminalLogs/bash_history_$(date +%Y%m%d-%H%M%S)
    sesslogfile=$DATAPATH/terminalLogs/bash_history_$(date +%Y%m%d-%H%M%S)
    
    #Set the proper shell (so 'script' can invoke the adequate shell instead of the wizard)
    export SHELL=/bin/bash
    
    
    #Launch root terminal (start a scripting session before launching the terminal)
	   echo $"WRITE exit TO FINISH THE SESION AND GO BACK TO THE MAIN MENU."
	   #/bin/bash
    script -e -q $sesslogfile
    
    
	   #Once finished, send bash command history to anyone interested
	   mailsubject=$"Voting server maintenance session registry"" $(date +%d/%m/%Y-%H:%M)"
	   mailbody=$"You provided ypour e-mail address to receive the logs of the execution of the maintenance session on a root terminal. Find it on the attached file. Use it to audit the session and detect any fraud."
    
    
    #Send mail to all the comission recipients
    export EMAIL="vtUJI administrator <"$MGREMAIL">"
	   echo "$mailbody" | mutt -s "$mailsubject"  -a "$sesslogfile" -- $MGREMAIL $emaillist
    
	   exit 0
fi






#It performs the certificate request and installation. After a long
#time disabled, certificate may be expired, so every enable must try a
#setup
if [ "$1" == "setupCertbot" ] 
then
    
    getVar disk SERVEREMAIL
    if [ "$SERVEREMAIL" == ""  ] ; then
        log "WARNING: No server email variable found"
	       exit 2
    fi
    
    getVar disk SERVERCN
    if [ "$SERVERCN" == ""  ] ; then
        log "WARNING: No server FQDN variable found"
	       exit 2
    fi
    
    #Guard to unexpected and undesired situation
    if [ -e /etc/letsencrypt -a ! -L /etc/letsencrypt ] ; then
        log "WARNING: certbot etc directory exists and is not a link. Shouldn't happen. Deleting."
        rm -rf /etc/letsencrypt   >>$LOGFILE 2>>$LOGFILE
    fi
    
    
    #Already enabled, ignore and exit
    if [ -e /etc/letsencrypt ] ; then
        log "WARNING: Certbot aready enabled. If not what you expected, please check."
        exit 1
    fi
    
    
    
    #On system boot or certbot re-enablements (there's no system
    #certbot dir but it is on the drive)
    if [ -e $DATAPATH/letsencrypt ] ; then
        log "Certbot directory previously existed in drive. This is a reboot or a re-enable."
        ln -s $DATAPATH/letsencrypt /etc/letsencrypt   >>$LOGFILE 2>>$LOGFILE
    fi
    
    
    #If apache is running, stop it temporarily (for when this is
    #called in maintenance)
    stoppedApache=0
    if (ps aux | grep apache | grep -v grep >>$LOGFILE 2>>$LOGFILE) ; then
        stoppedApache=1
        /etc/init.d/apache2 stop >>$LOGFILE 2>>$LOGFILE
    fi
    
    #Get a Let's Encrypt signed certificate with certbot
    $CERTBOT --standalone certonly -n --agree-tos -m "$SERVEREMAIL" -d "$SERVERCN"  >>$LOGFILE 2>>$LOGFILE
    ret=$?
    
    if [ "$stoppedApache" -eq 1 ] ; then
        /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE
    fi
    
    #If error on certificate generation, abort.
    if [ $ret -ne 0 ] ; then
        log "ERROR ($ret) generating/renewing certbot key"
        exit 5
    fi
    
    #If everything went right, there must be a directory (or a link
    #to it) with the certificate
    if [ ! -e /etc/letsencrypt ] ; then
        log "WARNING: certbot directory does not exist."
        exit 6
    fi
    
    
    #Move the certbot directory to the persistence unit if not done
    #yet (this may have happened on a running system), and link
    if [ ! -e $DATAPATH/letsencrypt ] ; then
	       mv /etc/letsencrypt $DATAPATH/   >>$LOGFILE 2>>$LOGFILE
	       if [ $? -ne 0 ] ; then
            log "ERROR: letsencrypt dir could not be copied to disk: not enough free space"
            rm  -rf /etc/letsencrypt   >>$LOGFILE 2>>$LOGFILE
            exit 4 # not enough free space
        fi
    fi
    
    if [ ! -e /etc/letsencrypt ] ; then
        #Link the moved dir to its system path
        ln -s $DATAPATH/letsencrypt /etc/letsencrypt   >>$LOGFILE 2>>$LOGFILE
    fi
    
    
    #Link current certificate/chain/key to the expected location (from
    #this moment on, everything is as if this was a hand-installed
    #certificate)
    rm -f $DATAPATH/webserver/server.crt    >>$LOGFILE 2>>$LOGFILE
    rm -f $DATAPATH/webserver/server.key    >>$LOGFILE 2>>$LOGFILE
    rm -f $DATAPATH/webserver/ca_chain.pem  >>$LOGFILE 2>>$LOGFILE
    rm -f $DATAPATH/webserver/server.csr    >>$LOGFILE 2>>$LOGFILE
    
    ln -s $DATAPATH/letsencrypt/live/$SERVERCN/cert.pem     \
       $DATAPATH/webserver/server.crt    >>$LOGFILE 2>>$LOGFILE
    ln -s $DATAPATH/letsencrypt/live/$SERVERCN/privkey.pem  \
       $DATAPATH/webserver/server.key    >>$LOGFILE 2>>$LOGFILE
    ln -s $DATAPATH/letsencrypt/live/$SERVERCN/chain.pem    \
       $DATAPATH/webserver/ca_chain.pem  >>$LOGFILE 2>>$LOGFILE
    touch   $DATAPATH/webserver/server.csr   >>$LOGFILE 2>>$LOGFILE
    
    
    #Automate renewal
    aux=$(cat /etc/crontab | grep certbot)
    if [ "$aux" == "" ]
    then
        echo -e "0 3 * * 1 root  $CERTBOT --apache certonly -n -d '$SERVERCN' \n\n" \
             >> /etc/crontab  2>>$LOGFILE
    fi
    
    #Set state variable
    setVar USINGCERTBOT "1" disk

    #Set ssl cert state variable
    setVar disk SSLCERTSTATE "ok"  #On certbot, always ok
    
    exit 0
fi



#Disables the current certbot certificate
if [ "$1" == "disableCertbot" ] 
then
    getVar disk SERVERCN
    getVar disk COMPANY
    getVar disk DEPARTMENT
    getVar disk COUNTRY
    getVar disk STATE
    getVar disk LOC
    getVar disk SERVEREMAIL
    
    
    #Force renew csr
    log "$PVOPS generateCSR \"renew\" \"$SERVERCN\" \"$COMPANY\" \"$DEPARTMENT\" \"$COUNTRY\" \"$STATE\" \"$LOC\" \"$SERVEREMAIL\""

    $PVOPS generateCSR "renew" "$SERVERCN" "$COMPANY" "$DEPARTMENT" "$COUNTRY" "$STATE" "$LOC" "$SERVEREMAIL"
    if [ $? -ne 0 ]
	   then
		      log "Error on the forced ssl certificate renewal." 0 0
	       exit 1
    fi
    
    #Disable auto update
    sed -i -re "/certbot/d" /etc/crontab 2>>$LOGFILE
    
    #Set state variable
    setVar USINGCERTBOT "0" disk
    
    #Unlink the certbot dir
    rm  /etc/letsencrypt   >>$LOGFILE 2>>$LOGFILE
    
    #Set state to renew
    setVar  SSLCERTSTATE "renew" disk
    
    exit 0
fi






#Freezes the system (all services that write the persistence unit are
#stopped and all communication with the outer is closed)
if [ "$1" == "freezeSystem" ] 
then
    #Mark the system as frozen
    setVar SYSFROZEN "1" mem
    
    #Stop all services that may alter the persistent data
    stopServers
    if [ $? -ne 0 ] ; then
        log "Freeze failed. Some service failed to stop".
        startServers
        exit 1
    fi
    
    #Launch a substitution webserver with a static info page
    bash /usr/local/share/simpleWeb/simpleHttp.sh start

    opLog "System frozen by the system administrator"

    exit 0
fi



#Restores services and outer communication
if [ "$1" == "unfreezeSystem" ] 
then
    #Stop substitution webserver
    bash /usr/local/share/simpleWeb/simpleHttp.sh stop
    
    #Restart services again
    startServers
    if [ $? -ne 0 ] ; then
        log "Unfreeze failed. Some service failed to start".
        exit 1
    fi
    
    #Mark the system as unfrozen
    setVar SYSFROZEN "0" mem
    
    opLog "System unfrozen by the system administrator"
    
    exit 0
fi




#Receives a list of emails which belong to the key custody committee,
#they must be stored to be used as the recipients of security
#notifications
#2 -> Temporary file to read the list from. Will erase it at the end.
if [ "$1" == "setComEmails" ] 
then
    
    if [ ! -f "$2" ] ; then
        log "input email file does not exist."
        exit 1
    fi
    
    #Reset the destination file
    echo -n "" > $DATAPATH/root/keyComEmails
    
    #Read the file 
    filecontent=$(cat  "$2")
    
    
    #Parse input addresses
    emaillist=""
	   for eml in $filecontent; do
        #Check if proper email syntax
	       parseInput email "$eml"
	       if [ $? -ne 0 ] ; then
		          log "Invalid address: $eml. Dropped" 0 0
            continue
	       fi
        #Add the proper email to the list
        emaillist="$emaillist$eml\n"
	   done
    
    #Write the email list to the persistent file
    echo -ne "$emaillist" > $DATAPATH/root/keyComEmails
    
    #Remove the input file, as it is always a temporary buffer
    rm -f "$2" >>$LOGFILE 2>>$LOGFILE
    
    exit 0
fi




#Prints the list of e-mails which belong to the key custody committee
if [ "$1" == "getComEmails" ] 
then
    
    if [ ! -f $DATAPATH/root/keyComEmails ] ; then
        log "$DATAPATH/root/keyComEmails file does not exist. Returning nothing"
        exit 1
    fi

    #Print it
    cat $DATAPATH/root/keyComEmails
    
    exit 0    
fi




#Checks whether a user exists at the database
#2 -> username
if [ "$1" == "userExists" ]
then
    checkParameterOrDie  USER "${2}" "0"
    
    #Escape username
    username=$($addslashes  "$2"  2>>$LOGFILE)
    
    
	   found=$(dbQuery "select us from eVotPob where us='$username';")
	   if [ $? -ne 0 ] ; then
        log "userExists: database server access error."
        exit 2
    fi
    
    #Doesn't exist
    if [ "$found" == "" ] ; then
        exit 1
    fi
    
    #Exists
    exit 0
fi




#Sets a new password for a user in the database
#2 -> username
#3 -> new password
if [ "$1" == "updateUserPassword" ]
then
    checkParameterOrDie  USER "${2}" "0"
    checkParameterOrDie  PWD  "${3}" "0"

    #Escape username
    username=$($addslashes  "$2"  2>>$LOGFILE)
    
    #Hash the new password
    pwdsum=$(/usr/local/bin/genPwd.php "$3" 2>>$LOGFILE)
    
    #Update password
    dbQuery "update eVotPob set pwd='$pwdsum' where us='$username';"
    ret=$?
    
    #Log the password update on the oplog
    opLog "Admin attempted user password reset for user $username. Result: $ret"
    
    exit $ret
fi




#Prints to a tmp file a snapshot of the operations log
if [ "$1" == "readOpLog" ]
then
    
    cp -vf $OPLOG /tmp/oplog   >>$LOGFILE 2>>$LOGFILE
    chmod 744 /tmp/oplog  >>$LOGFILE 2>>$LOGFILE
    
    exit 0
fi





#Will print to stdout a set of human readable system health and status
#information
if [ "$1" == "stats" ] 
then
    /usr/local/bin/stats.sh live 2>>$LOGFILE
	   exit 0
fi





#Will start statistics collection on the round robin databases
if [ "$1" == "stats-start" ] 
then
    
    if (! grep /etc/crontab -rEe "stats\.sh")
    then
        #Update stats Every 5 minutes
        echo -e "0,5,10,15,20,25,30,35,40,45,50,55 * * * * "\
             "root /usr/local/bin/stats.sh update\n\n" >> /etc/crontab
    fi
    
    exit 0
fi





#Setup statistics system: both round robin databases and the visualization webapp
if [ "$1" == "stats-setup" ] 
then
    
    #Delete former databases, if any
	   rm -vf $DATAPATH/rrds/* >>$LOGFILE 2>>$LOGFILE
    
    #Start statistics database system and visualization webapp
	   /usr/local/bin/stats.sh start >>$LOGFILE 2>>$LOGFILE
	   if [ $? -ne 0 ] ; then
        log "Error starting statistics system"
        exit 1
    fi
    
    #Feed the first data to the system and generate the initial graphics
	   /usr/local/bin/stats.sh update >>$LOGFILE 2>>$LOGFILE
    
    exit 0
fi







log "Operation '$1' not found."  
exit 42
