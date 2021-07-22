#!/bin/bash


MESSAGE="$(hostname) rebooted at: $(date +"%d-%m-%Y %H:%M:%S")"

mail -r root@jibux.info -s "$MESSAGE" admin@jibux.info<<<"$MESSAGE"

/home/data/scripts/ssl/renew_lets_encrypt.sh &>>/var/log/renew_lets_encrypt.log

