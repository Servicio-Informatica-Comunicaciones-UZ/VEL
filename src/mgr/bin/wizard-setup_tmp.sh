

    
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

    



















   


   



	  #Generate the certificate sign request for the SSL connections
	  generateCSR "new"  
	  ret=$?
	  [ "$ret" -ne 0 ] && systemPanic $"Error grave: no se pudo generar la petición de certificado."
	       
   #Set the SSL certiifcate as a variable
   


   
	       


        
    
	   
    #Este aviso sólo debe salir si es ssl y new, en plain se ejecuta igual  pero de forma transpartente
	   if [ "$1" == 'new' ]
	   then
	       [ "$WWWMODE" != "plain" ] && $dlg --msgbox $"Vamos a generar un certificado de pruebas para poder operar el sistema durante el proceso de firma del válido" 0 0
	   fi
	   
    #Si no hay cert (dummy o bueno), generar un dummy a partir de la csr (ya hay una llave seguro)
	   $PVOPS configureServers "configureWebserver" "dummyCert"

	   
	   



