# Waffle - Home Server

This repository contains a kubernetes cluster starter for a home server, and includes traefik ingress controllers for public and local access.

The sister project, [home-server-ansible](https://github.com/drinkataco/home-server-ansible) allows you to provision a file server and kubernetes cluster, using k3s.

Services includes by default include [Home Assistant](https://www.home-assistant.io/), [Filebrowser](https://github.com/filebrowser/filebrowser), [Flame](https://hub.docker.com/r/pawelmalak/flame), [Transmission](https://z.shw.al/transmission/web/)

## Contents

<!-- vim-md-toc format=bullets max_level=4 ignore=^Contents$ -->
* [Quick Start](#quick-start)
  * [Configuration](#configuration)
  * [Access](#access)
* [Advanced](#advanced)
  * [Kustomization](#kustomization)
  * [Customising with Patches](#customising-with-patches)
    * [Basic Auth](#basic-auth)
    * [Volumes](#volumes)
    * [Internet Access](#internet-access)
    * [HTTPS](#https)
<!-- vim-md-toc END -->

**Why Kubernetes?**

The purpose of this repository is theory! For me have a base to learn and test kubernetes, docker, and traefik, among other things with a real usable project.

## Quick Start

Copy the `overlays/example` directory with a name of your choosing, for example `overlays/your-cluster`.

Install all dependencies with `kubectl kustomize --enable-helm ./helm | kubectl apply -f -` (or `make dependencies`). If you are using [k3s](https://k3s.io) as your kubernetes distribution, make sure you have disabled traefik `--disable=traefik`, so we can install and manage traefik here.

Deploy your cluster with `kubectl kustomize overlays/your-cluster | kubectl apply -f -` (or `ENV=your-cluster make`)

### Configuration

You should add a [volume](https://kubernetes.io/docs/concepts/storage/volumes/) to each pod to persist data. Read the [volumes](#volumes) section to see an example of adding a volume patch to your overlay.

Several containers need some extra configuration to work through our architecture. Homeassistant, for example, requires you to enable reverse proxy access by setting `http.use_x_Forwarded_for: true` and `http.trusted_proxies[] = '10.0.0.0/8'`, as defined in their [documentation](https://www.home-assistant.io/integrations/http/#reverse-proxie).

### Access

You should add the following to you `/etc/hosts` file to access your cluster - with the IP address being the location of your cluster.

```
127.0.0.1 homeassistant filebrowser waffle
```

Alternatively, you could add `address=/crepe/filebrowser/homeassistant/your_cluster_ip` (where your_cluster_ip is the IP of your kubernetes cluster) to your `dnsmasq` config for network-wide DNS.

You can then access the services from your web browser:

- [http://waffle/](http://waffle/) - main route and ingress for most services
- [http://filebrowser/](http://filebrowser/) - [filebrowser](https://github.com/filebrowser/filebrowser) service
- [http://homeassistant/](http://homeassistant/) - [homeassistant](https://www.home-assistant.io/) automation service

## Advanced

### Kustomization

The file `kustomization.yaml` in your overlay directory shows all the resources that will be provisioned, and any patches that you can apply.

Example patches include HTTPS certificates, public hostnames, and NFS volumes. It is worth to have a look around these files and read the comments to see what you can modify!

### Customising with Patches

Several patches and extra config is provided in [./overlays/example/](./overlays/example). These instructions assume you have copied this example config into `./overlays/your-cluster`

#### Basic Auth

1. Generate a htpasswd secret for use with the middleware. Read the comments for `secret-basic-auth` under `secretGenerator` in `./overlays/your-cluster/kustomization.yaml`
1. To enable basic auth for a service uncomment the middleware named `basic-auth` in `/overlays/your-cluster/patches/ingress/custom/main.yaml`
1. Find and enable the patch file in your `kustomization.yaml` file
1. Reapply your cluster config - `ENV=your-cluster make apply`

#### Volumes

1. Modify the `./overlays/your-cluster/patches/volumes/` for the pod you want to attach a volume to. An example for an NFS volume is provided by default.
1. Find and enable the patch file in your `kustomization.yaml` file
1. Reapply your cluster config - `ENV=your-cluster make apply`

#### Internet Access

1. You must have a registered Domain and it must point to the public IP of your kubernetes cluster - accessible over port 80 and 443.
1. Update the `Host()` rule in the traefik `IngressRoute`. For example, in `./overlays/your-cluster/patches/ingress/custom/homeassistant.yaml` replace the value is `Host()` with `homeassistant.yourwebsite.org` - remember, this value must be enclosed in backticks (\`)
1. Find and enable the patch files in your `kustomization.yaml` file
1. Reapply your cluster config - `ENV=your-cluster make apply`

#### HTTPS

Certificates are provisioned and managed with [Cert-Manager](https://cert-manager.io/)

1. Enable the `certificate/issuer.yaml` under `resources` in your kustomization.yaml file.
1. In this file you must provide your email address in `spec.acme.email`. The issuer used by default is [letsencrypt](https://letsencrypt.org/)
1. Each service has its own certificate in `certificate/<service name>.yaml`. You should change the values in `spec.commonName` and `spec.dnsNames[]` to match your DNS hostnames
1. Find and enable the resource and patch files in your `kustomization.yaml` file
1. Reapply your cluster config - `ENV=your-cluster make apply`

**BONUS #1** - middleware exists, named `secure-headers` for all `IngressRoutes`, enabling certain HTTPS features such as HSTS. This middleware should be enabled in your `./overlays/your-cluster/patches/ingress/custom/<service name>.yaml`.

**BONUS #2** - you can force traefik to redirect port 80 requests to 443. See `helmCharts[name=traefik].valuesInline.additionalArguments` [here](./helm/traefik/kustomization.yaml).

