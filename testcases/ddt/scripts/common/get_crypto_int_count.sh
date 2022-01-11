source "common.sh"                                                      
                                                                        
############################### CLI Params ###################################
ip_type=$1                                                                              
############################ USER-DEFINED Params ##############################
# Try to avoid defining values here, instead see if possible                   
# to determine the value dynamically                                           
CRYPTO_IP=''
case $ARCH in                                                        
esac                                                                 
case $DRIVER in                                                      
esac                                                              
case $SOC in                                  
am64xx|am62xx|am654|j7*)
	count=`get_num_sa2ul_interrupts.sh -c 0`
;;
*)
	IRQ_NUM=`get_irq_for_iface.sh -i $ip_type`
	count=`get_num_interrupts_for_irq.sh -i $IRQ_NUM -c 0`
;;        
esac              
echo $count
