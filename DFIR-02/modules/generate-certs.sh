#!/bin/bash

# Certificate Generation Script for DFIR IRIS and Velociraptor
# This script generates SSL certificates for secure communication

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Warning: .env file not found, using default values"
fi

# Certificate settings
CERT_DIR="./certs"
CERT_COUNTRY="${CERT_COUNTRY:-FR}"
CERT_STATE="${CERT_STATE:-IDF}"
CERT_CITY="${CERT_CITY:-Paris}"
CERT_ORG="${CERT_ORG:-DFIR-Lab}"
CERT_OU="${CERT_OU:-Security}"
CERT_EMAIL="${CERT_EMAIL:-admin@dfir.local}"

# Certificate validity (in days)
CERT_VALIDITY=3650  # 10 years

echo "🔐 Generating SSL certificates for DFIR IRIS and Velociraptor..."

# Create certificate directory
mkdir -p "${CERT_DIR}"

# Function to generate certificate
generate_cert() {
    local name=$1
    local cn=$2
    local alt_names=$3
    
    echo "📜 Generating certificate for ${name} (CN: ${cn})"
    
    # Generate private key
    openssl genrsa -out "${CERT_DIR}/${name}.key" 4096
    
    # Create certificate signing request
    openssl req -new -key "${CERT_DIR}/${name}.key" -out "${CERT_DIR}/${name}.csr" \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=${cn}/emailAddress=${CERT_EMAIL}"
    
    # Create extensions file if alt names provided
    if [ ! -z "${alt_names}" ]; then
        cat > "${CERT_DIR}/${name}.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = ${alt_names}
EOF
        # Sign certificate with extensions
        openssl x509 -req -in "${CERT_DIR}/${name}.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" \
            -CAcreateserial -out "${CERT_DIR}/${name}.crt" -days ${CERT_VALIDITY} -extensions v3_req \
            -extfile "${CERT_DIR}/${name}.ext"
        rm "${CERT_DIR}/${name}.ext"
    else
        # Sign certificate without extensions
        openssl x509 -req -in "${CERT_DIR}/${name}.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" \
            -CAcreateserial -out "${CERT_DIR}/${name}.crt" -days ${CERT_VALIDITY}
    fi
    
    # Clean up CSR
    rm "${CERT_DIR}/${name}.csr"
    
    # Set appropriate permissions
    chmod 600 "${CERT_DIR}/${name}.key"
    chmod 644 "${CERT_DIR}/${name}.crt"
    
    echo "✅ Certificate generated: ${CERT_DIR}/${name}.crt"
}

# 1. Generate CA certificate
echo "🏛️  Generating Certificate Authority (CA)..."
openssl genrsa -out "${CERT_DIR}/ca.key" 4096
openssl req -new -x509 -days ${CERT_VALIDITY} -key "${CERT_DIR}/ca.key" -out "${CERT_DIR}/ca.crt" \
    -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=DFIR-CA/emailAddress=${CERT_EMAIL}"

chmod 600 "${CERT_DIR}/ca.key"
chmod 644 "${CERT_DIR}/ca.crt"
echo "✅ CA certificate generated: ${CERT_DIR}/ca.crt"

# 2. Generate IRIS certificate
generate_cert "iris" "iris-web" "DNS:iris-web,DNS:localhost,IP:127.0.0.1,IP:172.20.0.2"

# 3. Generate Velociraptor server certificate
generate_cert "velociraptor-server" "velociraptor-server" "DNS:velociraptor-server,DNS:localhost,IP:127.0.0.1,IP:172.20.0.3"

# 4. Generate Velociraptor client certificate
generate_cert "velociraptor-client" "velociraptor-client" "DNS:velociraptor-client,DNS:localhost,IP:127.0.0.1"

# 5. Generate mutual authentication certificates for IRIS-Velociraptor communication
generate_cert "iris-velociraptor" "iris-velociraptor" "DNS:iris-web,DNS:velociraptor-server"

# 6. Create certificate bundle
echo "📦 Creating certificate bundle..."
cat "${CERT_DIR}/ca.crt" > "${CERT_DIR}/ca-bundle.crt"
echo "✅ Certificate bundle created: ${CERT_DIR}/ca-bundle.crt"

# 7. Generate DH parameters for enhanced security
echo "🔒 Generating Diffie-Hellman parameters (this may take a while)..."
openssl dhparam -out "${CERT_DIR}/dhparam.pem" 2048
chmod 644 "${CERT_DIR}/dhparam.pem"
echo "✅ DH parameters generated: ${CERT_DIR}/dhparam.pem"

# 8. Create verification script
cat > "${CERT_DIR}/verify-certs.sh" << 'EOF'
#!/bin/bash
echo "🔍 Verifying certificates..."
for cert in *.crt; do
    if [ "$cert" != "ca.crt" ]; then
        echo "Verifying $cert..."
        openssl verify -CAfile ca.crt "$cert"
    fi
done
echo "📋 Certificate details:"
for cert in *.crt; do
    echo "=== $cert ==="
    openssl x509 -in "$cert" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After|DNS:|IP Address:)"
    echo
done
EOF

chmod +x "${CERT_DIR}/verify-certs.sh"

# Set final permissions
find "${CERT_DIR}" -name "*.key" -exec chmod 600 {} \;
find "${CERT_DIR}" -name "*.crt" -exec chmod 644 {} \;
find "${CERT_DIR}" -name "*.pem" -exec chmod 644 {} \;

echo "🎉 Certificate generation completed!"
echo "📁 Certificates are stored in: ${CERT_DIR}/"
echo "🔍 Run './certs/verify-certs.sh' to verify all certificates"
echo "⚠️  Remember to update your configuration files with the new certificates"

# Display certificate information
echo ""
echo "📋 Generated certificates:"
ls -la "${CERT_DIR}/"*.crt "${CERT_DIR}/"*.key 2>/dev/null || true

echo ""
echo "🔐 Certificate fingerprints:"
for cert in "${CERT_DIR}/"*.crt; do
    if [ -f "$cert" ]; then
        echo "$(basename "$cert"): $(openssl x509 -noout -fingerprint -sha256 -in "$cert" | cut -d= -f2)"
    fi
done