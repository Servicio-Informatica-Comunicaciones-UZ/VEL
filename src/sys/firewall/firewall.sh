#!/bin/bash



setupFirewall () {
    iptables -F


    #Acepta las conexiones internas por localhost
    #iptables -A INPUT -d 127.0.0.1 -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    
    
    #Limita los pings a 2 por segundo
    iptables -A INPUT -p icmp -m limit --limit 2/second -j ACCEPT
    iptables -A INPUT -p icmp -j DROP
    
    
    #Protección contra el ataque sync flood
    #La quitamos porque al limitar los paquetes SYN, está limitando el número de conexiones totales al equipo a 5 por segundo, lo que resulta absurdo. Además, ya se controla el volumen de paquetes por host y por tiempo. 
    #iptables -N SYN_FLOOD
    #iptables -A SYN_FLOOD -m limit --limit 5/s --limit-burst 20 -j RETURN
    #iptables -A SYN_FLOOD -j DROP
    #iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    
    
    #Acepta todas las entradas referentes a conexiones iniciadas por esta máquina
    iptables -A INPUT --match state --state ESTABLISHED,RELATED -j ACCEPT
    
    #  Carga el módulo de match 'state' y acepta paquetes que sean de
    #  respuesta a preticiones de la propia máquina (ni de nueva
    #  conexión ni inválidos)(La ! indica negación de lo que sigue)
    #  --> La de arriba es más restrictiva y la usamos
    #iptables -A INPUT -m state ! --state  NEW,INVALID -j ACCEPT
    
    
 
    
    #Drop de multicast, anycast y broadcast en general
    iptables -A INPUT -m addrtype --dst-type BROADCAST -j DROP
    iptables -A INPUT -m addrtype --dst-type MULTICAST -j DROP
    iptables -A INPUT -m addrtype --dst-type ANYCAST   -j DROP

   
    # Drop de los paquetes dirigidos al Samba (provocaría el baneo
    # involuntario de muchos equipos). Es posible que no lleguen aquí
    # si son broadcast, pero por si emite algunos en unicast
    iptables -A INPUT -p tcp -m multiport --dport 135,137,138,139 -j DROP
    iptables -A INPUT -p udp -m multiport --dport 135,137,138,139 -j DROP

    
    

    #Lista de reglas para los nodos que están en la whitelist. Los nodos de la LCN pasarán siempre en http/https. pero drop en el resto
    #Si un paquete llega aquí, es de la LCN. Si va a 80 o 433 pasa libremente. Si no, drop en vez de ban.
    iptables -N LCNACT
    iptables -A LCNACT -p tcp -m multiport --dport 80,443 -j ACCEPT
    iptables -A LCNACT -j DROP



    #Creamos un set de reglas para la whitelist. 
    iptables -N LCN
    # El contenido de este set lo determina un script del cron, que se descarga 
    # periódicamente la lista de nodos de la LCN y los añade. Si un paquete viene dre la LCN, salta a LCNACT
    #     iptables -I LCN -s "IP_ORIGEN" -j LCNACT

    
 
    
    
   

    # Es la regla que salta a la verificación de whitelist de la LCN. Si un paquete viene de la LCN, saltará a LCNACT, y si no, seguirá adelante a enfrentarse a BAN y PBAN
    iptables -A INPUT -j LCN
    
    
    #Lista de reglas de Ban: Si entra en Ban, lo elimina de pre-ban, lo añade a ban y desde entonces rechaza los paquetes.
    iptables -N BAN
    #iptables -A BAN -j LOG --log-prefix 'Baneado: '
    iptables -A BAN -m recent --name prebanlist --remove
    iptables -A BAN -m recent --name banlist    --set    -j REJECT
    
    
    
    # Lista de reglas de PreBan: Si entra en PreBan, reject
    iptables -N PBAN
    #iptables -A PBAN -j LOG --log-prefix 'Pre-baneado: '
    #Cada paquete que llegue aquí, se descarta. mejor que reject, para evitar un reenvio temprano y dejar que se cumpla el timeout 
    # Pongo rcheck para evitar que esta regla actualice la lista de last_seen de esta IP
    iptables -A PBAN -m recent --name prebanlist --rcheck -j DROP
    
    
    
    #Cualquier comunicación no tcp o no dirigida a los puertos http y https provoca el baneo directo del host
    iptables -A INPUT -p tcp -m multiport ! --dport 80,443 -j BAN
    #iptables -A INPUT -p udp -j BAN  #El problema es que hay muchos serviicos udp inesperados que pueden banear equipos de la misma red. añadirlos? hacer drop en vez de ban? 5353(mdns),17500(dropbox),1514(ossec)
    iptables -A INPUT -p udp -j DROP

        
    #Si supera las 20 conexiones en 2 segundos, entra en PreBan, donde se hace drop. Esto es para limitar el ratio de peticiones web
    #Al poner update, teoricamente, si la IP no está en prebanlist, no harà match 
    #de ningun modo. Si pusiera el set aquí, como devuelve siempre true, siempre haría el jump
    # AVISO: cualquier valor de hitcount por encima de 20 devuelve: 'invalid argument' al ejecutarlo
    #
    iptables -A INPUT -m recent --name prebanlist --hitcount 20  --seconds 2 --update -j PBAN
    
    
    # Si está en banlist por menos de 2 horas, reject (está baneado 2 horas)
    # Si intenta volver a acceder antes de 2 horas, al hacer un
    # update, se resetea este contador. El rcheck evita que se
    # actualice la banlist, por lo que a las dos horas del primer intento ya podrá conectar
    iptables -A INPUT -m recent --name banlist --seconds $[2*3600] \
	--rcheck -j REJECT --reject-with icmp-host-prohibited
    
    
   
    
    #Si Después de pasar todas las barreras, es una conexión a http o https, la deja pasar, y actualiza la lista de preban
    #iptables -A INPUT -p tcp -m multiport --dport http,https -m recent --name prebanlist --set -j ACCEPT
    #iptables -A INPUT -m recent --name prebanlist --set -j ACCEPT
    iptables -A INPUT -p tcp  --dport http -m recent --name prebanlist --set -j ACCEPT
    iptables -A INPUT -p tcp  --dport https -m recent --name prebanlist --set -j ACCEPT
    #[ "$1" == "ssl" ] && iptables -A INPUT -p tcp  --dport https -m recent --name prebanlist --set -j ACCEPT
    
    #Si Después de pasar todas las barreras, va a otro puerto, reject
    iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
    
    
    # Ver las listas de recent: /proc/net/ipt_recent/ o en /proc/net/xt_recent/

    
    #Quitar el baneo
    #echo -150.128.49.XX >/proc/net/xt_recent/banlist


    #Ver los logs
    #tail -f /var/log/messages | grep --color=auto 49.XX &
    #tail -f /var/log/apache2/access.log &


    #Acepta conexiones nuevas al puerto https
    #[ "$1" == "ssl" ] && iptables -A INPUT -p TCP --dport 443 -j ACCEPT  

    #Acepta conexiones nuevas al puerto http
    #iptables -A INPUT -p TCP --dport 80  -j ACCEPT

    #Rechaza cualquier otro paquete (incluso pings)   
    #iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited

}    

