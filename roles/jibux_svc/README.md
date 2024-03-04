# Jibux services

## Description

* Simple CardDav/CalDav server using [Radicale](https://radicale.org/)
* Used with Traefik and letsencrypt OVH DNS01 challenge for certificate generation

Services can run into a device not publicly accessible (private IPv4) or publicly accessible (IPv6 or public IPv4)

### Variables

* `svc_host` is the domain used to access the services. It will resolve the IP of the host. Its IP is updated by the `jibux_svc_pre_start.py` script. This script is launched in `ExecStartPre` by `jibux_svc.service`. It will fail if the discovered router MAC address is not matching `svc_router_whitelist`.
* `dav_sync_host` is an alias to `svc_host`. It is used to access the Radicale server.
* `svc_enabled` stands for `jibux_svc` service activation/deactivation at boot time.

## Structure

### Files

* docker-compose.yaml
* radicale_config
* traefik.yaml - Traefik configuration
* jibux_svc_config.yaml - Configuration used by `jibux_svc_pre_start.py` script

#### `jibux_svc_config.yaml` configuration structure

```yaml
---
router_whitelist:
  - description: Mobile network sharing
    ssid: My wifi network  # Matching wifi network name
    ipv6: true  # Defaults to false
    ipv4: false  # Defaults to true
  - description: Home
    mac: f5:eb:73:42:d0:e4  # Matching router mac address
    ip_type: public  # Defaults to 'private' (only for ipv4)
    iface: eth0  # Use this interface if possible
```

### `data` directory

This directory is synchronized with MEGA cloud using [MEGAcmd client](https://github.com/meganz/MEGAcmd). The `mega-cmd` server is launched via systemd by `ExecStartPre` of `jibux_svc.service`.

#### `secrets`

Here should be the credentials to access OVH API for DNS01 challenge and for `jibux_svc_pre_start.py` script:

* ovh_endpoint
* ovh_application_key
* ovh_application_secret
* ovh_consumer_key

#### `radicale`

* `config`: users
* `data`: users data

#### `traefik`

* `letsencrypt`: HTTPS certificate
* `conf`: misc configurations

### `scripts` directory

* `jibux_svc_pre_start.py` - see help into the script

