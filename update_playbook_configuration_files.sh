#!/bin/bash


COPY_CMD="rsync -a"
HOST="jibux-server.local"

copy()
{
	$COPY_CMD "root@$HOST:$2" "roles/$1/files/$3"
}

copy raspberry /etc/modprobe.d/raspi-blacklist.conf raspi-blacklist.conf

copy misc /etc/hosts hosts
copy misc /etc/vim/vimrc vimrc
copy misc /root/.bashrc root_bashrc
copy misc /root/.selected_editor .selected_editor
copy misc /etc/apt/apt.conf.d/50unattended-upgrades 50unattended-upgrades
copy misc /etc/hdparm.conf hdparm.conf
copy misc /etc/auto.mnt auto.mnt
copy misc /etc/auto.master auto.master
copy misc /var/spool/cron/crontabs/root cron_root
copy misc /root/scripts/reboot.sh reboot.sh

copy webserver /etc/apache2/apache2.conf apache2.conf
copy webserver /etc/apache2/ports.conf ports.conf
copy webserver /etc/apache2/sites-available/000-default.conf 000-default.conf
copy webserver /etc/apache2/sites-available/jibux.info.conf jibux.info.conf
copy webserver /etc/apache2/conf-available/security.conf security.conf
copy webserver /etc/php/7.4/fpm/pool.d/jb_dedi_web.conf jb_dedi_web.conf
copy webserver /etc/php/7.4/fpm/php-fpm.conf php-fpm.conf
copy webserver /etc/php/7.4/fpm/php.ini php.ini
copy webserver /etc/default/sslh sslh
copy webserver /etc/mysql/my.cnf my.cnf
copy webserver /etc/iptables/rules.v4 rules.v4
copy webserver /etc/iptables/rules.v6 rules.v6
copy webserver /etc/fail2ban/jail.local f2b_jail.local
copy webserver /etc/sudoers sudoers
copy webserver /etc/ssh/sshd_config sshd_config
copy webserver /etc/network/interfaces interfaces
copy webserver /etc/logrotate.d/apache2-private apache2-private
copy webserver /etc/logrotate.d/renew_lets_encrypt renew_lets_encrypt
copy webserver /etc/logrotate.d/openvpn openvpn

copy mailserver /etc/postfix/master.cf master.cf
copy mailserver /etc/postfix/main.cf main.cf
copy mailserver /etc/postfix/generic generic
copy mailserver /etc/postfix/canonical.recipient canonical.recipient
copy mailserver /etc/postfix/smtp_reply_filter smtp_reply_filter
copy mailserver /etc/postfix/mysql-virtual_domains.cf mysql-virtual_domains.cf
copy mailserver /etc/postfix/mysql-virtual_email2email.cf mysql-virtual_email2email.cf
copy mailserver /etc/postfix/mysql-virtual_forwardings.cf mysql-virtual_forwardings.cf
copy mailserver /etc/postfix/mysql-virtual_mailboxes.cf mysql-virtual_mailboxes.cf
copy mailserver /etc/postfix/mysql-virtual_mailbox_limit_maps.cf mysql-virtual_mailbox_limit_maps.cf
copy mailserver /etc/postfix/mysql-virtual_transports.cf mysql-virtual_transports.cf
copy mailserver /etc/mailname mailname
copy mailserver /etc/aliases aliases

