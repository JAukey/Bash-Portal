#!/bin/bash
VERSION="0.1"
valid_ip()
{
    local  ip=$1
    local  ipport=0
    local  stat=1
    local  ipRegular="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
    local  ipportalRegular="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\:[0-9]{2,5}$"
    if [ -z "$ip" ];then                                                                                
        echo "The ip shouldn't be empty!"                                                              
        exit 1                                                                                         
    else                                                                                               
        if [[ "$ip" =~ $ipportalRegular ]]; then
            OIFS=$IFS 
            IFS=':'  
            ipportal=($ip)
            IFS=$OIFS     
            OIFS=$IFS
            IFS='.'  
            ip=(${ipport[0]})
            IFS=$OIFS        
            [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 && ${ipport[1]} -le 65535 ]]
            stat=$?
        else
	    if [[ "$ip" =~ $ipRegular ]]; then                                                                        
                OIFS=$IFS                                                                                                   
                IFS='.'                                                                                                     
                ip=($ip)                                                                                              
                IFS=$OIFS                                                                                                   
                [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
                stat=$?                                                                                                     
            fi                                                                                    
        fi
  	if [ $stat -eq 1 ];then                                                                                        
            echo "Wrong IP or Port!"                                                                                
            exit 1                                                                                                  
        fi 
    fi         
   return 
} 
valid_interface(){
    OLD_IFS="$IFS"                                                               
    IFS=","                                                              
    local arr=($1)                                                                         
    IFS="$OLD_IFS"
    for i in ${arr[@]}                                                                                                  
    do                                                                                                                  
	if [ -z "$(ifconfig $i 2>/dev/null)" ];then                                                                     
                if [ $i = "start" ];then                                                                                
                    echo "The Interface shouldn't be empty!"                                                            
                    exit 1                                                                                               
                fi                                                                                                      
                    echo $(ifconfig $i 2>&1)                                                                            
                exit 1                                                                                                  
        fi                                                                                                              
    done
    return  
}
iptables_init(){
    valid_interface $1
    valid_ip $4
    if [ ! -f "/tmp/portal.list" ]; then 
	echo "====================
Portal Status
====================
Version: $VERSION
Start time: $(date +%s)
Managed interface: $1
Server ip: $4
++++++++++++++++++++" > "/tmp/portal.list"	
    else
        echo "Bash Portal had started!"
        exit 1
    fi
    OLD_IFS="$IFS"                                                                                                            
    IFS=","                                                                                                                   
    local arr=($1)                                                                                                                  
    IFS="$OLD_IFS"
    iptables -t nat -N ndsOUT -w
    iptables -t mangle -N ndsOUT -w
    iptables -t mangle -N ndsINC -w
    iptables -t filter -N ndsNET -w
    iptables -t filter -N ndsAUT -w
    for i in ${arr[@]}
    do
	iptables -t nat -I PREROUTING 1 -i $i -j ndsOUT -w
	iptables -t mangle -I PREROUTING 1 -i $i -j ndsOUT -w
	iptables -t mangle -I POSTROUTING 1 -o $i -j ndsINC -w
    iptables -t filter -I FORWARD 1 -i $i -j ndsNET -w
     done
    iptables -t nat -A ndsOUT -m mark --mark 0x400/0x700 -j ACCEPT -w
    iptables -t nat -A ndsOUT -p tcp -m tcp --dport 53 -j ACCEPT -w
    iptables -t nat -A ndsOUT -p udp -m udp --dport 53 -j ACCEPT -w
    iptables -t nat -A ndsOUT -p tcp -m tcp --dport 80 -j DNAT --to-destination $4 -w	
    iptables -t nat -A ndsOUT -j ACCEPT -w
    iptables -t filter -A ndsNET -m state --state INVALID -j DROP -w
    iptables -t filter -A ndsNET -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu -w
    iptables -t filter -A ndsNET -m mark --mark 0x400/0x700 -j ndsAUT -w
    iptables -t filter -A ndsNET -p tcp -m tcp --dport 53 -j ACCEPT -w
    iptables -t filter -A ndsNET -p udp -m udp --dport 53 -j ACCEPT -w
    iptables -t filter -A ndsNET -j REJECT --reject-with icmp-port-unreachable -w
    iptables -t filter -A ndsAUT -m state --state RELATED,ESTABLISHED -j ACCEPT -w
    iptables -t filter -A ndsAUT -j ACCEPT -w
}
iptables_delete(){
    valid_interface $1
    OLD_IFS="$IFS"                                                                                                            
    IFS=","                                                                                                                   
    local arr=($1)                                                                                                            
    IFS="$OLD_IFS" 
    if [ ! -f "/tmp/portal.list" ]; then 
	    echo "Bash Portal had stoped!"
        exit 1
    else
        rm -f /tmp/portal.list
    fi
    iptables -t nat -F ndsOUT -w
    iptables -t mangle -F ndsOUT -w
    iptables -t mangle -F ndsINC -w 
    iptables -t filter -F ndsAUT -w
    iptables -t filter -F ndsNET -w
    for i in ${arr[@]}                                                               
    do                                                                                 
        iptables -t nat -D PREROUTING -i $i -j ndsOUT -w                         
        iptables -t mangle -D PREROUTING -i $i -j ndsOUT -w                      
        iptables -t mangle -D POSTROUTING -o $i -j ndsINC -w  
        iptables -t filter -D FORWARD -i $i -j ndsNET -w
    done 
    iptables -t nat -X ndsOUT -w
    iptables -t mangle -X ndsOUT -w
    iptables -t mangle -X ndsINC -w
    iptables -t filter -X ndsAUT -w
    iptables -t filter -X ndsNET -w
}
iptables_status(){
local clientcount=-1
while read line
do
    local words=$line
    if [ -n "$(echo $words | sed -n '/Start time/p')" ];then
        local nowtime=$(date +%s)
        local begintime=${words#Start time: } 
        let local rangetime=nowtime-begintime
        echo ${line%:*}": $(date -d @$begintime)"
        echo "Start duration: "$[$rangetime/86400]" Day "$[$rangetime%86400/3600]" Hour "$[$rangetime%3600/60]" Min "$[$rangetime%60]" Sec"
    else
        if [ "$line" = "++++++++++++++++++++" ];then
            clientcount=0
            echo "Total download: $(iptables -n -v -t mangle -L POSTROUTING | awk 'NR==3 {print $2}')"	
            echo "Total upload: $(iptables -n -v -t mangle -L PREROUTING | awk 'NR==3 {print $2}')"	
            echo "++++++++++++++++++++"
        else
            if [ $clientcount -ge 0 ];then
                arr=($line)
                begintime=${arr[0]}
                let rangetime=nowtime-begintime
                let clientcount++
                echo " "
                echo "Client: $clientcount"
                echo "IP: ${arr[2]} MAC: ${arr[1]}"
                echo "Added time: $(date -d @${arr[0]})"
                echo "Added duration: "$[$rangetime/86400]" Day "$[$rangetime%86400/3600]" Hour "$[$rangetime%3600/60]" Min "$[$rangetime%60]" Sec"
                echo "Download: $(iptables -n -v -t mangle -L ndsINC | grep -w "${arr[2]}" | awk 'NR==1 {print $2}')"
                echo "Upload: $(iptables -n -v -t mangle -L ndsOUT | grep -w "${arr[2]}" | awk 'NR==1 {print $2}')"
            else
            echo $line
            fi
        fi
    fi
done < /tmp/portal.list
}
client_add(){
        OLD_IFS="$IFS"                                                                                                            
        IFS=","                                                                                                                   
        local arr=($1)                                                                                                            
        IFS="$OLD_IFS" 
	if [ $arr = "clientsadd" ];then
	    echo "The ip shouldn't be empty!"
	    exit 1
        fi
	for i in ${arr[@]}
	do
		valid_ip $i
		if [ -n "$(iptables-save | grep -w "ndsOUT -s $i/32")" ];then        
    		        echo "IP is in the iptables!"
			continue	
		fi 
		arpmac=$(cat /proc/net/arp | grep -w "$i" | awk '{print $4}')
		if [ -n "$arpmac" ];then
	        sed -i '$a '$(date +%s)' '$arpmac' '$i'' /tmp/portal.list
			iptables -t mangle -A ndsINC -d $i/32 -j MARK --set-xmark 0xa400/0xa400 -w
			iptables -t mangle -A ndsINC -d $i/32 -j ACCEPT -w
			iptables -t mangle -A ndsOUT -s $i/32 -m mac --mac-source $arpmac -j MARK --set-xmark 0xa400/0xa400 -w
		else
			echo "ip is not in arp!"
		fi
	done
}
client_delete(){
	OLD_IFS="$IFS"                                                                                                            
        IFS=","                                                                                                                   
        local arr=($1)                                                                                                            
        IFS="$OLD_IFS" 
	if [ $arr = "clientsdelete" ];then                                                                                       
            echo "The ip shouldn't be empty!"                                                                                 
            exit 1                                                                                                            
        fi 
	for i in ${arr[@]}
	do
		valid_ip $i
		if [ -z "$(iptables-save | grep -w "ndsOUT -s $i/32")" ];then                                                 
            echo "IP is not in the iptables!"                                                                                      
            continue                                                                                              
        fi 
		arpmac=$(cat /proc/net/arp | grep -w "$i" | awk '{print $4}')
		if [ -n "$arpmac" ];then
			sed -i '/'$arpmac'/d' /tmp/portal.list
			iptables -t mangle -D ndsINC -d $i/32 -j MARK --set-xmark 0xa400/0xa400 -w
			iptables -t mangle -D ndsINC -d $i/32 -j ACCEPT -w
			iptables -t mangle -D ndsOUT -s $i/32 -m mac --mac-source $arpmac -j MARK --set-xmark 0xa400/0xa400 -w
		else
			echo "ip is not in arp!"
		fi
	done
}
main(){
	case $1 in
	    "start")
		iptables_init $2 $@
		;;
	    "stop")
		iptables_delete $2 $@
		;;
	    "status")
		iptables_status $2 $@
		;;
	    "clientsadd")
		client_add $2 $@
		;;
	    "clientsdelete")
		client_delete $2 $@
		;;
	      *)
	 	echo "Wrong Cmd!"
		;;
	esac
}
main $@
