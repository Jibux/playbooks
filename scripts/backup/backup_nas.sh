#!/bin/bash


ROOT_PATH=/home/jibux/scripts/global/backup

$ROOT_PATH/backup.sh -vFf $ROOT_PATH/backup_nas_data/
$ROOT_PATH/backup.sh -vFfc $ROOT_PATH/backup_nas_media/

