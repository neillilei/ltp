#!/bin/sh
# Execute multiple processes in parallel
# returns 1 if any process returns non-zero value
# returns 0 otherwise
# usage: run_processes.sh -c <"#-separated commands">
#                  [-n <num_of_instances> ]
#                  [-a <cpu_affinity_mask>]
#                  [-d <delay_in_sec> ]
#                  [-p <priority> ]
#                  [-r <realtime priority> ]
#                  [-w] On first failure, wait for all processes
# if cpu affinity is set, then taskset is used to spawn the processes
source "functions.sh"  # Import do_cmd(), die() and other functions
pids=''
RET=0
OFS=$IFS
IFS="#"
tmp_dir=`mktemp -d`
i=0
_run_processes_kill=1 # Kill remaining process on first failure

COMMANDS_SET=0
INSTANCE_SET=0
AFFINITY_SET=0
DELAY_SET=0
PRIORITY_SET=0
RTPRIORITY_SET=0


p_instances=1
p_mask='0xFFFFFFFF'
p_delay=1
p_priority=0
r_priority=0
OPTIND=1
while getopts ":c:n:a:d:p:r:w" opt; do
  #echo "Opt is "$opt
  case $opt in
   c)
    if [[ $COMMANDS_SET = 0 ]]; then
      #echo "-commmands was triggered, Parameter: $OPTARG" >&2
      COMMANDS_SET=1
      p_commands=$OPTARG
    else
      echo "Option -commmands already was used."
      exit 1
    fi
   ;;
   n)
    if [[ $INSTANCE_SET = 0 ]]; then
      #echo "-num_instances was triggered, Parameter: $OPTARG" >&2
      INSTANCE_SET=1
      p_instances=$OPTARG
    else
      echo "Option -num_instances already was used."
      exit 1
    fi
    ;;
   a)
    if [[ $AFFINITY_SET = 0 ]]; then
      #echo "-cpu_affinity_mask was triggered, Parameter: $OPTARG" >&2
      AFFINITY_SET=1
      p_mask=$OPTARG
    else
      echo "Option -cpu_affinity_mask was already used."
      exit 1
    fi
    ;;
   d)
    if [[ $DELAY_SET = 0 ]]; then
      #echo "-inter_process_start_delay was triggered, Parameter: $OPTARG" >&2
      DELAY_SET=1
      p_delay=$OPTARG
    else
      echo "Option -inter_process_start_delay was already used."
      exit 1
    fi
    ;;
   p)
    if [[ $PRIORITY_SET = 0 ]]; then
      #echo "-task_priority was triggered, Parameter: $OPTARG" >&2
      PRIORITY_SET=1
      if [[ $OPTARG -lt 20 ]] && [[ $OPTARG -ge -20 ]]         
       then                                                          
         p_priority=$OPTARG                                     
      else
         die "Valid priority values are between -20 and +20, $OPTARG is not in valid range"
      fi
    else
      echo "Option -task_priority was already used."
      exit 1
    fi
    ;;
   r)
    if [[ $RTPRIORITY_SET = 0 ]]; then
      RTPRIORITY_SET=1
      if [[ $OPTARG -lt 100 ]] && [[ $OPTARG -ge 1 ]]
       then
         r_priority=$OPTARG
      else
         die "Valid realtime priority values are between 1 and 99, $OPTARG is not in valid range"
      fi
    else
      echo "Option -r (realtime priority) was already used."
      exit 1
    fi
    ;;
   w) 
    _run_processes_kill=0
    ;;
   \?)
    echo "Invalid option: -$OPTARG" >&2
    echo "Syntax is -c <#-separated commands> -n <num_of_instances> -a <cpu_affinity_mask> -d <inter_process_start_delay in sec> -p <task_priority>"
    ;;
  esac
done

# Start processes
for w in $p_commands 
do
  for (( j=0 ; j < $p_instances ; j++ ))
  do 
    echo "INSTANCE is $j COMMAND is $w"
    sleep $p_delay
    # if cpu affinity is set, use taskset
    if [[ $AFFINITY_SET = 1 ]]
    then
      c="taskset $p_mask $w"
      eval "$c" > $tmp_dir/log$i.$j.tmp 2>&1 &
    else
      eval "$w" > $tmp_dir/log$i.$j.tmp 2>&1 &
    fi
    process_id=$!
    if [[ $AFFINITY_SET = 1 ]]
    then
	echo "$(eval taskset -p $p_mask $process_id)"
        affinity_observed=`echo "$(eval taskset -p $process_id)"`
        affinity_observed=`echo $affinity_observed | awk 'BEGIN {FS=": "}{print $2}'`
	echo "OBSERVED affinity is $affinity_observed"
	affinity_observed=`echo '0x'$affinity_observed`
	echo "OBSERVED affinity is $affinity_observed"
        printf -v affinity_observed_decimal "%d" "$affinity_observed"
        printf -v affinity_expected_decimal "%d" "$p_mask"
        if [ $p_mask == 0xFFFFFFFF ]                                           
        then                                                                   
                cpu_count=`grep -c processor /proc/cpuinfo`
		affinity_expected_decimal=$((2**cpu_count-1))  
        fi 
        echo "OBSERVED AFFINITY is $affinity_observed_decimal and EXPECTED AFFINITY is $affinity_expected_decimal"
        if [ "$affinity_observed_decimal" -ne "$affinity_expected_decimal" ]
        then
           die "OBSERVED AFFINITY $affinity_observed_decimal and EXPECTED AFFINITY $affinity_expected_decimal do not match"
        fi
    fi
    typeset hash_${process_id}=$p_priority
    echo "$(eval echo \$hash_${process_id})"
    echo "PROCESS ID is $process_id"
    if [[ $PRIORITY_SET = 1 ]]
    then
      renice $p_priority -p $process_id
    fi
    if [[ $RTPRIORITY_SET = 1 ]]
    then
      chrt -p -r $r_priority $process_id
    fi
    pids="$pids:$process_id"
    pid_table+=( "$process_id" )
  done
  i=`expr $i + 1`
done
cnt=$i

IFS=':'

# Wait for all process to complete and check return value of process
for p in $pids
do
  if [ "x$p" != "x" ]
  then
    wait ${p}
    rc=$?
    if [ "$rc" -ne "0" ]
    then
      RET=1
      echo "*****************From run_processes.sh***********************"
      echo "Process $p exit with non-zero value at time " `date`                    
      echo ""
      if [ ${_run_processes_kill} -eq 1 ]; then
        echo "Going to kill ${pids[@]//:/ }"
        kill -9 ${pids[@]:1}
        break
      fi
    fi
  fi
done

IFS=$OFS

# Print logs in console
i=0
while [ $i -lt $cnt ]
do
  for (( j=0 ; j < $p_instances ;  j++ ))
  do
    process_id=${pid_table[$j]}
    echo $process_id
    echo "*************  start of $tmp_dir/log$i.$j.tmp    ***************"
    echo "Task priority is $(eval echo \$hash_${process_id})"
    cat $tmp_dir/log$i.$j.tmp
    echo "*************  end of $tmp_dir/log$i.$j.tmp    ***************"
  done
  i=`expr $i + 1`
done
exit $RET
