#!/usr/bin/env python3


import sys
import subprocess
import argparse
import logging
import socket
import traceback
import struct
import fcntl
import ipaddress
import dns.resolver
import ovh
import re
import urllib.request
from pathlib import Path
from operator import itemgetter
from yaml import load
from yaml import CSafeLoader as Loader


log_f = logging.Formatter('%(asctime)s %(levelname)-6s %(message)s', '%Y-%m-%d %H:%M:%S')
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


WORLD_IP = "00000000"
TTL = "60"
IP_TYPE_PRIVATE = 'private'
IP_TYPE_PUBLIC = 'public'

CONDITION_FAILED_CODE = 1
EXIT_ALLOW_RESTART = 255


def fail(msg, exit_code=CONDITION_FAILED_CODE):
    logger.error(msg)
    sys.exit(exit_code)


def logging_config(log_dir):
    if log_dir and Path(log_dir).is_dir():
        h = logging.FileHandler(f"{log_dir}/{Path(__file__).stem}.log")
    else:
        h = logging.StreamHandler()

    h.setFormatter(log_f)
    logger.addHandler(h)


def get_file_content(path):
    return path.read_text().rstrip()


def get_ovh_client(secrets_dir) -> ovh.Client:
    ovh_api_cred = {
        key: get_file_content(secrets_dir / Path(f"ovh_{key}"))
        for key in ['application_key', 'application_secret', 'consumer_key', 'endpoint']
    }
    return ovh.Client(
        endpoint=ovh_api_cred.get('endpoint', 'ovh-eu'),
        application_key=ovh_api_cred['application_key'],
        application_secret=ovh_api_cred['application_secret'],
        consumer_key=ovh_api_cred['consumer_key']
    )


def get_wifi_info():
    response = subprocess.run(['iwgetid'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if response.returncode != 0:
        logger.info("iwgetid command failed")
        return (None, None)
    line = response.stdout.rstrip()
    pattern = r"(?P<iface>[^\s]+)\s+ESSID:\"(?P<ssid>[^\"]+)\"$"
    m = re.search(pattern, line)
    if m:
        return (m.group("iface"), m.group("ssid"))
    else:
        return (None, None)


def ip_hexa_to_dec(ip):
    return socket.inet_ntoa(struct.pack("<L", int(ip, 16)))


def file_to_list(path):
    with open(path) as f:
        return [li.split() for li in f.read().splitlines()]


def get_routing_table():
    return file_to_list("/proc/net/route")


def get_arp_table():
    return file_to_list("/proc/net/arp")


def def_routes():
    # Sort based on metric (index 6)
    return sorted([r for r in get_routing_table() if r[1] == WORLD_IP], key=itemgetter(6))


def ping(ip, iface):
    logger.info(f"Ping {ip} with {iface} interface")
    command = ["ping", "-q", "-c", "1", "-I", iface, ip]
    response = subprocess.call(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if response != 0:
        fail(f"Ping {ip} failed", EXIT_ALLOW_RESTART)


def get_mac_from_ip(ip, iface):
    ping(ip, iface)
    macs = [a[3] for a in get_arp_table() if a[0] == ip and a[5] == iface]
    if len(macs) == 0:
        fail(f"Cannot get MAC address for IP {ip} using {iface} interface", EXIT_ALLOW_RESTART)
    return macs[0]


def format_router_info(iface, router_ip):
    formated_ip = ip_hexa_to_dec(router_ip)
    return (iface, formated_ip, get_mac_from_ip(formated_ip, iface))


def get_ip_router_info():
    info = [format_router_info(r[0], r[2]) for r in def_routes()]
    if len(info) == 0:
        fail("Cannot get router information", EXIT_ALLOW_RESTART)
    return info


def print_ip_router_info(info):
    for (iface, router_ip, router_mac) in info:
        logger.info(f"Interface {iface} - router IP {router_ip} - router mac {router_mac}")


def get_ipv4(iface):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', bytes(iface[:15], 'utf-8'))
    )[20:24])


def get_ipv4_public():
    return urllib.request.urlopen('https://v4.ident.me').read().decode('utf8')


def format_ipv6(ip_str):
    real_ip = ':'.join(ip_str[i:i + 4] for i in range(0, len(ip_str), 4))
    return ipaddress.ip_address(real_ip).compressed


def is_valid_ipv6(ip):
    return not ip.startswith("fe80")


def get_ipv6(iface):
    ips = [i[0] for i in file_to_list("/proc/net/if_inet6") if i[5] == iface and is_valid_ipv6(i[0])]
    if len(ips) == 0:
        fail("Cannot find valid IPV6 - you should deactivate it in the configuration")
    return format_ipv6(ips[0])


def extract_matching_iface(conf, ip_router_info):
    matching_ifaces = [iface for (iface, _, router_mac) in ip_router_info if conf.get('mac') == router_mac]
    if len(matching_ifaces) > 0:
        for iface in matching_ifaces:
            if conf.get('iface') == iface:
                return iface
        # Defaults to the first interface
        return matching_ifaces[0]
    return None


def get_used_conf(router_whitelist):
    ip_router_info = get_ip_router_info()
    print_ip_router_info(ip_router_info)
    (wifi_iface, ssid) = get_wifi_info()
    if wifi_iface:
        logger.info(f"Connected to wifi network '{ssid}' with '{wifi_iface}'")
    for conf in router_whitelist:
        if ssid and ssid == conf.get('ssid'):
            logger.info(f"Wifi network '{ssid}' is matching config")
            return (wifi_iface, conf)
        matching_iface = extract_matching_iface(conf, ip_router_info)
        if matching_iface:
            return (matching_iface, conf)
    fail('No router match whitelist')


def ip_setup(config):
    (used_iface, spec_conf) = get_used_conf(config.get('router_whitelist'))
    logger.info(f"Using interface {used_iface}")
    ip_type = spec_conf.get('ip_type', IP_TYPE_PRIVATE)
    if spec_conf.get('ipv4', True):
        ipv4 = get_ipv4_public() if ip_type == IP_TYPE_PUBLIC else get_ipv4(used_iface)
        logger.info(f"IPv4: {ipv4}")
        ipv4_setup = {'ip': ipv4}
    else:
        ipv4_setup = {'present': False}
    if spec_conf.get('ipv6', False):
        ipv6 = get_ipv6(used_iface)
        logger.info(f"IPv6: {ipv6}")
        ipv6_setup = {'type': 'AAAA', 'ip': ipv6}
    else:
        ipv6_setup = {'type': 'AAAA', 'present': False}
    return [ipv4_setup, ipv6_setup]


def check_remote_svc(url):
    logger.info(f"Check {url} accessibility")
    try:
        resp = urllib.request.urlopen(url, timeout=10)
        status = resp.status
        # content = resp.read().decode('utf8')
        # print(content)
        if status == 200:
            fail("URL already available")
        else:
            logger.info(f"URL return http status: {status}")
    except Exception as e:
        if logger.level == logging.DEBUG:
            traceback.print_exc()
        else:
            logger.info(f"URL not available: {e.reason}")


def parse_domain(domain):
    pattern = r"(?P<sub_domain>[\w\-\.]+)\.(?P<root_domain>[\w\-]+\.+[\w\-]+)$"
    m = re.search(pattern, domain)
    if m:
        return (m.group("root_domain"), m.group("sub_domain"))
    else:
        fail(f"Cannot parse '{domain}' domain")


def refresh_zone(root_domain, ovh_client):
    api_path = f"/domain/zone/{root_domain}/refresh"
    logger.info('Refresh zone')
    ovh_client.post(api_path)


def update_record(r_ip, r_type, domain, record_file, ovh_client):
    (root_domain, sub_domain) = parse_domain(domain)
    api_root_path = f"/domain/zone/{root_domain}/record"
    if record_file.is_file():
        logger.info(f'Update {r_type} record for {domain} to {r_ip}')
        api_path = f"{api_root_path}/{get_file_content(record_file)}"
        ovh_client.put(api_path, subDomain=sub_domain, target=r_ip)
    else:
        logger.info(f'Add {r_type} record for {domain} to {r_ip}')
        resp = ovh_client.post(api_root_path, fieldType=r_type, subDomain=sub_domain, target=r_ip, ttl=TTL)
        r_id = resp.get('id')
        if r_id is None:
            fail("Cannot get record id from response")
        record_file.write_text(str(r_id))
    refresh_zone(root_domain, ovh_client)


def delete_record(r_type, domain, record_file, ovh_client):
    (root_domain, sub_domain) = parse_domain(domain)
    logger.info(f'Delete {r_type} record for {domain}')
    if record_file.is_file():
        api_path = f"/domain/zone/{root_domain}/record/{get_file_content(record_file)}"
        ovh_client.delete(api_path)
        record_file.unlink()
    else:
        fail(f"'{record_file}' file not found, you must delete this record manually")
    refresh_zone(root_domain, ovh_client)


def find_dns64(ips):
    for ip in ips:
        if ip.startswith("64:ff9b"):
            return True
    return False


def update_dns(record, domain, secrets_dir, force):
    r_type = record.get('type', 'A')
    present = record.get('present', True)
    r_ip = record.get('ip', '')
    record_file = secrets_dir / Path("zone_records") / Path(f'{r_type}_{domain}')
    ovh_client = get_ovh_client(secrets_dir)
    try:
        resolved_domain = [i.to_text() for i in dns.resolver.resolve(domain, r_type)]
        logger.info(f"{domain} {r_type} resolves {','.join(resolved_domain)}")
        domain_up_to_date = r_ip in resolved_domain
        if present and domain_up_to_date and not force:
            logger.info(f'{domain} {r_type} up to date')
        elif present:
            update_record(r_ip, r_type, domain, record_file, ovh_client)
        elif r_type == 'AAAA' and find_dns64(resolved_domain):
            fail("You must activate IPV6 in the configuration or disable IPV6 at the mobile network level")
        else:
            delete_record(r_type, domain, record_file, ovh_client)
    except (dns.resolver.NXDOMAIN, dns.resolver.NoAnswer):
        if present:
            logger.info(f'{domain} {r_type} not found')
            update_record(r_ip, r_type, domain, record_file, ovh_client)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ip", help="Use this ip", required=False)
    parser.add_argument("--domain", help="Target domain", required=True)
    parser.add_argument(
        "--secrets-dir",
        help="Where to lookup credentials for OVH API and store OVH DNS info", required=True
    )
    parser.add_argument("-c", "--config", help="Config file", required=False)
    parser.add_argument("-l", "--log-dir", help="Output logs to this dir", required=False)
    parser.add_argument("--check-url", help="Check remote service before start", required=False)
    parser.add_argument("-f", "--force", help="Force DNS update", action='store_true', default=False)
    parser.add_argument("-v", "--verbose", help="Verbose", action='store_true', default=False)
    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    logging_config(args.log_dir)

    logger.info("Begin script")

    if not Path(args.secrets_dir).is_dir():
        fail(f"{args.secrets_dir} is not a directory or does not exist")

    if args.config:
        with open(args.config, "r") as ymlfile:
            config = load(ymlfile, Loader=Loader)
    else:
        config = {}

    record_list = ip_setup(config)

    if args.check_url:
        check_remote_svc(args.check_url)

    for r in record_list:
        update_dns(r, args.domain, Path(args.secrets_dir), args.force)


if __name__ == '__main__':
    main()
