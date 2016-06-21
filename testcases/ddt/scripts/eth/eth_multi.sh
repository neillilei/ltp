#! /bin/sh
############################################################################### 
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
#  
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation version 2.
# 
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################
source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
                                                                                
########################### REUSABLE TEST LOGIC ############################### 
# Usage information: eth_multi.sh -l <num_of_iterations> 
#                                 -t <type_of_test - example, 
#                                        ifupdown for ifdown/ifup on all interfaces,
#                                        ping for pinging each of the interfaces
#                                        ping_updown for pinging one interface while doing ifdown/ifup on
#                                           all other interfaces, 
#                                        ping_down for pinging on interface while bringing down 
#                                           all other interfaces
#                                 -s <sequence of network up/down operations>
#                                      example - all - bring all interfaces down and then bring them all up
#                                                one - bring one interface down and up before performing same 
#                                                      on another interface 
#                                 -d <duration of ping in seconds>
#                                 -p <packetsize for ping in bytes>   
#                                 -i <interfaces - example all>
#                                 -m <module_type - example pru>
#################################################################################

################################################################################
# Cleanup function for use before the test exits
################################################################################
do_cleanup()
{ 
  for device in `find /sys/class/net/*eth*`
  do 
    interface=`echo $device | cut -c16-`
    do_eth_up_down.sh -d "up" -i "$interface"
  done
}
p_iterations=10
p_type='ifupdown'
p_sequence='one'
p_duration=10
p_pktsize=64
p_interfaces='all'
p_module=''
OFS=$IFS
while getopts ":l:t:s:d:p:i:m:" opt; do
  case $opt in 
  l)
    p_iterations=$OPTARG
    ;;
  t)
    p_type="$OPTARG"
    ;;
  s)
    p_sequence="$OPTARG"
    ;;
  d)
    p_duration=$OPTARG
    ;;
  p)
    p_pktsize=$OPTARG
    ;;
  i)
   p_interfaces="$OPTARG"
   ;;
  m)
   p_module="$OPTARG"
  esac
done

# check for all eth interfaces supported and create an array
j=0
for device in `find /sys/class/net/*eth*`
do 
  operstate='down'
  interface=`echo $device | cut -c16-`
  `ifdown $interface`
  if [ ! -z "$p_module" ]
  then
    driver=`ethtool -i $interface|grep driver|grep -i $p_module`
    if [ ! -z "$driver" ]
    then
      if [ "$p_interfaces" == 'all' ] || [ "$operstate" == 'up' ]
      then
        int_name[j]=$interface
        ((j=j+1))
      fi
    fi
  else
    operstate=`cat /sys/class/net/$interface/operstate`
    if [ "$p_interfaces" == 'all' ] || [ "$operstate" == 'up' ]
    then
      int_name[j]=$interface
      ((j=j+1))
    fi
  fi
done

# First, bring every interface down
for interface in ${int_name[@]}
do
	do_eth_up_down.sh -d "down" -i "$interface"
done

# for each eth interface, find the corresponding gateway
for (( j=0; j < ${#int_name[@]}; j++ ))
do
 del_default_gateway.sh
 do_eth_up_down.sh -d "up" -i "${int_name[$j]}"
 eth_gateway[j]=`get_eth_gateway.sh -i ${int_name[j]}` || die "Error getting eth gateway for ${int_name[j]}"
 do_eth_up_down.sh -d "down" -i "${int_name[j]}"
done

# Bring up every interface before proceeding further
for interface in ${int_name[@]}
do
	do_eth_up_down.sh -d "up" -i "$interface"
done

# Now run the test based on command-line parameters
if [ "$p_type" = 'ping_updown' ] || [ "$p_type" = 'ping_down' ]
then
# for every interface
# start ping in background
# for every other interface
# do ifdown (and ifup, if applicable) on all other interfaces
  	for (( i=0; i < ${#int_name[@]}; i++ ))
  	do
    		do_eth_up_down.sh -d "down" -i "${int_name[i]}"
    		do_eth_up_down.sh -d "up" -i "${int_name[i]}"
    		rm nohup.out
    		nohup ping ${eth_gateway[i]} -s $p_pktsize -w $p_duration & 
    		pid=$!
    		for (( k=0; k<$p_iterations; k++ ))
    		do
       			if [ "$p_type" = 'ping_updown' ] 
       			then
         			for (( j=0; j<${#int_name[@]}; j++ ))
         			do
           				if [[ $j != $i ]]
           				then
    						do_eth_up_down.sh -d "down" -i "${int_name[j]}"
    						do_eth_up_down.sh -d "up" -i "${int_name[j]}"
           				fi  
         			done
       			elif [ "$p_type" = 'ping_down' ]
       			then
         			for (( j=0; j<${#int_name[@]}; j++ ))
         			do
             				if [[ $j != $i ]]
             				then
    						do_eth_up_down.sh -d "down" -i "${int_name[j]}"
             				fi  
           			done
           			k=$p_iterations
         		fi
    		done # for each iteration
    # wait for ping process to be completed
    		if [ "x$pid" != "x" ]                                               
    		then                                                              
      			wait ${pid}                                                       
      			rc=$?                                                           
      			if [ "$rc" -ne "0" ]                                            
      			then                                                            
        			die "Ping Process failed"                                                         
        			break                                                         
      			fi                                                              
    		fi                                                                
    		result=`cat nohup.out | grep " 0% packet loss"`
    		if [[ ! -n "$result" ]] 
    		then   
      			echo "$result"
      			die "${int_name[i]} - Ping resulted in packet loss"
    		fi
    		result=`cat nohup.out | grep "Network is unreachable"`
    		if [[ -n "$result" ]] 
    		then   
      			echo "$result"
      			die "${int_name[i]} - Network is unreachable"
    		fi
  	done 
# for each interface
#### done with ping_updown and ping_down, so perform other cases now
  elif [ "$p_sequence" = 'one' ]
  then
  	for (( k=0; k < ${#int_name[@]}; k++ ))
     	do
       		for (( i=0; i < $p_iterations ; i++ ))
       		do 
         	case $p_type in
         		'ifupdown')
    			do_eth_up_down.sh -d "down" -i "${int_name[k]}"
    			do_eth_up_down.sh -d "up" -i "${int_name[k]}"
          	;;
         		'ping')
           		do_cmd "ping ${eth_gateway[k]} -s $p_pktsize -w $p_duration"
          	;;
         	esac
      	done
    done 

  elif [ "$p_sequence" = 'reverse' ]
  then
	echo "Reverse sequence"
    	for (( i=0; i<$p_iterations ; i++ ))
    	do
      		for interface in ${int_name[@]}
      		do
        		if [ "$p_type" = 'ifupdown' ] 
        		then
    				do_eth_up_down.sh -d "down" -i "$interface"
        		fi
      		done
      		for (( j=${#int_name[@]}; j>0; j-- ))
      		do
        		if [ "$p_type" = 'ifupdown' ] 
        		then
    				do_eth_up_down.sh -d "up" -i "${int_name[j-1]}"
        		elif [ "$p_type" = 'ping' ] 
        		then
          			do_cmd "ping ${eth_gateway[j-1]} -s $p_pktsize -w $p_duration"
        		fi
      		done
   	done
   	elif [ "$p_sequence" = 'all' ]
   	then
     		for (( i=0; i<$p_iterations ; i++ ))
     		do
       			for (( k=0; k<${#int_name[@]}; k++ ))
       			do 
         		case $p_type in
         		'ifupdown')
    				do_eth_up_down.sh -d "down" -i "${int_name[k]}"
    				do_eth_up_down.sh -d "up" -i "${int_name[k]}"
          		;;
    
          		'ping')
             			do_cmd "ping ${eth_gateway[k]} -c 3 -w $p_duration -s $p_pktsize"
          		;;
         		esac
       		done 
     	done
   	fi
do_cleanup

IFS=$OFS
