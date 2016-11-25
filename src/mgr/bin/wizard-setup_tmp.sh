
#1 -> 'new' or 'reset'
doSystemConfiguration (){






    

    #Si estamos creando el sistema, la red se habrá configurado durante el setup
    if [ "$1" == 'reset' ]
        then
        configureNetwork 'Panic'
    fi

	
    #Abrimos o creamos la zona segura de datos.
    configureCryptoPartition "$1"
    #En $CRYPTDEV está el dev empleado, para desmontarlo  # TODO cambiar este retorno, ahora no es una global. De hecho, quitar y mantener en la parte priv, en una var de ram si hace falta


    
    #Si se está ejecutando una restauración
    if [ "$DORESTORE" -eq 1 ] ; then #////probar
	
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
    

    #Leemos variables de configuración que necesitamos aquí (si es new, 
    #ya están definidas, si es reset, se redefinen y no pasa nada)
#    WWWMODE=$(getVar disk WWWMODE) # extinguido
    SSHBAKSERVER=$(getVar disk SSHBAKSERVER)

    #Si hay backup de los datos locales
    if [ "$SSHBAKSERVER" != ""  ] ; then
	       if [ "$1" == "new"  ] ; then  #*-*-en restore estos valen los nuevos. restaurar el vars original y que los machaque aquí?
	           #Escribimos en un fichero los params que necesita el script del cron 
	           #(sólo al instalar, porque luego pueden ser modificados desde el menú idle)
	           #(en realidad no importa, porque al cambiarlos reescribe los clauers)
	           setVar disk SSHBAKSERVER "$SSHBAKSERVER"
	           setVar disk SSHBAKPORT   "$SSHBAKPORT"
	           setVar disk SSHBAKUSER   "$SSHBAKUSER"
	           setVar disk SSHBAKPASSWD "$SSHBAKPASSWD"
	       fi
    fi

    # Una vez montada la partición cifrada, sea new o reset (en este caso, ya habrá leido las vars del disco) o restore (ya habrá copiado los datos correspondientes)
    relocateLogs "$1"

    #////Si he de hacer algún cambio a la part cifrada, llamarlo aquí si es una op aislada. creo que en la de configurecryptopart ya hago los cambios correspondientes -> COMPROBAR Y BORRAR
    
    
    
    #Solo verificamos las piezas si es un reset, no si es nuevo servidor
    if [ "$1" == 'reset' ]
	then

        #Verificamos las piezas de la llave, pero sólo con fin informativo, no obligamos a cambiarla ya.
	$dlg --infobox $"Verificando piezas de la llave..." 0 0

	testForDeadShares 
	res=$?
	
        #Si no todas las piezas son correctas, solicitamos regeneración.
	if [ "$res" -ne "0" ];  then
	    $dlg --msgbox $"Se detectaron piezas corruptas.\n\nPara evitar una pérdida de datos, debería reunirse la comisión al completo en el menor tiempo posible y proceder a cambiar la llave." 0 0 
	fi	
    fi

    

    #Lanzamos los servicios del sistema (y acabamos la configuración de la instalación)
    configureServers "$1" 


    if [ "$DORESTORE" -eq 1 ] ; then

	$PSETUP recoverSSHBackup_phase2
	
    fi


    #Si estamos em modo de disco local, ponemos en marcha el proceso cron de backup cada minuto
    SSHBAKSERVER=$(getVar disk SSHBAKSERVER)
	   SSHBAKPORT=$(getVar disk SSHBAKPORT)
    if [ "$SSHBAKSERVER" != ""  ] ; then

	       if [ "$1" == 'reset' ] ; then
	           
	           #Añadimos las llaves del servidor SSH al known_hosts # TODO hace falta? al hacer el test en el config, se habrán añadido. O hacer dos ops separadas?
	           $PVOPS trustSSHServer "$SSHBAKSERVER" "$SSHBAKPORT"# TODO ESto no debería hacerse antes del restore, porque se necesita que se confíe en el servidor?? se hace con cada conexión del proceso de backup? verificar
            ret=$?
	           if [ "$ret" -ne 0 ] ; then
		              systemPanic $"Error configurando el acceso al servidor de copia de seguridad."
	           fi
	       fi
	
	       $PSETUP enableBackup	    
	       
    fi
    
    
    
    #Lanzamos el sistema de recogida de estadísticas en RRDs
    if [ "$1" == "new"  ] ; then
	#Construye las RRD
	$PVOPS stats startLog 
    fi
    
    #Creamos el cron que actualiza los resultados y genera las gráficas
    $PVOPS stats installCron
    
    #Actualizamos los gráficos al inicio (vacíos en la creación, no vacíos en el reboot)
    $PVOPS stats updateGraphs  >>$LOGFILE 2>>$LOGFILE
    

    #Escribimos el alias que permite que
    #se envien los emails de emergencia del smart y demás
    #servicios al correo del administrador
    
    $PSETUP setupNotificationMails

    
    #Realizamos los ajustes finales
    $PSETUP init4
        

    $dlg --msgbox $"Sistema iniciado correctamente y a la espera." 0 0
    

}  #end doSystemConfiguration





#1 -> 'new' or 'reset'
configureServers () {




    ######### Activación del servidor postfix ##########
    $dlg --infobox $"Configurando servidor de correo..." 0 0

    if [ "$1" == 'new' ]
	then :
	


    fi
    
    
    $PVOPS configureServers mailServer
    
    [ $? -ne 0 ] &&  systemPanic $"Error grave: no se pudo activar el servidor de correo." f
    








    #########  Solicitar datos de registro en eSurveySites ######### 

    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ]
	    then :
	    
            #Pedimos los parámetros para registrar el servidor en eSruveySites, 
	    #genera la petición de cert y la envia. # TODO en cualquier caso, esta fase del setup que necesita estar online, puede ejecutarse y si falla volver a pedir los datos, o directamente, como será algo opcional, pasarla al maintenance.
            esurveyParamsAndRequest
	    
	    
	    #Descargamos la lista de nodos y advertimos si no hay al menos dos nodos
	    wget https://esurvey.nisu.org/sites?lstnodest=1 -O /tmp/nodelist 2>/dev/null
	    ret=$?

	    if [ "$ret" -ne  0  ]
		then
		$dlg --msgbox $"Ha habido un error al descargar la lista de nodos. No podemos verificar si existen al menos dos nodos para garantizar el anonimato." 0 0
	    else
		numnodes=$(wc -l /tmp/nodelist | cut -d " " -f 1)
    
		[ "$numnodes" -lt "2"  ] && $dlg --msgbox $"No existen suficientes nodos en la red de latencia para garantizar un nivel mínimo de anonimato. Opere este sistema bajo su propia responsabilidad." 0 0
    
	    fi
	    rm /tmp/tempdlg /tmp/nodelist 2>/dev/null
	    
	    
	    
	    
            ### Construcción de la urna ###
	    $dlg --infobox $"Generando llaves de la urna..." 0 0
	    
	    keyyU=$(openssl genrsa $KEYSIZE 2>/dev/null | openssl rsa -text 2>/dev/null)
	    
	    modU=$(echo -n "$keyyU" | sed -e "1,/^modulus/ d" -e "/^publicExponent/,$ d" | tr -c -d 'a-f0-9' | sed -e "s/^00//" | hex2b64)
	    expU=$(echo -n "$keyyU" | sed -n -e "s/^publicExponent.*(0x\(.*\))/\1/p" | hex2b64)
	    
	    keyyU=$(echo "$keyyU" | sed -n -e "/BEGIN/,/KEY/p")
	    
	fi
    fi






    
    ######### Activación del servidor mysql ##########
    $dlg --infobox $"Configurando servidor de base de datos..." 0 0
 

    $PVOPS configureServers "dbServer-init"  "$1"
    
 
    ### Construímos el segundo fichero .sql, con los inserts necesarios para config. la aplicación ###
    if [ "$DORESTORE" -ne 1 ] ; then
	if [ "$1" == 'new' ] 
	    then
	    rm -f /tmp/config.sql
	    touch /tmp/config.sql


     #Si no está, añadir una op de mant que permita cambiar el mailer

     # TODO OJO!! casi todo esto ya está en una op de mant. invocar a esta op para no duplicar
            #Escapamos los campos que pueden contener caracteres problemáticos (o los que reciben entrada directa del usuario)
	    adminname=$($addslashes "$ADMINNAME" 2>>$LOGFILE)
	    admidnum=$($addslashes "$ADMIDNUM" 2>>$LOGFILE)
	    adminrealname=$($addslashes "$ADMREALNAME" 2>>$LOGFILE)
	    mgremail=$($addslashes "$MGREMAIL" 2>>$LOGFILE)
	    
	    
	    
            #Inserción del usuario administrador (ahora no puede entrar cuando quiera, sólo cuando se le autorice)
	    echo "insert into eVotPob (us,DNI,nom,rol,pwd,clId,oIP,correo) values ('$adminname','$admidnum','$adminrealname',3,'$MGRPWDSUM',-1,-1,'$mgremail');" >> /tmp/config.sql
	    
	    
            #Inserción del email del admin
            #El primero debe ser un insert. El update no traga. --> ya hay un insert, en el script del dump, pero fallaba por no tener permisos de ALTER y se abortaba el resto del script sql.
	    echo "update eVotDat set email='$mgremail';" >> /tmp/config.sql
	    
	    
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

            #echo "tkD al insertarlo: $SITESTOKEN"   >>$LOGFILE 2>>$LOGFILE

            #La timezone del servidor
	    echo "update eVotDat set TZ='$TIMEZONE';" >> /tmp/config.sql 
	    
	fi	
    fi
    

    
    $PVOPS configureServers "alterPhpScripts"

    
    
    if [ "$DORESTORE" -ne 1 ] ; then


	if [ "$1" == 'new' ]
	    then
         #Las rutas de los ficheros a leer ya las tiene la op.
	        $PSETUP populateDb
	fi

        #En cualquier caso, incluso cuando no estamos instalando, Ejecutamos los alters y updates de la BD para actualizarla.
	$PSETUP updateDb

	
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
