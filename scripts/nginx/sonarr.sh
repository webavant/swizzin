#!/bin/bash
# Nginx conf for *Arr
# Flying sausages 2020
# Refactored by Bakerboy448 2021
# Refactored by Brett 2023
master=$(_get_master_username)
app_name="sonarr"

if ! SONARR_OWNER="$(swizdb get $app_name/owner)"; then
    SONARR_OWNER=$master
fi
user="$SONARR_OWNER"

app_port="8989"
app_sslport="9898"
app_configdir="/home/$user/.config/${app_name^}"
app_baseurl="$app_name"
app_servicefile="${app_name}.service"
app_branch="develop"

cat > /etc/nginx/apps/$app_name.conf << ARRNGINX
location /$app_baseurl {
    proxy_pass http://127.0.0.1:$app_port;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_redirect off;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$http_connection;
    auth_basic "What's the password?";
    auth_basic_user_file /etc/htpasswd.d/htpasswd.${master};
}
# Allow the API External Access via NGINX
location /$app_baseurl/api {
    auth_basic off;
    proxy_pass http://127.0.0.1:$app_port;
}

# Allow Calendar Feed External Access via NGINX

location ^~ /$app_baseurl/feed/calendar {
    auth_basic off;
    proxy_pass http://127.0.0.1:$app_port;
}

ARRNGINX

wasActive=$(systemctl is-active $app_servicefile)

if [[ $wasActive == "active" ]]; then
    echo_log_only "Stopping $app_name"
    systemctl stop -q "$app_servicefile"
fi

apikey=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" "$app_configdir"/config.xml)

# Set to Debug as this is alpha software
# ToDo: Logs back to Info
cat > "$app_configdir"/config.xml << ARRCONFIG
<Config>
  <LogLevel>trace</LogLevel>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <BindAddress>localhost</BindAddress>
  <Port>$app_port</Port>
  <SslPort>$app_sslport</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey>${apikey}</ApiKey>
  <AuthenticationMethod>None</AuthenticationMethod>
  <UrlBase>$app_baseurl</UrlBase>
  <Branch>$app_branch</Branch>
</Config>
ARRCONFIG

chown -R "$user":"$user" "$app_configdir"

# Switch app back off if it was dead before; otherwise start it
if [[ $wasActive == "active" ]]; then
    systemctl start "$app_servicefile" -q
fi
