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




#Get the current status of the admin privileges
#STDOUT: echoes the human localised readable status string
#RETURN: the privilege status code
getAdminPrivilegeStatus () {
    
    if ($PVOPS adminPrivilegeStatus) ; then #if zero, no privilege
        echo -n $"None"
        return 0
    else
        echo -n $"Active"
        return 1
    fi
}




#Main maintenance menu
#Will set the following globals (the calls to the submenus will):
#MAINTACTION: which action to perform
#CLEARANCEMODE: how authorisation must be seeked
chooseMaintenanceAction () {
    
    #Get the privilege status for the admin
    local adminprivileges=$(getAdminPrivilegeStatus)
    
    exec 4>&1
    while true; do
        MAINTACTION=''
        
        local title=''
        title=$title$"Maintenance operations categories""\n"
        title=$title"===============================\n"
        title=$title"  * ""\Zb"$"Administrator privileges"": \Z5""$adminprivileges""\ZN\Z0""\n"
        
        local selec=$($dlg --no-cancel --no-tags --colors \
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
	               log "Main operation selector: bad selection. This must not happen"
                continue
	               ;;
	       esac
        break
    done
    
    return 0
}




chooseAdminOperation () {
    
    #Get the privilege status for the admin (0: no privilege)
    
    #If the user has privileges, show remove operation and viceversa
    if (getAdminPrivilegeStatus >>$LOGFILE 2>>$LOGFILE) ; then
        grantRemovePrivilegesLineTag=admin-priv-grant
        grantRemovePrivilegesLineItem=$"Grant privileges to the administrator."
    else
        grantRemovePrivilegesLineTag=admin-priv-remove
        grantRemovePrivilegesLineItem=$"Remove privileges for the administrator."
    fi
    
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu $"Administrator operations" 0 60  9  \
                    $grantRemovePrivilegesLineTag $grantRemovePrivilegesLineItem \
                    admin-auth    $"Administrator local authentication." \
                    admin-update  $"Update administrator credentials and info." \ # TODO Esta op, leer los datos de la bd, borrar vars
                    admin-new     $"Set new administrator user." \
                    admin-usrpwd  $"Set password for another user." \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    
    #Set clearance requirements based on the operation
    case "$selec" in
	       "admin-group" )
            
        ;;
        
        
	       
	       * )
            #No selection, back
            return 1
	           ;;
	   esac
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}




chooseKeyOperation () {
    
    return 1
}




chooseSSLOperation () {
        sslstate=$"OK"

    title=$title"  * ""\Zb"$"SSL certificate status"":       \Z5""$sslstate""\ZN"
    
    return 1
}




chooseBackupOperation () {
    
    return 1
}




chooseConfigOperation () {
    
    return 1
}




chooseMonitorOperation () {
    
    return 1
}




chooseMiscOperation () {
    
    return 1
}







# TODO when implementing each op menu:
#Set the opcode
#set the clearance mode


 # TODO Add line to the main menu title telling whether the admin has privileges or not, same with ssl status on the ssl emnu, create priv op that returns some vars with no clearance check (one function per var? )













getClearance () {

    #Requiere auth
    $dlg --msgbox $"Para verificar la autoridad para realizar esta acci�n, procedemos a pedir los fragmentos de llave." 0 0
 	  
    #Pide reconstruir llave s�lo para verificar que se tiene autorizaci�n de acceso 
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

#//// Variables a leer cada vez que se lance este script: # TODO revisar esto. probablemente faltan, pero leerlas en cada func, seg�n hagan falta mejor
MGREMAIL=$(getVar disk MGREMAIL)
ADMINNAME=$(getVar disk ADMINNAME)

SHARES=$(getVar usb SHARES)

copyOnRAM=$(getVar mem copyOnRAM)

# TODO leer estas variables para el modo mant? para default en la op de renovar cert ssl?
#"$HOSTNM.$DOMNAME"

sslCertState=$($PVOPS getSslCertState) # TODO use getVar
[ "$sslCertState" == "" ] && echo "Error: deber�a existir alg�n estado para el cert."  >>$LOGFILE 2>>$LOGFILE
  
	#Ver cu�les son estrictamente necesarias. borrar el resto////
#	setVarFromFile  $VARFILE MGREMAIL
#	setVarFromFile  $VARFILE ADMINNAME






#Matamos el daemon de entrop�a, porque, aunque no la carga mucho, consume mucho tiempo de CPU sin hacer nada.
$PVOPS randomSoundStop

#Revocamos el permiso para ejecutar ops privilegiadas.
$PVOPS storops resetAllSlots



#Muestra el men� de opciones y procesa la entrada de usuario
MAINTACTION=''
standBy



#De forma preventiva, anulamos los privilegios de admin. (Si se han elegido en el menu, lo hace en executesystemaction)
grantAdminPrivileges remove


#Reactivamos el daemonde entrop�a, por si hace falta
$PVOPS randomSoundStart
    


#Si la acci�n es no privilegiada, se ejecuta ahora y se resetea el bucle.
executeUnprivilegedAction



#Solicitamos los clauers y reconstru�mos la clave para autorizar la operaci�n.
obtainClearance



#Ejecuta la operaci�n solicitada
executeSystemAction "running"



#Revocamos el permiso para ejecutar ops privilegiadas (por paranoia).
$PVOPS storops resetAllSlots



# TODO print the operation in course on the background of the window?



#Asegurarme de que se loguean todas las acciones realizadas sobre el servidor. Sacar esto en la app? poner un visor web para la comisi�n? pedirles contrase�as nuevas para que accedan o una gen�rica?


# TODO en alg�n sitio se invoca esto? --> creo que era en el innerkey, pero lo voy a extinguir. si no hace falta, quitar
#    $PVOPS  stopServers



# TODO incluir tb la posibilidad de, en el SSL, instalar una clave privada externa? (por si acaso el porcedimiento de la org lo obliga), pero esta op debe ser con autorizaci�n de la comisi�n, pero esto s�lo en el modo mant, no en la inst. --> es un l�o y ser�a poco garante, no vale la pena fomentarlo. Describirlo como proced. de emergencia y ponerlo en el manual, describiendo los pasos para hacerlo desde el terminal. (as� menos mantenimiento). hacerlo al final de todo. --> a veces puede ser que la constituci�n del sistema y la elecci�n vayan muy pegadas... no s�. pensar qu� hago.














