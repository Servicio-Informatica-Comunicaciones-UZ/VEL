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

   
}




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



#Lets user select his timezone
selectTimezone () {

    local defaultItem="Europe"
    exec 4>&1
    while true
    do
        local areaOptions=$(ls -F  /usr/share/zoneinfo/right/ | grep / | sed -re "s|/| - |g")
        local tzArea=$($dlg --no-cancel --default-item $defaultItem --menu $"Choose your timezone" 0 50 15 $areaOptions   2>&1 >&4)        
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




    
    #We need to obtain a cipherkey and config parameters from a set of usb stores # TODO enclose as much as possible in functions
    if [ "$DOBUILDKEY" -eq 1 ] ; then
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
    fi
    
    
    # TODO Remember to set all variables from config that we need, here from usb config and, when set up, from crypto part config
    
    
    
    if [ "$DOFORMAT" -eq 1 ]   # TODO when finished,  put this before the rebuild key section
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
        

        # Get all configuration parameters # TODO (move here all user input and make it selectable through a menu)

        selectTimezone #Will set the global var TIMEZONE        
        


        #Execute configuration phase # TODO (does anything need to be done before getting any data? like network or partition?)
        
        
        

        # TODO remember to store all config variables, both those in usb and in hard drive
        
    fi
    





    #Saltar a  la sección de config de red/cryptfs  # TODO refactor this function, inside or outside the loop?
    doSystemConfiguration "reset/new"   
    
    
    # TODO give or remove privileges to the admin user, make sure this var is erradicated: SETAPPADMINPRIVILEGES=0


    
    
    break # TODO invoke here the maintenance script?
    
done #Main action loop



#Test e-mail notifications with admin, neuter setup scripts
$PSETUP init5

#Clean slots before going into maintenance mode (to void any rebuilt keys that may remain)
$PVOPS storops resetAllSlots     # TODO implement a delayed rebuilt key anulation? this way, multiple privileged actions can be performed without bothering the keyholders. think about this calmly


#Go into the maintenance mode. Process context is overriden with a new
#one for security reasons
exec /bin/bash  /usr/local/bin/wizard-maintenance.sh  
  


















###### Sistema nuevo #####
    
#Se formatea el sistema 
else 
    

    
    #BUCLE PRINCIPAL

    #Inicialización de los campos de los formularios.
    ipmodeArr=(null on off)  
    declare -a ipconfArr # es un array donde almacenaremos temporalmente el contenido del form de conf ip    

    declare -a crydrivemodeArr
    declare -a localcryconfArr
    declare -a fileconfArr
    crydrivemodeArr=(null on off off off off)
    
    MAILRELAY=""
    
    declare -a secsharingPars	


    proceed=0
    while [ "$proceed" -eq 0 ]
      do
      

      networkParams

      #La guardamos tb ahora porque hace falta para esta fase 2
      $PVOPS vars setVar c IPADDR "$IPADDR"

      #Configuramos el acceso a internet 
      configureNetwork 'noPanic'
      ret=$?	
      [ "$ret" -eq 1 ] && continue #Si no hay conectividad, vuelve a pedir los datos de config


      selectCryptoDrivemode

      
      selectMailerParams


      selectSharingParams
      

      $dlg --no-label $"Continuar"  --yes-label $"Modificar" --yesno  $"Ha acabado de definir los parámetros del servidor de voto. ¿Desea modificar los datos introducidos?" 0 0 
      #No (1) desea alterar nada
      [ "$?" -eq "1" ] && proceed=1
      
    done


    #Guardamos los params #////probar
    setConfigVars
  
    #Continuamos con la config inicial del sistema 


    #Nos aseguramos de que sincronice la hora 
    $dlg   --infobox $"Sincronizando hora del servidor..." 0 0

    
    #Ejecutamos elementos de configuración
    $PSETUP init3
    
    
    genNfragKey
    
    #Ahora que tenemos shares y config, pedimos los Clauers de los miembros de la comisión para guardar los nuevos datos. 
    
    #Avisamos antes de lo que va a ocurrir.
    $dlg --msgbox $"Ahora procederemos a repartir la nueva información del sistema en los dispositivos de la comisión de custodia.\n\nLos dispositivos que se empleen NO DEBEN CONTENER NINGUNA INFORMACIÓN, porque VAN A SER FORMATEADOS." 0 0


    writeClauers   
    
    #Informar de que se han escrito todos los clauers pero aún no se ha configurado el sistema. 
    $dlg --msgbox $"Se ha terminado de repartir las nuevas llave y configuración. Vamos a proceder a configurar el sistema" 0 0

    #Como en este caso no se elige modo de mantenimiento, indicamos el que corresponde
    doSystemConfiguration "new"


    #Forzamos un backup al acabar de instalar       #//// probar
    $PSETUP   forceBackup


    #Avisar al admin de que necesita un Clauer, y permitirle formatear uno en blanco. # TODO esto ya no. Darle un punto adicional por privileged
    $dlg --yes-label $"Omitir este paso" --no-label $"Formatear dispositivo"  --yesno  $"El administrador del sistema de voto necesita poseer un dispositivo Clauer propio con fines identificativos frente a la aplicación, aunque no contenga certificados. Si no posee ya uno, tiene la posibilidad de insertar ahora un dispositivo USB y formatearlo como Clauer." 0 0
    formatClauer=$?

    #Desea formatear un disp.
    if [ $formatClauer -eq 1 ]
	then
	
	success=0
	while [ "$success" -eq  "0" ]
	  do
	  
 # TODO refactor this. now insertusb can always be cancelled and return 1, no infinite loop. Below there already is a special case, extenbd also for this
	  insertUSB $"Inserte el dispositivo USB a escribir y pulse INTRO." "none"
	 #TODO Verificar comportamiento de esto. si ret 2 es part a format y si es 0, es part montable, luego puede escribir el store directamente
      
          #Pedir pasword nuevo
	  
          #Acceder  # TODO esto es un mount, checkdev y getpwd (y luego un format usb + format store)
	  storeConnect $DEV "newpwd" $"Introduzca una contraseña nueva:"
	  ret=$?
	  
          #Si el acceso se cancela, pedimos que se inserte otro
	  if [ $ret -eq 1 ] 
	      then
	      $dlg --msgbox $"Ha abortado el formateo del Clauer. Inserte otro para continuar" 0 0 
	      continue
	  fi
	  
          #Formatear y particionar el dev

	  $dlg   --infobox $"Preparando Clauer..." 0 0
	  formatearClauer "$DEV" "$PASSWD"	# TODO ahora la op de format sólo formatea el fichero. Si he de permitir formatear el devie, implementar eso aparte. quitar lo de las dos particiones, ahora sólo una de datos. Para asegurarse, que ponga a cero toda la unidad o que haga un wipe del fichero de store  
	  if [ $? -ne 0 ] 
	      then
	      $dlg --msgbox $"Error durante el formateo." 0 0
	      continue
	  fi
	  
	  sync

	  success=1
	  
	done
	
	detectUsbExtraction $DEV $"Clauer escrito con éxito. Retírelo y pulse INTRO." $"No lo ha retirado. Hágalo y pulse INTRO."
	
    fi
    

    $dlg --msgbox $"El sistema se ha iniciado con privilegios para el administrador. Estos se invalidarán en cuanto realice alguna operación de mantenimiento (tal como instalar el certificado SSL del servidor)." 0 0
  
    
fi #if se formatea el sistema









#*-*-Arreglar al menos el menú de standby y las operaciones que se realizan antes y después de llamar a una op del bucle infinito. ha sacado dos mensajes impresos. supongo que estarán dentro del maintenance, pero revisarlo bien cuando esté mejor el fichero de maintenance poner reads.







#//// Ver las PVOPS en  configureServers (y el resto), porque habrá alguna que podrá ser pasada a PSETUP







#Para verificar la sintaxis:   for i in $(ls ./data/config-tools/*.sh);   do    echo "-->Verificando script $i";   bash -n $i;   if [ $? -ne 0 ];       then       errorsFound=1;   fi; done;
