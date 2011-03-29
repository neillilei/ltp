#!/bin/sh

# Get devnode for non mtd device like 'mmc', 'usb', 'ata'
# Input: DEVICE_TYPE like 'mmc', 'usb', 'ata'
# Output: DEV_NODE like /dev/mmcblk0p1 

source "common.sh"
source "mtd_common.sh"


if [ $# -ne 1 ]; then
        echo "Error: Invalid Argument Count"
        echo "Syntax: $0 <device_type>"
        exit 1
fi
DEVICE_TYPE=$1

############################ Default Params ##############################
DEV_TYPE=`get_device_type_map.sh "$DEVICE_TYPE"` || die "error getting device type"
case $DEV_TYPE in
        mtd)
		PART=`get_mtd_partition_number.sh "$DEVICE_TYPE"` || die "error getting mtd partition number"
		DEV_NODE="$MTD_BLK_DEV$PART"
        ;;
        mmc)
                DEV_NODE="/dev/mmcblk0p1"
        ;;
        usb)
                DEV_NODE="/dev/sda1"
        ;;
        ata)
                DEV_NODE="/dev/hda1"
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
echo $DEV_NODE