# Home Assistant Kubernetes Cluster

This repository contains a kubernetes cluster starter for a homeserver, and includes traefik ingress controllers for public and local access.

Included as default are the following containers:

* [Home Assistant](https://www.home-assistant.io/)
* [Filebrowser](https://github.com/filebrowser/filebrowser)

**Why Kubernetes?**

The purpose of this repository is theory!

## Quick Start

To deploy your cluster simply run copy `./kustomization.example.yaml` to `kustomization.yaml` and run `kubectl apply -k .`.

Add the following hostsnames to your dnsmasq or /etc/hosts file to map to your cluster IP: homeassistant, filebrowser.

### Setting up persistent storage for your pods

By default your pod will not persist data on termination. To do this, it is suggested you add a file in your `kustomization.yaml` underneath `patchStrategicMerge` to define a volume!

An example of setting up an NFS drive as a persistent can be found in [patches/example/nfs_volume.yaml](./patches/example/nfs_volume.yaml).

Read more about [kubernetes volume storage](https://kubernetes.io/docs/concepts/storage/) for information how to persist your data.

### Enabling Home Assistant

When trying to access home assistant for the first time you will receive a 400 Bad Request Response. This is because, [by default](https://www.home-assistant.io/integrations/http/) home assistant blocks access via proxies, so we'll need to modify the configuration.yaml to allow access to it. We can do this automatically by running the `sh ./scripts/enable_hass_ingress.sh`

