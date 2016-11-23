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


#Default SSH port
DEFSSHPORT=22


#Buffer to pass return strings between the privileged script and the
#user script when stdout is locked by dialog
RETBUFFER=$TMPDIR/returnBuffer



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


#Check if a string matches the syntax restrictions of some data type
# $1 --> expected data type
# $2 --> input value string
#Returns 0 if matching data type, 1 otherwise.
#ALLOWEDCHARSET: If not matching, the allowed charset information for the data
#type is set there in some cases  # TODO: review that all calls comply with this.
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
        
	       "cc" ) #Two letter country code (no use in checking the whole set)
	           echo "$2" | grep -oEe "^[a-zA-Z][a-zA-Z]$" 2>&1 >/dev/null
	           [ $? -ne 0 ] && ret=1
	           ;;
	       
	       "freetext" ) #Any string (with limitations)
	           ALLOWEDCHARSET='- _<>=+@|�&!?.,: a-z A-Z 0-9'
            echo "$2" | grep -oEe "^[- _<>=+@|�&!?.,:a-zA-Z0-9]+$" 2>&1 >/dev/null
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
	           echo "parseInput: Wrong type -$1-"  >>$LOGFILE 2>>$LOGFILE
	           return 1
	           ;;	
    esac
    
    return $ret
}


#TODO check which vars do not exist anymore (iscsi, nfs, smb), and add news if needed

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

    local ret=0
    case "$1" in 
	       
	       "IPMODE" )
	           #Closed set value
	           if [ "$2" != "dhcp"   -a   "$2" != "static" ]
	           then
	               ret=1
	           fi
	           ;;
	       
	       "IPADDR" | "MASK" | "GATEWAY" | "DNS1" | "DNS2"  )
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
	       
	       "TRUEFALSE" )  #This is no variable
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
	       
	       "DRIVELOCALPATH" | "FILEPATH" )
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
        
	       "SSHBAKUSER" | "ADMINNAME" )
            parseInput user "$2"
	           ret=$?
	           ;;
	       
	       "DBPWD" | "SSHBAKPASSWD" | "PARTPWD" | "MYSQLROOTPWD" | "DEVPWD" | "MGRPWD" | "LOCALPWD" )
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
        
	       "MGREMAIL" | "SERVEREMAIL" )
            parseInput email "$2"
	           ret=$?
	           ;;
        
	       "SITESORGSERV" | "SITESNAMEPURP" )
            parseInput freetext "$2"
	           ret=$?
	           ;;
        
	       "ADMREALNAME" )
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
        
	       "DEV" ) #This is no variable
            parseInput dev "$2"
	           ret=$?
	           ;;

        "TIMEZONE" )
            parseInput timezone "$2"
	           ret=$?
	           ;;
        
	       * )
	           echo "Not Expected Variable name: $1"  >>$LOGFILE 2>>$LOGFILE
	           return 1
	           ;;	
	   esac
    
		  [ "$ret" -ne 0 ] && return 1
    return 0	    
}




#Function to pass return strings between the privileged script and the
#user script when stdout is locked by dialog
# $1 -> return string
doReturn () {
    rm -f $RETBUFFER     >>$LOGFILE 2>>$LOGFILE
    touch $RETBUFFER >>$LOGFILE 2>>$LOGFILE    
    chmod 644 $RETBUFFER >>$LOGFILE 2>>$LOGFILE    
    echo -n "$1" > $RETBUFFER
}


#Print and delete the last string returned by a privileged op   # TODO probably will be useless. check usage, and try to delete it
getReturn () {
    if [ -e "$RETBUFFER" ]
	   then
	       cat "$RETBUFFER"  2>>$LOGFILE
        rm -f $RETBUFFER  >>$LOGFILE 2>>$LOGFILE
    fi
}




#Lists all connected usb drives
#Return value: number of drives
#Prints: list of drives
listUSBDrives () {   
    local devs=""
    local ndevs=0
    devs=$($PVOPS listUSBDrives devs list 2>>$LOGFILE)
    ndevs=$($PVOPS listUSBDrives devs count 2>>$LOGFILE)
    
    echo -n "$devs"
    return ndevs
}

#Lists all writable partitions from all connected usb drives
#Return value: number of writable partitions
#Prints: list of writable partitions
listUSBPartitions () {   
    local parts=""
    local nparts=0
    parts=$($PVOPS listUSBDrives parts list 2>>$LOGFILE)
    nparts=$($PVOPS listUSBDrives parts count 2>>$LOGFILE)
    
    echo -n "$parts"
    return nparts
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
randomPassword () { # TODO eliminar usos var $pw
    pwlen=91
    [ "$1" != "" ] && pwlen="$1"
    
    pw=""
    while [ "$pw" == "" ]
      do
      pw=$(openssl rand -rand $RANDFILE -base64 $pwlen  2>>$LOGFILE)
      pw=$(echo $pw | sed -e "s/ //g")
      #Substitute b64 non-alpha chars (+ -> .  / -> -  = -> :) to avoid escape issues
      pw=$(echo $pw | sed -e "s/\+/./g")
      pw=$(echo $pw | sed -e "s/\//-/g")
      pw=$(echo $pw | sed -e "s/=/:/g")
    done
}


#Detect removal of a usb device
# $1 -> The dev path to oversee
# $2 -> Message to show
# $3 -> The "you didn't remove it" message
detectUsbExtraction (){    
    didnt=""
    
    #While dev is on the list of usbs, refresh and wait
    locdev=$( listUSBDrives | grep -o "$1" )
    while [ "$locdev" != "" ] ; do
        $dlg --msgbox "$2""\n$didnt"  0 0
        
        locdev=$( listUSBDrives | grep -o "$1" )
        didnt="$3"
    done
}




#Detect insertion of a usb device
# $1 --> "Insert device" message.
# $2 --> "No" label message.
#$USBDEV: dev path of the inserted usb device or partition
#Return code 0: selected device/partition is writable
#            1: nothing selected/insertion cancelled (the 'no' option has been selected)
#            2: selected device needs to be formatted
insertUSB () {  # TODO extinguish usage of $DEV and $ISCLAUER
    
	   $dlg --yes-label $"Continue" --no-label "$2"  --yesno "$1" 0 0
    
    #Insertion cancelled
	   [ $? -ne 0 ]  &&  return 1
    
    while true 
    do
        #Loop until one usb device is connected
        local usbs=$(listUSBDrives 2>/dev/null)
        local nusbs=$?
        if [ $nusbs -lt 1 ]
	       then
            $dlg --no-label "$2" --yesno $"Not inserted. Please, do it and press OK." 0 0
            [ $? -ne 0 ]  &&  break
            continue
            
            #If more than one usb device is detected, ask to leave just one and loop
        elif [ $nusbs -gt 1 ]
	       then
            $dlg --no-label "$2" --yesno $"More than one usb device detected. Please, remove all but one and press OK."  0 0
            [ $? -ne 0 ]  &&  break
            continue
        fi
        
        #Detect all writable partitions
        local parts=$(listUSBPartitions 2>/dev/null)
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
                options="$options $p -"
            done

            exec 4>&1
            local part=$($dlg --cancel-label "$2" --menu $"Choose one partition:" 0 0 3 $options  2>&1 >&4)
            [ $? -ne 0 ] && break
            
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
    local ret="$?"
    
    return $ret
}

#Does a test connection on a given SSH server and user
#1 -> SSH server address
#2 -> SSH server port
#3 -> Username
#4 -> Remote user password
#Depends on the $HOME variable
sshTestConnect () {

    local dispbak=$DISPLAY
    local sshapbak=$SSH_ASKPASS
		  export DISPLAY=none:0.0
		  export SSH_ASKPASS=$HOME/askPass.sh
    
    #Set password provision script
		  echo "echo '$4'" > $HOME/askPass.sh
		  chmod u+x  $HOME/askPass.sh >>$LOGFILE 2>>$LOGFILE

    #Do a SSH connection
		  echo "ssh -n  -p '$2'  '$3'@'$1'" >>$LOGFILE 2>>$LOGFILE
		  ssh -n  -p "$2"  "$3"@"$1" >>$LOGFILE 2>>$LOGFILE
		  ret="$?"
		  if [ "$ret"  -ne 0 ] ; then
        echo "SSH Connection error: $ret" >>$LOGFILE 2>>$LOGFILE
        return 1
		  fi
    
    #Erase password provision script
		  rm $HOME/askPass.sh >>$LOGFILE 2>>$LOGFILE
    
    #Restore environment
    export DISPLAY=$dispbak
    export SSH_ASKPASS=$sshapbak
    
    return 0
}
