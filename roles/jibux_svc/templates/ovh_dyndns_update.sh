#!/bin/bash


set -o errexit -o errtrace -o pipefail -o nounset


usage()
{
	echo "Update OVH dyndns entry for specific hostname"
	echo "Usage: $0 --hostname=<hostname> --cred-file=<OVH dyndns credentials> [other options]"
	echo "By default, will use src IP of default route"
	echo "--cred-file should be formated like this:"
	echo -e "USER_NAME=<user name>\nPASSWORD=<password>"
	echo "Other options:"
	echo "--ip=w.x.y.z - use specific IP"
	echo "--interface=iface - use specific interface"
	echo "--router-whitelist=a:b:c:d,e:f:g:h - update dns only if router mac address is matching one of the list"
	echo "--public - use router public IP instead of local private IP"
	echo "--force - force DNS update even if the hostname already resolves the good IP"
}

exit_usage()
{
	usage
	exit 1
}

date_fmt()
{
	date +"%Y-%m-%d %H:%M:%S"
}

err()
{
	echo "$(date_fmt) - ERROR - ${1:-}" >&2
}

warn()
{
	echo "$(date_fmt) - WARN - ${1:-}" >&2
}

log()
{
	echo "$(date_fmt) - ${1:-}"
}

fail()
{
	err "${1:-Something bad happened}"
	exit 1
}

is_mac_in_whitelist()
{
	local mac=$1
	local m
	for m in ${ROUTER_WHITELIST//,/ }; do
		[ "$m" == "$mac" ] && return 0
	done
	return 1
}

check_var()
{
	local v=$1
	local V=${v^^}
	[ -z "${!V}" ] && fail "Cannot get $v"
	return 0
}

ping_ip()
{
	local ip=$1
	local iface=$2
	log "Ping $ip with $iface interface"
	ping -q -c 1 -I "$iface" "$ip" &>/dev/null || fail "Ping $ip failed"
}

private_ip_setup()
{
	log "Private IP setup"
	if [ -z "$INTERFACE" ]; then
		INTERFACE=$(ip route show default | head -1 | awk '{print $5}') || fail "Error while getting interface"
	fi
	check_var "interface"
	log "Using interface $INTERFACE"

	if [ -n "$ROUTER_WHITELIST" ]; then
		ROUTER_IP=$(ip route show default | awk "\$5==\"$INTERFACE\" {print \$3}") || fail "Error while getting router IP"
		check_var "router_ip"
		log "Router IP: $ROUTER_IP"
		ping_ip "$ROUTER_IP" "$INTERFACE"
		ROUTER_MAC=$(arp -an | grep "($ROUTER_IP)" | awk "\$7==\"$INTERFACE\" {print \$4}") || fail "Error while getting router MAC"
		log "Router MAC: $ROUTER_MAC"
		check_var "router_mac"
		is_mac_in_whitelist "$ROUTER_MAC" || fail "Router MAC is not in whitelist"
	fi

	if [ -z "$IP" ]; then
		IP=$(ip -4 -br a show "$INTERFACE" | awk '{print $NF}') || fail "Error while getting IP"
	fi
}

public_ip_setup()
{
	log "Public IP setup"
	IP="$(dig @resolver4.opendns.com myip.opendns.com +short)"
}

exec_cmd()
{
	local cmd=$1
	local retries=$2
	local result=""
	local ret_code=1
	local i=0

	while [[ "$ret_code" != "0" && "$i" -lt "$retries" ]]; do
		i=$((i+1))
		ret_code=0
		printf "." >> "$LOG_FILE"
		result=$(eval "$cmd") || ret_code=$? && sleep 1
	done
	echo >> "$LOG_FILE"
	echo "$result"
	return $ret_code
}

update_dns()
{
	local res_log=""
	log "Update DNS"
	log "Exec curl" >> "$CURL_LOG"
	RESULT=$(exec_cmd "curl --connect-timeout $CURL_TIMEOUT -u '$USER_NAME:$PASSWORD' 'https://www.ovh.com/nic/update?system=dyndns&hostname=$HOST_NAME&myip=$IP' 2>>'$CURL_LOG'" 3) || fail "DNS update failed - exit code: $?"
	res_log="DNS update result: $RESULT"
	[[ "$RESULT" =~ ^(nochg|good)  ]] || fail "$res_log"
	log "$res_log"
	return 0
}


CURL_TIMEOUT=3
HOST_NAME=""
INTERFACE=""
IP=""
CRED_FILE=""
USER_NAME=""
PASSWORD=""
ROUTER_WHITELIST=""
IP_TYPE="private"
FORCE="no"

trap fail ERR

SCRIPT_NAME=$(basename -- "$0")

LOG_FILE="{{ scripts_log_dir }}/$SCRIPT_NAME.log"
exec &>> "$LOG_FILE"
CURL_LOG="{{ scripts_log_dir }}/curl.log"

for arg in "$@"; do
	case $arg in
	--ip=*)
		IP="${arg#*=}"
		shift
		;;
	--interface=*)
		INTERFACE="${arg#*=}"
		shift
		;;
	--hostname=*)
		HOST_NAME="${arg#*=}"
		shift
		;;
	--cred-file=*)
		CRED_FILE="${arg#*=}"
		shift
		;;
	--router-whitelist=*)
		ROUTER_WHITELIST="${arg#*=}"
		shift
		;;
	--public)
		IP_TYPE="public"
		shift
		;;
	--force)
		FORCE="yes"
		shift
		;;
	*)
		exit_usage
		;;
	esac
done

[ -z "$HOST_NAME" ] && exit_usage
[ -z "$CRED_FILE" ] && exit_usage
[ -f "$CRED_FILE" ] || fail "'$CRED_FILE' is not a file"

# shellcheck disable=SC1090
source "$CRED_FILE" || fail "Failed to source '$CRED_FILE'"

[ -z "$USER_NAME" ] && fail "You should specify USER_NAME into '$CRED_FILE'"
[ -z "$PASSWORD" ] && fail "You should specify PASSWORD into '$CRED_FILE'"

if [ "$IP_TYPE" == "private" ]; then
	private_ip_setup
elif [ "$IP_TYPE" == "public" ]; then
	public_ip_setup
fi

check_var "ip"
IP=${IP%%/*}
log "Using IP $IP"

RESOLVED_IP=$(dig "$HOST_NAME" +short || echo "")
if [[ "$FORCE" == "yes" || "$RESOLVED_IP" != "$IP" ]]; then
	update_dns
else
	log "'$HOST_NAME' already resolves '$IP'"
fi

exit 0

