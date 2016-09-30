#!/bin/bash

#This script contains all the setup actions that need to be executed by root. They are invoked through calls. No need for authorisation

#Las operaciones de setup (en varias fases) que deben ejecutarse con privilegios de root. Cuando acabe el setup, este script no podrá ser ejecutado por el usuario no privilegiado, evitando así dejar expuestas operaciones sensibles.  #////


#### INCLUDES ####

. /usr/local/bin/firewall.sh

. /usr/local/bin/common.sh  #Common functions for privileged and unprivileged scripts.

. /usr/local/bin/privileged-common.sh





# TODO add a guard here to disable the execution of this script once the system is loaded

#Which action is invoked
if [ "$1" == "init1" ]
    then
        privilegedSetupPhase1
elif
    
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
    
    
    
    #Configuramos el SMARTmonTools
     
    #Listar discos duros
    hdds=$(listHDDs)
    
    #Escribir la lista de HDDs en el fichero de config
    sed -i -re "s|(enable_smart=\").+$|\1$hdds\"|g" /etc/default/smartmontools >>$LOGFILE 2>>$LOGFILE
    
    #Reload SMART daemon
    /etc/init.d/smartmontools stop   >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/smartmontools start  >>$LOGFILE 2>>$LOGFILE
    
    
    #El monitor de RAID lo lanzaremos al final, porque necesito el e-mail del admin. # TODO


    

    #Lanzamos klogd para que indique al kernel que imprima por el terminal sólo los mensajes de máxima prioridad
    /etc/init.d/klogd      stop  >>$LOGFILE 2>>$LOGFILE
    /sbin/klogd -c 1   >>$LOGFILE 2>>$LOGFILE
    #    killall klogd      >>$LOGFILE 2>>$LOGFILE

    ###  Desde la Lucid se descarta el klogd por rsyslogd, pero la
    ###  versión distribuída aún no implementa la directriz para cambiar
    ###  el loglevel. Lo hacemos a mano sobre el proc
    echo "1  1  1  1" > /proc/sys/kernel/printk
    
    
    
     
    
    #No lanzamos el portmap. Sólo es necesario en servidores nfs o samba
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

    #Si se está usando plymouth (>=lucid lynx), lo matamos
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


    #Establecemos la variable que indica que estamos en setup (para que el panic saque el menú) #////si la quito del panic puedo quitar esta
    setPrivVar SYSTEMISRUNNING 0 r
}








privilegedSetupPhase2 () {

    #Lo primero que hacemos siempre: Si la máquina sobre la que corremos tiene RAIDs por software, los cargamos.
    setupRAIDs
    
    
    # Para evitar la suplantación del sistema, copiaremos todo el
    # sistema de ficheros del CD a RAM, pero ello requiere que exista un
    # mínimo de espacio disponible.
  
    # Espacio disponible en el aufs creado sobre este sistema.
    aufsSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)
    
    
    # si aufsSize no tiene al menos 1200 MB solicitar autorización para copiar todo el FS en RAM.
    
    exec 4>&1 
    $dlg  --msgbox $"Para evitar suplantaciones del CD que hace funcionar este sistema de voto, se va a copiar todo su contenido en memoria RAM." 0 0
    
    copyOnRAM=1
    if [ "$aufsSize" -lt 1200 ] #1200
	then
	copyOnRAM=0
	if [ "$aufsSize" -lt 870 ] #870
	    then
	    $dlg  --msgbox $"Se ha detectado que la cantidad de memoria RAM presente en el sistema es peligrosamente baja. No se realizará este procedimiento" 0 0
	else
	    $dlg --yes-label $"Copiar en RAM"  --no-label $"No copiar en RAM" --yesno  $"Se ha detectado que la cantidad de memoria RAM presente en el sistema puede resultar insuficiente para su correcto funcionamiento en un período prolongado:\n\nMemoria disponible para sistema de ficheros: $aufsSize MB\nTamaño estimado del sistema de ficheros del CD: $ESTIMATEDCDFSSIZE MB\n\n¿Desea copiarlo o desea operar desde el CD?" 0 0
	    [ "$?" -eq 0  ] && copyOnRAM=1
	    
	fi
	
    fi  
    
    if [ "$copyOnRAM" -eq 1 ]
	then
	$dlg --infobox $"Copiando el CD en memoria..."  0 0
	
	find /  -xdev -type f -print0 | xargs -0 touch
	
        #Calculamos espacio disponible ahora
	aufsSize=$(df -m | grep "aufs" | sed -re "s/\s+/ /g" | cut -d " " -f 4)
      
	$dlg --msgbox $"Copia finalizada con éxito.\n\nEl sistema de ficheros en RAM dispone todavía de: $aufsSize MB." 0 0
    else
	$dlg --msgbox $"No se copiará el CD en memoria.\n\nEl sistema no puede garantizar su integridad ante una violación de la seguridad física. Tomen las medidas pertinentes: aumenten la cantidad de memoria RAM para poder realizar el procedimiento o restrinjan el acceso a la ubicación física del servidor." 0 0
    fi
    
        
    
    #Workaround para el poltergist del directorio no listable a pesar de los permisos
    mv /var/www /var/aux >>$LOGFILE 2>>$LOGFILE
    mkdir /var/www >>$LOGFILE 2>>$LOGFILE
    chmod a+rx /var/www >>$LOGFILE 2>>$LOGFILE
    mv /var/aux/* /var/www/  >>$LOGFILE 2>>$LOGFILE
    #Establecemos los permisos definitivos del directorio (lo hago en la instalación , pero este WA igual lo fastidia.)
    chmod 550 /var/www/ >>$LOGFILE 2>>$LOGFILE
    chown root:www-data /var/www/  >>$LOGFILE 2>>$LOGFILE  #//// probar


    #Guardamos el estado de la copia en RAM en el fichero de variables en memoria
    setPrivVar copyOnRAM "$copyOnRAM" r   #////probar que lo escribe.
fi







#### Fase 3

if [ "$1" == "3" ]
    then
    

    /etc/init.d/openntpd stop  >>$LOGFILE 2>>$LOGFILE
    /etc/init.d/openntpd start >>$LOGFILE 2>>$LOGFILE
    ntpdate-debian  >>$LOGFILE 2>>$LOGFILE
   
    #Establecemos la hora del reloj de la CPU ahora que ya se habrá ajustado con el openntpd
    hwclock -w >>$LOGFILE 2>>$LOGFILE

    #Como no me fio del openntpd, pongo un cron diario de sincronización de hora
    echo -e "\n0 0 * * * root  ntpdate-debian >/dev/null 2>/dev/null ; hwclock -w >/dev/null 2>/dev/null\n" >> /etc/crontab  2>>$LOGFILE
    
    
    #Por si acaso, rehasheamos los certificados  de todas las CAs 
    c_rehash >>$LOGFILE 2>>$LOGFILE
    
    #Por si acaso, al inicio de la instalación, sincronizamos el reloj (porque al lanzarse el ntpd no tenía conectividad)
    #$dlg   --infobox $"Sincronizando la hora del sistema..." 0 0
    #ntpdate-debian >>$LOGFILE 2>>$LOGFILE
    #if [ "$?" -ne "0" ] ; then
#	$dlg   --msgbox $"Error sincronizando la hora. Se intentará más tarde." 0 0
#    else
#	hwclock -w >>$LOGFILE 2>>$LOGFILE
#    fi
    
fi





#### Fase 4

if [ "$1" == "4" ]
    then
    
    #Actualizamos la BD de aliases.
    /usr/bin/newaliases    >>$LOGFILE 2>>$LOGFILE
    
    
    #Creamos la Whitelist inicial de nodos de la LCN 
    bash /usr/local/bin/firewallWhitelist.sh  >>$LOGFILE 2>>$LOGFILE
	    

    #Para mayor seguridad, copiamos la config de raids al tmp del root
    cp /tmp/mdadm.conf $ROOTTMP/mdadm.conf
    chmod 440 $ROOTTMP/mdadm.conf

	    
    #Instalamos el monitor de RAIDs. Realiza chequeo de estado cada hora
    echo -e "\n0 * * * * root /sbin/mdadm --monitor  --scan  --oneshot --syslog --mail=root --config=$ROOTTMP/mdadm.conf >/dev/null 2>/dev/null\n" >> /etc/crontab  
	    
    #Probamos el monitor de RAID (modo test)
    mdadm --monitor  --scan  --oneshot --syslog --mail=root --config=$ROOTTMP/mdadm.conf  --test  >>$LOGFILE 2>>$LOGFILE

    #Marcamos en una variable que el sistema está en marcha (para que el panic NO saque el menú)  #//// si lo saco del panic, puedo uitarlo de aquí.
    setPrivVar SYSTEMISRUNNING 1 r

    #Activamos el bloqueo de ejecución de operaciones privilegiadas. Ahora, 
    #cualquier operación que se ejecute verificará antes que puede reconstruir 
    #la clave de cifrado del disco
    echo -n "1" > $LOCKOPSFILE
    chmod 400 $LOCKOPSFILE


fi




#### Fase 5

if [ "$1" == "5" ]
    then
     
#Una vez acabado el uso de los scripts de setup, los inutilizamos

#Quitamos el privileged del sudo
sed -i -re 's|(^\s*vtuji\s*ALL.*NOPASSWD:[^,]+),.*$|\1|g' /etc/sudoers  >>$LOGFILE 2>>$LOGFILE  #//// Probar que no fastidie al que está en ejecución y probar que no pueda ejecutarlo de nuevo.

#Quitamos los permisos de ejec al wizard.
chmod 550 /usr/local/bin/wizard-setup.sh
    
fi



#### Fase N

#if [ "$1" == "" ]
#    then



#fi






#### Operaciones específicas



# Forzamos un backup           #//// probar
if [ "$1" == "forceBackup" ]
    then
    
    echo "update eVotDat set backup="$(date +%s) | mysql -u root -p$(cat $DATAPATH/root/DatabaseRootPassword) eLection

    exit 0
fi






if [ "$1" == "setupNotificationMails" ]
    then

    getPrivVar d MGREMAIL

    echo -e "\nroot: $MGREMAIL" >> /etc/aliases   2>>$LOGFILE    

    exit 0
fi


if [ "$1" == "loadkeys" ]
    then


   if [ "$2" == "es" ]
       then
       loadkeys es  >>$LOGFILE 2>>$LOGFILE #Cargamos el teclado español
   fi

   exit 0
fi


#Configura las pm-utils, para pdoer suspender el equipo
if [ "$1" == "pmutils" ] 
    then
    #Reconfiguramos el pm-utils, para que se adapte a esta máquina. 
    dpkg -i /usr/local/bin/pm-utils*  >>$LOGFILE  2>>$LOGFILE

    exit 0
fi







# Estra op 
if [ "$1" == "recoverSSHBackupFile" ]
    then



#Descarga el fichero de backup y lo descomprime en el directorio indicado
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




#La contraseña de cifrado de los datos del backup
getPrivVar r CURRENTSLOT
slotPath=$ROOTTMP/slot$CURRENTSLOT/
DATABAKPWD=$(cat $slotPath/key)  #//// la key del slot actual

getPrivVar s SSHBAKUSER    
getPrivVar s SSHBAKSERVER
getPrivVar s SSHBAKPORT



#////guardar aquí las variables a restaurar (las que prevalece el valor establecido en la nueva inst y no en el fichero de bak). 
#Guardamos la contraseña del servidor ssh de backup actual en una variable
getPrivVar d SSHBAKPASSWD
SSHBAKPASSWDaux=$SSHBAKPASSWD





#Leemos la contraseña del servidor de backup donde está el restore
getPrivVar s SSHBAKPASSWD
#LA escribimos en el fichero de disco, de donde el script de askBackupPasswd la leerá.
setPrivVar SSHBAKPASSWD "$SSHBAKPASSWD" d



recoverSSHBackupFile "" "$DATABAKPWD" "$SSHBAKUSER" "$SSHBAKSERVER" "$SSHBAKPORT" "$ROOTTMP/backupRecovery"
ret="$?"

if [ "$ret" -ne 0 ] 
    then
    exit $ret
fi

#Recuperamos los ficheros del bak
# Es importante hacer esto antes de que se esciba ninguna variable en vars.conf.
#  Esto nos permite lograr recuperar aquellas que ahora no se van a  sobreescribir (las del ssh, el dbpwd y mailrelay se escriben después con sus valores nuevos).
mv -f "$ROOTTMP/backupRecovery/$DATAPATH/*"  $DATAPATH/

#//// Asegurarme de que al restaurar se mantienen los permisos. especialmente los extendidos.



#restauramos la contraseña del servidor de backup actual #*-*-
setPrivVar SSHBAKPASSWD "$SSHBAKPASSWDaux" d

fi







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















if [ "$1" == "iscsi" ]
    then
    
    if [ "$2" == "restart" ]
	then
	
	/etc/init.d/open-iscsi stop  >>$LOGFILE 2>>$LOGFILE 
	/etc/init.d/open-iscsi start >>$LOGFILE 2>>$LOGFILE 
	
    fi
    
 
    if [ "$2" == "discovery" ]
	then
	#3 -> iscsi server
	#4 -> iscsi port
	iscsiadm -m discovery  -t st -p "$3:$4" 2>>$LOGFILE
	
    fi
     
    
    
fi










if [ "$1" == "relocateLogs" ]
    then

# $1 -> 'new' o 'reset'
relocateLogs () {

    
    #Paramos, si están en marcha, los servicios que pueden tener ficheros abiertos.
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

    
   #en new, debe mover el dir /var/log a la part cifrada
    if [ "$1" == "new"  ]
	then
	mv /var/log $DATAPATH >>$LOGFILE 2>>$LOGFILE 
    else
	#Cuando es reset, guardamos los logs generados hasta este momento 
	#en otra ruta temporal, por si acaso se necesita analizar 
	#algo del proceso de inicio.
	#rm -rf /var/log >>$LOGFILE 2>>$LOGFILE 
	mv /var/log /var/currbootlogs >>$LOGFILE 2>>$LOGFILE 
    fi
    
    #en ambos, enlazamos la ruta /var/log a la partición cifrada
    ln -s $DATAPATH/log/ /var/log >>$LOGFILE 2>>$LOGFILE 
    #chmod go-w /var/log
    
    
    #Restauramos los servicios parados, para que accedan a los nuevos ficheros de log
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





if [ "$2" != "new" -a "$2" != "reset" ]
    then
	echo "relocateLogs: Bad parameter" >>$LOGFILE 2>>$LOGFILE
	exit 1
fi



relocateLogs "$2"


fi






if [ "$1" == "halt" ]
    then
    halt
fi






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















#### UTILS ####



#Para limitar el tiempo de ejecución.
#function lanza () { (eval "$1" & p=$! ; (sleep $2; kill $p 2>/dev/null) & wait $p) ; }


