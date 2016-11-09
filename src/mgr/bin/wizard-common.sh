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
            
	           local pass2=$($dlg $nocancelbutton  --max-input 32 --passwordbox $"Vuelva a escribir su contrase�a." 10 40 2>&1 >&4)
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












#SEGUIR

#Sets a config variable on disk file. these vars override those read from Clauer
# $1 -> variable
# $2 -> value
setVarOnDisc () {  #//// convertir para que llame a la func de pvops


    echo "****setting var on disc: '$1'='$2'" >>$LOGFILE 2>>$LOGFILE #/////Borrar

    touch $VARFILE

    #Verificamos si la variable est� definida en el fichero
    local isvardefined=$(cat $VARFILE | grep -Ee "^$1")

    #echo "isvardef: $isvardefined"

    #Si no lo est�, append
    if [ "$isvardefined" == "" ] ; then
	echo "$1=\"$2\"" >> $VARFILE
    else
    #Si lo est�, sustituci�n.
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

    #Borramos las l�neas vacias
    sed -i -re '/^\s*$/d' $VARFILE
}



stopServers () {
    $PVOPS  stopServers
}












#Comprueba todas las shares existentes en el slot activo
testForDeadShares () {
    
    $PVOPS storops testForDeadShares
    local ret="$?"

    [ "$ret" -eq 2 ] && systemPanic $"Error interno. Faltan datos de configuraci�n para realizar la resconstrucci�n."
      
    [ "$ret" -eq 3 ] && systemPanic $"No se puede reconstruir la llave. No hay suficientes piezas."

    return $ret
}




#1 -> Modo de acceso a la partici�n cifrada "$DRIVEMODE"
#2 -> Ruta donde se monta el dev que contiene el fichero de loopback "$MOUNTPATH" (puede ser cadena vac�a)
#3 -> Nombre del mapper device donde se monta el sistema cifrado "$MAPNAME"
#4 -> Path donde se monta la partici�n final "$DATAPATH"
#5 -> Ruta al dev loop que contiene la part cifrada "$CRYPTDEV"  (puede ser cadena vac�a)  # TODO this var is no maintained on the private part. just ignore it
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
    [ "$retval" -eq 12 ] &&  $dlg --msgbox $"Error durante el particionado: Dispositivo inv�lido." 0 0
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
      
      #Acceder  # TODO esto es un mount, checkdev y getpwd (y format usb + format store), adem�s esto coincide con lo visto fuera, seguramente lo pueda meter todo en una func y/o hacer un bucle
      storeConnect $DEV "newpwd" $"Miembro n�mero $member:\nIntroduzca una contrase�a nueva:"
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
	  
	  $dlg   --infobox $"Almacenando la configuraci�n del sistema..." 0 0

	  $PVOPS storops writeConfig "$DEV" "$PASSWD"
	  ret=$?
	  sync
	  sleep 1
	  
          #Si falla la escritura
	  if [ $ret -eq 1 ] 
	      then
	      $dlg --msgbox $"Ha fallado la escritura de la configuraci�n. Inserte otro Clauer para continuar" 0 0
	      continue
	  fi
      fi
      
      success=1
      
    done

    detectUsbExtraction $DEV $"Clauer escrito con �xito. Ret�relo y pulse INTRO." $"No lo ha retirado. H�galo y pulse INTRO."
}


writeClauers () {
  

    
    #for i in {0..23} -> no acepta sustituci�n de variables
    firstloop=1
    for i in $(seq 0 $(($SHARES-1)) )
      do
      writeNextClauer $i $SHARES $firstloop
      sync

      [ "$firstloop" -eq "1" ] && firstloop=0
      
    done


}



#Obtenci�n de params




        
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
###TODO depu�s, los valores establecidos aqu� se pasar�n al  privil. op adecuado donde se parsear�n de nuevo y se establecer�n si corresponde. Hacer op para leer y preestablecer los valores de estas variables y usarlas como valores default (para los pwd, obviamente, no)
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
				                "1" ) # IP
		                      parseInput ipaddr "$item" #if [ $? -ne 0 ] ; then loopAgain=1; 
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
		                      ;;	               esac
                
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
    #</DEBUG>
    
    return $ret
} #NetworkParams















     #PAR�METROS DE ACCESO A LA PARTICI�N CIFRADA   
     

     # $1 -> reset params (0) or keep previous values (1)
     selectCryptoDrivemode () {
	 
	 choice=""
	 while [ "$choice" == "" ]
	   do
	   choice=$($dlg --no-cancel   --radiolist  $"Ubicaci�n de los datos cifrados." 0 60 13  \
	       1 $"Partici�n en disco local" "${crydrivemodeArr[1]}"                 \
	       2 $"A trav�s de servidor NFS" "${crydrivemodeArr[2]}"    \
	       3 $"A trav�s de servidor Samba" "${crydrivemodeArr[3]}"  \
	       4 $"A trav�s de iSCSI" "${crydrivemodeArr[4]}"  \
	       5 $"Fichero en disco local" "${crydrivemodeArr[5]}"  \
	       2>&1 >&4 )
	   
	   for i in 1 2 3 4 5
	     do
	     crydrivemodeArr["$i"]="off"
	     [ "$i" -eq "$choice" ]  &&  crydrivemodeArr[$i]="on"
	   done
	   
	   #echo "Retorno del radio: "$choice
	   
	   USINGSSHBAK="0"
	   case "$choice" in
	       
	      "1" )
              USINGSSHBAK="1"
              #Mostrar el form espec�fico para partici�n Local 
	      DRIVEMODE="local" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      
              $dlg --yes-label $"Cancelar" --no-label $"Continuar"  --yesno $"A continuaci�n se le instar� a que seleccione una partici�n local.\nN�tese que los datos contenidos ser�n totalmente destruidos.\n\n�Desea continuar?" 0 0
	      
	      
	      #Cancelado
	      [ $? -eq 0 ] && choice='' && continue;
	      
	      listPartitions
	      
	      drive=$($dlg --cancel-label $"Cancelar"  --menu $"Seleccione una partici�n." 0 80 $(($NPARTS)) $PARTS 2>&1 >&4)
	      
	      [ $? -ne 0 ]  && choice='' && continue;
	      
	      DRIVELOCALPATH=$drive
	      
	      ;;



	      "2" ) 
	      formlen=5
	      DRIVEMODE="nfs" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      choice=""
	      nfsconfArr[2]=$DEFNFSPORT
	      while [ "$choice" == "" ]
		do
		choice=$($dlg  --cancel-label $"Atr�s"  --mixedform  $"Par�metros de acceso a la partici�n cifrada" 0 0 13  \
		    $"Campo"                        1  1 $"Valor"                   1  30  17 15   2  \
		    $"Servidor (IP/DN)"             3  1 "${nfsconfArr[1]}"         3  30  20  2048   0  \
		    $"Puerto"                       5  1 "${nfsconfArr[2]}"         5  30  20  6      0  \
		    $"Ruta de destino"              7  1 "${nfsconfArr[3]}"         7  30  20  2048   0  \
		    $"Tama�o del fichero (MB)"      9  1 "${nfsconfArr[4]}"         9  30  20  100    0  \
		    2>&1 >&4 )
		
		c=0
		for i in $choice
		  do
		  nfsconfArr["$c"]="$i"
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
		      parseInput ipdn "${nfsconfArr[1]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre v�lido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${nfsconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un n�mero de puerto v�lido" 0 0
			  again=$(($again | 1));
		      fi
		      ;;
		      		      		      
		      "3" )
		      parseInput path "${nfsconfArr[3]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una ruta v�lida. Los nombres de directorio pueden contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      		      
		      "4" )
		      parseInput int "${nfsconfArr[4]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un tama�o entero" 0 0
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
	      done


	      NFSSERVER="${nfsconfArr[1]}"
	      NFSPORT="${nfsconfArr[2]}"
	      NFSPATH="${nfsconfArr[3]}"
	      NFSFILESIZE="${nfsconfArr[4]}"
	      ;;



	      "3" )
              #Mostrar El form espec�fico para Samba
              formlen=7
	      DRIVEMODE="samba" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      choice=""
	      sambaconfArr[2]=$DEFSMBPORT
	      while [ "$choice" == "" ]
		do
		choice=$($dlg  --cancel-label $"Atr�s"  --mixedform  $"Par�metros de acceso a la partici�n cifrada" 0 0 13  \
		    $"Campo"                     1  1 $"Valor"                1  30  17 15   2  \
		    $"Servidor (IP/DN)"          3  1 "${sambaconfArr[1]}"    3  30  30 2048 0  \
		    $"Puerto"                    5  1 "${sambaconfArr[2]}"    5  30  20  6   0  \
		    $"Nombre del recurso"        7  1 "${sambaconfArr[3]}"    7  30  30 2048 0  \
		    $"Usuario"                   10 1 "${sambaconfArr[4]}"    10 30  20 256  0  \
		    $"Contrase�a"                12 1 "${sambaconfArr[5]}"    12 30  20 256  1  \
		    $"Tama�o del fichero (MB)"   14 1 "${sambaconfArr[6]}"    14 30  20 100  0  \
		    2>&1 >&4 )
		
		c=0
		for i in $choice
		  do
		  sambaconfArr["$c"]="$i"
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
		      parseInput ipdn "${sambaconfArr[1]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre v�lido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${sambaconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un n�mero de puerto v�lido" 0 0
			  again=$(($again | 1));
		      fi
		      ;;		      
		      
		      "3" )
		      parseInput path "${sambaconfArr[3]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una ruta v�lida. Los nombres de los directorios pueden contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "4" )
		      parseInput user "${sambaconfArr[4]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. El nombre de usuario no es v�lido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "5" )
		      parseInput pwd "${sambaconfArr[5]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. La contrase�a no es v�lida. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      	
		      "6" )
		      parseInput int "${sambaconfArr[6]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. El tama�o debe ser entero." 0 0
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
		
		
	      done
	      SMBSERVER="${sambaconfArr[1]}"
	      SMBPORT="${sambaconfArr[2]}"
	      SMBPATH="${sambaconfArr[3]}"
	      SMBUSER="${sambaconfArr[4]}"
	      SMBPWD="${sambaconfArr[5]}"
	      SMBFILESIZE="${sambaconfArr[6]}"
	      ;;
	      
	      
	      
	      "4" )
	      
	      $PSETUP iscsi restart #////Esta igual debe pasarse a PVOPS
	      
              #Mostrar el form espec�fico para iscsi #Pedir host y port: luego hacer discover o, si no hay un servidor, pedir a  mano
              formlen=3
	      DRIVEMODE="iscsi" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      choice=""
	      iscsiconfArr[2]=$DEFISCSIPORT
	      while [ "$choice" == "" ]
		do
		choice=$($dlg  --cancel-label $"Atr�s"  --mixedform  $"Par�metros de acceso a la partici�n cifrada" 0 0 13  \
		    $"Campo"                         1  1 $"Valor"                1  30  17 15   2  \
		    $"IP/DN del Portal/Target iSCSI" 3  1 "${iscsiconfArr[1]}"    3  30  20 2048    0  \
		    $"Puerto"                        5  1 "${iscsiconfArr[2]}"    5  30  20  6   0  \
		    2>&1 >&4 )
		
		c=0
		for i in $choice
		  do
		  iscsiconfArr["$c"]="$i"
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
		      parseInput ipdn "${iscsiconfArr[1]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre v�lido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${iscsiconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un n�mero de puerto v�lido" 0 0
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
		
		
		iscsiserv="${iscsiconfArr[1]}"
		
		
		parseInput ipaddr "$iscsiserv"
		ret=$?
		if [ "$ret" -ne 0 ] 
		    then
  		    #No es Ip, sino dn, y hay que resolverlo
		    iscsiip=$(host $iscsiserv | grep -oEe "([0-9]{1,3}\.){3}[0-9]{1,3}")
		    
		    if [ "$iscsiip" == "" ] 
			then
			$dlg --msgbox $"Error. No se pudo resolver el nombre del servidor." 0 0
			choice=""
			continue;
		    fi
		    iscsiserv=$iscsiip 
		fi
		
		
	      done
	      
	      
	      ISCSISERVER="$iscsiserv"
	      
	      ISCSIPORT="${iscsiconfArr[2]}"

	      [ "$choice" == "" ] && continue; # es un continue del bucle principal de sel modo de almacen. 
	      
	      #Ahora pedimos el id del target, con un discover o, si falla, manualmente
	      while true
		do
		
		#Hacer el discover.
		targets=$($PSETUP iscsi discovery  "$ISCSISERVER" "$ISCSIPORT")
		portalres=$?
		#Si hay servidor de targets (portal). sacar menu selector de targets
		if [ "$portalres" -eq 0 ] 
		    then
		    
		    listTargets "$targets"
		    
		    drive=$($dlg --cancel-label $"Cancelar"  --menu $"Seleccione un Target." 0 120 $(($NTAR)) $TARS 2>&1 >&4)
		    res=$?

		    echo "Target: "$drive  >>$LOGFILE 2>>$LOGFILE
		    
                    #Back
		    [ "$res" -ne 0 ]   && choice='' && continue 2; #Hace un continue en el bucle de sel de modo de almacen.
		    [ "$drive" == "" ] && choice='' && continue 2; #Hace un continue en el bucle de sel de modo de almacen.

		    #Modificarlos seg�n el target elegido.
		    ISCSISERVER=$(echo $drive | grep -oEe "^\([.0-9]+:" | grep -oEe "[.0-9]+")
		    ISCSIPORT=$(echo $drive | grep -oEe ":[.0-9]+\)" | grep -oEe "[0-9]+")
		    ISCSITARGET=$(echo $drive | grep -oEe "\)-.+$" | sed -re "s/^\)-//")
		    		    
		else
		    #Si no hay servidor de targets.
		    ISCSITARGET=$($dlg  --inputbox  \
			$"No se ha localizado un Portal iSCSI. Especifique un target manualmente." 0 0 "$ISCSITARGET"  2>&1 >&4)
	            #Back
		    [ "$?" -ne 0 ] && choice='' && continue 2;	
		    [ "$ISCSITARGET" == "" ] && choice='' && continue 2;	
		fi
				
		if [ "$ISCSITARGET" == "" ] 
		    then
		    $dlg --msgbox $"Debe proporcionar un identificador de target." 0 0
		    continue
		fi
		
		parseInput iscsitar "$ISCSITARGET"
		ret=$?
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. Debe introducir un identificador de target v�lido" 0 0
		    continue
		fi
		
		break
	      done
	      
	      ;;


	      "5" )
              USINGSSHBAK="1"
	      
              #Mostrar el form espec�fico para partici�n en un fs dentro de un fichero (loop)
	      DRIVEMODE="file" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      
	      
              $dlg --yes-label $"Cancelar" --no-label $"Continuar"  --yesno $"A continuaci�n se le instar� a seleccionar una partici�n local.\nEn su ra�z se escribir� un fichero con los datos cifrados.\nEsta partici�n debe contener un sistema de ficheros v�lido." 0 0
	      

	      #Cancelado
	      [ "$?" -eq 0 ] && choice='' && continue;
	      

	      listPartitions "wfs"
	      if [ "$NPARTS" -gt 0 ]
		  then
		  drive=$($dlg --cancel-label $"Cancelar"  --menu $"Seleccione una partici�n." 0 80 $(($NPARTS)) $PARTS 2>&1 >&4)
		  
		  [ $? -ne 0 ]  && choice='' && continue;
	      
	      else
		  $dlg --msgbox $"No existen particiones v�lidas. Elija otro modo." 0 0
		  choice=''
		  continue
	      fi
	      
	      FILEPATH=$drive
	      

              formlen=2
	      choice=""
	      while [ "$choice" == "" ]
		do
		choice=$($dlg  --cancel-label $"Atr�s"  --mixedform  $"Par�metros de acceso a la partici�n cifrada" 0 0 13  \
		    $"Campo"                    1  1 $"Valor"               1  30  17  15     2  \
		    $"Tama�o del fichero (MB)" 3  1 "${fileconfArr[1]}"    3  30  20  100    0  \
		    2>&1 >&4 )
		
		c=0
		for i in $choice
		  do
		  fileconfArr["$c"]="$i"
		  c=$(($c +1))
		done
		
                #Validar la entrada
		
		#Back
		[ "$choice" == "" ] && choice='' && break;
	  
	
		parseInput int "${fileconfArr[1]}"
		ret=$?
		[ "${fileconfArr[1]}" -eq 0 ] && ret=1
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. Debe introducir un tama�o de fichero entero positivo" 0 0
		    choice=''
		    continue;
		fi
	
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
		
		FILEFILESIZE="${fileconfArr[1]}"
	      done
              ;;
	      
	  esac



	#Permite elegir si se va a usar backup por SSH (S�lo lo pregunta si el modo es local)
	if [ "$USINGSSHBAK" -eq "1" ] ; then
	    
	    $dlg  --yes-label $"S�" --no-label $"No" --yesno $"Como el modo de almacenamiento elegido se ubica dentro de esta misma m�quina, se recomienda proporcionar alg�n mecanismo de copia de seguridad externo para evitar una p�rdida irreparable de los datos. Esta copia se realizar� sobre un servidor SSH a su elecci�n, y los datos se almacenar�n cifrados.\n\n�Desea emplear un servidor SSH para la copia de seguridad?" 0 0
	    answer=$?

	    #Si no desea usar backup ssh 
	    [ "$answer" -ne 0 ] && USINGSSHBAK=0
	    
	    
	fi
	
	#Params de backup, si es un modo local
	if [ "$USINGSSHBAK" -eq "1" ] ; then
	    
	    while true; do
		selectDataBackupParams 
		if [ "$?" -ne 0 ] 
		    then
		    $dlg --msgbox $"Debe introducir los par�metros de copia de seguridad." 0 0
		    continue
		fi

		$dlg --infobox $"Verificando acceso al servidor de copia de seguridad..." 0 0

		#A�adimos las llaves del servidor SSH al known_hosts		 
		local ret=$($PVOPS sshKeyscan "$SSHBAKPORT" "$SSHBAKSERVER")
		if [ "$ret" -ne 0 ]  #//// PRobar!!
		    then
		    $dlg --msgbox $"Error conectando con el servidor de copia de seguridad. Revise los datos." 0 0
		    continue
		fi
    echo "pasa el keyscan correctamente" >>$LOGFILE 2>>$LOGFILE
		#Verificar acceso al servidor
		export DISPLAY=none:0.0
		export SSH_ASKPASS=/tmp/askPass.sh
		echo "echo '$SSHBAKPASSWD'" > /tmp/askPass.sh
		chmod u+x  /tmp/askPass.sh >>$LOGFILE 2>>$LOGFILE

		echo "ssh -n  -p '$SSHBAKPORT'  '$SSHBAKUSER'@'$SSHBAKSERVER'" >>$LOGFILE 2>>$LOGFILE
		ssh -n  -p "$SSHBAKPORT"  "$SSHBAKUSER"@"$SSHBAKSERVER" >>$LOGFILE 2>>$LOGFILE
		ret="$?"
		echo "ret? $ret">>$LOGFILE 2>>$LOGFILE
		if [ "$ret"  -ne 0 ]
		    then
		    $dlg --msgbox $"Error accediendo al servidor de copia de seguridad. Revise los datos." 0 0
		    continue
		fi

		echo "pasa. la compr. de ssh" >>$LOGFILE 2>>$LOGFILE

		rm /tmp/askPass.sh >>$LOGFILE 2>>$LOGFILE
		
		break
	    done
	fi
	
	
# part cifrada: localizaci�n( disco_local/nfs/samba/iscsi/loop_fichero)?                                    
#  local: --> ruta de la partici�n (sel.)
#    nfs: --> ip/dn  ruta tama�o   # ip:ruta
#  samba: --> ip/dn ruta , user, pwd, tama�o
#  iscsi: --> ip/dn del target, nombre_target
#fichero: --> ruta de la partici�n en que se almacenar� al fichero, tama�o


	done

	#Generamos los par�metros no interactivos.
       
        #Establecemos el nombre del fichero de loopback (necesariamente �nico), siempre en la raiz
	CRYPTFILENAME="$CRYPTFILENAMEBASE"$(date +%s) # TODO Do not use as global in functions. make sure it is written in config before gbiulding the ciph part. -Also, try to move this to the privileged part (as they are written there, if I remember well)


	#echo "Crypto drive mode: $DRIVEMODE"  >>$LOGFILE 2>>$LOGFILE
	
	#echo "Local path:        $DRIVELOCALPATH"  >>$LOGFILE 2>>$LOGFILE
	
	#echo "NFS server:        $NFSSERVER" >>$LOGFILE 2>>$LOGFILE
	#echo "NFS port:          $NFSPORT" >>$LOGFILE 2>>$LOGFILE
	#echo "NFS path:          $NFSPATH" >>$LOGFILE 2>>$LOGFILE
	#echo "NFS file size:     $NFSFILESIZE" >>$LOGFILE 2>>$LOGFILE
	
	#echo "Samba server:      $SMBSERVER" >>$LOGFILE 2>>$LOGFILE
	#echo "Samba port:        $SMBPORT" >>$LOGFILE 2>>$LOGFILE
	#echo "Samba path:        $SMBPATH" >>$LOGFILE 2>>$LOGFILE
	#echo "Samba user:        $SMBUSER" >>$LOGFILE 2>>$LOGFILE
	#echo "Samba pwd:         $SMBPWD" >>$LOGFILE 2>>$LOGFILE
	#echo "Samba file size:   $SMBFILESIZE" >>$LOGFILE 2>>$LOGFILE
	
	#echo "iSCSI server:      $ISCSISERVER" >>$LOGFILE 2>>$LOGFILE
	#echo "iSCSI port:        $ISCSIPORT" >>$LOGFILE 2>>$LOGFILE
	#echo "iSCSI target:      $ISCSITARGET" >>$LOGFILE 2>>$LOGFILE
	
	#echo "Local file:        $FILEPATH" >>$LOGFILE 2>>$LOGFILE
	#echo "File system size:  $FILEFILESIZE" >>$LOGFILE 2>>$LOGFILE
	

	#echo "Local mode?:       $USINGSSHBAK" >>$LOGFILE 2>>$LOGFILE
	#echo "SSH Server:        $SSHBAKSERVER" >>$LOGFILE 2>>$LOGFILE
	#echo "SSH port:          $SSHBAKPORT" >>$LOGFILE 2>>$LOGFILE
	#echo "SSH User:          $SSHBAKUSER" >>$LOGFILE 2>>$LOGFILE
	#echo "SSH pwd:           $SSHBAKPASSWD" >>$LOGFILE 2>>$LOGFILE

	
	#echo "Filename:          $CRYPTFILENAME" >>$LOGFILE 2>>$LOGFILE
	

} #Selectcryptodrivemode
    

#////En principio, cada ciclo del men� de mant ser� un proceso distino (el anterior morir�), por lo que las variables deber�an quedar liberadas.





selectDataBackupParams () {

	formlen=5
	choice=""
	backupconfArr[2]=$DEFSSHPORT
	while [ "$choice" == "" ]
	  do
	  choice=$($dlg  --no-cancel  --mixedform  $"Par�metros para realizaci�n de copias de seguridad sobre un servidor SSH." 0 0 13  \
		    $"Campo"                     1  1 $"Valor"                1  30  17 15   2  \
		    $"Servidor SSH (IP/DN)"      3  1 "${backupconfArr[1]}"   3  30  30 2048 0  \
		    $"Puerto"                    5  1 "${backupconfArr[2]}"   5  30  20  6   0  \
		    $"Usuario"                   7  1 "${backupconfArr[3]}"   7  30  20 256  0  \
		    $"Contrase�a"                9  1 "${backupconfArr[4]}"   9  30  20 256  1  \
		    2>&1 >&4 )
		
		c=0
		for i in $choice
		  do
		  backupconfArr["$c"]="$i"
		  c=$(($c +1))
		done
		
		#Validar la entrada
		
		#Back
		[ "$choice" == "" ] && return 1;
	  
		len=0
		again=0
		for i in $choice
		  do
		  case "$len" in 
		      "1" )
		      parseInput ipdn "${backupconfArr[1]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre v�lido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${backupconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un n�mero de puerto v�lido" 0 0
			  again=$(($again | 1));
		      fi
		      ;;		      
		      
		      "3" )
		      parseInput user "${backupconfArr[3]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. El nombre de usuario no es v�lido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "4" )
		      parseInput pwd "${backupconfArr[4]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. La contrase�a no es v�lida. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
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


	      done
	      USINGSSHBAK="1"
	      SSHBAKSERVER="${backupconfArr[1]}"
	      SSHBAKPORT="${backupconfArr[2]}"
	      SSHBAKUSER="${backupconfArr[3]}"
	      SSHBAKPASSWD="${backupconfArr[4]}"
	      
	      return 0	
}




# $1 -> reset params (0) or keep previous values (1)
selectMailerParams () {
	
	#Solicitar datos del administrador del sistema
	verified=0
	while [ "$verified" -eq 0 ]
	  do
	  
	  verified=1
	  
	  
	  $dlg  --yes-label $"S�" --no-label $"No" --yesno $"El sistema incluye un servidor de correo para enviar las actas. �Necesita su red que este se redirija a un servidor intermedio (relay host)?" 0 0 
	  
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
	      $dlg --msgbox $"Debe proporcionar un nombre de dominio o una IP v�lida." 0 0
	      continue
	  fi
	  	  
	done
	
}
    


#PAR�METROS DE COMPARTICI�N DE LA CLAVE
    

# $1 -> reset params (0) or keep previous values (1)    
selectSharingParams () {
	
	#$dlg --msgbox $"Ahora se le solicitaran los par�metros de compartici�n de la llave de cifrado del sistema. Notese que se requiere un minimo de dos personas compartiendo la llave y que debe ser necesarias dos o mas para reconstruirla. \nNo se recomienda que el minimo de personas para reconstruirla coincida con el n�mero de miembros, para evitar una perdida de datos por la corrupcion accidental de piezas." 0 0
	formlen=3
	choice=""
	while [ "$choice" == "" ]
	  do
	  choice=$($dlg  --no-cancel  --mixedform  $"Par�metros de compartici�n de la clave" 0 0 13  \
	      $"Campo"                                                 1  1 $"Valor"                  1  50  17 15   2  \
	      $"Miembros de la comisi�n de custodia de la clave"       3  1 "${secsharingPars[1]}"    3  50  5 3 0  \
	      $"de los cuales podr�n reconstruirla un m�nimo de"       5  1 "${secsharingPars[2]}"    5  50  5 3 0  \
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
		 $dlg --msgbox $"Error. Un s�lo miembro no debe poder reconstruir la llave" 0 0
		 choice=""
		 continue;
	     fi

	     if [ "${secsharingPars[2]}" -gt "${secsharingPars[1]}" ]
		 then
		 $dlg --msgbox $"Error. El n�mero de miembros debe ser mayor al m�nimo de reconstrucci�n" 0 0
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
    
    $dlg --msgbox $"Vamos a generar un certificado para las conexiones seguras.\n Debe proporcionar los datos de la entidad propietaria de este servidor (el nombre de dominio bajo el que operar� el servidor)" 0 0
    
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
      
      #////a�adir campos y comprobaciones que hay implementados en el branch*-*-

 COMPANY=$($dlg  --no-cancel  --inputbox  \
	  $"Nombre de la organizaci�n\nque controla el servidor:" 0 0 "$COMPANY"  2>&1 >&4)
      
      DEPARTMENT=$($dlg --no-cancel  --inputbox \
	  $"Departamento o sub-organizaci�n\nque controla el servidor (opcional):" 0 0 "$DEPARTMENT" 2>&1 >&4)
      
      COUNTRY=$($dlg  --no-cancel  --inputbox  \
	  $"Pa�s en que se ubica la organizaci�n\nque controla el servidor:" 0 0 "$COUNTRY"  2>&1 >&4)

      STATE=$($dlg  --no-cancel  --inputbox  \
	  $"Provincia en que se ubica la organizaci�n\nque controla el servidor (opcional):" 0 0 "$STATE"  2>&1 >&4)
      LOC=$($dlg  --no-cancel  --inputbox  \
	  $"Localidad en que se ubica la organizaci�n\nque controla el servidor (opcional):" 0 0 "$LOC"  2>&1 >&4)
      SERVEREMAIL=$($dlg  --no-cancel  --inputbox  \
	  $"Correo electr�nico de contacto con su organizaci�n (opcional):" 0 0 "$SERVEREMAIL"  2>&1 >&4)
	  
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
	  $dlg --msgbox $"Debe proporcionar un c�digo de pa�s." 0 0
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
	  $"El nombre de organizaci�n no puede contener los caracteres:\n  = ' \" / \$" 0 0 && continue

      
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
	  $dlg --msgbox $"Debe introducir un c�digo de pa�s v�lido." 0 0 
	  continue
      fi
      
      if [ "$SERVEREMAIL" != "" ]
	  then
	  parseInput email "$SERVEREMAIL"
	  if [ $? -ne 0 ] 
	      then
	      verified=0 
	      $dlg --msgbox $"Debe introducir una direcci�n de correo v�lida." 0 0
	      continue
	  fi
      fi
      
      parseInput dn "$SERVERCN"
      if [ $? -ne 0 ] 
	  then
	  verified=0  
	  $dlg --msgbox $"Debe introducir un nombre de dominio v�lido." 0 0 
	  continue
      fi
      
      if [ "$verified" -eq 1 ] 
	  then
	  $dlg --yes-label $"Revisar"  --no-label $"Continuar"  --yesno \
	      $"Datos adquiridos. �Desea revisarlos o desea continuar con la generaci�n de la petici�n de certificado?" 0 0 
	  verified=$?
      fi
      
    done
    
    $dlg --infobox $"Generando petici�n de certificado..." 0 0

    $PVOPS configureServers generateCSR "$mode" "$SERVERCN" "$COMPANY" "$DEPARTMENT" "$COUNTRY" "$STATE" "$LOC" "$SERVEREMAIL"
    ret=$?

    echo "$PVOPS configureServers generateCSR '$mode' '$SERVERCN' '$COMPANY' '$DEPARTMENT' '$COUNTRY' '$STATE' '$LOC' '$SERVEREMAIL' ret:$ret"  >>$LOGFILE 2>>$LOGFILE

    if [ "$ret" -ne 0 ]
	then
	$dlg --msgbox $"Error generando la petici�n de certificado." 0 0
	return 1
    fi
    

    return 0
}


    


#//// revisar el uso correcto en modo mant  --> no veo la diferencia. probarlo en funcionamiento y seguir el proceso.
#Reconstruye la clave, con fines de comprobar la autorizaci�n de realizar acciones 
# de mantenimiento sin reiniciar el equipo o para recuperar los datos del backup

# 1 -> el modo de readClauer (k, c, o b (ambos))  # Quiz� pasar al flujo directo, ver d�nde se usa
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
	  $dlg --yes-label $"Reanudar" --no-label $"Finalizar"  --yesno  $"Ha cancelado la inserci�n de un Clauer.\n�Desea finalizar la inserci�n de dispositivos?" 0 0  
	  
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
      
      #Preguntar si quedan m�s dispositivos
      $dlg   --yes-label $"S�" --no-label $"No" --yesno  $"�Quedan m�s Clauers por leer?" 0 0  
      ret=$?
      
    done
	


    
    $dlg   --infobox $"Reconstruyendo la llave de cifrado..." 0 0
        
rebuildKey 
	ret=$?

	#Si no se logra con ninguna combinaci�n, p�nico y adi�s.
        if [ "$ret" -ne 0 ] 
	    then
	    $dlg --msgbox  $"No se ha podido reconstruir la llave." 0 0 
	    return 1
	fi
	
    fi

    $dlg --msgbox $"Se ha logrado reconstruir la llave." 0 0 

    return 0
}








humanReadable () {
    
    python -c "
num=$1
units=['B','KB','MB','GB','TB']
multiplier=0
while num >= 1024 and multiplier<len(units):
  #print 'Num ',num
  #print 'Mul ',multiplier
  num/=1024.0
  multiplier+=1
#print 'Num ',round(num,1)
#print 'Mul ',multiplier

print str(round(num,2))+units[multiplier]
" 
}




# $1 --> Modo wfs 's�lo parts con FS v�lido', (nada) --> Todas las particiones
#Retorno:
#PARTS: lista de particiones para mostrar en un menu
#NPARTS: num de particiones
listPartitions () {

    listDevs     >>$LOGFILE 2>>$LOGFILE  #TODO change for listUSBDrives
    listClauers  >>$LOGFILE 2>>$LOGFILE #TODO change for listUSBDrives

    echo "DEVS+CLS: $DEVS $CLS" >>$LOGFILE 2>>$LOGFILE

    clid=$"Clauer"

    usbsticks=$(echo "$DEVS $CLS" | sed "s/-//g" | sed "s/$clid//g")

    echo "usbsticks: $usbsticks"  >>$LOGFILE 2>>$LOGFILE
        
    drives=""
    
    for n in a b c d e f g h i j k l m n o p q r s t u v w x y z 
      do
      
      found=0
      for d in $usbsticks
	do
	[ "$d" == "/dev/sd$n" ] && found=1 && break
      done
      
      [ $found -eq 0 ] && drives="$drives /dev/sd$n"
      
      found=0
      for d in $usbsticks
	do
	[ "$d" == "/dev/hd$n" ] && found=1 && break
      done
      
      [ $found -eq 0 ] && drives="$drives /dev/hd$n"
      
    done
    
    #Listamos los dispositivos RAID 
    #en el modo con fs, nunca listar� los devs que formen parte de raids, al no poder montarlos, 
    #en este mode debe mostrarlos por si se desea destruir el raid
    for mdid in $(seq 0 99) ; do
	drives="$drives /dev/md$mdid"
    done
    
    echo "Drives not usbstick: $drives"  >>$LOGFILE 2>>$LOGFILE

    PARTS=""
    NPARTS=0
    
    parts=""
    for drive in $drives
      do
      
      echo "Checking: $drive"  >>$LOGFILE 2>>$LOGFILE
      
      dp=$($PVOPS fdiskList "$drive" 2>>$LOGFILE)

      if [ "$dp" != "" ] 
	  then
	  echo "Checking2: $drive"  >>$LOGFILE 2>>$LOGFILE

	  
	  thisparts=$($PVOPS fdiskList $drive 2>/dev/null | grep -Ee "^$drive" | cut -d " " -f 1 )

	  
	  if [ "$1" == "wfs" ]
	      then
	      moreparts=""
	      for part in $thisparts
		do
		
		if [ $($PVOPS checkforWritableFS "$part") -eq 0 ]
		    then
		    moreparts="$moreparts $part" #Si se puede montar y escribir, la sacamos
		fi
	      done
	  else
	      moreparts=$thisparts
	  fi
	  parts="$parts "$moreparts    
      fi
      
    done

    echo "Partitions: "$parts  >>$LOGFILE 2>>$LOGFILE

    for part in $parts
      do

      partinfo=""
      
      
      if [ "$1" == "wfs" ]
	  then
          #Obtenemos el FS de la particion
	  thisfs=$($PVOPS guessFS "$part") 

	  partinfo="$partinfo$thisfs"
      fi

      #Obtenemos el tam de la part
      drive=$(echo $part | sed -re 's/[0-9]+$//g')
      nblocks=$($PVOPS fdiskList "$drive" 2>/dev/null | grep "$part" | sed -re "s/[ ]+/ /g" | cut -d " " -f4 | grep -oEe '[0-9]+' )
	  
      if [ "$nblocks" != "" ]
	  then
	  ### Esto no sirve. Es el tam de bloque del FS, no el tam de
          ### sector que usa el kernel. El kernel usa como tama�o m�nimo
          ### de sector 1K (incluso si es de 512).
          #echo -n "a" > /media/testpart/blocksizeprobe      
          #blocksize=$(ls -s /media/testpart/blocksizeprobe | cut -d " " -f1) #Saca el tam de bloque en Kb
          #rm -f /media/testpart/blocksizeprobe
      
	  blocksize=$($PVOPS fdiskList "$drive" 2>/dev/null | grep -Eoe "[*][ ]+[0-9]+[ ]+=" | sed -re "s/[^0-9]//g" )
	  if [ "$blocksize" != "" ]
	      then
	      [ "$blocksize" -lt 1024 ] && blocksize=1024
	      
	      thissize=$(($blocksize*$nblocks))      
	      hrsize=$(humanReadable "$thissize")
	      
      
	      partinfo="$partinfo|$hrsize"
	  fi
      fi
      
      [ "$partinfo" == ""  ] && partinfo="-"
      
      NPARTS=$(($NPARTS +1))
      PARTS=$PARTS" $part $partinfo"
    done
    
    
    echo "Partitions: "$parts  >>$LOGFILE 2>>$LOGFILE
    echo "Num:        "$NPARTS >>$LOGFILE 2>>$LOGFILE
    echo "Partitions: "$PARTS  >>$LOGFILE 2>>$LOGFILE
}









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











#Pasa las variables de configuraci�n empleadas en este caso a una cadena separada por saltos de linea para volcarlo a un clauer
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
	
    	"nfs" )
	$PVOPS vars setVar c NFSSERVER "$NFSSERVER"
	$PVOPS vars setVar c NFSPORT "$NFSPORT"
	$PVOPS vars setVar c NFSPATH "$NFSPATH"
	$PVOPS vars setVar c NFSFILESIZE "$NFSFILESIZE"
        $PVOPS vars setVar c CRYPTFILENAME "$CRYPTFILENAME"
    	;;
	
    	"samba" )
	$PVOPS vars setVar c SMBSERVER "$SMBSERVER"
	$PVOPS vars setVar c SMBPORT "$SMBPORT"
	$PVOPS vars setVar c SMBPATH "$SMBPATH"
	$PVOPS vars setVar c SMBUSER "$SMBUSER"
	$PVOPS vars setVar c SMBPWD "$SMBPWD"
	$PVOPS vars setVar c SMBFILESIZE "$SMBFILESIZE"
        $PVOPS vars setVar c CRYPTFILENAME "$CRYPTFILENAME"
    	;;
	
    	"iscsi" )
	$PVOPS vars setVar c ISCSISERVER "$ISCSISERVER"
	$PVOPS vars setVar c ISCSIPORT "$ISCSIPORT"
	$PVOPS vars setVar c ISCSITARGET "$ISCSITARGET"
    	;;
	
    	"file" )
	$PVOPS vars setVar c FILEPATH "$FILEPATH"
	$PVOPS vars setVar c FILEFILESIZE "$FILEFILESIZE"
        $PVOPS vars setVar c CRYPTFILENAME "$CRYPTFILENAME"
    	;;
	
    esac

    $PVOPS vars setVar c USINGSSHBAK "$USINGSSHBAK"
    
    if [ "$USINGSSHBAK" -eq 1 ] ; then
	$PVOPS vars setVar c SSHBAKSERVER "$SSHBAKSERVER"
	$PVOPS vars setVar c SSHBAKPORT "$SSHBAKPORT"
	$PVOPS vars setVar c SSHBAKUSER "$SSHBAKUSER"
	$PVOPS vars setVar c SSHBAKPASSWD "$SSHBAKPASSWD"
    fi


    $PVOPS vars setVar c SHARES "$SHARES"
    $PVOPS vars setVar c THRESHOLD "$THRESHOLD"
}

