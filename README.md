# TPKC Stack
TPKC Stack is a Docker stack containing Traefik - Portainer - KeyCloak - and a simple whoami web app as a PoC. 

It uses Traefik as a reverse proxy and managing SSL. KeyCloak for Auth & SSO, Portainer to easily manage our stack, and future containers, and then a simple web app to check that everything is running.

After following this guide you will have a Docker stack running that is secure & production ready (after some small tweaks) with secure authentacation using SSO from KeyCloak.

### Please note, the guide is still a WIP, and things may change in the future!!


# Getting Started

## Requirements & Expectations
* This assunes we are running on a Linux server (Ubuntu) - or on Windows with WSL2 installed (Ubuntu)
* Docker is installed
* You are somewhat familliar with Docker, Portainer, Keycloak & Traefik

## DNS records
We assume you have a DNS setup that looks like this:

```dns
A: auth.yourdomain.com ; <public-server-ip>
A: portainer.yourdomain.com ; <public-server-ip>
A: traefik.yourdomain.com ; <public-server-ip>
A: test.yourdomain.com ; <public-server-ip>
```
## Getting the files
* Clone / Download this repo inside of WSL, we assume these filea are stored in the `/home/<your username>/TPKC/` directory

* CD into the directory: `cd ./TPKC`

* Add execution permissions to `stack.sh` by running 
```shell
chmod +x ./stack.sh
```

* Get your (trusted) certificates from Cloudflare, Let's Encrypt, or somewhere else.

## Quick note
If something goes wrong and you want to start 100% over you can do so with the `./stack.sh reset` command. Be warned that it clears all of the containers & volumes.

```shell
sudo ./stack.sh reset
```

## Lets go!
* First off, make sure you place a valid trusted wildcard cert inside `./certs/` - thet should be called `cert.crt` & `private.key` (x509)
* Create a .env file that looks like this:
```ini
KEYCLOAK_USER=<admin usernamee>
KEYCLOAK_PASSWORD=<admin password>
POSTGRES_USER=<postgres username>
POSTGRES_PASSWORD=<postgres password>
BASE_HOST=<root host name, eg google.com>
TRAEFIK_USERFILE_CONTENTS=<"traefik userfile contents user:hashed>"
KC_MIDDLEWARE_REALM=<keycloak realm>
KC_MIDDLEWARE_CLIENT_ID=<keycloak middleware client id>
KC_MIDDLEWARE_CLIENT_SECRET=<keycloak middleware client secret>
```
Please make sure to use secure passwords for everything, you can generate some by using 
```shell
openssl rand -hex 32
```
**TRAEFIK_USERFILE_CONTENTS** should be set like so:
* Run this command in your terminal (You may need to install `apache2-utils` first `sudo apt install apache2-utils`)
```shell
echo $(htpasswd -nB user) | sed -e s/\\$/\\$\\$/g
```
* take the output of this and put it as the variable `RAEFIK_USERFILE_CONTEN` **(Remember quotes around this one!)**

* after this you can run the stack by running
```shell
sudo ./stack.sh start
```

* wait for everything to start up, then go to `https://auth.<your domain name>.tld:8443/admin/console` to set up and configure keycloak.
* Make changes in .env to match your keycloak client config (to make it work with our Traefik middleware)
* Set up Portainer to work with keycloak: https://techwave.j2dk.in/portainer-sso-with-keycloak/