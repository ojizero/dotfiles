#!/bin/sh

# DSM reserves the ports 80 and 443, I don't want that this
# script fixes it. Added as a "boot up" triggered task.
#
# Ref: https://3os.org/infrastructure/synology/disable-dms-listening-on-80-443-ports/#disable-the-synology-nas-dsm-to-listen-on-80-443-ports

sed -i -e 's/80/81/' -e 's/443/444/' /usr/syno/share/nginx/server.mustache /usr/syno/share/nginx/DSM.mustache /usr/syno/share/nginx/WWWService.mustache

synosystemctl restart nginx
