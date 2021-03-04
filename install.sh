#!/bin/bash

# Libernet Installer
# by Lutfa Ilham
# v1.1

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

LIBERNET_DIR="/root/libernet"
LIBERNET_WWW="/www/libernet"

function install_packages() {
  while IFS= read -r line; do
    opkg install "${line}"
  done < ./requirements.txt
}

function install_requirements() {
  echo -e "Installing packages" \
    && opkg update \
    && install_packages \
    && echo -e "Copying proprietary binary" \
    && cp -arvf ./proprietary/* /usr/bin/
}

function enable_uhttp_php() {
  echo -e "Enabling uhttp php execution" \
    && sed -i '/^#.*php-cgi/s/^#//' '/etc/config/uhttpd' \
    && uci commit uhttpd \
    && echo -e "Restarting uhttp service" \
    && /etc/init.d/uhttpd restart
}

function add_libernet_environment() {
  echo -e "Adding Libernet environment" \
    && echo -e "# Libernet\nexport LIBERNET_DIR=${LIBERNET_DIR}" | tee -a '/etc/profile'
}

function install_libernet() {
  echo -e "Installing Libernet" \
    && mkdir -p "${LIBERNET_DIR}" \
    && echo -e "Copying binary" \
    && cp -arvf ./bin "${LIBERNET_DIR}/" \
    && echo -e "Copying system" \
    && cp -arvf ./system "${LIBERNET_DIR}/" \
    && echo -e "Copying log" \
    && cp -arvf ./log "${LIBERNET_DIR}/" \
    && echo -e "Copying web files" \
    && mkdir -p "${LIBERNET_WWW}" \
    && cp -arvf ./web/* "${LIBERNET_WWW}/" \
    && echo -e "Configuring Libernet" \
    && sed -i "s/LIBERNET_DIR/$(echo ${LIBERNET_DIR} | sed 's/\//\\\//g')/g" "${LIBERNET_WWW}/config.inc.php"
}

function configure_libernet_firewall() {
  echo "Configuring Libernet firewall" \
    && uci set network.libernet=interface \
    && uci set network.libernet.proto='none' \
    && uci set network.libernet.ifname='tun1' \
    && uci commit \
    && uci add firewall zone \
    && uci set firewall.@zone[-1].network='libernet' \
    && uci set firewall.@zone[-1].name='libernet' \
    && uci set firewall.@zone[-1].masq='1' \
    && uci set firewall.@zone[-1].mtu_fix='1' \
    && uci set firewall.@zone[-1].input='REJECT' \
    && uci set firewall.@zone[-1].forward='REJECT' \
    && uci set firewall.@zone[-1].output='ACCEPT' \
    && uci add firewall forwarding \
    && uci set firewall.@forwarding[-1].src='lan' \
    && uci set firewall.@forwarding[-1].dest='libernet' \
    && uci commit
}

function finish_install() {
    echo -e "Libernet successfully installed!\nLibernet URL: http://router-ip/libernet"
}

install_requirements \
  && install_libernet \
  && add_libernet_environment \
  && enable_uhttp_php \
  && configure_libernet_firewall \
  && finish_install