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
}




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
#1 -> file path where to read the initial list and where the final list will be written
getEmailList () {
    
    if [ ! -f "$1" ] ; then
        log "input email file does not exist."
        return  2
    fi
    
    local emaillist=""
    exec 4>&1
    while true; do
	       emaillist=$($dlg --backtitle $"Write the e-mail addresses, one per line." \
                         --cancel-label $"Back to the menu" \
                         --editbox "$1" 0 0  2>&1 >&4)
	       [ $? -ne 0  ] &&  return 1 # Go back
        
        #Parse input addresses
	       for eml in $emaillist; do 
	           parseInput email "$eml"
	           if [ $? -ne 0 ] ; then
		              $dlg --msgbox $"There are invalid addresses. Please, check." 0 0
                #Write the user edited list as input of the dialog
                echo "$emaillist" > "$1"
		              continue 2
	           fi
	       done
	       
	       break
    done
    
    #If all ok, write the updated list on the input file
    echo "$emaillist" > "$1"
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
                    admin-update  $"Update administrator credentials and access info." \
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
    
    #Freeze/Unfreeze system
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
        
        
        "admin-update" )
            admin-update
            return $?
            ;;
        
        
        "admin-new" )
            admin-new
            return $?
            ;;
        
        
        "admin-usrpwd" )
            admin-usrpwd
            return $?
            ;;
        
        
        
        ##### Key operations #####
        
        "key-store-validate" )
            key-store-validate
            return $?
            ;;
        
        
        "key-store-pwd" )
            key-store-pwd
            return $?
            ;;
        
        
        "key-validate-key" )
            key-validate-key
            return $?
            ;;
        
        
        "key-renew-key" )
            key-renew-key
            return $?
            ;;
        
        
        "key-emails-set" )
            key-emails-set
            return $?
            ;;
        
        
        "key-emails-get" )
            #Read the list of emails to a temp file
            local current=$($PVOPS getComEmails)
            echo "$current" > /tmp/emails
            
            #Display it
            $dlg --ok-label $"Back" --no-cancel --textbox /tmp/emails 0 0
            
            #Remove the temp file
            rm -f /tmp/emails  >>$LOGFILE  2>>$LOGFILE
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
            ssl-key-renew
            return $?
            ;;
        
        
        
        
        ##### Backup operations #####
        
        "backup-enable" )
            backup-enable
            return $?
            ;;
        
        
        "backup-disable" )
            backup-disable
            return $?
            ;;
        
        
        "backup-config" )
            backup-config
            return $?
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
            config-network
            return $?
            ;;
        
        
        "config-mailer" )
            config-mailer
            return $?
            ;;
        
        
        "config-anonimity" )
            config-anonimity
            return $?
            ;;
        
        
        
        ##### Monitor operations #####
        
        "monitor-sys-monit" )
            monitor-sys-monit
            return $?
            ;;
        
        
        "monitor-stat-reset" )
            monitor-stat-reset
            return $?
            ;;
        
        
        "monitor-log-ops-view" )
            monitor-log-ops-view
            return $?
            ;;
        
        
        
        ##### Miscellaneous operations #####
        
        "misc-shell" )
            misc-shell
            return $?
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
    
    
    #Launch the root terminal with a private operation (will read the
    #e-mail list from the file and send the history)
	   $PVOPS launchTerminal
    if [ $? -eq 1 ] ; then
        $dlg --msgbox $"Error starting terminal session." 0 0
    fi
    
    $dlg --msgbox $"Terminal session terminated." 0 0
    return 0
}





key-emails-set () {
    
    #Try to read the current list, if any (anyways, an initial file is needed)
    local current=$($PVOPS getComEmails)
    echo "$current" > /tmp/emails
    
	   #Input a list of e-mail addresses for the key custory committee
	   getEmailList /tmp/emails
    [ $? -ne 0 ] && return 1 #Cancelled, back to the menu
    
    #Write the updated list
    $PVOPS setComEmails  /tmp/emails
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




#Request a newly issued (or enable existing) letsencrypt certificate,
#and also certbot certificate management
certbot-enable () {
    
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




#Disable letsencrypt issued certificates and certbot certificate
#management, current certificate will be still in place, but a manual
#renewal requets will be generated
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




#Ask to insert, mount and read a usb storage, the read keyshare and
#config will be erased at the end on the keyslot reset
key-store-validate () {
    
    while true
    do
        #Read key fragment and config, so integrity of both blocks
        #will be checked
        readNextUSB "b"
        ret=$?
        msg=""
        [ $ret -eq 1 ] && msg=$"General read error. Please, regenerate key as soon as possible."
        [ $ret -eq 3 ] && msg=$"Data block read error. Please, regenerate key as soon as possible."
        [ $ret -eq 4 ] && msg=$"Read configuration corrupted or tampered. Please, regenerate key as soon as possible."
        #Went OK
        [ $ret -eq 0 ] && msg=$"Read operations successful. Encrypted storage is OK"
        #Operation cancelled
        [ $ret -eq 9 ] && msg=$"Operation cancelled. Back to the main menu"
        
        $dlg --msgbox "$msg" 0 0
        
        break
    done
    
    return $ret
}




#Ask to insert a usb store, it's password and a new password. Set the
#new password on the store.
key-store-pwd () {
    
    #Detect device insertion
    insertUSB $"Insert USB key storage device for password update" $"Cancel"
    [ $? -eq 1 ] && return 9
    if [ $? -eq 2 ] ; then
        #No readable partitions.
        $dlg --msgbox $"Device contained no readable partitions." 0 0
        return 1 
    fi
    
    #Mount the device (will do on /media/usbdrive)
    $PVOPS mountUSB mount $USBDEV
    [ $? -ne 0 ] && return 1 #Mount error

    
    #Ask for current device password
    while true ; do
        #Returns passowrd in $PASSWD
        getPassword auth $"Please, insert the current password for the connected USB device" 1
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Password insertion cancelled." 0 0
            $PVOPS mountUSB umount
            return 2
        fi
	       
        #Access the store on the mounted path and check password
        #(store name is a constant expected by the store handler)
        $PVOPS storops-checkPwd /media/usbdrive/ "$PASSWD" 2>>$LOGFILE
        if [ $? -ne 0 ] ; then
            #Keep asking until cancellation or success
            $dlg --msgbox $"Password not correct." 0 0
            continue
        fi
        break
    done
    local CURRPWD="$PASSWD"
    
    
    #Ask for a new device password (returns password in $PASSWD)
    getPassword new $"Please, insert a new password to protect the connected USB device" 1
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Password insertion cancelled." 0 0
        $PVOPS mountUSB umount
        return 2
    fi
    local NEWPWD="$PASSWD"
    
    
    $dlg  --infobox $"Updating secure storage password..." 0 0
    
    #Do the password update
    $PVOPS storops-changePassword /media/usbdrive/ "$CURRPWD" "$NEWPWD"  >>$LOGFILE  2>>$LOGFILE
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Password change error." 0 0
        return 3
    fi
    
    #Ensure write of the updated store is complete and umount
	   sync
	   $PVOPS mountUSB umount
    
    #Ask the user to remove the usb device
    detectUsbExtraction $USBDEV $"USB device password successfully changed. Remove it and press RETURN." \
                        $"Didn't remove it. Please, do it and press RETURN."
    
    return 0
}



#Will  ask for  all  the  devices (as  in  an authorisation process),
#rebuild the key and then check all read shares for errors.
key-validate-key () {
    
    #Ask for the usb devices and try to rebuild the key
    readUsbsRebuildKey  keyonly
    ret=$?
    msg=''
    [ $ret -eq 1 ] && msg=$"Key rebuild error. Repeat process with more key shares if available"
    [ $ret -eq 2 ] && msg=$"Process cancelled, back to the menu"
    
    if [ $ret -ne 0 ] ; then
        $dlg --msgbox "$msg" 0 0
        return 1
    fi
    
    $dlg --infobox $"Checking key shares..." 0 0
    testForDeadShares
	   #If any share is dead, recommend a key renewal.
	   if [ $? -ne 0 ] ; then
	       $dlg --msgbox $"Corrupt key shares detected. Please, generate and share a new key as soon as possible." 0 0
        return 2
	   fi
    
    $dlg --infobox $"Checking rebuilt key..." 0 0
    $PVOPS storops-checkKeyClearance
    if [ $? -ne 0 ] ; then
	       $dlg --msgbox $"Key doesn't match the system key." 0 0
	       return 3
    fi
    
    $dlg --msgbox $"Key and fragments successfully checked." 0 0
    return 0
}



#Will generate and share a new cipher key and add it to the ciphered
#partition list of authorised keys. If successful, the old one will be
#erased.
key-renew-key () {
    
    $dlg --msgbox $"A new cipher key will be generated and shared among usb drives. PLEASE, USE A NEW SET OF USB DRIVES and keep the old ones. If this process fails at any step, old key will still be valid." 0 0
    
    #Read current variable values
    SHARES=$($PVOPS getPubVar disk  SHARES)
    THRESHOLD=$($PVOPS getPubVar disk  THRESHOLD)
    
    #Allow to change key sharing parameters
    while true ; do
        selectSharingParams
        [ $? -ne 0 ] && return 1 # Cancelled
        
        $dlg --no-label $"Go on"  --yes-label $"Review" --yesno  $"Are you sure to go on with the process?" 0 0 
	       [ $? -eq 0 ] && continue # Review
        break
    done
    
    #Store new variable values
    setVar disk SHARES  "$SHARES"
    setVar disk THRESHOLD  "$THRESHOLD"
    
    
    #Switch slot to generate new key
    $PVOPS storops-switchSlot 2
    
    
    #Generate and fragment persistence drive cipherkey (on the active slot)
    $dlg --infobox $"Generating new shared key for the encrypted disk drive..." 0 0
    $PVOPS genNfragKey $SHARES $THRESHOLD
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error while fragmenting key." 0 0
        return 2 #Failed
    fi
    
    
    #Write key and config to the new usb drive set
    writeUsbs "$SHARES"
    
    
    #Add the new key to the cipherkey list and rmove former one
    $dlg --infobox $"Substituting persistent data cipher key..." 0 0
    $PVOPS substituteKey
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error while substituting key. Old key still valid." 0 0
        return 3 #Failed
    fi
    
    $dlg --msgbox $"Key substitution successful. Keep USB drives containing old key in case they are needed for a backup recovery." 0 0
    return 0
}





#Will allow to set the password for a given user (onviosuly, this can
#only be executed with the previous local authentication of the admin)
admin-usrpwd () {
    
    local username=''
    while true
    do
        #Ask for username
        username=$($dlg --cancel-label $"Back"  --inputbox  \
		                      $"Username for the user whose password will be reset:" 0 0 "$username"  2>&1 >&4)
        #If back, end procedure
        [ "$?" -ne 0 ] && return 1
        
        
        #If the user doesn't exist, repeat
        if (! $PVOPS userExists "$username") ; then
            $dlg --msgbox $"User not found in database. Please, check." 0 0
            continue
        fi
        
        
        #Ask for a new password for the user (returns password in $PASSWD)
        getPassword new $"Please, insert a password for the user:"" $username" 1
        [ $? -ne 0 ]  && continue #Cancelled, start again
        
        break
    done
    
    #Update password
    $PVOPS updateUserPassword "$username" "$PASSWD"
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Password update error. Please, check." 0 0
        return 2
    fi
    
    $dlg --msgbox $"Password updated successfully." 0 0
    return 0;
}





#Renew SSL certificate but generating a new private key
ssl-key-renew () {
    
    #Get the initial values
    HOSTNM=$(getVar disk HOSTNM)
    DOMNAME=$(getVar disk DOMNAME)
    SERVERCN=$(getVar disk SERVERCN)
    
    COMPANY=$(getVar disk COMPANY)
    DEPARTMENT=$(getVar disk DEPARTMENT)
    COUNTRY=$(getVar disk COUNTRY)
    STATE=$(getVar disk STATE)
    LOC=$(getVar disk LOC)
    SERVEREMAIL=$(getVar disk SERVEREMAIL)
    
    #Allow selecting new parameter values if needed
    sslCertParameters
    
    #Generate a new certificate sign request in renew mode
    $PVOPS generateCSR "renew" "$SERVERCN" "$COMPANY" "$DEPARTMENT" "$COUNTRY" "$STATE" "$LOC" "$SERVEREMAIL"
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Certificate renewal error. Please, check." 0 0
        return 1
    fi
    
    #Update variable values
    setVar disk COMPANY "$COMPANY"
    setVar disk DEPARTMENT "$DEPARTMENT"
    setVar disk COUNTRY "$COUNTRY"
    setVar disk STATE "$STATE"
    setVar disk LOC "$LOC"
    setVar disk SERVEREMAIL "$SERVEREMAIL"
    setVar disk SERVERCN "$SERVERCN"
    
    #Set state to renew
    setVar disk SSLCERTSTATE "renew"
    
    $dlg --msgbox $"Certificate request generation successful. Current certificate will still be operative until process is complete." 0 0
    return 0
}





#Allow to reset the administrator credentials (webapp pwd, local pwd, IP address)
admin-update () {

    #Force updating selected admin variable values from the database
    #values (not passwords, they can be overriden here anyhow)
    $PVOPS updateAdminVariables
    
    #Get the initial values from the updated variables
    ADMINNAME=$(getVar disk ADMINNAME)
    ADMREALNAME=$(getVar disk ADMREALNAME)
    ADMIDNUM=$(getVar disk ADMIDNUM)
    ADMINIP=$(getVar disk ADMINIP)
    MGREMAIL=$(getVar disk MGREMAIL)
    
    #Allow selecting new parameter values if needed (some data won't
    #be updateable)
    sysAdminParams lock
    
    
    #Update administrator data on the database and variables (only IP and passwords)
    $PVOPS setAdmin reset "$ADMINNAME" "$MGRPWD" "$ADMREALNAME" "$ADMIDNUM" "$ADMINIP" "$MGREMAIL" "$LOCALPWD"
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error updating administrator credentials." 0 0
        return 1
    fi
    
    $dlg --msgbox $"Administrator credentials update successful." 0 0
    return 0
}     # TODO prueba con acentos, leer de la db cadena con acentos y pintarla





#Prompts to insert new admin user's data and credentials and
#inserts/updates it on the database and does the needed system
#configuration for notification, etc.
admin-new () {
    
    #Allow inserting new admin's info (if the user already exists, it will be updated)
    sysAdminParams
    
    
    #Insert new webapp administrator into the database (internally, it
    #removes privileges tothe former one and checks if the user
    #already exists and updates its info)
    $PVOPS setAdmin new "$ADMINNAME" "$MGRPWD" "$ADMREALNAME" "$ADMIDNUM" "$ADMINIP" "$MGREMAIL" "$LOCALPWD"
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error inserting or updating new administrator's information." 0 0
        return 1
    fi
    
    $dlg --msgbox $"Administrator substitution successful." 0 0
    return 0
}





#Enable daily remote backups
backup-enable () {
    
    #Read the ssh backup parameters and write them to the disk variables
    backup-config
    
    $dlg --infobox $"Configuring SSH backup..." 0 0
    
    #Set trust on the backup server
	   $PVOPS trustSSHServer "$SSHBAKSERVER" "$SSHBAKPORT"
    if [ $? -ne 0 ] ; then
		      $dlg --msgbox $"Error configuring trust in SSH backup server." 0 0
        return 1
	   fi
    
    #Enable the backup cron and database mark
	   $PVOPS enableBackup
    if [ $? -ne 0 ] ; then
		      $dlg --msgbox $"Error configuring SSH backup service. Database service down." 0 0
        return 1
	   fi
    
    $dlg --msgbox $"Backup system successfully enabled." 0 0
    return 0
}





#Disable daily remote backups
backup-disable () {
    
    #Disable the backup cron and database mark
    $PVOPS disableBackup
    if [ $? -ne 0 ] ; then
		      $dlg --msgbox $"Error disabling SSH backup service. Database service down." 0 0
        return 1
	   fi
    
    #Reset backup variables
    setVar disk SSHBAKSERVER ""
	   setVar disk SSHBAKPORT   ""
	   setVar disk SSHBAKUSER   ""
	   setVar disk SSHBAKPASSWD ""
    
    $dlg --msgbox $"Backup system successfully disabled." 0 0
    return 0
}





#Update backup remote server information
backup-config () {
    
    #Get current variable values, if any
    SSHBAKSERVER=$(getVar disk SSHBAKSERVER)
	   SSHBAKPORT=$(getVar disk SSHBAKPORT)
	   SSHBAKUSER=$(getVar disk SSHBAKUSER)
	   SSHBAKPASSWD=$(getVar disk SSHBAKPASSWD)
    
    while true
    do
        #Get backup parameters
        sshBackupParameters
        [ $? -ne 0 ] && return 0 #Cancel
        
        #Check link with ssh server
        $dlg --infobox $"Checking connectivity with SSH server:"" $SSHBAKSERVER" 0 0
        checkSSHconnectivity
        if [ $? -ne 0 ] ; then
            #No link
            $dlg --msgbox $"Connectivity error. Please, check." 0 0
            continue
        fi
        
        break
    done
    
    #Set the updated variables
    setVar disk SSHBAKSERVER "$SSHBAKSERVER"
	   setVar disk SSHBAKPORT   "$SSHBAKPORT"
	   setVar disk SSHBAKUSER   "$SSHBAKUSER"
	   setVar disk SSHBAKPASSWD "$SSHBAKPASSWD"

    $dlg --msgbox $"Backup parameters updated." 0 0
    return 0
}


















config-network () {
    # TODO     #Get current variable values
                    while true ; do
                        networkParams
                        action=$?
                        
                        #User selected to show the menu
                        [ $action -eq 1 ] && break
                        
                        #Setup network and try connectivity
                        configureNetwork
                        if [ $? -ne 0 ] ; then
                            $dlg --yes-label $"Review" --no-label $"Keep" \
                                 --yesno  $"Network connectivity error. Go on or review the parameters?" 0 0
                            #Review them, loop again
                            [ $? -eq 0 ] && continue
                        fi
                        break
                    done
    $dlg --msgbox $"Not implemented." 0 0
    return 0
}

config-mailer () {
    # TODO     #Get current variable values, if any
    mailerParams
    $dlg --msgbox $"Not implemented." 0 0
    return 0
}

config-anonimity () {
    $dlg --msgbox $"Not implemented." 0 0
    #refactor  "10" ) #Anonimity network (optional)
    $dlg --no-label $"Skip"  --yes-label $"Register" \
                         --yesno  $"Do you wish to register your voting service to allow using the eSurvey Anonimity Network?""\n"$"(it can be done later at any moment)" 0 0
                    if [ $? -eq 0 ]
                    then
                        lcnRegisterParams
                        #If go to menu pressed
                        [ $? -ne 0 ] && action=1 && break

                        #Generate the certificate and key
                        $dlg --infobox $"Generating signing certificate for the Anonimity Network Central Authority..." 0 0
                        esurveyGenerateReq
                        if [ $? -ne 0 ] ; then  #If failed
                            action=1
                            $dlg --msgbox $"Error generating Anonimity Service certificate." 0 0
                        fi
                        
                        #Perform the registration
                        esurveyRegisterReq
                        #If failed
                        [ $? -ne 0 ] && action=1
                    else
                        #If skipped, generate a generic certificate
                        #for internal usage
                        SITESEMAIL="-"
                        SITESORGSERV="-"
                        SITESNAMEPURP="-"
                        SITESCOUNTRY="-"
                        $dlg --infobox $"Generating vote signing certificate" 0 0
                        esurveyGenerateReq
                        if [ $? -ne 0 ] ; then  #Failed
                            action=1
                            $dlg --msgbox $"Error generating voting service certificate." 0 0
                        fi
                    fi
    return 0
}




monitor-sys-monit () {
    $dlg --msgbox $"Not implemented." 0 0
    return 0
}

monitor-stat-reset () {
    $dlg --msgbox $"Not implemented." 0 0
    return 0
}

monitor-log-ops-view () {
    $dlg --msgbox $"Not implemented." 0 0
    return 0
}













##################
#  Main Program  #
##################


#Preemtive status reset (this wal, all operations start at slot 1 and
#all are clean)
$PVOPS storops-resetAllSlots
$PVOPS storops-switchSlot 1


#Idle screen. Select which action to execute
chooseMaintenanceAction


#Check if the operation needs any clearance and obtain it (clear any
#possibly existing key clearance)
getClearance "$MAINTACTION"
clearance=$?

#Failed to get clearance. Go to the idle screen
if [ $clearance -ne 0 ] ; then
    doLoop
fi



#Execute the selected operation
executeMaintenanceOperation "$MAINTACTION"



#Clean key slots to minimise key exposure (I know it's redundant, I don't care)
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
