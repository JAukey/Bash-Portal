#!/bin/bash
iptables_init(){
	arr=$1
	iptables -t nat -N ndsOUT -w
	iptables -t mangle -N ndsOUT -w
	iptables -t mangle -N ndsINC -w
	for i in ${arr[@]}
	do
		iptables -t nat -I PREROUTING 1 -i $i -j ndsOUT -w
		iptables -t mangle -I PREROUTING 1 -i $i -j ndsOUT -w
		iptables -t mangle -I POSTROUTING 1 -o $i -j ndsINC -w
	done
	iptables -t nat -A ndsOUT -m mark --mark 0x400/0x700 -j ACCEPT -w
	iptables -t nat -A ndsOUT -p tcp -m tcp --dport 80 -j DNAT --to-destination $4 -w	
	#iptables -t nat -A ndsOUT -p udp  -m udp --dport 53 -j DNAT --to-destination $5 -w	
}
iptables_delete(){
	arr=$1
	iptables -t nat -F ndsOUT -w
        iptables -t mangle -F ndsOUT -w
        iptables -t mangle -F ndsINC -w
	for i in ${arr[@]}                                                               
        do                                                                                 
                iptables -t nat -D PREROUTING -i $i -j ndsOUT -w                         
                iptables -t mangle -D PREROUTING -i $i -j ndsOUT -w                      
                iptables -t mangle -D POSTROUTING -o $i -j ndsINC -w                     
        done 
	iptables -t nat -X ndsOUT -w
        iptables -t mangle -X ndsOUT -w
        iptables -t mangle -X ndsINC -w
  
}
client_add(){
	arr=$1
	for i in ${arr[@]}
	do
		arpmac=$(cat /proc/net/arp | grep -w "$i" | awk '{print $4}')
		if [ -n "$arpmac" ];then
			iptables -t mangle -A ndsINC -d $i/32 -j MARK --set-xmark 0xa400/0xa400 -w
			iptables -t mangle -A ndsINC -d $i/32 -j ACCEPT -w
			iptables -t mangle -A ndsOUT -s $i/32 -m mac --mac-source $arpmac -j MARK --set-xmark 0xa400/0xa400 -w
		else
			echo "ip is not in arp!"
		fi
	done
}
client_delete(){
	arr=$1
	for i in ${arr[@]}
	do
		arpmac=$(cat /proc/net/arp | grep -w "$i" | awk '{print $4}')
		if [ -n "$arpmac" ];then
			iptables -t mangle -D ndsINC -d $i/32 -j MARK --set-xmark 0xa400/0xa400 -w
			iptables -t mangle -D ndsINC -d $i/32 -j ACCEPT -w
			iptables -t mangle -D ndsOUT -s $i/32 -m mac --mac-source $arpmac -j MARK --set-xmark 0xa400/0xa400 -w
		else
			echo "ip is not in arp!"
		fi
	done
}
main(){
	OLD_IFS="$IFS"                                                                     
        IFS=","                                                                            
        arr=($2)                                                                           
        IFS="$OLD_IFS" 
	case $1 in
	    "start")
		iptables_init $arr $@
		;;
	    "stop")
		iptables_delete $arr $@
		;;
	    "clientsadd")
		client_add $arr $@
		;;
	     "clientsdelete")
		client_delete $arr $@
		;;
	      *)
	 	echo "Wrong Cmd!"
		;;
	esac
}
main $@
