#!/bin/bash
# Regénère les configs Nginx pour tous les containers kasm actifs.
# Utile après un redémarrage du serveur pour restaurer les locations.

echo "Génération des configs Nginx pour tous les containers kasm..."

for container in $(docker ps --format '{{.Names}}' | grep -v '^ubuntu-' | grep -v '^vigie'); do
    port=$(docker inspect "$container" --format '{{(index (index .NetworkSettings.Ports "6901/tcp") 0).HostPort}}' 2>/dev/null)

    if [ -z "$port" ]; then
        echo "  SKIP $container : port 6901 non exposé"
        continue
    fi

    sudo tee /etc/nginx/kasm-locations/${container}.conf > /dev/null << NGINX
location = /kasm/${container}/ {
    return 302 /kasm/${container}/vnc_auto.html?autoconnect=true&reconnect=true&reconnect_delay=1000&resize=scale&quality=6&path=kasm/${container}/websockify;
}

location ^~ /kasm/${container}/websockify {
    proxy_pass http://127.0.0.1:${port}/websockify;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_buffering off;
}

location ^~ /kasm/${container}/ {
    proxy_pass http://127.0.0.1:${port}/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
    proxy_buffering off;
}
NGINX
    echo "  OK $container → port $port"
done

sudo nginx -t && sudo systemctl reload nginx
echo "Done."
