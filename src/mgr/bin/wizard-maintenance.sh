#!/bin/bash



##############
#  Includes  #
##############

. /usr/local/bin/common.sh

. /usr/local/bin/wizard-common.sh




#############
#  Methods  #
#############




#Log function
log () {
    echo "["$(date --rfc-3339=ns)"][wizard-maintenance]: "$*  >>$LOGFILE 2>>$LOGFILE
}




#Error function. Will message the user and then reset the maintenance
#application to the main menu
#$1 -> error message
resetLoop () {
    #Show error message to the user
    log "$1"
    $dlg --msgbox "$1" 0 0
    
    #Return to the maintenance idle loop
	   doLoop
} # TODO Call this everywhere there's an error that needs to go back to the loop




#Reboots the maintenance application, so every action is performed on
#a clean environment by overriding the process context of the previous
#execution
doLoop () {
    exec /bin/bash  /usr/local/bin/wizard-maintenance.sh
    shutdownServer "h" #This will never be executed
}






#Main maintenance menu
#Will set the global MAINTACTION
chooseMaintenanceAction () {
    
    MAINTACTION='' # TODO Add line telling whether the admin has privileges or not, create priv op that returns some vars with no clearance check
    exec 4>&1
    while true; do
        selec=$($dlg --no-cancel --no-tags --menu $"Maintenance operations categories" 0 80  6  \
	                    admin-cat   $"Administrator operation." \
                     key-cat   $"Shared key management." \
	                    recover $"Recover a voting system backup." \
	                    term    $"Launch administrator terminal." \
                     reboot  $"Reboot system." \
	                    halt    $"Shutdown system." \
	                    2>&1 >&4)
        
        case "$selec" in
	           "start" )
                DOSTART=1
                DOINSTALL=0
                DORESTORE=0
	               return 1
                ;;
            
	           "setup" )
                #Double check option if user chose to format
                $dlg --yes-label $"Back" --no-label $"Format system" \
                     --yesno  $"You chose NEW system.\nThis will destroy any previous installation of the voting system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOSTART=0
	               DOINSTALL=1
                DORESTORE=0
	               return 2
                ;;
            
            "recover" )
                #Double check option if user chose to recover
                $dlg --yes-label $"Back" --no-label $"Recover backup" \
                     --yesno  $"You chose to RECOVER a backup.\nThis will destroy any changes on a previously existing system. Do you wish to continue?" 0 0
                [ $? -eq 0 ] && continue
                
                DOSTART=0
	               DOINSTALL=0
	               DORESTORE=1
	               return 3
                ;;
	           
	           "term" )
	               $dlg --yes-label $"Yes" --no-label $"No"  \
                     --yesno  $"WARNING:\n\nYou chose to open a terminal. This gives free action powers to the administrator. Make sure he does not operate it without proper technical supervision. Do you wish to continue?" 0 0
	               [ "$?" -ne 0 ] && continue
                $PVOPS rootShell
                continue
                ;;
	           
	           "reboot" )	
	               $dlg --yes-label $"Cancel"  --no-label $"Reboot" --yesno $"Are you sure to go on?" 0 0
	               [ "$?" -eq 1 ] && shutdownServer "r"
	               continue
	               ;;	
		          
	           "halt" )	
	               $dlg --yes-label $"Cancel"  --no-label $"Shutdown" --yesno $"Are you sure to go on?" 0 0
	               [ "$?" -eq 1 ] && shutdownServer "h"
	               continue
	               ;;
	           
	           * )
	               log "main operation selector: bad selection. This must not happen" 
                continue
	               ;;
	       esac   
    done

    

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
        ## TODO implementar a dos niveles: primero un men� de grupos de ops, y luego cada grupo tendr� una o m�s ops
        # Ops de administrador
	       exec 4>&1 ### TODO rehacer y que no se vea el tag con el cod de op, creo que era --no-tag, ver man dialog, y cambiar el� n�mero por un tag m�s descriptivo
	       selec=$($dlg --no-cancel  --no-tags --menu $"El sistema est� en marcha.\nSi lo desean pueden realizar alguna de estas acciones:" 0 80  14  \
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




obtainClearance () {

    #Requiere auth
    $dlg --msgbox $"Para verificar la autoridad para realizar esta acci�n, procedemos a pedir los fragmentos de llave." 0 0
 	  
    #Pide reconstruir llave s�lo para verificar que se tiene autorizaci�n de acceso 
    readUsbsRebuildKey  keyonly
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



#Lo que vendr�a a ser un continue pero con el bucle a nivel de proceso que uso.
doLoop () {
    exec /bin/bash  /usr/local/bin/wizard-maintenance.sh
}


##################
#  Main Program  #
##################








#Select which action to execute
chooseMaintenanceAction








#Finished. Continue the main program loop
doLoop










# TODO SEGUIR revisar e integrar



# TODO add a maint option to join esurvey lcn network (if not done during setup, and also to change registration)

#//// Variables a leer cada vez que se lance este script: # TODO revisar esto. probablemente faltan, pero leerlas en cada func, seg�n hagan falta mejor
MGREMAIL=$(getVar disk MGREMAIL)
ADMINNAME=$(getVar disk ADMINNAME)

SHARES=$(getVar usb SHARES)

copyOnRAM=$(getVar mem copyOnRAM)

# TODO leer estas variables para el modo mant? para default en la op de renovar cert ssl?
#"$HOSTNM.$DOMNAME"

sslCertState=$($PVOPS getSslCertState) # TODO use getVar
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





#Asegurarme de que se loguean todas las acciones realizadas sobre el servidor. Sacar esto en la app? poner un visor web para la comisi�n? pedirles contrase�as nuevas para que accedan o una gen�rica?


# TODO en alg�n sitio se invoca esto? --> creo que era en el innerkey, pero lo voy a extinguir. si no hace falta, quitar
#    $PVOPS  stopServers



# TODO incluir tb la posibilidad de, en el SSL, instalar una clave privada externa? (por si acaso el porcedimiento de la org lo obliga), pero esta op debe ser con autorizaci�n de la comisi�n, pero esto s�lo en el modo mant, no en la inst. --> es un l�o y ser�a poco garante, no vale la pena fomentarlo. Describirlo como proced. de emergencia y ponerlo en el manual, describiendo los pasos para hacerlo desde el terminal. (as� menos mantenimiento). hacerlo al final de todo. --> a veces puede ser que la constituci�n del sistema y la elecci�n vayan muy pegadas... no s�. pensar qu� hago.














