#!/bin/bash



##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh




###############
#  Constants  #
###############






#############
#  Methods  #
#############




#Log function
log () {
    echo "["$(date --rfc-3339=ns)"][wizard-maintenance]: "$*  >>$LOGFILE 2>>$LOGFILE
}





#Wrapper for the privileged operation to set a variable
# $1 -> Destination: 'disk' persistent disk;
#                    'mem'  (default) or nothing if we want it in ram;
#                    'usb'  if we want it on the usb config file;
#                    'slot' in the active slot configuration
# $2 -> variable
# $3 -> value
setVar () {    
    $PVOPS setVarSafe "$1" "$2" "$3"
}



#Wrapper for the privileged operation to get a variable value	
# $1 -> Where to read the var from 'disk' disk;
#                                  'mem' or nothing if we want it from volatile memory;
#                                  'usb' if we want it from the usb config file;
#                                  'slot' from the active slot's configuration
# $2 -> var name (to be read)
#STDOUT: the value of the read variable, empty string if not found
#Returns: 0 if it could find the variable, 1 otherwise.
getVar () {
    $PVOPS getVarSafe $1 $2
    return $?
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




#Get the current status of the ssl certificate
#STDOUT: echoes the human localised readable status string
#RETURN: the privilege status code
getSSLCertificateStatus () {
    
    local status=$($PVOPS getPubVar disk  SSLCERTSTATE) #dummy, renew, ok
    
    if [ "$status" == "ok" ] ; then
        echo -n $"Running on proper certificate"
        return 0
    elif [ "$status" == "renew" ] ; then
        echo -n $"Expecting certificate for the new key"
        return 2
    else # "dummy"
        echo -n $"Running on test certificate"
        return 1
    fi
}




#Main maintenance menu
#Will set the following globals (the calls to the submenus will):
#MAINTACTION: which action to perform
chooseMaintenanceAction () {
    
    #Get the privilege status for the admin
    local adminprivileges=$(getAdminPrivilegeStatus)
    
    exec 4>&1
    while true; do
        MAINTACTION=''
        CLEARANCEMODE='key' #Default clearance mode
        
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
    
    #Get the privilege status for the admin (ret 0: no privilege). If the
    #user has privileges (ret 1), show remove operation and
    #viceversa
    if (getAdminPrivilegeStatus >>$LOGFILE 2>>$LOGFILE) ; then
        local grantRemovePrivilegesLineTag=admin-priv-grant
        local grantRemovePrivilegesLineItem=$"Grant privileges to the administrator."
    else
        local grantRemovePrivilegesLineTag=admin-priv-remove
        local grantRemovePrivilegesLineItem=$"Remove privileges for the administrator."
    fi
    
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu $"Administrator operations" 0 60  7  \
                    "$grantRemovePrivilegesLineTag" "$grantRemovePrivilegesLineItem" \
                    admin-auth    $"Administrator local authentication." \
                    admin-update  $"Update administrator credentials and info." \
                    admin-new     $"Set new administrator user." \
                    admin-usrpwd  $"Set password for another user." \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}




chooseKeyOperation () {
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu $"Shared key management." 0 60  8  \
                 key-store-validate  $"Verify USB storage integrity." \
                 key-store-pwd       $"Change password of a USB storage drive." \
                 key-validate-key    $"Verify full key integrity." \
                 key-renew-key       $"Renew key and/or change comission composition." \
                 key-emails-set      $"Set/change comission's e-mail adresses." \
                 key-emails-get      $"View comission's e-mail adresses." \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}




chooseSSLOperation () {

    local sslstateText=''
    sslstateText=$(getSSLCertificateStatus)
    local sslstate=$?
    
    if [ $sslstate -eq 0 ] ; then #ok
        local certInstallText=$"Install a renewed certificate but keeping the private key."
    elif [  $sslstate -eq 1 ] ; then #dummy
        local certInstallText=$"Install the pending certificate, overwriting the temporary one."
    elif [  $sslstate -eq 2 ] ; then #renew
        local certInstallText=$"Install the pending certificate and subtitute the currently operative one."
    else
        log "Bad sslcert status code returned $sslstate"
    fi
    
    local title=''
    title=$title$"SSL certificate management""\n"
    title=$title"===============================\n"
    title=$title"  * ""\Zb"$"SSL certificate status"": \Z5""$sslstateText""\ZN"
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu "$title" 0 90  5  \
                 ssl-csr-read      $"Get the certificate sign request." \
                 ssl-cert-install  $certInstallText \
                 ssl-key-renew     $"Renew the SSL certificate and private key." \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}




chooseBackupOperation () {

    #Enable/Disable backups (other operations are also dependant)
    if ($PVOPS isBackupEnabled) ; then #It is enabled
        local backupEnableTag=backup-disable
        local backupEnableItem=$"Disable SSH backups."

        local backupForceTag=backup-force
        local backupForceItem=$"Force a backup now."
        
        local backupConfigTag=backup-config
        local backupConfigItem=$"Change backup configuration."
        
    else #It is disabled
        local backupEnableTag=backup-enable
        local backupEnableItem=$"Enable SSH backups."

        local backupForceTag=''
        local backupForceItem=''

        local backupConfigTag=''
        local backupConfigItem=''
    fi
    
    #Freeze/Unfreeze system   # SYSFROZEN TODO añadir esta var a mem, autorizarla en getpub, hacer ops de freeze y unfreeze
    local frozen=$($PVOPS getPubVar SYSFROZEN)
    if [ "$frozen" -eq 1 ] ; then
        local freezeTag=backup-unfreeze
        local freezeItem=$"Enable services again."
    else
        local freezeTag=backup-freeze
        local freezeItem=$"Disable services temporarily."
    fi
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu $"Backup system management." 0 60  6  \
                    "$backupEnableTag"  "$backupEnableItem" \
                    "$freezeTag"        "$freezeItem" \
                    "$backupForceTag"   "$backupForceItem" \
                    "$backupConfigTag"  "$backupConfigItem" \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}




chooseConfigOperation () {
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu $"System configuration." 0 60  5  \
                 config-network    $"Change network connection parameters." \
                 config-mailer     $"Change mail server configuration." \
                 config-anonimity  $"Anonimity network registration." \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}




chooseMonitorOperation () {
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu $"Monitoring operations." 0 60  5  \
                 monitor-sys-monit     $"System monitor." \
                 monitor-stat-reset    $"Reset statistics database." \
                 monitor-log-ops-view  $"Examine executed operations log." \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}




chooseMiscOperation () {
    
    local selec=''
    selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                 --menu $"Other operations." 0 60  5  \
                 misc-shell         $"Open an administrator shell." \
                 misc-pow-suspend   $"Suspend computer." \
                 misc-pow-shutdown  $"Shutdown computer." \
	                2>&1 >&4)
    
    #Chose to go back
    [ $? -ne 0 -o "$selec" == ""  ] && return 1
    
    #Set the operation code
    MAINTACTION="$selec"
    
    return 0
}










#Execute the chosen operation. Clearance must have been obtained
#before this.
#1 -> operation code
#RETURN: 0: Everything went well, 1: Error
executeMaintenanceOperation () {
    
    #Set clearance requirements based on the operation
    case "$1" in

        ##### Admin operations #####
        
	       "admin-priv-grant" )
            $dlg --msgbox $"Not implemented." 0 0
            #$PVOPS  grantAdminPrivileges
            return 0
            ;;

        "admin-priv-remove" )
            $dlg --msgbox $"Not implemented." 0 0
            #$PVOPS  removeAdminPrivileges
            return 0
            ;;
        
        "admin-auth" )
            admin-auth
            return 0
            ;;
        
        "admin-update" )  # TODO Esta op, leer los datos de la bd, borrar vars inútiles del fichero de disco
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "admin-new" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "admin-usrpwd" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;

        ##### Key operations #####
        
        "key-store-validate" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "key-store-pwd" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "key-validate-key" )
            $dlg --msgbox $"Not implemented." 0 0
            #Validate key is:
            # No-clearance (we will call the rebuild internally, not on clearance request)
            # readUsbsRebuildKey keyonly #So the usbs are requested and the key rebuilt if possible (with the earliest available comb)
            # testForDeadShares #Where all shares are tested on reconstruction, so we know all are ok
            # $PVOPS storops-checkKeyClearance #Where the key is compared with the actual one, so we know it is not an alien key
            return 0
            ;;
        
        "key-renew-key" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "key-emails-set" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "key-emails-get" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        ##### SSL certificate operations #####
        
        "ssl-csr-read" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "ssl-cert-install" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "ssl-key-renew" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        ##### Backup operations #####
        
        "backup-enable" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "backup-disable" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "backup-force" )
            $dlg --msgbox $"Not implemented." 0 0
            #TODO backup-force will freeze and unfreeze automatically and then call the backup script or let the services running and then wait for the cron to act? Hablar con manolo a ver cómo era el backup en la app, si yo fuerzo qué pasa porque esté activa
            return 0
            ;;
        
        "backup-config" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "backup-unfreeze" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "backup-freeze" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        ##### Configuration operations #####
        
        "config-network" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "config-mailer" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "config-anonimity" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        ##### Monitor operations #####
        "monitor-sys-monit" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "monitor-stat-reset" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "monitor-log-ops-view" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        ##### Miscellaneous operations #####
        
        "misc-shell" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "misc-pow-suspend" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        "misc-pow-shutdown" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
	       * )
            #No operation code # TODO see how to handle
            $dlg --msgbox $"Bad operation code"": $1." 0 0
            log "Bad operation code: $1."
            return 1
	           ;;
	   esac
    
    return 0
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
    local freeOps="admin-auth           admin-priv-remove  
                   key-store-validate   key-store-pwd         key-validate-key
                   backup-unfreeze
                   monitor-sys-monit    monitor-log-ops-view
                   misc-pow-suspend     misc-pow-shutdown  "

    #List of operations that can be executed just with administrator
    #local password authentication
    local pwdOps="admin-usrpwd
                  key-emails-get
                  ssl-csr-read        ssl-cert-install   ssl-key-renew
                  backup-force        backup-freeze
                  monitor-stat-reset  "
    # TODO quizá añadir 'admin-priv-grant' a pwdOps cuando la app notifique y loguee el estado claramente
    #TODO crear sistema de logs de interés para la comisión y los admins. usar el oplog? un log de app y el oplog para la de mant? otro log para añadir al acta de una elec? añadir a este oplog además de ops realizadas, el etado de privilegio, auths locales, ediciones de usuarios en la BD, bajas de votos y bajas/altas de votantes en una elección una vez está iniciada... ver qué más cosas pueden dejar de ser ejecutadas sólo bajo privilegio a ejecutarse siempre con logs.
    
    #If no operation code, then reject
    if [ "$1" == "" ] ; then
        log "getClearance: No operation code"
        return 1
    fi
    
    #If operation needs no authorisation, go on
    if (contains "$freeOps" "$1") ; then
        log "getClearance: Operation $1 needs no authorisation. Go on"
        return 0
    fi
    
    
    #If operation needs password authorisation
    if (contains "$pwdOps" "$1") ; then
        
        $dlg --msgbox $"You need to be the system administrator to perform this operation. Please, authenticate." 0 0
        
        #Ask for the admin's local password (will set PASSWD)
        getPassword auth $"Administrator Local Password" 1
        [ $? -ne 0 ] && return 1 #Cancelled password insertion
            
        #Check the challenge password against the actual one
        $PVOPS authAdmin "$PASSWD"
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Password not valid." 0 0            
            return 1
        fi
        
        #Authentication successful
        return 0
    fi
    
    
    #Else, any other operation (by default), will require the highest
    #clearance: the shared ciphering key
    $dlg --msgbox $"To validate your clearance to perform this operation, you will be requested to rebuild the shared key. Please, prepare the comission usb drives" 0 0
    
    #Ask for the usb devices and try to rebuild the key
    readUsbsRebuildKey  keyonly
    [ $? -ne 0 ] && return 1  #Key rebuild error or user cancelled
    
    #Check if key is the expected one
    $PVOPS storops-checkKeyClearance
    if [ $? -ne 0 ] ; then
	       $dlg --msgbox $"Key not valid. Access denied." 0 0
	       return 1
    fi
    
    #Key is valid
    return 0
}







################
#  Operations  #
################




#Authenticate the user locally and, if successful, mark the database
#to grant an additional auth point
admin-auth () {
    
    #Ask for the admin's local password (will set PASSWD)
    getPassword auth $"Insert Administrator Local Password" 1
    [ $? -ne 0 ] && return 1 #Cancelled password insertion
    
    #Check the challenge password against the actual one
    $PVOPS authAdmin "$PASSWD"
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Password not valid." 0 0            
        return 1
    fi
    
    #Grant the additional auth point in the database.
    $PVOPS raiseAdminAuth
    return $?
}




















##################
#  Main Program  #
##################




#Idle screen. Select which action to execute
chooseMaintenanceAction



#Check if the operation needs any clearance and obtain it (clear any
#possibly existing key clearance)
$PVOPS storops-resetAllSlots
getClearance "$MAINTACTION"
clearance=$?

#Failed to get clearance. Go to the idle screen
if [ $clearance -ne 0 ] ; then
    doLoop
fi



#Execute the selected operation
executeMaintenanceOperation "$MAINTACTION"



#Clean key slots to minimise key exposure
$PVOPS storops-resetAllSlots

#Clean admin authentication, if any
$PVOPS clearAuthAdmin


#Finished. loop to the idle screen
doLoop





# TODO add a maint option to join esurvey lcn network (if not done during setup, and also to change registration)

#//// Variables a leer cada vez que se lance este script: # TODO revisar esto. probablemente faltan, pero leerlas en cada func, según hagan falta mejor
#MGREMAIL=$(getVar disk MGREMAIL)
#ADMINNAME=$(getVar disk ADMINNAME)

#SHARES=$(getVar usb SHARES)

#copyOnRAM=$(getVar mem copyOnRAM)

# TODO leer estas variables para el modo mant? para default en la op de renovar cert ssl?
#"$HOSTNM.$DOMNAME"

  
	#Ver cuáles son estrictamente necesarias. borrar el resto////
#	setVarFromFile  $VARFILE MGREMAIL
#	setVarFromFile  $VARFILE ADMINNAME





# TODO print the operation in course on the background of the window?



#Asegurarme de que se loguean todas las acciones realizadas sobre el servidor. Sacar esto en la app? poner un visor web para la comisión? pedirles contraseñas nuevas para que accedan o una genérica?


# TODO en algún sitio se invoca esto? --> creo que era en el innerkey, pero lo voy a extinguir. si no hace falta, quitar
#    $PVOPS  stopServers



# TODO incluir tb la posibilidad de, en el SSL, instalar una clave privada externa? (por si acaso el porcedimiento de la org lo obliga), pero esta op debe ser con autorización de la comisión, pero esto sólo en el modo mant, no en la inst. --> es un lío y sería poco garante, no vale la pena fomentarlo. Describirlo como proced. de emergencia y ponerlo en el manual, describiendo los pasos para hacerlo desde el terminal. (así menos mantenimiento). hacerlo al final de todo. --> a veces puede ser que la constitución del sistema y la elección vayan muy pegadas... no sé. pensar qué hago.














