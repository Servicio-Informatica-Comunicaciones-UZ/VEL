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



# TODO Cuando elija la config, renombrar a un nombre genérico e ignorar el resto



#############
#  Methods  #
#############


# TODO extinguir systemPanic, al menos en el wizard. cambiar por msgbox y ya


# TODO: now show before anything, recovery is not dependent on usb config (later will need thekey, but just as when starting. Add here setup entry)


#Main setup menu
chooseMaintenanceAction () {
    
    exec 4>&1
    while true; do
        selec=$($dlg --no-cancel  --menu $"Select an action:" 0 80  6  \
	                    1 $"Start voting system." \
                     2 $"Setup new voting system." \
	                    3 $"Recover a voting system backup." \
	                    4 $"Launch administrator terminal." \
                     5 $"Reboot system." \
	                    6 $"Shutdown system." \
	                    2>&1 >&4)
        
        case "$selec" in
	           "1" )
                DOBUILDKEY=1
                DOFORMAT=0
                DORESTORE=0
	               return 1
                ;;
            
	           "2" )
                #Double check option if user chose to format
                $dlg --yes-label $"Back" --no-label $"Format system" \
                     --yesno  $"You chose NEW system.\nThis will destroy any previous installation of the voting system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOBUILDKEY=0
	               DOFORMAT=1
                DORESTORE=0
	               return 2
                ;;
            
            "3" )
                #Double check option if user chose to recover
                $dlg --yes-label $"Back" --no-label $"Recover backup" \
                     --yesno  $"You chose to RECOVER a backup.\nThis will destroy any changes on a previously existing system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOBUILDKEY=1
	               DOFORMAT=1
	               DORESTORE=1
	               return 3
                ;;
	           
	           "4" )
	               $dlg --yes-label $"Yes" --no-label $"No"  \
                     --yesno  $"WARNING:\n\nYou chose to open a terminal. This gives free action powers to the administrator. Make sure he does not operate it without proper technical supervision. Do you wish to continue?" 0 0
	               [ "$?" -eq 1 ] && continue
	               [ "$?" -eq 0 ] && exec $PVOPS rootShell
                exec /bin/false
                ;;
	           
	           "5" )	
	               $dlg --yes-label $"Cancel"  --no-label $"Reboot" --yesno $"Are you sure to go on?" 0 0
	               [ "$?" -eq 1 ] && shutdownServer "r"
	               continue
	               ;;	
		          
	           "6" )	
	               $dlg --yes-label $"Cancel"  --no-label $"Shutdown" --yesno $"Are you sure to go on?" 0 0
	               [ "$?" -eq 1 ] && shutdownServer "h"
	               continue
	               ;;
	           
	           * )
	               echo "systemPanic: bad selection"  >>$LOGFILE 2>>$LOGFILE
	               $dlg --msgbox "BAD SELECTION" 0 0
	               shutdownServer "h"
	               ;;
	       esac   
    done
    shutdownServer "h"
}



#Returns which parameter gathering secion to access next to retake base flow
#Returns 254 on cancel
selectParameterSection () {
    exec 4>&1
    local selec=''
    while true; do
        selec=$($dlg --cancel-label $"Go back to the main menu"  --menu $"Select parameter section:" 0 80  6  \
	                    1 $"Set local timezone." \
                     2 $"Network configuration." \
	                    3 $"Encrypted drive configuration." \ # TODO add here all ops in the flow
	                    4 $"SSH system backup." \
                     5 $"aa." \
	                    6 $"aa." \
                     99 $"Continue to system setup" \
	                    2>&1 >&4)
        [ "$selec" != "" ] && return $selec
        return 254
    done
}





#Lets user select his timezone
#Will set the global var TIMEZONE
selectTimezone () {

    local defaultItem="Europe"
    exec 4>&1
    while true
    do
        local areaOptions=$(ls -F  /usr/share/zoneinfo/right/ | grep / | sed -re "s|/| - |g")
        local tzArea=$($dlg --cancel-label $"Menu" --default-item $defaultItem --menu $"Choose your timezone" 0 50 15 $areaOptions   2>&1 >&4)        
        if [ "$tzArea" == ""  ] ; then
	           $dlg --msgbox $"Please, select a timezone area." 0 0
	           continue
        fi
        defaultItem=$tzArea
        
        local tzOptions=$(ls /usr/share/zoneinfo/right/$tzArea | sed -re "s|$| - |g")
        local tz=$($dlg --cancel-label $"Back" --menu $"Choose your timezone" 0 50 15 $tzOptions   2>&1 >&4)
        [ "$?" -ne 0 -o "$tz" == "" ]  && continue
                
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
    KEYSIZE=$($dlg --cancel-label $"Menu" \
                   --menu $"Select a size for the RSA keys:" 0 30  5  \
	                  1024 $"bit" \
	                  1152 $"bit" \
	                  1280 $"bit" \
	                  2>&1 >&4)
    #Selected back to the menu
    [ "$?" -ne 0 ] && return 1
    
    #Just a guard, shouldn't happen
    [ "$KEYSIZE" == "" ] && KEYSIZE="1280"
    
    echo "KEYSIZE: $KEYSIZE"   >>$LOGFILE 2>>$LOGFILE
    
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
        
        createUserTempDir  # TODO if this functiionality unused and can be deleted, do it
        
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
                
        # TODO rebuild localization from scratch. For now, I'll rewrite everything only in english
        #    export TEXTDOMAINDIR=/usr/share/locale
        #    export TEXTDOMAIN=wizard-setup.sh  # TODO ver si es factible invocar a los otros scripts con cadenas localizadas. Si no, separar las funcs y devolver valores para que las acdenas se impriman en este (y considerarlo tb por seguridad una vez funcione todo)
        
        #Relaunch self with the selected language
        exec  "$0" "$lan"
fi


echo "Selected language: $LANGUAGE"  >>$LOGFILE 2>>$LOGFILE

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
$PSETUP moveToRAM






#Main action loop
while true
do

    #Clean active slot, to avoid inconsistencies
    $PVOPS storops resetSlot #TODO maybe call here function that cleans all slots? decide once finished. (resetAllSlots)
    
    #Select startup action
    chooseMaintenanceAction
    
    
    
    
    
    ##### Ask for the configuration parameters #####
    if [ "$DOFORMAT" -eq 1 ]
    then 
        
        #On fresh install, show EULA
        if [ "$DORESTORE" -eq 0 ] ; then
            $dlg --extra-button --extra-label $"I do not agree" --no-cancel \
                 --ok-label $"I agree"  --textbox /usr/share/doc/License.$LANGUAGE 0 0
            #Does not accept EULA, halt
            [ $? -eq 3 ] && $PSETUP halt
        else
            #On restore, inform about the procedure
            $dlg --msgbox $"You chose to restore a backup. A fresh installation will be performed first, where you will be able to change basic configuration. Please, use a NEW SET of usb drives on it. You will be asked to insert the OLD SET at the end to perform the restoration." 0 0
        fi
        
        
        # Get all configuration parameters #TODO maybe all of this can be put into a function for clarity (maybe not all, but only the largest sections)
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
        
        
        #Generate persistence drive cipherkey
        $dlg   --infobox $"Generating shared key for the encrypted disk drive..." 0 0
        $PVOPS genNfragKey
        
        # TODO store some config vars now (memory and usb variables) check if the file for the future usb writing has beens et diring yhe key generation or we must do it.
        #Pasa las variables de configuración empleadas en este caso a una cadena separada por saltos de linea para volcarlo a un clauer
   
    
    setVar usb DRIVEMODE "$DRIVEMODE"
    
    case "$DRIVEMODE" in
	
	"local" )
        setVar usb DRIVELOCALPATH "$DRIVELOCALPATH"
	;;
	
    	"file" )
	setVar usb FILEPATH "$FILEPATH"
	setVar usb FILEFILESIZE "$FILEFILESIZE"
        setVar usb CRYPTFILENAME "$CRYPTFILENAME"
    	;;
	
    esac


	setVar usb SSHBAKSERVER "$SSHBAKSERVER"
	setVar usb SSHBAKPORT "$SSHBAKPORT"
	setVar usb SSHBAKUSER "$SSHBAKUSER"
	setVar usb SSHBAKPASSWD "$SSHBAKPASSWD"


    setVar usb SHARES "$SHARES"
    setVar usb THRESHOLD "$THRESHOLD"


    fi
    
    
    
    
    ######## Get parameters and key from usb drives ##########
    if [ "$DOBUILDKEY" -eq 1 ] ; then
        #We need to obtain a cipherkey and config parameters from a set of usb stores
        $dlg --msgbox $"We need to rebuild the shared cipher key.""\n"$"You will be asked to insert all available usb devices holding key fragments" 0 0
        
        while true
        do
            #Ask to insert a device and read config and key share
            readNextUSB
            ret=$?
            [ $ret -eq 1 ] && continue   #Read error: ask for another usb
            [ $ret -eq 2 ] && continue   #Password error: ask for another usb
            [ $ret -eq 3 ] && continue   #Read config/keyshare error: ask for another usb
            [ $ret -eq 4 ] && continue   #Config syntax error: ask for another usb
            
            #User cancel
            if [ $ret -eq 9 ] ; then
                $dlg --yes-label $"Insert another device" --no-label $"Back to the main menu" \
                     --yesno  $"Do you want to insert a new device or cancel the procedure?" 0 0  

                [ $? -eq 1 ] && continue 2 #Cancel, go back to the menu
                continue #Go on, ask for another usb
            fi
            
            #Successfully read and removed, ask if any remaining
            $dlg --yes-label $"Insert another device" --no-label $"No more left" \
                 --yesno  $"Successfully read. Are there any devices left?" 0 0
            
            [ $? -eq 1 ] && break #None left, go on
            continue #Any left, ask for another usb
        done
        
        #All devices read, set read config as the working config
        $PVOPS storops settleConfig  >>$LOGFILE 2>>$LOGFILE
        
        #Try to rebuild key (first a simple attempt and then an all combinations)
        $dlg --infobox $"Reconstructing ciphering key..." 0 0
        rebuildKey
        [ $? -ne 0 ] && continue #Failed, go back to the menu
        
        $dlg --msgbox $"Key successfully rebuilt." 0 0


        # TODO up to now, we have a key and config in roottmp in both cases. see if we need to read some of the usb vars to userspace (check needs of the userspace app and the calls to privops and psetup) and do it here
        
    fi





    ######## Setup system ######### # TODO some sections will be new only and some reload only



    
    # TODO setup hdd
    
    
    #TODO on new: store all HDD variables now? (store also ip config)
    
    setVar usb IPMODE $IPMODE
	setVar usb HOSTNM "$HOSTNM"
 setVar usb DOMNAME "$DOMNAME"
 
    if [ "$IPMODE" == "static"  ] #si es 'dhcp' no hacen falta
	then
	setVar usb IPADDR "$IPADDR"
	setVar usb MASK "$MASK"
	setVar usb GATEWAY "$GATEWAY"
	setVar usb DNS1 "$DNS1"
	setVar usb DNS2 "$DNS2"
    fi
 

    
    # TODO configure network if reloading (read network config from hdd)
    #
    # configureNetwork
    # if [ $? -ne 0 ] ; then
    #     $dlg --yes-label $"Review" --no-label $"Keep" \
    #          --yesno  $"Network connectivity error. Go on or review the parameters?" 0 0
    #     #Review them, loop again
    #     [ $? -eq 0 ] && continue
    # fi



    #Setup hosts file and hostname
    $PSETUP configureHostDomain "$IPADDR" "$HOSTNM" "$DOMNAME"
    
    #Make sure time is synced
    $dlg   --infobox $"Syncronizing server time..." 0 0
    $PSETUP forceTimeAdjust
    

    # TODO configure ssh backup key trust if reloading

    # #Set trust on the server
    # sshScanAndTrust "$SSHBAKSERVER"  "$SSHBAKPORT"
    # if [ $? -ne 0 ] ; then
    #     echo "SSH Keyscan error." >>$LOGFILE 2>>$LOGFILE
    #     return 1
		  # fi



    
    
    ######## Retrieve backup to restore #########

    ######## Share key and basic config on usbs #########

    #Setup network, persistence drive and other basics



    




    
    #TODO Once the system is set up (or maybe before config?), store variables, un usbs, disk, etc. (see all sources and keep them simple and coordinated)
    # TODO remember to store all config variables, both those in usb and in hard drive (the second group will be done, obviously, after setting up the drive) # TODO cambiar nomenclatura sobre las fuentes. hacver wrapper de getvar y setvar para userspace
        setVar usb IPADDR "$IPADDR" # TODO maybe store it to the hard drive, now that we don0t support remote drives 
	       setVar usb HOSTNM "$HOSTNM" #store both on dhcp and manual

        #Guardamos los params # TODO revisra todos los forms para saber qué params guardar. quiatr viejos y ojo a los nuevos.
        setConfigVars # OJO, las que se guatden en el hdd, pasar a más tarde
  

        # TODO write usbs if in install # TODO when writing the usbdevs, if no writable partitions found, offer to format a drive?


        # TODO write csr if in install
        

    
    
    # TODO Remember to set all variables from config that we need, here (from usb config after rebuild or set during installation) and, when set up, from crypto part config
    







    

        

        
    





    #Saltar a  la sección de config de red/cryptfs  # TODO refactor this function, inside or outside the loop?
    doSystemConfiguration "reset/new"   
    
    
    # TODO give or remove privileges to the admin user, make sure this var is erradicated: SETAPPADMINPRIVILEGES=0






    # TODO: now, clauers are written at the end, after everything is configured.
        #Avisamos antes de lo que va a ocurrir.
    $dlg --msgbox $"Ahora procederemos a repartir la nueva información del sistema en los dispositivos de la comisión de custodia.\n\nLos dispositivos que se empleen NO DEBEN CONTENER NINGUNA INFORMACIÓN, porque VAN A SER FORMATEADOS." 0 0
    writeClauers   
    


    #Forzamos un backup al acabar de instalar       #//// probar
    $PSETUP   forceBackup
    
    $dlg --msgbox $"System is running properly.""\n"$"The administrator has now privileged access to the voting web application. Don't forget to remove privileges before running an election. Otherwise he will have the means to disenfranchise targeted voters." 0 0
    
    break # TODO invoke here the maintenance script?
    
done #Main action loop



#Send test e-mails and do the final security adjustments to lock down
#all scripts and operations not needed anymore
$PSETUP init5

#Clean any remaining rebuilt keys. Any privileged action invoked from
#now will need a key reconstruction
$PVOPS storops resetAllSlots


#Go into the maintenance mode. Process context is overriden with a new
#one for security reasons
exec /bin/bash  /usr/local/bin/wizard-maintenance.sh  
  




# TODO implement a delayed rebuilt key anulation? this way, multiple privileged actions can be performed without bothering the keyholders. think about this calmly. maybe a file with the last action timestamp and a cron? but I think it's too risky...

# TODO any action not requiring a key rebuild, now will require admin's local pwd

# TODO (?) Arreglar al menos el menú de standby y las operaciones que se realizan antes y después de llamar a una op del bucle infinito. ha sacado dos mensajes impresos. supongo que estarán dentro del maintenance, pero revisarlo bien cuando esté mejor el fichero de maintenance poner reads
