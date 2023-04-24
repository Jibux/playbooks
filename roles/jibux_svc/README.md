# Jibux services

## Description

* Simple CardDav/CalDav server using [Radicale](https://radicale.org/)
* Used with Traefik and letsencrypt OVH DNS01 challenge for certificate generation

The goal is to run services in a local network not publicly accessible. They can be reached by a domain which should resolve a private IP.

### Variables

* `svc_host` is the domain used to access the services. It will resolve the private IP of the host. Its IP is updated by the `ovh_dyndns_update.sh` script. This script is launched in `ExecStartPre` by `jibux_svc.service`. It will fail if the discovered router MAC address is not matching `ovh_dyndns_router_whitelist`.
* `dav_sync_host` is an alias to `svc_host`. It is used to access the Radicale server.
* `ovh_dyndns_interface` is the network interface where to get the private IP from.
* `svc_enabled` stands for `jibux_svc` service activation/deactivation at boot time.

## Structure

### Files

* docker-compose.yaml
* radicale_config
* traefik.yaml - Traefik configuration

### `data` directory

This directory is synchronized with MEGA cloud using [MEGAcmd client](https://github.com/meganz/MEGAcmd). The `mega-cmd` server is launched via systemd by `ExecStartPre` of `jibux_svc.service`.

#### `secrets`

Here should be the credentials to access OVH API for DNS01 challenge:

* ovh_endpoint
* ovh_application_key
* ovh_application_secret
* ovh_consumer_key

Rights needed:

```
POST /domain/zone/<domain>/record
POST /domain/zone/<domain>/refresh
DELETE /domain/zone/<domain>/record/*
```

Also the credentials used by `ovh_dyndns_update.sh` script:

* ovh_dyndns 

#### `radicale`

* `config`: users
* `data`: users data

#### `traefik`

* `letsencrypt`: HTTPS certificate
* `conf`: misc configurations

### `scripts` directory

* `ovh_dyndns_update.sh` - see help into the script

