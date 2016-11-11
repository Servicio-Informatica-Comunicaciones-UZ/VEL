#!/bin/bash
# Methods and global variables only common to all non-privileged scripts go here

###############
#  Constants  #
###############

#Actual version number of this voting system
VERSION=$(cat /etc/vtUJIversion)

#Block id used in the secure store for the key fragment
KEYBID='eSurvey_eLection_keyshare'

#Block id used in the secure store for the configuration
CONFBID='eSurvey_eLection_config'




#############
#  Methods  #
#############



#Wrapper: move logs to privileged location
# $1 ->   'new': new install (just moves logs)
#       'reset': substitutes logs for the previous ones and saves apart current ones
relocateLogs () {
    $PSETUP  relocateLogs "$1"
}



#Create unprivileged user tmp directory
createUserTempDir (){
    #If it doesn't exist, create
    [ -e "$TMPDIR" ] || mkdir "$TMPDIR"
    #if it's not a dir, delete and create
    [ -d "$TMPDIR" ] || (rm "$TMPDIR" && mkdir "$TMPDIR") 
    #If it exists, empty it
    [ -e "$TMPDIR" ] && rm -rf "$TMPDIR"/*
}    




#Configure access to ciphered data
#1 -> 'new': setup new ciphered device
#     'reset': load existing ciphered device
configureCryptoPartition () {
    
    if [ "$1" == 'new' ]
	   then
	       $dlg --infobox $"Creating ciphered data device..." 0 0
    else
	       $dlg --infobox $"Accessing ciphered data device..." 0 0
    fi
    sleep 1
    
    #Setup the partition
    $PVOPS configureCryptoPartition "$1"
    local ret=$?
    [ "$ret" -eq 2 ] && systemPanic $"Error mounting base drive."
    [ "$ret" -eq 3 ] && systemPanic $"Critical error: no empty loopback device found"
    [ "$ret" -ne 4 ] && systemPanic $"Unknown data access mode. Configuration is corrupted or tampered."
    [ "$ret" -ne 5 ] && systemPanic $"Couldn't encrypt the storage area."
    [ "$ret" -ne 6 ] && systemPanic $"Couldn't access storage area." 
    [ "$ret" -ne 7 ] && systemPanic $"Couldn't format the filesystem."
    [ "$ret" -ne 8 ] && systemPanic $"Couldn't mount the filesystem."
    [ "$ret" -ne 0 ] && systemPanic $"Error configuring encrypted drive."
    
}






#Get a password from user
#1 -> mode:  (auth) will ask once, (new) will ask twice and check for equality
#2 -> message to be shown
#3 -> cancel button? 0 no, 1 yes
# Return 0 if ok, 1 if cancelled
# $PASSWD : inserted password (due to dialog handling the stdout)
getPassword () {
    
    exec 4>&1
    
    local nocancelbutton=" --no-cancel "    
    [ "$3" == "0" ] && nocancelbutton=""
    
    while true; do
        
	       local pass=$($dlg $nocancelbutton --max-input 32 --passwordbox "$2" 10 40 2>&1 >&4)
	       [ "$?" -ne 0 ] && return 1 
	       
	       [ "$pass" == "" ] && continue
        
        #If this is a new password dialog
        if [ $1 == 'new' ] 
	       then
            #Check password strength
            local errmsg=$(checkPassword "$pass")
            if [ "$?" -ne 0 ] ; then
                $dlg --msgbox "$errmsg" 0 0
                continue
            fi
            
	           local pass2=$($dlg $nocancelbutton  --max-input 32 --passwordbox $"Vuelva a escribir su contraseña." 10 40 2>&1 >&4)
	           [ $? -ne 0 ] && return 1 

            #If not matching, ask again
            if [ "$pass" != "$pass2" ] ; then
                $dlg --msgbox $"Passwords don't match." 0 0
	               continue
            fi
	    	  fi
        
        break
    done
    
    PASSWD=$pass
    return 0
}







#Check validity and strength of password
#1 -> password to check
#Returns 0 if OK, 1 if error
#Stdout: Error message to be displayed
checkPassword () {
    local pass=$1
    
    if [ ${#pass} -lt 8 ] ; then
		      echo $"Password too short (min. 8 chars)."
	       return 1
	   fi
    
	   if [ ${#pass} -gt 32 ] ; then
    		  echo $"Password too long (max. 32 chars)."
		      return 1
	   fi
    
	   if $(parseInput pwd "$pass") ; then
		      :
	   else    
		      echo $"Password not valid. Use: ""$ALLOWEDCHARSET"
		      return 1
	   fi
    
    return 0
}







#Detects insertion of a device and reads the config/keyshare/both to the current slot 
#1 -> 'c': read the config olny
#     'k': read the keyshare only
#     'b' or '': read both
#Returns  0: OK
#         1: read error
#         2: password error
#         9: cancelled
readNextUSB () {
    
    #Detect device insertion
    insertUSB $"Insert USB key storage device" $"Cancel"
    [ $? -eq 1 ] && return 9
    if [ $? -eq 2 ] ; then
        #No readable partitions.
        $dlg --msgbox $"Device contained no readable partitions." 0 0
        return 1 
    fi
    
    #Mount the device (will do on /media/usbdrive)
    $PVOPS mountUSB mount $USBDEV

    #Ask for device password
    while true ; do
        #Returns passowrd in $PASSWD
        getPassword auth $"Please, insert the password for the connected USB device" 0
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Password insertion cancelled." 0 0
            $PVOPS mountUSB umount
            return 2
        fi
	       
        #Access the store on the mounted path and check password
        #(store name is a constant expected by the store handler)
        $PVOPS storops checkPwd /media/usbdrive/ "$PASSWD" 2>>$LOGFILE
        if [ $? -ne 0 ] ; then
            #Keep asking until cancellation or success
            $dlg --msgbox $"Password not correct." 0 0
            continue
        fi
        break
    done
    
    #Read config
    if [ "$1" != "k" ] ; then
	       $PVOPS storops readConfigShare /media/usbdrive/ "$PASSWD" >>$LOGFILE 2>>$LOGFILE
        ret=$?
	       if [ $ret -ne 0 ] ; then
	           $dlg --msgbox $"Error ($ret) while reading configuration from USB." 0 0
            $PVOPS mountUSB umount
	           return 3
	       fi

        #Check config syntax
        $PVOPS storops parseConfig  >>$LOGFILE 2>>$LOGFILE
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Configuration file tampered or corrupted." 0 0
            $PVOPS mountUSB umount
            return 4
        fi
        
        #Compare last read config with the one currently considered as
        #valid (if no tampering occurred, all should match perfectly)
        #If different, user will be prompted
	       $PVOPS storops compareConfigs        
    fi
    
    #Read keyshare
    if [ "$1" != "c" ] ; then
       	$PVOPS storops readKeyShare /media/usbdrive/ "$PASSWD" >>$LOGFILE 2>>$LOGFILE
	       ret=$?
       	if [ $ret -ne 0 ] ; then
	           $dlg --msgbox $"Error ($ret) while reading keyshare from USB." 0 0
            $PVOPS mountUSB umount
	           return 3
	       fi
	   fi
    
    #Umount the device once done reading
    $PVOPS mountUSB umount
    
    #Detect extraction before returning control to main program
    detectUsbExtraction $USBDEV $"USB device successfully read. Remove it and press RETURN." \
                        $"Didn't remove it. Please, do it and press RETURN."
    
    return 0
}







#Grant admin user a privileged admin status on the web app
#1-> 'grant' or 'remove'
grantAdminPrivileges () {
    echo "Setting web app privileged admin status to: $1"  >>$LOGFILE 2>>$LOGFILE
	   $PVOPS  grantAdminPrivileges "$1"	
}



#Will try to rebuild the key using the shares on the active slot
rebuildKey () {
    
    $PVOPS storops rebuildKey
    
    #If rebuild failed, try a lengthier approach
    if [ $? -ne 0 ]
    then
        $dlg --msgbox $"Key reconstruction failed. System will try to recover. This might take a while." 0 0 
        
        $PVOPS storops rebuildKeyAllCombs 2>>$LOGFILE  #0 ok  1 bad pwd
	       local ret=$?
        local errmsg=''
        #If rebuild failed again, nothing can be done, back to the menu
	       [ "$ret" -eq 10 ] && errmsg=$"Missing configuration parameters."
        [ "$ret" -eq 11 ] && errmsg=$"Not enough shares available."
        [ "$ret" -eq 1  ] && errmsg=$"Some shares may be corrupted. Not enough left."
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Key couldn't be reconstructed. $errmsg" 0 0 
            return 1
	       fi
	   fi
    
    return 0
}







        
#### Network connection parameters ####
# Will read the user input parameters and set them to their
# destination global variables. Notice that since an empty field is
# ignored and all values are shifted, we will only update the
# variables if all the values are set.
#Set variables:
#  IPMODE
#  IPADDR
#  MASK
#  GATEWAY
#  DNS1
#  DNS2
#  HOSTNM
#  DOMNAME
###TODO depués, los valores establecidos aquí se pasarán al  privil. op adecuado donde se parsearán de nuevo y se establecerán si corresponde. Hacer op para leer y preestablecer los valores de estas variables y usarlas como valores default (para los pwd, obviamente, no)
networkParams () {
    
    selectIPMode () {
                
        #Default value
        isDHCP=on
        isUserSet=off
        
       	exec 4>&1 
	       local choice=""
	       while true
	       do
            [ "$IPMODE" == "dhcp" ]   && isDHCP=on && isUserSet=off
            [ "$IPMODE" == "static" ] && isDHCP=off && isUserSet=on
            
	           choice=$($dlg --cancel-label $"Menu"   --radiolist  $"Network connection mode" 0 0 2  \
	                         1 $"Automatic (DHCP)" "$isDHCP"  \
	                         2 $"User set" "$isUserSet"  \
	                         2>&1 >&4 )
	           #If cancelled, exit
            [ $? -ne 0 ] && return 1
            
            #If none selected, ask again
            [ "$choice" == "" ] && continue
            
            #If static config is chosen
	           if [ "$choice" -eq 2 ] ; then
	               IPMODE="static"
                
                #Show the parameter form
                selectIPParams
                
                #If back, show the mode selector again
                [ "$?" -eq '2' ] && continue
            else
                #DHCP mode selected
                IPMODE="dhcp"
                while true ; do
                    local errmsg=""
                    
	                   local hostn=$($dlg --cancel-label $"Back"  --inputbox  \
		                                     $"Hostname:" 0 0 "$HOSTNM"  2>&1 >&4)
                    #If back, show the mode selector again
                    [ "$?" -ne 0 ] && continue 2
                    
	                   parseInput hostname "$hostn"
	                   [ $? -ne 0 ] && errmsg=""$"Hostname not valid."
                    
	                   local domn=$($dlg --cancel-label $"Back"  --inputbox  \
		                                    $"Domain name:" 0 0 "$DOMNAME"  2>&1 >&4)
                    #If back, continue to go to the previous prompt
                    [ "$?" -ne 0 ] && continue
                    
	                   parseInput dn "$domn"
                    [ $? -ne 0 ] && errmsg="$errmsg\n"$"Domain not valid."
                    
                    #If errors, go to the first prompt
                    if [ "$errmsg" != "" ] ; then
		                      $dlg --msgbox "$errmsg" 0 0
		                      continue
	                   fi
                    #If all set ad correct, set the globals
                    HOSTNM="$hostn"
                    DOMNAME="$domn"
                    break
                done
            fi
            break
	  	    done
        return 0
    }
    
    selectIPParams () {
        
        #Preset values are on the global variables. Will only be
        #updated if value is correct; and if some field is left empty,
        #none will be update (due to dialog limitations)
        local choice=""
        exec 4>&1
        local BAKIFS=$IFS
        IFS=$(echo -en "\n\b") #We need this to avoid interpreting a space as an entry 
	       while true
	       do
	           local formlen=7
	           choice=$($dlg  --cancel-label $"Back"  --mixedform  $"Network connection parameters" 0 0 20  \
	                          $"Field"            1  1 $"Value"   1  30  17 15   2  \
	                          $"IP Address"       3  1 "$IPADDR"  3  30  17 15   0  \
	                          $"Net Mask"         5  1 "$MASK"    5  30  17 15   0  \
	                          $"Gateway Address"  7  1 "$GATEWAY" 7  30  17 15   0  \
	                          $"Primary DNS"      10 1 "$DNS1"    10 30  17 15   0  \
	                          $"Secondary DNS"    12 1 "$DNS2"    12 30  17 15   0  \
	                          $"Hostname"         15 1 "$HOSTNM"  15 30  17 256  0  \
                           $"Domain"           17 1 "$DOMNAME" 17 30  17 256  0  \
	                          2>&1 >&4 )
            
	           #If cancelled, exit
            [ $? -ne 0 ] && return 2

            #Check that all fields have been filled in (choice must
            #have the expected number of items), otherwise, loop
            local clist=($choice)
            if [ ${#clist[@]} -le "$formlen" ] ; then
            	   $dlg --msgbox $"All fields are mandatory" 0 0
	               continue 
	           fi
            
            #Parse each entry before setting it
     	      local i=0
	           local loopAgain=0
            local errors=""
	           for item in $choice
	           do
                IFS=$BAKIFS #Restore temporarily
                
	               case "$i" in
				                "1" ) #IP
		                      parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"IP address not valid"
  		                    else IPADDR="$item" ; fi
		                      ;;
		                  
		                  "2" ) #MASK
                        parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Net mask not valid"
		                      else MASK="$item" ; fi
		                      ;;
	                   
		                  "3" ) #Gateway
		                      parseInput ipaddr "$item"
				                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Gateway address not valid"
                        else GATEWAY="$item" ; fi
		                      ;;
	                   
		                  "4" ) #Primary DNS
		                      parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Primary DNS address address not valid"
		                      else DNS1="$item" ; fi
				                    ;;
		                  
		                  "5" ) #Secondary DNS
 	                      parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Secondary DNS address address not valid"
		                      else DNS2="$item" ; fi
				                    ;;
	                   
		                  "6" ) # Hostname
		                      parseInput hostname "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Host name not valid"
		                      else HOSTNM="$item" ; fi
		                      ;;
		                  "7" ) # Domain for the host
		                      parseInput dn "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Domain name not valid"
		                      else DOMNAME="$item" ; fi
		                      ;;
	               esac
                
                BAKIFS=$IFS
                IFS=$(echo -en "\n\b")
                
                #Next item, until the number of expected items
	               i=$((i+1))
	           done
            
            IFS=$BAKIFS
            
            #Show errors in the form, then loop
	           if [ "$loopAgain" -eq 1 ] ; then
                $dlg --msgbox "$errors" 0 0
                continue
	           fi
            break
        done
	   } #SelectIPParams
    
    
    selectIPMode
    local ret=$?
    
    #<DEBUG>
	   echo "IPMODE: "$IPMODE  >>$LOGFILE 2>>$LOGFILE  # TODO guess where these vars are passed to the privileged part and stored on the config (either drive or usbdevs)
	   echo "IP:   "$IPADDR >>$LOGFILE 2>>$LOGFILE
	   echo "MASK: "$MASK >>$LOGFILE 2>>$LOGFILE
	   echo "GATE: "$GATEWAY >>$LOGFILE 2>>$LOGFILE
	   echo "DNS1: "$DNS1 >>$LOGFILE 2>>$LOGFILE
	   echo "DNS2: "$DNS2 >>$LOGFILE 2>>$LOGFILE
	   echo "HOSTNM: "$HOSTNM >>$LOGFILE 2>>$LOGFILE
 	  echo "DOMNAME: "$DOMNAME >>$LOGFILE 2>>$LOGFILE
   #</DEBUG>
    
    return $ret
} #NetworkParams



#Configure and check network connectivity
#Will access the following global variables:
# IPMODE
# IPADDR
# MASK
# GATEWAY
# DNS1
# DNS2
configureNetwork () {
    echo "Configuring network: $PSETUP configureNetwork $IPMODE $IPADDR $MASK $GATEWAY $DNS1 $DNS2" >>$LOGFILE 2>>$LOGFILE
    $dlg --infobox $"Configuring network connection..." 0 0
    
    #On reset, paremetrs will be empty, but will be read from the config fiile
    $PSETUP configureNetwork "$IPMODE" "$IPADDR" "$MASK" "$GATEWAY" "$DNS1" "$DNS2"
    local ret="$?"
    
    if [ "$ret" == "11"  ]; then
	       echo "Error: no accessible ethernet interfaces found."  >>$LOGFILE 2>>$LOGFILE
	       return 1
    elif [ "$ret" == "12"  ]; then
	       echo "Error: No destination reach from any interface." >>$LOGFILE 2>>$LOGFILE
        return 1
    elif [ "$ret" == "13"  ]; then
	       echo "Error: DHCP client error." >>$LOGFILE 2>>$LOGFILE
        return 1
    elif [ "$ret" == "14"  ]; then
	       echo "Error: Gateway connectivity error." >>$LOGFILE 2>>$LOGFILE
        return 1
    fi
    
    #Check Internet connectivity
    $dlg --infobox $"Checking Internet connectivity..." 0 0
	   ping -w 5 -q 8.8.8.8  >>$LOGFILE 2>>$LOGFILE 
	   if [ $? -eq 0 ] ; then
        return 2
    fi
    return 0
}





























#SEGUIR

#Sets a config variable on disk file. these vars override those read from Clauer
# $1 -> variable
# $2 -> value
setVarOnDisc () {  #//// convertir para que llame a la func de pvops


    echo "****setting var on disc: '$1'='$2'" >>$LOGFILE 2>>$LOGFILE #/////Borrar

    touch $VARFILE

    #Verificamos si la variable está definida en el fichero
    local isvardefined=$(cat $VARFILE | grep -Ee "^$1")

    #echo "isvardef: $isvardefined"

    #Si no lo está, append
    if [ "$isvardefined" == "" ] ; then
	echo "$1=\"$2\"" >> $VARFILE
    else
    #Si lo está, sustitución.
	sed -i -re "s/^$1=.*$/$1=\"$2\"/g" $VARFILE
    fi
    
}



		
# $1 -> file to read from
# $2 -> var name (to be read)
# $3 -> (optional) name of the destination variable
setVarFromFile () {

    
    [ "$1" == "" -o   "$2" == "" ] && return 1
    
    [ -f "$1" ] || return 1
    
    
    local destvar=$2
    [ "$3" != "" ] && destvar=$3

    
    export $destvar=$(cat $1 | grep -e "$2" | sed -re "s/$2=\"(.+)\"\s*$/\1/g")


    echo "****getting var from file '$1': '$2' on var '$3' = "$(cat $1 | grep -e "$2" | sed -re "s/$2=\"(.+)\"\s*$/\1/g") >>$LOGFILE 2>>$LOGFILE  #////QUITAR

    return 0 
}




#Deletes a config variable on disk file. (Mainly to fall back to the value set on Clauer)
# $1 -> variable
delVarOnDisc () {
    
    touch $VARFILE
    
    #Si la variable existe, la borra
    local isvardefined=$(cat $VARFILE | grep -Ee "^$1")
    if [ "$isvardefined" != "" ] ; then
	sed -i -re "s/^$1=.*$//g" $VARFILE
    fi

    #Borramos las líneas vacias
    sed -i -re '/^\s*$/d' $VARFILE
}



stopServers () {
    $PVOPS  stopServers
}












#Comprueba todas las shares existentes en el slot activo
testForDeadShares () {
    
    $PVOPS storops testForDeadShares
    local ret="$?"

    [ "$ret" -eq 2 ] && systemPanic $"Error interno. Faltan datos de configuración para realizar la resconstrucción."
      
    [ "$ret" -eq 3 ] && systemPanic $"No se puede reconstruir la llave. No hay suficientes piezas."

    return $ret
}




#1 -> Modo de acceso a la partición cifrada "$DRIVEMODE"
#2 -> Ruta donde se monta el dev que contiene el fichero de loopback "$MOUNTPATH" (puede ser cadena vacía)
#3 -> Nombre del mapper device donde se monta el sistema cifrado "$MAPNAME"
#4 -> Path donde se monta la partición final "$DATAPATH"
#5 -> Ruta al dev loop que contiene la part cifrada "$CRYPTDEV"  (puede ser cadena vacía)  # TODO this var is no maintained on the private part. just ignore it
umountCryptoPart () {

    $PVOPS umountCryptoPart "$1" "$2" "$3" "$4" "$5"

}





genNfragKey () {

    $dlg   --infobox $"Generando llave para la unidad cifrada..." 0 0

    $PVOPS genNfragKey
}


#1-> el dev
#2-> el pwd
formatearClauer () {

    $PVOPS formatearClauer "$1" "$2"
    local retval="$?"

    [ "$retval" -eq 11 ] &&  $dlg --msgbox $"No existe el dispositivo" 0 0
    [ "$retval" -eq 12 ] &&  $dlg --msgbox $"Error durante el particionado: Dispositivo inválido." 0 0
    [ "$retval" -eq 13 ] &&  $dlg --msgbox $"Error durante el particionado" 0 0
    [ "$retval" -eq 14 ] &&  $dlg --msgbox $"Error durante el formateo" 0 0

    echo "formatearClauer: retval: ---$retval---"  >>$LOGFILE 2>>$LOGFILE
	
    return "$retval"
}


#1->currShare
#2->numShares
#3->first clauer? 1 - Si   0 - No
#4->'config' -> only writes config 'share' -> only writes share  '' -> writes both
writeNextClauer () {

    member=$(($1+1))
         
    success=0
    while [ "$success" -eq  "0" ]
      do
      
      clauerpos=$"el siguiente"
      [ "$3" -eq 1 ] && clauerpos=$"el primer"
      
      insertUSB $"Inserte $clauerpos Clauer a escribir ($member de $2) y pulse INTRO." "none"
      # TODO comprobar con nuevo funcionamiento de esta func , entre otras cosas, no hay loop infinito. si ret 1, pedir de nuevo
     
      
      #Pedir pasword nuevo
      
      #Acceder  # TODO esto es un mount, checkdev y getpwd (y format usb + format store), además esto coincide con lo visto fuera, seguramente lo pueda meter todo en una func y/o hacer un bucle
      storeConnect $DEV "newpwd" $"Miembro número $member:\nIntroduzca una contraseña nueva:"
      ret=$?
      
      #Si el acceso se cancela, pedimos que se inserte otro
      if [ "$ret" -eq 1 ] 
	  then
	  $dlg --msgbox $"Ha abortado el formateo del presente Clauer. Inserte otro para continuar" 0 0
	  continue
      fi
      
      #Formatear y particionar el dev        
      $dlg   --infobox $"Preparando Clauer..." 0 0

      formatearClauer "$DEV" "$PASSWD"   
      retf="$?"

      if [ "$retf" -ne 0  ]
	  then
	  continue
      fi

      sync
      
      #escribir fragmento de llave
      if [ "$4" == "" -o "$4" == "share" ]
	  then

	  $dlg   --infobox $"Escribiendo fragmento de llave..." 0 0
          #0 succesully set  1 write error
	  $PVOPS storops writeKeyShare "$DEV" "$PASSWD"  "$1"
	  ret=$?
	  sync
	  sleep 1
	  
          #Si falla la escritura
	  if [ $ret -eq 1 ] 
	      then
	      $dlg --msgbox $"Ha fallado la escritura del fragmento de llave. Inserte otro Clauer para continuar" 0 0 
	      continue
	  fi
      fi
      
      #escribir config
      if [ "$4" == "" -o "$4" == "config" ]
	  then
	  
	  $dlg   --infobox $"Almacenando la configuración del sistema..." 0 0

	  $PVOPS storops writeConfig "$DEV" "$PASSWD"
	  ret=$?
	  sync
	  sleep 1
	  
          #Si falla la escritura
	  if [ $ret -eq 1 ] 
	      then
	      $dlg --msgbox $"Ha fallado la escritura de la configuración. Inserte otro Clauer para continuar" 0 0
	      continue
	  fi
      fi
      
      success=1
      
    done

    detectUsbExtraction $DEV $"Clauer escrito con éxito. Retírelo y pulse INTRO." $"No lo ha retirado. Hágalo y pulse INTRO."
}


writeClauers () {
  

    
    #for i in {0..23} -> no acepta sustitución de variables
    firstloop=1
    for i in $(seq 0 $(($SHARES-1)) )
      do
      writeNextClauer $i $SHARES $firstloop
      sync

      [ "$firstloop" -eq "1" ] && firstloop=0
      
    done


}












#Prompt user to select a partition among those available
#1 -> 'all' to list all available partitions
#     'wfs' to show only those with a valid fs
#2 -> Top message to be shown
#Return: 0 if ok, 1 if cancelled
#DRIVE: name of the selected partition
hddPartitionSelector () {
    
    local partitions=$($PVOPS listHDDPartitions "$1" fsinfo)
    local npartitions=$?
    
    #Error
    if [ $npartitions -eq 255 ] ; then
        $dlg --msgbox $"Error accessing drives. Please check." 0 0
        return 1
        #No partitions available
    elif [ $npartitions -eq 0 ] ; then
        $dlg --msgbox $"No drive partitions available. Please check." 0 0
        return 1
    fi
    local drive=$($dlg --cancel-label $"Cancel"  \
                       --menu "$2" 0 80 \
                       $(($npartitions)) $partitions 2>&1 >&4)
	   #If canceled, go back to the mode selector
	   [ $? -ne 0 ]  && return 1;
    
    DRIVE="$drive"
    return 0
}



#Select which method should be used to setup an encrypted drive
#Will set the follwong global variables:
#DRIVEMODE
#DRIVELOCALPATH
#FILEPATH
#FILEFILESIZE
#CRYPTFILENAME
selectCryptoDriveMode () {
    
    local isLocal=on
    local isLoop=off
    
    exec 4>&1     
	   local choice=""
	   while true
	   do
        [ "$DRIVEMODE" == "local" ]   && isLocal=on  && isLoop=off
        [ "$DRIVEMODE" == "file" ]    && isLocal=off && isLoop=on
        
        choice=$( $dlg --cancel-label $"Menu" \
                       --radiolist  $"Ciphered filesystem location:" 0 0 2  \
	                      1 $"Local drive partition"      "$isLocal" \
	                      2 $"Local drive loopback file"  "$isLoop"  \
	                      2>&1 >&4 )
        
        #If cancelled, exit
        [ $? -ne 0 ] && return 1
        
        #If none selected, ask again
        [ "$choice" == "" ] && continue
        
        
        
	       if [ "$choice" -eq 1 ] #### Local partition
        then
	           DRIVEMODE="local"
            
            #Choose partition
            hddPartitionSelector all $"Choose a partition (WARNING: ALL INFORMATION ON THE SELECTED PARTITION WILL BE LOST)."
            [ $? -ne 0 ] && continue
            
            #Set the selected partition
	           DRIVELOCALPATH=$DRIVE
	           
        else #### Loopback filesystem
	          	DRIVEMODE="file"
	           
            #Choose partition
            hddPartitionSelector wfs $"Choose a partition. Loop filesystem will be written on a file in its root directory."
            [ $? -ne 0 ] && continue
            
            #Set the selected partition
            FILEPATH=$DRIVE

            #Ask additional parameters to create the loopback filesystem
	           while true
		          do
                local fsize=$($dlg --cancel-label $"Back"  --inputbox  \
		                                 $"Loopback filesystem file size (in MB):" 0 0 "$FILEFILESIZE"  2>&1 >&4)

                #If back, go to the mode selector
                [ "$?" -ne 0 ] && continue 2
                
	               parseInput int "$fsize"
                if [ $? -ne 0 ] ; then
                    $dlg --msgbox $"Value not valid. Must be a positive integer." 0 0
		                  continue
	               fi
                
                FILEFILESIZE="$fsize"
                break
	           done
            
            #Generate a unique name for the loopback file
	           CRYPTFILENAME="$CRYPTFILENAMEBASE"$(date +%s) # TODO Do not use as global in functions. make sure it is written in config before gbiulding the ciph part. -Also, try to move this to the privileged part (as they are written there, if I remember well)
        fi
        break
	   done
    #<DEBUG>
    echo "Crypto drive mode: $DRIVEMODE"  >>$LOGFILE 2>>$LOGFILE
    echo "Local path:        $DRIVELOCALPATH"  >>$LOGFILE 2>>$LOGFILE
	   echo "Local file:        $FILEPATH" >>$LOGFILE 2>>$LOGFILE
	   echo "File system size:  $FILEFILESIZE" >>$LOGFILE 2>>$LOGFILE
		  echo "Filename:          $CRYPTFILENAME" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
} #selectCryptoDriveMode





#Will prompt the user to select the ssh backup server connection
#parameters
#Will set the following globals:
#SSHBAKSERVER
#SSHBAKPORT
#SSHBAKUSER
#SSHBAKPASSWD
sshBackupParameters () {
    
    #Defaults
    [ "$SSHBAKPORT" == "" ] && SSHBAKPORT=$DEFSSHPORT
    
    local choice=""
    exec 4>&1
    local BAKIFS=$IFS
    IFS=$(echo -en "\n\b")
    while true
    do
		      local formlen=4
	       choice=$($dlg  --cancel-label $"Back" --mixedform  $"SSH backup parameters" 0 0 12  \
		                     $"Field"              1  1 $"Value"                1  30  17 15   2  \
		                     $"SSH server (IP/DN)" 3  1 "$SSHBAKSERVER" 3  30  30 2048 0  \
		                     $"Port"               5  1 "$SSHBAKPORT"   5  30  20  6   0  \
		                     $"Username"           7  1 "$SSHBAKUSER"   7  30  20 256  0  \
		                     $"Password"           9  1 "$SSHBAKPASSWD"   9  30  20 256  1  \
		                     2>&1 >&4 )        
        
	       #If cancelled, exit
        [ $? -ne 0 ] && return 2
        
        #All mandatory, ask again if any empty
        local clist=($choice)
        if [ ${#clist[@]} -le "$formlen" ] ; then
            $dlg --msgbox $"All fields are mandatory" 0 0
	           continue 
	       fi
        
	       #Parse each entry before setting it
     	  local i=0
	       local loopAgain=0
        local errors=""
	       for item in $choice
	       do
            IFS=$BAKIFS #Restore temporarily
            
	           case "$i" in
				            "1" ) #IP or DN of the SSH server
		                  parseInput ipdn "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"SSH server address IP or domain not valid"
  		                else SSHBAKSERVER="$item" ; fi
		                  ;;
		              
				            "2" ) #SSH server port
		                  parseInput port "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Server port number not valid"
  		                else SSHBAKPORT="$item" ; fi
		                  ;;

                "3" ) #Remote username
		                  parseInput user "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Username not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else SSHBAKUSER="$item" ; fi
		                  ;;

                "4" ) #Remote password
		                  parseInput pwd "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Password not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else SSHBAKPASSWD="$item" ; fi
		                  ;;
            esac

            BAKIFS=$IFS
            IFS=$(echo -en "\n\b")

            i=$((i+1))
		      done

        IFS=$BAKIFS
        
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
    done
    #</DEBUG>
    echo "SSH Server:        $SSHBAKSERVER" >>$LOGFILE 2>>$LOGFILE
	   echo "SSH port:          $SSHBAKPORT" >>$LOGFILE 2>>$LOGFILE
	   echo "SSH User:          $SSHBAKUSER" >>$LOGFILE 2>>$LOGFILE
	   echo "SSH pwd:           $SSHBAKPASSWD" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
}





#Does a test connection to the set SSH backup server
#Return: 0 if OK, non-zero if any problem happened
checkSSHconnectivity () {
    
		  #Set trust on the server
    sshScanAndTrust "$SSHBAKSERVER"  "$SSHBAKPORT"
    if [ $? -ne 0 ] ; then
        echo "SSH Keyscan error." >>$LOGFILE 2>>$LOGFILE
        return 1
		  fi
    
    #Perform test connection
    return sshTestConnect "$SSHBAKSERVER"  "$SSHBAKPORT"  "$SSHBAKUSER"  "$SSHBAKPASSWD"
}








                # TODO  con HOSTNM Y DOMNAME los dos construir el fqdn y usarlo en el mailer, en el hosts y donde haga falta

# $1 -> reset params (0) or keep previous values (1)
selectMailerParams () {
	
	#Solicitar datos del administrador del sistema
	verified=0
	while [ "$verified" -eq 0 ]
	  do
	  
	  verified=1
	  
	  
	  $dlg  --yes-label $"Sí" --no-label $"No" --yesno $"El sistema incluye un servidor de correo para enviar las actas. ¿Necesita su red que este se redirija a un servidor intermedio (relay host)?" 0 0 
	  
	  #No necesita relay
	  [ $? -ne 0 ] && MAILRELAY=""  && return 0
	  
	  MAILRELAY=$($dlg  --inputbox  \
	      $"Nombre de dominio del servidor de correo intermedio." 0 0 "$MAILRELAY"  2>&1 >&4)
	  
	  #Cancelado
	  [ $? -ne 0 ] &&  verified=0 && continue

	  if [ "$MAILRELAY" == "" ]
	      then
	      verified=0
	      $dlg --msgbox $"Debe proporcionar un nombre de dominio o una IP." 0 0
	      continue
	  fi
	  
	  parseInput ipdn "$MAILRELAY"
	  if [ $? -ne 0 ] 
	      then
	      verified=0  
	      $dlg --msgbox $"Debe proporcionar un nombre de dominio o una IP válida." 0 0
	      continue
	  fi
	  	  
	done
	
}
    


#PARÁMETROS DE COMPARTICIÓN DE LA CLAVE
    

# $1 -> reset params (0) or keep previous values (1)    
selectSharingParams () {
	
	#$dlg --msgbox $"Ahora se le solicitaran los parámetros de compartición de la llave de cifrado del sistema. Notese que se requiere un minimo de dos personas compartiendo la llave y que debe ser necesarias dos o mas para reconstruirla. \nNo se recomienda que el minimo de personas para reconstruirla coincida con el número de miembros, para evitar una perdida de datos por la corrupcion accidental de piezas." 0 0
	formlen=3
	choice=""
	while [ "$choice" == "" ]
	  do
	  choice=$($dlg  --no-cancel  --mixedform  $"Parámetros de compartición de la clave" 0 0 13  \
	      $"Campo"                                                 1  1 $"Valor"                  1  50  17 15   2  \
	      $"Miembros de la comisión de custodia de la clave"       3  1 "${secsharingPars[1]}"    3  50  5 3 0  \
	      $"de los cuales podrán reconstruirla un mínimo de"       5  1 "${secsharingPars[2]}"    5  50  5 3 0  \
	      2>&1 >&4 )
      
	  c=0
	  for i in $choice
	    do
	    secsharingPars["$c"]="$i"
	    c=$(($c +1))
	  done
	  
	  
          #Validar la entrada
	  
          #Back
	  [ "$choice" == "" ] && choice='' && break;
      
	  len=0
	  again=0
	  for i in $choice
	    do
	    case "$len" in 
		"1" )
                parseInput int "${secsharingPars[1]}"
		ret=$?
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. Debe introducir un valor entero" 0 0
		    again=$(($again | 1)); 
		fi
		;;
		
		"2" )
		parseInput int "${secsharingPars[2]}"
		ret=$?
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. Debe introducir un valor entero" 0 0
		    again=$(($again | 1)); 
		fi
		;;
		
		esac
		
		len=$(($len +1))    
		  
		[ "$len" -ge "$formlen" ] && break
		  
	     done
		
      
	     [ "$again" -eq 1 ]&& choice="" && continue
		
		
	     len=0
	     for i in $choice
	       do
	       len=$(($len +1))
	     done
	     
	     if [ "$len" -lt "$formlen" ]
		 then
		 $dlg --msgbox $"Error. Faltan campos por rellenar" 0 0
		 choice=""
		 continue; 	
	     fi
	     
	     
             #Verificamos que el num de miembros sea >= que el threshold y >= que 2, y el threshold sea >=2
	     if [ "${secsharingPars[1]}" -lt 2 ]
		 then
		 $dlg --msgbox $"Error. Debe haber al menos dos miembros custodiando la llave" 0 0
		 choice=""
		 continue;
	     fi
	     
	     if [ "${secsharingPars[2]}" -lt 2 ]
		 then
		 $dlg --msgbox $"Error. Un sólo miembro no debe poder reconstruir la llave" 0 0
		 choice=""
		 continue;
	     fi

	     if [ "${secsharingPars[2]}" -gt "${secsharingPars[1]}" ]
		 then
		 $dlg --msgbox $"Error. El número de miembros debe ser mayor al mínimo de reconstrucción" 0 0
		 choice=""
		 continue;
	     fi
	     
        done
	     
        SHARES="${secsharingPars[1]}"
        THRESHOLD="${secsharingPars[2]}"
}














# $1 --> 'new' o 'renew'  #///Cambiar en las llamadas
fetchCSR () {
    
    $PVOPS fetchCSR "$1"
    
}




# 1 -> 'new' o 'renew'	
generateCSR () { #*-*-adaptando al  nuevo conjunto de datos
    
    local mode="$1"
    
    $dlg --msgbox $"Vamos a generar un certificado para las conexiones seguras.\n Debe proporcionar los datos de la entidad propietaria de este servidor (el nombre de dominio bajo el que operará el servidor)" 0 0
    
    #Generamos un cert autofirmado
    COMPANY=""
    DEPARTMENT=""
    COUNTRY=""
    STATE=""
    LOC=""
    SERVEREMAIL=""
    SERVERCN=""
  
    HOSTNM=$($PVOPS vars getVar c HOSTNM) #////probar
    SITESCOUNTRY=$($PVOPS vars getVar d SITESCOUNTRY) 
    SITESORGSERV=$($PVOPS vars getVar d SITESORGSERV)
    SITESEMAIL=$($PVOPS vars getVar d SITESEMAIL)

    [ "$HOSTNM" != "" ] && SERVERCN="$HOSTNM"
    [ "$SITESCOUNTRY" != "" ] && COUNTRY="$SITESCOUNTRY"
    [ "$SITESORGSERV" != "" ] && COMPANY="$SITESORGSERV"
    [ "$SITESEMAIL" != "" ] && SERVEREMAIL="$SITESEMAIL"
    
    verified=0
    while [ "$verified" -eq 0 ]
      do
      
      verified=1
      
      #////añadir campos y comprobaciones que hay implementados en el branch*-*-

 COMPANY=$($dlg  --no-cancel  --inputbox  \
	  $"Nombre de la organización\nque controla el servidor:" 0 0 "$COMPANY"  2>&1 >&4)
      
      DEPARTMENT=$($dlg --no-cancel  --inputbox \
	  $"Departamento o sub-organización\nque controla el servidor (opcional):" 0 0 "$DEPARTMENT" 2>&1 >&4)
      
      COUNTRY=$($dlg  --no-cancel  --inputbox  \
	  $"País en que se ubica la organización\nque controla el servidor:" 0 0 "$COUNTRY"  2>&1 >&4)

      STATE=$($dlg  --no-cancel  --inputbox  \
	  $"Provincia en que se ubica la organización\nque controla el servidor (opcional):" 0 0 "$STATE"  2>&1 >&4)
      LOC=$($dlg  --no-cancel  --inputbox  \
	  $"Localidad en que se ubica la organización\nque controla el servidor (opcional):" 0 0 "$LOC"  2>&1 >&4)
      SERVEREMAIL=$($dlg  --no-cancel  --inputbox  \
	  $"Correo electrónico de contacto con su organización (opcional):" 0 0 "$SERVEREMAIL"  2>&1 >&4)
	  
      SERVERCN=$($dlg --no-cancel  --inputbox  \
	  $"Nombre de dominio del servidor:" 0 0 "$SERVERCN"  2>&1 >&4)

      
      if [ "$COMPANY" == "" ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe proporcionar un nombre de organizacion." 0 0
	  continue
      fi

      if [ "$COUNTRY" == "" ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe proporcionar un código de país." 0 0
	  continue
      fi
      
      if [ "$SERVERCN" == "" ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe proporcionar un nombre de dominio." 0 0
	  continue
      fi
      
      
      
      aux=$(echo "$COMPANY" | grep -Ee "[='\"/$]")	  
      [ "$aux" != "" ] && verified=0  && $dlg --msgbox \
	  $"El nombre de organización no puede contener los caracteres:\n  = ' \" / \$" 0 0 && continue

      
      aux=$(echo "$DEPARTMENT" | grep -Ee "[='\"/$]")	  
      [ "$aux" != "" ] && verified=0  && $dlg --msgbox \
	  $"El nombre de departamento no puede contener los caracteres:\n  = ' \" / \$" 0 0 && continue	  

      aux=$(echo "$STATE" | grep -Ee "[='\"/$]")	  
      [ "$aux" != "" ] && verified=0  && $dlg --msgbox \
	  $"La provincia no puede contener los caracteres:\n  = ' \" / \$" 0 0 && continue	  
      
      aux=$(echo "$LOC" | grep -Ee "[='\"/$]")	  
      [ "$aux" != "" ] && verified=0  && $dlg --msgbox \
	  $"La localidad no puede contener los caracteres:\n  = ' \" / \$" 0 0 && continue	  

      parseInput cc "$COUNTRY"
      if [ $? -ne 0 ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe introducir un código de país válido." 0 0 
	  continue
      fi
      
      if [ "$SERVEREMAIL" != "" ]
	  then
	  parseInput email "$SERVEREMAIL"
	  if [ $? -ne 0 ] 
	      then
	      verified=0 
	      $dlg --msgbox $"Debe introducir una dirección de correo válida." 0 0
	      continue
	  fi
      fi
      
      parseInput dn "$SERVERCN"
      if [ $? -ne 0 ] 
	  then
	  verified=0  
	  $dlg --msgbox $"Debe introducir un nombre de dominio válido." 0 0 
	  continue
      fi
      
      if [ "$verified" -eq 1 ] 
	  then
	  $dlg --yes-label $"Revisar"  --no-label $"Continuar"  --yesno \
	      $"Datos adquiridos. ¿Desea revisarlos o desea continuar con la generación de la petición de certificado?" 0 0 
	  verified=$?
      fi
      
    done
    
    $dlg --infobox $"Generando petición de certificado..." 0 0

    $PVOPS configureServers generateCSR "$mode" "$SERVERCN" "$COMPANY" "$DEPARTMENT" "$COUNTRY" "$STATE" "$LOC" "$SERVEREMAIL"
    ret=$?

    echo "$PVOPS configureServers generateCSR '$mode' '$SERVERCN' '$COMPANY' '$DEPARTMENT' '$COUNTRY' '$STATE' '$LOC' '$SERVEREMAIL' ret:$ret"  >>$LOGFILE 2>>$LOGFILE

    if [ "$ret" -ne 0 ]
	then
	$dlg --msgbox $"Error generando la petición de certificado." 0 0
	return 1
    fi
    

    return 0
}


    


#//// revisar el uso correcto en modo mant  --> no veo la diferencia. probarlo en funcionamiento y seguir el proceso.
#Reconstruye la clave, con fines de comprobar la autorización de realizar acciones 
# de mantenimiento sin reiniciar el equipo o para recuperar los datos del backup

# 1 -> el modo de readClauer (k, c, o b (ambos))  # Quizá pasar al flujo directo, ver dónde se usa
getClauersRebuildKey () {
    
    
    ret=0
    firstcl=1
    #mientras queden dispositivos
    while [ $ret -ne 1 ]
      do
      
      readNextUSB  "$1"  
      status=$?
      
      [ "$firstcl" -eq 1 ] && firstcl=0
      
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
	  ret=0
	  continue
      fi
      

      #Si todo ha ido bien y ha leido config, compararlas
      if [ "$1" == "c" -o "$1" == "b" ] ; then
	  $PVOPS storops compareConfigs
      fi
      
      #Preguntar si quedan más dispositivos
      $dlg   --yes-label $"Sí" --no-label $"No" --yesno  $"¿Quedan más Clauers por leer?" 0 0  
      ret=$?
      
    done
	


    
    $dlg   --infobox $"Reconstruyendo la llave de cifrado..." 0 0
        
rebuildKey 
	ret=$?

	#Si no se logra con ninguna combinación, pánico y adiós.
        if [ "$ret" -ne 0 ] 
	    then
	    $dlg --msgbox  $"No se ha podido reconstruir la llave." 0 0 
	    return 1
	fi
	
    fi

    $dlg --msgbox $"Se ha logrado reconstruir la llave." 0 0 

    return 0
}





























#Pasa las variables de configuración empleadas en este caso a una cadena separada por saltos de linea para volcarlo a un clauer
setConfigVars () {
    
    $PVOPS vars setVar c IPMODE $IPMODE
	$PVOPS vars setVar c HOSTNM "$HOSTNM"
 $PVOPS vars setVar c DOMNAME "$DOMNAME"
 
    if [ "$IPMODE" == "static"  ] #si es 'dhcp' no hacen falta
	then
	$PVOPS vars setVar c IPADDR "$IPADDR"
	$PVOPS vars setVar c MASK "$MASK"
	$PVOPS vars setVar c GATEWAY "$GATEWAY"
	$PVOPS vars setVar c DNS1 "$DNS1"
	$PVOPS vars setVar c DNS2 "$DNS2"
    fi
    
    
    $PVOPS vars setVar c DRIVEMODE "$DRIVEMODE"
    
    case "$DRIVEMODE" in
	
	"local" )
        $PVOPS vars setVar c DRIVELOCALPATH "$DRIVELOCALPATH"
	;;
	
    	"file" )
	$PVOPS vars setVar c FILEPATH "$FILEPATH"
	$PVOPS vars setVar c FILEFILESIZE "$FILEFILESIZE"
        $PVOPS vars setVar c CRYPTFILENAME "$CRYPTFILENAME"
    	;;
	
    esac


	$PVOPS vars setVar c SSHBAKSERVER "$SSHBAKSERVER"
	$PVOPS vars setVar c SSHBAKPORT "$SSHBAKPORT"
	$PVOPS vars setVar c SSHBAKUSER "$SSHBAKUSER"
	$PVOPS vars setVar c SSHBAKPASSWD "$SSHBAKPASSWD"


    $PVOPS vars setVar c SHARES "$SHARES"
    $PVOPS vars setVar c THRESHOLD "$THRESHOLD"
}

