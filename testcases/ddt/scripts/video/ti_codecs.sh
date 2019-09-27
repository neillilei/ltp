#! /bin/bash
#
# Copyright (C) 2019 Texas Instruments Incorporated - http://www.ti.com/
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

source "common.sh"
source "st_log.sh"
source "functions.sh"

# Load require video modules
insert_video_modules()
{
	local _modules="videobuf2-common.ko videobuf2-memops.ko videobuf2-v4l2.ko videobuf2-dma-sg.ko videobuf2-dma-contig.ko v4l2-mem2mem.ko vxd-dec.ko vxe_enc.ko"
	for m in $_modules; do
		lsmod | grep ${m%.ko} || modprobe $m
	done
}

# Run TI decoder
run_tidec_decode()
{
	insert_video_modules
	tidec_decode -b $* | grep 'test app completed successfully'
}

# Run TI encoder
run_tienc_encode()
{
	insert_video_modules
	tienc_encode $*
}

# Download Test media if not in fs
get_media()
{
	local __media_url=http://gtopentest-server.gt.design.ti.com/anonymous/common/Multimedia/ti-img-encode-decode-testvecs/$1
	local __checksums=/tmp/checksums.txt
	local __media_folder=/usr/share/ti/tidec-decode
	local __media

  if [[ "$1" == "encoder" ]]
  then
    __media_folder=/usr/share/ti/tienc-encode
  fi
	ls ${__media_folder} &>/dev/null || mkdir -p ${__media_folder}
	local __media_checksum=$(md5sum ${__media_folder}/* | awk '{print $1}' | sort -u)
	Wget ${__media_url}/media_checksums.txt -O ${__checksums} || return 1
	local __remote_checksum=$(awk '{print $1}' ${__checksums} | sort -u)
	local __remote_media=$(awk '{print $2}' ${__checksums} | sort -u)
	if [[ "$__media_checksum" != "$__remote_checksum" ]]
	then
		rm ${__media_folder}/*
		for __media in $__remote_media
		do
		    Wget ${__media_url}/${__media} -O ${__media_folder}/`basename ${__media}` || echo "Could not download  ${__media_url}/${__media}"
		done
	fi
}

# Stop weston
stop_weston()
{
  ps -ef | grep -i weston | grep -v grep && /etc/init.d/weston stop && sleep 3
}
