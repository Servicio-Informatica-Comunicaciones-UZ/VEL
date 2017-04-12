#!/bin/bash



setupFirewall () {
    
    # Flush all chains
    iptables -F
    iptables -t filter -F
    iptables -t mangle -F
    iptables -t nat -F
    
    # Delete unused chains
    iptables -t filter -X
    iptables -t mangle -X
    iptables -t nat -X

    # Set default policies
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    
    
    
    # Drop any potential router traffic
    iptables -P FORWARD DROP
    
    
    
    
    # Drop malicious 'localhost' traffic coming from interfaces
    # different from loopback interface
    iptables -A INPUT ! -i lo -d 127.0.0.0/8 -j DROP
    
    # Accept localhost traffic
    #iptables -A INPUT -d 127.0.0.1 -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    
    
    
    # Accept all packages belonging to connections established by this
    # host
    iptables -A INPUT --match state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Load state module and accept packages that are a response to
    # requests by this host (not invalid, nor new connections)
    # [Removed] Using the one above, which is more restrictive
    #iptables -A INPUT -m state ! --state  NEW,INVALID -j ACCEPT
    
    
    
    # Limit pings to 2 per second
    iptables -A INPUT -p icmp -m limit --limit 2/second -j ACCEPT
    iptables -A INPUT -p icmp -j DROP
    
    
    
    # SYNC flood protection
    # [Removed] By limiting the numbr of SYNC packages, it was limiting
    # the number of connections to a ridiculous rate. Besides there
    # already is a volume of packages per time limit.
    #iptables -N SYN_FLOOD
    #iptables -A SYN_FLOOD -m limit --limit 5/s --limit-burst 20 -j RETURN
    #iptables -A SYN_FLOOD -j DROP
    #iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    
    
    
    #Drop multicast, anycast and broadcast in general
    iptables -A INPUT -m addrtype --dst-type BROADCAST -j DROP
    iptables -A INPUT -m addrtype --dst-type MULTICAST -j DROP
    iptables -A INPUT -m addrtype --dst-type ANYCAST   -j DROP
    
    #Drop incoming udp traffic (up here, not started by this host)
    iptables -A INPUT -p udp -j DROP
    
    # Drop possible unicast Samba packages (to avoid bans on the same network)
    iptables -A INPUT -p tcp -m multiport --dport 135,137,138,139 -j DROP
    iptables -A INPUT -p udp -m multiport --dport 135,137,138,139 -j DROP
    
    
    
    # Whitelisted IPs. Ban not possible, no volume limits, but only
    # http(s) connections allowed.
    iptables -N LCNACT
    iptables -A LCNACT -p tcp -m multiport --dport 80,443 -j ACCEPT
    iptables -A LCNACT -j DROP
    
    # Whitelist rule set (to be filled by an update script with lines
    # as below). If source address is in the LCN set, jump to LCNACT.
    iptables -N LCN
    #iptables -I LCN -s "SOURCE_IP" -j LCNACT
    
    # Jump to the see if origin is in the whitelist or not.
    iptables -A INPUT -j LCN
    
    
    #### Everything passing here might be banned ####
    # Ban rule set (if entering BAN, remove from PREBAN, add to BAN,
    # and drop everything).
    iptables -N BAN
    # Uncomment to debug
    #iptables -A BAN -j LOG --log-prefix 'Banned: '
    iptables -A BAN -m recent --name prebanlist --remove
    iptables -A BAN -m recent --name banlist    --set    -j REJECT
    
    # Pre-ban rule set (If entering PREBAN, drop -better than reject,
    # to avoid a sooner resending-).
    iptables -N PBAN
    # Uncomment to debug
    #iptables -A PBAN -j LOG --log-prefix 'Pre-banned: '
    # Using rcheck, to avoid updating the last_seen list for this IP
    # after running this rule
    iptables -A PBAN -m recent --name prebanlist --rcheck -j DROP
    
    
    
    # Any package addressed to ports different than http(s) is a cause
    # of direct ban (no naughty peepers)
    iptables -A INPUT -p tcp -m multiport ! --dport 80,443 -j BAN
    
    
    
    # If a client exceeds 20 connections per second, preban it
    #
    # (using 'update', if the IP is not in prebanlist yet, it won't
    # match; if using 'set', as it always returns true, it would
    # always jump)
    # WARNING: any hitcount value above 20 will return 'invalid
    # argument' on execution
    iptables -A INPUT -m recent --name prebanlist --hitcount 20 \
             --seconds 2 --update -j PBAN
    
    
    # Clients are banned for two hours
    #
    # If in banlist for less than 2h, reject. If trying to access
    # again before 2h, the counter would reset after the
    # update. 'rcheck' avoids this, so after 2h it will be un-banned
    iptables -A INPUT -m recent --name banlist \
             --seconds $[2*3600]	--rcheck \
             -j REJECT --reject-with icmp-host-prohibited
    
    
    
    # Allow http and https connections from any source and update
    # preban list
    iptables -A INPUT -p tcp  --dport http -m recent \
             --name prebanlist --set -j ACCEPT
    iptables -A INPUT -p tcp  --dport https -m recent \
             --name prebanlist --set -j ACCEPT
    #iptables -A INPUT -p tcp -m multiport --dport http,https |
    #         -m recent --name prebanlist --set -j ACCEPT
    
    
    
    # If anything leaked up to here, simply reject (with a host
    # prohibited response, which is quite unexpected)
    iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
    
    
    
    
    
    
    
    ##### TOOLS #####
    
    # See recent list:
    #cat /proc/net/ipt_recent/
    #cat /proc/net/xt_recent/
    
    
    # Remove ban:
    #echo -8.8.8.8 >/proc/net/xt_recent/banlist
    
    
    # See logs:
    #tail -f /var/log/messages | grep --color=auto 8.8.8.8 &
    #tail -f /var/log/apache2/access.log &
    
    return 0
}
