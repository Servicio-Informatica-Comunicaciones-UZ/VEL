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
    
    DOBUILDKEY=0
    DOFORMAT=0
    DORESTORE=0
    
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
	               return 1
                ;;
            
	           "2" )
                #Double check option if user chose to format
                $dlg --yes-label $"Back" --no-label $"Format system" --yesno  $"You chose NEW system.\nThis will destroy any previous installation of the voting system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOBUILDKEY=0
	               DOFORMAT=1
	               return 2
                ;;
            
            "3" )
                #Double check option if user chose to recover
                $dlg --yes-label $"Back" --no-label $"Recover backup" --yesno  $"You chose to RECOVER a backup.\nThis will destroy any changes on a previously existing system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOBUILDKEY=1
	               DOFORMAT=1
	               DORESTORE=1
	               return 3
                ;;
	           
	           "4" )
	               $dlg --yes-label $"Yes" --no-label $"No"  --yesno  $"WARNING:\n\nYou chose to open a terminal. This gives free action powers to the administrator. Make sure he does not operate it without proper technical supervision. Do you wish to continue?" 0 0
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



#Let user select his timezone
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
        $dlg --msgbox $"The cipher key needs to be rebuilt.""\n"$"You will be asked to insert all available usb devices holding key fragments" 0 0
        
        
        while true
        do
            #Detect device insertion
            insertUSB $"Insert USB key storage device" $"Cancel"
            [ $? -eq 1 ] && continue 2 #Cancelled. Go back to the menu
            if [ $? -eq 2 ] ; then
                #No readable partitions. Ask for another one
                $dlg --msgbox $"Device contained no readable partitions. Please, insert another one." 0 0
                continue 
            fi
            
            #Mount the device (will do on /media/usbdrive)
            $PVOPS mountUSB mount $USBDEV
            
            #Ask for device password
            getPassword auth $"Please, insert the password for the connected USB device" 0
            if [ $? -ne 0 ] ; then
                $dlg --msgbox $"Password insertion cancelled. Please, insert another one." 0 0
                continue
            fi
	           
            #Access the store on the mounted path and check password
            #(store name is a constant expected by the store handler)
            $PVOPS storops checkPwd /media/usbdrive/ "$pwd" 2>>$LOGFILE  #0 ok  1 bad pwd
            ret=$?
  

            #Read config and 
            
            
        done







    fi


    break # TODO invoke here the maintenance script?
    
done #Main action loop


  
  


  
  $dlg --infobox $"Leyendo configuración del sistema..."  0 0
  sleep 1
  
  
  #Se puede acceder al Clauer. Leemos la configuración.  
  ESVYCFG=''
 
  
  clauerFetch $DEV c
  #Si falla, pedimos otro clauer
  if [ $? -ne 0 ] 
      then
      confirmSystemFormat $"No se han podido leer los datos de configuración de este Clauer." 
      #Si lo confirma, salta a la sección de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi
  

 
  #Verificamos que la última config leída tiene una estructura aceptable.
  $PVOPS storops parseConfig  >>$LOGFILE 2>>$LOGFILE
  if [ $? -ne 0 ]
      then
      #si la config no era adecuada, proponer format
      confirmSystemFormat $"La información de configuración leida estaba corrupta o manipulada." 
      #Si lo confirma, salta a la sección de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi












###### Sistema ya creado #####
	
	
# Es clauer y sí hay configuración previa. Se piden más clauers para iniciar el sistema.
if [ "$DOFORMAT" -eq 0 ] 
    then 
    
    #Si el sistema se está reiniciando, por defecto invalida los privilegios de admin
    SETAPPADMINPRIVILEGES=0 # TODO later, call setadmin... remove

    #Leemos la pieza de la clave del primer clauer (del que acabamos de sacar la config)
    clauerFetch $DEV k 
    
    detectUsbExtraction $DEV $"Clauer leido con éxito. Retírelo y pulse INTRO." $"No lo ha retirado. Hágalo y pulse INTRO."
    #Insertar un segundo dispositivo (jamás se podrá cargar el sistema con uno solo)
    
    
    
    #Preguntar si quedan más dispositivos (a priori no sabemos el número de clauers que habrá presentes, así que simplificamos y dejamos que ellos decidan cuántos quedan). Una vez leídos todos, ya veremos si hay bastantes o no.
    $dlg   --yes-label $"Sí" --no-label $"No" --yesno  $"¿Quedan más Clauers por leer?" 0 0  
    ret=$?
    
    #mientras queden dispositivos
    while [ $ret -ne 1 ]
      do
      
      readNextClauer 0 b
      status=$?
      
      
      if [ "$status" -eq 9 ]
	  then
	  $dlg --yes-label $"Reanudar" --no-label $"Finalizar"  --yesno  $"Ha cancelado la inserción de un Clauer.\n¿Desea finalizar la inserción de dispositivos?" 0 0  
	  
	  #Si desea finalizar, salimos del bucle
	  [ $? -eq 1 ] && break;
	  
      fi

      #Error
      if [ "$status" -ne 0  ]
	  then
	  $dlg --msgbox $"Error de lectura. Pruebe con otro dispositivo" 0 0
	  continue
      fi

      #Si todo es correcto
      if [ "$status" -eq 0  ] 
	  then
	  
	  #Compara la última config leída con la aceptada actualmente (y si hay diferencias, pregunta cuál usar)
	  $PVOPS storops compareConfigs

      fi	  
      
      #Preguntar si quedan más dispositivos
      $dlg   --yes-label $"Sí" --no-label $"No" --yesno  $"¿Quedan más Clauers por leer?" 0 0  
      ret=$?
      
    done
    
    #echo "Todos leidos"
    
    $dlg   --infobox $"Examinando los datos de configuración..." 0 0

    #Parsear la config y almacenarla
    $PVOPS storops parseConfig  >>$LOGFILE 2>>$LOGFILE

    if [ $? -ne 0 ]
	then
	systemPanic  $"Los datos de configuración están corruptos o manipulados."
    fi
    
    #Una vez están todos leídos, la config elegida como válida (si había incongruencias)
    #se almacena para su uso oficial de ahora en adelante (puede cambiarse con comandos)
    $PVOPS storops settleConfig  >>$LOGFILE 2>>$LOGFILE
    
  
    $dlg   --infobox $"Reconstruyendo la llave de cifrado..." 0 0

    $PVOPS storops rebuildKey #//// probar
    stat=$? 

    #Si falla la primera reconstrucción, probamos todas
    if [ $stat -ne 0 ] 
	then

	$dlg --msgbox $"Se ha producido un error durante la reconstrucción de la llave por la presencia de fragmentos defectuosos. El sistema intentará recuperarse." 0 0 

        retrieveKeywithAllCombs
	ret=$?

	#Si no se logra con ninguna combinación, pánico y adiós.
         if [ "$ret" -ne 0 ] 
	    then
	     systemPanic $"No se ha podido reconstruir la llave de la zona cifrada."
	 fi
	 
    fi

    $dlg --msgbox $"Se ha logrado reconstruir la llave. Se prosigue con la carga del sistema." 0 0 

    #Saltar a  la sección de config de red/cryptfs
    doSystemConfiguration "reset"   


        







###### Sistema nuevo #####
    
#Se formatea el sistema 
else 
    #echo "Se formatea" 
    
    #Cuando el sistema se esté instalando, y hasta que se instale el cert SSL correcto, el admin tendrá privilegios
    SETAPPADMINPRIVILEGES=1 # TODO later, call setadmin... grant
    
    
    #Pedimos que acepte la licencia
    $dlg --extra-button --extra-label $"No acepto la licencia" --no-cancel --ok-label $"Acepto la licencia"  --textbox /usr/share/doc/License.$LANGUAGE 0 0
    #No acepta la licencia (el extra-button retorna con cod. 3)
    [ "$?" -eq 3 ] && $PSETUP halt;  #////probar



    if [ "$DORESTORE" -eq 1 ] ; then
	$dlg --msgbox $"Ha elegido restaurar una copia de seguridad del sistema. Primero se instalará un sistema totalmente limpio. Podrá alterar los parámetros básicos. Emplee un conjunto de Clauers NUEVOS. Al final se le solicitarán los clauers antiguos para proceder a restaurar los datos." 0 0
    fi
    
    
    #BUCLE PRINCIPAL

    #Inicialización de los campos de los formularios.
    ipmodeArr=(null on off)  
    declare -a ipconfArr # es un array donde almacenaremos temporalmente el contenido del form de conf ip    

    declare -a crydrivemodeArr
    declare -a localcryconfArr
    declare -a iscsiconfArr
    declare -a sambaconfArr
    declare -a nfsconfArr
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
    $PSETUP   3
    
    
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


    #Avisar al admin de que necesita un Clauer, y permitirle formatear uno en blanco.
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
	  
          #Acceder  # TODO esto es un mount, checkdev y getpwd
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




#Realizamos los ajustes de seguridad comunes
$PSETUP 5

#Limpiamos los slots antes de pasar a mantenimiento (para anular las claves reconstruidas que pueda haber)
$PVOPS storops resetAllSlots  #//// probar que ya limpie y pueda ejecutar al menos una op de mant correctamente.


#Una vez acabado el proceso de instalación/reinicio, lanzamos el proceso de mantenimiento. 
# El uso del exec resulta de gran importancia dado que al sustituír el contexto del proceso 
# por el de este otro, destruye cualquier variable sensible que pudiese haber quedado en memoria.
exec /bin/bash  /usr/local/bin/wizard-maintenance.sh





#*-*-Arreglar al menos el menú de standby y las operaciones que se realizan antes y después de llamar a una op del bucle infinito. ha sacado dos mensajes impresos. supongo que estarán dentro del maintenance, pero revisarlo bien cuando esté mejor el fichero de maintenance poner reads.







#//// Ver las PVOPS en  configureServers (y el resto), porque habrá alguna que podrá ser pasada a PSETUP







#Para verificar la sintaxis:   for i in $(ls ./data/config-tools/*.sh);   do    echo "-->Verificando script $i";   bash -n $i;   if [ $? -ne 0 ];       then       errorsFound=1;   fi; done;
