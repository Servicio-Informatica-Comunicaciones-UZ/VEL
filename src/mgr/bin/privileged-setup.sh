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
	   mkdir -p /media/usbdrive  >>$LOGFILE 2>>$LOGFILE
    
    #Prepare root user tmp dir
    chmod 700 $ROOTTMP/ >>$LOGFILE 2>>$LOGFILE
    $PVOPS storops init
}








moveToRAM () {
    
    ###################################################################
    # To avoid tampering, we will copy all the CD filesystem to RAM,  #
    # but we need a minimum extra memory.                             #
    # [Already using kernel toram option, but this will act as a      #
    # double check and will also allow for a finer control when toram #
    # option fails due to tight memory conditions]                    #
    ###################################################################
    exec 4>&1 
    $dlg  --msgbox $"To avoid tampering, all the CD content will be loaded to RAM memory" 0 0
    local copyOnRAM=1    
    
    #Calculate free space (in MB) for the aufs (the stackable root filesystem)
    local aufsSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 2)
    local aufsFreeSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)

    #Calculate size (in MB) of the uncompressed CD filesystem
    local cdfsSize=$(du -s /lib/live/mount/rootfs/ | cut -f 1)

    #Size of the CD
    local cdandpad=$(python -c "print int( $cdfsSize + $aufsSize*0.3 )")
    
    
    #If not enough free space, return
    if [ "$aufsSize" -lt $cdfsSize ]
    then
	       $dlg  --msgbox $"Not enough free memory. CD content won't be copied. System physical tampering protection cannot be assured." 0 0
	       copyOnRAM=0
        
    #If copying the CD doesn't leave at least a 30% of the aufs
    #original free space or aufs is smaller than a constant, let the
    #user decide
    elif [ "$aufsSize" -lt $MINAUFSSIZE -o  "$aufsFreeSize" -lt "$cdandpad" ]
	   then
	       copyOnRAM=0
        
	       $dlg --yes-label $"Copy"  --no-label $"Do not copy" --yesno  $"Amount of free memory may be insufficient for a proper functioning in certain conditions.""\n\n"$"Available memory:"" $aufsFreeSize MB\n"$"Size of the CD filesystem:"" $cdfsSize MB\n\n"$"Copy the system if you belive usage won't be affected" 0 0
        [ "$?" -eq 0  ] && copyOnRAM=1    
	   fi
	   
    if [ "$copyOnRAM" -eq 1 ]
	   then
        #Copy the filesystem to RAM
	       $dlg --infobox $"Copying CD filesystem to system memory..."  0 0
	       find /  -xdev -type f -print0 | xargs -0 touch
	       
        #Calculate available space at the end
	       local aufsFinalFreeSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)
        $dlg --msgbox $"Copy successful.""\n\n"$"Still available RAM filesystem space:"" $aufsFinalFreeSize MB." 0 0
    fi
    #Persist this variable (to the memory config file)
    setPrivVar copyOnRAM "$copyOnRAM" r
    
    #Workaround. This directory may not be listable despite the proper permissions  # TODO commented out. If problems detected, uncomment, otherwise, delete
#    mv /var/www /var/aux >>$LOGFILE 2>>$LOGFILE
#    mkdir /var/www >>$LOGFILE 2>>$LOGFILE
#    chmod a+rx /var/www >>$LOGFILE 2>>$LOGFILE
#    mv /var/aux/* /var/www/  >>$LOGFILE 2>>$LOGFILE
#    chmod 550 /var/www/ >>$LOGFILE 2>>$LOGFILE
#    chown root:www-data /var/www/  >>$LOGFILE 2>>$LOGFILE
}




privilegedSetupPhase3 () {
    
    #Force time adjust, system and hardware clocks
    /etc/init.d/openntpd stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/openntpd start >>$LOGFILE 2>>$LOGFILE
    ntpdate-debian  >>$LOGFILE 2>>$LOGFILE
    hwclock -w >>$LOGFILE 2>>$LOGFILE
}





privilegedSetupPhase4 () {
    
    #Load initial whitelist # TODO add gui form to spec the admin's ip and add it permanently to the whitelist. Add that as an option on the edit admin op. IF necessary move these calls ahead until we have the admin's IP
	   bash /usr/local/bin/whitelistLCN.sh >>$LOGFILE 2>>$LOGFILE
    bash /usr/local/bin/updateWhitelist.sh>>$LOGFILE 2>>$LOGFILE
    
    
    #Test the RAID arrays, if any, and generate a test message for the administrator
    mdadm --monitor  --scan  --oneshot --syslog --mail=root  --test  >>$LOGFILE 2>>$LOGFILE
    #If RAIDS are found, Warn the admin that he must receive an e-mail with the test  # TODO Make sure mailer is configured by now
    mdadm --examine --scan --config=partitions >/tmp/mdadm.conf  2>>$LOGFILE
    if [ "$(cat /tmp/mdadm.conf)" != "" ] 
	   then
	       $dlg --msgbox $"RAID arrays detected. You will receive an e-mail with the test result." 0 0
    fi
    
    
    #Activate privileged operations execution lock. Any op invoked
    #from now on will first check for a valid rebuilt cipherkey
    echo -n "1" > $LOCKOPSFILE
    chmod 400 $LOCKOPSFILE
}




privilegedSetupPhase5 () {
    
    # TODO add some more useful info on the e-mail?
    emailAdministrator $"Test" $"This is a test e-mail to prove that the messaging system works end to end."
    $dlg --msgbox $"You must receive an e-mail as a proof for the notification system working properly. Check your inbox" 0 0
    
    ### Now, neuter the setup scripts to reduce attack vectors ###
    
    #Remove sudo capabilities to privileged setup so it cannot be invoked by user
    #(actually, removing all items from the sudo line but the first, which is privileged-ops and actually needed)
    sed -i -re 's|(^\s*vtuji\s*ALL.*NOPASSWD:[^,]+),.*$|\1|g' /etc/sudoers  >>$LOGFILE 2>>$LOGFILE
    
    #Remove read and execution permissions on wizard
    chmod 550 /usr/local/bin/wizard-setup.sh
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
	       getPrivVar c IPMODE
	       getPrivVar c IPADDR
	       getPrivVar c MASK
	       getPrivVar c GATEWAY
	       getPrivVar c DNS1
	       getPrivVar c DNS2
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
	       getPrivVar c IPADDR
	       getPrivVar c HOSTNM
 	      getPrivVar c DOMNAME
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

    # TODO: see this, see how to use it here and if something else needs to be done orr removed
    #hostnamectl set-hostname $HOSTNM.$DOMNAME

    
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






# TODO review this better when implementing and testing  the backup recovery
# TODO: on backup: overwrite file? add a new file with unique name such as timestamp? implement a round robin?
#Gets all needed recover parameters and calls the backup download and
#decipher procedure, then restores files and variables
recoverSSHBackupFileOp () {

        #Get backup data ciphering password (the shared hard drive cipher password)
        getPrivVar r CURRENTSLOT
        slotPath=$ROOTTMP/slot$CURRENTSLOT/
        DATABAKPWD=$(cat $slotPath/key)  #TODO review slot system
        #Get backup file SSH location parameters
        getPrivVar s SSHBAKUSER    
        getPrivVar s SSHBAKSERVER
        getPrivVar s SSHBAKPORT


        #Temporarily save all config variables that must be preserved (as now
        #we need to overwrite some for the restore)
        getPrivVar d SSHBAKPASSWD
        SSHBAKPASSWDaux=$SSHBAKPASSWD


        #Get the ssh password for the location where we must get the backup file
        getPrivVar s SSHBAKPASSWD
        #Write it on the disk password file (askBackupPasswd script will search for it there).
        setPrivVar SSHBAKPASSWD "$SSHBAKPASSWD" d
        
        #Recover backup
        recoverSSHBackupFile "" "$DATABAKPWD" "$SSHBAKUSER" "$SSHBAKSERVER" "$SSHBAKPORT" "$ROOTTMP/backupRecovery"
        ret="$?"
        if [ "$ret" -ne 0 ] 
        then
            exit $ret
        fi

        #Recover backup files. It is important to do this before
        #writing any variables in vars.conf. This enables us to
        #recover those that are not going to be overwritten (ssh,
        #dbpwd and mailrelay will be written later with their new
        #values).
        mv -f "$ROOTTMP/backupRecovery/$DATAPATH/*"  $DATAPATH/  # TODO change this. aufs may not be big enough to hold all of this. Write directly on the peristent data dev, also download the encrypted bak file there
        
        #Restore temporarily saved variables
        setPrivVar SSHBAKPASSWD "$SSHBAKPASSWDaux" d 
}

# TODO review this better when implementing and testing  the backup recovery.
#Downloads backup file and untars it on the specified dir
# $2 -> Password de cifrado de los datos
# $3 -> user
# $4 -> ssh server
# $5 -> port
# $6 -> backup data destination folder path
recoverSSHBackupFile () {
    
    export DISPLAY=none:0.0
    export SSH_ASKPASS=/usr/local/bin/askBackupPasswd.sh
    
    #Añadimos las llaves del servidor SSH al known_hosts
    mkdir -p /root/.ssh/  >>$LOGFILE 2>>$LOGFILE
    ssh-keyscan -p "$5" -t rsa1,rsa,dsa "$4" > /root/.ssh/known_hosts  2>>$LOGFILE
    if [ "$?" -ne 0 ] 
	   then
	       $dlg --msgbox $"Error configurando el acceso al servidor de copia de seguridad." 0 0
	       return 1
    fi
    
    mkdir $ROOTTMP/bak
    
    scp -P "$5" "$3"@"$4":vtUJI_backup.tgz.aes "$ROOTTMP/bak/"  >>$LOGFILE 2>>$LOGFILE
    if [ "$?" -ne 0 ]
	   then
	       $dlg --msgbox $"Error conectando con el servidor de Copia de Seguridad." 0 0
	       return 1
    fi
    
    openssl enc -d  -aes-256-cfb  -pass "pass:$2" -in "$ROOTTMP/bak/vtUJI_backup.tgz.aes" -out "$ROOTTMP/bak/vtUJI_backup.tgz"
    if [ "$?" -ne 0 ] 
	   then
	       $dlg --msgbox $"Error descifrando el fichero de Copia de Seguridad: fichero corrupto o llave incorrecta." 0 0 
	       return 1
    fi

# TODO hacer que se guarden copias en round robin o infinitas. Sea como sea, aquí hacer un ls y sacar un selector de qué fichero de bak usar
    
    rm -rf "$ROOTTMP/bak/vtUJI_backup.tgz.aes"
    rm -rf "$6"
    mkdir  "$6"
    
    tar xzf "$ROOTTMP/bak/vtUJI_backup.tgz" -C "$6"
    if [ "$?" -ne 0 ] 
	   then
	       $dlg --msgbox $"Error desempaquetando el fichero de Copia de Seguridad: fichero corrupto." 0 0 
	       return 1
    fi
    
    rm -rf "$ROOTTMP/bak/vtUJI_backup.tgz"
    
    rmdir $ROOTTMP/bak
    
    return 0
}



######################
##   Main program   ##
######################


#Which action is invoked
if [ "$1" == "init1" ]
then
    privilegedSetupPhase1
    
elif [ "$1" == "moveToRAM" ]
then
    moveToRAM
    
elif [ "$1" == "init3" ]
then
    privilegedSetupPhase3
    
elif [ "$1" == "init4" ]
then
    privilegedSetupPhase4
    
elif [ "$1" == "init5" ]
then
    privilegedSetupPhase5


elif [ "$1" == "configureNetwork" ] 
then
    IPMODE="$2"
    IPADDR="$3"
    MASK="$4"
    GATEWAY="$5"
    DNS1="$6"
    DNS2="$7"
    
    configureNetwork
    exit $?

elif [ "$1" == "configureHostDomain" ] 
then
    IPADDR="$2"
    HOSTNM="$3"
    DOMNAME="$4"
    
    configureHostDomain
    exit $?
    
    
    
#Shutdowns the system
elif [ "$1" == "halt" ]
then
    halt


    
    
#System logs are relocated from the RAM fs to the ciphered partition on the hard drive
elif [ "$1" == "relocateLogs" ]
then
    if [ "$2" != "new" -a "$2" != "reset" ]
    then
	       echo "relocateLogs: Bad parameter" >>$LOGFILE 2>>$LOGFILE
	       exit 1
    fi
    relocateLogs "$2"




    
#Set admin e-mail as the recipient for all system notification e-mails  # TODO Add this to the update admin maint op
elif [ "$1" == "setupNotificationMails" ]
then
    getPrivVar d MGREMAIL
    #Check for a previous entry, and overwrite
    found=$(cat /etc/aliases | grep -Ee "^\s*root:")
    if [ "$found" != "" ] ; then
        sed -i -re "s/^(\s*root: ).*$/\1$MGREMAIL/g" /etc/aliases
    else
        echo -e "\nroot: $MGREMAIL" >> /etc/aliases 2>>$LOGFILE
    fi
    #Update mail aliases BD.
    /usr/bin/newaliases >>$LOGFILE 2>>$LOGFILE



    
    
#loads a keyboard keymap
elif [ "$1" == "loadkeys" ]
then
    loadkeys "$2"  >>$LOGFILE 2>>$LOGFILE



    
#Configure pm-utils to be able to suspend the computer
elif [ "$1" == "pmutils" ] 
then
    #Reinstall and reconfigure package # TODO probably a reconfigure would be-enough
    dpkg -i /usr/local/bin/pm-utils*  >>$LOGFILE  2>>$LOGFILE






#If there are RAIDS, check them before doing anything else
elif [ "$1" == "checkRAIDs" ]
then
    checkRAIDs
    exit $?

    

    

#Setup timezone and store variable
elif [ "$1" == "setupTimezone" ]
then
    
    #No timezone passed, it is a system load
    if [ "$2" == "" ] ; then
        #Read it from usb config (it is already settled)  # TODO check if settled, otherwise read from active slot.
        getPrivVar c TIMEZONE
    else
        #Check passed timezone
        checkParameterOrDie TIMEZONE "$2"
        #Set it on usb config var (and set the global variable)
        setPrivVar TIMEZONE "$TIMEZONE" c  # TODO make sure this is not overwritten later. As this is setup, vars should be written here and then shared on the devices, not overwritten by anything
    fi
    
    echo "$TIMEZONE" > /etc/timezone
    rm -f /etc/localtime
    ln -s "/usr/share/zoneinfo/right/$TIMEZONE" /etc/localtime
    

    
    
#Recover the system from a backup file retrieved through SSH  #  TODO test
elif [ "$1" == "recoverSSHBackup_phase1" ]
then
    recoverSSHBackupFileOp # TODO backup recovery process: get parameters from user when recovering, forget clauer conf move ssh bak paramsfrom clauer conf to disk conf and allow to modify them during operation theough a menu option
    

elif [ "$1" == "recoverSSHBackup_phase2" ]
then
    
    #restore database dump
    mysql -f -u root -p$(cat $DATAPATH/root/DatabaseRootPassword) eLection  <"$ROOTTMP/backupRecovery/$ROOTTMP/dump.*" 2>>$LOGFILE    
    [ $? -ne 0 ] && systemPanic $"Error durante la recuperación del backup de la base de datos."
    
    #Delete backup directory # TODO. this may change
    rm -rf "$ROOTTMP/backupRecovery/"



elif [ "$1" == "enableBackup" ]
then
    #Write cron to check every minute for a pending backup
    aux=$(cat /etc/crontab | grep backup.sh)
    if [ "$aux" == "" ]
    then
        echo -e "* * * * * root  /usr/local/bin/backup.sh\n\n" >> /etc/crontab  2>>$LOGFILE	    # TODO review this script
    fi
    
    
elif [ "$1" == "disableBackup" ]
then
    #Delete backup cron line (if exists)
    sed -i -re "/backup.sh/d" /etc/crontab
    
    
#Mark system to force a backup
elif [ "$1" == "forceBackup" ]
then
    #Backup cron reads database for next backup date. Set date to now. # TODO make sure this works fine and the pwd is there
    echo "update eVotDat set backup="$(date +%s) | mysql -u root -p$(cat $DATAPATH/root/DatabaseRootPassword) eLection
    
    
    
    
else
    echo "Bad privileged setup operation: $1" >>$LOGFILE  2>>$LOGFILE
fi


exit 0


















































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
    if [ "$1" == "new"  ]
	   then
	       mv /var/log $DATAPATH >>$LOGFILE 2>>$LOGFILE 
    else
        #If reset, save boot process logs in a temporary dir in case
	       #they are needed.
	       mv /var/log /var/currbootlogs >>$LOGFILE 2>>$LOGFILE 
    fi
    #Substitute them with the ones on the ciphered partition
    ln -s $DATAPATH/log/ /var/log >>$LOGFILE 2>>$LOGFILE 
    
    #Restore stopped services
    /etc/init.d/rsyslog start >>$LOGFILE 2>>$LOGFILE 
    
    if [ "$RESTARTMYSQL" -eq "1" ]
	   then
	       /etc/init.d/mysql start >>$LOGFILE 2>>$LOGFILE
    fi
    if [ "$RESTARTAPACHE" -eq "1" ]
	   then
	       /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE 
    fi
}










if [ "$1" == "populateDb" ]
    then
    
    checkParameterOrDie INT "${2}" "0" # Guess inside here if backups are used or not, don't rely on the main program, so delete param $2 and use a locally read vr if needed

    getPrivVar d DBPWD

    #Ejecutamos las sentencias sql genéricas y las específicas (el -f obliga a cont. aunque haya un error, que no nos afectan)
    mysql -f -u election -p"$DBPWD" eLection  </usr/local/bin/buildDB.sql 2>>/tmp/mysqlerr
    mysql -f -u election -p"$DBPWD" eLection  <$TMPDIR/config.sql 2>>/tmp/mysqlerr
    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de base de datos." f
    

    rm -f $TMPDIR/config.sql
    
    #Si no se usan backups alteramos la Bd para indicarlo
    if [ "$2" -ne 1 ] 
	then
	echo "update  eVotDat set backup=-1;"| mysql -u election -p"$DBPWD" eLection
	[ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de base de datos." f
    fi

    exit 0
fi   


if [ "$1" == "updateDb" ]
    then

    getPrivVar d DBPWD

    #grep /usr/local/bin/buildDB.sql -iEe "\s*alter "  2>>$LOGFILE       > /tmp/dbUpdate.sql

    perl -000 -lne 'print $1 while /^\s*((UPDATE|ALTER).+?;)/sgi' /usr/local/bin/buildDB.sql  2>>$LOGFILE  > /tmp/dbUpdate.sql
    mysql -f -u root -p"$MYSQLROOTPWD" eLection          2>>/tmp/mysqlerr  < /tmp/dbUpdate.sql #////probar


    exit 0
fi


# //// en la func de montar la part cifrada, establecer los permisos para todos los directorios y ficheros. Así me aseguro de que estén bien.
