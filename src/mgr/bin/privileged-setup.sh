#!/bin/bash

#This script contains all the setup actions that need to be executed
#by root. They are invoked through calls. No need for authorisation as
#on this phase, system is being monitored by the committee. After
#setup, user won't be able to call it again.



#### INCLUDES ####

#System firewall functions
. /usr/local/bin/firewall.sh

#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh








#Log function
log () {
    echo "["$(date --rfc-3339=ns)"][privileged-setup]: "$*  >>$LOGFILE 2>>$LOGFILE
}


#Move logs to the encrypted persistent drive
# $1 -> 'new' o 'reset'
relocateLogs () {
    
    #Stop all services that might be logging
    RESTARTMYSQL=0
    RESTARTAPACHE=0

    if isRunning mysqld
	   then
	       /etc/init.d/mysql stop >>$LOGFILE 2>>$LOGFILE 
	       RESTARTMYSQL=1
    fi
    if isRunning apache2
	   then
	       /etc/init.d/apache2 stop >>$LOGFILE 2>>$LOGFILE 
	       RESTARTAPACHE=1
    fi
    
    /etc/init.d/rsyslog stop >>$LOGFILE 2>>$LOGFILE 
    
    #If new, move /var/log to the ciphered partition
    if [ "$1" == "new"  ] ; then
	       mv /var/log $DATAPATH >>$LOGFILE 2>>$LOGFILE 
    else
        #If reset, save boot process logs in a temporary dir in case
	       #they are needed.
	       mv /var/log /var/currbootlogs >>$LOGFILE 2>>$LOGFILE 
    fi
    #Substitute them with the ones on the ciphered partition
    ln -s $DATAPATH/log /var/log >>$LOGFILE 2>>$LOGFILE 
    
    #Restore stopped services
    /etc/init.d/rsyslog start >>$LOGFILE 2>>$LOGFILE 
    
    if [ "$RESTARTMYSQL" -eq "1" ] ; then
	       /etc/init.d/mysql start >>$LOGFILE 2>>$LOGFILE
    fi
    if [ "$RESTARTAPACHE" -eq "1" ] ; then
	       /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE 
    fi
}





privilegedSetupPhase1 () {
    
    #Init log (unprivileged user can write but not read, nor copy, delete or substitute it, as /tmp has sticky bit).
    echo "vtUJI $VERSION LogFile" >  $LOGFILE
    echo "===============================" >> $LOGFILE
    chown root:root $LOGFILE
    chmod 622 $LOGFILE
    
    
    #It is set on startup, in /etc/init.d/networking, but just in case, we call it again here
    setupFirewall >>$LOGFILE 2>>$LOGFILE
    
    
    #Configure lm-sensors sensors. Detect modules to be loaded and load them
    modsToLoad=$(echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" | sensors-detect | sed -re "1, /^# Chip drivers$/ d" -e "/#----cut here----/,$ d")
    for module in $modsToLoad; do modprobe $module; done;
    
    
    
    ##### Configure SMARTmonTools #####
     
    #List hard drives
    hdds=$(listHDDs)
    
    #Write list of HDDs to be monitored on the config file
    sed -i -re "s|(enable_smart=\").+$|\1$hdds\"|g" /etc/default/smartmontools >>$LOGFILE 2>>$LOGFILE
    
    #Reload SMART daemon
    /etc/init.d/smartmontools stop   >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/smartmontools start  >>$LOGFILE 2>>$LOGFILE


    #Disable kernel logging to the terminal (to avoid annoying messages between and over dialogs)
    sysctl -w kernel.printk="1 1 1 1"
    
    
    ##### Prepare display #####
    
    # Clear terminal 7 (and 1 just in case), so no text is seen after plymouth quits
    #<RELEASE>
    clear > /dev/tty7
    clear > /dev/tty1
    #</RELEASE>
    
    #Kill plymouth (if alive) so we can show the curses GUI
    plymouth quit
    
    #Jump to terminal 7 (the graphic one, where we run our curses GUI)
    chvt 7


    ##### Last pre-setup steps #####
    
    #Create dir where usbs will be mounted
	   mkdir -p  /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
    chmod 755 /media/usbdrive
    
    #Create root home dir structures
    mkdir -p /root/log    >>$LOGFILE 2>>$LOGFILE
    mkdir -p /root/stats  >>$LOGFILE 2>>$LOGFILE
    mkdir -p /root/tmp    >>$LOGFILE 2>>$LOGFILE  # TODO ver que con el umask, other no tiene permisos.

    #Prepare root user tmp dir
    chmod 700 $ROOTTMP/ >>$LOGFILE 2>>$LOGFILE
    $PVOPS storops-init
    
    #Unlock privileged operations during setup
    echo -n "0" > $LOCKOPSFILE
    chmod 400 $LOCKOPSFILE
    
    #Prepare whitelist file
    touch /etc/whitelist
    chmod 644 /etc/whitelist
}






#Copies all of the filesystem to RAM. This way, it cannot be altered
#by a CD-ROM substitution.
#1-> 1: force copy, even if only a dangerously low memory amount is available.
moveToRAM () {
    
    ###################################################################
    # To avoid tampering, we will copy all the CD filesystem to RAM,  #
    # but we need a minimum extra memory.                             #
    # [Already using kernel toram option, but this will act as a      #
    # double check and will also allow for a finer control when toram #
    # option fails due to tight memory conditions]                    #
    ###################################################################
    exec 4>&1 
    
    #Calculate free space (in MB) for the aufs (the stackable root filesystem)
    local aufsSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 2)
    local aufsFreeSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)

    #Calculate size (in MB) of the uncompressed CD filesystem
    local cdfsSize=$(du -ms /lib/live/mount/rootfs/ | cut -f 1)

    #Size of the CD and a 30% of the original free space (the pad free space we leave)
    local cdandpad=$(python -c "print int( $cdfsSize + $aufsSize*0.3 )")
    
    
    #If not enough free space, return
    if [ "$aufsSize" -lt "$cdfsSize" ] ; then
        setVar copyOnRAM "0" mem
        return 1
    fi
    
    
    #If copying the CD doesn't leave at least a 30% of the aufs
    #original free space or aufs is smaller than a constant, let the
    #user decide (must call again with the force parameter)
    if [ "$aufsSize" -lt $MINAUFSSIZE -o  "$aufsFreeSize" -lt "$cdandpad" ]
    then
        #If force not activated, return and let decide
        if [ "$1" -ne 1 ] ; then
            setVar copyOnRAM "0" mem
            return 2
        fi
        
        #If forced, go on
    fi
	   
    #Copy the filesystem to RAM
	   find /  -xdev -type f -print0 | xargs -0 touch # TODO test if this double copies the CD (through the path /lib/live/mount/ ). Check on a 4GB system before and after
    
    #Mark that it was copied
    setVar copyOnRAM "1" mem
    
    return 0
}









privilegedSetupPhase4 () {
    
    #Add administrator's IP to the whitelist (also done on setAdmin)
    getVar disk ADMINIP
    echo "$ADMINIP" >> /etc/whitelist
    
    #Load initial whitelist
	   bash /usr/local/bin/whitelistLCN.sh >>$LOGFILE 2>>$LOGFILE
    bash /usr/local/bin/updateWhitelist.sh >>$LOGFILE 2>>$LOGFILE
    
    
    #Test the RAID arrays, if any, and generate a test message for the administrator
    mdadm --monitor  --scan  --oneshot --syslog --mail=root  --test  >>$LOGFILE 2>>$LOGFILE
    #If RAIDS are found, Warn the admin that he must receive an e-mail with the test  # TODO Make sure mailer is configured by now
    mdadm --examine --scan --config=partitions >/tmp/mdadm.conf  2>>$LOGFILE
    if [ "$(cat /tmp/mdadm.conf)" != "" ] 
	   then
        # Not an error, just to tell that the user must be warned of
        # the incoming e-mail
	       return 1
    fi
    
    return 0
}





privilegedSetupPhase5 () {
    
    # TODO add some more useful info on the e-mail?
    emailAdministrator $"Test" $"This is a test e-mail to check that the messaging system works end to end."
    
    ### Now, neuter the setup scripts to reduce attack vectors ###
    
    #Remove sudo capabilities to privileged setup so it cannot be invoked by user
    #(actually, removing all items from the sudo line but the first, which is privileged-ops and actually needed)
    sed -i -re 's|(^\s*vtuji\s*ALL.*NOPASSWD:[^,]+),.*$|\1|g' /etc/sudoers  >>$LOGFILE 2>>$LOGFILE
    
    #Remove read and execution permissions on wizard
    chmod 550 /usr/local/bin/wizard-setup.sh
}









######################
##   Main program   ##
######################


#Which action is invoked
if [ "$1" == "init1" ]
then
    privilegedSetupPhase1
    exit 0
fi




#2 -> force copy on low memory situation
if [ "$1" == "moveToRAM" ]
then
    moveToRAM "$2"
    exit $?
fi




if [ "$1" == "forceTimeAdjust" ]
then
    forceTimeAdjust
    exit 0
fi



#If there are RAID arrays, will return 1 to warn the user of the
#incoming e-mail with the RAID test results
if [ "$1" == "init4" ]
then
    privilegedSetupPhase4
    exit $?
fi




#Activate privileged operations execution lock. Any op invoked from
#now on will first check for a valid rebuilt cipherkey or for admin
#password
if [ "$1" == "lockOperations" ]
then
    echo -n "1" > $LOCKOPSFILE
    exit 0
fi




if [ "$1" == "init5" ]
then
    privilegedSetupPhase5
    exit 0
fi    



    
#System logs are relocated from the RAM fs to the ciphered partition on the hard drive
if [ "$1" == "relocateLogs" ]
then
    if [ "$2" != "new" -a "$2" != "reset" ] ; then
	       log "relocateLogs: Bad parameter"
	       exit 1
    fi
    relocateLogs "$2"
    exit 0
fi



    
#Set admin e-mail as the recipient for all system notification e-mails
if [ "$1" == "setupNotificationMails" ]
then
    getVar disk MGREMAIL
    
    setNotifcationEmail "$MGREMAIL"
    
    exit 0
fi    



    
#loads a keyboard keymap
if [ "$1" == "loadkeys" ]
then
    loadkeys "$2"  >>$LOGFILE 2>>$LOGFILE
    exit 0
fi    




#Configure pm-utils to be able to suspend the computer
if [ "$1" == "pmutils" ] 
then
    #Reinstall and reconfigure package
    dpkg -i /usr/local/bin/pm-utils*  >>$LOGFILE  2>>$LOGFILE
    exit 0
fi    




#If there are RAIDS, check them before doing anything else
if [ "$1" == "checkRAIDs" ]
then
    checkRAIDs
    exit $?
fi    
    

    

#Setup timezone and store variable
if [ "$1" == "setupTimezone" ]
then
    #Check passed timezone
    checkParameterOrDie TIMEZONE "$2"
    
    echo "$TIMEZONE" > /etc/timezone
    rm -f /etc/localtime
    ln -s "/usr/share/zoneinfo/right/$TIMEZONE" /etc/localtime
    exit 0
fi        




#Set the value of the variable on the specified variable storage.
# $2 -> Destination: 'disk' persistent disk;
#                    'mem'  (default) or nothing if we want it in ram;
#                    'usb'  if we want it on the usb config file;
#                    'slot' in the active slot configuration
# $3 -> variable
# $4 -> value
if [ "$1" == "setVar" ] 
then
    # TODO Define a list of variables that won't be writable once system is locked (despite having clearance to execute the operation)
    
    checkParameterOrDie "$3" "$4" 0  # TODO make sure that in all calls to this op, the var is in checkParameter.
    setVar "$3" "$4" "$2"
    exit 0
fi





#Get the value of the variable on the specified variable storage.
# $2 -> Destination: 'disk' persistent disk;
#                    'mem'  (default) or nothing if we want it in ram;
#                    'usb'  if we want it on the usb config file;
#                    'slot' in the active slot configuration
# $3 -> variable
if [ "$1" == "getVar" ]
then
    getVar "$2" "$3" aux
    echo -n $aux
    exit 0
fi





#Prepares the database to be loaded from the ciphered partition ( on
#install it will generate passwords and move the database to the
#ciphered partition)
#2 ->  'new' if this is an installation 
#    'reset' if just reloading
if [ "$1" == "setupDatabase" ] 
then
    if [ "$2" != 'new' -a "$2" != 'reset' ] ; then 
	       log "setupDatabase: param error: $2"  
	       exit 1
    fi
    
    
    #Just in case it is running
    /etc/init.d/mysql stop  >>$LOGFILE 2>>$LOGFILE

    
    if [ "$2" == 'new' ]
	   then
	       #If installing, move the whole mysql directory to the ciphered
	       #persistence drive
	       rm -rf $DATAPATH/mysql 2>/dev/null >/dev/null
	       cp -rp /var/lib/mysql $DATAPATH/
	       [ $? -ne 0 ] &&  exit 2 # not enough free space 
        
        #If copy is successful, change permissions
	       chown -R mysql:mysql $DATAPATH/mysql/
    fi
    
    
    #Change mysql config to point to the new data dir # TODO if using SELinux, this may require some additional configuration
    sed -i -re "/datadir/ s|/var/lib/mysql.*|$DATAPATH/mysql|g" /etc/mysql/my.cnf
    
    #Start mysql 
    /etc/init.d/mysql start >>$LOGFILE 2>>$LOGFILE
    [ $? -ne 0 ] &&  exit 3
    
    
    if [ "$2" == 'new' ]
	   then
        #Generate and store non-privileged database password
        DBPWD=$(randomPassword 15)
        [ "$DBPWD" == ""  ] &&  exit 4
        setVar DBPWD "$DBPWD" disk
        
        
        #Generate and store root database password
        MYSQLROOTPWD=$(randomPassword 20)
        [ "$MYSQLROOTPWD" == ""  ] &&  exit 4
        echo -n "$MYSQLROOTPWD" > $DBROOTPWDFILE
        chmod 600 $DBROOTPWDFILE >>$LOGFILE 2>>$LOGFILE
        
        
        #Change database default root password
        mysqladmin -u root -p'defaultpassword' password "$MYSQLROOTPWD" 2>>$SQLLOGFILE
        [ $? -ne 0 ] &&  exit 4
        
        #Create user, schema, set privileges and password and refresh passwords
        mysql -u root -p"$MYSQLROOTPWD" mysql 2>>$SQLLOGFILE  <<-EOF
          CREATE DATABASE eLection;
          CREATE USER 'election'@'localhost' 
            IDENTIFIED BY '$DBPWD';
          GRANT SELECT, INSERT, UPDATE, DELETE, ALTER, CREATE TEMPORARY TABLES, DROP, CREATE 
            ON eLection.* TO election@localhost;
          FLUSH PRIVILEGES;
EOF
        [ $? -ne 0 ] &&  exit 4
    fi
    
    exit 0
fi




# Generates ballot box RSA keys and stores them on the database
if [ "$1" == "generateBallotBoxKeys" ]
then
    getVar disk KEYSIZE
    
    #Generate RSA keys
    keyyU=$(openssl genrsa $KEYSIZE 2>>$SQLLOGFILE | openssl rsa -text 2>>$SQLLOGFILE)

    #Extract mod and exp
	   modU=$(echo -n "$keyyU" | sed -e "1,/^modulus/ d" -e "/^publicExponent/,$ d" | tr -c -d 'a-f0-9' | sed -e "s/^00//" | hex2b64)
	   expU=$(echo -n "$keyyU" | sed -n -e "s/^publicExponent.*(0x\(.*\))/\1/p" | hex2b64)
	   
	   keyyU=$(echo "$keyyU" | sed -n -e "/BEGIN/,/KEY/p")
    
	   
    #Insert ballot box key into database
    # modU -> bb module (B64)
    # expU -> bb public exponent (B64)
    # keyyU -> bb private key. (PEM)
	   dbQuery "update eVotDat set modU='$modU', expU='$expU', keyyU='$keyyU';"
    exit $?
fi




#Sets other web application configurations
if [ "$1" == "setWebAppDbConfig" ]
then
    getVar disk TIMEZONE
    
    #Set the timezone on the web app
	   dbQuery "update eVotDat set TZ='$TIMEZONE';"
    exit $?
fi




#Run the script that creates the tables and sets the default data on
#the web app database
if [ "$1" == "populateDB" ]
then
    #Run the script (-f to go on despite errors, as the script
    #executes some alters for backwards compatibility). No error
    #control can be performed here and dbQuery cannot be used.
    getVar disk DBPWD
    log "Executing buildDB.sql"
    cat /usr/local/bin/buildDB.sql |
        mysql -f -u election -p"$DBPWD" eLection 2>>$SQLLOGFILE
    
    #Configure the Certificate authentication method
    getVar disk SERVERCN
    dbQuery "update eVotMetAut set nomA='Certificate'," \
            "tipEx=1, disp=1," \
            "urlA='https://$SERVERCN/auth/certAuth/certAuth.php'" \
            "where idH=11;"
    exit $?
fi





#Create a self-signed certificate from the pending certificate request
#(and also the CA chain)
if [ "$1" == "generateSelfSigned" ] 
then
    #Generate self-signed certificate
    openssl x509 -req -days 3650 \
            -in      $DATAPATH/webserver/server.csr \
            -signkey $DATAPATH/webserver/server.key \
            -out     $DATAPATH/webserver/server.crt   >>$LOGFILE 2>>$LOGFILE
    
    #Set the same certificate as the CA chain
	   cp $DATAPATH/webserver/server.crt $DATAPATH/webserver/ca_chain.pem  >>$LOGFILE 2>>$LOGFILE
    
    exit 0
fi





#Recover the system persistent data from a backup file retrieved
#through SSH
#2 -> ssh server address
#3 -> ssh server port
#4 -> ssh server user
#5 -> ssh server user password
#6 -> path of the backup file to retrieve (on the remote ssh server)
#RETURN:  0 if OK, 1 if error
if [ "$1" == "restoreBackup" ]
then 
    
    sshserver="$2"
    sshport="$3"
    sshuser="$4"
    sshpasswd="$5"
    sshfilepath="$6"
    
    
    #Get the active slot
    getVar mem CURRENTSLOT
    slotPath=$ROOTTMP/slot$CURRENTSLOT/
    
    
    #Get the old key (the one used to encrypt the file we are
    #about to retrieve) from the active key slot
    DATABAKPWD=$(cat $slotPath/key)
    
    
    #Set trust on the server
    sshScanAndTrust "$sshserver"  "$sshport"
    if [ $? -ne 0 ] ; then
        log "SSH Keyscan error."
        exit 1
		  fi
    
    
    #Retrieve the backup file, decrypt and untar it on the persistence
    #drive. All of this, streamlined.
    sshRemoteCommand  "$sshserver"  "$sshport"  "$sshuser"  "$sshpasswd" "cat '$sshfilepath'" |
        openssl enc -d  -aes-256-cfb  -pass "pass:$DATABAKPWD"  2>>$LOGFILE |
        tar xzf - -C /  2>>$LOGFILE
    
    if [ $? -ne 0 ] ; then
        log "Failed backup copy retrieval and recovery."
        exit 1
    fi
    
    # TODO asegurarme de que la base folder es /, para ello, el tar debe contener un /media/crypStorage, que creo que sí porque en el tar de backup, la ruta es absoluta
    
    
    #Move database dump to volatile memory. This way, if any
    #intervention is necessary, the dump is available, otherwise, it
    #will be deleted on system shutdown and it won't be accumulated on
    #future backups
    mv  $DATAPATH/dump.*  /root/
    
    #Also, add a help readme for the admin
    echo "#Commands to restore the database dump." >/root/dump.readme
    echo "#If needed, drop database first and recreate it." >>/root/dump.readme
    echo 'mysql -f -u root -p$(cat '$DBROOTPWDFILE') eLection  <"/root/dump.*"' >>/root/dump.readme
    
    exit 0
fi    










log "Bad privileged setup operation: $1"
exit 42
