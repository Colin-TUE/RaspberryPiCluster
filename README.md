# RaspberryPiCluster

Repo containing the resources, links, and other stuff I used to setup my own K8s Cluster using Raspberry Pis

- [RaspberryPiCluster](#raspberrypicluster)
  - [Materials](#materials)
  - [K3s Cluster setup](#k3s-cluster-setup)
    - [Installation steps](#installation-steps)
  - [K3s Applications](#k3s-applications)
    - [0. Cluster Dashboard](#0-cluster-dashboard)
    - [1. Echo test applciation](#1-echo-test-applciation)
    - [2. Raspberry Pi Monitor](#2-raspberry-pi-monitor)
    - [3. PiHole setup](#3-pihole-setup)
  - [References](#references)

## Materials

The materials I used for this cluster are:

- 1x Raspberry Pi 3 Model B v1.2 2015 for the control node.
- 3x Raspberry Pi 3 Model B v1.2 2015 for the compute nodes.
- 1x Raspberry Pi 3 Model B+ 2017 for a compute node with different specs.
- 1x unmanaged switch for the networking.
- 5x 32 GB MicroSD cards (one per Raspberry Pi).
  - Recommended minimum is 8 GB.
  - Raspberry Pi 3 Model B maximum used to be 32 GB, currently is unlimited ([Getting Started Documentation](https://www.raspberrypi.com/documentation/computers/getting-started.html#sd-cards)).
- ...
- a bunch of Micro USB cables and adapters for power routing.
  - or use 1 USB hub with many USB ports (preferable)
- a bunch of network cables (CAT5E) for network connectivity.

## K3s Cluster setup

My setup mostly follows the K3s setup including the Raspberry Pi monitoring tool (reference is marked in bold below).

The reason for following this specific setup is that I prefer to use a K3s cluster over a K8s cluster. K3s is meant for resource constraint edge nodes, which Raspberry Pi's are. I also noticed that most of the K8s setups use MicroK8s instead of K8s directly. Although I expect it to work just fine, being closer to what the software is meant for is better for learning and playing around.

### Installation steps

Follow the steps from [this guide](https://github.com/alexortner/kubernetes-on-raspberry-pi/tree/main/setup).

Things done differently:

- Set up each Raspberry Pi with a static IP address [docs](https://www.makeuseof.com/raspberry-pi-set-static-ip/). If you want to connect to it via your router, make sure it is in the same subnet.
- Before installing K3s, I ran `sudo apt-get update` and `sudo apt-get upgrade` to make sure all latest packages are installed.
- I use a local kubeconfig file instead of the default one in my home folder. A local file can be specified on the context setting using the `--kubeconfig .kubeconfig` arguments or by setting the `export KUBECONFIG=<path>` environment variable.
  - `export KUBECONFIG=.kubeconfig`
  - `kubectl config use-context k3s`
- Applied some memory limits to the K3s server on the master node, since it was runnig out of RAM and swap and becoming unresponsive.
  - Noticed that the `kubectl` command on the client was becoming unresponsive and so checked the the utilization of the master node(using `htop`). Which used 100% of its swap. The checked the difference between having all workers connected and all of them disconnected.
  - `sudo systemctl set-property k3s.service MemoryHigh=75% MemorySwapMax=50M`
  - `sudo systemctl restart k3s.service`

## K3s Applications

### 0. Cluster Dashboard

TBW

### 1. Echo test applciation

Based on [this tutorial](https://github.com/alexortner/kubernetes-on-raspberry-pi/tree/main/apps/1_helloRaspi).

Run the following commands:

```bash
# Simple statement that logs every two seconds:
kubectl run hello-raspi --image=busybox -- /bin/sh -c 'while true; do echo $(date)": Hello Raspi"; sleep 2; done'
> pod/hello-raspi created

# Check the logs:
kubectl logs hello-raspi -f
> Fri Dec 30 10:18:47 UTC 2022: Hello Raspi
> Fri Dec 30 10:18:49 UTC 2022: Hello Raspi
> Fri Dec 30 10:18:51 UTC 2022: Hello Raspi
> ...

# clean up the pod
kubectl delete pod hello-raspi
> pod "hello-raspi" deleted
```

### 2. Raspberry Pi Monitor

Based on [this MQTT broker tutorial](https://github.com/alexortner/kubernetes-on-raspberry-pi/tree/main/apps/3_mosquittoMQTT) and [this raspi monitor tutorial](https://github.com/alexortner/kubernetes-on-raspberry-pi/tree/main/apps/4_raspiMonitor).

TBW

### 3. PiHole setup

TBW

## References

- [3D Printable Cluster Case](https://www.thingiverse.com/thing:1573414)
- [Setup using MicroK8s](https://ubuntu.com/tutorials/how-to-kubernetes-cluster-on-raspberry-pi#1-overview)
- [Setup bramble and networking](https://www.raspberrypi.com/tutorials/cluster-raspberry-pi-tutorial/)
- [Setup MicroK8s after bramble is setup](https://ubuntu.com/tutorials/how-to-kubernetes-cluster-on-raspberry-pi#4-installing-microk8s)
- [K8s setup for Raspbian](https://github.com/sonujose/kubernetes-raspberrypi)
- [K3s setup with a GPU node](https://mitchmurphy.io/k3s-raspberry-pi/)
- [__K3s setup including basic monitoring application__](https://github.com/alexortner/kubernetes-on-raspberry-pi) & [article](https://medium.com/thinkport/how-to-build-a-raspberry-pi-kubernetes-cluster-with-k3s-76224788576c)
- [Raspberry Pi static IP config](https://www.makeuseof.com/raspberry-pi-set-static-ip/)
- [Kubeconfig file parameters](https://www.nathannellans.com/post/kubernetes-using-kubectl-with-kubeconfig-files)
- [`systemctl` man page](https://www.man7.org/linux/man-pages/man1/systemctl.1.html)
- [`systemctd.resource-control` man page](https://www.man7.org/linux/man-pages/man5/systemd.resource-control.5.html)
