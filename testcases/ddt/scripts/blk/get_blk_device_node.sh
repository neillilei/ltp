#!/bin/sh 
# 
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
# 

# Get devnode for non mtd device like 'mmc', 'usb', 'usbxhci', 'sata'
# Input: DEVICE_TYPE like 'mmc', 'usb', 'usbxhci', 'sata'
# Optional Input: DEVICE PROPERTIES like 'superspeed'
# Output: DEV_NODE like /dev/mmcblk0p1 

source "common.sh"
source "mtd_common.sh"
source "blk_device_common.sh"

if [ $# -lt 1 ]; then
    echo "Error: Invalid Argument Count"
    echo "Syntax: $0 <device_type> <optional_param>"
    exit 1
fi
DEVICE_TYPE=$1
EXTRA_PARAM=$2
############################ Functions ################################
# this function is to get SCSI device usb or sata node based on by-id
# input is either 'sata' or 'usb' or 'usbxhci'
 
find_scsi_basenode() {
  SCSI_DEVICE=$1
    case $SCSI_DEVICE in
      sata)
        # remove DVD
        files=`ls /dev/disk/by-id/* |grep -v "DRW" |grep -i ata `
        if [[ ! -z "$files" ]]; then
          for file in $files; do
              basenode="/dev/""$(basename $(readlink $file))"
              udevadm info -a -n $basenode |grep -i 'pci' > /dev/null && continue 
              echo $basenode
              exit 0
          done
        fi
      ;;
      usb|usbxhci)
        usb_cnt_interface=`get_usb_controller_name.sh "$SCSI_DEVICE"`
        usb_speed_found=1
        # in USB case, extra param is used to indicate usb speed
        DEVICE_SPEED=$EXTRA_PARAM
        for file in `ls /dev/disk/by-path/* |grep -i "$usb_cnt_interface" |head -1`
        do
        	if [[ ! -z "$file" ]]; then
        		basenode="/dev/""$(basename $(readlink $file))"
            if [[ ! -z "$DEVICE_SPEED" ]]; then
              usb_speed=`find_usbhost_speed.sh "$DEVICE_SPEED"`
              speed=`udevadm info -a -n $DEV_NODE|grep speed`
              for speed in `udevadm info -a -n $DEV_NODE|grep speed`
              do
                if [[ "${speed}" == *$usb_speed* ]]; then
                  echo $basenode
                  exit 0
                else
                  usb_speed_found=0
                fi
              done
            fi
        	fi
        done
        if [[ ! -z "$usb_speed_found" ]]; then
          echo $basenode
          exit 0
        else
          echo "Could not find USB device or USB device with specified speed"
          exit 1
        fi
      ;;

      pci)
        file=`ls /dev/disk/by-path/* |grep -i 'pci'|head -1`
        if [[ ! -z "$file" ]]; then
          basenode="/dev/""$(basename $(readlink $file))"
          echo $basenode
          exit 0
        fi
      ;;
    esac
  # if could not find match, let user know
  echo "Could not find device node for SCSI device!"
  exit 1
}

# return: /dev/mmcblk0 etc
find_emmc_basenode() {
    emmc_node=`ls /dev/mmcblk* |grep boot |head -1 |sed s'/boot[0-9]*//' `
    echo $emmc_node
}

find_mmc_basenode() {
    emmc_node=`find_emmc_basenode` 
    if [ -n "$emmc_node" ]; then
      mmc_node=`ls /dev/mmcblk* |sed s",$emmc_node.*$,,g" |grep -E ".*blk[[:digit:]]+$" |head -1`
    else
      mmc_node=`ls /dev/mmcblk* |grep -E ".*blk[[:digit:]]+$" |head -1`
    fi  
    echo $mmc_node
}


############################ Default Params ##############################
DEV_TYPE=`get_device_type_map.sh "$DEVICE_TYPE"` || die "error getting device type: $DEV_TYPE"
case $DEV_TYPE in
        mtd)
          PART=`get_mtd_partition_number.sh "$DEVICE_TYPE"` || die "error getting mtd partition number: $PART"
          DEV_NODE="$MTD_BLK_DEV$PART"
        ;;
        mmc)
          mmc_basenode=`find_mmc_basenode`
          if [ -z "$mmc_basenode" ]; then
            die "Could not fine mmc basenode"
          fi
          DEV_NODE=`find_part_with_biggest_size "$mmc_basenode" "mmc"` || die "error getting partition with biggest size: $DEV_NODE"
        ;;
        emmc)
          emmc_basenode=`find_emmc_basenode`
          if [ -z "$emmc_basenode" ]; then
            die "Could not fine emmc basenode"
          fi
          # create two partition if emmc doesn't have any partition on it
          create_three_partitions $emmc_basenode 80 1024 > /dev/null
          DEV_NODE=`find_part_with_biggest_size "$emmc_basenode" "emmc"` || die "error getting partition with biggest size: $DEV_NODE"
        ;;
        usb)
          basenode=`find_scsi_basenode "usb"` || die "error getting usb base node: $basenode"
          # create 3 partitions with the size 80M, 2048M, and remaining if there is no partition
          create_three_partitions $basenode 80 1024 > /dev/null
          DEV_NODE=`find_part_with_biggest_size "$basenode" "usb"` || die "error getting partition with biggest size: $DEV_NODE"
        ;;
        usbxhci)
          basenode=`find_scsi_basenode "usbxhci"` || die "error getting usbxhci base node: $basenode" 
          create_three_partitions $basenode 80 1024 > /dev/null
          DEV_NODE=`find_part_with_biggest_size "$basenode" "usbxhci"` || die "error getting partition with biggest size: $DEV_NODE"
        ;;
        pci)
          basenode=`find_scsi_basenode "pci"` || die "error getting pci basenode: $basenode" 
          create_three_partitions $basenode 80 2048 > /dev/null
          DEV_NODE=`find_part_with_biggest_size "$basenode" "pci"` || die "error getting partition with biggest size: $DEV_NODE"
        ;;
        ata)
          DEV_NODE="/dev/hda1"
        ;;
        sata)
          basenode=`find_scsi_basenode "sata"` || die "error getting sata basenode: $basenode" 
          # Typically, sata harddisk is big, so create 16G (16384) to be able to run 10G filesize test 
          create_three_partitions $basenode 80 16384 > /dev/null
          DEV_NODE=`find_part_with_biggest_size "$basenode" "sata"` || die "error getting partition with biggest size: $DEV_NODE"
        ;;
        *)
          die "Invalid device type in $0 script"
        ;;
esac

############################ USER-DEFINED Params ##############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
esac

######################### Logic here ###########################################
if [ -n "$DEV_NODE" ]; then
  echo $DEV_NODE
else
  die "Was not able to get devnode to test. Backtrace:: $DEV_NODE ::"
fi
