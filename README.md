# marlowe-deploy

## Hetzner based deployment of Marlowe

This repo contains code which provisions a NixOS based server on Hetzner bare metal machine and deploys Marlowe services on it. All the Marlowe services are deployed directly as system level service using this setup.

### Prerequisites

#### API authentication

In order to setup the server, we need an Hetzner robot API access. The API user/password should be configured under user settings:

  * top right corner
  * Settings
  * on the main screen accordion "Web service and app settings"
  * First tab "Webservice / app user"

The new credentials will be sent to an admin user account so please be prepared that the admin is available to share the credentials ;-)

After you receive the credential you can set them in the ./hetzner/auth-config.nix file:

```shell
# agenix is configured through `./secrets.nix` file
$ agenix -e ./hetzner/auth-config.nix
```

#### Configuring the new machine

Before we can trigger the provisioning script we have to update the machine configuration. SSH into the rescue machine and copy relevant information from the `ip addr` into our `./hetzner/config.toml` file.

After this operation we can trigger the provisioning script:

```shell
$ initialize-hetzner
```

## Hetzner machine updates

In order to update the machine probably you want to update some input in the flake.nix or only in the flake.lock:

```shell
$ nix flake update marlowe-docs-website
```

And then you can redeploy the machine:

```shell
$ redeploy-hetzner
```

### Speeding up the deployment

In order to speed up the deployment please login into the machine to your user account, setup the ssh keys and then clone this repo and follow the usual deployment steps. Deploying from the machine itself is **much** faster than deploying from your local machine.

