

    
    #Si se está ejecutando una restauración
    if [ "$DORESTORE" -eq 1 ] ; then #////probar

        # TODO asegurarme de que se hace el trust antes de descargar el backup
        
	       while true; do 
	           
	           $dlg --msgbox $"Prepare ahora los Clauers del sistema anterior. Vamos a recuperar los datos." 0 0

            #La llave y la config a restaurar las metemos en el slot 2
	           $PVOPS storops-switchSlot 2

	           

            #Pedir Clauers con la config y rebuild key
	           readUsbsRebuildKey
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
	           $PVOPS storops-switchSlot 1


	           break
	       done


    fi
    
   if [ "$DORESTORE" -eq 1 ] ; then

	$PSETUP recoverSSHBackup_phase2
	
    fi

    

















   


   ####FRagments of priviñleged-ops:

	   



#//// sin verif condicionada a verifcert?

## TODO cambiar numeración de params, será 1 o 2 ahora
if [ "$3" == "installSSLCert" ] 
then
	   
	   #Verificamos el certificado frente a la cadena.
	   verifyCert $ROOTSSLTMP/server.crt $ROOTSSLTMP/ca_chain.pem
	   if [ "$?" -ne 0 ] 
	   then
 	      #No ha verificado. Avisamos y salimos (borramos el cert y la chain en temp)
	       log "Cert not properly verified against chain" 
	       rm -rf $ROOTSSLTMP/*  >>$LOGFILE  2>>$LOGFILE
	       exit 1
	   fi
	   
	   #Según si estamos instalando el primer cert o uno renovado, elegimos el dir.
	   crtstate=$(cat $DATAPATH/root/sslcertstate.txt 2>>$LOGFILE)
	   if [ "$crtstate" == "RENEW" ]
	   then
	       basepath="$DATAPATH/webserver/newcsr/"
	   else #DUMMY y  OK
	       basepath="$DATAPATH/webserver/"
	   fi


    #Si todo ha ido bien, copiamos la chain a su ubicación 
	   mv -f $ROOTSSLTMP/ca_chain.pem  $basepath/ca_chain.pem >>$LOGFILE  2>>$LOGFILE
    
    #Si todo ha ido bien, copiamos el cert a su ubicación
	   mv -f $ROOTSSLTMP/server.crt  $basepath/server.crt >>$LOGFILE  2>>$LOGFILE
	   

	   /etc/init.d/apache2 stop  >>$LOGFILE  2>>$LOGFILE


	   #Si es renew, sustituye el cert activo por el nuevo.
	   if [ "$crtstate" == "RENEW" ]
	   then
	       mv -f  "$DATAPATH/webserver/newcsr/server.csr"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       mv -f  "$DATAPATH/webserver/newcsr/server.crt"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       mv -f  "$DATAPATH/webserver/newcsr/server.key"   "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       mv -f  "$DATAPATH/webserver/newcsr/ca_chain.pem" "$DATAPATH/"  >>$LOGFILE  2>>$LOGFILE
	       rm -rf "$DATAPATH/webserver/newcsr/"                           >>$LOGFILE  2>>$LOGFILE
	   fi

	   
    #Cambiar estado de SSL
	   echo -n "OK" > $DATAPATH/root/sslcertstate.txt


	   #enlazar el csr en el directorio web. (borrar cualquier enlace anterior)
	   rm /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	   cp -f $DATAPATH/webserver/server.csr /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	   chmod 444 /var/www/server.csr  >>$LOGFILE 2>>$LOGFILE
	   
	   
	   /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE
	   if [ "$ret" -ne 0 ]; then
	       log "Error restarting web server!" 
	       exit 2
	   fi
	   
	   exit 0
fi

