#!/bin/bash



##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh




#############
#  Methods  #
#############




#Log function
log () {
    echo "["$(date --rfc-3339=ns)"][wizard-maintenance]: "$*  >>$LOGFILE 2>>$LOGFILE
}




#Error function. Will message the user and then reset the maintenance
#application to the main menu
#$1 -> error message
resetLoop () {
    #Show error message to the user
    log "$1"
    $dlg --msgbox "$1" 0 0
    
    #Return to the maintenance idle loop
	   doLoop
} # TODO Call this everywhere there's an error that needs to go back to the loop




#Reboots the maintenance application, so every action is performed on
#a clean environment by overriding the process context of the previous
#execution
doLoop () {
    exec /bin/bash  /usr/local/bin/wizard-maintenance.sh
    shutdownServer "h" #This will never be executed
}






#Main maintenance menu
#Will set the following globals (the calls to the submenus will):
#MAINTACTION: which action to perform
#CLEARANCEMODE: how authorisation must be seeked
chooseMaintenanceAction () {
    
    exec 4>&1
    while true; do
        MAINTACTION=''
        
        
        adminprivileges=$"YES"
        sslstate=$"OK"
        
        
        local title=''
        title=$title$"Maintenance operations categories""\n"
        title=$title"===============================\n"
        title=$title"  * ""\Zb"$"Administrator has privileges"": \Z5""$adminprivileges""\ZN\Z0""\n"
        title=$title"  * ""\Zb"$"SSL certificate status"":       \Z5""$sslstate""\ZN"
        
        selec=$($dlg --no-cancel --no-tags --colors \
                     --menu "$title" 0 60  9  \
	                      admin-group   $"Administrator operations." \
                       key-group     $"Shared key management." \
	                      ssl-group     $"SSL certificate management." \
	                      backup-group  $"Backup system management." \
                       config-group  $"System configuration." \
	                      monitor-group $"Monitoring operations." \
                       misc-group    $"Other operations." \
	                    2>&1 >&4)
        
        case "$selec" in
	           "admin-group" )
                chooseAdminOperation
                [ $? -ne 0 ] && continue #Chose to go Back
                ;;

            "key-group" )
                chooseKeyOperation
                [ $? -ne 0 ] && continue #Chose to go Back
                ;;

            "ssl-group" )
                chooseSSLOperation
                [ $? -ne 0 ] && continue #Chose to go Back
                ;;            
	          	
            "backup-group" )
                chooseBackupOperation
                [ $? -ne 0 ] && continue #Chose to go Back
                ;;            
	           
            "config-group" )
                chooseConfigOperation
                [ $? -ne 0 ] && continue #Chose to go Back
                ;;            
	           
            "monitor-group" )
                chooseMonitorOperation
                [ $? -ne 0 ] && continue #Chose to go Back
                ;;            
	           
            "misc-group" )
                chooseMiscOperation
                [ $? -ne 0 ] && continue #Chose to go Back
                ;;            
	           
	           * )
	               log "main operation selector: bad selection. This must not happen" 
                continue
	               ;;
	       esac
        
        break
    done
    
    return 0
}




chooseAdminOperation () {
    :
}




chooseKeyOperation () {
    :
}




chooseSSLOperation () {
    :
}




chooseBackupOperation () {
    :
}




chooseConfigOperation () {
    :
}




chooseMonitorOperation () {
    :
}




chooseMiscOperation () {
    :
}







# TODO when implementing each op menu:
#Set the opcode
#set the clearance mode


 # TODO Add line to the main menu title telling whether the admin has privileges or not, same with ssl status on the ssl emnu, create priv op that returns some vars with no clearance check (one function per var? )













getClearance () {

    #Requiere auth
    $dlg --msgbox $"Para verificar la autoridad para realizar esta acción, procedemos a pedir los fragmentos de llave." 0 0
 	  
    #Pide reconstruir llave sólo para verificar que se tiene autorización de acceso 
    readUsbsRebuildKey  keyonly
    ret=$?
      
    if [ "$ret" -ne 0 ]
	then
	$dlg --msgbox $"No se ha logrado reconstruir la llave. Acceso denegado." 0 0
	doLoop
    fi

    $PVOPS storops checkClearance
    ret=$?    


    if [ "$ret" -eq 1 -o "$ret" -eq 2  ]
	then
	$dlg --msgbox $"No se ha obtenido ninguna llave. Acceso denegado." 0 0
	doLoop
    fi

    if [ "$ret" -eq 3 ]
	then
	$dlg --msgbox $"La llave obtenida no es correcta. Acceso denegado." 0 0
	doLoop
    fi
    
}










##################
#  Main Program  #
##################








#Select which action to execute
chooseMaintenanceAction








#Finished. Continue the main program loop
doLoop










# TODO SEGUIR revisar e integrar



# TODO add a maint option to join esurvey lcn network (if not done during setup, and also to change registration)

#//// Variables a leer cada vez que se lance este script: # TODO revisar esto. probablemente faltan, pero leerlas en cada func, según hagan falta mejor
MGREMAIL=$(getVar disk MGREMAIL)
ADMINNAME=$(getVar disk ADMINNAME)

SHARES=$(getVar usb SHARES)

copyOnRAM=$(getVar mem copyOnRAM)

# TODO leer estas variables para el modo mant? para default en la op de renovar cert ssl?
#"$HOSTNM.$DOMNAME"

sslCertState=$($PVOPS getSslCertState) # TODO use getVar
[ "$sslCertState" == "" ] && echo "Error: debería existir algún estado para el cert."  >>$LOGFILE 2>>$LOGFILE
  
	#Ver cuáles son estrictamente necesarias. borrar el resto////
#	setVarFromFile  $VARFILE MGREMAIL
#	setVarFromFile  $VARFILE ADMINNAME






#Matamos el daemon de entropía, porque, aunque no la carga mucho, consume mucho tiempo de CPU sin hacer nada.
$PVOPS randomSoundStop

#Revocamos el permiso para ejecutar ops privilegiadas.
$PVOPS storops resetAllSlots



#Muestra el menú de opciones y procesa la entrada de usuario
MAINTACTION=''
standBy



#De forma preventiva, anulamos los privilegios de admin. (Si se han elegido en el menu, lo hace en executesystemaction)
grantAdminPrivileges remove


#Reactivamos el daemonde entropía, por si hace falta
$PVOPS randomSoundStart
    


#Si la acción es no privilegiada, se ejecuta ahora y se resetea el bucle.
executeUnprivilegedAction



#Solicitamos los clauers y reconstruímos la clave para autorizar la operación.
obtainClearance



#Ejecuta la operación solicitada
executeSystemAction "running"



#Revocamos el permiso para ejecutar ops privilegiadas (por paranoia).
$PVOPS storops resetAllSlots



# TODO print the operation in course on the background of the window?



#Asegurarme de que se loguean todas las acciones realizadas sobre el servidor. Sacar esto en la app? poner un visor web para la comisión? pedirles contraseñas nuevas para que accedan o una genérica?


# TODO en algún sitio se invoca esto? --> creo que era en el innerkey, pero lo voy a extinguir. si no hace falta, quitar
#    $PVOPS  stopServers



# TODO incluir tb la posibilidad de, en el SSL, instalar una clave privada externa? (por si acaso el porcedimiento de la org lo obliga), pero esta op debe ser con autorización de la comisión, pero esto sólo en el modo mant, no en la inst. --> es un lío y sería poco garante, no vale la pena fomentarlo. Describirlo como proced. de emergencia y ponerlo en el manual, describiendo los pasos para hacerlo desde el terminal. (así menos mantenimiento). hacerlo al final de todo. --> a veces puede ser que la constitución del sistema y la elección vayan muy pegadas... no sé. pensar qué hago.














