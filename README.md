# TPKC Stack

TPKC Stack is a Docker stack containing Traefik - Portainer - KeyCloak - and a simple whoami web app as a PoC.

It uses Traefik as a reverse proxy and managing SSL. KeyCloak for Auth & SSO, Portainer to easily manage our stack, and future containers, and then a simple web app to check that everything is running.

After following this guide you will have a Docker stack running that is secure & production ready (after some small tweaks) with secure authentacation using SSO from KeyCloak.

# Getting Started

## Requirements & Expectations

- This assunes we are running on a Linux server (Ubuntu) - or on Windows with WSL2 installed (Ubuntu)
- Docker is installed
- You are somewhat familliar with Docker, Portainer, Keycloak & Traefik

## If running on Windows with WSL
* Make a file called startup.ps1 in the `C:\` dir
```powershell
start "C:\Program Files\Docker\Docker\Docker Desktop.exe"
start-service -Name com.docker.service
```
* Open "Task Scheduler"
* Create a new task (Not a basic task)
* Lets call it `DockerDaemonStartUp`
* Click "Run wether user is logged in or not"
* Click "Run with highest privilege"
* Make sure "Configure for" is set to "Windows 10"
* Go to Triggers, adn add a new trigger "At startup", add a one minute delay, to allow the system to stat up before running Docker.
* Now go to the actions tab, and create a new one, The action should be "Start a program", and the path is `"C:\startup.ps1"`

## DNS records

We assume you have a DNS setup that looks like this:

```dns
A: auth.yourdomain.com ; <public-server-ip>
A: portainer.yourdomain.com ; <public-server-ip>
A: traefik.yourdomain.com ; <public-server-ip>
A: test.yourdomain.com ; <public-server-ip>
```

### If you dont want to use a public domain name, you can edit the Hosts file like so:
Hosts config (on the server)
```txt
127.0.0.1		auth.<yourdomain.com>
127.0.0.1		dashboard.<yourdomain.com>
127.0.0.1		traefik.<yourdomain.com>
127.0.0.1		test.<yourdomain.com>
127.0.0.1		portainer.<yourdomain.com>
```
Make sure to get the internal ip of your server as well.
Then on the machine you want to be able to access the services on:

```txt
<server-internal-ip>		dashboard.<yourdomain.com>
<server-internal-ip>		portainer.<yourdomain.com>
<server-internal-ip>		traefik.<yourdomain.com>
<server-internal-ip>		auth.<yourdomain.com>
<server-internal-ip>		test.<yourdomain.com>
```
## Quick note

If something goes wrong and you want to start 100% over you can do so with the `./stack.sh reset` command. Be warned that it clears all of the containers & volumes.

```shell
sudo ./stack.sh reset
```

## Getting the files

- Clone / Download this repo inside of WSL, we assume these filea are stored in the `/home/<your username>/TPKC/` directory

- CD into the directory: `cd ./TPKC`

- Add execution permissions to `stack.sh` by running

```shell
chmod +x ./stack.sh
```

## Getting Certificates
You can either get your certificates from Let's Encrypt, Cloudflare, or wherever you have your domain name, then use them like so:
* Put the private key in a file called `private.key` inside the `./certs/` directory.
* Then put your certificate in a file called `cert.crt` inside the `./certs/` directory.

### If you want to create a new self-signed certificate:
* You can generate a self-signed certificate by running:
```shell
./stack.sh ssl
```
* You will then be asked to enter a list of domain names, I recommend entering `*.<yourdomain.com>,yourdomain.com,localhost`
This will generate your certificates and put them inside the `./certs/` directory.



## Lets go!

- First off, make sure you place a valid trusted wildcard cert inside `./certs/` - thet should be called `cert.crt` & `private.key` (x509)
- Create a .env file that looks like this:

```ini
KEYCLOAK_USER=<admin usernamee>
KEYCLOAK_PASSWORD=<admin password>
POSTGRES_USER=<postgres username>
POSTGRES_PASSWORD=<postgres password>
BASE_HOST=<root host name, eg google.com>
TRAEFIK_USERFILE_CONTENTS="<traefik userfile contents user:hashed>"
KC_MIDDLEWARE_REALM=<keycloak realm>
KC_MIDDLEWARE_CLIENT_ID=<keycloak middleware client id>
KC_MIDDLEWARE_CLIENT_SECRET=<keycloak middleware client secret>
```

Please make sure to use secure passwords for everything, you can generate some by using

```shell
openssl rand -hex 32
```

**TRAEFIK_USERFILE_CONTENTS** should be set like so:

- Generate a htpasswd (user:(sha1)hash) and put it in quotes, in the variable `RAEFIK_USERFILE_CONTEN`
- You may need to install apache2-utils to use the command below. Run this command to install it: `sudo apt install apache2-utils`
- Then generate one like so:
```shell
htpasswd -nbs <username> <password>
```

- after this you can run the stack by running

```shell
sudo ./stack.sh start
```

* Now would be a good time to set up the admin account for Portainer. go to `https://portainer.<yourdomain.com>/` to set it up. (You have a 30 minute window from starting Portainer for the first time to be able to set the admin password.)

## Configure Keycloak
Wait for everything to start up (This might take a few minutes), then go to `https://auth.<yourdomain.com>:8443/admin/console`
You should log in using the username and password you specified in your `.env` file.

* Either import your existing `realm-export.json` file, or make a new Realm.

## Create a user
* Go to users tab in the sidebar, click `Create new user`
* Enter a username, email, and so on. and click the `Email verified` checkbox.
* Then go in to the **Credentials** tab in the new user you made, and add a password.
* You can also go in and add the user to groups, and give the user roles / permissions.

## Lets set up keycloak auth on our test server (`test.<yourdomain.com>`)
* Go to Clients and make a new client, we call it `Gatekeeper`, we use the following settings
```txt
Client Type: OpenID Connect
Client ID: gatekeeper
Name: Gatekeeper
Description: Default gatekeeper, doesn't check much, just that you have a valid Keycloak session before allowing access.
```

* Click next and follow to the next page, here we use the following options:
```txt
Client authentacation: on
Check these boxes: "Standard flow", "OAuth 2.0 Device Authorization Grant", and "Direct access grants"
``` 
* Click next, and enter the following values
```txt
Root URL: https://test.<yourdomain.com>/
Home URL: https://test.<yourdomain.com>/
Valid Redirect URLS: https://test.<yourdomain.com>/*
Web Origins: https://test.<yourdomain.com>/
```
* Click save, then go into the **Credentials** tab on the page that comes up.
* Copy the Client Secret
* Change these lines in the `.env` file:
```ini
KC_MIDDLEWARE_REALM=<Your newly created realm name here.>
KC_MIDDLEWARE_CLIENT_ID=gatekeeper
KC_MIDDLEWARE_CLIENT_SECRET=<Put the client secret you copied here.>
```

### Lets set up Portainer to authenticate via Keycloak
- Set up Portainer to work with keycloak: https://techwave.j2dk.in/portainer-sso-with-keycloak/

