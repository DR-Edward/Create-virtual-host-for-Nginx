#!/usr/bin/env bash

set -euo pipefail

# =========================
# CONFIG
# =========================
WEB_ROOT="/var/www/html"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
PREFIX="vhost."
INDEX_FILE="index.html"
HOST_FILE='/etc'
HOST_NAME='dnsmasq.hosts'

# =========================
# STATE (for rollback)
# =========================
CREATED_DIR=false
CREATED_INDEX=false
CREATED_CONF=false
CREATED_SYMLINK=false

# =========================
# DOMAIN DATA
# =========================
DOMAIN=""
DOMAIN_DIR=""
CONF_AVAILABLE=""
CONF_ENABLED=""

# =========================
# LOGGING
# =========================
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; }

# =========================
# VALIDATIONS
# =========================
require_root()
{
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be executed as root"
    exit 1
  fi
}

validate_domain()
{
if [[ ! "$1" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
  log_error "Invalid domain name: $1"
    exit 1
  fi
}

check_exist()
{
  if [[ -e "$1" ]]; then
      log_error "Already exists: $1"
      exit 1
  fi
}

# =========================
# ROLLBACK
# =========================
rollback()
{
  log_error "An error happens. Executing rollback..."

  [[ "$CREATED_SYMLINK" == true ]] && rm -f "$CONF_ENABLED"
  [[ "$CREATED_CONF" == true ]] && rm -f "$CONF_AVAILABLE"
  [[ "$CREATED_INDEX" == true ]] && rm -f "$DOMAIN_DIR/$INDEX_FILE"
  [[ "$CREATED_DIR" == true ]] && rm -rf "$DOMAIN_DIR"

  log_info "Rollback complete"
}

trap rollback ERR

# =========================
# CORE FUNCTIONS
# =========================
create_directory()
{
  DOMAIN_DIR="$WEB_ROOT/$PREFIX$DOMAIN"
  check_exist "$DOMAIN_DIR"

  log_info "Creating directory: $DOMAIN_DIR"
  mkdir -p "$DOMAIN_DIR"
  CREATED_DIR=true
}

create_index()
{
  local index_path="$DOMAIN_DIR/$INDEX_FILE"
  check_exist "$index_path"

  log_info "Creating index file: $index_path"

  cat > "$index_path" <<EOF
<!DOCTYPE html>
<html>
  <head>
      <meta charset="UTF-8">
  </head>
  <body>
      <h1>$DOMAIN</h1>
      <pre>
      ⠸⣿⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠔⠒⠒⠒⢤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠙⠻⣿⣷⣦⣀⠀⠀⠀⢀⣾⣷⠀⠘⠀⠀⠀⠙⢆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠉⠛⠙⢏⢩⣶⣿⣿⠿⠖⠒⠤⣄⠀⠀⠈⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠋⢅⡈⠐⠠⢀⠀⠈⢆⠀⠀⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠐⠠⢀⠩⠀⢸⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⣿⣹⠆⣿⣉⢀⡟⡄⣰⠉⠂⢸⣏⠁⠀⠀⠀⡌⠀⠀⠸⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠛⠀⠀⠓⠒⠘⠉⠛⠘⠒⠃⠘⠒⠂⠀⠀⢰⠁⠀⠀⠀⠑⢤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⢦⢠⡄⡄⢠⣦⠀⣔⠢⠀⠀⠀⠀⡠⠃⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠙⠒⠒⠤⢄⣀⠤⠔⠒⡄
      ⠀⠀⠀⠸⠏⠳⠃⠟⠺⠆⠬⠽⠀⠀⠀⢰⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇
      ⠀⣄⢀⡀⣠⠀⢠⡀⣠⢠⡀⠀⣠⢀⡀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡼⠀
      ⠀⡏⢿⡇⣿⣒⠈⣧⡇⢸⣒⡂⣿⢺⡁⠀⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡤⠊⠀⠀
      ⠀⠀⠈⠀⠀⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡸⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⣼⣳⠀⡟⣼⠀⠀⠀⠀⠀⠀⠀⠈⢆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠇⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠃⠈⠃⠃⠘⠀⠀⠀⠀⠀⠀⠀⠀⠈⢆⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⢀⠎⠀⠀⠀⠀⠀
      ⡖⢲⡄⣶⣲⡆⢲⠒⣶⢀⡖⢲⠀⡶⡄⡆⠀⠀⠀⠀⣿⠁⠀⠈⠑⠢⣄⠀⠀⠀⢠⠎⠀⠀⠀⠀⠀⠀
      ⠳⠼⠃⠿⠀⠀⠸⠀⠿⠈⠣⠞⠀⠇⠹⠇⠀⠀⠀⢸⣿⠀⠀⠀⠀⠀⠀⠙⣢⡴⠁⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣶⣶⣶⣾⣿⡿⠀⠀⠀⠀⠀⠀⠀⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⠛⠿⠛⠉⠀⠀⠀⠀⠀⠀⠀⢀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣴⣶⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀
      ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⠛⠉⠻⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
      </pre>
  </body>
  <style>
    body {
      background-color: #181a1b;
      color: #e8e6e3;
      min-height: 100vh;
    }
  </style>
</html>
EOF

  CREATED_INDEX=true
}

create_nginx_config()
{
  CONF_AVAILABLE="$NGINX_AVAILABLE/$DOMAIN.conf"
  CONF_ENABLED="$NGINX_ENABLED/$DOMAIN.conf"

  check_exist "$CONF_AVAILABLE"

  log_info "Creating Nginx config: $CONF_AVAILABLE"

  cat > "$CONF_AVAILABLE" <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN;

    root $DOMAIN_DIR;
    index $INDEX_FILE index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

  CREATED_CONF=true
}

enable_site()
{
  check_exist "$CONF_ENABLED"

  log_info "Enabling site (symlink)"
  ln -s "$CONF_AVAILABLE" "$CONF_ENABLED"

  CREATED_SYMLINK=true
}

reload_nginx()
{
  log_info "Validating Nginx configuration"
  nginx -t

  log_info "Restarting Nginx"
  systemctl reload nginx
}

# =========================
# SELECTING IP SECTION
# =========================
get_ipv4_list() {
  ip -4 -o addr show \
    | awk '{print $4}' \
    | cut -d/ -f1 \
    | sort -u
}

ensure_loopback() {
  local list=("$@")
  local has_loopback=false

  for ip in "${list[@]}"; do
    if [[ "$ip" == "127.0.0.1" ]]; then
      has_loopback=true
      break
    fi
  done

  if ! $has_loopback; then
    list+=("127.0.0.1")
  fi

  printf "%s\n" "${list[@]}"
}

build_ip_array() {
  local ips=()

  while IFS= read -r ip; do
    [[ -n "$ip" ]] && ips+=("$ip")
  done < <(get_ipv4_list)

  mapfile -t ips < <(ensure_loopback "${ips[@]}")

  printf "%s\n" "${ips[@]}"
}

print_menu() {
  local ips=("$@")

  echo "Select an IP address:"
  for i in "${!ips[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${ips[$i]}"
  done
}

read_option() {
  local max="$1"
  local choice

  while true; do
    read -rp "Enter option number: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max )); then
      echo "$choice"
      return 0
    fi

    echo "Invalid option. Try again."
  done
}

select_ipv4() {
  local ips=()

  mapfile -t ips < <(build_ip_array)

  if [[ "${#ips[@]}" -eq 0 ]]; then
    log_error "No IPv4 addresses found"
    return 1
  fi

  print_menu "${ips[@]}"

  local choice
  choice=$(read_option "${#ips[@]}")

  IP_SELECTED="${ips[$((choice-1))]}"

  echo "You chose the IP: $IP_SELECTED"
}

add_domain_to_hosts()
{
  select_ipv4
  echo "$IP_SELECTED $DOMAIN" >> "$HOST_FILE/$HOST_NAME"
}

# =========================
# MAIN
# =========================
usage()
{
  echo ""
  echo "This script must have a valid domain name like 'domain.com' or 'vhost.first-domain' "
  echo -e "\t-d Creates a full domain for nginx"
  exit 1
}

main()
{
  require_root

  if [[ $# -eq 0 ]]; then
    usage
  fi

  while getopts "d:" opt; do
    case "$opt" in
      d) DOMAIN="$OPTARG" ;;
      *) usage ;;
    esac
  done

  if [[ -z "$DOMAIN" ]]; then
    usage
  fi

  validate_domain "$DOMAIN"

  log_info "Starting domain creation: $DOMAIN"

  create_directory
  create_index
  create_nginx_config
  add_domain_to_hosts
  enable_site
  reload_nginx

  log_info "Domain created successfully: $DOMAIN"
}

main "$@"