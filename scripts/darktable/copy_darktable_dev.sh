#!/bin/bash


ROOT="/data/Photos-Images/Darktable/"
PWD="$(pwd -P)"

FOLDER="${PWD##*$ROOT}"
DESTINATION="/data/Photos-Images/Famille/$FOLDER"

rsync -av ./darktable_exported/*jpg "$DESTINATION/"

