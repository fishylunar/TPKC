#!/usr/bin/env bash

STACK_NAME="TPKC-stack"
CERTS_DIR="./certs"
CERT_FILE="$CERTS_DIR/cert.crt"
KEY_FILE="$CERTS_DIR/private.key"
NETWORK_NAME="traefik"

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
    echo "🗑️ Stopping and removing all containers in stack/project: $STACK_NAME..."
    
    docker ps -a --filter "label=com.docker.compose.project=$STACK_NAME" -q | xargs -r docker rm -f
    
    echo "🗑️ Removing all associated volumes..."
    docker volume ls --filter "label=com.docker.compose.project=$STACK_NAME" -q | xargs -r docker volume rm
    
    echo "🗑️ Removing Docker network '$NETWORK_NAME'..."
    docker network rm "$NETWORK_NAME" 2>/dev/null || echo "Network '$NETWORK_NAME' already removed."
    
    echo "✅ Cleanup completed for stack/project: $STACK_NAME."
}

# Handle script arguments
case "$1" in
    start)
        start_stack
    ;;
    stop)
        stop_stack
    ;;
    reset)
        reset_stack
    ;;
    *)
        echo "Usage: $0 {start|stop|reset}"
        exit 1
    ;;
esac
