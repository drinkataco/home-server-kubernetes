#!/bin/sh

HASS_CONTAINER_NAME=$(kubectl get pods \
  --field-selector=status.phase=Running \
  --no-headers \
  -o custom-columns=':metadata.name' \
  | grep 'homeassistant');
TMP_FILE='/tmp/configuration.yaml'

# Copy existing configuration.yaml to local
kubectl cp "${HASS_CONTAINER_NAME}:config/configuration.yaml" "${TMP_FILE}" 

# Add HTTP Reverse Proxy
if grep -q ^http:$ "$TMP_FILE"; then
  echo 'WARNING a http object has already been found in configuration.yaml'
  printf 'Do you want to overwrite it? [y/N] '
  read -r overwrite
  if [ "$overwrite" != 'y' -a "$overwrite" != 'Y' ]; then
    exit
  fi
fi

echo 'Adding http: object to enable reverse proxies'

cat <<HDL >>$TMP_FILE

http:
  use_x_forwarded_for: true
  trusted_proxies:
    - '10.0.0.0/8'
HDL

# Copy updated file back to container
kubectl cp "${TMP_FILE}" "${HASS_CONTAINER_NAME}:config/configuration.yaml"

# Restart container to reapply config
kubectl exec "${HASS_CONTAINER_NAME}" -- reboot
