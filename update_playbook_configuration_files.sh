#!/bin/bash


COPY_CMD="rsync -a"
HOST="jibux-server"

copy() {
	$COPY_CMD root@$HOST:$2 roles/$1/files/$3
}

copy raspberry /etc/modprobe.d/raspi-blacklist.conf raspi-blacklist.conf

copy misc /root/.bashrc root_bashrc
copy misc /var/spool/cron/crontabs/root cron_root

