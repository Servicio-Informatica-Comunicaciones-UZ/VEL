#!/bin/bash

echo 'TERMINAL isnide w-s 1: '$TERM

export TERM=linux



##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh

echo 'TERMINAL isnide w-s 2: '$TERM
locale
read


###############
#  Constants  #
###############


#Determines if an action on the idle menu doesn't need authorization by key reuilding  
BYPASSAUTHORIZATION=0 ### //// Esta variable debe desaparecer. El control de autorizaci�n  pasa por completo al prog priv.




######################
#  Global Variables  #
######################


hald_present=0

#Current config file accepted as in use (in case of mismatch)
CURRINUSE=0

#Para que el panic saque el men�  #////si lo quito del panic, puedo quitarlod e aqu�
SYSTEMISRUNNING=0

SETAPPADMINPRIVILEGES=''



#############
#  Methods  #
#############


# //// VER si estas 3 funcs las pongo en commons o las dejo aqu� (dependiendo de cu�ntas variables necesito usar como root), y si el fichero de variables de root debe contener tb las variables del fichero de usuario.


#//// Es posible que estas funciones desaparezcan, si al final todos los params los maneja el root





#//// esta se llama en el setup --> op de setup que la haga. Tb se llama en otros puntos que deber�n pasar a ser op.




choosemaintenanceAction () {

    exec 4>&1 
    selec=$($dlg --no-cancel  --menu $"Seleccione una acci�n a llevar a cabo:" 0 80  6  \
	1 $"Iniciar el sistema de voto." \
	2 $"Recuperar una instalaci�n del sistema de voto." \
	3 $"Lanzar un terminal de administraci�n." \
	4 $"Apagar el equipo." \
	2>&1 >&4)
    
    
    while true; do
    case "$selec" in
	
	"1" )
	return 0
        ;;

	"2" )
	DORESTORE=1
	DOFORMAT=1
	return 0
        ;;
	
	"3" )
	$dlg --yes-label $"S�" --no-label $"No"  --yesno  $"ATENCI�N:\n\nHa elegido lanzar un terminal. Esto otorga al manipulador del equipo acceso a datos sensibles hasta que este sea reiniciado. Aseg�rese de que no sea operado sin supervisi�n t�cnica para verificar que no se realiza ninguna acci�n il�cita. �Desea continuar?" 0 0
	[ "$?" -eq 0 ] && exec $PVOPS rootShell  #//// cambiar todos los sitios en que saque un bas de root por 'exec privops rootsh'
        exec /bin/false
        ;;	
	
	"4" )	
        #      maxhits=2
#      hits=0
#      while [ $hits -lt $maxhits  ]
#	do
#	$dlg --yes-label $"Cancelar"  --no-label $"Apagar" --yesno $"Pulse -Apagar- repetidas veces para apagarlo.\n\nPulsaciones restantes: "$(($maxhits-$hits)) 0 0
#	ret=$?	
#	[ $ret -eq 1 ] && hits=$(($hits + 1))
#	[ $ret -eq 0 ] && hits=0
#      done
#      shutdownServer "h"
	
	$dlg --yes-label $"Cancelar"  --no-label $"Apagar" --yesno $"�Est� seguro de que desea apagar el equipo?" 0 0
	ret=$?	
	[ $ret -eq 1 ] && shutdownServer "h"
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










#//// Esta func a root. All� crear un servicio que reciba los params del wizard y los guarde para ser escritos en el clauer (revisados, claro). luego, leerlos todos del/los ficheros correspondientes en cada invocaci�n a privops (mejor eso o que los busquen uno a uno?).




# $1 -> Parte 1 del mensaje de confirmaci�n.

confirmSystemFormat (){
    
    $dlg --no-label $"Inicio"  --yes-label $"Formatear" --yesno  $"$1\nEsto implica que, o el sistema esta vacio, o desea reinstalarlo. \nSi elige continuar, se destruir�n todos los datos\n del sistema si los hubiese y se instalar�\nel sistema de voto totalmente de cero. \n\n�Desea continuar o desea volver al inicio?" 0 0
    button=$?

    #echo "Pulsado $button"

    #Desea insertar otro disp.
    if [ $button -eq 1 ]
	then
	DOFORMAT=0  
	return
    fi
	
    #Doble confirmaci�n
    $dlg   --yes-label $"S�" --no-label $"No" --yesno  $"�Seguro que desea continuar?" 0 0  
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






#////  este probablemente deba ponerlo como root, pero ver si no es necesario. En todo caso, filtrar los params a lo bestia. Que el dev s�lo pueda ser /dev/sd[a-z][0-9]* o algo asi (verificar), limitar el tama�o del pwd..




# ++++ seguir:

# //// Un programa que corre con sudo, su espacio de memoria es accesible por el usuario que lo ejecuta o s�lo por el root? --> parece ser que s�lo por el root.

# //// Verificar que la pwd de DB del usuario no se escirbe en vars.conf en ning�n caso, y solo se usa en el setup.
# //// Sacar el pwd del ssh backup de vars.conf
# //// Sacar el pwd de la part de /root (o al menos quitarle los permisos de lectura a g y o.)

#////Revisar los restos del setup y las ops del standby en /tmp, /root, /home/vtuji y /media/cryptStorage.










 #////SEGUIR++++







##### Par�metros del admin del sistema #####


sysadminParams () {


    $dlg --msgbox $"Vamos a definir los datos de acceso como administrador al programa Web de gesti�n del sistema de voto. Deber� recordarlos para poder acceder en el futuro.\n\nRecuerde que el acceso a las funciones de administraci�n privilegiadas s�lo podr� llevarse a cabo previa autorizaci�n de la comisi�n de custodia por medio de esta aplicaci�n." 0 0
    
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
	  $dlg --msgbox $"Debe introducir un nombre de usuario v�lido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
	  continue
      fi


      getPwd '' 1 $"Introduzca la contrase�a para\nel administrador del sistema de voto.\nEs imprescindible que la recuerde." 1
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
      
      
      parseInput completename "$ADMREALNAME"
      if [ $? -ne 0 ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe introducir un nombre v�lido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
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
	  $dlg --msgbox $"Debe introducir un numero de DNI v�lido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0 
	  continue
      fi
      



      MGREMAIL=$($dlg --no-cancel  --inputbox  \
	  $"Correo electr�nico del administrador del sistema de voto.\nSe emplear� para notificar incidencias del sistema." 0 0 "$MGREMAIL"  2>&1 >&4)
      
      if [ "$MGREMAIL" == "" ] 
	  then
	  verified=0 
	  $dlg --msgbox $"Debe proporcionar un correo electr�nico." 0 0 
	  continue
      fi
      
      parseInput email "$MGREMAIL"
      if [ $? -ne 0 ] 
	  then 
	  verified=0
	  $dlg --msgbox $"Debe introducir una direcci�n de correo v�lida." 0 0
	  continue
      fi
      


          #Solicitamos que se indique la zona horaria en la que nos hallamos
      options=$(cat /usr/local/share/timezones | sed -re "s/(.*)/\1 . /g")
      tz=$($dlg --no-cancel --default-item "$TIMEZONE" --menu $"Seleccione la zona horaria en la que se ubica el servidor de voto:" 0 50 15 $options   2>&1 >&4)
      
      if [ "$tz" == ""  ] 
	  then
	  verified=0
	  $dlg --msgbox $"Debe seleccionar una zona horaria." 0 0
	  continue
      fi
      TIMEZONE="$tz"
      


	  #Selector de tama�o de llave
      KEYSIZE=""
      exec 4>&1 
      KEYSIZE=$($dlg --no-cancel  --menu $"Seleccione un tama�o para las llaves del sistema\n(a mayor valor, m�s robustez, pero m�s coste computacional):" 0 80  5  \
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
	      $"Datos adquiridos. �Desea revisarlos o desea continuar con la configuraci�n del sistema?" 0 0 
	  verified=$?
      fi
      
    done



}


##### Datos de registro en eSurveySites #####


esurveyParamsAndRequest () {


	    $dlg --msgbox $"Vamos a definir los datos para registrar el sistema como miembro v�lido de la red eSurvey. Si ya est� registrado como usuario de eSurveySites, introduzca los datos correctos. Si no, puede crear una nueva cuenta ahora introduciendo los datos deseados." 0 0
	    
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
		  $"Correo electr�nico, identificador de usuario para eSurveySites." 0 0 "$SITESEMAIL"  2>&1 >&4)
	      
	      if [ "$SITESEMAIL" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar una direcci�n de correo." 0 0
		  continue
	      fi
	      
	      parseInput email "$SITESEMAIL"
	      if [ $? -ne 0 ] 
		  then
		  verified=0 
		  $dlg --msgbox $"Debe introducir una direcci�n de correo v�lida." 0 0
		  continue
	      fi
	      
	      

	  #yesno: auto-generar password (que recibir� en el correo) o especificarlo
	      $dlg --yes-label $"Especificar"  --no-label $"Generar"  --yesno \
		  $"Desea especificar una contrase�a para eSurveySites (si ya posee una cuenta elija 'especificar') o prefiere que se genere autom�ticamente (la recibir� en su correo)?" 0 0 
	      generatePWD=$?
	      
	      
	      if [ "$generatePWD" -eq 0 ]
		  then
	      # Pide la contrase�a
		  getPwd '' 1 $"Contrase�a de acceso a eSurveySites.\nSi ya posee una cuenta, escriba la contrase�a." 1
		  SITESPWD="$pwd"
		  pwd=''
	      else
	      #Lo auto-genera
		  randomPassword 10
		  SITESPWD=$pw
		  pw=''
	      fi
	      
	      
	      
	      SITESORGSERV=$($dlg --no-cancel  --inputbox  \
		  $"Nombre de su organizaci�n o del servidor." 0 0 "$SITESORGSERV"  2>&1 >&4)
	      
	      if [ "$SITESORGSERV" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar un nombre." 0 0
		  continue
	      fi
	      
	      parseInput name "$SITESORGSERV"
	      if [ $? -ne 0 ] 
		  then 
		  verified=0 
		  $dlg --msgbox $"Debe introducir un nombre v�lido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
		  continue
	      fi
	      


	      SITESNAMEPURP=$($dlg --no-cancel  --inputbox  \
		  $"Nombre o prop�sito del sistema de voto." 0 0 "$SITESNAMEPURP"  2>&1 >&4)
	      
	      if [ "$SITESNAMEPURP" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar un nombre." 0 0
		  continue
	      fi
	      
	      parseInput name "$SITESNAMEPURP"
	      if [ $? -ne 0 ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe introducir un nombre v�lido. Puede contener los caracteres: $ALLOWEDCHARSET" 0 0
		  continue
	      fi
	      

	      
	      SITESCOUNTRY=$($dlg --no-cancel  --inputbox  \
		  $"Pa�s en que se ubica su organizaci�n o su servidor (2 letras)." 0 0 "$SITESCOUNTRY"  2>&1 >&4)
	      
	      if [ "$SITESCOUNTRY" == "" ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe proporcionar un c�digo de pa�s de 2 letras." 0 0
		  continue
	      fi
	      
	      parseInput cc "$SITESCOUNTRY"
	      if [ $? -ne 0 ] 
		  then
		  verified=0
		  $dlg --msgbox $"Debe introducir un c�digo v�lido." 0 0 
		  continue
	      fi
	      


	      if [ "$verified" -eq 1 ] 
		  then
		  $dlg --yes-label $"Revisar"  --no-label $"Continuar"  --yesno \
		      $"Datos adquiridos. �Desea revisarlos o desea continuar con la configuraci�n del sistema?" 0 0 
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
	      
	  #urlencode en Sed: Define la etiqueta a, lee la siguiente l�nea y para ella sustituye = por %3D, etc. y salta a 'a' de nuevo.
	      req=$(echo "$certS" >/tmp/crt$$; echo "$keyyS" |
		  openssl x509 -signkey /dev/stdin -in /tmp/crt$$ -x509toreq 2>>$LOGFILE | sed -n -e "/BEGIN/,/END/p" |
		  sed -e :a -e N -e 's/\//%2F/g;s/=/%3D/g;s/+/%2B/g;s/\n/%0A/;ta' ; rm /tmp/crt$$);
	      
	      
	      
          #conexion con sites
	      $dlg --infobox $"Conectando con eSurveySites..." 0 0
	      
	      
	  #Urlencode del mail y el pwd:
	      mail=$($urlenc "$SITESEMAIL" 2>>$LOGFILE)
	      pwd=$($urlenc "$SITESPWD" 2>>$LOGFILE)
	      
	  #El param once provoca que la cuenta no pueda usarse tras el registro (para evitar un DoS el dia de la elecci�n)
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
		  "1" ) #L�nea de Estado
                    if [ "$line" == "ERR" ] 
			then
			$dlg --msgbox $"Error al entregar la solicitud de certificado en eSurveySites. Tal vez la direcci�n de correo ya pertenece a una cuenta registrada." 0 0
			err=1 
			verified=0 
			break
		    fi
		    if [ "$line" == "REG" ] 
			then
			$dlg --msgbox $"Error al entregar la solicitud de certificado en eSurveySites. Tal vez la direcci�n de correo ya pertenece a una cuenta registrada." 0 0
			err=1
			verified=0
			break
		    fi
		    if [ "$line" == "DUP" ] 
			then
			$dlg --msgbox $"Error: ya existe una solicitud en eSurveySites con estos datos. Modif�quelos." 0 0
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
		
		  "4" ) #OK-> Token de la petici�n de firma
		    SITESTOKEN="$line"
		  ;;	
		esac

	        #echo "$linenum-->"$line

		linenum=$(($linenum+1))

		[ $err -eq 1 ] && break
	      done
	      #Esto lo pongo como guarda por si a�ado c�digo debajo de esto
	      [ $verified -eq 0 ] && continue

	    done  #Fin de entrada de datos de admin, cert y petici�n de cert

	    #echo "valor de tkD devuelto: $SITESTOKEN"   >>$LOGFILE 2>>$LOGFILE


}







##### Configuraci�n principal del sistema #####


#1 -> 'new' or 'reset'
doSystemConfiguration (){


    #Si estamos creando el sistema, la red se habr� configurado durante el setup
    if [ "$1" == 'reset' ]
        then
        configureNetwork 'Panic'
    fi

	
    #Abrimos o creamos la zona segura de datos.
    configureCryptoPartition "$1"   "$MOUNTPATH"  "$MAPNAME"  "$DATAPATH"
    #En $CRYPTDEV est� el dev empleado, para desmontarlo


    
    #Si se est� ejecutando una restauraci�n
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
		$dlg --msgbox $"Error durante la recuperaci�n del backup. Vuelva a intentarlo." 0 0 
		continue
	    fi


	    #Recuperamos el fichero y lo desciframos
	    $PSETUP recoverSSHBackupFile 
	    if [ $? -ne 0 ] 
		then
		$dlg --msgbox $"Error durante la recuperaci�n del backup. Vuelva a intentarlo." 0 0
		continue
	    fi
	    
	
	    #Volvemos al Slot de la instalaci�n nueva (sobre la que estamso restaurando la vieja)
	    $PVOPS clops switchSlot 1


	    break
	done


    fi
    

    #Leemos variables de configuraci�n que necesitamos aqu� (si es new, 
    #ya est�n definidas, si es reset, se redefinen y no pasa nada)
    WWWMODE=$($PVOPS vars getVar d WWWMODE)
    USINGSSHBAK=$($PVOPS vars getVar c USINGSSHBAK)

    #Si hay backup de los datos locales
    if [ "$USINGSSHBAK" -eq 1  ] ; then
	if [ "$1" == "new"  ] ; then  #*-*-en restore estos valen los nuevos. restaurar el vars original y que los machaque aqu�?
	    #Escribimos en un fichero los params que necesita el script del cron 
	    #(s�lo al instalar, porque luego pueden ser modificados desde el men� idle)
	    #(en realidad no importa, porque al cambiarlos reescribe los clauers)
	    $PVOPS vars setVar d SSHBAKSERVER "$SSHBAKSERVER"
	    $PVOPS vars setVar d SSHBAKPORT   "$SSHBAKPORT"
	    $PVOPS vars setVar d SSHBAKUSER   "$SSHBAKUSER"
	    $PVOPS vars setVar d SSHBAKPASSWD "$SSHBAKPASSWD"
	fi
    fi

    # Una vez montada la partici�n cifrada, sea new o reset (en este caso, ya habr� leido las vars del disco) o restore (ya habr� copiado los datos correspondientes)
    relocateLogs "$1"

    #////Si he de hacer alg�n cambio a la part cifrada, llamarlo aqu� si es una op aislada. creo que en la de configurecryptopart ya hago los cambios correspondientes -> COMPROBAR Y BORRAR
    
    
    
    #Solo verificamos las piezas si es un reset, no si es nuevo servidor
    if [ "$1" == 'reset' ]
	then

        #Verificamos las piezas de la llave, pero s�lo con fin informativo, no obligamos a cambiarla ya.
	$dlg --infobox $"Verificando piezas de la llave..." 0 0

	testForDeadShares 
	res=$?
	
        #Si no todas las piezas son correctas, solicitamos regeneraci�n.
	if [ "$res" -ne "0" ];  then
	    $dlg --msgbox $"Se detectaron piezas corruptas.\n\nPara evitar una p�rdida de datos, deber�a reunirse la comisi�n al completo en el menor tiempo posible y proceder a cambiar la llave." 0 0 
	fi	
    fi

    

    #Lanzamos los servicios del sistema (y acabamos la configuraci�n de la instalaci�n)
    configureServers "$1" 


    if [ "$DORESTORE" -eq 1 ] ; then

	$PSETUP recoverDbBackup
	
    fi


    #Si estamos em modo de disco local, ponemos en marcha el proceso cron de backup cada minuto
    if [ "$USINGSSHBAK" -eq 1  ] ; then

	if [ "$1" == 'reset' ] ; then
	    
	    SSHBAKSERVER=$($PVOPS vars getVar d SSHBAKSERVER)
	    SSHBAKPORT=$($PVOPS vars getVar d SSHBAKPORT)

	    #A�adimos las llaves del servidor SSH al known_hosts
	    local ret=$($PVOPS sshKeyscan "$SSHBAKPORT" "$SSHBAKSERVER")
	    if [ "$ret" -ne 0 ]  #//// PRobar!!
		then
		systemPanic $"Error configurando el acceso al servidor de copia de seguridad."
	    fi
	fi
	
	$PSETUP enableBackup	    
	
    fi
    
    
    
    #Lanzamos el sistema de recogida de estad�sticas en RRDs
    if [ "$1" == "new"  ] ; then
	#Construye las RRD
	$PVOPS stats startLog 
    fi
    
    #Creamos el cron que actualiza los resultados y genera las gr�ficas
    $PVOPS stats installCron
    
    #Actualizamos los gr�ficos al inicio (vac�os en la creaci�n, no vac�os en el reboot)
    $PVOPS stats updateGraphs  >>$LOGFILE 2>>$LOGFILE
    

    #Escribimos el alias que permite que
    #se envien los emails de emergencia del smart y dem�s
    #servicios al correo del administrador
    
    $PSETUP setupNotificationMails
	
    #Para que el panic NO saque el men�  #////si lo quito del panic, pueod quitarlo de aqu�.
    SYSTEMISRUNNING=1

    #Realizamos los ajustes finales
    $PSETUP 4
        

    $dlg --msgbox $"Sistema iniciado correctamente y a la espera." 0 0
    

}  #end doSystemConfiguration





#1 -> 'new' or 'reset'
configureServers () {




    ######### Activaci�n del servidor postfix ##########
    $dlg --infobox $"Configurando servidor de correo..." 0 0

    if [ "$1" == 'new' ]
	then :
	
        #Guardamos las variables d econfiguraci�n correspondientes (esta la pido 
        #al principio pero no se necesita hasta ahora. Adem�s ahora la guardo 
        #s�lo en disco, y no tb en el clauer)
	$PVOPS vars setVar d MAILRELAY "$MAILRELAY"
    fi
    
    
    $PVOPS configureServers mailServer
    
    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de correo." f
    



    
    ######### Solicitar datos del administrador del sistema ######### 

    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ]
	    then :
	    
	    #Pedimos los par�metros del sysadmin
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
	    
            #Pedimos los par�metros para registrar el servidor en eSruveySites, 
	    #genera la petici�n de cert y la envia.
            esurveyParamsAndRequest
	    
	    
	    #Descargamos la lista de nodos y advertimos si no hay al menos dos nodos
	    wget https://esurvey.nisu.org/sites?lstnodest=1 -O /tmp/nodelist 2>/dev/null
	    ret=$?

	    if [ "$ret" -ne  0  ]
		then
		$dlg --msgbox $"Ha habido un error al descargar la lista de nodos. No podemos verificar si existen al menos dos nodos para garantizar el anonimato." 0 0
	    else
		numnodes=$(wc -l /tmp/nodelist | cut -d " " -f 1)
    
		[ "$numnodes" -lt "2"  ] && $dlg --msgbox $"No existen suficientes nodos en la red de latencia para garantizar un nivel m�nimo de anonimato. Opere este sistema bajo su propia responsabilidad." 0 0
    
	    fi
	    rm /tmp/tempdlg /tmp/nodelist 2>/dev/null
	    
	    
	    
	    
            ### Construcci�n de la urna ###
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






    
    ######### Activaci�n del servidor mysql ##########
    $dlg --infobox $"Configurando servidor de base de datos..." 0 0
 

    $PVOPS configureServers "dbServer-init"  "$1"
    
 
    ### Constru�mos el segundo fichero .sql, con los inserts necesarios para config. la aplicaci�n ###
    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ] 
	    then
	    rm -f $TMPDIR/config.sql
	    touch $TMPDIR/config.sql
	    
            #Escapamos los campos que pueden contener caracteres problem�ticos (o los que reciben entrada directa del usuario)
	    adminname=$($addslashes "$ADMINNAME" 2>>$LOGFILE)
	    admidnum=$($addslashes "$ADMIDNUM" 2>>$LOGFILE)
	    adminrealname=$($addslashes "$ADMREALNAME" 2>>$LOGFILE)
	    mgremail=$($addslashes "$MGREMAIL" 2>>$LOGFILE)
	    
	    
	    
            #Inserci�n del usuario administrador (ahora no puede entrar cuando quiera, s�lo cuando se le autorice)
	    echo "insert into eVotPob (us,DNI,nom,rol,pwd,clId,oIP,correo) values ('$adminname','$admidnum','$adminrealname',3,'$MGRPWDSUM',-1,-1,'$mgremail');" >> $TMPDIR/config.sql
	    
	    
            #Inserci�n del email del admin
            #El primero debe ser un insert. El update no traga. --> ya hay un insert, en el script del dump, pero fallaba por no tener permisos de ALTER y se abortaba el resto del script sql.
	    echo "update eVotDat set email='$mgremail';" >> $TMPDIR/config.sql
	    
	    
            #Insertamos las llaves de la urna
            # modU -> mod de la urna (B64)
            # expU -> exp p�blico de la urna (B64)
            # keyyU -> llave privada de la urna. (PEM)
	    echo "update eVotDat set modU='$modU', expU='$expU', keyyU='$keyyU';" >> $TMPDIR/config.sql 
	    
	    
            #Insertamos las llaves y el certificado autofirmado enviado a eSurveySites.
            # keyyS -> llave privada del servidor de firma (PEM)
            # certS -> certificado autofirmado del servidor de firma (B64)
            # expS  -> exponente p�blico del cert de firma (B64)
            # modS  -> m�dulo del cert de firma (B64)
	    echo "update eVotDat set keyyS='$keyyS', certS='$certS', expS='$expS', modS='$modS';" >> $TMPDIR/config.sql 
	    
            #Insertamos el token de verificaci�n que nos ha devuelto eSurveySites
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

	
        #Ejecutamos la cesi�n o denegaci�n de privilegios al adminsitrador de la aplicaci�n
	grantAdminPrivileges

    fi


    ######### Activaci�n del servidor web ##########
    $dlg --infobox $"Configurando servidor web..." 0 0
    sleep 1
    

    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ]
	    then :

            #Selecci�n de modo de operaci�n: SSL o Plain
	    while true;
	      do
	      exec 4>&1 
	      selec=$($dlg --no-cancel  --menu $"Seleccione un modo de operaci�n para el servidor web:" 0 80  2  \
		  1 $"Con certificado SSL" \
		  2 $"Conexi�n no cifrada" \
		  2>&1 >&4)
	      
	      case $selec in
		  
		  "1" )
                    WWWMODE="ssl"
		    wwwmodemsg=$"A�ade un nivel m�s de privacidad y autenticidad del servidor. Requiere la solicitud de un certificado digital, un proceso relativamente costoso temporal y econ�micamente."
		    wwwmodename=$"Con certificado SSL"
		  ;;
	      	      
		  "2" )
		    WWWMODE="plain"
		    wwwmodemsg=$"La informaci�n viajar� desprotegida. El sistema podr� emplearse inmediatamente y sin coste adicional. Aunque la seguridad del voto no se ver� afectada, si se emplea autenticaci�n local las contrase�as viajar�n desprotegidas." 
		    wwwmodename=$"Conexi�n no cifrada"
	          ;;
	      
		  * )
		    continue
		  ;;
              esac
	      $dlg --yesno $"Ha elegido el modo:\n\n$wwwmodename\n\n$wwwmodemsg\n\n�Continuar?" 0 0 
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
	
        #Si estamos instalando o por alguna raz�n no hay fichero de llave, generamos csr
	genCSR=0
	[ "$1" == 'new' ] && genCSR=1
	[ -f $DATAPATH/webserver/server.key ] || genCSR=1
	[ "$WWWMODE" == "plain" ] &&  genCSR=0 #Si es modo plain, ya hemos generado el csr
	if [ "$genCSR" -eq 1 ]
	    then 
	    
	    generateCSR "new"
	    ret=$?
	    
	    echo "Retorno de generateCSR: $ret"  >>$LOGFILE 2>>$LOGFILE
	    
	    [ "$ret" -ne 0 ] && systemPanic $"Error grave: no se pudo generar la petici�n de certificado."
	    
            #EScribimos el pkcs10 en la zona de datos de un clauer
	    $dlg --msgbox $"Se ha generado una petici�n de certificado SSL para este servidor.\nPor favor, prepare un dispositivo USB para almacenarla (puede ser uno de los Clauers empleados ahora).\nEsta petici�n deber� ser entregada a una Autoridad de Certificacion confiable para su firma.\n\nHaga notar al encargado de este proceso que en un fichero adjunto debe proporcionarse toda la cadena de certificaci�n." 0 0

	    fetchCSR "new"
	    
	fi
    
	
        #Este aviso s�lo debe salir si es ssl y new, en plain se ejecuta igual  pero de forma transpartente
	if [ "$1" == 'new' ]
	    then
	    [ "$WWWMODE" != "plain" ] && $dlg --msgbox $"Vamos a generar un certificado de pruebas para poder operar el sistema durante el proceso de firma del v�lido" 0 0
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





#Este bloque se ejecuta s�lo una vez, antes del exec
if [ "$1" == "" ]
    then


    #Ejecutamos las acciones de configuraci�n privilegiadas.
    $PSETUP   1
    

    # //// Al final ver si lo uso para algo, o todo lo hace el root
    #Si no existe, crearlo
    [ -e "$TMPDIR" ] || mkdir "$TMPDIR"
    #Si no es fichero borrarlo y recrearlo
    [ -d "$TMPDIR" ] || (rm "$TMPDIR" && mkdir "$TMPDIR") 
    #Si existe, vaciarlo
    [ -e "$TMPDIR" ] && rm -rf "$TMPDIR"/*
    
 

    #Cr�ditos
    $dlg --msgbox "vtUJI - Telematic voting system v.$VERSION\n\nProject Director: Manuel Mollar Villanueva\nDeveloped by aCube Software Development (acube.projects@gmail.com)\nProgrammed by Manuel Mollar Villanueva and Francisco Jos� Arag� Monzon�s\n\nProject funded by:\n\nUniversitat Jaume I\nMinisterio de Industria, Turismo y Comercio\nFondo Social Europeo." 0 0
    
    
    #Mostrar selector de idioma
    exec 4>&1 
    lan=""
    while [ "$lan" == "" ]
      do
      lan=$($dlg --no-cancel  --menu "Select Language:" 0 40  3  \
	  "es" "Espa�ol" \
	  "ca" "Catal�" \
	  "en" "English" \
	  2>&1 >&4)
    done
    
    # Si LANG es C o POSIX, se impone, pero si lo dejas vac�o o pones una
    # cadena inv�lida, igual falla. hay que poner una cadena v�lida
    # cualquiera p. ej. es_ES.UTF-8, de las que salen en locale -a    
    
    export LANGUAGE="$lan"
    export LC_ALL=""
    export LANG="es_ES.UTF-8" 

    export TEXTDOMAINDIR=/usr/share/locale
    export TEXTDOMAIN=wizard-setup.sh  #//// ver si es factible invocar a los otros scripts con cadenas localizadas. Si no, separar las funcs y devolver valores para que las acdenas se impriman en este (y considerarlo tb por seguridad una vez funcione todo)

    #TODO descomentar
#    exec  "$0" "$lan"

#TODO borrar
    exec /bin/bash

    
fi #Fin Bloque que se ejecuta una sola vez al inicio

echo "selected language: $LANGUAGE"  >>$LOGFILE 2>>$LOGFILE







#Selector de timezones por defecto (una peque�a comodidad para el usuario)  #//// ROOT

case "$LANGUAGE" in 
    
    "es" ) 
    TIMEZONE="Europe/Madrid"
    $PSETUP loadkeys es   
    ;;
    
    "ca" ) 
    TIMEZONE="Europe/Madrid"
    $PSETUP loadkeys es   
    ;;
    
    "en" ) 
    TIMEZONE="Europe/London"
    ;;  
    
esac



    #Ejecutamos las acciones de configuraci�n privilegiadas. (fase 2)
    $PSETUP   2




ESVYCFG=''
PASSWD=''
DOFORMAT=0
DORESTORE=0



while true   #0
do

while true   #1
do



  #Insertar un primer dispositivo
  insertClauerDev $"Inserte un dispositivo Clauer que contenga \nlos datos de configuraci�n del sistema para iniciarlo.\n\nSi desea realizar una primera instalaci�n\ndel sistema o formatearlo, inserte un dispositivo USB vacio o pulse formatear." $"Formatear"
  

  #$dlg --infobox "Devs detected""($NDEVS):\n$DEVS\n""Clauers detected""($NCLS):\n$CLS"  0 0
  #sleep 1
  #$dlg --infobox "Dev chosen"": $DEV\n""Clauer?"" $ISCLAUER"  0 0
  #sleep 1

  if [ "$DEV" == "" ]
      then
      confirmSystemFormat $"Ha pulsado formatear."
      #Si lo confirma, salta a la secci�n de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  #Si no es clauer,preguntar y repetir o saltar
  elif [ $ISCLAUER -eq 0 ]
      then
      confirmSystemFormat $"Este dispositivo no es un Clauer."
      #Si lo confirma, salta a la secci�n de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi
  
  
  
  #Es un Clauer. Conectar con el clauer y pedir contrase�a
  clauerConnect $DEV auth
  
  ret=$?
  
  #Si se cancela la insercion de pwd, preguntar.
  if [ $ret -eq 1 ] 
      then
      confirmSystemFormat $"Ha elegido no proporcionar una contrase�a." 
      #Si lo confirma, salta a la secci�n de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi
  
  
  $dlg --infobox $"Leyendo configuraci�n del sistema..."  0 0
  sleep 1
  
  
  #Se puede acceder al Clauer. Leemos la configuraci�n.  
  ESVYCFG=''
 
  
  clauerFetch $DEV c
  #Si falla, pedimos otro clauer
  if [ $? -ne 0 ] 
      then
      confirmSystemFormat $"No se han podido leer los datos de configuraci�n de este Clauer." 
      #Si lo confirma, salta a la secci�n de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi
  

 
  #Verificamos que la �ltima config le�da tiene una estructura aceptable.
  $PVOPS clops parseConfig  >>$LOGFILE 2>>$LOGFILE
  if [ $? -ne 0 ]
      then
      #si la config no era adecuada, proponer format
      confirmSystemFormat $"La informaci�n de configuraci�n leida estaba corrupta o manipulada." 
      #Si lo confirma, salta a la secci�n de formatear sistema completo
      [ $DOFORMAT -eq 1  ] &&  break
      continue; #Sino, vuelve a pedir un dev
  fi

  
  
  ###### Elegir Acci�n a llevar a cabo ######
  #En el modo reset o restore (no en el new), antes de reconstruir la llave, pedimos que se indique la acci�n a realizar. As� ning�n atacante podr� acceder al men� de acciones despu�s de que la clave se haya reconstru�do.
  #Si la acci�n es restaurar un backup, se pondr� en modo doformat y tb se alzar� el flag dorestore
  DORESTORE=0
  choosemaintenanceAction
  
  break;
done  #1

  #Si ha elegido formatear, le damos una �ltima oportunidad de echarse atr�s
  if [ "$DOFORMAT" -eq 1 -a "$DORESTORE" -eq 0 ]
      then
      $dlg --no-label $"Inicio"  --yes-label $"Formatear sistema" --yesno  $"Ha elegido FORMATEAR el sistema.\nEs muy importante que comprenda que, en caso de continuar, \nsi hab�a una instalaci�n previa del sistema de voto ser� totalmente destruida.\n\n�Est� seguro de que desea continuar, o desea volver al inicio?" 0 0
      button=$?
      #Desea insertar otro disp.
      [ $button -eq 1 ] && continue
  fi
  
  break;
done #0








###### Sistema ya creado #####
	
	
# Es clauer y s� hay configuraci�n previa. Se piden m�s clauers para iniciar el sistema.
if [ "$DOFORMAT" -eq 0 ] 
    then 
    
    #Si el sistema se est� reiniciando, por defecto invalida los privilegios de admin
    SETAPPADMINPRIVILEGES=0

    #Leemos la pieza de la clave del primer clauer (del que acabamos de sacar la config)
    clauerFetch $DEV k 
    
    detectClauerextraction $DEV $"Clauer leido con �xito. Ret�relo y pulse INTRO."
    #Insertar un segundo dispositivo (jam�s se podr� cargar el sistema con uno solo)
    
    
    
    #Preguntar si quedan m�s dispositivos (a priori no sabemos el n�mero de clauers que habr� presentes, as� que simplificamos y dejamos que ellos decidan cu�ntos quedan). Una vez le�dos todos, ya veremos si hay bastantes o no.
    $dlg   --yes-label $"S�" --no-label $"No" --yesno  $"�Quedan m�s Clauers por leer?" 0 0  
    ret=$?
    
    #mientras queden dispositivos
    while [ $ret -ne 1 ]
      do
      
      readNextClauer 0 b
      status=$?
      
      
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
	  continue
      fi

      #Si todo es correcto
      if [ "$status" -eq 0  ] 
	  then
	  
	  #Compara la �ltima config le�da con la aceptada actualmente (y si hay diferencias, pregunta cu�l usar)
	  $PVOPS clops compareConfigs

      fi	  
      
      #Preguntar si quedan m�s dispositivos
      $dlg   --yes-label $"S�" --no-label $"No" --yesno  $"�Quedan m�s Clauers por leer?" 0 0  
      ret=$?
      
    done
    
    #echo "Todos leidos"
    
    $dlg   --infobox $"Examinando los datos de configuraci�n..." 0 0

    #Parsear la config y almacenarla
    $PVOPS clops parseConfig  >>$LOGFILE 2>>$LOGFILE

    if [ $? -ne 0 ]
	then
	systemPanic  $"Los datos de configuraci�n est�n corruptos o manipulados."
    fi
    
    #Una vez est�n todos le�dos, la config elegida como v�lida (si hab�a incongruencias)
    #se almacena para su uso oficial de ahora en adelante (puede cambiarse con comandos)
    $PVOPS clops settleConfig  >>$LOGFILE 2>>$LOGFILE
    
  
    $dlg   --infobox $"Reconstruyendo la llave de cifrado..." 0 0

    $PVOPS clops rebuildKey #//// probar
    stat=$? 

    #Si falla la primera reconstrucci�n, probamos todas
    if [ $stat -ne 0 ] 
	then

	$dlg --msgbox $"Se ha producido un error durante la reconstrucci�n de la llave por la presencia de fragmentos defectuosos. El sistema intentar� recuperarse." 0 0 

        retrieveKeywithAllCombs
	ret=$?

	#Si no se logra con ninguna combinaci�n, p�nico y adi�s.
         if [ "$ret" -ne 0 ] 
	    then
	     systemPanic $"No se ha podido reconstruir la llave de la zona cifrada."
	 fi
	 
    fi

    $dlg --msgbox $"Se ha logrado reconstruir la llave. Se prosigue con la carga del sistema." 0 0 

    #Saltar a  la secci�n de config de red/cryptfs
    doSystemConfiguration "reset"   


        







###### Sistema nuevo #####
    
#Se formatea el sistema 
else 
    #echo "Se formatea" 
    
    #Cuando el sistema se est� instalando, y hasta que se instale el cert SSL correcto, el admin tendr� privilegios
    SETAPPADMINPRIVILEGES=1
    
    
    #Pedimos que acepte la licencia
    $dlg --extra-button --extra-label $"No acepto la licencia" --no-cancel --ok-label $"Acepto la licencia"  --textbox /usr/share/doc/License.$LANGUAGE 0 0
    #No acepta la licencia (el extra-button retorna con cod. 3)
    [ "$?" -eq 3 ] && $PSETUP halt;  #////probar



    if [ "$DORESTORE" -eq 1 ] ; then
	$dlg --msgbox $"Ha elegido restaurar una copia de seguridad del sistema. Primero se instalar� un sistema totalmente limpio. Podr� alterar los par�metros b�sicos. Emplee un conjunto de Clauers NUEVOS. Al final se le solicitar�n los clauers antiguos para proceder a restaurar los datos." 0 0
    fi
    
    
    #BUCLE PRINCIPAL

    #Inicializaci�n de los campos de los formularios.
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
      

      $dlg --no-label $"Continuar"  --yes-label $"Modificar" --yesno  $"Ha acabado de definir los par�metros del servidor de voto. �Desea modificar los datos introducidos?" 0 0 
      #No (1) desea alterar nada
      [ "$?" -eq "1" ] && proceed=1
      
    done


    #Guardamos los params #////probar
    setConfigVars
  
    #Continuamos con la config inicial del sistema 


    #Nos aseguramos de que sincronice la hora 
    $dlg   --infobox $"Sincronizando hora del servidor..." 0 0

    
    #Ejecutamos elementos de configuraci�n
    $PSETUP   3
    
    
    genNfragKey
    
    #Ahora que tenemos shares y config, pedimos los Clauers de los miembros de la comisi�n para guardar los nuevos datos. 
    
    #Avisamos antes de lo que va a ocurrir.
    $dlg --msgbox $"Ahora procederemos a repartir la nueva informaci�n del sistema en los dispositivos de la comisi�n de custodia.\n\nLos dispositivos que se empleen NO DEBEN CONTENER NINGUNA INFORMACI�N, porque VAN A SER FORMATEADOS." 0 0


    writeClauers   
    
    #Informar de que se han escrito todos los clauers pero a�n no se ha configurado el sistema. 
    $dlg --msgbox $"Se ha terminado de repartir las nuevas llave y configuraci�n. Vamos a proceder a configurar el sistema" 0 0

    #Como en este caso no se elige modo de mantenimiento, indicamos el que corresponde
    doSystemConfiguration "new"


    #Forzamos un backup al acabar de instalar       #//// probar
    $PSETUP   forceBackup


    #Avisar al admin de que necesita un Clauer, y permitirle formatear uno en blanco.
    $dlg --yes-label $"Omitir este paso" --no-label $"Formatear dispositivo"  --yesno  $"El administrador del sistema de voto necesita poseer un dispositivo Clauer propio con fines identificativos frente a la aplicaci�n, aunque no contenga certificados. Si no posee ya uno, tiene la posibilidad de insertar ahora un dispositivo USB y formatearlo como Clauer." 0 0
    formatClauer=$?

    #Desea formatear un disp.
    if [ $formatClauer -eq 1 ]
	then
	
	success=0
	while [ "$success" -eq  "0" ]
	  do
	  
 
	  insertClauerDev $"Inserte el dispositivo USB a escribir y pulse INTRO." "none"
	  
      
          #Pedir pasword nuevo
	  
          #Acceder
	  clauerConnect $DEV "newpwd" $"Introduzca una contrase�a nueva:"
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
	
	detectClauerextraction $DEV $"Clauer escrito con �xito. Ret�relo y pulse INTRO."
	
    fi
    

    $dlg --msgbox $"El sistema se ha iniciado con privilegios para el administrador. Estos se invalidar�n en cuanto realice alguna operaci�n de mantenimiento (tal como instalar el certificado SSL del servidor)." 0 0
  
    
fi #if se formatea el sistema




#Realizamos los ajustes de seguridad comunes
$PSETUP 5

#Limpiamos los slots antes de pasar a mantenimiento (para anular las claves reconstruidas que pueda haber)
$PVOPS clops resetAllSlots  #//// probar que ya limpie y pueda ejecutar al menos una op de mant correctamente.


#Una vez acabado el proceso de instalaci�n/reinicio, lanzamos el proceso de mantenimiento. 
# El uso del exec resulta de gran importancia dado que al sustitu�r el contexto del proceso 
# por el de este otro, destruye cualquier variable sensible que pudiese haber quedado en memoria.
exec /bin/bash  /usr/local/bin/wizard-maintenance.sh





#*-*- SEGUIR MA�ANA:
#*-*-Revisar y racionalizar  todas las anotaciones: borrar las obsoletas e incongruentes, las duplicadas, etc. intentar agruparlas. Los puntos que ya he probado, borrarlos, y los otros anotarlos para verificarlos cuando regenere. Revisar el TODO y las hojas de la mesa.
#*-*-Arreglar al menos el men� de standby y las operaciones que se realizan antes y despu�s de llamar a una op del bucle infinito. ha sacado dos mensajes impresos. supongo que estar�n dentro del maintenance, pero revisarlo bien cuando est� mejor el fichero de maintenance poner reads.
#*-*-Creo que el recovery ya est� bien. Regenerar el Cd y probarlo (instalar, reiniciar, backup y recover)
#*-*- Luego ponerme ya con las ops en concreto.
#*-*- Revisar el script de instalaci�n y hacer los cambios de seguridad (permisos extendidos, etc.)







#//// Ver las PVOPS en  configureServers (y el resto), porque habr� alguna que podr� ser pasada a PSETUP







#Para verificar la sintaxis:   for i in $(ls ./data/config-tools/*.sh);   do    echo "-->Verificando script $i";   bash -n $i;   if [ $? -ne 0 ];       then       errorsFound=1;   fi; done;
