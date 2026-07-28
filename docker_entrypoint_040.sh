#!/bin/bash
# StartOS 0.4.0 entrypoint for the single-image Mempool BIP-110 package.
#
# Unlike the 0.3.x entrypoint, all connection settings (Bitcoin cookie auth,
# indexer, lightning, database) come from the generated mempool-config.json,
# which is mounted read-only at /backend/mempool-config.json. This script only
# needs the DB credentials and the lightning toggle, which it reads from that
# file via jq. The backend is launched directly (node) using the mounted config
# rather than the upstream start.sh (which would regenerate the config from env).
set -ea

CONFIG_FILE="/backend/mempool-config.json"

backend_process=""
db_process=""
frontend_process=""

_term() {
  echo "Caught SIGTERM signal!"
  if [ -n "$backend_process" ]; then
    kill -TERM "$backend_process" 2>/dev/null
    wait "$backend_process" 2>/dev/null
  fi
  if [ -n "$frontend_process" ]; then
    kill -TERM "$frontend_process" 2>/dev/null
    wait "$frontend_process" 2>/dev/null
  fi
  if [ -n "$db_process" ]; then
    echo "Shutting down MariaDB gracefully..."
    mysqladmin -u root shutdown 2>/dev/null || kill -TERM "$db_process" 2>/dev/null
    wait "$db_process" 2>/dev/null
  fi
  echo "All processes stopped."
  exit 0
}
trap _term SIGTERM SIGINT

# Read the settings this script needs from the mounted config.
LIGHTNING_ENABLED=$(jq -r '.LIGHTNING.ENABLED // false' "$CONFIG_FILE")
MYSQL_DATABASE=$(jq -r '.DATABASE.DATABASE // "mempool"' "$CONFIG_FILE")
MYSQL_USER=$(jq -r '.DATABASE.USERNAME // "mempool"' "$CONFIG_FILE")
MYSQL_PASSWORD=$(jq -r '.DATABASE.PASSWORD // "mempool"' "$CONFIG_FILE")
export MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD

# ============================ FRONTEND (nginx) ============================
if [ "$LIGHTNING_ENABLED" = "true" ]; then
  LIGHTNING_DETECTED_PORT=9735
fi
__MEMPOOL_BACKEND_MAINNET_HTTP_HOST__=${BACKEND_MAINNET_HTTP_HOST:=127.0.0.1}
__MEMPOOL_BACKEND_MAINNET_HTTP_PORT__=${BACKEND_MAINNET_HTTP_PORT:=8999}
__MEMPOOL_FRONTEND_HTTP_PORT__=${FRONTEND_HTTP_PORT:=8080}
__ACCELERATOR_BUTTON__=true
__SERVICES_API__="https://mempool-rdts.startos/api/v1/services"

sed -i "s/__MEMPOOL_BACKEND_MAINNET_HTTP_HOST__/${__MEMPOOL_BACKEND_MAINNET_HTTP_HOST__}/g" /etc/nginx/conf.d/nginx-mempool.conf
sed -i "s/__MEMPOOL_BACKEND_MAINNET_HTTP_PORT__/${__MEMPOOL_BACKEND_MAINNET_HTTP_PORT__}/g" /etc/nginx/conf.d/nginx-mempool.conf

cp /etc/nginx/conf.d/nginx-mempool.conf /etc/nginx/nginx-mempool.conf

# Substitute from a pristine, never-overwritten template. If this entrypoint
# re-runs within the same subcontainer instance (e.g. a crash-restart), using
# /etc/nginx/nginx.conf as both source and destination would re-apply
# "s/listen 80/listen 8080/" to its own prior output on every pass, turning
# "listen 8080;" into "listen 808080;", "listen 8080808080;", etc.
NGINX_CONF_DIST="/etc/nginx/nginx.conf.dist"
if [ ! -f "$NGINX_CONF_DIST" ]; then
  cp /etc/nginx/nginx.conf "$NGINX_CONF_DIST"
fi
cp "$NGINX_CONF_DIST" /backend/nginx.conf
sed -i -e "s/__MEMPOOL_FRONTEND_HTTP_PORT__/${__MEMPOOL_FRONTEND_HTTP_PORT__}/g" -e "s/127.0.0.1://" -e "/listen/a\                server_name 127.0.0.1;" -e "s/listen 80/listen 8080/g" /backend/nginx.conf
cat /backend/nginx.conf > /etc/nginx/nginx.conf
/patch/entrypoint.sh

# ============================ DATABASE (MariaDB) ============================
MYSQL_DATADIR="/var/lib/mysql"
UPGRADE_MARKER="$MYSQL_DATADIR/.upgrade_done"
MYSQL_DIR="/var/run/mysqld"
MYSQL_SOCKET="$MYSQL_DIR/mysqld.sock"

if [ -d "$MYSQL_DIR" ]; then
  chown -R mysql:mysql $MYSQL_DIR
else
  mkdir -p $MYSQL_DIR
  chown -R mysql:mysql $MYSQL_DIR
fi

if [ ! -d "$MYSQL_DATADIR/mysql" ]; then
  echo "Initializing MariaDB data directory..."
  mariadb-install-db --user=mysql --datadir="$MYSQL_DATADIR" > /dev/null
  chown -R mysql:mysql "$MYSQL_DATADIR"
  chmod -R 755 "$MYSQL_DATADIR"
  touch "$UPGRADE_MARKER"

  if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
    MYSQL_ROOT_PASSWORD=$(pwgen 16 1)
    export MYSQL_ROOT_PASSWORD
  fi

  tfile=$(mktemp)
  [ -f "$tfile" ] || exit 1

  cat << EOF > "$tfile"
USE mysql;
FLUSH PRIVILEGES ;
GRANT ALL ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
GRANT ALL ON *.* TO 'root'@'localhost' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
DROP DATABASE IF EXISTS test ;
FLUSH PRIVILEGES ;
EOF

  if [ "$MYSQL_DATABASE" != "" ]; then
    echo "[i] Creating database: $MYSQL_DATABASE"
    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> "$tfile"
    if [ "$MYSQL_USER" != "" ]; then
      echo "[i] Creating user: $MYSQL_USER"
      echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
      echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
      echo "FLUSH PRIVILEGES;" >> "$tfile"
    fi
  fi

  /usr/sbin/mysqld --user=mysql --datadir="$MYSQL_DATADIR" --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < "$tfile"
  rm -f "$tfile"
  echo 'MySQL init process done.'
fi

chown -R mysql:mysql "$MYSQL_DATADIR"
chmod -R 755 "$MYSQL_DATADIR"

# Run mysql_upgrade once after a data-dir upgrade
if [ -d "$MYSQL_DATADIR/mysql" ] && [ ! -f "$UPGRADE_MARKER" ]; then
  echo "Starting MariaDB for upgrade..."
  mariadbd --user=mysql --datadir="$MYSQL_DATADIR" --skip-grant-tables &
  until mysqladmin -u root ping; do sleep 2; done
  mysql --socket="$MYSQL_SOCKET" <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
ALTER USER 'root'@'%' IDENTIFIED VIA unix_socket;
FLUSH PRIVILEGES;
EOF
  mysql_upgrade -u root --protocol=SOCKET --socket=/run/mysqld/mysqld.sock
  touch "$UPGRADE_MARKER"
  mysqladmin -u root shutdown
fi

# ============================ START UP ============================
# Keep the mempool DB user's password in sync with mempool-config.json on
# every boot, not just first-time datadir init. On a 0.3.x -> 0.4.x upgrade
# the datadir already exists, so the GRANT ... IDENTIFIED BY above never
# runs again; the DB user keeps its 0.3.x password forever while
# mempool-config.json can carry a different one, and the backend fails to
# authenticate on every restart. --init-file runs before mariadbd starts
# accepting connections, so this works without a separate authenticated
# session and is safe to repeat (ALTER USER to the same password is a no-op).
sync_password_file=$(mktemp)
cat << EOF > "$sync_password_file"
ALTER USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
ALTER USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
FLUSH PRIVILEGES;
EOF

mariadbd --user=mysql --datadir="$MYSQL_DATADIR" --init-file="$sync_password_file" &
db_process=$!

sed -i "s/user nobody;//g" /etc/nginx/nginx.conf
nginx -g 'daemon off;' &
frontend_process=$!

# Backend reads the mounted /backend/mempool-config.json (cwd = /backend).
# NODE_OPTIONS (heap size) is provided by the StartOS service definition.
cd /backend
/backend/wait-for-it.sh localhost:3306 --timeout=720 --strict -- node /backend/package/index.js &
backend_process=$!

echo 'All processes initialized'

wait -n $db_process $backend_process $frontend_process
EXIT_CODE=$?
echo "A child process exited (code=$EXIT_CODE), shutting down..."
_term
