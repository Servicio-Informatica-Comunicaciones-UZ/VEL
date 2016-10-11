#!/bin/bash

#This script contains all the setup actions that need to be executed
#by root. They are invoked through calls. No need for authorisation as
#on this phase, system is being monitored by the committee. After
#setup, these operations will be disabled.



#### INCLUDES ####

#System firewall functions
. /usr/local/bin/firewall.sh

#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh




#Once the system is loaded, none of these operations can be called, for security reasons
getPrivVar r SYSTEMISRUNNING
if [ "$SYSTEMISRUNNING" != "" -a "$SYSTEMISRUNNING" -eq 1 ]
then
    echo "*** Attempted call to privileged setup while system is running" >> $LOGFILE
	   exit 99
fi


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
    
    #Escribir la lista de HDDs en el fichero de config
    sed -i -re "s|(enable_smart=\").+$|\1$hdds\"|g" /etc/default/smartmontools >>$LOGFILE 2>>$LOGFILE
    
    #Reload SMART daemon
    /etc/init.d/smartmontools stop   >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/smartmontools start  >>$LOGFILE 2>>$LOGFILE
    
    
    #El monitor de RAID lo lanzaremos al final, porque necesito el e-mail del admin. # TODO


    

    #Lanzamos klogd para que indique al kernel que imprima por el terminal s�lo los mensajes de m�xima prioridad
    /etc/init.d/klogd      stop  >>$LOGFILE 2>>$LOGFILE
    /sbin/klogd -c 1   >>$LOGFILE 2>>$LOGFILE
    #    killall klogd      >>$LOGFILE 2>>$LOGFILE

    ###  Desde la Lucid se descarta el klogd por rsyslogd, pero la
    ###  versi�n distribu�da a�n no implementa la directriz para cambiar
    ###  el loglevel. Lo hacemos a mano sobre el proc
    echo "1  1  1  1" > /proc/sys/kernel/printk
    
    
    
     
    
    #No lanzamos el portmap. S�lo es necesario en servidores nfs o samba
    #/etc/init.d/portmap start >>$LOGFILE 2>>$LOGFILE  
    
    


#    #Desactivamos los logs del sistema
#    #Ya no los desactivo.
#    sed -i -re "s|/var/log/[^ ]+|/dev/null|g" /etc/syslog.conf
#
#    #Desactivamos los Logs del sistema (para los que escriben directamete, sin el syslogd)
#    rm /var/log/syslog
#    ln -s /dev/null /var/log/syslog
#    rm /var/log/dmesg
#    ln -s /dev/null /var/log/dmesg
#    rm /var/log/kern.log
#    ln -s /dev/null /var/log/kern.log
#    rm /var/log/udev
#    ln -s /dev/null /var/log/udev
#    rm /var/log/messages
#    ln -s /dev/null /var/log/messages
#    rm /var/log/daemon.log
#    ln -s /dev/null /var/log/daemon.log


   
    
    #Matamos el usplash (para que muestre mi script)
    /etc/init.d/usplash start >>$LOGFILE 2>>$LOGFILE

    # Limpiamos el terminal 7 (para que al quiatr el plymouth no saque texto) #///Comentar para debug.
    clear > /dev/tty7

    #Si se est� usando plymouth (>=lucid lynx), lo matamos
    plymouth quit
    


    #mostramos el terminal virtual 8, si estamos en jaunty (usando usplash)
    [ -e "/etc/init.d/usplash" ] && chvt 8

    #mostramos el terminal virtual 7, si estamos en lucid+ (usando plymouth)
    [ -e "/bin/plymouth" ] && chvt 7

    
    #El tty 1 lo limpiamos, pues es la consola del sistrema y no puede matarse
    clear > /dev/tty1


    #Preparamos el tmp del root  #////probar
    chmod 700 $ROOTTMP/ >>$LOGFILE 2>>$LOGFILE
    $PVOPS clops init


    #Establecemos la variable que indica que estamos en setup (para que el panic saque el men�) #////si la quito del panic puedo quitar esta
    setPrivVar SYSTEMISRUNNING 0 r
}








privilegedSetupPhase2 () {

    #If there are RAIDS, check them before doing anything else
    checkRAIDs
    
    
    # Para evitar la suplantaci�n del sistema, copiaremos todo el
    # sistema de ficheros del CD a RAM, pero ello requiere que exista un
    # m�nimo de espacio disponible.
  
    # Espacio disponible en el aufs creado sobre este sistema.
    aufsSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)
    
    
    # si aufsSize no tiene al menos 1200 MB solicitar autorizaci�n para copiar todo el FS en RAM.
    
    exec 4>&1 
    $dlg  --msgbox $"Para evitar suplantaciones del CD que hace funcionar este sistema de voto, se va a copiar todo su contenido en memoria RAM." 0 0
    
    copyOnRAM=1
    if [ "$aufsSize" -lt 1200 ] #1200
	then
	copyOnRAM=0
	if [ "$aufsSize" -lt 870 ] #870
	    then
	    $dlg  --msgbox $"Se ha detectado que la cantidad de memoria RAM presente en el sistema es peligrosamente baja. No se realizar� este procedimiento" 0 0
	else
	    $dlg --yes-label $"Copiar en RAM"  --no-label $"No copiar en RAM" --yesno  $"Se ha detectado que la cantidad de memoria RAM presente en el sistema puede resultar insuficiente para su correcto funcionamiento en un per�odo prolongado:\n\nMemoria disponible para sistema de ficheros: $aufsSize MB\nTama�o estimado del sistema de ficheros del CD: $ESTIMATEDCDFSSIZE MB\n\n�Desea copiarlo o desea operar desde el CD?" 0 0
	    [ "$?" -eq 0  ] && copyOnRAM=1
	    
	fi
	
    fi  
    
    if [ "$copyOnRAM" -eq 1 ]
	then
	$dlg --infobox $"Copiando el CD en memoria..."  0 0
	
	find /  -xdev -type f -print0 | xargs -0 touch
	
        #Calculamos espacio disponible ahora
	aufsSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)
      
	$dlg --msgbox $"Copia finalizada con �xito.\n\nEl sistema de ficheros en RAM dispone todav�a de: $aufsSize MB." 0 0
    else
	$dlg --msgbox $"No se copiar� el CD en memoria.\n\nEl sistema no puede garantizar su integridad ante una violaci�n de la seguridad f�sica. Tomen las medidas pertinentes: aumenten la cantidad de memoria RAM para poder realizar el procedimiento o restrinjan el acceso a la ubicaci�n f�sica del servidor." 0 0
    fi
    
        
    
    #Workaround para el poltergist del directorio no listable a pesar de los permisos
    mv /var/www /var/aux >>$LOGFILE 2>>$LOGFILE
    mkdir /var/www >>$LOGFILE 2>>$LOGFILE
    chmod a+rx /var/www >>$LOGFILE 2>>$LOGFILE
    mv /var/aux/* /var/www/  >>$LOGFILE 2>>$LOGFILE
    #Establecemos los permisos definitivos del directorio (lo hago en la instalaci�n , pero este WA igual lo fastidia.)
    chmod 550 /var/www/ >>$LOGFILE 2>>$LOGFILE
    chown root:www-data /var/www/  >>$LOGFILE 2>>$LOGFILE  #//// probar


    #Guardamos el estado de la copia en RAM en el fichero de variables en memoria
    setPrivVar copyOnRAM "$copyOnRAM" r   #////probar que lo escribe.
}




privilegedSetupPhase3 () {
    
    /etc/init.d/openntpd stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/openntpd start >>$LOGFILE 2>>$LOGFILE
    ntpdate-debian  >>$LOGFILE 2>>$LOGFILE
   
    #Establecemos la hora del reloj de la CPU ahora que ya se habr� ajustado con el openntpd
    hwclock -w >>$LOGFILE 2>>$LOGFILE

    #Como no me fio del openntpd, pongo un cron diario de sincronizaci�n de hora
    echo -e "\n0 0 * * * root  ntpdate-debian >/dev/null 2>/dev/null ; hwclock -w >/dev/null 2>/dev/null\n" >> /etc/crontab  2>>$LOGFILE
    
    
    #Por si acaso, rehasheamos los certificados  de todas las CAs 
    c_rehash >>$LOGFILE 2>>$LOGFILE
    
    #Por si acaso, al inicio de la instalaci�n, sincronizamos el reloj (porque al lanzarse el ntpd no ten�a conectividad)
    #$dlg   --infobox $"Sincronizando la hora del sistema..." 0 0
    #ntpdate-debian >>$LOGFILE 2>>$LOGFILE
    #if [ "$?" -ne "0" ] ; then
#	$dlg   --msgbox $"Error sincronizando la hora. Se intentar� m�s tarde." 0 0
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
    
    #Marcamos en una variable que el sistema est� en marcha (para que el panic NO saque el men�)  #//// si lo saco del panic, puedo uitarlo de aqu�.
    setPrivVar SYSTEMISRUNNING 1 r

    #Activamos el bloqueo de ejecuci�n de operaciones privilegiadas. Ahora, 
    #cualquier operaci�n que se ejecute verificar� antes que puede reconstruir 
    #la clave de cifrado del disco
    echo -n "1" > $LOCKOPSFILE
    chmod 400 $LOCKOPSFILE


}




privilegedSetupPhase5 () {

     
#Una vez acabado el uso de los scripts de setup, los inutilizamos

#Quitamos el privileged del sudo
sed -i -re 's|(^\s*vtuji\s*ALL.*NOPASSWD:[^,]+),.*$|\1|g' /etc/sudoers  >>$LOGFILE 2>>$LOGFILE  #//// Probar que no fastidie al que est� en ejecuci�n y probar que no pueda ejecutarlo de nuevo.

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
    
    #A�adimos las llaves del servidor SSH al known_hosts
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
    
    [ $? -ne 0 ] && systemPanic $"Error durante la recuperaci�n del backup de la base de datos."

    #Borramos el directorio donde estaba el backup recuperado 
    rm -rf "$ROOTTMP/backupRecovery/"

fi







if [ "$1" == "enableBackup" ]
    then

    #Escribimos la l�nea al final del fichero crontab del sistema
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

    #Ejecutamos las sentencias sql gen�ricas y las espec�ficas (el -f obliga a cont. aunque haya un error, que no nos afectan)
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


# //// en la func de montar la part cifrada, establecer los permisos para todos los directorios y ficheros. As� me aseguro de que est�n bien.
