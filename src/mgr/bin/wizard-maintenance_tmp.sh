#!/bin/bash



##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh




#Log function
log () {
    echo "["$(date --rfc-3339=ns)"][wizard-maintenance]: "$*  >>$LOGFILE 2>>$LOGFILE
}




#Fatal error function. Will reset the maintenance application
#$1 -> error message
resetLoop () {
    #Show error message to the user
    log "$1"
    $dlg --msgbox "$1" 0 0
    
    #Return to the maintenance idle loop
	   exec /bin/bash  /usr/local/bin/wizard-maintenance.sh
    shutdownServer "h" #This will never be executed
} # TODO Call this everywhere there's an error that needs to go back to the loop







# SEGUIR REVISANDO




# Pide que se inserte un dev USB y que se seleccione un fichero del mismo, que luego se copairá a un temporal del root
# $1 -> Mensaje de inserción de dev
# $2 -> Background message
#Return: 0 Ok 1 Err
getFileToTmp() {

    #//// quitar el param 1 (o decirle qué ficero es y llamar a la func correspondiente)

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
	           $dlg --msgbox $"Ruta inválida. Los nombres de directorio pueden contener los caracteres: $ALLOWEDCHARSET" 0 0 
	           continue
        fi
        
        aux=$(echo "$selfile" | grep -Ee "^/media/USB/.+")
        if [ "$aux" == "" ] 
	       then
	           $dlg --msgbox $"Ruta inválida. Debe ser subdirectorio de /media/USB/" 0 0  
	           continue
        fi
        
        aux=$(echo "$selfile" | grep -Ee "/\.\.(/| |$)")
        if [ "$aux" != "" ] 
	       then
	           $dlg --msgbox $"Ruta inválida. No puede acceder a directorios superiores." 0 0  
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

    ## TODO make sure to rename the chosen files to the expected names.

    # TODO make sure the cert file is validated

    # TODO make sure all the cert chain is validated before accepting it

    ## TODO restart el apache y el postfix

    #Pedimos el fichero con el certificado ssl
    getFileToTmp $"Inserte un dispositivo USB del que leer el certificado de servidor y pulse INTRO." $"Seleccione el certificado de servidor"
    ret=$?
    [ "$ret" -ne 0 ] && return 1 
    
    #Verificamos y, si correcto, copiamos el cert a una ubicación temporal (para evitar inconsistencias si falla la carga de la cha
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
	           $dlg --msgbox $"El fichero sólo debe contener el certificado de servidor." 0 0 
            return 1;
            ;;
	       "19" )
            $dlg --msgbox $"Error: certificado no válido." 0 0
            return 1;
            ;;
	       "20" )
            $dlg --msgbox $"Error: el certificado no corresponde con la llave." 0 0  
            return 1;
            ;;
    esac
    
    
    
    #Pedimos el fichero con la cadena de certificación del cert de servidor
    getFileToTmp $"Inserte un dispositivo USB del que leer el fichero con la cadena de certificación y pulse INTRO. (puede dejar el mismo)"  $"Seleccione la cadena de certificación"
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
	           $dlg --msgbox $"El fichero sólo debe contener el certificado de servidor." 0 0 
            return 1;
            ;;
	       "19" )
            $dlg --msgbox $"Error: certificado no válido." 0 0
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
	       $dlg --msgbox $"Fallo de verificación de la cadena de certificación.\nEsto puede ser debido a que el sistema no reconoce la CA raíz. Se aborta el proceso" 0 0 
	       return 1
    fi
    if [ "$ret" -eq 2 ] 
	   then 
	       return 1
    fi

    return 0
}




# TODO SEGUIR MAÑANA
#RETURN: $emaillist --> Lista de correos electrónicos
getEmailList () {

    #Pedir listado de correos electrónicos de los interesados en recibir copia del/los fichero/s
    echo "" > /tmp/emptyfile
    while true; do
	       emaillist=$($dlg --backtitle $"Escriba el listado de destinatarios (uno por línea)." --editbox /tmp/emptyfile 0 0  2>&1 >&4)
	       emlcanceled=$?
        
	       [ "$emlcanceled" -ne 0  ] &&  return 1

	       if [ "$emaillist" == ""  ]
	       then
	           $dlg --msgbox $"Debe especificar al menos una dirección." 0 0
	           continue
	       fi
	       
	       
	       echo "$emaillist" > /tmp/emptyfile

        #Comprobamos la lista de correos
	       for eml in $emaillist; do 
	           log "$eml" 
	           parseInput email "$eml"
	           if [ $? -ne 0 ] 
		          then
		              $dlg --msgbox $"Existen direcciones de correo no válidas." 0 0
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
        #No me vale un msgbox pq sólo puede llevar un button, y el yesno tampoco porque no hace scroll
        $dlg --ok-label $"Refrescar" --extra-button  --extra-label $"Volver" --no-cancel --textbox /tmp/stats 0 0
        
        [ $? -ne 0 ] && refresh=false
    done
    
    rm -f /tmp/stats  >>$LOGFILE  2>>$LOGFILE
}





























maintenanceActionMenu () {  #////probar que al darle a esc, se queda en el bucle.

    
    #Entrada variable del menú sobre operaciones del certificado ssl
    sslmenuitem=$"Operaciones sobre el certificado SSL del servidor web."
    [ "$sslCertState" == "NOCERT" ] && sslmenuitem=$"Cambiar a modo de servidor web con certificado SSL."


    #Entrada variable del menú sobre las operaciones sobre el backup backup
    backuplinetag="10"
    backuplinemsg=$"Cambiar parámetros de copia de seguridad remota."
    [ "$SSHBAKSERVER" == "" ] && backuplinetag="" && backuplinemsg=""
    
    
    while true; do
        ## TODO implementar a dos niveles: primero un menú de grupos de ops, y luego cada grupo tendrá una o más ops
        # Ops de administrador
	       exec 4>&1 ### TODO rehacer y que no se vea el tag con el cod de op, creo que era --no-tag, ver man dialog, y cambiar elñ número por un tag más descriptivo
	       selec=$($dlg --no-cancel  --no-tags --menu $"El sistema está en marcha.\nSi lo desean pueden realizar alguna de estas acciones:" 0 80  14  \
	                    01  $"Otorgar privilegios al administrador del sistema de voto temporalmente." \
	                    02  $"Resetear credenciales del administrador del sistema de voto." \
	                    03  $"Crear nuevo administrador del sistema de voto." \
	                    04  $"Verificar la integridad de las piezas de la llave." \
	                    05  $"Cambiar llave de cifrado de disco." \
	                    06  $"Trasladar datos cifrados a otra ubicación." \  # TODO para esto, no sería mejor hacerlo como un procedimiento de backup y restauración? se instala un nuevo sistema y se restaura la copia. # TODO además, asegurarme que en el backup se para el servidir web o al menos se bloquean los cambios persistentes
	               07  "$sslmenuitem" \
	                   08  $"Cambiar parámetros del servidor de correo" \
	                   09  $"Cambiar parámetros de acceso a la red" \
	                   "$backuplinetag"   "$backuplinemsg" \
	                   11  $"Resetear estadísticas de uso del sistema." \
	                   12  $"Monitor del estado del sistema." \
	                   13  $"Suspender el equipo." \
	                   14  $"Lanzar un terminal de administración." \
	                   15  $"Apagar el equipo." \
	                   2>&1 >&4) # TODO reformular en dos niveles, agrupar funciones
	       
	       echo "Selección: $selec"   >>$LOGFILE 2>>$LOGFILE
        
	       
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
	               #Si la selección es mala, repetir ad infinitum
	               MAINTACTION=""
	               continue
	               ;;

	       esac   

	       #Si la selección era correcta, sale del bucle 
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
	crtstatestr=$"El sistema está funcionando con un certificado de prueba."
	op1val="4"
	op1str=$"Releer petición de certificado."
	op2val="1" 
	op2str=$"Instalar certificado."
        ;;
	
	"OK" )
	crtstatestr=$"El sistema está funcionando con un certificado válido."
	op1val="1"
	op1str=$"Instalar un certificado renovado sin cambiar la llave privada."
	op2val="3" 
	op2str=$"Renovar el certificado y la llave privada."
        ;;

	"RENEW" )
	crtstatestr=$"El sistema está esperando la renovación del certificado."
	op1val="5"
	op1str=$"Releer petición de certificado."
	op2val="2" 
	op2str=$"Instalar certificado renovado."
        ;;
		
	* )
	log "Error: bad cert state: $sslCertState." 
	MAINTACTION=""
	doLoop
        ;;	
    esac
 
    
    exec 4>&1 # TODO si este menu tiene tag + label y una es superflua, ocultarla
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
	log "Error: bad selection in ssl submenu." 
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
    
      
    #Submenú de operaciones con el certificado ssl
    [ "$MAINTACTION" == "sslcert" ] && sslActionMenu
}


#Si la acción es no privilegiada, se ejecuta y se resetea el bucle.  # TODO refactor this. Create a verify key function and call it before any op that requires to
executeUnprivilegedAction () {

#  non: sslcert-getcurrcsr sslcert-getnewcsr


    ### Acciones que requieren o no autorización según ciertas condiciones ###

    #Dejaremos instalar un certificado sin la verifiación de la comisión
    # sii el certificado presente no verifica (es autofirmado)
    if [ "$MAINTACTION" == "sslcert-installcurr" -o "$MAINTACTION" == "sslcert-installnew" ]  #////continuar. pasar a privop sin verif.
	then
	verifyCert $DATAPATH/webserver/server.crt $DATAPATH/webserver/ca_chain.pem
	BYPASSAUTHORIZATION=$?
	log "BYPASSAUTHORIZATION $MAINTACTION: $BYPASSAUTHORIZATION"
	if [ "$BYPASSAUTHORIZATION" -eq 0]
	    then
	    log "La op es verificada (condicionalmente)"
	    return 1
	fi
    fi


    #Acciones que no requieren autorización nunca
    if [ "$MAINTACTION" != "shutdown" -a "$MAINTACTION" != "monitor" -a "$MAINTACTION" != "suspend" -a "$MAINTACTION" != "sslcert-getnewcsr" ]
	then
	log "La op es verificada"
	return 1
    fi
  

    #Si llega aquí, la op no requiere auth. Se ejecuta ya y loop.
    $dlg --msgbox $"Esta operación no requiere autorización para ser ejecutada." 0 0
    ret=0

    executeSystemAction

    doLoop
}







obtainClearance () {

    #Requiere auth
    $dlg --msgbox $"Para verificar la autoridad para realizar esta acción, procedemos a pedir los fragmentos de llave." 0 0
 	  
    #Pide reconstruir llave sólo para verificar que se tiene autorización de acceso 
    readUsbsRebuildKey  keyonly
    ret=$?
      
    if [ "$ret" -ne 0 ]
	then
	$dlg --msgbox $"No se ha logrado reconstruir la llave. Acceso denegado." 0 0
	doLoop
    fi

    $PVOPS storops-checkKeyClearance
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


  
    #Acciones a llevar a cabo en cada operación de mantenimiento # TODO ojo. aquí falta código. revisar a fondo el script de la versión 1.0.2, creo que sólo falta de las ops de mant no revisadas
    case "$MAINTACTION" in 

 
      # //// ++++  revisar todas las acciones de mantenimiento. pasar a privops lo que sea. Los elementos no comunes pasarlos a cada fichero.

      ######### Otorga privilegios al admin de la app por una sesión ########
      "grantadminprivs" )
        

$PVOPS  grantAdminPrivileges
	
	while true; do
	    
	    $dlg --msgbox $"Ahora puede operar como administrador a través de la aplicación web de voto.\n\nRecuerde que esto debe realizarse bajo la supervisión de la comisión.\n\nPulse INTRO para retirar estos privilegios." 0 0 
	    
	    $dlg --no-label $"Retirar"  --yes-label $"Atrás" --yesno  $"¿Desea retirar los privilegios de administrador?" 0 0 
	    [ "$?" -eq "1" ] && break
	done
	

$PVOPS  removeAdminPrivileges
        
      ;;


      ######### Resetea las credenciales del admin de la app (contraseña local, IP, Clauer y además le da privilegios)########
      "resetadmin" )
      
      $dlg --msgbox $"Va a resetear la contraseña del usuario administrador." 0 0



# TODO cargar también los default de las vars de abajo aquí 
# TODO para saber quién es el administrador actual, ver el valor default
      # TODO: en resumen: esta interfaz permitirá pner todos los valores para el admin y los mostrará como defaults si ya existían. Para el instalador, no sacar nada e insertar new user. Para el new admin, sacar en blanco y update/insert según si existe el username o no (y el dni?). para el new pwd del admin actual, sacar lo mismo relleno.
      #      # TODO ya que se pueden cambiar los datos del admin en la BD, no sería mejor cargarlos de allí en vez de vars? si decido esto, borrar la svars inútiles que se guarden/carguen en el setup
      
# TODO Además, no distinguir entre nuevo o viejo. Sacar todos los datos y actualizarlos/insertarlos todos


      
      sysAdminParams lock
      [ $? -ne 0 ] && return 1 # TODO ver la op de abajo
      
      $PVOPS setAdmin reset "$ADMINNAME" "$MGRPWD" "$ADMREALNAME" "$ADMIDNUM" "$ADMINIP" "$MGREMAIL" "$LOCALPWD" # TODO make sure the ip and two passwords are set here, (and the username) the rest are useless
      
      #Además, da privilegios al administrador
$PVOPS  grantAdminPrivileges
      
      $dlg --msgbox $"Adicionalmente, el sistema ha otorgado privilegios para el administrador. Estos se invalidarán en cuanto realice alguna otra operación de mantenimiento." 0 0
      
      ;;


      ######### Resetea las credenciales del admin de la app (contraseña local, IP, Clauer y además le da privilegios)########
      "newadmin" )
      
      $dlg --msgbox $"Va a crear un usuario administrador nuevo." 0 0


      # TODO aquí no cargar defaults
      
# TODO para saber quién es el administrador actual, ver el valor default (lo cargo aquí? yo creoque no. si hace falta para quitarle los privs, hacerlo en la op priv)
# TODO: en resumen: esta interfaz permitirá pner todos los valores para el admin y los mostrará como defaults si ya existían. Para el instalador, no sacar nada e insertar new user. Para el new admin, sacar en blanco y update/insert según si existe el username o no (y el dni?). para el new pwd del admin actual, sacar lo mismo relleno.
# TODO Además, no distinguir entre nuevo o viejo. Sacar todos los datos y actualizarlos/insertarlos todos
      
      sysAdminParams
      [ $? -ne 0 ] && return 1 # TODO ha cancelado la operación. Ver si esto está bien implementado según el flujo (o revisar el flujo, y hacerlo para todas la sops. que todas sean cancelables.)
      
      $PVOPS setAdmin new "$ADMINNAME" "$MGRPWD" "$ADMREALNAME" "$ADMIDNUM" "$ADMINIP" "$MGREMAIL" "$LOCALPWD" 

      
      #Además, da privilegios al administrador
$PVOPS  grantAdminPrivileges
      
      $dlg --msgbox $"Adicionalmente, el sistema ha otorgado privilegios para el administrador. Estos se invalidarán en cuanto realice alguna otra operación de mantenimiento." 0 0
      
      ;;


      ######### Monitor ########
      "monitor" )
      systemMonitorScreen
      ;;


      ######### Suspender ########
      "suspend" )

	$dlg --clear --yes-label $"Cancelar"  --no-label $"Suspender" --yesno $"¿Está seguro de que desea suspender el equipo?" 0 0
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
	#Al levantarse, volverá aquí 
	return 0

      ;;


      ######### Apagar ########
      "shutdown" )
        
        $dlg --yes-label $"Cancelar"  --no-label $"Apagar" --yesno $"¿Está seguro de que desea apagar el equipo?" 0 0
	ret=$?
	[ $ret -eq 1 ] && shutdownServer "h"
	return 0
        
      ;;	
		

      ######### Lanza un terminal, para casos desesperados. ######### 
      "terminal" )

	
      ;;


      ######### Resetea las RRD de estadíticas del sistema ########
      "resetrrds" )
      
        $dlg  --yes-label $"Sí"  --no-label $"No"   --yesno  $"¿Seguro que desea reiniciar la recogida de estaditicas del sistema?" 0 0 
	[ "$?" -ne "0" ] && return 1
      
	#Resetemaos las estadísticas
	$PVOPS stats resetLog
	
	$dlg --msgbox $"Reinicio completado con éxito." 0 0
	
      ;;
      

      ######### Operaciones con el cert del servidor. ######### 

      # TODO extinguir el  fichero sslcertstate.txt, ahora va todo en una variable en disk, los valores: ok si hay un cert instalado, dummy si está a la espera del primer cert corriendo con un self-signed o renew si está a la espera de un nuevo cert pero corriendo con uno funcional.
      
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

      log "Retorno de generateCSR: $ret" 

      
      if [ "$ret" -eq 0 ]; then

          #Escribimos el pkcs10 en la zona de datos de un clauer
	  $dlg --msgbox $"Se ha generado una petición de certificado SSL para este servidor.\nPor favor, prepare un dispositivo USB para almacenarla (puede ser uno de los Clauers empleados ahora).\nEsta petición deberá ser entregada a una Autoridad de Certificacion confiable para su firma.\n\nHaga notar al encargado de este proceso que en un fichero adjunto debe proporcionarse toda la cadena de certificación." 0 0
	  
	  fetchCSR "renew"

	  echo -n "RENEW" > $DATAPATH/root/sslcertstate.txt	  

	  $dlg --msgbox $"Petición de certificado generada correctamente." 0 0
      else
	  $dlg --msgbox $"Error generando la nueva petición de certificado." 0 0	  
      fi
      
      ;;
      
      
      "sslcert-new" )
      
      $dlg --yesno $"Ha elegido utilizar el servidor con certificado SSL. Si completa esta acción, ya no se permitir acceder al servidor de voto sin cifrado. Deberá solicitar y comprar un certificado de una autoridad confiable. ¿Desea continuar?" 0 0 
      [ "$?" -ne 0 ] &&  return 0
      
      
      generateCSR "new"	
      ret=$?
      log "Retorno de generateCSR: $ret" 
      
      if [ "$ret" -eq 0 ]; then
	  
          #EScribimos el pkcs10 en la zona de datos de un clauer
	  $dlg --msgbox $"Se ha generado una petición de certificado SSL para este servidor.\nPor favor, prepare un dispositivo USB para almacenarla (puede ser uno de los Clauers empleados ahora).\nEsta petición deberá ser entregada a una Autoridad de Certificacion confiable para su firma.\n\nHaga notar al encargado de este proceso que en un fichero adjunto debe proporcionarse toda la cadena de certificación." 0 0
	  
	  fetchCSR "new"
	  	  
	  
	  $PVOPS configureServers "configureWebserver" "dummyCert"

	  $PVOPS configureServers "configureWebserver" "wsmode"

	  $PVOPS configureServers "configureWebserver" "finalConf"
      	 

	  $dlg --msgbox $"Servidor web configurado correctamente." 0 0
      else
	  $dlg --msgbox $"Error configurando el servidor web." 0 0	  
      fi

      ;;


      ######### Permite modificar los parámetros del servidor de correo. ######### 
      "mailerparams" )
       
      #Sacamos el formulario de parámetros del mailer
      mailerParams
      
      $dlg --infobox $"Configurando servidor de correo..." 0 0

      setVar disk MAILRELAY "$MAILRELAY"
      
      $PVOPS configureMailRelay  # TODO call only the configure relay here. call the confgiure mail domain on the changeIP params op.

      [ $? -ne 0 ] &&  resetLoop $"Error grave: no se pudo activar el servidor de correo."
            
      ;;


      ######### Permite modificar los parámetros del backup cuando es modo local. ######### 
      "backupparams" )
      
      
      $dlg --no-label $"Continuar"  --yes-label $"Cancelar" --yesno  $"Dado que se van a modificar parámeros de configuración básicos, estos deben ser escritos en los Clauers.\n\nAsegúrese de que se reuna toda la comisión.\n\nPrepare un conjunto de Clauers nuevo, diferente al actual.\n\nLa llave de cifrado será renovada, invalidando la actual.\n\n¿Seguro que desea continuar?" 0 0 
      [ "$?" -eq "0" ] && return 1
      
      
      #Pedimos los nuevos parámetros
      while true; do
	  selectDataBackupParams # TODO: now the function has changed. 
	  if [ "$?" -ne 0 ] 
	      then 
	      $dlg --msgbox $"Debe introducir los parámetros de copia de seguridad." 0 0
	      continue
	  fi
	  
	  $dlg --infobox $"Verificando acceso al servidor de copia de seguridad..." 0 0

# TODO revisar bien. que no se guarden los nuevos valores a menos que todo funcione bien, o decirles de repetir (ver la op en el setup). Para la prueba se guarda el trust en el unpriviñleged, pero hay que llamar a lña op priv para guardarla para cuando el root acceda (seguro? vewr el script de backup a ver si allí la añade siempre o espera que esté añadida. si es lo primero, borrar de aquí y de cualquier sitio donde se haga eso)

   #Verificar acceso al servidor # Expects:  "$SSHBAKSERVER" "$SSHBAKPORT" "$SSHBAKUSER" "$SSHBAKPASSWD"
	  checkSSHconnectivity
   if [ "$?" -ne 0 ] 
	      then 
	      $dlg --msgbox $"Error accediendo al servidor de copia de seguridad. Revise los datos." 0 0 
	      continue
	  fi

   
	  #Añadimos las llaves del servidor SSH al known_hosts del root
	  $PVOPS trustSSHServer "$SSHBAKSERVER" "$SSHBAKPORT"
	  if [ $? -ne 0 ] ; then
	      $dlg --msgbox $"Error configurando el acceso al servidor de copia de seguridad." 0 0
	      continue
	  fi


	 	  
	  break
	  
      done

	  
	  #////guardamos los nuevos valores de dichos params en fich de clauer y en disco --> asegurarme de que exista el fichero de config de clauer con los parámetros que tocan. Ver cómo hacía para grabarlo, si uso el mismo fichero o lo duplicaba o algo y hacerlo aquí. Ojo a la nueva llave generada, la vieja y la autorización para ejecutar ops.
	  #SSHBAKSERVER=$(getVar disk SSHBAKSERVER)
	  # set en vez de get, y set en c y en d, y después de verificar..  SSHBAKPORT=$(getVar disk SSHBAKPORT)

      #Generar nueva llave externa y almacenarla en un set de clauers.



#	$PVOPS enableBackup	    


# TODO functionality to enable/disable backup and add option to  change bak params  on the menu
	  
	

  #Ahora se regenera la llave de cifrado.
      $dlg --msgbox $"Ahora se procederá a construir el nuevo conjunto de Clauers. Podrá elegir los parámetros de compartición de la nueva llave." 0 0 
      


      
      
      
      ;;


      ######### Permite modificar los parámetros de acceso a internet. ######### 
      "networkparams" )
          $dlg --msgbox "Still not reviewed." 0 0

          # TODO Load defaults
          
          # TODO get new parameters
          
          configureNetwork
          
          #Setup hosts file and hostname
          configureHostDomain
          ;;


      ######### Verificación de la integridad de las piezas de la llave. #########
      "verify" )
      $dlg --msgbox "Still not reviewed." 0 0 
      ;;

	
      ######### Se cambia la llave compartida entre los custodios. ######### 
      #Permite cambiar los parámetros de compartición.
      "newouterkey" )
      $dlg --msgbox "Still not reviewed." 0 0 
      ;;	


      ######### Se cambia la llave interna del sistema. ######### ### TODO extinguir esta opción. Si hay un compromiso de la llave interna, hacer un backup y un restore y a correr.
      #Requiere reubicar todos los datos cifrados en otra localización (permite elegir de nuevo el modo)
      "newinnerkey" )
      $dlg --msgbox "Still not reviewed." 0 0 
      ;;


      * )          
        resetLoop "Maintenance operation selector: bad selection."
        ;;
      
    esac

}

#Lo que vendría a ser un continue pero con el bucle a nivel de proceso que uso.
doLoop () {
    exec /bin/bash  /usr/local/bin/wizard-maintenance.sh
}


##################
#  Main Program  #
##################


# TODO add a maint option to join esurvey lcn network (if not done during setup, and also to change registration)

#//// Variables a leer cada vez que se lance este script: # TODO revisar esto. probablemente faltan, pero leerlas en cada func, según hagan falta mejor
MGREMAIL=$(getVar disk MGREMAIL)
ADMINNAME=$(getVar disk ADMINNAME)

SHARES=$(getVar usb SHARES)

copyOnRAM=$(getVar mem copyOnRAM)

# TODO leer estas variables para el modo mant? para default en la op de renovar cert ssl?
#"$HOSTNM.$DOMNAME"

sslCertState=$($PVOPS getSslCertState) # TODO use getVar
[ "$sslCertState" == "" ] && echo "Error: debería existir algún estado para el cert."  >>$LOGFILE 2>>$LOGFILE
  
	#Ver cuáles son estrictamente necesarias. borrar el resto////
#	setVarFromFile  $VARFILE MGREMAIL
#	setVarFromFile  $VARFILE ADMINNAME






#Matamos el daemon de entropía, porque, aunque no la carga mucho, consume mucho tiempo de CPU sin hacer nada.
$PVOPS randomSoundStop

#Revocamos el permiso para ejecutar ops privilegiadas.
$PVOPS storops-resetAllSlots



#Muestra el menú de opciones y procesa la entrada de usuario
MAINTACTION=''
standBy



#De forma preventiva, anulamos los privilegios de admin. (Si se han elegido en el menu, lo hace en executesystemaction)
$PVOPS  removeAdminPrivileges


#Reactivamos el daemonde entropía, por si hace falta
$PVOPS randomSoundStart
    


#Si la acción es no privilegiada, se ejecuta ahora y se resetea el bucle.
executeUnprivilegedAction



#Solicitamos los clauers y reconstruímos la clave para autorizar la operación.
obtainClearance



#Ejecuta la operación solicitada
executeSystemAction "running"



#Revocamos el permiso para ejecutar ops privilegiadas (por paranoia).
$PVOPS storops-resetAllSlots

#Relanzamos el bucle.
doLoop



#Asegurarme de que se loguean todas las acciones realizadas sobre el servidor. Sacar esto en la app? poner un visor web para la comisión? pedirles contraseñas nuevas para que accedan o una genérica?


# TODO en algún sitio se invoca esto? --> creo que era en el innerkey, pero lo voy a extinguir. si no hace falta, quitar
#    $PVOPS  stopServers



# TODO incluir tb la posibilidad de, en el SSL, instalar una clave privada externa? (por si acaso el porcedimiento de la org lo obliga), pero esta op debe ser con autorización de la comisión, pero esto sólo en el modo mant, no en la inst. --> es un lío y sería poco garante, no vale la pena fomentarlo. Describirlo como proced. de emergencia y ponerlo en el manual, describiendo los pasos para hacerlo desde el terminal. (así menos mantenimiento). hacerlo al final de todo. --> a veces puede ser que la constitución del sistema y la elección vayan muy pegadas... no sé. pensar qué hago.














