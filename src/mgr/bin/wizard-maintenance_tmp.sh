#!/bin/bash
























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











executeSystemAction (){

  # TODO ojo. aquí falta código. revisar a fondo el script de la versión 1.0.2, creo que sólo falta de las ops de mant no revisadas
    case "$MAINTACTION" in 



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


      



        

        ######### Resetea las RRD de estadíticas del sistema ########
        "resetrrds" )
            
            $dlg  --yes-label $"Sí"  --no-label $"No"   --yesno  $"¿Seguro que desea reiniciar la recogida de estaditicas del sistema?" 0 0 
	           [ "$?" -ne "0" ] && return 1
            
	           #Resetemaos las estadísticas
	           $PVOPS stats resetLog
	           
	           $dlg --msgbox $"Reinicio completado con éxito." 0 0
	           
            ;;








        

        ######### Operaciones con el cert del servidor. ######### 

      


        
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
            
            
            $dlg --no-label $"Continuar"  --yes-label $"Cancelar" --yesno  $"Dado que se van a modificar parámeros de configuración básicos, estos deben ser escritos en los Clauers.\n\nAsegúrese de que se reuna toda la comisión.\n\nPrepare un conjunto de Clauers nuevo, diferente al actual.\n\nLa llave de cifrado será renovada, invalidando la actual.\n\n¿Seguro que desea continuar?" 0 0 # TODO ya no van al clauer
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



    esac

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

#Ver cuáles son estrictamente necesarias. borrar el resto////
#	setVarFromFile  $VARFILE MGREMAIL
#	setVarFromFile  $VARFILE ADMINNAME





















