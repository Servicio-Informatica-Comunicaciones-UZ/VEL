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


# See if this function can be deleted. We would need an error message passback system to let the invoker script handle this. Leave for alter

#Fatal error function. It is redefined on each script with the
#expected behaviour, for security reasons.
#$1 -> error message
systemPanic () {

    #Show error message to the user
    $dlg --msgbox "$1" 0 0
    
    #Destroy sensitive variables  # TODO review if this is needed or list of vars must be updated
    keyyU=''
    keyyS=''
    MYSQLROOTPWD=''

    #Offer emergency administration choices
    exec 4>&1 
    selec=$($dlg --no-cancel  --menu $"Select an option." 0 0  3  \
	                1 $"Shutdown system." \
	                2 $"Reboot system." \
	                3 $"Launch an administration terminal." \
	                2>&1 >&4)
    
    case "$selec" in
	       
	       "1" )
            #Shutdown
            shutdownServer "h"
	           ;;

	       "2" )
	           #Reboot
            shutdownServer "r"
            ;;
	       
	       "3" )
            #Launch a root terminal (with a disclaimer for the overseers)
	           $dlg --yes-label $"Yes" --no-label $"No"  --yesno  $"WARNING: This action may allow the user access to sensitive data until it is rebooted. Make sure it is not operated without supervision from a qualified overseer. ¿Do you wish to continue?." 0 0
	           [ "$?" -eq 0 ] && exec $PVOPS rootShell
            ;;	
	       * )
	           echo "systemPanic: Bad selection"  >>$LOGFILE 2>>$LOGFILE
	           $dlg --msgbox "BAD SELECTION" 0 0
	           shutdownServer "h"
	           ;;
	   esac
    
    shutdownServer "h"
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
    
    # Clear terminal 7 (and 1 just in case), so no text is seen after plymouth quits
    #<RELEASE>
    clear > /dev/tty7
    clear > /dev/tty1
    #</RELEASE>
    
    #Kill plymouth (if alive) so we can show the curses GUI
    plymouth quit
    
    #Jump to terminal 7 (the graphic one, where we run our curses GUI)
    chvt 7
    
    #Prepare root user tmp dir
    chmod 700 $ROOTTMP/ >>$LOGFILE 2>>$LOGFILE
    $PVOPS clops init
}








privilegedSetupPhase2 () {
    
    #If there are RAIDS, check them before doing anything else
    checkRAIDs
    [ $? -ne 0 ] && systemPanic "Error: failed RAID volume due to errors or degradation. Please, solve this issue before going on with the system installation/boot."
    
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
    
#SEGUIR
    
    #Por si acaso, rehasheamos los certificados  de todas las CAs # TODO hacer esto cuando pueda estar instalando un cert o una CA
    c_rehash >>$LOGFILE 2>>$LOGFILE
    
    #Por si acaso, al inicio de la instalación, sincronizamos el reloj (porque al lanzarse el ntpd no tenía conectividad)
    #$dlg   --infobox $"Sincronizando la hora del sistema..." 0 0
    #ntpdate-debian >>$LOGFILE 2>>$LOGFILE
    #if [ "$?" -ne "0" ] ; then
#	$dlg   --msgbox $"Error sincronizando la hora. Se intentará más tarde." 0 0
#    else
#	hwclock -w >>$LOGFILE 2>>$LOGFILE
#    fi
    
}





privilegedSetupPhase4 () {
    
    #Actualizamos la BD de aliases.
    /usr/bin/newaliases    >>$LOGFILE 2>>$LOGFILE
    
    
    #Creamos la Whitelist inicial de nodos de la LCN 
    bash /usr/local/bin/firewallWhitelist.sh  >>$LOGFILE 2>>$LOGFILE
	   	    
    # TODO maybe, if we i18n all files, add here a warning to the root user, that he must receive an e-mail with the test for the raid # TODO we should really avoid UI from root. Move all UI to user space
    
    #Test the RAID arrays if any and generate a test message for the administrator
    mdadm --monitor  --scan  --oneshot --syslog --mail=root  --test  >>$LOGFILE 2>>$LOGFILE
    

    #Activamos el bloqueo de ejecución de operaciones privilegiadas. Ahora, 
    #cualquier operación que se ejecute verificará antes que puede reconstruir 
    #la clave de cifrado del disco
    echo -n "1" > $LOCKOPSFILE
    chmod 400 $LOCKOPSFILE


}




privilegedSetupPhase5 () {

     
#Una vez acabado el uso de los scripts de setup, los inutilizamos

#TODO Remove sudo capabilities to privileged setup so it cannot be invoked by user
sed -i -re 's|(^\s*vtuji\s*ALL.*NOPASSWD:[^,]+),.*$|\1|g' /etc/sudoers  >>$LOGFILE 2>>$LOGFILE  #TODO Probar que no fastidie al que está en ejecución y probar que no pueda ejecutarlo de nuevo.

#Quitamos los permisos de ejec al wizard.
chmod 550 /usr/local/bin/wizard-setup.sh
    
}




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
        mv -f "$ROOTTMP/backupRecovery/$DATAPATH/*"  $DATAPATH/

        #TODO Asegurarme de que al restaurar se mantienen los permisos. especialmente los extendidos.
        
        #Restore temporarily saved variables
        setPrivVar SSHBAKPASSWD "$SSHBAKPASSWDaux" d 
}


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
    
    rm -rf "$6"
    mkdir  "$6"
    
    tar xzf "$ROOTTMP/bak/vtUJI_backup.tgz" -C "$6"
    if [ "$?" -ne 0 ] 
	   then
	       $dlg --msgbox $"Error desempaquetando el fichero de Copia de Seguridad: fichero corrupto." 0 0 
	       return 1
    fi
    
    rm -rf "$ROOTTMP/bak/vtUJI_backup.tgz.aes"
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
    
elif [ "$1" == "init2" ]
then
    privilegedSetupPhase2
    
elif [ "$1" == "init3" ]
then
    privilegedSetupPhase3
    
elif [ "$1" == "init4" ]
then
    privilegedSetupPhase4
    
elif [ "$1" == "init5" ]
then
    privilegedSetupPhase5

    
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

    
#Mark webapp to force a backup
elif [ "$1" == "forceBackup" ]
then
    # TODO make sure this works fine and the pwd is there
    echo "update eVotDat set backup="$(date +%s) | mysql -u root -p$(cat $DATAPATH/root/DatabaseRootPassword) eLection

    
#setup admin's password as the recipient for all system notification e-mails
elif [ "$1" == "setupNotificationMails" ]
then
    getPrivVar d MGREMAIL
    echo -e "\nroot: $MGREMAIL" >> /etc/aliases   2>>$LOGFILE    


#loads a keyboard keymap
elif [ "$1" == "loadkeys" ]
then
    loadkeys "$2"  >>$LOGFILE 2>>$LOGFILE

#Configure pm-utils to be able to suspend the computer
elif [ "$1" == "pmutils" ] 
then
    #Reinstall and reconfigure package
    dpkg -i /usr/local/bin/pm-utils*  >>$LOGFILE  2>>$LOGFILE
    

 #Recover the system from a backup file retrieved through SSH  #  TODO test
elif [ "$1" == "recoverSSHBackupFile" ]
then
    recoverSSHBackupFileOp
    
    
else
    :
fi
exit 0























if [ "$1" == "recoverDbBackup" ]
    then

    #restore database dump
    mysql -f -u root -p$(cat $DATAPATH/root/DatabaseRootPassword) eLection  <"$ROOTTMP/backupRecovery/$ROOTTMP/dump.*" 2>>/tmp/mysqlRestoreErr
    
    [ $? -ne 0 ] && systemPanic $"Error durante la recuperación del backup de la base de datos."

    #Borramos el directorio donde estaba el backup recuperado 
    rm -rf "$ROOTTMP/backupRecovery/"

fi







if [ "$1" == "enableBackup" ]
    then

    #Escribimos la línea al final del fichero crontab del sistema
    echo -e "* * * * * root  /usr/local/bin/backup.sh\n\n" >> /etc/crontab  2>>$LOGFILE	    
    
fi
























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
    
    checkParameterOrDie INT "${2}" "0"

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
