#!/bin/bash


COLOR_PROFILES=~/color_profiles

/opt/Argyll_V2.0.1/bin/dispwin -I $COLOR_PROFILES/print_profile
darktable
/opt/Argyll_V2.0.1/bin/dispwin -I $COLOR_PROFILES/normal_profile

