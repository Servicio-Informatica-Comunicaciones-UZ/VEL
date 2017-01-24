#!/bin/bash
























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











executeSystemAction (){

  # TODO ojo. aqu� falta c�digo. revisar a fondo el script de la versi�n 1.0.2, creo que s�lo falta de las ops de mant no revisadas
    case "$MAINTACTION" in 



        ######### Resetea las credenciales del admin de la app (contrase�a local, IP, Clauer y adem�s le da privilegios)########
        "resetadmin" )
            
            $dlg --msgbox $"Va a resetear la contrase�a del usuario administrador." 0 0



            # TODO cargar tambi�n los default de las vars de abajo aqu� 
            # TODO para saber qui�n es el administrador actual, ver el valor default
            # TODO: en resumen: esta interfaz permitir� pner todos los valores para el admin y los mostrar� como defaults si ya exist�an. Para el instalador, no sacar nada e insertar new user. Para el new admin, sacar en blanco y update/insert seg�n si existe el username o no (y el dni?). para el new pwd del admin actual, sacar lo mismo relleno.
            #      # TODO ya que se pueden cambiar los datos del admin en la BD, no ser�a mejor cargarlos de all� en vez de vars? si decido esto, borrar la svars in�tiles que se guarden/carguen en el setup
            
            # TODO Adem�s, no distinguir entre nuevo o viejo. Sacar todos los datos y actualizarlos/insertarlos todos


            
            sysAdminParams lock
            [ $? -ne 0 ] && return 1 # TODO ver la op de abajo
            
            $PVOPS setAdmin reset "$ADMINNAME" "$MGRPWD" "$ADMREALNAME" "$ADMIDNUM" "$ADMINIP" "$MGREMAIL" "$LOCALPWD" # TODO make sure the ip and two passwords are set here, (and the username) the rest are useless
            
            #Adem�s, da privilegios al administrador
            $PVOPS  grantAdminPrivileges
            
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
            
            $PVOPS setAdmin new "$ADMINNAME" "$MGRPWD" "$ADMREALNAME" "$ADMIDNUM" "$ADMINIP" "$MGREMAIL" "$LOCALPWD" 

            
            #Adem�s, da privilegios al administrador
            $PVOPS  grantAdminPrivileges
            
            $dlg --msgbox $"Adicionalmente, el sistema ha otorgado privilegios para el administrador. Estos se invalidar�n en cuanto realice alguna otra operaci�n de mantenimiento." 0 0
            
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

      


        
        "sslcert-renew" )
            
            generateCSR "renew"
            ret=$?

            log "Retorno de generateCSR: $ret" 

            
            if [ "$ret" -eq 0 ]; then

                #Escribimos el pkcs10 en la zona de datos de un clauer
	               $dlg --msgbox $"Se ha generado una petici�n de certificado SSL para este servidor.\nPor favor, prepare un dispositivo USB para almacenarla (puede ser uno de los Clauers empleados ahora).\nEsta petici�n deber� ser entregada a una Autoridad de Certificacion confiable para su firma.\n\nHaga notar al encargado de este proceso que en un fichero adjunto debe proporcionarse toda la cadena de certificaci�n." 0 0
	               
	               fetchCSR "renew"

	               echo -n "renew" > $DATAPATH/root/sslcertstate.txt	  

	               $dlg --msgbox $"Petici�n de certificado generada correctamente." 0 0
            else
	               $dlg --msgbox $"Error generando la nueva petici�n de certificado." 0 0	  
            fi
            
            ;;
        
        
       


        ######### Permite modificar los par�metros del servidor de correo. ######### 
        "mailerparams" )
            
            #Sacamos el formulario de par�metros del mailer
            mailerParams
            
            $dlg --infobox $"Configurando servidor de correo..." 0 0

            setVar disk MAILRELAY "$MAILRELAY"
            
            $PVOPS configureMailRelay  # TODO call only the configure relay here. call the confgiure mail domain on the changeIP params op.

            [ $? -ne 0 ] &&  resetLoop $"Error grave: no se pudo activar el servidor de correo."
            
            ;;


        ######### Permite modificar los par�metros del backup cuando es modo local. ######### 
        "backupparams" )
            
            
            $dlg --no-label $"Continuar"  --yes-label $"Cancelar" --yesno  $"Dado que se van a modificar par�meros de configuraci�n b�sicos, estos deben ser escritos en los Clauers.\n\nAseg�rese de que se reuna toda la comisi�n.\n\nPrepare un conjunto de Clauers nuevo, diferente al actual.\n\nLa llave de cifrado ser� renovada, invalidando la actual.\n\n�Seguro que desea continuar?" 0 0 # TODO ya no van al clauer
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



            #	$PVOPS enableBackup	    


            # TODO functionality to enable/disable backup and add option to  change bak params  on the menu
	           
	           

            #Ahora se regenera la llave de cifrado.
            $dlg --msgbox $"Ahora se proceder� a construir el nuevo conjunto de Clauers. Podr� elegir los par�metros de compartici�n de la nueva llave." 0 0 
            


            
            
            
            ;;


        ######### Permite modificar los par�metros de acceso a internet. ######### 
        "networkparams" )
            $dlg --msgbox "Still not reviewed." 0 0

            # TODO Load defaults
            
            # TODO get new parameters
            
            configureNetwork
            
            #Setup hosts file and hostname
            configureHostDomain
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



    esac

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

#Ver cu�les son estrictamente necesarias. borrar el resto////
#	setVarFromFile  $VARFILE MGREMAIL
#	setVarFromFile  $VARFILE ADMINNAME





















