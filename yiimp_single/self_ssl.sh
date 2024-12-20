#!/usr/bin/env bash

#####################################################
# Source: https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by: afiniel for crypto use
#####################################################

# Load required functions and configurations
source /etc/functions.sh
source /etc/yiimpool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

# Exit on error and enable pipe fail
set -euo pipefail

# Function to print error messages
print_error() {
  local line file
  read -r line file <<< "$(caller)"
  echo "Error in line $line of file $file:" >&2
  sed "${line}q;d" "$file" >&2
}

trap print_error ERR

# Display banner
term_art
echo
echo -e "$YELLOW Creating initial SSL certificate${NC}"
echo

# Install OpenSSL if not installed
install_if_not_installed apt_install openssl

# Create SSL directory if it doesn't exist
sudo mkdir -p "$STORAGE_ROOT/ssl"

# Generate private key if not already generated
if [ ! -f "$STORAGE_ROOT/ssl/ssl_private_key.pem" ]; then
  (
    umask 077
    hide_output sudo openssl genrsa -out "$STORAGE_ROOT/ssl/ssl_private_key.pem" 2048
  )
fi

# Generate self-signed certificate if not already generated
if [ ! -f "$STORAGE_ROOT/ssl/ssl_certificate.pem" ]; then
  CSR="/tmp/ssl_cert_sign_req-$RANDOM.csr"
  hide_output sudo openssl req -new -key "$STORAGE_ROOT/ssl/ssl_private_key.pem" -out "$CSR" \
    -sha256 -subj "/CN=$PRIMARY_HOSTNAME"

  CERT="$STORAGE_ROOT/ssl/$PRIMARY_HOSTNAME-selfsigned-$(date --rfc-3339=date | tr -d '-').pem"
  hide_output sudo openssl x509 -req -days 365 -in "$CSR" -signkey "$STORAGE_ROOT/ssl/ssl_private_key.pem" -out "$CERT"

  sudo rm -f "$CSR"
  sudo ln -s "$CERT" "$STORAGE_ROOT/ssl/ssl_certificate.pem"
fi

# Generate Diffie-Hellman cipher bits if not already generated
if [ ! -f /etc/nginx/dhparam.pem ]; then
  hide_output sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
fi

echo -e "$GREEN => Initial self-signed SSL generation complete <= ${NC}"

cd $HOME/Yiimpoolv1/yiimp_single
