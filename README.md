# Home Assistant Kubernetes Cluster

This repository contains a kubernetes cluster starter for a homeserver, and includes traefik ingress controllers for public and local access.

Included as default are the following containers:

* [Home Assistant](https://www.home-assistant.io/)
* [Filebrowser](https://github.com/filebrowser/filebrowser)

**Why Kubernetes?**

The purpose of this repository is theory! For me have a base to learn and test kubernetes, docker, and traefik, among other things with a real usable project.

## Quick Start

To deploy your cluster simply run copy `./kustomization.example.yaml` to `kustomization.yaml` and run `kubectl apply -k .`.

### Enabling Your App

By default your application will be deployment on three hosts:

* `homeassistant` - this will be the homeassistant installation
* `filebrowser` - the will be filebrowser installation
* `waffle` - main ingress route for applications. [Flame](https://github.com/pawelmalak/flame) is used on the root directory, and subdirectories can run other applications - for example, waffle/transmission for [transmission](https://github.com/linuxserver/docker-transmission)

Add `your_cluster_ip homeassistant filebrowser avalanche` to your /etc/hosts file, or alternatively if your router supports dnsmaqs `address=/crepe/filebrowser/homeassistant/your_cluster_ip`, to then access these services by hostname (where `your_cluster_ip` is the IP address of your kubernetes cluster)

Navigate to `http://filebrowser` in your web browser to now test the connection to filebrowser.

## Advanced Usage

This repository is made to be extended and patched. All custom resources and patches should go in the [/custom](./custom) directory.

Examples of these resources are in the [/custom/examples](./custom/examples) directory, and should be copied and modified if to be used. Patches should be configured accordingly, and go under `patchesStrategicMerge` in your kustomization.yaml file.

Some examples of using these patches:

### Setting up persistent storage for your pods

By default your pod will not persist data on termination. To do this, it is suggested you add a file in your `kustomization.yaml` underneath `patchStrategicMerge` to define a volume!

An example of setting up an NFS drive as a persistent can be found in [custom/examples/deployment.nfs-patch.yaml](./custom/examples/deployment.nfs-patch.yaml).

Read more about [kubernetes volume storage](https://kubernetes.io/docs/concepts/storage/) for information how to persist your data.

### Public Access

To set up public access (over the internet) you can add a patch to change the hostnames, and add a custom resource to set up a letsencrypt certificate.

You can use the [ingress patch](./custom/examples/ingress.public-patch.yaml) to change a hostname and add TLS. The [certification resource](./custom/examples/ingress.certificate.yaml) can be used to provision a certificate with [cert-manager](https://cert-manager.io/).

The [auth middleware](./custom/examples/middleware-auth.yaml) can be used to set up basic auth for your route(s).


