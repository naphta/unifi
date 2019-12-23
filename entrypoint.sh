#!/usr/bin/env bash
log() {
  echo "$(date +"[%Y-%m-%d %T,%3N]") <docker-entrypoint> $*"
}

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

MONGODB_USERNAME="mongodb"
MONGODB_PASSWORD="mongodb"
MONGODB_DATABASE="unifi"
MONGODB_HOST="127.0.0.1"
MONGODB_PORT="27017"

JAVA_ARGS="-Djava.awt.headless=true -Dfile.encoding=UTF-8"

sed -i "s/{{ mongodb_uri }}/mongodb:\/\/${MONGODB_USERNAME}:${MONGODB_PASSWORD}@${MONGODB_HOST}:${MONGODB_PORT}\/${MONGODB_DATABASE}/" /etc/unifi/data/system.properties
sed -i "s/{{ mongodb_stats_uri }}/mongodb:\/\/${MONGODB_USERNAME}:${MONGODB_PASSWORD}@${MONGODB_HOST}:${MONGODB_PORT}\/${MONGODB_DATABASE}_stat/" /etc/unifi/data/system.properties
sed -i "s/{{ mongodb_unifi_db }}/${MONGODB_DATABASE}/" /etc/unifi/data/system.properties

if [[ ! -d "/etc/unifi/cert" || ! -f "/etc/unifi/cert/cert.pem" ]]; then
  log 'No certificates directory found.'
else
  log 'Certificates directory found'
  log 'Checking Certificates...'

  if md5sum -c "/etc/unifi/cert/cert.md5" &>/dev/null; then
    log "Certificates has not changed, not updating controller."
  else
    if [ ! -e "/etc/unifi/keystore" ]; then
      log "WARN: Missing keystore, creating a new one"

      if [ ! -d "/etc/unifi" ]; then
        log "Missing data directory, creating..."
        mkdir "/etc/unifi"
      fi

      keytool -genkey -keyalg RSA -alias unifi -keystore "/etc/unifi/keystore" \
        -storepass aircontrolenterprise -keypass aircontrolenterprise -validity 1825 \
        -keysize 4096 -dname "cn=UniFi"
    fi

    TEMPFILE=$(mktemp)
    TMPLIST="${TEMPFILE}"
    CERTTEMPFILE=$(mktemp)
    TMPLIST+=" ${CERTTEMPFILE}"
    CERTURI=$(openssl x509 -noout -ocsp_uri -in "/etc/unifi/cert/cert.pem")
    # Identrust cross-signed CA cert needed by the java keystore for import.
    # Can get original here: https://www.identrust.com/certificates/trustid/root-download-x3.html
    cat >"${CERTTEMPFILE}" <<'_EOF'
-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----
_EOF

    log "Certificates has changed, updating controller..."
    md5sum "/etc/unifi/cert/cert.pem" >"/etc/unifi/cert/cert.pem.md5"
    log "Using openssl to prepare certificate..."
    CHAIN=$(mktemp)
    TMPLIST+=" ${CHAIN}"

    if [[ "${CERTURI}" == *"letsencrypt"* && "$CERT_IS_CHAIN" == "true" ]]; then
      awk 1 "${CERTTEMPFILE}" "/etc/unifi/cert/cert.pem" >>"${CHAIN}"
    elif [[ "${CERTURI}" == *"letsencrypt"* ]]; then
      awk 1 "${CERTTEMPFILE}" "/etc/unifi/cert/chain.pem" "/etc/unifi/cert/cert.pem" >>"${CHAIN}"
    elif [[ -f "/etc/unifi/cert/ca.pem" ]]; then
      awk 1 "/etc/unifi/cert/ca.pem" "/etc/unifi/cert/chain.pem" "/etc/unifi/cert/cert.pem" >>"${CHAIN}"
    else
      awk 1 "/etc/unifi/cert/chain.pem" "/etc/unifi/cert/cert.pem" >>"${CHAIN}"
    fi
    openssl pkcs12 -export -passout pass:aircontrolenterprise \
      -in "${CHAIN}" \
      -inkey "/etc/unifi/cert/${CERT_PRIVATE_NAME}" \
      -out "${TEMPFILE}" -name unifi
    log "Removing existing certificate from Unifi protected keystore..."
    keytool -delete -alias unifi -keystore "/etc/unifi/keystore" \
      -deststorepass aircontrolenterprise
    log "Inserting certificate into Unifi keystore..."
    keytool -trustcacerts -importkeystore \
      -deststorepass aircontrolenterprise \
      -destkeypass aircontrolenterprise \
      -destkeystore "/etc/unifi/keystore" \
      -srckeystore "${TEMPFILE}" -srcstoretype PKCS12 \
      -srcstorepass aircontrolenterprise \
      -alias unifi
    log "Cleaning up temp files"
    for file in ${TMPLIST}; do
      rm -f "${file}"
    done
    log "Done!"
  fi
fi

touch /etc/unifi/logs/server.log
ln -sf /proc/1/fd/1 /etc/unifi/logs/server.log

/usr/bin/java "${JAVA_ARGS}" -jar /etc/unifi/lib/ace.jar start
