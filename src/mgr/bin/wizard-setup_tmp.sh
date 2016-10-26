#!/bin/bash


##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh

#Terminal is being set to dumb, although we change it on the
#bootstrapper. We need to set it here as well to allow for curses to
#work
export TERM=linux



###############
#  Constants  #
###############



#Determines if an action on the idle menu doesn't need authorization by key reuilding  
BYPASSAUTHORIZATION=0 ### TODO Esta variable debe desaparecer. El control de autorización  pasa por completo al prog priv.




######################
#  Global Variables  #
######################


#Current config file accepted as in use (in case of mismatch) # TODO quitar este asco de variable. Cuando elija la config, renombrar a un nombre genérico e ignorar el resto
CURRINUSE=0

SETAPPADMINPRIVILEGES=''



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

    #Offer emergency administration choices
    exec 4>&1 
    selec=$($dlg --no-cancel  --menu $"Select an option." 0 0  3  \
	                1 $"Shutdown system." \
	                2 $"Reboot system." \
	                3 $"Launch an administration terminal." \
	                2>&1 >&4)
    
    case "$selec" in
	       
	       "1" )
            #Shutdown
            shutdownServer "h"
	           ;;

	       "2" )
	           #Reboot
            shutdownServer "r"
            ;;
	       
	       "3" )
            #Launch a root terminal (with a disclaimer for the overseers)
	           $dlg --yes-label $"Yes" --no-label $"No"  --yesno  $"WARNING: This action may allow the user access to sensitive data until it is rebooted. Make sure it is not operated without supervision from a qualified overseer. ¿Do you wish to continue?." 0 0
	           [ "$?" -eq 0 ] && exec $PVOPS rootShell
            ;;	
	       * )
	           echo "systemPanic: Bad selection"  >>$LOGFILE 2>>$LOGFILE
	           $dlg --msgbox "BAD SELECTION" 0 0
	           shutdownServer "h"
	           ;;
	   esac
    
    shutdownServer "h"
}





#Main setup menu  # TODO: now show before anything, recovery is not dependent on usb config (later will need thekey, but just as when starting. Add here setup entry)
choosemaintenanceAction () {
    
    exec 4>&1 
    selec=$($dlg --no-cancel  --menu $"Select an action:" 0 80  6  \
	                1 $"Start voting system." \
                 2 $"Setup new voting system." \
	                3 $"Recover a voting system backup." \
	                4 $"Launch administrator terminal." \
	                5 $"Shutdown computer." \
	                2>&1 >&4)
    
    while true; do
        case "$selec" in
	           "1" )
                DOBUILDKEY=1
	               return 1
                ;;
            
	           "2" )
                DOBUILDKEY=0 #TODO maybe, instead of raise phase flags, implemenmt as functions and return operation number and implement different pipelines?
	               DOFORMAT=1
	               return 2
                ;;
            
            "3" )
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




#SEGUIR


# $1 -> Parte 1 del mensaje de confirmación.

confirmSystemFormat (){
    
    $dlg --no-label $"Inicio"  --yes-label $"Formatear" --yesno  $"$1\nEsto implica que, o el sistema esta vacio, o desea reinstalarlo. \nSi elige continuar, se destruirán todos los datos\n del sistema si los hubiese y se instalará\nel sistema de voto totalmente de cero. \n\n¿Desea continuar o desea volver al inicio?" 0 0
    button=$?

    #echo "Pulsado $button"

    #Desea insertar otro disp.
    if [ $button -eq 1 ]
	then
	DOFORMAT=0  
	return
    fi
	
    #Doble confirmación
    $dlg   --yes-label $"Sí" --no-label $"No" --yesno  $"¿Seguro que desea continuar?" 0 0  
    button=$?
    
    #echo "Pulsado $button"

    #Desea insertar otro disp.
    if [ $button -eq 1 ] 
	then
	DOFORMAT=0
	return
    fi
    
    DOFORMAT=1
    return
}


#//// revisar todas las func que quedan: ver si van a commons o deben convertirse en ops priv o privsetup+++






#////  este probablemente deba ponerlo como root, pero ver si no es necesario. En todo caso, filtrar los params a lo bestia. Que el dev sólo pueda ser /dev/sd[a-z][0-9]* o algo asi (verificar), limitar el tamaño del pwd..





# //// Verificar que la pwd de DB del usuario no se escirbe en vars.conf en ningún caso, y solo se usa en el setup.
# //// Sacar el pwd del ssh backup de vars.conf
# //// Sacar el pwd de la part de /root (o al menos quitarle los permisos de lectura a g y o.)

#////Revisar los restos del setup y las ops del standby en /tmp, /root, /home/vtuji y /media/cryptStorage.










##### Parámetros del admin del sistema #####


sysadminParams () {


    $dlg --msgbox $"Vamos a definir los datos de acceso como administrador al programa Web de gestión del sistema de voto. Deberá recordarlos para poder acceder en el futuro.\n\nRecuerde que el acceso a las funciones de administración privilegiadas sólo podrá llevarse a cabo previa autorización de la comisión de custodia por medio de esta aplicación." 0 0
    
    MGRPWD=""
    MGREMAIL=""
    ADMINNAME=""
    ADMREALNAME=""
    ADMIDNUM=""
    verified=0
    while [ "$verified" -eq 0 ]
      do
      
      verified=1


      ADMINNAME=$($dlg --no-cancel  --inputbox  \
	  $"Nombre de usuario del administrador del sistema de voto." 0 0 "$ADMINNAME"  2>&1 >&4)
      
      if [ "$ADMINNAME" == "" ] 
	  then
	  verified=0 
	  $dlg --msgbox $"Debe proporcionar un nombre de usuario." 0 0 
	  continue
      fi
      
      parseInput user "$ADMINNAME"
      if [ $? -ne 0 ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe introducir un nombre de usuario válido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
	  continue
      fi


      getPwd '' 1 $"Introduzca la contraseña para\nel administrador del sistema de voto.\nEs imprescindible que la recuerde." 1
      MGRPWD="$pwd"
      pwd=''
      

      ADMREALNAME=$($dlg --no-cancel  --inputbox  \
	  $"Nombre completo del administrador del sistema de voto." 0 0 "$ADMREALNAME"  2>&1 >&4)
      
      if [ "$ADMREALNAME" == "" ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe proporcionar un nombre." 0 0
	  continue
      fi
      
      
      parseInput freetext "$ADMREALNAME"
      if [ $? -ne 0 ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe introducir un nombre válido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
	  continue
      fi




      ADMIDNUM=$($dlg --no-cancel  --inputbox  \
	  $"DNI del administrador del sistema de voto." 0 0 "$ADMIDNUM"  2>&1 >&4)
      
      if [ "$ADMIDNUM" == "" ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe proporcionar un DNI." 0 0
	  continue
      fi
      
      parseInput dni "$ADMIDNUM"
      if [ $? -ne 0 ] 
	  then
	  verified=0 
	  $dlg --msgbox $"Debe introducir un numero de DNI válido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0 
	  continue
      fi
      



      MGREMAIL=$($dlg --no-cancel  --inputbox  \
	  $"Correo electrónico del administrador del sistema de voto.\nSe empleará para notificar incidencias del sistema." 0 0 "$MGREMAIL"  2>&1 >&4)
      
      if [ "$MGREMAIL" == "" ] 
	  then
	  verified=0 
	  $dlg --msgbox $"Debe proporcionar un correo electrónico." 0 0 
	  continue
      fi
      
      parseInput email "$MGREMAIL"
      if [ $? -ne 0 ] 
	  then 
	  verified=0
	  $dlg --msgbox $"Debe introducir una dirección de correo válida." 0 0
	  continue
      fi
      





	  #Selector de tamaño de llave
      KEYSIZE=""
      exec 4>&1 
      KEYSIZE=$($dlg --no-cancel  --menu $"Seleccione un tamaño para las llaves del sistema\n(a mayor valor, más robustez, pero más coste computacional):" 0 80  5  \
	  1024 - \
	  1152 - \
	  1280 - \
	  2>&1 >&4)
      [ "$?" -ne 0 ]       && KEYSIZE="1024"
      [ "$KEYSIZE" == "" ] && KEYSIZE="1024"
      
      echo "keysize: $KEYSIZE"   >>$LOGFILE 2>>$LOGFILE
      

      if [ "$verified" -eq 1 ] 
	  then
	  $dlg --yes-label $"Revisar"  --no-label $"Continuar"  --yesno \
	      $"Datos adquiridos. ¿Desea revisarlos o desea continuar con la configuración del sistema?" 0 0 
	  verified=$?
      fi
      
    done



}


##### Datos de registro en eSurveySites #####


esurveyParamsAndRequest () {


	    $dlg --msgbox $"Vamos a definir los datos para registrar el sistema como miembro válido de la red eSurvey. Si ya está registrado como usuario de eSurveySites, introduzca los datos correctos. Si no, puede crear una nueva cuenta ahora introduciendo los datos deseados." 0 0
	    
	    SITESEMAIL=''
	    SITESPWD=''
	    SITESORGSERV=''
	    SITESNAMEPURP=''
	    SITESCOUNTRY=''
	    
	#Proponemos como email el mismo que para admin la aplic.
	    SITESEMAIL="$MGREMAIL"
	    

	    verified=0
	    while [ "$verified" -eq 0 ]
	      do
	      verified=1
	      
	      
	      
	      SITESEMAIL=$($dlg --no-cancel  --inputbox  \
		  $"Correo electrónico, identificador de usuario para eSurveySites." 0 0 "$SITESEMAIL"  2>&1 >&4)
	      
	      if [ "$SITESEMAIL" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar una dirección de correo." 0 0
		  continue
	      fi
	      
	      parseInput email "$SITESEMAIL"
	      if [ $? -ne 0 ] 
		  then
		  verified=0 
		  $dlg --msgbox $"Debe introducir una dirección de correo válida." 0 0
		  continue
	      fi
	      
	      

	  #yesno: auto-generar password (que recibirá en el correo) o especificarlo
	      $dlg --yes-label $"Especificar"  --no-label $"Generar"  --yesno \
		  $"Desea especificar una contraseña para eSurveySites (si ya posee una cuenta elija 'especificar') o prefiere que se genere automáticamente (la recibirá en su correo)?" 0 0 
	      generatePWD=$?
	      
	      
	      if [ "$generatePWD" -eq 0 ]
		  then
	      # Pide la contraseña
		  getPwd '' 1 $"Contraseña de acceso a eSurveySites.\nSi ya posee una cuenta, escriba la contraseña." 1
		  SITESPWD="$pwd"
		  pwd=''
	      else
	      #Lo auto-genera
		  randomPassword 10
		  SITESPWD=$pw
		  pw=''
	      fi
	      
	      
	      
	      SITESORGSERV=$($dlg --no-cancel  --inputbox  \
		  $"Nombre de su organización o del servidor." 0 0 "$SITESORGSERV"  2>&1 >&4)
	      
	      if [ "$SITESORGSERV" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar un nombre." 0 0
		  continue
	      fi
	      
	      parseInput freetext "$SITESORGSERV"
	      if [ $? -ne 0 ] 
		  then 
		  verified=0 
		  $dlg --msgbox $"Debe introducir un nombre válido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
		  continue
	      fi
	      


	      SITESNAMEPURP=$($dlg --no-cancel  --inputbox  \
		  $"Nombre o propósito del sistema de voto." 0 0 "$SITESNAMEPURP"  2>&1 >&4)
	      
	      if [ "$SITESNAMEPURP" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar un nombre." 0 0
		  continue
	      fi
	      
	      parseInput freetext "$SITESNAMEPURP"
	      if [ $? -ne 0 ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe introducir un nombre válido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
		  continue
	      fi
	      

	      
	      SITESCOUNTRY=$($dlg --no-cancel  --inputbox  \
		  $"País en que se ubica su organización o su servidor (2 letras)." 0 0 "$SITESCOUNTRY"  2>&1 >&4)
	      
	      if [ "$SITESCOUNTRY" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar un código de país de 2 letras." 0 0
		  continue
	      fi
	      
	      parseInput cc "$SITESCOUNTRY"
	      if [ $? -ne 0 ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe introducir un código válido." 0 0 
		  continue
	      fi
	      


	      if [ "$verified" -eq 1 ] 
		  then
		  $dlg --yes-label $"Revisar"  --no-label $"Continuar"  --yesno \
		      $"Datos adquiridos. ¿Desea revisarlos o desea continuar con la configuración del sistema?" 0 0 
		  verified=$?
		  [ "$verified" -eq 0 ] && continue
	      fi
	      
	      
	      
	      
          ### Generamos los certificados de firma del servidor de voto ###
	      $dlg --infobox $"Generando certificado para eSurveySites..." 0 0
	      
	      par=$(openssl req -x509 -newkey rsa:$KEYSIZE -keyout /dev/stdout -nodes -days 3650 \
		  -subj "/C=$SITESCOUNTRY/O=$SITESORGSERV/CN=$SITESNAMEPURP/emailAddress=$SITESEMAIL" 2>>$LOGFILE) 
	      
	      [ "$par" == "" ] &&  systemPanic $"Error grave: no se pudo generar el certificado de sites."
	      
	      keyyS=$(echo "$par" | sed -n -e "/PRIVATE/,/PRIVATE/p");
	      certS=$(echo "$par" | sed -n -e "/CERTIFICATE/,/CERTIFICATE/p")
	      
	      
	      
  	  ### Generamos una pet de certificado (en urlencoded) a partir del certificado ###
	  #Importante las comillas en el echo que permiten pasar todo el contenido como un solo arg. 
	      expS=$(echo -n "$keyyS" | openssl rsa -text 2>/dev/null | sed -n -e "s/^publicExponent.*(0x\(.*\))/\1/p" | hex2b64)
	      modS=$(echo -n "$keyyS" | openssl rsa -text 2>/dev/null | sed -e "1,/^modulus/ d" -e "/^publicExponent/,$ d" | tr -c -d 'a-f0-9' | sed -e "s/^00//" | hex2b64)
	      
	  #urlencode en Sed: Define la etiqueta a, lee la siguiente línea y para ella sustituye = por %3D, etc. y salta a 'a' de nuevo.
	      req=$(echo "$certS" >/tmp/crt$$; echo "$keyyS" |
		  openssl x509 -signkey /dev/stdin -in /tmp/crt$$ -x509toreq 2>>$LOGFILE | sed -n -e "/BEGIN/,/END/p" |
		  sed -e :a -e N -e 's/\//%2F/g;s/=/%3D/g;s/+/%2B/g;s/\n/%0A/;ta' ; rm /tmp/crt$$);
	      
	      
	      
          #conexion con sites
	      $dlg --infobox $"Conectando con eSurveySites..." 0 0
	      
	      
	  #Urlencode del mail y el pwd:
	      mail=$($urlenc "$SITESEMAIL" 2>>$LOGFILE)
	      pwd=$($urlenc "$SITESPWD" 2>>$LOGFILE)
	      
	  #El param once provoca que la cuenta no pueda usarse tras el registro (para evitar un DoS el dia de la elección)
	      result=$(wget  -O - -o /dev/null "http://esurvey.nisu.org/sites?mailR=$mail&pwdR=$pwd&req=$req&lg=es&once=1")

	      echo "Respuesta de sites: $result"   >>$LOGFILE 2>>$LOGFILE

	      if [ "$result" == "" ] 
		  then
		  $dlg --msgbox $"Error conectando con eSurveySites." 0 0  
		  verified=0 
		  continue
	      fi
	      
	      linenum=1
	      err=0
	      for line in $(echo "$result")
		do 
		
		case "$linenum" in
		  "1" ) #Línea de Estado
                    if [ "$line" == "ERR" ] 
			then
			$dlg --msgbox $"Error al entregar la solicitud de certificado en eSurveySites. Tal vez la dirección de correo ya pertenece a una cuenta registrada." 0 0
			err=1 
			verified=0 
			break
		    fi
		    if [ "$line" == "REG" ] 
			then
			$dlg --msgbox $"Error al entregar la solicitud de certificado en eSurveySites. Tal vez la dirección de correo ya pertenece a una cuenta registrada." 0 0
			err=1
			verified=0
			break
		    fi
		    if [ "$line" == "DUP" ] 
			then
			$dlg --msgbox $"Error: ya existe una solicitud en eSurveySites con estos datos. Modifíquelos." 0 0
			err=1
			verified=0
			break
		    fi
		    if [ "$line" != "OK" ] 
			then
			$dlg --msgbox $"Error conectando con eSurveySites." 0 0
			err=1
			verified=0
			break
		    fi
		  ;;

		  "2" ) #ERR,DUP->Mensaje de estado OK-> exponente en b64 
		    [ "$expS" != "$line" ] &&   systemPanic $"Error en eSurveySites: diferencias entre los datos enviados y los devueltos por el servidor." 
		  ;;
		
		  "3" ) #OK-> Mod en B64
		    [ "$modS" != "$line" ] &&   systemPanic $"Error en eSurveySites: diferencias entre los datos enviados y los devueltos por el servidor." 
		  ;;
		
		  "4" ) #OK-> Token de la petición de firma
		    SITESTOKEN="$line"
		  ;;	
		esac

	        #echo "$linenum-->"$line

		linenum=$(($linenum+1))

		[ $err -eq 1 ] && break
	      done
	      #Esto lo pongo como guarda por si añado código debajo de esto
	      [ $verified -eq 0 ] && continue

	    done  #Fin de entrada de datos de admin, cert y petición de cert

	    #echo "valor de tkD devuelto: $SITESTOKEN"   >>$LOGFILE 2>>$LOGFILE


}







##### Configuración principal del sistema #####


#1 -> 'new' or 'reset'
doSystemConfiguration (){


# TODO This is what should be done on a new install to setup timezonem, and also on loading. See how we organize process below and include this in both processes. Ensure it is done after config file from usbs is settled when reloading.

if [ "$DOFORMAT" -eq 1 ] 
then 
    selectTimezone #Will set the global var TIMEZONE
fi

$PSETUP setupTimezone "$TIMEZONE" #When reloading, timezone will be empty, thus triggering the read from config
    

    #Si estamos creando el sistema, la red se habrá configurado durante el setup
    if [ "$1" == 'reset' ]
        then
        configureNetwork 'Panic'
    fi

	
    #Abrimos o creamos la zona segura de datos.
    configureCryptoPartition "$1"
    #En $CRYPTDEV está el dev empleado, para desmontarlo  # TODO cambiar este retorno, ahora no es una global. De hecho, quitar y mantener en la parte priv, en una var de ram si hace falta


    
    #Si se está ejecutando una restauración
    if [ "$DORESTORE" -eq 1 ] ; then #////probar
	
	while true; do 
	    
	    $dlg --msgbox $"Prepare ahora los Clauers del sistema anterior. Vamos a recuperar los datos." 0 0

            #La llave y la config a restaurar las metemos en el slot 2
	    $PVOPS clops switchSlot 2

	   

            #Pedir Clauers con la config y rebuild key
	    getClauersRebuildKey  b
	    ret=$?

	    if [ $ret -ne 0 ] 
		then 
		$dlg --msgbox $"Error durante la recuperación del backup. Vuelva a intentarlo." 0 0 
		continue
	    fi


	    #Recuperamos el fichero y lo desciframos
	    $PSETUP recoverSSHBackup_phase1 
	    if [ $? -ne 0 ] 
		then
		$dlg --msgbox $"Error durante la recuperación del backup. Vuelva a intentarlo." 0 0
		continue
	    fi
	    
	
	    #Volvemos al Slot de la instalación nueva (sobre la que estamso restaurando la vieja)
	    $PVOPS clops switchSlot 1


	    break
	done


    fi
    

    #Leemos variables de configuración que necesitamos aquí (si es new, 
    #ya están definidas, si es reset, se redefinen y no pasa nada)
    WWWMODE=$($PVOPS vars getVar d WWWMODE)
    USINGSSHBAK=$($PVOPS vars getVar c USINGSSHBAK)

    #Si hay backup de los datos locales
    if [ "$USINGSSHBAK" -eq 1  ] ; then
	if [ "$1" == "new"  ] ; then  #*-*-en restore estos valen los nuevos. restaurar el vars original y que los machaque aquí?
	    #Escribimos en un fichero los params que necesita el script del cron 
	    #(sólo al instalar, porque luego pueden ser modificados desde el menú idle)
	    #(en realidad no importa, porque al cambiarlos reescribe los clauers)
	    $PVOPS vars setVar d SSHBAKSERVER "$SSHBAKSERVER"
	    $PVOPS vars setVar d SSHBAKPORT   "$SSHBAKPORT"
	    $PVOPS vars setVar d SSHBAKUSER   "$SSHBAKUSER"
	    $PVOPS vars setVar d SSHBAKPASSWD "$SSHBAKPASSWD"
	fi
    fi

    # Una vez montada la partición cifrada, sea new o reset (en este caso, ya habrá leido las vars del disco) o restore (ya habrá copiado los datos correspondientes)
    relocateLogs "$1"

    #////Si he de hacer algún cambio a la part cifrada, llamarlo aquí si es una op aislada. creo que en la de configurecryptopart ya hago los cambios correspondientes -> COMPROBAR Y BORRAR
    
    
    
    #Solo verificamos las piezas si es un reset, no si es nuevo servidor
    if [ "$1" == 'reset' ]
	then

        #Verificamos las piezas de la llave, pero sólo con fin informativo, no obligamos a cambiarla ya.
	$dlg --infobox $"Verificando piezas de la llave..." 0 0

	testForDeadShares 
	res=$?
	
        #Si no todas las piezas son correctas, solicitamos regeneración.
	if [ "$res" -ne "0" ];  then
	    $dlg --msgbox $"Se detectaron piezas corruptas.\n\nPara evitar una pérdida de datos, debería reunirse la comisión al completo en el menor tiempo posible y proceder a cambiar la llave." 0 0 
	fi	
    fi

    

    #Lanzamos los servicios del sistema (y acabamos la configuración de la instalación)
    configureServers "$1" 


    if [ "$DORESTORE" -eq 1 ] ; then

	$PSETUP recoverSSHBackup_phase2
	
    fi


    #Si estamos em modo de disco local, ponemos en marcha el proceso cron de backup cada minuto
    if [ "$USINGSSHBAK" -eq 1  ] ; then

	if [ "$1" == 'reset' ] ; then
	    
	    SSHBAKSERVER=$($PVOPS vars getVar d SSHBAKSERVER)
	    SSHBAKPORT=$($PVOPS vars getVar d SSHBAKPORT)

	    #Añadimos las llaves del servidor SSH al known_hosts
	    local ret=$($PVOPS sshKeyscan "$SSHBAKPORT" "$SSHBAKSERVER")
	    if [ "$ret" -ne 0 ]  #//// PRobar!!
		then
		systemPanic $"Error configurando el acceso al servidor de copia de seguridad."
	    fi
	fi
	
	$PSETUP enableBackup	    
	
    fi
    
    
    
    #Lanzamos el sistema de recogida de estadísticas en RRDs
    if [ "$1" == "new"  ] ; then
	#Construye las RRD
	$PVOPS stats startLog 
    fi
    
    #Creamos el cron que actualiza los resultados y genera las gráficas
    $PVOPS stats installCron
    
    #Actualizamos los gráficos al inicio (vacíos en la creación, no vacíos en el reboot)
    $PVOPS stats updateGraphs  >>$LOGFILE 2>>$LOGFILE
    

    #Escribimos el alias que permite que
    #se envien los emails de emergencia del smart y demás
    #servicios al correo del administrador
    
    $PSETUP setupNotificationMails

    
    #Realizamos los ajustes finales
    $PSETUP 4
        

    $dlg --msgbox $"Sistema iniciado correctamente y a la espera." 0 0
    

}  #end doSystemConfiguration





#1 -> 'new' or 'reset'
configureServers () {




    ######### Activación del servidor postfix ##########
    $dlg --infobox $"Configurando servidor de correo..." 0 0

    if [ "$1" == 'new' ]
	then :
	
        #Guardamos las variables d econfiguración correspondientes (esta la pido 
        #al principio pero no se necesita hasta ahora. Además ahora la guardo 
        #sólo en disco, y no tb en el clauer)
	$PVOPS vars setVar d MAILRELAY "$MAILRELAY"
    fi
    
    
    $PVOPS configureServers mailServer
    
    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de correo." f
    



    
    ######### Solicitar datos del administrador del sistema ######### 

    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ]
	    then :
	    
	    #Pedimos los parámetros del sysadmin
	    sysadminParams

            #Ahora el pwd se guarda SALTED
	    MGRPWDSUM=$(/usr/local/bin/genPwd.php "$MGRPWD" 2>>$LOGFILE)
	    MGRPWD=''

	    #Guardamos las variables que necesite el programa en el fichero de variables de disco
	    $PVOPS vars setVar d MGREMAIL  "$MGREMAIL"  #////probar
	    $PVOPS vars setVar d ADMINNAME "$ADMINNAME"
	    $PVOPS vars setVar d KEYSIZE   "$KEYSIZE"

	fi
    fi 





    #########  Solicitar datos de registro en eSurveySites ######### 

    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ]
	    then :
	    
            #Pedimos los parámetros para registrar el servidor en eSruveySites, 
	    #genera la petición de cert y la envia.
            esurveyParamsAndRequest
	    
	    
	    #Descargamos la lista de nodos y advertimos si no hay al menos dos nodos
	    wget https://esurvey.nisu.org/sites?lstnodest=1 -O /tmp/nodelist 2>/dev/null
	    ret=$?

	    if [ "$ret" -ne  0  ]
		then
		$dlg --msgbox $"Ha habido un error al descargar la lista de nodos. No podemos verificar si existen al menos dos nodos para garantizar el anonimato." 0 0
	    else
		numnodes=$(wc -l /tmp/nodelist | cut -d " " -f 1)
    
		[ "$numnodes" -lt "2"  ] && $dlg --msgbox $"No existen suficientes nodos en la red de latencia para garantizar un nivel mínimo de anonimato. Opere este sistema bajo su propia responsabilidad." 0 0
    
	    fi
	    rm /tmp/tempdlg /tmp/nodelist 2>/dev/null
	    
	    
	    
	    
            ### Construcción de la urna ###
	    $dlg --infobox $"Generando llaves de la urna..." 0 0
	    
	    keyyU=$(openssl genrsa $KEYSIZE 2>/dev/null | openssl rsa -text 2>/dev/null)
	    
	    modU=$(echo -n "$keyyU" | sed -e "1,/^modulus/ d" -e "/^publicExponent/,$ d" | tr -c -d 'a-f0-9' | sed -e "s/^00//" | hex2b64)
	    expU=$(echo -n "$keyyU" | sed -n -e "s/^publicExponent.*(0x\(.*\))/\1/p" | hex2b64)
	    
	    keyyU=$(echo "$keyyU" | sed -n -e "/BEGIN/,/KEY/p")

	    #Guardamos las variables en el fichero del disco.
	    $PVOPS vars setVar d SITESORGSERV  "$SITESORGSERV"  #////probar
	    $PVOPS vars setVar d SITESNAMEPURP "$SITESNAMEPURP"
	    $PVOPS vars setVar d SITESEMAIL    "$SITESEMAIL"
	    $PVOPS vars setVar d SITESCOUNTRY  "$SITESCOUNTRY"
	    
	fi
    fi






    
    ######### Activación del servidor mysql ##########
    $dlg --infobox $"Configurando servidor de base de datos..." 0 0
 

    $PVOPS configureServers "dbServer-init"  "$1"
    
 
    ### Construímos el segundo fichero .sql, con los inserts necesarios para config. la aplicación ###
    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ] 
	    then
	    rm -f $TMPDIR/config.sql
	    touch $TMPDIR/config.sql
	    
            #Escapamos los campos que pueden contener caracteres problemáticos (o los que reciben entrada directa del usuario)
	    adminname=$($addslashes "$ADMINNAME" 2>>$LOGFILE)
	    admidnum=$($addslashes "$ADMIDNUM" 2>>$LOGFILE)
	    adminrealname=$($addslashes "$ADMREALNAME" 2>>$LOGFILE)
	    mgremail=$($addslashes "$MGREMAIL" 2>>$LOGFILE)
	    
	    
	    
            #Inserción del usuario administrador (ahora no puede entrar cuando quiera, sólo cuando se le autorice)
	    echo "insert into eVotPob (us,DNI,nom,rol,pwd,clId,oIP,correo) values ('$adminname','$admidnum','$adminrealname',3,'$MGRPWDSUM',-1,-1,'$mgremail');" >> $TMPDIR/config.sql
	    
	    
            #Inserción del email del admin
            #El primero debe ser un insert. El update no traga. --> ya hay un insert, en el script del dump, pero fallaba por no tener permisos de ALTER y se abortaba el resto del script sql.
	    echo "update eVotDat set email='$mgremail';" >> $TMPDIR/config.sql
	    
	    
            #Insertamos las llaves de la urna
            # modU -> mod de la urna (B64)
            # expU -> exp público de la urna (B64)
            # keyyU -> llave privada de la urna. (PEM)
	    echo "update eVotDat set modU='$modU', expU='$expU', keyyU='$keyyU';" >> $TMPDIR/config.sql 
	    
	    
            #Insertamos las llaves y el certificado autofirmado enviado a eSurveySites.
            # keyyS -> llave privada del servidor de firma (PEM)
            # certS -> certificado autofirmado del servidor de firma (B64)
            # expS  -> exponente público del cert de firma (B64)
            # modS  -> módulo del cert de firma (B64)
	    echo "update eVotDat set keyyS='$keyyS', certS='$certS', expS='$expS', modS='$modS';" >> $TMPDIR/config.sql 
	    
            #Insertamos el token de verificación que nos ha devuelto eSurveySites
	    echo "update eVotDat set tkD='$SITESTOKEN';" >> $TMPDIR/config.sql 

            #echo "tkD al insertarlo: $SITESTOKEN"   >>$LOGFILE 2>>$LOGFILE

            #La timezone del servidor
	    echo "update eVotDat set TZ='$TIMEZONE';" >> $TMPDIR/config.sql 
	    
	fi	
    fi
    

    
    $PVOPS configureServers "alterPhpScripts"

    
    
    if [ "$DORESTORE" -ne 1 ] ; then


	if [ "$1" == 'new' ]
	    then
            #Las rutas de los ficheros a leer ya las tiene la op.
	    $PSETUP populateDb "$USINGSSHBAK"
	fi

        #En cualquier caso, incluso cuando no estamos instalando, Ejecutamos los alters y updates de la BD para actualizarla.
	$PSETUP updateDb

	
        #Ejecutamos la cesión o denegación de privilegios al adminsitrador de la aplicación
	grantAdminPrivileges

    fi


    ######### Activación del servidor web ##########
    $dlg --infobox $"Configurando servidor web..." 0 0
    sleep 1
    

    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ]
	    then :

            #Selección de modo de operación: SSL o Plain
	    while true;
	      do
	      exec 4>&1 
	      selec=$($dlg --no-cancel  --menu $"Seleccione un modo de operación para el servidor web:" 0 80  2  \
		  1 $"Con certificado SSL" \
		  2 $"Conexión no cifrada" \
		  2>&1 >&4)
	      
	      case $selec in
		  
		  "1" )
                    WWWMODE="ssl"
		    wwwmodemsg=$"Añade un nivel más de privacidad y autenticidad del servidor. Requiere la solicitud de un certificado digital, un proceso relativamente costoso temporal y económicamente."
		    wwwmodename=$"Con certificado SSL"
		  ;;
	      	      
		  "2" )
		    WWWMODE="plain"
		    wwwmodemsg=$"La información viajará desprotegida. El sistema podrá emplearse inmediatamente y sin coste adicional. Aunque la seguridad del voto no se verá afectada, si se emplea autenticación local las contraseñas viajarán desprotegidas." 
		    wwwmodename=$"Conexión no cifrada"
	          ;;
	      
		  * )
		    continue
		  ;;
              esac
	      $dlg --yesno $"Ha elegido el modo:\n\n$wwwmodename\n\n$wwwmodemsg\n\n¿Continuar?" 0 0 
	      [ $? -ne 0 ] && continue	  
	      break
	    done

	    
	    $dlg --infobox $"Configurando servidor web..." 0 0
	

	    #Guardamos el modo como variable persistente 
	    $PVOPS vars setVar d WWWMODE "$WWWMODE"

	    if [ "$WWWMODE" == "plain" ] ; then
	    
		$PVOPS configureServers generateDummyCSR #////probar
		ret=$?
		
		[ "$ret" -ne 0 ] && systemPanic $"Error generando el certificado de pruebas." 0 0	

	    fi

	fi   
    fi #DORESTORE -ne 1
    
    
    $PVOPS configureServers "configureWebserver" "wsmode"
    
    
    if [ "$DORESTORE" -ne 1 ] 
	then
	
        #Si estamos instalando o por alguna razón no hay fichero de llave, generamos csr
	genCSR=0
	[ "$1" == 'new' ] && genCSR=1
	[ -f $DATAPATH/webserver/server.key ] || genCSR=1
	[ "$WWWMODE" == "plain" ] &&  genCSR=0 #Si es modo plain, ya hemos generado el csr
	if [ "$genCSR" -eq 1 ]
	    then 
	    
	    generateCSR "new"
	    ret=$?
	    
	    echo "Retorno de generateCSR: $ret"  >>$LOGFILE 2>>$LOGFILE
	    
	    [ "$ret" -ne 0 ] && systemPanic $"Error grave: no se pudo generar la petición de certificado."
	    
            #EScribimos el pkcs10 en la zona de datos de un clauer
	    $dlg --msgbox $"Se ha generado una petición de certificado SSL para este servidor.\nPor favor, prepare un dispositivo USB para almacenarla (puede ser uno de los Clauers empleados ahora).\nEsta petición deberá ser entregada a una Autoridad de Certificacion confiable para su firma.\n\nHaga notar al encargado de este proceso que en un fichero adjunto debe proporcionarse toda la cadena de certificación." 0 0

	    fetchCSR "new"
	    
	fi
    
	
        #Este aviso sólo debe salir si es ssl y new, en plain se ejecuta igual  pero de forma transpartente
	if [ "$1" == 'new' ]
	    then
	    [ "$WWWMODE" != "plain" ] && $dlg --msgbox $"Vamos a generar un certificado de pruebas para poder operar el sistema durante el proceso de firma del válido" 0 0
	fi
	
        #Si no hay cert (dummy o bueno), generar un dummy a partir de la csr (ya hay una llave seguro)
	$PVOPS configureServers "configureWebserver" "dummyCert"

	
	
    fi


    $PVOPS configureServers "configureWebserver" "finalConf"
    
    
    $PSETUP pmutils


} # end configureServers()  








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






#Launch pivileged setup phase 2, where all of the CD filesystem is
#moved to system memory and RAID units are configured
$PSETUP   2




ESVYCFG=''


# TODO review this var, try to make it non-global
PASSWD=''

DOFORMAT=0
DORESTORE=0



while true   #0
do

while true   #1
do



  #Insertar un primer dispositivo
  insertUSB $"Inserte un dispositivo Clauer que contenga \nlos datos de configuración del sistema para iniciarlo.\n\nSi desea realizar una primera instalación\ndel sistema o formatearlo, inserte un dispositivo USB vacio o pulse formatear." $"Formatear"
# TODO devolverá una part a montar y ret 0 o un dev a formatear con ret 2
  
# TODO review. use list usbs
  #$dlg --infobox "Devs detected""($NDEVS):\n$DEVS\n""Clauers detected""($NCLS):\n$CLS"  0 0
  #sleep 1
  #$dlg --infobox "Dev chosen"": $DEV\n""Clauer?"" $ISCLAUER"  0 0
  #sleep 1
# TODO also, check return 1 and not only the returneddev (which by the way is no longer a global, but a stdout)
  if [ "$DEV" == "" ]
      then
      confirmSystemFormat $"Ha pulsado formatear."
      #Si lo confirma, salta a la sección de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  #Si no es clauer,preguntar y repetir o saltar
  elif [ $ISCLAUER -eq 0 ]
      then
      confirmSystemFormat $"Este dispositivo no es un Clauer."
      #Si lo confirma, salta a la sección de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi
  
  
  
  #Es un Clauer. Conectar con el clauer y pedir contraseña
  clauerConnect $DEV auth
  
  ret=$?
  
  #Si se cancela la insercion de pwd, preguntar.
  if [ $ret -eq 1 ] 
      then
      confirmSystemFormat $"Ha elegido no proporcionar una contraseña." 
      #Si lo confirma, salta a la sección de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi
  
  
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
  $PVOPS clops parseConfig  >>$LOGFILE 2>>$LOGFILE
  if [ $? -ne 0 ]
      then
      #si la config no era adecuada, proponer format
      confirmSystemFormat $"La información de configuración leida estaba corrupta o manipulada." 
      #Si lo confirma, salta a la sección de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi

  
  
  ###### Elegir Acción a llevar a cabo ######
  #En el modo reset o restore (no en el new), antes de reconstruir la llave, pedimos que se indique la acción a realizar. Así ningún atacante podrá acceder al menú de acciones después de que la clave se haya reconstruído.
  #Si la acción es restaurar un backup, se pondrá en modo doformat y tb se alzará el flag dorestore
  DORESTORE=0
  choosemaintenanceAction
  
  break;
done  #1

  #Si ha elegido formatear, le damos una última oportunidad de echarse atrás
  if [ "$DOFORMAT" -eq 1 -a "$DORESTORE" -eq 0 ]
      then
      $dlg --no-label $"Inicio"  --yes-label $"Formatear sistema" --yesno  $"Ha elegido FORMATEAR el sistema.\nEs muy importante que comprenda que, en caso de continuar, \nsi había una instalación previa del sistema de voto será totalmente destruida.\n\n¿Está seguro de que desea continuar, o desea volver al inicio?" 0 0
      button=$?
      #Desea insertar otro disp.
      [ $button -eq 1 ] && continue
  fi
  
  break;
done #0















###### Sistema ya creado #####
	
	
# Es clauer y sí hay configuración previa. Se piden más clauers para iniciar el sistema.
if [ "$DOFORMAT" -eq 0 ] 
    then 
    
    #Si el sistema se está reiniciando, por defecto invalida los privilegios de admin
    SETAPPADMINPRIVILEGES=0

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
	  $PVOPS clops compareConfigs

      fi	  
      
      #Preguntar si quedan más dispositivos
      $dlg   --yes-label $"Sí" --no-label $"No" --yesno  $"¿Quedan más Clauers por leer?" 0 0  
      ret=$?
      
    done
    
    #echo "Todos leidos"
    
    $dlg   --infobox $"Examinando los datos de configuración..." 0 0

    #Parsear la config y almacenarla
    $PVOPS clops parseConfig  >>$LOGFILE 2>>$LOGFILE

    if [ $? -ne 0 ]
	then
	systemPanic  $"Los datos de configuración están corruptos o manipulados."
    fi
    
    #Una vez están todos leídos, la config elegida como válida (si había incongruencias)
    #se almacena para su uso oficial de ahora en adelante (puede cambiarse con comandos)
    $PVOPS clops settleConfig  >>$LOGFILE 2>>$LOGFILE
    
  
    $dlg   --infobox $"Reconstruyendo la llave de cifrado..." 0 0

    $PVOPS clops rebuildKey #//// probar
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
    SETAPPADMINPRIVILEGES=1
    
    
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
	  
          #Acceder
	  clauerConnect $DEV "newpwd" $"Introduzca una contraseña nueva:"
	  ret=$?
	  
          #Si el acceso se cancela, pedimos que se inserte otro
	  if [ $ret -eq 1 ] 
	      then
	      $dlg --msgbox $"Ha abortado el formateo del Clauer. Inserte otro para continuar" 0 0 
	      continue
	  fi
	  
          #Formatear y particionar el dev

	  $dlg   --infobox $"Preparando Clauer..." 0 0
	  formatearClauer "$DEV" "$PASSWD"	  
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
$PVOPS clops resetAllSlots  #//// probar que ya limpie y pueda ejecutar al menos una op de mant correctamente.


#Una vez acabado el proceso de instalación/reinicio, lanzamos el proceso de mantenimiento. 
# El uso del exec resulta de gran importancia dado que al sustituír el contexto del proceso 
# por el de este otro, destruye cualquier variable sensible que pudiese haber quedado en memoria.
exec /bin/bash  /usr/local/bin/wizard-maintenance.sh





#*-*-Arreglar al menos el menú de standby y las operaciones que se realizan antes y después de llamar a una op del bucle infinito. ha sacado dos mensajes impresos. supongo que estarán dentro del maintenance, pero revisarlo bien cuando esté mejor el fichero de maintenance poner reads.







#//// Ver las PVOPS en  configureServers (y el resto), porque habrá alguna que podrá ser pasada a PSETUP







#Para verificar la sintaxis:   for i in $(ls ./data/config-tools/*.sh);   do    echo "-->Verificando script $i";   bash -n $i;   if [ $? -ne 0 ];       then       errorsFound=1;   fi; done;
