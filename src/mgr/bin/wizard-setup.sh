#!/bin/bash


##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh



##################################
#  Global Variables / Constants  #
##################################

#Terminal is being set to dumb. Although we change it on the
#bootstrapper, we need to set it here as well to allow for curses to
#work
export TERM=linux




#############
#  Methods  #
#############



#Log function
log () {
    echo  "["$(date --rfc-3339=ns)"][wizard-setup]: "$*  >>$LOGFILE 2>>$LOGFILE
}



#Main setup menu
chooseMaintenanceAction () {
    
    exec 4>&1
    while true; do
        selec=$($dlg --no-cancel --no-tags --menu $"Select an action:" 0 80  6  \
	                    start   $"Start voting system." \
                     setup   $"Setup new voting system." \
	                    recover $"Recover a voting system backup." \
	                    term    $"Launch administrator terminal." \
                     reboot  $"Reboot system." \
	                    halt    $"Shutdown system." \
	                    2>&1 >&4)
        
        case "$selec" in
	           "start" )
                DOSTART=1
                DOINSTALL=0
                DORESTORE=0
	               return 1
                ;;
            
	           "setup" )
                #Double check option if user chose to format
                $dlg --yes-label $"Back" --no-label $"Format system" \
                     --yesno  $"You chose NEW system.\nThis will destroy any previous installation of the voting system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOSTART=0
	               DOINSTALL=1
                DORESTORE=0
	               return 2
                ;;
            
            "recover" )
                #Double check option if user chose to recover
                $dlg --yes-label $"Back" --no-label $"Recover backup" \
                     --yesno  $"You chose to RECOVER a backup.\nThis will destroy any changes on a previously existing system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOSTART=0
	               DOINSTALL=0
	               DORESTORE=1
	               return 3
                ;;
	           
	           "term" )
	               $dlg --yes-label $"Yes" --no-label $"No"  \
                     --yesno  $"WARNING:\n\nYou chose to open a terminal. This gives free action powers to the administrator. Make sure he does not operate it without proper technical supervision. Do you wish to continue?" 0 0
	               [ "$?" -ne 0 ] && continue
                $PVOPS rootShell
                continue
                ;;
	           
	           "reboot" )	
	               $dlg --yes-label $"Cancel"  --no-label $"Reboot" --yesno $"Are you sure to go on?" 0 0
	               [ "$?" -eq 1 ] && shutdownServer "r"
	               continue
	               ;;	
		          
	           "halt" )	
	               $dlg --yes-label $"Cancel"  --no-label $"Shutdown" --yesno $"Are you sure to go on?" 0 0
	               [ "$?" -eq 1 ] && shutdownServer "h"
	               continue
	               ;;
	           
	           * )
	               log "main operation selector: bad selection. This must not happen" 
                continue
	               ;;
	       esac   
    done
    shutdownServer "h"
}



#Returns which parameter gathering section to access next to retake base flow
#Returns 254 on cancel (max value: 255)
selectParameterSection () {
    exec 4>&1
    local selec=''
    while true; do
        selec=$($dlg --cancel-label $"Go back to the main menu" \
                     --no-tags \
                     --menu $"Select parameter section:" 0 80  11  \
	                    1  $"Set local timezone." \
                     2  $"Network configuration." \
	                    3  $"Encrypted drive configuration." \
	                    4  $"SSH system backup." \
                     5  $"Mail server configuration." \
	                    6  $"Secret sharing parameters." \
	                    7  $"System administrator data." \
	                    8  $"SSL certificate." \
	                    9  $"Key strength." \
	                    10 $"Anonimity Network Registration (optional)." \
                     99 $"Continue to system setup" \
	                    2>&1 >&4)
        [ "$selec" != "" ] && return $selec
        return 254
    done
}

#Stores those configuration variables that go to the disk
setDiskVariables () {
    
    setVar disk IPMODE  "$IPMODE"
	   setVar disk HOSTNM  "$HOSTNM"
    setVar disk DOMNAME "$DOMNAME"
    setVar disk IPADDR  "$IPADDR"
	   setVar disk MASK    "$MASK"
	   setVar disk GATEWAY "$GATEWAY"
	   setVar disk DNS1    "$DNS1"
	   setVar disk DNS2    "$DNS2"
    
    setVar disk TIMEZONE "$TIMEZONE"
    
    setVar disk SSHBAKSERVER "$SSHBAKSERVER"
	   setVar disk SSHBAKPORT   "$SSHBAKPORT"
	   setVar disk SSHBAKUSER   "$SSHBAKUSER"
	   setVar disk SSHBAKPASSWD "$SSHBAKPASSWD"
    
    setVar disk MAILRELAY "$MAILRELAY"
    
    setVar disk ADMINNAME "$ADMINNAME"
    setVar disk ADMIDNUM "$ADMIDNUM"
    setVar disk ADMREALNAME "$ADMREALNAME"
	   setVar disk MGREMAIL "$MGREMAIL"
    setVar disk ADMINIP "$ADMINIP"
    
    setVar disk KEYSIZE   "$KEYSIZE"
    
    #Some of these are used on the webapp, for the STORK authentication # TODO review: will we still support STORK?
    setVar disk SITESORGSERV  "$SITESORGSERV"
	   setVar disk SITESNAMEPURP "$SITESNAMEPURP"
	   setVar disk SITESEMAIL    "$SITESEMAIL"
	   setVar disk SITESCOUNTRY  "$SITESCOUNTRY"
    setVar disk SITESTOKEN    "$SITESTOKEN"
    
    #These are saved only to be loaded as defaults on the maintenance operation form
    setVar disk COMPANY "$COMPANY"
    setVar disk DEPARTMENT "$DEPARTMENT"
    setVar disk COUNTRY "$COUNTRY"
    setVar disk STATE "$STATE"
    setVar disk LOC "$LOC"
    setVar disk SERVEREMAIL "$SERVEREMAIL"
    setVar disk SERVERCN "$SERVERCN"
}

#Reads needed variables from the usb config file
getUsbVariables () {
    
    getVar usb DRIVEMODE
    getVar usb DRIVELOCALPATH
	   getVar usb FILEPATH
	   getVar usb FILEFILESIZE
    getVar usb CRYPTFILENAME
    
    getVar usb SHARES
    getVar usb THRESHOLD
}

#Reads needed variables from the disk config file
getDiskVariables () {

    getVar disk IPMODE
	   getVar disk HOSTNM
    getVar disk DOMNAME
    getVar disk IPADDR
	   getVar disk MASK
	   getVar disk GATEWAY
	   getVar disk DNS1
	   getVar disk DNS2
    
    getVar disk TIMEZONE
    
    getVar disk SSHBAKSERVER
	   getVar disk SSHBAKPORT
	   getVar disk SSHBAKUSER
	   getVar disk SSHBAKPASSWD

    getVar disk MAILRELAY

    getVar disk ADMINNAME
    getVar disk ADMIDNUM
    getVar disk ADMREALNAME
	   getVar disk MGREMAIL
    getVar disk ADMINIP
	   getVar disk LOCALPWDSUM # TODO decide how we use this password for semi-priv op verification and if it must be loaded here (maybe, an op to check it)
    
    getVar disk KEYSIZE
    
    getVar disk SITESORGSERV
	   getVar disk SITESNAMEPURP
    getVar disk SITESTOKEN
}



#Lets user select his timezone
#Will set the global var TIMEZONE
selectTimezone () {

    local defaultItem="Europe"
    local tzArea=''
    local tz=''
    exec 4>&1
    while true
    do
        local areaOptions=$(ls -F  /usr/share/zoneinfo/right/ | grep / | sed -re "s|/| |g")
        tzArea=$($dlg --no-items --cancel-label $"Menu" --default-item $defaultItem \
                      --menu $"Choose your timezone" 0 50 15 $areaOptions   2>&1 >&4)
        [ $? -ne 0 -o "$tzArea" == ""  ] && return 1 #Go to the menu
        
        defaultItem=$tzArea
        
        local tzOptions=$(ls /usr/share/zoneinfo/right/$tzArea | sed -re "s|$| |g")
        tz=$($dlg --no-items --cancel-label $"Back" --menu $"Choose your timezone" 0 50 15 $tzOptions   2>&1 >&4)
        [ $? -ne 0 -o "$tz" == "" ]  && continue
        
        break
    done
    
    #Need to use return global because stdout cannot be redirected due to dialog using it
    TIMEZONE="$tzArea/$tz"
    
    return 0
}


#Lets the user select which key lengths to use on the web app for the elections
#Will set the global var KEYSIZE
selectKeySize () {
    KEYSIZE=""
    exec 4>&1
    local choice=''
    choice=$($dlg --cancel-label $"Menu" \
                  --menu $"Select a size for the RSA keys:" 0 30  5  \
	                 1024 $"bit" \
	                 1152 $"bit" \
	                 1280 $"bit" \
	                 2>&1 >&4)
    #Selected back to the menu
    [ $? -ne 0  -o  "$choice" == "" ] && return 1
    
    KEYSIZE="$choice"
    log "KEYSIZE: $KEYSIZE"  
    
    return 0
}








##################
#  Main Program  #
##################



#This block is executed just once (skipped after invoking this same
#script from inside itself)
if [ "$1" == "" ]
    then        
        #Launch pivileged setup phase 1, where some security and
        #preliminary system setup is made
        $PSETUP   init1
        
        
        #Print credits
        $dlg --msgbox "UJI Telematic voting system v.$VERSION" 0 0
        
        
        #Show language selector
        exec 4>&1 
        lan=""
        while [ "$lan" == "" ]
        do
            lan=$($dlg --no-cancel  --menu "Select Language:" 0 40  3  \
	                      "es_ES" "Español" \
	                      "ca_ES" "Català" \
	                      "en_US" "English" \
	                      2>&1 >&4)
        done
        export LANGUAGE="$lan.UTF-8"
        export LANG="$lan.UTF-8" 
        export LC_ALL=""
        
        # TODO rebuild localization from scratch.
        #    export TEXTDOMAINDIR=/usr/share/locale
        #    export TEXTDOMAIN=wizard-setup.sh  # TODO ver si es factible invocar a los otros scripts con cadenas localizadas. Si no, separar las funcs y devolver valores para que las acdenas se impriman en este (y considerarlo tb por seguridad una vez funcione todo)
        
        #Relaunch self with the selected language
        exec  "$0" "$lan"
fi


log "Selected language: $LANGUAGE" 

#Keyboard is selected automatically
case "$LANGUAGE" in     
    "es_ES.UTF-8" ) 
    $PSETUP loadkeys es   
    ;;
    
    "ca_ES.UTF-8" ) 
    $PSETUP loadkeys es   
    ;;
esac


#Check any existing RAID arrays
$PSETUP checkRAIDs
if [ $? -ne 0 ] ; then
    $dlg --msgbox $"Error: failed RAID volume due to errors or degradation. Please, solve this issue before going on with the system installation/boot. You will be prompted with a root shell. Reboot when finished." 0 0
    exec $PVOPS rootShell
fi



#If possible, Move CD filesystem to system memory
$dlg  --msgbox $"To avoid tampering, all the CD content will be loaded to RAM memory" 0 0
force=0
while true
do
    $dlg --infobox $"Copying CD filesystem to system memory..."  0 0
    $PSETUP moveToRAM $force
    ret=$?
    
    #Not enough memory
    if [ $ret -eq 1 ] ; then
        $dlg --msgbox $"Not enough free memory. CD content won't be copied. System physical tampering protection cannot be assured." 0 0
    fi
    
    #Low memory
    if [ $ret -eq 2 ] ; then
        aufsFreeSize=$($PVOPS getFilesystemSize aufsFreeSize)
        cdfsSize=$($PVOPS getFilesystemSize cdfsSize)
        
        #Let the user decide
        $dlg --yes-label $"Copy"  --no-label $"Do not copy" --yesno  $"Amount of free memory may be insufficient for a proper functioning in certain conditions.""\n\n"$"Available memory:"" $aufsFreeSize MB\n"$"Size of the CD filesystem:"" $cdfsSize MB\n\n"$"Copy the system if you belive usage won't be affected" 0 0
        if [ "$?" -eq 0  ] ; then
            force=1
            continue
        fi
    fi
    
    #Copy successful
    if [ $ret -eq 0 ] ; then
        #Calculate and show available space at the end
	       aufsFinalFreeSize=$($PVOPS getFilesystemSize aufsFreeSize)
        $dlg --msgbox $"Copy successful.""\n\n"$"Still available RAM filesystem space:"" $aufsFinalFreeSize MB." 0 0
    fi
    
    break
done



#Init usb and slot system management
$PVOPS storops init

#Store the chosen language as a memory variable
setVar mem LANGUAGE "$LANGUAGE"



#Main action loop
while true
do
    
    #Clean active slot, to avoid inconsistencies
    $PVOPS storops resetAllSlots
    
    
    
    #Select startup action
    chooseMaintenanceAction
    
    
    
    
    #On fresh install, show EULA
    if [ "$DOINSTALL" -eq 1 ] ; then
        $dlg --extra-button --extra-label $"I do not agree" --no-cancel \
             --ok-label $"I agree"  --textbox /usr/share/doc/License.$LANGUAGE 40 80
        #Does not accept EULA, halt
        [ $? -eq 3 ] && shutdownServer "h"
    fi

    #On restore, inform about the procedure # TODO CHECK IF THE PROCEDURE IS RIGHT, review that all sections of the restore are right and well ordered
    if [ "$DORESTORE" -eq 1 ] ; then
        $dlg --msgbox $"You chose to restore a backup. A fresh installation will be performed first, where you will be able to change basic configuration. Please, use a NEW SET of usb drives on it. You will be asked to insert the OLD SET at the end to perform the restoration." 0 0
    fi
    
    
    
    
    ##### Ask for the configuration parameters #####
    if [ "$DOINSTALL" -eq 1  -o  "$DORESTORE" -eq 1 ]
    then
        
        # Get all configuration parameters [some perform ad-hoc configurations]
        nextSection=1
        while true
        do
            
            case "$nextSection" in     

                "1" ) #Timezone
                    selectTimezone
                    action=$?
                    ;;
                
                
                "2" ) #Network
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
                    ;;
                
                
                "3" ) #Persistence encrypted data drive 
                    selectCryptoDriveMode
                    action=$?
                    ;;
                
                
                "4" ) #SSH backup
                    #It is an optional feature
                    $dlg  --yes-label $"Yes" --no-label $"No" \
                          --yesno $"Do you want to set up periodic system backups through SSH?" 0 0
	                   if [ $? -ne 0 ] ; then #No
                        SSHBAKSERVER="" #To mark it is not used
                        action=0 #Go on
                    else
                        while true; do
                            #Get backup parameters
                            sshBackupParameters
                            action=$?
                            #If go to menu pressed
                            [ $action -ne 0 ] && break

                            #Check link with ssh server
                            $dlg --infobox $"Checking connectivity with SSH server:"" $SSHBAKSERVER" 0 0
                            checkSSHconnectivity
                            #No link
                            if [ $? -ne 0 ] ; then
                                #Ask to continue or go back
                                $dlg --no-label $"Continue"  --yes-label $"Review parameters" \
                                     --yesno  $"SSH server connectivity error. Continue or review parameters?" 0 0
                                #Selected back"
                                [ $? -eq 0 ] && continue
                            fi
                            break
                        done
                    fi
                    ;;
                
                
                "5" ) #Mail server
                    mailerParams
                    action=$?
                    ;;
                
                
                "6" ) #Secret sharing
                    selectSharingParams
                    action=$?
                    ;;
                
                
                "7" ) #System administrator
                    sysAdminParams
                    action=$?
                    ;;
                
                
                "8" ) #SSL certificate
                    sslCertParameters
                    action=$?
                    ;;
                
                
                "9" ) #Key lengths
                    selectKeySize
                    action=$?
                    ;;
                
                
                "10" ) #Anonimity network (optional)
                    action=0
                    $dlg --no-label $"Skip"  --yes-label $"Register" \
                         --yesno  $"Do you wish to register your voting service to allow using the eSurvey Anonimity Network?""\n"$"(it can be done later at any moment)" 0 0
                    if [ $? -eq 0 ]
                    then
                        lcnRegisterParams
                        #If go to menu pressed
                        [ $? -ne 0 ] && action=1 && break
                        
                        #Perform the registration
                        esurveyRegisterReq
                        #If failed
                        [ $? -ne 0 ] && action=1
                    fi
                    ;;
                
                
                * ) #Confirmation to proceed with setup
                    $dlg --no-label $"Proceed with Setup"  --yes-label $"Back to the Menu" \
                         --yesno  $"Now the system will be installed. Are you sure all configuration parameters are correct?" 0 0 
                    
                    #Go on with setup
                    [ "$?" -eq "1" ] && break
                    
                    #Go back to the menu
                    action=1
                    ;;
            esac
            
            #Go to next section
            if [ $action -eq 0 ] ; then
                nextSection=$((nextSection+1))
            else
                #Show parameter sections menu
                selectParameterSection
                ret=$?
                nextSection=$ret
                
                #Go back to the main menu
                [ $ret -eq 254 ] && continue 2
            fi
        done
        
        #Set vars that will be put to the usb store (only the basic
        #ones, needed to load the encrypted drive)
        setVar usb DRIVEMODE "$DRIVEMODE"
        setVar usb DRIVELOCALPATH "$DRIVELOCALPATH"
	       setVar usb FILEPATH "$FILEPATH"
	       setVar usb FILEFILESIZE "$FILEFILESIZE"
        setVar usb CRYPTFILENAME "$CRYPTFILENAME"
        
        setVar usb SHARES "$SHARES"
        setVar usb THRESHOLD "$THRESHOLD"
        
        #Generate and fragment persistence drive cipherkey (on the active slot)
        $dlg --infobox $"Generating shared key for the encrypted disk drive..." 0 0
        $PVOPS genNfragKey $SHARES $THRESHOLD
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Error while fragmenting key." 0 0
            continue #Failed, go back to the menu
        fi
    fi
    
    
    
    
    
    
    ######## Get parameters and key from usb drives ##########  # TODO review this block while implementing backup recovery
    if [ "$DOSTART" -eq 1  -o  "$DORESTORE" -eq 1 ] ; then
        #We need to obtain a cipherkey and config parameters from a set of usb stores
        $dlg --msgbox $"We need to rebuild the shared cipher key.""\n"$"You will be asked to insert all available usb devices holding key fragments" 0 0
        
        #Read all available usbs from the commission and try to
        #rebuild the shared key
        readUsbsRebuildKey
        ret=$?
        [ $ret -eq 1 ] && continue  #Key rebuild error, go back to the menu
        [ $ret -eq 2 ] && continue  #USer cancelled, go back to the menu
        
        
        #If this is a simple startup, check whether any share is corrupted
        if [ "$DOSTART" -eq 1 ]
	       then
    	       $dlg --infobox $"Checking all key shares..." 0 0
            testForDeadShares
	           #If any share is dead, recommend a key renewal.
	           if [ $? -ne 0 ] ; then
	               $dlg --msgbox $"Corrupt key shares detected. Please, generate and share a new key as soon as possible." 0 0 
	           fi
        fi
        echo "Press RETURN to continue..." && read #breakpoint # TODO remove # TODO SEGUIR imprime valores de variables y temo que no se estén seteando. Revisar bien
        #Read (as globals) the configuration variables needed on the setup
        getUsbVariables
    fi
    
    
    
    
    
    
    ######## Setup system #########
    
    
    mode='new'
    [ "$DOINSTALL" -eq 0 ] && mode='reset'
    
    
    #Setup ciphered persistence drive
    configureCryptoPartition "$mode"
    [ $? -ne 0 ] && continue #Failed, go back to the menu

    
    #Move system logs to the drive
    relocateLogs "$mode"
    
    
    
    #Save config variables on the persistent ciphered drive after installing it
    if [ "$DOINSTALL" -eq 1  -o  "$DORESTORE" -eq 1 ] ; then
        setDiskVariables
    fi
    
    #On startup, get the required vars instead
    if [ "$DOSTART" -eq 1 ] ; then 
        getDiskVariables
    fi
    
    
    
    
    #Configure network [only on reload]
    if [ "$DOSTART" -eq 1 ]
    then
        configureNetwork
        [ $? -ne 0 ] && $dlg --msgbox $"Network connectivity error. We'll go on with system load. At the end, please, check." 0 0
    fi
    
    #Setup hosts file and hostname, and also
    #mail server hostname configuration
    configureHostDomain
    
    
    
    #Configure timezone
    $PSETUP setupTimezone "$TIMEZONE"    
    
    #Make sure time is synced
    $dlg   --infobox $"Syncronizing server time..." 0 0
    $PSETUP forceTimeAdjust
    
    
    
    #Configure mysql (also, if new, generate users and passwords)
    $dlg --infobox $"Configuring database server..." 0 0
    errinfo=""
    $PSETUP setupDatabase "$mode"
    ret=$?
    [ $ret -eq 2 ] && errinfo=$"Error copying database to ciphered drive. Not enough space or destination not found."
    [ $ret -eq 3 ] && errinfo=$"Error starting database daemon. Please, check."
    [ $ret -eq 4 ] && errinfo=$"Error while changing default passwords. Please, check."
    if [ $ret -ne 0 ] ; then
        $dlg --msgbox $"Error configuring database server."" $errinfo" 0 0
        continue #Failed, go back to the menu
    fi
    
    
    
    
    ### Setup web app database
    if [ "$DOINSTALL" -eq 1 ]
    then
        
        #Build the database with the base configuration
        $PSETUP populateDB
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Error configuring database." 0 0
            continue #Failed, go back to the menu
        fi
        
        #Generate ballot box rsa keypair and insert it into DB
        $dlg --infobox $"Generate Ballot Box keys..." 0 0
        $PSETUP generateBallotBoxKeys
        
        #Miscellaneous database options
        $dlg --infobox $"Configuring web application data..." 0 0
        $PSETUP setWebAppDbConfig
        
        #If anonymity network registration process was performed, insert data
        if [ "$SITESTOKEN" != "" ] ; then
            $PVOPS storeLcnCreds "$SITESTOKEN" "$SITESPRIVK" "$SITESCERT" "$SITESEXP" "$SITESMOD"
        fi
        
        #Insert webapp administrator into the database
        $PVOPS setAdmin new "$ADMINNAME" "$MGRPWD" "$ADMREALNAME" "$ADMIDNUM" "$ADMINIP" "$MGREMAIL" "$LOCALPWD" 
    fi
    
    
    
    
    #Set admin e-mail as the alias for root, so he will receive all
    #system notifications (already done on install on setAdmin)
    $PSETUP setupNotificationMails
    
    
    
    
    #If using SSH backups, configure it
    if [ "$SSHBAKSERVER" != ""  ] ; then
        
        $dlg --infobox $"Configuring SSH backup..." 0 0
        
        #Set trust on the backup server
	       $PVOPS trustSSHServer "$SSHBAKSERVER" "$SSHBAKPORT"
        if [ $? -ne 0 ] ; then
		          $dlg --msgbox $"Error configuring SSH backup service." 0 0
            continue #Failed, go back to the menu
	       fi
        
        #Enable the backup cron and database mark
	       $PVOPS enableBackup
    else
        #Otherwise, remove cron (if any) and mark the databse
        $PVOPS disableBackup
    fi
    
    
    
    
    #Handle SSL certificate
    if [ "$DOINSTALL" -eq 1 ]
    then        
	       #Generate the certificate signing request for the SSL connections
	       generateCSR "new"
	       [ $? -ne 0 ] && continue #Failed, go back to the menu
	       
        #Generate temporary self-signed certificate from the csr.
	       $PSETUP generateSelfSigned
        
        #Store the SSL certificate current state
        setVar disk SSLCERTSTATE  "dummy" #Currently running with a self-signed
    fi
    
    #Set the certificate and key on the route expected by apache and postfix 
    $PVOPS setupSSLcertificate
    
    
    
    
    #Configure apache web server    
    $dlg --infobox $"Configuring web services..." 0 0
    
    #Set configuration variables on the web app's PHP scripts
    $PVOPS processPHPScripts
    
    #Start daemon
    $PVOPS startApache
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error activating web server." 0 0
        continue #Failed, go back to the menu
    fi
    
    
    
    
    #Configure postfix mail server
    $dlg --infobox $"Configuring mail server..." 0 0
    
    $PVOPS mailServer relay "$MAILRELAY"
    $PVOPS mailServer reload
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Error activating mail server." 0 0
        continue #Failed, go back to the menu
    fi
    
    
    
    
    #Setup statistics system  # TODO review everything regarding this. Do it at the end
    $dlg --infobox $"Setting up statistics system..." 0 0
    if [ "$DOINSTALL" -eq 1 ] ; then
	       #Build RRDs
	       $PVOPS stats startLog 
    fi
    
    #Setup cron that updates the results and generates the graphics
    $PVOPS stats installCron # TODO review this op.
    
    #Draw the stat graphs
    $PVOPS stats updateGraphs  >>$LOGFILE 2>>$LOGFILE  # TODO review this op.
    
    
    
    
    #Reconfigure power management package to fit the specific hardware
    $dlg --infobox $"Configuring power management..." 0 0
    $PSETUP pmutils
    
    
    
    
    #Final setup steps: initial firewall whitelist, RAID test e-mail
    $dlg --infobox $"Last configuration steps..." 0 0
    $PSETUP init4
    [ $? -ne 0 ] && $dlg --msgbox $"RAID arrays detected. You will receive an e-mail with the test result." 0 0
    
    
    
    
    if [ "$DOINSTALL" -eq 1 ] ; then
        #Give privileged access to the webapp to the administrator (temporary)
        grantAdminPrivileges  grant
    else
        #Explicitly remove privileges to the administrator on reload
        grantAdminPrivileges  remove
    fi
    
    
    
    
    if [ "$DOINSTALL" -eq 1 ] ; then
        
        #Store certificate request (won't let go until it is written
        #on a usb)
        $dlg --msgbox $"Insert a usb device to write the generated SSL certificate request." 0 0
        fetchCSR
        
        
        
        #Share key and basic config on usbs to be kept by the
        #commission (usbs must have avalid data partition)
        $dlg --msgbox $"Now we'll write the key shares on the commission's usb drives. Make sure these drives are cleanly formatted and free of any other key shares currently in use, as they might be overwritten." 0 0
        writeUsbs "$SHARES"
    fi
    
    
    
    
    #Force a backup after installation is complete
    $PVOPS forceBackup
    
    
    #Lock privileged operations. Any privileged action invoked from
    #now will need a key reconstruction
    $PSETUP lockOperations
    
    
    #Clean any remaining rebuilt keys.
    $PVOPS storops resetAllSlots
    
    
    #Send test e-mails and do the final security adjustments to lock down
    #all scripts and operations not needed anymore
    $PSETUP init5
    $dlg --msgbox $"You must receive an e-mail as a proof for the notification system working properly. Check your inbox" 0 0
    
    
    
    
    #Inform the user that system is successfully running
    $dlg --msgbox $"System is running properly.""\n"$"The administrator has now privileged access to the voting web application. Don't forget to remove privileges before running an election. Otherwise he will have the means to disenfranchise targeted voters." 0 0
    
    
    #Go into the maintenance mode. Process context is overriden with a new
    #one for security reasons
    # exec /bin/bash  /usr/local/bin/wizard-maintenance.sh  # TODO SEGUIR  poner que el wizard-maintenance saque un terminal directo y compilar para primeras pruebas.
    exec /bin/bash # TODO borrar
    
    
    
    break
done #Main action loop
log "wizard maintenance loop script execution failed."
exit 42







# TODO reimplementar backup retrieval    ######## Retrieve backup to restore #########  # TODO revisar y reintegrar todo el sistema de backup y de recuperación
# TODO: now show before anything, recovery is not dependent on usb config (later will need thekey, but just as when starting. Add here setup entry)
# TODO on a recovery, ask the backup location parameters there, don't expect to read them from the usbs. Also, on the fresh install he will be able to set new ssh bak location (but on restoring, the values on the hard drive will be there. should we overwrite them? should we avoid defining certain things on a fresh install?) --> should we do this instead?: ask for the restoration clauers at the beginning, and ask for the ssh backup location (and provisional ip config). retrieve backup, setup hdd, restoee ******** I'm getting dizzy, think this really carefully. restoration is an emergency procedure and should not mess with the other ones, leave the other ones simple and see later what to do with this, I personally prefer to have the ip and ssh bak config on the hard drive and minimise usb config. if this means making a whole special flow for the restore, then it is. Think carefully what we backup and what we restore.
    

# TODO implement a delayed rebuilt key anulation? this way, multiple privileged actions can be performed without bothering the keyholders. think about this calmly. maybe a file with the last action timestamp and a cron? but I think it's too risky...



# TODO any action not requiring a key rebuild, now will require admin's local pwd


# TODO: add a maint option to change ip config [commis. authorisation] --> this existed, just was not yet moved from the old script and was not in the new ones. same happend to some other ops.

# TODO --> we could also add a maint option to allow changing the ssh backup location (and without the authorisation of the com. only the admin password) --> do it. now the params are on disk

# TODO  asegurarme de que sólo es el root quien ejecuta los backups. ver eprms de ficheros, ver qué hace la bd y la app php, ver mi  script y si hay cron de backup
