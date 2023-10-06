#!/usr/bin/env python3

import argparse
import logging
import subprocess
import time
import os
import shutil
import sys
from pathlib import Path
from yaml import load
from yaml import CSafeLoader as Loader


logger = logging.getLogger(os.path.basename(__file__))
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('%(asctime)s %(levelname)-6s %(name)s %(message)s', '%Y-%m-%d %H:%M:%S')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)


MEGA_SYNC_COLUMNS = ["ID", "LOCALPATH", "REMOTEPATH", "RUN_STATE", "STATUS", "ERROR"]
MEGA_SYNC_COLUMNS_INDEXES = {col: idx for idx, col in enumerate(MEGA_SYNC_COLUMNS)}
MEGA_SYNC_COLUMNS_SEP = ":"
SLEEP_TIME = 5
ITEM_SYNCED = "Synced"
ITEM_NO_ERROR = "NO"
SYNC_STATE_STOPPED = ["Paused", "Suspended", "Disabled"]


def mega_cmd(cmd):
    mega_call = subprocess.run(cmd, stdout=sys.stdout, stderr=sys.stderr)
    if mega_call.returncode != 0:
        logger.warning(f"{cmd[0]} call got errors")


def mega_rm(path):
    mega_cmd(["mega-rm", "-r", "-f", path])


def mega_mkdir(d):
    mega_cmd(["mega-mkdir", "-p", d])


def mega_sync_cmd(cmd=[]):
    mega_call = subprocess.run([
        "mega-sync",
        f"--col-separator={MEGA_SYNC_COLUMNS_SEP}",
        f"--output-cols={','.join(MEGA_SYNC_COLUMNS)}"] + cmd,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if mega_call.returncode != 0:
        print(mega_call.stdout)
        print(mega_call.stderr)
        raise Exception("mega-sync call failed")
    return mega_call.stdout.splitlines()


def filter_output(output, first_line):
    try:
        index = output.index(first_line)
        return output[index + 1:]
    except ValueError:
        return []


def get_configured_mega_paths():
    output = mega_sync_cmd()
    first_line = MEGA_SYNC_COLUMNS_SEP.join(MEGA_SYNC_COLUMNS)
    filtered_output = filter_output(output, first_line)
    return [i.split(MEGA_SYNC_COLUMNS_SEP) for i in filtered_output]


def items_matched(item_to_configure, configured_item):
    idx1 = MEGA_SYNC_COLUMNS_INDEXES['LOCALPATH']
    idx2 = MEGA_SYNC_COLUMNS_INDEXES['REMOTEPATH']
    return configured_item[idx1] == item_to_configure['local'] and configured_item[idx2] == item_to_configure['remote']


def configure_mega_path(item):
    logger.info(f"Configure {item['id']}")
    mega_mkdir(item['remote'])
    local_path = Path(item['local'])
    local_path.mkdir(parents=True, exist_ok=True)
    mega_sync_cmd([item['local'], item['remote']])
    logger.info(f"{item['id']} configured")


def check_and_configure_mega_path(item_to_configure, configured_mega_paths):
    for configured_item in configured_mega_paths:
        if items_matched(item_to_configure, configured_item):
            logger.debug(f"{item_to_configure['id']} already configured")
            return
    configure_mega_path(item_to_configure)


def setup_sync_config(mega_paths_to_configure):
    configured_mega_paths = get_configured_mega_paths()
    for i in mega_paths_to_configure:
        check_and_configure_mega_path(i, configured_mega_paths)


def is_item_to_be_pruned(item, mega_paths_to_configure):
    for item_to_configure in mega_paths_to_configure:
        if items_matched(item_to_configure, item):
            return False
    return True


def prune_sync(item_id, local_path, remote_path):
    mega_sync_cmd(["-d", item_id])
    logger.info(f"Sync {item_id} removed")
    resp = input(f"Remove local directory {local_path}? (y/N): ")
    if resp.lower() in ['y', 'yes']:
        shutil.rmtree(local_path)
        logger.info(f"Local directory {local_path} removed")
    resp = input(f"Remove remote directory {remote_path}? (y/N): ")
    if resp.lower() in ['y', 'yes']:
        mega_rm(remote_path)
        logger.info(f"Remote directory {remote_path} removed")


def ask_and_prune_sync(item):
    item_id = item[MEGA_SYNC_COLUMNS_INDEXES['ID']]
    local_path = item[MEGA_SYNC_COLUMNS_INDEXES['LOCALPATH']]
    remote_path = item[MEGA_SYNC_COLUMNS_INDEXES['REMOTEPATH']]
    resp = input(f"Remove sync {item_id} {local_path} <-> {remote_path}? (y/N): ")
    if resp.lower() in ['y', 'yes']:
        prune_sync(item_id, local_path, remote_path)


def prune_syncs(mega_paths_to_configure):
    configured_mega_paths = get_configured_mega_paths()
    for configured_item in configured_mega_paths:
        if is_item_to_be_pruned(configured_item, mega_paths_to_configure):
            ask_and_prune_sync(configured_item)


def item_sync_error(item):
    return item[MEGA_SYNC_COLUMNS_INDEXES['ERROR']]


def is_item_sync_in_error(error):
    return error != ITEM_NO_ERROR


def item_sync_state(item):
    return item[MEGA_SYNC_COLUMNS_INDEXES['RUN_STATE']]


def is_sync_state_stopped(state):
    return state in SYNC_STATE_STOPPED


def item_sync_status(item):
    return item[MEGA_SYNC_COLUMNS_INDEXES['STATUS']]


def is_item_synced(status):
    return status == ITEM_SYNCED


def check_item_status(item_to_configure):
    configured_mega_paths = get_configured_mega_paths()
    for configured_item in configured_mega_paths:
        if items_matched(item_to_configure, configured_item):
            error = item_sync_error(configured_item)
            if is_item_sync_in_error(error):
                raise Exception(f"{item_to_configure['id']} is in error ({error})")
            state = item_sync_state(configured_item)
            status = item_sync_status(configured_item)
            logger.info(f"{item_to_configure['id']} sync run state '{state}', status '{status}'")
            if is_sync_state_stopped(state):
                raise Exception(f"{item_to_configure['id']} is not running")
            if is_item_synced(status):
                return True
            return False
    raise Exception(f"{item_to_configure['id']} is not configured")


def get_mega_paths_to_wait(mega_paths_to_configure, args_wait):
    if 'all' in args_wait:
        return mega_paths_to_configure
    mega_ids = [i['id'] for i in mega_paths_to_configure]
    for item in args_wait:
        if item not in mega_ids:
            raise Exception(f"'{item}' not in mega ids to configure")
    return [i for i in mega_paths_to_configure if i['id'] in args_wait]


def wait_all_to_be_synced(mega_paths_to_configure):
    items_synced = [check_item_status(i) for i in mega_paths_to_configure]
    if all(items_synced):
        logger.info("All items synced")
        return
    else:
        time.sleep(SLEEP_TIME)
        return wait_all_to_be_synced(mega_paths_to_configure)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--sync-config", help="Sync config file", required=True)
    parser.add_argument("-p", "--prune", help="Prune unconfigured syncs", action='store_true')
    parser.add_argument("-v", "--verbose", help="Verbose mode", action='store_true')
    parser.add_argument(
        "-w", "--wait",
        help="Comma separated list of ids to wait to be synced (use no arg or all to wait for every configured items)",
        nargs='?', const="all")
    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    with open(args.sync_config, "r") as ymlfile:
        mega_paths_to_configure = load(ymlfile, Loader=Loader)

    setup_sync_config(mega_paths_to_configure)

    if args.prune:
        prune_syncs(mega_paths_to_configure)

    if args.wait:
        mega_paths_to_wait = get_mega_paths_to_wait(mega_paths_to_configure, args.wait.split(','))
        wait_all_to_be_synced(mega_paths_to_wait)


if __name__ == '__main__':
    main()
