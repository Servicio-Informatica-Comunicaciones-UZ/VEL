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
    log "**Looping to the maintenance menu**"
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
    log "returned SSL status: $status"
    
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




#Allows the user to input a list of e-mails
#OUTPUT FILE: /home/vtuji/shellSessionRecipients -> list of e-mails
getEmailList () {
    # Needs a file to be displayed, so we create an empty file
    echo -n "" > /tmp/empty
    
    local emaillist=""
    exec 4>&1 
    while true; do
	       emaillist=$($dlg --backtitle $"Write the e-mail addresses of the recipients of the session logs." \
                         --cancel-label $"Back to the menu" \
                         --editbox /tmp/empty 0 0  2>&1 >&4)
	       [ $? -ne 0  ] &&  return 1 # Go back
        
        #Parse input addresses
	       for eml in $emaillist; do 
	           parseInput email "$eml"
	           if [ $? -ne 0 ] ; then
		              $dlg --msgbox $"There are invalid addresses. Please, check." 0 0
                #Write the former list as input of the dialog
                echo "$emaillist" > /tmp/empty
		              continue 2
	           fi
	       done
	       
	       break
    done
    rm -f /tmp/empty >>$LOGFILE 2>>$LOGFILE
    
    echo "$emaillist" > /home/vtuji/shellSessionRecipients
    return 0
}




#Main maintenance menu
#Will set the following globals (the calls to the submenus will):
#MAINTACTION: which action to perform
chooseMaintenanceAction () {
    
    #Get the privilege status for the admin
    local adminprivileges=""
    adminprivileges=$(getAdminPrivilegeStatus)
    local adminprivStatus=$?
    
    local color=1 #If privileges, show in red
    [ $adminprivStatus -eq 0 ] && color=2 # If no privileges, show in green
    
    exec 4>&1
    while true; do
        MAINTACTION=''
        CLEARANCEMODE='key' #Default clearance mode
        
        local title=''
        title=$title$"Maintenance operations categories""\n"
        title=$title"===============================\n"
        title=$title"  * ""\Zb"$"Administrator privileges"": \Zn\Z$color""$adminprivileges""\Zn\Z0""\n"
        
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
    log "current SSL state ($sslstate): $sslstateText"
    
    if [ $sslstate -eq 0 ] ; then #ok
        local certInstallText=$"Install a renewed certificate but keeping the private key."
        local color=2 #Green
    elif [  $sslstate -eq 1 ] ; then #dummy
        local certInstallText=$"Install the pending certificate, overwriting the temporary one."
        local color=1 #Red
    elif [  $sslstate -eq 2 ] ; then #renew
        local certInstallText=$"Install the pending certificate and substitute the currently operative one."
        local color=3 #Yellow
    else
        log "Bad sslcert status code returned $sslstate"
    fi

    #These ops depend on certbot, if activated, they don't appear
    sslCsrReadTag="ssl-csr-read"
    sslCsrReadText=$"Get the certificate sign request."
    
    sslCertInstallTag="ssl-cert-install"
    sslCertInstallText="$certInstallText" 
    
    sslKeyRenewTag="ssl-key-renew"
    sslKeyRenewText=$"Renew the SSL certificate and private key."
    
    local usingCertbot=$($PVOPS getPubVar disk USINGCERTBOT)
    certbotTag=certbot-enable
    certbotItem=$"Use a Let's Encrypt automated Certificate."                      
    if [ "$usingCertbot" -eq 1 ] ; then
        certbotTag=certbot-disable
        certbotItem=$"Disable Let's Encrypt automated Certificate."
        
        sslCsrReadTag=""
        sslCsrReadText=""
        sslCertInstallTag=""
        sslCertInstallText=""
        sslKeyRenewTag=""
        sslKeyRenewText=""
    fi
    
    
    local title=''
    title=$title$"SSL certificate management""\n"
    title=$title"===============================\n"
    title=$title"  * ""\Zb"$"SSL certificate status"": \Zn\Z$color""$sslstateText""\Zn"
    
    local selec=''
    while true ; do
        selec=$($dlg --cancel-label $"Back" --no-tags --colors \
                     --menu "$title" 0 90  5  \
                     "$certbotTag"        "$certbotItem"        \
                     "$sslCsrReadTag"     "$sslCsrReadText"     \
                     "$sslCertInstallTag" "$sslCertInstallText" \
                     "$sslKeyRenewTag"    "$sslKeyRenewText"    \
	                    2>&1 >&4)
        #Chose to go back
        [ $? -ne 0 ] && return 1
        #When there are deactivated options and one is selected, don't go on
        [ "$selec" == "" ] && continue
        break
    done
    
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
    local frozen=$($PVOPS getPubVar mem SYSFROZEN)
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
            $PVOPS  grantAdminPrivileges
            if [ $? -ne 0 ] ; then
                $dlg --msgbox $"Error accessing database." 0 0            
                return 1
            fi
            $dlg --msgbox $"The administrator will now have extended access to the voting application. Don't forget to remove the privileges before holding an election." 0 0
            return 0
            ;;

        
        "admin-priv-remove" )
            $PVOPS  removeAdminPrivileges
            if [ $? -ne 0 ] ; then
                $dlg --msgbox $"Error accessing database." 0 0            
                return 1
            fi
            $dlg --msgbox $"Administrator privileges removed." 0 0
            return 0
            ;;
        
        
        "admin-auth" )
            admin-auth
            return $?
            ;;
        
        # TODO seguir faltan por implementar
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
            # free operation (we will call the rebuild internally, not on clearance request)
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
        
        "certbot-enable" )
            certbot-enable
            return 0
            ;;
        
        "certbot-disable" )
            certbot-disable
            return 0
            ;;

        "ssl-csr-read" )
            ssl-csr-read
            return 0
            ;;
        
        "ssl-cert-install" )
            ssl-cert-install
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
        
        
        
        "backup-config" )
            $dlg --msgbox $"Not implemented." 0 0
            return 0
            ;;
        
        
        
        "backup-force" )
            $dlg --yes-label $"Back" --no-label $"Force Backup" \
                 --yesno  $"If you force a backup, you will stop the voting application until the backup is done. Are you sure it is safe to do it right now? This operation will be logged." 0 0
            if [ $? -ne 0 ] ; then
                $PVOPS forceBackup
                $dlg --msgbox $"System services will be stopped until the backup copy is done." 0 0
            fi
            return 0
            ;;
        
        
        
        "backup-unfreeze" )
            $dlg --msgbox $"System services will be restored immediately." 0 0
            $PVOPS unfreezeSystem
            if [ $? -ne 0 ] ; then
                $dlg --msgbox $"Error unfreezing. Some services were unable to start. Please, check." 0 0
            fi
            return 0
            ;;
        
        
        
        "backup-freeze" )
            $dlg --yes-label $"Back" --no-label $"Freeze System" \
                 --yesno  $"This will stop the voting application and all system services until you unfreeze the system. Are you sure it is safe to do it right now? This operation will be logged." 0 0
            if [ $? -ne 0 ] ; then
                $PVOPS freezeSystem
                if [ $? -ne 0 ] ; then
                    $dlg --msgbox $"Error freezing. Some services were unable to stop. Please, check." 0 0
                else
                    $dlg --msgbox $"System services stopped." 0 0
                fi
            fi
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
            misc-shell
            return 0
            ;;
        
        
        
        "misc-pow-suspend" )
            $dlg --yes-label $"Back" --no-label $"Suspend" \
                 --yesno  $"Are you sure?" 0 0
            if [ $? -ne 0 ] ; then
                $PVOPS suspend
            fi
            [ $? -eq 1 ] && $dlg --msgbox $"Can't suspend if disc is not in memory." 0 0
            return 0
            ;;
        
        
        
        "misc-pow-shutdown" )
            $dlg --yes-label $"Back" --no-label $"Shutdown" \
                 --yesno  $"Are you sure?" 0 0
            if [ $? -ne 0 ] ; then
                $PVOPS shutdownServer "h"
            fi
            return 0
            ;;
        
        
        
	       * )
            #No operation code
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
                   monitor-sys-monit    monitor-log-ops-view
                   misc-pow-suspend     misc-pow-shutdown  "

    #List of operations that can be executed just with administrator
    #local password authentication
    local pwdOps="admin-usrpwd
                  key-emails-get
                  ssl-csr-read        ssl-cert-install   ssl-key-renew
                  backup-force        backup-freeze      backup-unfreeze
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
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error accessing database." 0 0            
        return 1
    fi
    
    $dlg --msgbox $"Administrator authentication successful." 0 0
    return 0
}




#Launch a root terminal to perform any emergency and unexpected admin
#tasks not available in the operations menu. This is only a last
#resort and gives full access to the administrator, so keep him under
#expert supervision
misc-shell () {
    
    #Big red warning, screen is shown for at least 3 seconds after hitting a button
    $dlg --yes-label $"Go on" --no-label $"Back" --colors --sleep 3 --yesno \
         "\Zb\Z1"$"WARNING!""\Zn\n\n"$"Opening a root terminal gives the administrator full access to the system. This is a delicate situation, as he""\n\Zb\Z1"$"CAN POTENTIALLY BREAK THE SECURITY AND INTEGRITY OF FUTURE ELECTIONS.""\Zn\n"$"You will receive an e-mail with the history of commands used by him for audit purposes, but there are ways to circumvent this security measure.""\n\Zb\Z1"$"KEEP HIM UNDER THE SUPERVISION OF AN INDEPENDENT QUALIFIED TECHNICIAN AT ALL TIMES""\Zn" 0 0
    #Go Back to the menu
    [ $? -ne 0 ] && return 1
    
    
	   #Insert a list of e-mail addresses where the shell history will be
	   #delivered (additionally to the commission ones, defined elsewhere)
	   getEmailList
    [ $? -ne 0 ] && return 1 #Back to the menu
    
    #Launch the root terminal with a private operation (will read the
    #e-mail list from the file and send the history)
	   $PVOPS launchTerminal /home/vtuji/shellSessionRecipients
    if [ $? -eq 1 ] ; then
        $dlg --msgbox $"Error processing e-mail list." 0 0
    fi
    
    rm /home/vtuji/shellSessionRecipients >>$LOGFILE 2>>$LOGFILE

    $dlg --msgbox $"Terminal session terminated." 0 0
}





#Read the current/to renew CSR to sign or renew the SSL certificate
ssl-csr-read () {
    
    $dlg --msgbox $"Insert a usb device to write the current SSL certificate request." 0 0
    fetchCSR cancel
    
    $dlg --msgbox $"Certificate request successfully read." 0 0
}



#Install a SSL certificate, either for the current test certificate or
#a new one for a new key or for the same key
ssl-cert-install () {
    local ret=0

    while true
    do
        #Detect device insertion
        insertUSB $"Insert USB storage device" $"Cancel"
        ret=$?

        [ $ret -eq 1 ] && return 1 #Cancelled, return
        if [ $ret -eq 2 ] ; then
            #No readable partitions found.
            $dlg --msgbox $"Device contained no readable partitions." 0 0
            continue
        fi
        
        #Mount the device (will do on /media/usbdrive)
        $PVOPS mountUSB mount $USBDEV
        if [ $? -ne 0 ] ; then
            #Mount error. Try another one
            $dlg --msgbox $"Error mounting the device." 0 0
            continue
        fi
        
        break
    done
    
    while true
    do   
        #Ask for the SSL certificate file
        selectUsbFilepath $"The signed SSL certificate file"
        if [ $? -ne 0 ] ; then
            $PVOPS mountUSB umount
            return 1 #Cancelled, return
        fi
        local sslcertFile="$chosenFilepath"
        
        #Ask for the SSL certificate chain file
        selectUsbFilepath $"The certificate authority chain for the SSL certificate"
        if [ $? -ne 0 ] ; then
            $PVOPS mountUSB umount
            return 1 #Cancelled, return
        fi
        local chainFile="$chosenFilepath"
        
        #Read the files, parse them and if legitimate, install them
        $PVOPS installSSLCert "$sslcertFile" "$chainFile"
        ret=$?        
        if [ $ret -eq 0 ] ; then
            $dlg --msgbox $"SSL certificate successfully installed." 0 0
            $PVOPS mountUSB umount
            return 0
        fi
        #If error, show it and loop (can cancel there)
        [ $ret -eq 1 ] && $dlg --msgbox $"Certificate is not a valid x509." 0 0
        [ $ret -eq 2 ] && $dlg --msgbox $"Self signed certificates not allowed" 0 0
        [ $ret -eq 3 ] && $dlg --msgbox $"Certificate does not match the private key" 0 0
        [ $ret -eq 4 ] && $dlg --msgbox $"Some certificate in the CA chain is not valid. Check them." 0 0
        [ $ret -eq 5 ] && $dlg --msgbox $"Failed validating chain trust and certificate purpose." 0 0
        [ $ret -eq 6 ] && $dlg --msgbox $"Error configuring webserver." 0 0
        [ $ret -eq 7 ] && $dlg --msgbox $"Error configuring mail server" 0 0
        continue
        
    done
}





certbot-enable () {
    
    # TODO SEGUIR MAÑANA : en el enable, hay que pedir los params, por si es la primera vez (y grabar en disco dichos params).? En principio se pidieron en el install. He de poder cambiarlos en cada renew sea certbot o no?  Revisar todas las ops de ssl y ver enc uáles he de permitir cambiar los params del cert a generar, y sobretodo la autorización para ello (si se puede tocar el nombre de dominio, hará falta comisión, y en algunos no debería) Yen este de certbot debería? si el update es automático y nu ca cambia. Quizá añadir una nueva opción con comisión y que permita cambiar los params, ver si puedo hacer una sólo para  params y luego usar el resto para normal y certbot. Cómo afectará al certbot el que yo cambie el dominio? se enlazará adecuadamente como cert activo? --> creo que en ese caso los links de setupCertbot deberán machacar lo existente y rehacerse cada vez que se llame a esta func.
    
    $dlg --infobox $"Configuring Let's Encrypt SSL certificate..." 0 0
    $PVOPS setupCertbot
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error enabling certificate service." 0 0 # TODO set different return codes and set different messages
        log "certbot enable error"
        return 1
    fi

    
    $PVOPS startApache
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error restarting web server." 0 0
	       log "Error restarting apache" 
	       return 1
	   fi
    
    $PVOPS mailServer-reload
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error restarting mail server." 0 0
	       log "Error restarting postfix" 
	       return 1
	   fi
    
    $dlg --msgbox $"Certbot successfully enabled." 0 0
    return 0
}



certbot-disable () {
    
    $dlg --infobox $"Disabling certbot, generating new certificate request..." 0 0
    
    #Forces a certificate renew
    $PVOPS disableCertbot
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error on the certificate renewal generation." 0 0
        log "certbot disable error"
        return 1
    fi
    
    $dlg --msgbox $"Successfully disabled. Current certbot certificate will keep working until expiration or the new one is installed. Please, get the signing request to complete the process." 0 0
    return 0
}












##################
#  Main Program  #
##################


#redirectError


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








# TODO ELIMINAR LA VERSIÓN ESTÁTICA de index.php antes de actualizar
# el bundle de nuevo


# TODO add a maint option to join esurvey lcn network (if not done
# during setup, and also to change registration)

#TODO Asegurarme de que se loguean todas las acciones realizadas sobre
#el servidor. Sacar esto en la app? poner un visor web para la
#comisión? pedirles contraseñas nuevas para que accedan o una
#genérica?

# TODO: add a maint option to change ip config [commis. authorisation]
# --> this existed, just was not yet moved from the old script and was
# not in the new ones. same happend to some other ops.

# TODO --> we could also add a maint option to allow changing the ssh
# backup location (and without the authorisation of the com. only the
# admin password) --> do it. now the params are on disk
