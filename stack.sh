#!/usr/bin/env bash

STACK_NAME="TPKC"
CERTS_DIR="./certs"
CERT_FILE="$CERTS_DIR/cert.crt"
KEY_FILE="$CERTS_DIR/private.key"
NETWORK_NAME="traefik"

# Function to generate self-signed certificate
gen_selfsigned_cert() {
    echo "🔑 Generating self-signed certificate..."

    # Create the certificates directory if it doesn't exist
    mkdir -p "$CERTS_DIR"

    # Prompt for domains
    read -p "Enter a comma-separated list of domains (e.g., example.com, www.example.com): " DOMAIN_INPUT
    IFS=',' read -r -a DOMAINS <<< "$DOMAIN_INPUT"

    # Generate a private key
    openssl genrsa -out "$KEY_FILE" 2048

    # Create a configuration file for the certificate
    cat > openssl.cnf <<EOL
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
x509_extensions    = v3_req
prompt             = no

[ req_distinguished_name ]
C  = DK
ST = Some-State
L  = Some-City
O  = Your Organization
OU = Your Organizational Unit
CN = ${DOMAINS[0]}

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[ alt_names ]
EOL

    # Add each domain to the configuration file
    for i in "${!DOMAINS[@]}"; do
        echo "DNS.$((i + 1)) = ${DOMAINS[i]}" >> openssl.cnf
    done

    # Generate the self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$KEY_FILE" -out "$CERT_FILE" -config openssl.cnf

    # Clean up
    rm openssl.cnf

    echo "✅ Self-signed certificate and private key generated:"
    echo "   Private Key: $KEY_FILE"
    echo "   Certificate: $CERT_FILE"
}

# Function to check and create the "traefik" Docker network
check_create_docker_network() {
    if docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$"; then
        echo "✅ Docker network '$NETWORK_NAME' already exists."
    else
        echo "🚀 Creating Docker network '$NETWORK_NAME'..."
        docker network create "$NETWORK_NAME"
        if [ $? -eq 0 ]; then
            echo "✅ Docker network '$NETWORK_NAME' created successfully."
        else
            echo "❌ Error: Failed to create Docker network '$NETWORK_NAME'!"
            exit 1
        fi
    fi
}

# Function to check environment variables
check_env_variables() {
    echo "⭐ Setting up $STACK_NAME environment"
    
    if [ -f .env ]; then
        export $(grep -v '^#' .env | xargs)
    else
        echo "❌ Error: .env file not found!"
        exit 1
    fi
    
    REQUIRED_VARS=(
        "KEYCLOAK_USER"
        "KEYCLOAK_PASSWORD"
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "BASE_HOST"
        "TRAEFIK_USERFILE_CONTENTS"
        "KC_MIDDLEWARE_REALM"
        "KC_MIDDLEWARE_CLIENT_ID"
        "KC_MIDDLEWARE_CLIENT_SECRET"
    )
    
    MISSING_VARS=()
    for VAR in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!VAR}" ]; then
            MISSING_VARS+=("$VAR")
        fi
    done
    
    if [ ${#MISSING_VARS[@]} -ne 0 ]; then
        echo "❌ Error: The following required environment variables are missing:"
        for VAR in "${MISSING_VARS[@]}"; do
            echo "  - $VAR"
        done
        exit 1
    fi
    
    echo "✅ All required environment variables are set."
}

# Function to check and validate certificates
check_certificates() {
    if [ ! -d "$CERTS_DIR" ]; then
        echo "❌ Error: Certificate directory ($CERTS_DIR) does not exist!"
        exit 1
    fi
    
    if [ ! -f "$CERT_FILE" ]; then
        echo "❌ Error: Missing certificate file ($CERT_FILE)!"
        exit 1
    fi
    
    if [ ! -f "$KEY_FILE" ]; then
        echo "❌ Error: Missing private key file ($KEY_FILE)!"
        exit 1
    fi
    
    if ! openssl x509 -in "$CERT_FILE" -noout >/dev/null 2>&1; then
        echo "❌ Error: Certificate file ($CERT_FILE) is not a valid X.509 certificate!"
        exit 1
    fi
    
    if ! openssl rsa -in "$KEY_FILE" -check -noout >/dev/null 2>&1; then
        echo "❌ Error: Private key file ($KEY_FILE) is not a valid RSA key!"
        exit 1
    fi
    
    echo "✅ Certificate and private key are valid."
}

# Function to start the stack
start_stack() {
    check_env_variables
    check_certificates
    check_create_docker_network
    
    echo "🚀 Starting $STACK_NAME..."
    docker compose up -d
    echo "🎉 Containers should be spinning up now!"
}

# Function to stop the stack
stop_stack() {
    echo "🛑 Stopping $STACK_NAME..."
    docker compose down
    echo "✅ Stack stopped."
}

# Function to reset the stack
reset_stack() {
    echo "🗑️ Stopping and removing all containers..."
    docker compose down --remove-orphans
    
    echo "🗑️ Removing all containers associated with the compose project..."
    docker compose rm -f -s -v
    
    echo "🗑️ Removing all images used by the compose project..."
    docker compose config --images | xargs -r docker rmi -f
    
    echo "🗑️ Removing all volumes..."
    docker compose down --volumes
    
    echo "🗑️ Removing Docker network '$NETWORK_NAME'..."
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
    
    echo "✅ Cleanup completed for stack: $STACK_NAME."
}

# Handle script arguments
case "$1" in
    start)
        start_stack
    ;;
    stop)
        stop_stack
    ;;
    ssl)
        gen_selfsigned_cert
    ;;
    reset)
        reset_stack
    ;;
    *)
        echo "Usage: $0 {start|stop|reset}"
        exit 1
    ;;
esac
