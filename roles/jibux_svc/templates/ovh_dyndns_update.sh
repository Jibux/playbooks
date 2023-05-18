#!/bin/bash


set -o errexit -o errtrace -o pipefail -o nounset


usage()
{
	echo "Update OVH dns entry for specific hostname"
	echo "Usage: $0 --hostname=<hostname> --cred-dir=<directory where are located OVH API credential files> [other options]"
	echo "By default, will use src IP of default route"
	echo "Other options:"
	echo "--ip=w.x.y.z - use specific IP"
	echo "--interface=iface - use specific interface"
	echo "--router-whitelist=a:b:c:d,e:f:g:h - update dns only if router mac address is matching one of the list"
	echo "--public - use router public IP instead of local private IP"
	echo "--log-dir - output logs to this directory"
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
	echo -e "$(date_fmt) - ERROR - ${1:-}" >&2
}

warn()
{
	echo -e "$(date_fmt) - WARN - ${1:-}" >&2
}

log()
{
	echo -e "$(date_fmt) - ${1:-}"
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

ovh_api_sig()
{
	local sig_data
	local method=$1
	local url=$2
	local body=$3
	local timestamp=$4

	sig_data="$OVH_APPLICATION_SECRET+$OVH_CONSUMER_KEY+$method+$url+$body+$timestamp"
	echo "\$1\$$(echo -n "${sig_data}" | sha1sum - | cut -d' ' -f1)"
}


ovh_timestamp()
{
	curl --connect-timeout "$CURL_TIMEOUT" -s "$OVH_API_URL/auth/time"
}

ovh_api_call()
{
	local method=$1
	local path=$2
	local body=${3:-}
	local timestamp
	local url="$OVH_API_URL/$path"
	timestamp=$(ovh_timestamp)
	sig=$(ovh_api_sig "$method" "$url" "$body" "$timestamp")
	curl -sS --fail-with-body -X "$method" \
--connect-timeout "$CURL_TIMEOUT" \
--header 'Content-Type:application/json;charset=utf-8' \
--header "X-Ovh-Application:$OVH_APPLICATION_KEY" \
--header "X-Ovh-Timestamp:$timestamp" \
--header "X-Ovh-Signature:$sig" \
--header "X-Ovh-Consumer:$OVH_CONSUMER_KEY" \
--data "$body" \
"$url"
}

update_dns()
{
	local res=""
	local data
	local ip_v_suffix="(v$1)"
	local type=$2
	local record_file="$ZONE_RECORDS_DIR/${type}_$HOST_NAME"
	log "Update DNS $ip_v_suffix"

	if [ -f "$record_file" ]; then
		# Record exist: update it
		log "Update '$SUB_DOMAIN' record for '$BASE_DOMAIN' $ip_v_suffix"
		data='{"subDomain":"'"$SUB_DOMAIN"'","target":"'"$IP"'"}'
		ovh_api_call "PUT" "domain/zone/$BASE_DOMAIN/record/$(cat "$record_file")" "$data" || fail "Update zone failed"
	else
		# Record does not exist: create it
		data='{"fieldType":"'"$type"'","subDomain":"'"$SUB_DOMAIN"'","target":"'"$IP"'","ttl":'"$TTL"'}'
		log "Create '$SUB_DOMAIN' record for '$BASE_DOMAIN' $ip_v_suffix"
		res=$(ovh_api_call "POST" "domain/zone/$BASE_DOMAIN/record" "$data" ) || fail "$res"
		echo "$res" | jq -r .id > "$record_file"
		log "Refresh zone"
		ovh_api_call "POST" "domain/zone/$BASE_DOMAIN/refresh" || fail "Fail to refresh zone"
	fi

	return 0
}

update_dns_v4()
{
	update_dns "4" "A"
}

init_api_var()
{
	local v=$1
	local v_name=${1^^}
	local file="$CRED_DIR/$v"
	if [ -f "$file" ]; then
		eval "$v_name=$(<"$file")"
	else
		warn "$file does not exist!"
		eval "$v_name="
	fi
}

init_api_vars()
{
	init_api_var "ovh_consumer_key"
	init_api_var "ovh_application_key"
	init_api_var "ovh_application_secret"
}

get_base_domain()
{
	local host=$1
	local arr
	IFS='.' read -r -a arr <<< "$host"
	echo "${arr[-2]}.${arr[-1]}"
}


CURL_TIMEOUT=3
HOST_NAME=""
INTERFACE=""
IP=""
CRED_DIR=""
OVH_API_URL="{{ ovh_api_url }}"
OVH_CONSUMER_KEY=""
OVH_APPLICATION_KEY=""
OVH_APPLICATION_SECRET=""
ROUTER_WHITELIST=""
IP_TYPE="private"
FORCE="no"
TTL=60

trap fail ERR

SCRIPT_NAME=$(basename -- "$0")

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
	--cred-dir=*)
		tmp_var="${arg#*=}"
		CRED_DIR="${tmp_var%/}"
		shift
		;;
	--log-dir=*)
		LOG_FILE="${arg#*=}/$SCRIPT_NAME.log"
		exec &>> "$LOG_FILE"
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
BASE_DOMAIN=$(get_base_domain "$HOST_NAME")
SUB_DOMAIN=${HOST_NAME//\.$BASE_DOMAIN/}
log "Base domain: $BASE_DOMAIN"
log "Sub domain: $SUB_DOMAIN"

[ -d "$CRED_DIR" ] || fail "'$CRED_DIR' is not a directory or does not exist"
init_api_vars
ZONE_RECORDS_DIR="$CRED_DIR/zone_records"
mkdir -p "$ZONE_RECORDS_DIR"

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
	update_dns_v4
else
	log "'$HOST_NAME' already resolves '$IP'"
fi

exit 0

