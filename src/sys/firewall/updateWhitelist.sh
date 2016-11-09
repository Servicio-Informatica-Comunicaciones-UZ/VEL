#!/bin/bash

. /usr/local/bin/common.sh


PATH=$PATH:/sbin:/usr/sbin



#Get domains in list
x=$(cat /etc/whitelist | sort | uniq |
           grep -Ee '^\s*(([a-zA-Z](-?[a-zA-Z0-9])*)\.)*[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}\s*$' |
           sed -re 's%^\s*(.+)\s*$%iptables -I LCN -s "\1" -j LCNACT%g')

#Get IPs in list
y=$(cat /etc/whitelist | sort | uniq |
           grep -Ee '^\s*[0-9]{1,3}(\.[0-9]{1,3}){3}\s*$' |
           sed -re 's%^\s*(.+)\s*$%iptables -I LCN -s "\1" -j LCNACT%g')


#To avoid removing the existing whitelist if any read or parsing error ocurred
if [ "$x" != "" -o "$y" != ""  ]; then 
    iptables -F LCN
    #iptables -I LCN -s "www.example.com" -j LCNACT
    echo "$x" | sh
    #iptables -I LCN -s "127.0.0.1" -j LCNACT
    echo "$y" | sh
fi
