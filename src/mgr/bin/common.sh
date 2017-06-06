#!/bin/bash
# Methods and global variables common to all management scripts go here
# Functions here are used in privileged and unprivileged config scripts.




###############
#  Constants  #
###############

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#Dialog options for all windows
DLGCNF="--shadow --cr-wrap --aspect 60 --insecure"
#<DEBUG>
# Enable tracing of the dialog widgets
DLGCNF="--shadow --cr-wrap --aspect 60 --insecure --trace /tmp/dialogTrace"
#</DEBUG>
dlg="dialog $DLGCNF "


#Wizard log file
LOGFILE=/tmp/wizardLog

#Log for the sql operations during install/maintenance (more
#sensitive, root access only)
SQLLOGFILE=/root/log/sqlLog

#Log of the executed operations #TODO test that the move to /var/log works
OPLOG=/var/log/opLog


#If this file contains a 1, no privileged operation will execute
#unless the valid ciphering key can be rebuilt from the fragments
#stored on the active slot.
LOCKOPSFILE="/root/lockPrivileged"


#In MB, minimum size of the AUFS to automatically copy the CD to RAM
#(AUFS reserves 50% of the system memory)
MINAUFSSIZE=1800


#Source of random input
RANDFILE=/dev/random
#<DEBUG>
RANDFILE=/dev/urandom
#</DEBUG>

#Persistent drive paths (for encrypted, physical and loopback filesystems)
MOUNTPATH="/media/localpart"
MAPNAME="EncMap"
DATAPATH="/media/crypStorage"


#Base name for the loopback filesystem file
CRYPTFILENAMEBASE="vtUJI-encryptedFS-"


#Number of key sharing slots managed by the system.
SHAREMAXSLOTS=2

#Default SSH port
DEFSSHPORT=22



#The base non-persistent directory for Root operation
ROOTTMP="/root"

#File where the database root password is stored
DBROOTPWDFILE=$DATAPATH/root/DatabaseRootPassword

#File where the password to cipher backup is stored during operation
DATABAKPWDFILE=$ROOTTMP/dataBackupPassword


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
#issues, now all return the same so we have only two states, OK and ERR
export DIALOG_ESC=1
export DIALOG_ERROR=1
export DIALOG_HELP=1
export DIALOG_ITEM_HELP=1






###############
#  Functions  #
###############


#Base log function. May be redefined on each script
log () {
    echo "["$(date --rfc-3339=ns)"][common]: "$*  >>$LOGFILE 2>>$LOGFILE
}



#Preemptively redirect all STDERR to the log file
#Save the STDERR file descriptor in descriptor 8, just in case we need
#it; restore stderr to its descriptor with exec 2>&8
## Not used anymore. Will hide the errors and prompt of the
## interactive terminal session.
redirectError () {
    exec 8>&2
    exec 2>>$LOGFILE
}



#Check if an element is in a list
#1 -> list [Don't forget to pass it between double quotes]
#2 -> search element
#RETURN 0:found, 1: Not found
contains() {

    #If no list, return no
    [ "$1" == "" ] && return 1
    
    #If no item, return no
    [ "$2" == "" ] && return 1

    #For each element in list, if match, return yes
    for i in $1 ; do
        [ "$i" == "$2" ] && return 0
    done
    
    #Not found
    return 1
}


#Send a mail to the root user (which will be forwarded to the
#administrator's e-mail address)
# 1-> subject
# 2-> body of the message
emailAdministrator(){
    echo "$2" | mail -s "$1" root 
}


#Wrapper for the privileged  op
# 1-> h: halts the system (default)
#     r: reboots
shutdownServer(){
    $PVOPS shutdownServer "$1"
}


#Hash a cleartext password
# 1-> password to hash
#STDOUT: sha256 hash
hashPassword () {
    echo -n "$1" | sha256sum | cut -d " " -f 1 | tr -d "\n"
}


#Check if a string matches the syntax restrictions of some data type
# $1 --> expected data type
# $2 --> input value string
#Returns 0 if matching data type, 1 otherwise.
#ALLOWEDCHARSET: If not matching, the allowed charset information for the data
#type is set there in some cases
parseInput () {
    
    #For those who have one, set the allowed characters to match the
    #parser   
    ALLOWEDCHARSET=''
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
	           
	           echo "$2" | grep -oiEe "^([a-z]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+$" 2>&1 >/dev/null
		          [ $? -ne 0 ] && notDn=1
            #echo "validating ip or dn Return: $((notIp & notDn))  notIp: $notIp  notDn: $notDn  str: $2"

            #If either of them is 0, returns zero (it is ip or dn), if both are 1 (not ip nor dn) returns 1
	           return $((notIp & notDn))
	           ;;
        
	       
	       "dn" ) #Domain name (full, with top level)
	           echo "$2" | grep -oiEe "^([a-z]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+$" 2>&1 >/dev/null
		          [ $? -ne 0 ] && ret=1
	      	    ;;

	       "hostname" ) #Hostname (allows trailing numbers)
	           echo "$2" | grep -oiEe "^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.?)+$" 2>&1 >/dev/null
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
	           ALLOWEDCHARSET='-.�+_;:,*@#%|~!?()=& a-z A-Z 0-9'
	           echo "$2" | grep -oEe "^[-.�+_;:,*@#%|~!?()=&a-zA-Z0-9]+$" 2>&1 >/dev/null
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
        
 	      "pem" ) #PEM string
	           echo "$2" | grep -oEe "^[- 0-9a-zA-Z/+]+=?=?$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
               
	       "cc" ) #Two letter country code (no use in checking the whole set)
	           echo "$2" | grep -oEe "^[a-zA-Z][a-zA-Z]$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
	       
	       "freetext" ) #Any string (with limitations)
	           ALLOWEDCHARSET='- _<>=+@|�&!?.,: a-z A-Z 0-9'
            echo "$2" | grep -oEe "^[- _<>=+@|�&!?.,:a-zA-Z0-9]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;


	       "x500" ) #Any string (with limitations, to be part of a distinguished name)
	           ALLOWEDCHARSET='- _<>+@|�&!?.,: a-z A-Z 0-9' #All but [='\"/$]
            echo "$2" | grep -oEe "^[- _<>+@|�&!?.,:a-zA-Z0-9]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "dni" ) #ID number
	           ALLOWEDCHARSET='- . a-z A-Z 0-9'
	           echo "$2" | grep -oEe "^[-. 0-9a-zA-Z]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
        "crypfilename" ) #Filename of an encrypted filesystem (base name and a set of numbers)
	           echo "$2" | grep -oEe "^$CRYPTFILENAMEBASE[0-9]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
	       "dev" ) #Path to a device: /dev/sda, hdb, md0...
	           echo "$2" | grep -oEe "^/dev/[shm][a-z]+[0-9]*$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
        
 	       "timezone" ) #Timezone descriptor
	           echo "$2" | grep -oEe "^[-+/a-zA-Z0-9]+$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
         
        * )
	           log "parseInput: Wrong type -$1-" 
	           return 1
	           ;;	
    esac
    
    return $ret
}


#TODO check which vars do not exist anymore (iscsi, nfs, smb), and add new ones if needed

#Check if a certain variable has a proper value (content type is inferred from the variable name)
# $1 -> Variable name
# $2 -> Actual value
#Ret: 0 Ok, value meets the type syntax;  1 wrong value syntax
checkParameter () {
    
    local ret=0
    case "$1" in 
	       
	       "IPMODE" )
	           #Closed set value
	           if [ "$2" != "dhcp"   -a   "$2" != "static" ]
	           then
	               ret=1
	           fi
	           ;;
	       
	       "IPADDR" | "MASK" | "GATEWAY" | "DNS1" | "DNS2" | "ADMINIP" )
	           parseInput ipaddr "$2"
	           ret=$?
            ;;
	       
	       "DOMNAME" | "SERVERCN" )
            parseInput dn "$2"
	           ret=$?
	           ;;

        "HOSTNM" )
            parseInput hostname "$2"
	           ret=$?
	           ;;
	       
	       "TRUEFALSE" | "SYSFROZEN" | "LOCALAUTH" | "USINGCERTBOT" )
            #Closed set value
	           if [ "$2" != "0" -a "$2" != "1" ] ; then
                ret=1
            fi
	           ;;
	       
	       "DRIVEMODE" )
	           #Closed set value
	           if [ "$2" != "local"   -a   "$2" != "file" ] ; then
	               ret=1
	           fi
	           ;;	
	       
	       "DRIVELOCALPATH" | "FILEPATH" | "PATH" )
            parseInput path "$2"
	           ret=$?
	           ;;
	       
        "MAILRELAY" | "SSHBAKSERVER" )
            parseInput ipdn "$2"
	           ret=$?
            ;;
	       
	       "SSHBAKPORT" )
            parseInput port "$2"
	           ret=$?
	           ;;	
        
	       "SSHBAKUSER" | "ADMINNAME" | "USER" )
            parseInput user "$2"
	           ret=$?
	           ;;
	       
	       "DBPWD" | "SSHBAKPASSWD" | "PARTPWD" | "MYSQLROOTPWD" | "DEVPWD" | "MGRPWD" | "LOCALPWD" | "PWD" )
            parseInput pwd "$2"
	           ret=$?
	           ;;
	       
	       "FILEFILESIZE" | "SHARES" | "THRESHOLD" )
            parseInput int "$2"
	           ret=$?
	           ;;
        
	       "INT" ) #This is no variable
            parseInput int0 "$2"
	           ret=$?
	           ;;
	       
	       "CRYPTFILENAME" )
            parseInput crypfilename "$2"
	           ret=$?
	           ;;
        
	       "MGREMAIL" | "SERVEREMAIL" | "SITESEMAIL" )
            parseInput email "$2"
	           ret=$?
	           ;;
        
	       "SITESORGSERV" | "SITESNAMEPURP" | "LANGUAGE" )
            parseInput freetext "$2"
	           ret=$?
	           ;;
        
	       "ADMREALNAME" | "SITESTOKEN")
            parseInput freetext "$2"
	           ret=$?
	           ;;
        
	       "ADMIDNUM" )
            parseInput dni "$2"
	           ret=$?
	           ;;
        
	       "SITESCOUNTRY" | "COUNTRY" )
            parseInput cc "$2"
	           ret=$?
	           ;;
        
	       "KEYSIZE" )
	           if [ "$2" -ne "1024"   -a   "$2" -ne "1152"  -a   "$2" -ne "1280" ]
	           then
	               ret=1
	           fi
	           ;;

        "SSLCERTSTATE" )
	           if [ "$2" != "dummy"   -a   "$2" != "ok"  -a   "$2" != "renew" ]
	           then
	               ret=1
	           fi
	           ;;
        
	       "DEV" ) #This is no variable
            parseInput dev "$2"
	           ret=$?
	           ;;

        "TIMEZONE" )
            parseInput timezone "$2"
	           ret=$?
	           ;;

        "SITESCERT" | "SITESPRIVK" )
            parseInput pem "$2"
	           ret=$?
	           ;;
        
        "SITESEXP" | "SITESMOD" )
            parseInput b64 "$2"
	           ret=$?
	           ;;

        "COMPANY" | "DEPARTMENT" | "STATE" | "LOC" )
            parseInput x500 "$2"
	           ret=$?
	           ;;
        
	       * )
	           log "Not Expected Variable name: $1" 
	           return 1
	           ;;	
	   esac
    
		  [ "$ret" -ne 0 ] && return 1
    return 0	    
}




#Lists all connected usb drives
#Return value: number of drives
#Prints: list of drives
listUSBDrives () {   
    local devs=""
    local ndevs=0
    devs=$($PVOPS listUSBDrives devs list 2>>$LOGFILE)
    ndevs=$($PVOPS listUSBDrives devs count 2>>$LOGFILE)
    log "listUSBDrives ($ndevs): $devs"
    
    echo -n "$devs"
    return $ndevs
}




#Lists all the partitions for a given drive
#1 -> drive path
#Return value: number of partitions
#Prints: list of partitions
getPartitionsForDrive () {
    local parts=$(ls $1* 2>>$LOGFILE | grep -vEe "${1}$" 2>>$LOGFILE)
    local nparts=0
    
    if [ "$parts" != "" ] ; then
        for part in $parts ; do
            nparts=$((nparts+1))
        done
    fi
    
    echo -n $parts
    return $nparts
}




#Lists all connected usb drives and its partitions (either writable or
#not, just need it to be quicker than the other function)
#Return value: number of drives and partitions
#Prints: list of drives and its partitions
listUSBDrivesPartitions () {   
    local devparts=""
    local ndevparts=0
    
    local devs=$(listUSBDrives)
    local parts=''
    for dev in $devs ; do
        parts=$(getPartitionsForDrive $dev)
        local nparts=$?
        
        devparts="$devparts $parts"
        ndevparts=$(( ndevparts + nparts ))
    done
    log "listUSBDrivesPartitions ($ndevparts): $devparts"
    
    echo -n $devparts
    return $ndevparts
}




#Lists all writable partitions from all connected usb drives
#Return value: number of writable partitions
#Prints: list of mountable partitions
listUSBPartitions () {   
    local parts=""
    local nparts=0
    parts=$($PVOPS listUSBDrives parts list 2>>$LOGFILE)
    nparts=$($PVOPS listUSBDrives parts count 2>>$LOGFILE)
    log "listUSBPartitions ($nparts): $parts"
    
    echo -n "$parts"
    return $nparts
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


#Generate a true random password
# $1 -> Length in chars for the password (optional)
#Stdout: the generated password
randomPassword () {
    local pwlen=91
    [ "$1" != "" ] && pwlen="$1"
    
    local pw=""
    while [ "$pw" == "" ]
    do
        #Substitute b64 non-alpha chars (+ -> .  / -> - ) to avoid escape issues
        #Also, delete trailing = as it could affect the entropy of the result
        pw=$(openssl rand -rand $RANDFILE -base64 $((pwlen*2))  2>>$LOGFILE \
                    | tr "+/" ".-" | sed -e "s/ //g" | sed -e "s/=//g")
        
        #Take only the number of desired characters
        pw=$(echo $pw | cut -c1-$pwlen)
    done
    #Return it
    echo -n $pw
}



#Compares two files using the sha1 digest algorithm
#1 -> first file path
#2 -> second file path
#Return: 0 if equals, 1 otherwise
compareFiles () {
    
    #If one file does not exist, return no-match
    [ ! -e "$1" ] && return 1
    [ ! -e "$2" ] && return 1
    
    #Calculate digests
    local firstDigest=$(sha1sum "$1" | cut -d " " -f 1 | tr -d "\n" )
    local secondDigest=$(sha1sum "$2" | cut -d " " -f 1 | tr -d "\n" )
    
    #See if they match
    [ "$firstDigest" == "$secondDigest" ] && return 0
    return 1
}



#Detect removal of a usb device
# $1 -> The dev path to oversee
# $2 -> Message to show
# $3 -> The "you didn't remove it" message
detectUsbExtraction (){
    local didnt=""
    
    #While dev is on the list of usbs, refresh and wait
    local locdev=$( listUSBDrivesPartitions | grep -o "$1" )
    while [ "$locdev" != "" ] ; do
        $dlg --msgbox "$2""\n$didnt"  0 0
        
        locdev=$( listUSBDrivesPartitions | grep -o "$1" )
        didnt="$3"
    done
}




#Detect insertion of a usb device
# $1 --> "Insert device" message.
# $2 --> "No" label message
#$USBDEV: dev path of the inserted usb device or partition
#Return code 0: selected device/partition is writable
#            1: nothing selected/insertion cancelled (the 'no' option has been selected)
#            2: selected device needs to be formatted
insertUSB () {
    
    $dlg --yes-label $"Continue" --no-label "$2"  --yesno "$1" 0 0
    [ $? -ne 0 ]  &&  return 1 #Insertion cancelled
    
    while true 
    do
        #Loop until one usb device is connected
        local usbs=''
        usbs=$(listUSBDrives 2>/dev/null)
        local nusbs=$?
        if [ $nusbs -lt 1 ]
	       then
            $dlg --yes-label $"OK" --no-label "$2" \
                 --yesno $"Not inserted. Please, do it and press OK." 0 0
            [ $? -ne 0 ]  &&  break
            continue
            
        #If more than one usb device is detected, ask to leave just one and loop
        elif [ $nusbs -gt 1 ]
	       then
            $dlg --yes-label $"OK" --no-label "$2" \
                 --yesno $"More than one usb device detected. Please, remove all but one and press OK."  0 0
            [ $? -ne 0 ]  &&  break
            continue
        fi
        
        #Detect all writable partitions
        local parts=''
        parts=$(listUSBPartitions 2>/dev/null)
        local nparts=$?
        if [ $nparts -le 0 ]
	       then
            #One device, no writable partitions: return it and mark that format is needed
            USBDEV=$usbs
            return 2
            
        elif [ $nparts -eq 1 ]
	       then
            #One device, with one writable partition: return it
            USBDEV=$parts
            return 0

        else
            #More than one writable partition on the device. Let user select which one
            local options=""
            for p in $parts
            do
                options="$options $p"
            done

            exec 4>&1
            local part=''
            part=$($dlg --no-items --cancel-label "$2" --menu $"Choose one partition:" 0 0 3 $options  2>&1 >&4)
            [ $? -ne 0 -o "$part" == ""  ] && break #Cancel
            
            USBDEV=$part
            return 0
        fi
        
        break
    done
    
    return 1
}



#Convert a hexadecimal string (from stdin) into base64 (to stdout)
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


#Trust a ssh server key
#1 -> SSH server address
#2 -> SSH server port
#Depends on the $HOME variable
sshScanAndTrust () {
    local ret=0
    log "SSH scanning... $1:$2"
    
    if [ ! -e $HOME/.ssh/ ] ; then
        mkdir $HOME/.ssh/      >>$LOGFILE 2>>$LOGFILE
        chmod 755 $HOME/.ssh/  >>$LOGFILE 2>>$LOGFILE
    fi
    if [ ! -e $HOME/.ssh/known_hosts ] ; then
        touch $HOME/.ssh/known_hosts      >>$LOGFILE 2>>$LOGFILE
        chmod 644 $HOME/.ssh/known_hosts  >>$LOGFILE 2>>$LOGFILE
    fi

    #Delete any previous appearance of the host in the known_hosts
    ssh-keygen -f $HOME/.ssh/known_hosts -R "$1" >>$LOGFILE 2>>$LOGFILE
    
    #Scan for the server's keys and append them to the user's know hosts file
    #rsa1 disabled for security reasons
    ssh-keyscan -p "$2" -t rsa,ecdsa,ed25519,dsa "$1" >> $HOME/.ssh/known_hosts  2>>$LOGFILE
    ret=$?
    
    return $ret
}

#Does a SSH connection on a given server and user and executes a
#remote command. If no command is specified, it simply does a test
#connection.
#1 -> SSH server address
#2 -> SSH server port
#3 -> Username
#4 -> Remote user password
#5 -> (optional) Remote command to execute
#Return: the return code of the executed command if connection was successful
#STDOUT: the output of the command
sshRemoteCommand () {
    local ret=0

    remoteCommand="$5"
    [ "$remoteCommand" == "" ] && remoteCommand="ls"
    
    #Do a SSH connection and execute the command
		  #log "ssh -n  -p '$2'  '$3'@'$1'"
		  sshpass -p"$4" ssh -n -p "$2"  "$3"@"$1" "$remoteCommand" 2>>$LOGFILE
    ret=$?
    
    if [ $ret  -ne 0 ] ; then
        log "SSH Connection error: $ret"
        ret=1
		  fi
    
    return $ret
}





#Returns the currently configured IP address (for when it is needed
#and network config is dhcp)
#STDOUT: own IP address
getOwnIP () {
    /sbin/ifconfig | grep -Ee "^eth" -A 1 |
        grep -Ee "inet addr" |
        sed -re  "s/^.*inet addr:([^\s]+)\s.*$/\1/g" |
        tr -d "\n "
}





#List active eth interfaces
getEthInterfaces () {
    /sbin/ifconfig -s  2>/dev/null  | cut -d " " -f1 | grep -oEe "eth[0-9]+"
}
