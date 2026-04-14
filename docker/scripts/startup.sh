#!/bin/bash
rm -f /tmp/.X*-lock /tmp/.X11-unix/X*
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
