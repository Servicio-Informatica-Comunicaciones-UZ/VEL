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
    detectUsbExtraction $USBDEV $"USB device successfully read. Remove it and press RETURN." $"Didn't remove it. Please, do it and press RETURN."
    
    return 0
}




#Grant admin user a privileged admin status on the web app
#1-> 'grant' or 'remove'
grantAdminPrivileges () {
    echo "Setting web app privileged admin status to: $1"  >>$LOGFILE 2>>$LOGFILE
	   $PVOPS  grantAdminPrivileges "$1"	
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









#Retorno 0 -> ok 1 -> Error
#        retrievedKey -> Llave reconstruida.  #////++++ Ya no. Los sitios que se use, pasarlos a PRIV.
retrieveKeywithAllCombs () {


        $PVOPS storops rebuildKeyAllCombs 2>>$LOGFILE  #0 ok  1 bad pwd  #////probar
	local ret=$?
	
	[ "$ret" -eq 10 ] && systemPanic $"Error interno. Faltan datos de configuración para realizar la resconstrucción."
    
	[ "$ret" -eq 11 ] && systemPanic $"No se puede reconstruir la llave. No hay suficientes piezas."
	
	return $ret
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



#Obtención de params




        
    #PARÁMETROS DE ACCESO A INTERNET
    
    # $1 -> reset params (0) or keep previous values (1)
    networkParams () {



      selectIPMode () {
       	exec 4>&1 
	choice=""
	while [ "$choice" == "" ]
	  do
	  choice=$($dlg --no-cancel   --radiolist  $"Configuración de acceso a Internet" 0 0 2  \
	      1 $"Automatica por DHCP" "${ipmodeArr[1]}"  \
	      2 $"Manual" "${ipmodeArr[2]}"  \
	      2>&1 >&4 )
	

	  for i in 1 2
	    do
	    ipmodeArr["$i"]="off"
	    [ "$i" -eq "$choice" ]  &&  ipmodeArr[$i]="on"
	  done
	  
          #echo "Retorno del radio: "$choice
	  IPMODE="dhcp"
	  if [ "$choice" -eq 2 ] 
	      then
	      
	      IPMODE="static"
	      
	      selectIPParams
	      
	      [ "$?" -eq '2' ] && choice="" && continue
	  fi
	  	  
	#Salimos y seguimos con la config	  
	done
	
      }
    
      selectIPParams () {
	
	choice=""
	while [ "$choice" == "" ]
	  do
	  
	  
	  #Mostrar el form de config de conexión
	  #	      $"Modo"                      0  0 "Manual" 1  30  17 15 0  \      
	  formlen=7

	  choice=$($dlg  --cancel-label $"Atrás"  --mixedform  $"Parámetros de acceso a Internet" 0 0 20  \
	      $"Campo"                     1  1 $"Valor"             1  30  17 15   2  \
	      $"Dirección IP"              3  1 "${ipconfArr[1]}"    3  30  17 15   0  \
	      $"Máscara de Red"            5  1 "${ipconfArr[2]}"    5  30  17 15   0  \
	      $"Puerta de Enlace"          7  1 "${ipconfArr[3]}"    7  30  17 15   0  \
	      $"DNS Primario"              10 1 "${ipconfArr[4]}"    10 30  17 15   0  \
	      $"DNS Secundario"            12 1 "${ipconfArr[5]}"    12 30  17 15   0  \
	      $"Nombre del host (FQDN)"    15 1 "${ipconfArr[6]}"    15 30  17 4096 0  \
	      2>&1 >&4 )
	  

	  #echo "RETORNO: $choice"
	  #Recordar: si se pulsa cancelar, no se devuelve ningún valor introducido, por lo que no pueden recordarse los params
	  
	  c=0
	  for i in $choice
	    do
	    ipconfArr[$c]="$i"
	    c=$(($c +1))
	  done
	    

	  [ "$choice" == "" ] && return 2; # retornamos al proceso padre indicando 'back'
	  
	  
          #Procesamos el retorno. Verificando cada campo y su estructura.
 

    
          #Se esperan 6 campos. Tomaremos los primeros 6 que entren (se separa por espacios)
	  #Como pongo un campo para diferenciar el cancel del empty, ignoramos el campo 0
	  len=0
	  again=0
	  for i in $choice
	    do
    
	    
	    #echo "entra. i:"$i" len:"$len
    
	    case "$len" in 
		
		
		"1" )
		#En la 1ª iter, viene la IP
		parseInput ipaddr "$i"
		ret=$?
		
		IPADDR="$i"

		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. La dirección IP no es válida" 0 0
		    again=$(($again | 1));
		fi
		;;
		
		"2" )
                #Se espera la Mask
                parseInput ipaddr "$i"
		ret=$?
		
		MASK="$i"
		
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. La máscara de red no es válida" 0 0
		    again=$(($again | 1)); 
		fi
		;;
	
		"3" )
	        #Se espera la default gateway
		parseInput ipaddr "$i"
		ret=$?
		
		GATEWAY="$i"
		
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. La dirección de la puerta de enlace no es válida" 0 0
		    again=$(($again | 1));
		fi
		;;
	
		"4" )
   	        #Se espera el dns primario
		parseInput ipaddr "$i"
		ret=$?
		
		DNS1="$i"
		
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. La dirección del DNS primario no es válida" 0 0
		    again=$(($again | 1)); 
		fi
		;;
		
		"5" )
 	        #Se espera el dns secundario
		parseInput ipaddr "$i"
		ret=$?
		
		DNS2="$i"
		
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. La dirección del DNS secundario no es válida" 0 0
		    again=$(($again | 1)); 
		fi
		;;
	
		"6" )
		#Se espera el nombre del server
		parseInput dn "$i"
		ret=$?
		
		FQDN="$i"
		
		if [ $ret -ne 0 ]
		    then
		    $dlg --msgbox $"Error. El nombre del servidor no es válido" 0 0
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
	  
	  
	  #echo "salimos del bucle general? '$choice'"
	  
	done
	
	#echo "Retorno del form: "$choice
	

       } #SelectIPParams

       #Llamamos a ambas subfunciones
       selectIPMode


	#echo "IPMODE:   "$IPMODE
	
	#echo "IP:   "$IPADDR
	#echo "MASK: "$MASK
	#echo "GATE: "$GATEWAY
	#echo "DNS1: "$DNS1
	#echo "DNS2: "$DNS2
	#echo "FQDN: "$FQDN

     } #NetworkParams




     #PARÁMETROS DE ACCESO A LA PARTICIÓN CIFRADA   
     

     # $1 -> reset params (0) or keep previous values (1)
     selectCryptoDrivemode () {
	 
	 choice=""
	 while [ "$choice" == "" ]
	   do
	   choice=$($dlg --no-cancel   --radiolist  $"Ubicación de los datos cifrados." 0 60 13  \
	       1 $"Partición en disco local" "${crydrivemodeArr[1]}"                 \
	       2 $"A través de servidor NFS" "${crydrivemodeArr[2]}"    \
	       3 $"A través de servidor Samba" "${crydrivemodeArr[3]}"  \
	       4 $"A través de iSCSI" "${crydrivemodeArr[4]}"  \
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
              #Mostrar el form específico para partición Local 
	      DRIVEMODE="local" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      
              $dlg --yes-label $"Cancelar" --no-label $"Continuar"  --yesno $"A continuación se le instará a que seleccione una partición local.\nNótese que los datos contenidos serán totalmente destruidos.\n\n¿Desea continuar?" 0 0
	      
	      
	      #Cancelado
	      [ $? -eq 0 ] && choice='' && continue;
	      
	      listPartitions
	      
	      drive=$($dlg --cancel-label $"Cancelar"  --menu $"Seleccione una partición." 0 80 $(($NPARTS)) $PARTS 2>&1 >&4)
	      
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
		choice=$($dlg  --cancel-label $"Atrás"  --mixedform  $"Parámetros de acceso a la partición cifrada" 0 0 13  \
		    $"Campo"                        1  1 $"Valor"                   1  30  17 15   2  \
		    $"Servidor (IP/DN)"             3  1 "${nfsconfArr[1]}"         3  30  20  2048   0  \
		    $"Puerto"                       5  1 "${nfsconfArr[2]}"         5  30  20  6      0  \
		    $"Ruta de destino"              7  1 "${nfsconfArr[3]}"         7  30  20  2048   0  \
		    $"Tamaño del fichero (MB)"      9  1 "${nfsconfArr[4]}"         9  30  20  100    0  \
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
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre válido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${nfsconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un número de puerto válido" 0 0
			  again=$(($again | 1));
		      fi
		      ;;
		      		      		      
		      "3" )
		      parseInput path "${nfsconfArr[3]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una ruta válida. Los nombres de directorio pueden contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      		      
		      "4" )
		      parseInput int "${nfsconfArr[4]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un tamaño entero" 0 0
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
              #Mostrar El form específico para Samba
              formlen=7
	      DRIVEMODE="samba" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      choice=""
	      sambaconfArr[2]=$DEFSMBPORT
	      while [ "$choice" == "" ]
		do
		choice=$($dlg  --cancel-label $"Atrás"  --mixedform  $"Parámetros de acceso a la partición cifrada" 0 0 13  \
		    $"Campo"                     1  1 $"Valor"                1  30  17 15   2  \
		    $"Servidor (IP/DN)"          3  1 "${sambaconfArr[1]}"    3  30  30 2048 0  \
		    $"Puerto"                    5  1 "${sambaconfArr[2]}"    5  30  20  6   0  \
		    $"Nombre del recurso"        7  1 "${sambaconfArr[3]}"    7  30  30 2048 0  \
		    $"Usuario"                   10 1 "${sambaconfArr[4]}"    10 30  20 256  0  \
		    $"Contraseña"                12 1 "${sambaconfArr[5]}"    12 30  20 256  1  \
		    $"Tamaño del fichero (MB)"   14 1 "${sambaconfArr[6]}"    14 30  20 100  0  \
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
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre válido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${sambaconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un número de puerto válido" 0 0
			  again=$(($again | 1));
		      fi
		      ;;		      
		      
		      "3" )
		      parseInput path "${sambaconfArr[3]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir una ruta válida. Los nombres de los directorios pueden contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "4" )
		      parseInput user "${sambaconfArr[4]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. El nombre de usuario no es válido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "5" )
		      parseInput pwd "${sambaconfArr[5]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. La contraseña no es válida. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      	
		      "6" )
		      parseInput int "${sambaconfArr[6]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. El tamaño debe ser entero." 0 0
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
	      
              #Mostrar el form específico para iscsi #Pedir host y port: luego hacer discover o, si no hay un servidor, pedir a  mano
              formlen=3
	      DRIVEMODE="iscsi" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      choice=""
	      iscsiconfArr[2]=$DEFISCSIPORT
	      while [ "$choice" == "" ]
		do
		choice=$($dlg  --cancel-label $"Atrás"  --mixedform  $"Parámetros de acceso a la partición cifrada" 0 0 13  \
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
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre válido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${iscsiconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un número de puerto válido" 0 0
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

		    #Modificarlos según el target elegido.
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
		    $dlg --msgbox $"Error. Debe introducir un identificador de target válido" 0 0
		    continue
		fi
		
		break
	      done
	      
	      ;;


	      "5" )
              USINGSSHBAK="1"
	      
              #Mostrar el form específico para partición en un fs dentro de un fichero (loop)
	      DRIVEMODE="file" #Config de acceso a la part privada. 'local','iscsi','nfs','samba','file'
	      
	      
              $dlg --yes-label $"Cancelar" --no-label $"Continuar"  --yesno $"A continuación se le instará a seleccionar una partición local.\nEn su raíz se escribirá un fichero con los datos cifrados.\nEsta partición debe contener un sistema de ficheros válido." 0 0
	      

	      #Cancelado
	      [ "$?" -eq 0 ] && choice='' && continue;
	      

	      listPartitions "wfs"
	      if [ "$NPARTS" -gt 0 ]
		  then
		  drive=$($dlg --cancel-label $"Cancelar"  --menu $"Seleccione una partición." 0 80 $(($NPARTS)) $PARTS 2>&1 >&4)
		  
		  [ $? -ne 0 ]  && choice='' && continue;
	      
	      else
		  $dlg --msgbox $"No existen particiones válidas. Elija otro modo." 0 0
		  choice=''
		  continue
	      fi
	      
	      FILEPATH=$drive
	      

              formlen=2
	      choice=""
	      while [ "$choice" == "" ]
		do
		choice=$($dlg  --cancel-label $"Atrás"  --mixedform  $"Parámetros de acceso a la partición cifrada" 0 0 13  \
		    $"Campo"                    1  1 $"Valor"               1  30  17  15     2  \
		    $"Tamaño del fichero (MB)" 3  1 "${fileconfArr[1]}"    3  30  20  100    0  \
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
		    $dlg --msgbox $"Error. Debe introducir un tamaño de fichero entero positivo" 0 0
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



	#Permite elegir si se va a usar backup por SSH (Sólo lo pregunta si el modo es local)
	if [ "$USINGSSHBAK" -eq "1" ] ; then
	    
	    $dlg  --yes-label $"Sí" --no-label $"No" --yesno $"Como el modo de almacenamiento elegido se ubica dentro de esta misma máquina, se recomienda proporcionar algún mecanismo de copia de seguridad externo para evitar una pérdida irreparable de los datos. Esta copia se realizará sobre un servidor SSH a su elección, y los datos se almacenarán cifrados.\n\n¿Desea emplear un servidor SSH para la copia de seguridad?" 0 0
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
		    $dlg --msgbox $"Debe introducir los parámetros de copia de seguridad." 0 0
		    continue
		fi

		$dlg --infobox $"Verificando acceso al servidor de copia de seguridad..." 0 0

		#Añadimos las llaves del servidor SSH al known_hosts		 
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
	
	
# part cifrada: localización( disco_local/nfs/samba/iscsi/loop_fichero)?                                    
#  local: --> ruta de la partición (sel.)
#    nfs: --> ip/dn  ruta tamaño   # ip:ruta
#  samba: --> ip/dn ruta , user, pwd, tamaño
#  iscsi: --> ip/dn del target, nombre_target
#fichero: --> ruta de la partición en que se almacenará al fichero, tamaño


	done

	#Generamos los parámetros no interactivos.
       
        #Establecemos el nombre del fichero de loopback (necesariamente único), siempre en la raiz
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
    

#////En principio, cada ciclo del menú de mant será un proceso distino (el anterior morirá), por lo que las variables deberían quedar liberadas.





selectDataBackupParams () {

	formlen=5
	choice=""
	backupconfArr[2]=$DEFSSHPORT
	while [ "$choice" == "" ]
	  do
	  choice=$($dlg  --no-cancel  --mixedform  $"Parámetros para realización de copias de seguridad sobre un servidor SSH." 0 0 13  \
		    $"Campo"                     1  1 $"Valor"                1  30  17 15   2  \
		    $"Servidor SSH (IP/DN)"      3  1 "${backupconfArr[1]}"   3  30  30 2048 0  \
		    $"Puerto"                    5  1 "${backupconfArr[2]}"   5  30  20  6   0  \
		    $"Usuario"                   7  1 "${backupconfArr[3]}"   7  30  20 256  0  \
		    $"Contraseña"                9  1 "${backupconfArr[4]}"   9  30  20 256  1  \
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
			  $dlg --msgbox $"Error. Debe introducir una IP o nombre válido" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "2" )
		      parseInput port "${backupconfArr[2]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. Debe introducir un número de puerto válido" 0 0
			  again=$(($again | 1));
		      fi
		      ;;		      
		      
		      "3" )
		      parseInput user "${backupconfArr[3]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. El nombre de usuario no es válido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
			  again=$(($again | 1)); 
		      fi
		      ;;
		      
		      "4" )
		      parseInput pwd "${backupconfArr[4]}"
		      ret=$?
		      if [ $ret -ne 0 ]
			  then
			  $dlg --msgbox $"Error. La contraseña no es válida. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
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
  
    FQDN=$($PVOPS vars getVar c FQDN) #////probar
    SITESCOUNTRY=$($PVOPS vars getVar d SITESCOUNTRY) 
    SITESORGSERV=$($PVOPS vars getVar d SITESORGSERV)
    SITESEMAIL=$($PVOPS vars getVar d SITESEMAIL)

    [ "$FQDN" != "" ] && SERVERCN="$FQDN"
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




# $1 --> Modo wfs 'sólo parts con FS válido', (nada) --> Todas las particiones
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
    #en el modo con fs, nunca listará los devs que formen parte de raids, al no poder montarlos, 
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
          ### sector que usa el kernel. El kernel usa como tamaño mínimo
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






#$1 -> Lista de targets host:port,1 tarid ## etc. (ojo, cada elem ocupa 2 items de la lista)
#Ret: TARS -> lista de targets (pares "target -")
#     NTAR -> long de la lista
listTargets () {

    TARS=''
    NTAR=0
    
    istarid=0
    entry=""
    for tar in $1
      do

      if [ $istarid -eq 0 ]
	  then
	  ip=$(echo $tar | grep -oEe "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
	  port=$(echo $tar | grep -oEe ":[0-9]+," | grep -oEe "[0-9]+")
	  entry="($ip:$port)-"
      else
	  entry="$entry$tar"
	  TARS=$TARS" $entry -"
	  NTAR=$(($NTAR+1))
      fi
      
      istarid=$(( ($istarid+1)%2 ))
    done
    
    return 0
}





# $1 -> '': salta a systemPanic si no consigue conectividad   'noPanic': devuelve 1 y sale si no consigue conectividad
configureNetwork () {
    
    echo "wizard-common.sh:   $PVOPS configureNetwork $1 $DOFORMAT $IPMODE $IPADDR $MASK $GATEWAY $DNS1 $DNS2 $FQDN " >>$LOGFILE 2>>$LOGFILE
    
    $dlg --infobox $"Configurando la red..." 0 0
    
    #En reset estos parámetros estarán vacíos, pero en la op privada ya lo he contemplado.
    $PVOPS configureNetwork "$1" "$DOFORMAT"  "$IPMODE" "$IPADDR" "$MASK" "$GATEWAY" "$DNS1" "$DNS2" "$FQDN" 
    local cfretval="$?"

    #En caso de error
    local errMsg=""
    if [ "$cfretval" == "11"  ]; then
	errMsg=$"Error: no se encuentran interfaces ethernet accesibles." 
    fi
    if [ "$cfretval" == "12"  ]; then
	errMsg=$"Error: no se pudo comunicar con la puerta de enlace. Revise conectividad." 
    fi
    if [ "$cfretval" == "13"  ]; then
	errMsg=$"Error: no se pudo obtener la configuración IP. Revise conectividad."
    fi
    if [ "$errMsg" != ""  ]; then
	if [ "$1" == "noPanic"  ]; then
	    $dlg --msgbox "$errMsg" 0 0
	    return 1
	else
	    systemPanic "$errMsg"
	    return 1
	fi
    fi

    #No podemos deducir el FQDN. Hay que pedirlo explícitamente
    if [ "$cfretval" == "42"  ]; then
	
	
	while true ; do
	    
	    FQDN=$($dlg --no-cancel  --inputbox  \
		$"No se ha podido deducir el nombre de dominio del servidor.\nEspecifique uno:" 0 0 "$FQDN"  2>&1 >&4)
	    
	    parseInput dn "$FQDN"
	    if [ $? -ne 0 ] 
		then
		$dlg --msgbox $"Debe introducir un nombre de dominio válido." 0 0
		continue
	    fi
	    
	    break
	done
	
	#Guardamos la variable
	$PVOPS vars setVar c FQDN "$FQDN"
    fi    

    #Configuramos lo que falta, en relación al FQDN.
    $PVOPS configureNetwork2

}











#Pasa las variables de configuración empleadas en este caso a una cadena separada por saltos de linea para volcarlo a un clauer
setConfigVars () {
    
    $PVOPS vars setVar c IPMODE $IPMODE
    
    if [ "$IPMODE" == "static"  ] #si es 'dhcp' no hacen falta
	then
	$PVOPS vars setVar c IPADDR "$IPADDR"
	$PVOPS vars setVar c MASK "$MASK"
	$PVOPS vars setVar c GATEWAY "$GATEWAY"
	$PVOPS vars setVar c DNS1 "$DNS1"
	$PVOPS vars setVar c DNS2 "$DNS2"
	$PVOPS vars setVar c FQDN "$FQDN"
    fi
    
    if [ "$FQDN" != ""  ]
	then
	$PVOPS vars setVar c FQDN "$FQDN"
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

