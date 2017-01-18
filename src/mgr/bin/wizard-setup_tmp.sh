

    
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



   


### TODO respecto a la gestión de cert ssl:
# TODO op de instalar cert. recibe un cert. si dummy/renew, mira si el actual/candidato son autofirmados, si el nuevo valida y si coincide con la llave. si ok (se habrá renovado el cert sin cambiar la llave, luego se habrá refirmado la csr que ya tenemos), mirar que el actual valida, que le falta menos de X para caducar (o dejamos siempre y punto?), que el nuevo valida y si coincide con la llave.
# TODO op que lance un proceso de renew de clave (si en modo ok). genera csr nuevo, etc [hacer además que esté disponible siempre, sin tener en cuenta el modo y se pueda machacar el renew con otro? MEjor que sea machacable, así si hubiese algún error que requirese reiniciar el proceso antes de instalar un cert firmado, se podría hacer]

# TODO Reiniciar apache y postfix, ambos lo usan

#TODO añadir cron que avise por e-mail cuando falte X para caducar el cert

	


#//// sin verif condicionada a verifcert
# 4-> certChain o serverCert
## TODO cambiar numeración de params, será 1 o 2 ahora--> aplanar a ops de 1 nivel sólo
if [ "$3" == "checkCertificate" ] 
then

	   if [ "$4" != "serverCert" -a "$4" != "certChain" ]
	   then
	       log "checkCertificate: bad param 4: $4"
	       exit 1
	   fi

	   #El nombre con que se guardará si se acepta 
	   destfilename="ca_chain.pem"

	   keyfile=''
	   #Si estamos verificando el cert de serv, necesitamos la privkey
	   if [ "$4" == "serverCert" ]
	   then

	       #El nombre con que se guardará si se acepta 
	       destfilename="server.crt"

	       crtstate=$(cat $DATAPATH/root/sslcertstate.txt 2>>$LOGFILE)
	       
	       if [ "$crtstate" == "RENEW" ]
		      then
		          #Buscamos la llave en el subdirectorio (porque la del principal está en uso y e sválida)
		          keyfile="$DATAPATH/webserver/newcsr/server.key"
	       else #DUMMY y  OK
		          #La buscamos en el dir principal
		          keyfile="$DATAPATH/webserver/server.key"
	       fi
        
	   fi 
	   
	   checkCertificate  $ROOTFILETMP/usbrreadfile "$4" $keyfile
	   ret="$?"

	   if [ "$ret" -ne 0 ] 
	   then
	       rm -rf $ROOTFILETMP/*  >>$LOGFILE  2>>$LOGFILE #Vaciamos el temp de lectura de ficheros
	       exit "$ret" 	  
	   fi

	   #Si no existe el temp específico de ssl, crearlo
	   if [ -e $ROOTSSLTMP ]
	   then
	       :
	   else
	       mkdir -p  $ROOTSSLTMP >>$LOGFILE 2>>$LOGFILE
	       chmod 750 $ROOTSSLTMP >>$LOGFILE 2>>$LOGFILE
	   fi
	   
	   #Movemos el fichero al temporal específico (al destino se copiará cuando estén verificados la chain y el cert)	  
	   mv -f $ROOTFILETMP/usbrreadfile $ROOTSSLTMP/$destfilename  >>$LOGFILE  2>>$LOGFILE
	   
	   
	   rm -rf $ROOTFILETMP/* >>$LOGFILE  2>>$LOGFILE #Vaciamos el temp de lectura de ficheros
	   exit 0
fi




      

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







# 3 -> file path to copy to destination # TODO ver si no lo uso en nignuan parte y cargarme este temp
if [ "$2" == "copyFile" ] 
then


	   
    
	   
	   rm -rf    $ROOTFILETMP >>$LOGFILE 2>>$LOGFILE
	   mkdir -p  $ROOTFILETMP >>$LOGFILE 2>>$LOGFILE
	   chmod 750 $ROOTFILETMP >>$LOGFILE 2>>$LOGFILE
	   
	   destfile=$ROOTFILETMP"/usbrreadfile"
	   
	   #echo "------->cp $3  $destfile"
    #echo "-------------------"
    #ls -l $3
    #echo "-------------------"
    #ls -l $DATAPATH 
    #echo "-------------------"

	   cp -f "$3" "$destfile"  >>$LOGFILE 2>>$LOGFILE
    
	   exit 0
fi


