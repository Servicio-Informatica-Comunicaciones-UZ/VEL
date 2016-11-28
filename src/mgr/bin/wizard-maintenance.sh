#!/bin/bash



##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh




# TODO en alg�n sitio se invoca esto?
#    $PVOPS  stopServers



#Fatal error function. It is redefined on each script with the
#expected behaviour, for security reasons.
#$1 -> error message
systemPanic () { # TODO TRY TO EXTINGUISH
    
    #Show error message to the user
    $dlg --msgbox "$1" 0 0
    
    #Return to the maintenance idle loop
	   exec /bin/bash  /usr/local/bin/wizard-maintenance.sh
    shutdownServer "h" #This will never be executed
}





# Pide que se inserte un dev USB y que se seleccione un fichero del mismo, que luego se copair� a un temporal del root
# $1 -> Mensaje de inserci�n de dev
# $2 -> Background message
#Return: 0 Ok 1 Err
getFileToTmp() {

    #//// quitar el param 1 (o decirle qu� ficero es y llamar a la func correspondiente)

    msg=$"Inserte un dispositivo USB."
    [ "$1" != "" ] && msg="$1"
    
    insertUSB "$msg" "none" # TODO check return and handle as below
    #TODO verificar que ret es 0, luego se puede montar, y ahora devuelve una part, no un dev, seguir traza para verificar que lo haga bien
    
    $PVOPS getFile mountDev "$1"
    ret=$?
    
    if [ "$ret" -ne 0 ] 
	then
	$dlg --msgbox $"El dispositivo no pudo ser accedido." 0 0 
	return 1
    fi
	      

    ### El usuario puede examinar todo el
    ### contenido del sistema de ficheros (sin, en
    ### principio, poder leer ninguno)
    goodpath=0
    while [ $goodpath -eq 0 ]
      do
      selfile=""
      selfile=$($dlg --backtitle "$2" --fselect /media/USB/ 8 60 2>&1 >&4 )
      ret=$?
      
      if [ "$?" -ne 0 ]
	  then
	  break;
      fi
      
      if [ "$selfile" == "" ]   
	  then
	  break
      fi
		
      #Verificaciones de seguridad:
      parseInput path "$selfile"
      if [ $? -ne 0 ] 
	  then 
	  $dlg --msgbox $"Ruta inv�lida. Los nombres de directorio pueden contener los caracteres: $ALLOWEDCHARSET" 0 0 
	  continue
      fi
      
      aux=$(echo "$selfile" | grep -Ee "^/media/USB/.+")
      if [ "$aux" == "" ] 
	  then
	  $dlg --msgbox $"Ruta inv�lida. Debe ser subdirectorio de /media/USB/" 0 0  
	  continue
      fi
      
      aux=$(echo "$selfile" | grep -Ee "/\.\.(/| |$)")
      if [ "$aux" != "" ] 
	  then
	  $dlg --msgbox $"Ruta inv�lida. No puede acceder a directorios superiores." 0 0  
	  continue
      fi
      
      goodpath=1
    done
    

    if [ $goodpath -eq 0 ]  
	then 
	$PVOPS getFile umountDev
	return 1	
    fi
    
    $PVOPS getFile copyFile "$selfile"
    if [ "$?" -ne 0 ] 
	then 
	$dlg --msgbox $"Error al copiar el fichero." 0 0  
	umount /media/USB; 
	return 1 
    fi
    
    $PVOPS getFile umountDev
    
    return 0
}





#1-> chain and crt destinaton, and csr and key location
installSSLCert () {

    #Pedimos el fichero con el certificado ssl
    getFileToTmp $"Inserte un dispositivo USB del que leer el certificado de servidor y pulse INTRO." $"Seleccione el certificado de servidor"
    ret=$?
    [ "$ret" -ne 0 ] && return 1 
    
    #Verificamos y, si correcto, copiamos el cert a una ubicaci�n temporal (para evitar inconsistencias si falla la carga de la cha
    $PVOPS configureServers "configureWebserver" "checkCertificate" 'serverCert'
    case "$?" in 
	"14" )
        $dlg --msgbox $"Error: el fichero esta vacio." 0 0
        return 1;
        ;;
	"15" )
	$dlg --msgbox $"Error de lectura." 0 0
        return 1;
        ;;
	"16" )
	$dlg --msgbox $"Error: el fichero no contiene certificados PEM." 0 0
        return 1;
        ;;
	"17" )
	$dlg --msgbox $"Error procesando el fichero de certificado." 0 0 
        return 1;
        ;;
	"18" )
	$dlg --msgbox $"El fichero s�lo debe contener el certificado de servidor." 0 0 
        return 1;
        ;;
	"19" )
        $dlg --msgbox $"Error: certificado no v�lido." 0 0
        return 1;
        ;;
	"20" )
        $dlg --msgbox $"Error: el certificado no corresponde con la llave." 0 0  
        return 1;
        ;;
    esac
    
   
    
    #Pedimos el fichero con la cadena de certificaci�n del cert de servidor
    getFileToTmp $"Inserte un dispositivo USB del que leer el fichero con la cadena de certificaci�n y pulse INTRO. (puede dejar el mismo)"  $"Seleccione la cadena de certificaci�n"
    ret=$?
    [ "$ret" -ne 0 ] && return 1
    
    
    $PVOPS configureServers "configureWebserver" "checkCertificate" 'certChain'
    case "$?" in 
	"14" )
        $dlg --msgbox $"Error: el fichero esta vacio." 0 0
        return 1;
        ;;
	"15" )
	$dlg --msgbox $"Error de lectura." 0 0
        return 1;
        ;;
	"16" )
	$dlg --msgbox $"Error: el fichero no contiene certificados PEM." 0 0
        return 1;
        ;;
	"17" )
	$dlg --msgbox $"Error procesando el fichero de certificado." 0 0 
        return 1;
        ;;
	"18" )
	$dlg --msgbox $"El fichero s�lo debe contener el certificado de servidor." 0 0 
        return 1;
        ;;
	"19" )
        $dlg --msgbox $"Error: certificado no v�lido." 0 0
        return 1;
        ;;
	"20" )
        $dlg --msgbox $"Error: el certificado no corresponde con la llave." 0 0  
        return 1;
        ;;
    esac
    
    
    $PVOPS configureServers "configureWebserver" "installSSLCert"
    ret=$?
    if [ "$ret" -eq 1 ] 
	then
	#No ha verificado. Avisamos y salimos
	$dlg --msgbox $"Fallo de verificaci�n de la cadena de certificaci�n.\nEsto puede ser debido a que el sistema no reconoce la CA ra�z. Se aborta el proceso" 0 0 
	return 1
    fi
    if [ "$ret" -eq 2 ] 
	then 
	return 1
    fi

    return 0
}





#RETURN: $emaillist --> Lista de correos electr�nicos
getEmailList () {

    #Pedir listado de correos electr�nicos de los interesados en recibir copia del/los fichero/s
    echo "" > /tmp/emptyfile
    while true; do
	emaillist=$($dlg --backtitle $"Escriba el listado de destinatarios (uno por l�nea)." --editbox /tmp/emptyfile 0 0  2>&1 >&4)
	emlcanceled=$?
    
	[ "$emlcanceled" -ne 0  ] &&  return 1

	if [ "$emaillist" == ""  ]
	    then
	    $dlg --msgbox $"Debe especificar al menos una direcci�n." 0 0
	    continue
	fi
	
	
	echo "$emaillist" > /tmp/emptyfile

        #Comprobamos la lista de correos
	for eml in $emaillist; do 
	    echo "$eml"  >>$LOGFILE 2>>$LOGFILE
	    parseInput email "$eml"
	    if [ $? -ne 0 ] 
		then
		$dlg --msgbox $"Existen direcciones de correo no v�lidas." 0 0
		continue 2
	    fi
	done
	
	break
    done
    
    
    return 0
}






systemMonitorScreen () {

    refresh=true
    while $refresh ;
      do
      
      $PVOPS stats > /tmp/stats  2>>$LOGFILE
      
      # 0 -> refrescar
      # 3 -> volver
      #No me vale un msgbox pq s�lo puede llevar un button, y el yesno tampoco porque no hace scroll
      $dlg --ok-label $"Refrescar" --extra-button  --extra-label $"Volver" --no-cancel --textbox /tmp/stats 0 0
      
      [ $? -ne 0 ] && refresh=false
    done
    
    rm -f /tmp/stats  >>$LOGFILE  2>>$LOGFILE
}





























maintenanceActionMenu () {  #////probar que al darle a esc, se queda en el bucle.

    
    #Entrada variable del men� sobre operaciones del certificado ssl
    sslmenuitem=$"Operaciones sobre el certificado SSL del servidor web."
    [ "$sslCertState" == "NOCERT" ] && sslmenuitem=$"Cambiar a modo de servidor web con certificado SSL."


    #Entrada variable del men� sobre las operaciones sobre el backup backup
    backuplinetag="10"
    backuplinemsg=$"Cambiar par�metros de copia de seguridad remota."
    [ "$SSHBAKSERVER" == "" ] && backuplinetag="" && backuplinemsg=""
    
    
    while true; do

	exec 4>&1 
	selec=$($dlg --no-cancel  --menu $"El sistema est� en marcha.\nSi lo desean pueden realizar alguna de estas acciones:" 0 80  14  \
	    01  $"Otorgar privilegios al administrador del sistema de voto temporalmente." \
	    02  $"Resetear credenciales del administrador del sistema de voto." \
	    03  $"Crear nuevo administrador del sistema de voto." \
	    04  $"Verificar la integridad de las piezas de la llave." \
	    05  $"Cambiar llave de cifrado de disco." \
	    06  $"Trasladar datos cifrados a otra ubicaci�n." \  # TODO para esto, no ser�a mejor hacerlo como un procedimiento de backup y restauraci�n? se instala un nuevo sistema y se restaura la copia. # TODO adem�s, asegurarme que en el backup se para el servidir web o al menos se bloquean los cambios persistentes
	    07  "$sslmenuitem" \
	    08  $"Cambiar par�metros del servidor de correo" \
	    09  $"Cambiar par�metros de acceso a la red" \
	    "$backuplinetag"   "$backuplinemsg" \
	    11  $"Resetear estad�sticas de uso del sistema." \
	    12  $"Monitor del estado del sistema." \
	    13  $"Suspender el equipo." \
	    14  $"Lanzar un terminal de administraci�n." \
	    15  $"Apagar el equipo." \
	    2>&1 >&4) # TODO reformular en dos niveles, agrupar funciones
	
	echo "Selecci�n: $selec"   >>$LOGFILE 2>>$LOGFILE
    
	
	case "$selec" in
	    
	"01" )
        MAINTACTION="grantadminprivs"
        ;;

	"02" )
        MAINTACTION="resetadmin"
        ;;

	"03" )
        MAINTACTION="newadmin"
        ;;

	"04" )
        MAINTACTION="verify"
        ;;
	
	"05" )
        MAINTACTION="newouterkey"
        ;;
	
	"06" )
        MAINTACTION="newinnerkey"
        ;;

	"07" )
        MAINTACTION="sslcert"
        ;;

	"08" )
        MAINTACTION="mailerparams"
        ;;

	"09" )
        MAINTACTION="networkparams"
        ;;

	"10" )
        MAINTACTION="backupparams"
        ;;

	"11" )
        MAINTACTION="resetrrds"
        ;;

	"12" )
        MAINTACTION="monitor"
        ;;

	"13" )
        MAINTACTION="suspend"
	;;
	
	"14" )
        MAINTACTION="terminal"
        ;;
	
	"15" )
        MAINTACTION="shutdown"	
        ;;

	* )
	#Si la selecci�n es mala, repetir ad infinitum
	MAINTACTION=""
	continue
	;;

	esac   

	#Si la selecci�n era correcta, sale del bucle 
        break

    done

}





sslActionMenu () {

    #El caso de pasar del modo sin ssl al modo con ssl es especial.
    if [ "$sslCertState" == "NOCERT" ] ; then
	MAINTACTION="sslcert-new"
	return 0
    fi


    #Si el estado es DUMMY: 'releer csr 4'      'instalar cert 1'
    #Si el estado es OK:    'reinstalar cert 1' 'regenerar cert 3'
    #Si el estado es RENEW: 'releer csr 5'      'instalar nuevo cert 2'
    case "$sslCertState" in
	"DUMMY" )
	crtstatestr=$"El sistema est� funcionando con un certificado de prueba."
	op1val="4"
	op1str=$"Releer petici�n de certificado."
	op2val="1" 
	op2str=$"Instalar certificado."
        ;;
	
	"OK" )
	crtstatestr=$"El sistema est� funcionando con un certificado v�lido."
	op1val="1"
	op1str=$"Instalar un certificado renovado sin cambiar la llave privada."
	op2val="3" 
	op2str=$"Renovar el certificado y la llave privada."
        ;;

	"RENEW" )
	crtstatestr=$"El sistema est� esperando la renovaci�n del certificado."
	op1val="5"
	op1str=$"Releer petici�n de certificado."
	op2val="2" 
	op2str=$"Instalar certificado renovado."
        ;;
		
	* )
	echo "Error: bad cert state: $sslCertState."  >>$LOGFILE 2>>$LOGFILE
	MAINTACTION=""
	doLoop
        ;;	
    esac
 
    
    exec 4>&1 
    selec=$($dlg  --menu "$crtstatestr" 0 80  3  \
	"$op1val" "$op1str" \
	"$op2val" "$op2str" \
	2>&1 >&4)
    
    
    case "$selec" in
	
	"1" )
        MAINTACTION="sslcert-installcurr"
        ;;

	"2" )
        MAINTACTION="sslcert-installnew"
        ;;
	
	"3" )
        MAINTACTION="sslcert-renew"
        ;;
		
	"4" )
        MAINTACTION="sslcert-getcurrcsr"
        ;;
		
	"5" )
        MAINTACTION="sslcert-getnewcsr"
        ;;
		
	* )
	echo "Error: bad selection in ssl submenu."  >>$LOGFILE 2>>$LOGFILE
	#Back
	MAINTACTION=""
	doLoop
        ;;
	
    esac
    
    return 0

}























########################## Blucle principal  ##############################


standBy () {
    
    #Muestra el menu
    maintenanceActionMenu
    
      
    #Submen� de operaciones con el certificado ssl
    [ "$MAINTACTION" == "sslcert" ] && sslActionMenu
}


#Si la acci�n es no privilegiada, se ejecuta y se resetea el bucle.  # TODO refactor this. Create a verify key function and call it before any op that requires to
executeUnprivilegedAction () {

#  non: sslcert-getcurrcsr sslcert-getnewcsr


    ### Acciones que requieren o no autorizaci�n seg�n ciertas condiciones ###

    #Dejaremos instalar un certificado sin la verifiaci�n de la comisi�n
    # sii el certificado presente no verifica (es autofirmado)
    if [ "$MAINTACTION" == "sslcert-installcurr" -o "$MAINTACTION" == "sslcert-installnew" ]  #////continuar. pasar a privop sin verif.
	then
	verifyCert $DATAPATH/webserver/server.crt $DATAPATH/webserver/ca_chain.pem
	BYPASSAUTHORIZATION=$?
	echo "BYPASSAUTHORIZATION $MAINTACTION: $BYPASSAUTHORIZATION" >>$LOGFILE  2>>$LOGFILE
	if [ "$BYPASSAUTHORIZATION" -eq 0]
	    then
	    echo "La op es verificada (condicionalmente)" >>$LOGFILE 2>>$LOGFILE
	    return 1
	fi
    fi


    #Acciones que no requieren autorizaci�n nunca
    if [ "$MAINTACTION" != "shutdown" -a "$MAINTACTION" != "monitor" -a "$MAINTACTION" != "suspend" -a "$MAINTACTION" != "sslcert-getnewcsr" ]
	then
	echo "La op es verificada" >>$LOGFILE 2>>$LOGFILE
	return 1
    fi
  

    #Si llega aqu�, la op no requiere auth. Se ejecuta ya y loop.
    $dlg --msgbox $"Esta operaci�n no requiere autorizaci�n para ser ejecutada." 0 0
    ret=0

    executeSystemAction

    doLoop
}







obtainClearance () {

    #Requiere auth
    $dlg --msgbox $"Para verificar la autoridad para realizar esta acci�n, procedemos a pedir los fragmentos de llave." 0 0
 	  
    #Pide reconstruir llave s�lo para verificar que se tiene autorizaci�n de acceso 
    getClauersRebuildKey  k
    ret=$?
      
    if [ "$ret" -ne 0 ]
	then
	$dlg --msgbox $"No se ha logrado reconstruir la llave. Acceso denegado." 0 0
	doLoop
    fi

    $PVOPS storops checkClearance
    ret=$?    


    if [ "$ret" -eq 1 -o "$ret" -eq 2  ]
	then
	$dlg --msgbox $"No se ha obtenido ninguna llave. Acceso denegado." 0 0
	doLoop
    fi

    if [ "$ret" -eq 3 ]
	then
	$dlg --msgbox $"La llave obtenida no es correcta. Acceso denegado." 0 0
	doLoop
    fi
    
}




# Depende de la var de entorno MAINTACTION
executeSystemAction (){


  
    #Acciones a llevar a cabo en cada operaci�n de mantenimiento # TODO ojo. aqu� falta c�digo. revisar a fondo el script de la versi�n 1.0.2, creo que s�lo falta de las ops de mant no revisadas
    case "$MAINTACTION" in 

 
      # //// ++++  revisar todas las acciones de mantenimiento. pasar a privops lo que sea. Los elementos no comunes pasarlos a cada fichero.

      ######### Otorga privilegios al admin de la app por una sesi�n ########
      "grantadminprivs" )
        

        grantAdminPrivileges grant
	
	while true; do
	    
	    $dlg --msgbox $"Ahora puede operar como administrador a trav�s de la aplicaci�n web de voto.\n\nRecuerde que esto debe realizarse bajo la supervisi�n de la comisi�n.\n\nPulse INTRO para retirar estos privilegios." 0 0 
	    
	    $dlg --no-label $"Retirar"  --yes-label $"Atr�s" --yesno  $"�Desea retirar los privilegios de administrador?" 0 0 
	    [ "$?" -eq "1" ] && break
	done
	

        grantAdminPrivileges remove
        
      ;;


      ######### Resetea las credenciales del admin de la app (contrase�a local, IP, Clauer y adem�s le da privilegios)########
      "resetadmin" )
      
      $dlg --msgbox $"Va a resetear la contrase�a del usuario administrador." 0 0


# TODO cargar tambi�n los default de las vars de abajo aqu� 
# TODO para saber qui�n es el administrador actual, ver el valor default
# TODO: en resumen: esta interfaz permitir� pner todos los valores para el admin y los mostrar� como defaults si ya exist�an. Para el instalador, no sacar nada e insertar new user. Para el new admin, sacar en blanco y update/insert seg�n si existe el username o no (y el dni?). para el new pwd del admin actual, sacar lo mismo relleno.
# TODO Adem�s, no distinguir entre nuevo o viejo. Sacar todos los datos y actualizarlos/insertarlos todos


      
      sysAdminParams lock
      [ $? -ne 0 ] && return 1 # TODO ver la op de abajo
      
      $PVOPS resetAdmin "$MGRPWD" "$ADMINNAME" "$ADMREALNAME" "$ADMIDNUM" "$MGREMAIL" "$LOCALPWD" "$ADMINIP" # TODO revisar esta op y ver que hace lo que espero, que es dejar el mismo admin y cambiar sus pwds
      
      #Adem�s, da privilegios al administrador
      grantAdminPrivileges grant
      
      $dlg --msgbox $"Adicionalmente, el sistema ha otorgado privilegios para el administrador. Estos se invalidar�n en cuanto realice alguna otra operaci�n de mantenimiento." 0 0
      
      ;;


      ######### Resetea las credenciales del admin de la app (contrase�a local, IP, Clauer y adem�s le da privilegios)########
      "newadmin" )
      
      $dlg --msgbox $"Va a crear un usuario administrador nuevo." 0 0


      # TODO aqu� no cargar defaults
      
# TODO para saber qui�n es el administrador actual, ver el valor default (lo cargo aqu�? yo creoque no. si hace falta para quitarle los privs, hacerlo en la op priv)
# TODO: en resumen: esta interfaz permitir� pner todos los valores para el admin y los mostrar� como defaults si ya exist�an. Para el instalador, no sacar nada e insertar new user. Para el new admin, sacar en blanco y update/insert seg�n si existe el username o no (y el dni?). para el new pwd del admin actual, sacar lo mismo relleno.
# TODO Adem�s, no distinguir entre nuevo o viejo. Sacar todos los datos y actualizarlos/insertarlos todos
      
      sysAdminParams
      [ $? -ne 0 ] && return 1 # TODO ha cancelado la operaci�n. Ver si esto est� bien implementado seg�n el flujo (o revisar el flujo, y hacerlo para todas la sops. que todas sean cancelables.)
      
      $PVOPS resetAdmin "$MGRPWD" "$ADMINNAME" "$ADMREALNAME" "$ADMIDNUM" "$MGREMAIL" "$LOCALPWD" "$ADMINIP"#TODO revisar esta op y asegurarme de que hace lo que espero, que es cambiar el admin por otro. all� deber� mirar el admin actual y quitarle dicho privilegio.

      # TODO en alg�n punto se tendr�n qu actualizar las vars en privileged. ya sea aqu� fuera o al llamara  resetadmin. decidir d�nde.
      
      #Adem�s, da privilegios al administrador
      grantAdminPrivileges grant
      
      $dlg --msgbox $"Adicionalmente, el sistema ha otorgado privilegios para el administrador. Estos se invalidar�n en cuanto realice alguna otra operaci�n de mantenimiento." 0 0
      
      ;;


      ######### Monitor ########
      "monitor" )
      systemMonitorScreen
      ;;


      ######### Suspender ########
      "suspend" )

	$dlg --clear --yes-label $"Cancelar"  --no-label $"Suspender" --yesno $"�Est� seguro de que desea suspender el equipo?" 0 0
	ret=$?	
	if [ $ret -eq 1 ] ; then
	    $PVOPS suspend
	    ret=$?	
	fi
		
	if [ "$ret" -eq 1 ]
	    then
	    $dlg --msgbox $"Por razones de seguridad no se puede suspender el equipo, al no hallarse el disco copiado en RAM." 0 0
	    return 1
	fi
	#Al levantarse, volver� aqu� 
	return 0

      ;;


      ######### Apagar ########
      "shutdown" )
        
        $dlg --yes-label $"Cancelar"  --no-label $"Apagar" --yesno $"�Est� seguro de que desea apagar el equipo?" 0 0
	ret=$?
	[ $ret -eq 1 ] && shutdownServer "h"
	return 0
        
      ;;	
		

      ######### Lanza un terminal, para casos desesperados. ######### 
      "terminal" )
      
	$dlg --msgbox $"ATENCI�N:\n\nHa elegido lanzar un terminal. Esto otorga al manipulador del equipo acceso a datos sensibles hasta que finalice la sesi�n. Aseg�rese de que no sea operado sin supervisi�n t�cnica para verificar que no se realiza ninguna acci�n il�cita. Sus acciones ser�n registradas y enviadas a la lista de destinatarios interesados, que se solicita a continuaci�n." 0 0
	
	
        #Pedir listado de correos electr�nicos de receptores del bash_history
	getEmailList 
	if [ $? -eq 1  ] 
	    then
	    $dlg --msgbox $"Se ha cancelado la sesi�n de terminal." 0 0 
	    return 1
	fi
	
	$PVOPS launchTerminal
	
      ;;


      ######### Resetea las RRD de estad�ticas del sistema ########
      "resetrrds" )
      
        $dlg  --yes-label $"S�"  --no-label $"No"   --yesno  $"�Seguro que desea reiniciar la recogida de estaditicas del sistema?" 0 0 
	[ "$?" -ne "0" ] && return 1
      
	#Resetemaos las estad�sticas
	$PVOPS stats resetLog
	
	$dlg --msgbox $"Reinicio completado con �xito." 0 0
	
      ;;
      

      ######### Operaciones con el cert del servidor. ######### 

      "sslcert-getcurrcsr" )
        fetchCSR "new" #No hay cambio de estado  
      ;;

      "sslcert-getnewcsr" )
        fetchCSR "renew" #No hay cambio de estado  
      ;;
 
      "sslcert-installcurr" | "sslcert-installnew" )
      
      installSSLCert "$DATAPATH"
      ret=$?

      if [ "$ret" -eq 0 ]; then
	  $dlg --msgbox $"Certificado instalado correctamente." 0 0
      else
	  $dlg --msgbox $"Error instalando el certificado." 0 0
      fi
      ;;

      
      "sslcert-renew" )
      
      generateCSR "renew"
      ret=$?

      echo "Retorno de generateCSR: $ret"  >>$LOGFILE 2>>$LOGFILE
      
      if [ "$ret" -eq 0 ]; then

          #Escribimos el pkcs10 en la zona de datos de un clauer
	  $dlg --msgbox $"Se ha generado una petici�n de certificado SSL para este servidor.\nPor favor, prepare un dispositivo USB para almacenarla (puede ser uno de los Clauers empleados ahora).\nEsta petici�n deber� ser entregada a una Autoridad de Certificacion confiable para su firma.\n\nHaga notar al encargado de este proceso que en un fichero adjunto debe proporcionarse toda la cadena de certificaci�n." 0 0
	  
	  fetchCSR "renew"

	  echo -n "RENEW" > $DATAPATH/root/sslcertstate.txt	  

	  $dlg --msgbox $"Petici�n de certificado generada correctamente." 0 0
      else
	  $dlg --msgbox $"Error generando la nueva petici�n de certificado." 0 0	  
      fi
      
      ;;
      
      
      "sslcert-new" )
      
      $dlg --yesno $"Ha elegido utilizar el servidor con certificado SSL. Si completa esta acci�n, ya no se permitir acceder al servidor de voto sin cifrado. Deber� solicitar y comprar un certificado de una autoridad confiable. �Desea continuar?" 0 0 
      [ "$?" -ne 0 ] &&  return 0
      
      
      generateCSR "new"	
      ret=$?
      echo "Retorno de generateCSR: $ret"  >>$LOGFILE 2>>$LOGFILE
      
      if [ "$ret" -eq 0 ]; then
	  
          #EScribimos el pkcs10 en la zona de datos de un clauer
	  $dlg --msgbox $"Se ha generado una petici�n de certificado SSL para este servidor.\nPor favor, prepare un dispositivo USB para almacenarla (puede ser uno de los Clauers empleados ahora).\nEsta petici�n deber� ser entregada a una Autoridad de Certificacion confiable para su firma.\n\nHaga notar al encargado de este proceso que en un fichero adjunto debe proporcionarse toda la cadena de certificaci�n." 0 0
	  
	  fetchCSR "new"
	  	  
	  
	  $PVOPS configureServers "configureWebserver" "dummyCert"

	  $PVOPS configureServers "configureWebserver" "wsmode"

	  $PVOPS configureServers "configureWebserver" "finalConf"
      	 

	  $dlg --msgbox $"Servidor web configurado correctamente." 0 0
      else
	  $dlg --msgbox $"Error configurando el servidor web." 0 0	  
      fi

      ;;


      ######### Permite modificar los par�metros del servidor de correo. ######### 
      "mailerparams" )
       
      #Sacamos el formulario de par�metros del mailer
      mailerParams
      
      $dlg --infobox $"Configurando servidor de correo..." 0 0

      setVar disk MAILRELAY "$MAILRELAY"
      
      $PVOPS configureServers mailServerM

      [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de correo."
            
      ;;


      ######### Permite modificar los par�metros del backup cuando es modo local. ######### 
      "backupparams" )
      
      
      $dlg --no-label $"Continuar"  --yes-label $"Cancelar" --yesno  $"Dado que se van a modificar par�meros de configuraci�n b�sicos, estos deben ser escritos en los Clauers.\n\nAseg�rese de que se reuna toda la comisi�n.\n\nPrepare un conjunto de Clauers nuevo, diferente al actual.\n\nLa llave de cifrado ser� renovada, invalidando la actual.\n\n�Seguro que desea continuar?" 0 0 
      [ "$?" -eq "0" ] && return 1
      
      
      #Pedimos los nuevos par�metros
      while true; do
	  selectDataBackupParams # TODO: now the function has changed. 
	  if [ "$?" -ne 0 ] 
	      then 
	      $dlg --msgbox $"Debe introducir los par�metros de copia de seguridad." 0 0
	      continue
	  fi
	  
	  $dlg --infobox $"Verificando acceso al servidor de copia de seguridad..." 0 0

# TODO revisar bien. que no se guarden los nuevos valores a menos que todo funcione bien, o decirles de repetir (ver la op en el setup). Para la prueba se guarda el trust en el unprivi�leged, pero hay que llamar a l�a op priv para guardarla para cuando el root acceda (seguro? vewr el script de backup a ver si all� la a�ade siempre o espera que est� a�adida. si es lo primero, borrar de aqu� y de cualquier sitio donde se haga eso)

   #Verificar acceso al servidor # Expects:  "$SSHBAKSERVER" "$SSHBAKPORT" "$SSHBAKUSER" "$SSHBAKPASSWD"
	  checkSSHconnectivity
   if [ "$?" -ne 0 ] 
	      then 
	      $dlg --msgbox $"Error accediendo al servidor de copia de seguridad. Revise los datos." 0 0 
	      continue
	  fi

   
	  #A�adimos las llaves del servidor SSH al known_hosts del root
	  $PVOPS trustSSHServer "$SSHBAKSERVER" "$SSHBAKPORT"
	  if [ $? -ne 0 ] ; then
	      $dlg --msgbox $"Error configurando el acceso al servidor de copia de seguridad." 0 0
	      continue
	  fi


	 	  
	  break
	  
      done

	  
	  #////guardamos los nuevos valores de dichos params en fich de clauer y en disco --> asegurarme de que exista el fichero de config de clauer con los par�metros que tocan. Ver c�mo hac�a para grabarlo, si uso el mismo fichero o lo duplicaba o algo y hacerlo aqu�. Ojo a la nueva llave generada, la vieja y la autorizaci�n para ejecutar ops.
	  #SSHBAKSERVER=$(getVar disk SSHBAKSERVER)
	  # set en vez de get, y set en c y en d, y despu�s de verificar..  SSHBAKPORT=$(getVar disk SSHBAKPORT)

      #Generar nueva llave externa y almacenarla en un set de clauers.



#	$PSETUP enableBackup	    


# TODO functionality to enable/disable backup and add option to  change bak params  on the menu
	  
	

  #Ahora se regenera la llave de cifrado.
      $dlg --msgbox $"Ahora se proceder� a construir el nuevo conjunto de Clauers. Podr� elegir los par�metros de compartici�n de la nueva llave." 0 0 
      


      
      
      
      ;;


      ######### Permite modificar los par�metros de acceso a internet. ######### 
      "networkparams" )
   $dlg --msgbox "Still not reviewed." 0 0
      ;;


      ######### Verificaci�n de la integridad de las piezas de la llave. #########
      "verify" )
      $dlg --msgbox "Still not reviewed." 0 0 
      ;;

	
      ######### Se cambia la llave compartida entre los custodios. ######### 
      #Permite cambiar los par�metros de compartici�n.
      "newouterkey" )
      $dlg --msgbox "Still not reviewed." 0 0 
      ;;	


      ######### Se cambia la llave interna del sistema. ######### ### TODO extinguir esta opci�n. Si hay un compromiso de la llave interna, hacer un backup y un restore y a correr.
      #Requiere reubicar todos los datos cifrados en otra localizaci�n (permite elegir de nuevo el modo)
      "newinnerkey" )
      $dlg --msgbox "Still not reviewed." 0 0 
      ;;


      * )          
        echo "systemPanic: bad selection."
	shutdownServer "h"
      ;;
      
    esac

}

#Lo que vendr�a a ser un continue pero con el bucle a nivel de proceso que uso.
doLoop () {
    exec /bin/bash  /usr/local/bin/wizard-maintenance.sh
}


##################
#  Main Program  #
##################


# TODO add a maint option to join esurvey lcn network (if not done during setup, and also to change registration)

#//// Variables a leer cada vez que se lance este script: # TODO revisar esto. probablemente faltan, pero leerlas en cada func, seg�n hagan falta mejor
MGREMAIL=$(getVar disk MGREMAIL)
ADMINNAME=$(getVar disk ADMINNAME)

SHARES=$(getVar usb SHARES)

copyOnRAM=$(getVar mem copyOnRAM)

# TODO leer estas variables para el modo mant? para default en la op de renovar cert ssl?
#"$HOSTNM.$DOMNAME"

sslCertState=$($PVOPS getSslCertState)
[ "$sslCertState" == "" ] && echo "Error: deber�a existir alg�n estado para el cert."  >>$LOGFILE 2>>$LOGFILE
  
	#Ver cu�les son estrictamente necesarias. borrar el resto////
#	setVarFromFile  $VARFILE MGREMAIL
#	setVarFromFile  $VARFILE ADMINNAME






#Matamos el daemon de entrop�a, porque, aunque no la carga mucho, consume mucho tiempo de CPU sin hacer nada.
$PVOPS randomSoundStop

#Revocamos el permiso para ejecutar ops privilegiadas.
$PVOPS storops resetAllSlots



#Muestra el men� de opciones y procesa la entrada de usuario
MAINTACTION=''
standBy



#De forma preventiva, anulamos los privilegios de admin. (Si se han elegido en el menu, lo hace en executesystemaction)
grantAdminPrivileges remove


#Reactivamos el daemonde entrop�a, por si hace falta
$PVOPS randomSoundStart
    


#Si la acci�n es no privilegiada, se ejecuta ahora y se resetea el bucle.
executeUnprivilegedAction



#Solicitamos los clauers y reconstru�mos la clave para autorizar la operaci�n.
obtainClearance



#Ejecuta la operaci�n solicitada
executeSystemAction "running"



#Revocamos el permiso para ejecutar ops privilegiadas (por paranoia).
$PVOPS storops resetAllSlots

#Relanzamos el bucle.
doLoop




