

    
    #Si se está ejecutando una restauración
    if [ "$DORESTORE" -eq 1 ] ; then #////probar

        # TODO asegurarme de que se hace el trust antes de descargar el backup
        
	       while true; do 
	           
	           $dlg --msgbox $"Prepare ahora los Clauers del sistema anterior. Vamos a recuperar los datos." 0 0

            #La llave y la config a restaurar las metemos en el slot 2
	           $PVOPS storops switchSlot 2

	           

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
	           $PVOPS storops switchSlot 1


	           break
	       done


    fi
    
   if [ "$DORESTORE" -eq 1 ] ; then

	$PSETUP recoverSSHBackup_phase2
	
    fi

    

    







   
 


   



	    
	    
    # TODO : turn into PSETUP ops, call on install only
    
    # One to generate ballot box key and store it on the db [put a guard to check if database is running and created?]

    # a PVOP to insert sites info (If not configured, what to do?) [must be a pvop since it will be callable as a  mantenance op]

    	    $dlg --infobox $"Generando llaves de la urna..." 0 0
	    
	    keyyU=$(openssl genrsa $KEYSIZE 2>/dev/null | openssl rsa -text 2>/dev/null)
	    
	    modU=$(echo -n "$keyyU" | sed -e "1,/^modulus/ d" -e "/^publicExponent/,$ d" | tr -c -d 'a-f0-9' | sed -e "s/^00//" | hex2b64)
	    expU=$(echo -n "$keyyU" | sed -n -e "s/^publicExponent.*(0x\(.*\))/\1/p" | hex2b64)
	    
	    keyyU=$(echo "$keyyU" | sed -n -e "/BEGIN/,/KEY/p")


    
	    
            #Insertamos las llaves de la urna
            # modU -> mod de la urna (B64)
            # expU -> exp público de la urna (B64)
            # keyyU -> llave privada de la urna. (PEM)
	    echo "update eVotDat set modU='$modU', expU='$expU', keyyU='$keyyU';" >> /tmp/config.sql 
	    
	    
            #Insertamos las llaves y el certificado autofirmado enviado a eSurveySites.
            # keyyS -> llave privada del servidor de firma (PEM)
            # certS -> certificado autofirmado del servidor de firma (B64)
            # expS  -> exponente público del cert de firma (B64)
            # modS  -> módulo del cert de firma (B64)
	    echo "update eVotDat set keyyS='$SITESPRIVK', certS='$SITESCERT', expS='$SITESEXP', modS='$SITESMOD';" >> /tmp/config.sql 
	    
            #Insertamos el token de verificación que nos ha devuelto eSurveySites
	    echo "update eVotDat set tkD='$SITESTOKEN';" >> /tmp/config.sql 

            #La timezone del servidor
	    echo "update eVotDat set TZ='$TIMEZONE';" >> /tmp/config.sql 
	    








     

     

    
    $PVOPS configureServers "alterPhpScripts"






    
    
    
    if [ "$DORESTORE" -ne 1 ] ; then



        #En cualquier caso, incluso cuando no estamos instalando, Ejecutamos los alters y updates de la BD para actualizarla.
	$PSETUP updateDb # TODO ver qué utilidad tiene esto, si total, se instala y ya. hasta que no implemente un sistema de update, no sirve de nada creo

	
        #Ejecutamos la cesión o denegación de privilegios al adminsitrador de la aplicación
	grantAdminPrivileges  # TODO now, it expects the value here. do it aprpopiately depending on what's expected

    fi






    

    ######### Activación del servidor web ##########
    $dlg --infobox $"Configurando servidor web..." 0 0
    sleep 1
    

    if [ "$DORESTORE" -ne 1 ] ; then
	       if [ "$1" == 'new' ]
	       then :

             


	            
	            $dlg --infobox $"Configurando servidor web..." 0 0
	            

	            #Guardamos el modo como variable persistente 
	            setVar disk WWWMODE "$WWWMODE"  # TODO extinguir. desde ahora sólo SSL (self-signed provisionalmente), y si hace falta, para las pruebas, enviar el cert selfsigned por correo para que lo autorice en el cliente.

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
	    
	    generateCSR "new"  # TODO incluir tb la posibilidad de instalar una clave privada externa (por si acaso el porcedimiento de la org lo obliga), pero esta op debe ser con autorización de la comisión, pero esto sólo en el modo mant, no en la inst.
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
