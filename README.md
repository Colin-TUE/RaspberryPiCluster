# RaspberryPiCluster

Repo containing the resources, links, and other stuff I used to setup my own K8s Cluster using Raspberry Pis

- [RaspberryPiCluster](#raspberrypicluster)
  - [Materials](#materials)
  - [K3s Cluster setup](#k3s-cluster-setup)
    - [Installation steps](#installation-steps)
  - [K3s Applications](#k3s-applications)
    - [0. Cluster Dashboard](#0-cluster-dashboard)
      - [Accessing Dashboard through Master Node](#accessing-dashboard-through-master-node)
    - [1. Echo test applciation](#1-echo-test-applciation)
    - [2. Raspberry Pi Monitor](#2-raspberry-pi-monitor)
    - [2.1 Hooking the Monitor to Grafana](#21-hooking-the-monitor-to-grafana)
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

Follow the steps in [this K3s tutorial](https://docs.k3s.io/installation/kube-dashboard) for direct installation and [this guide](https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard) for installation using Helm charts.

The commands to execute when setting up the Dashboard via Helm and with a NodePort:

```bash
# Create seperate namespace
kubectl create namespace kubernetes-dashboard

# Create admin user for the dashboard
kubectl create -f ./dashboard/dashboard.admin-user.yml -f ./dashboard/dashboard.admin-user-role.yml

# Add repo to find the helm chart
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

# Install dashboard with service port and memory limit
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --namespace=kubernetes-dashboard --set=service.externalPort=8080,resources.limits.cpu=200m
```

There are two ways to access the K8s Dashboard:

1. via K8s proxy: `kubectl proxy`
2. via a port forward: `kubectl port-forward service/kubernetes-dashboard 9001:8080 --namespace kubernetes-dashboard`

Open the Dashboard in your browser by navigating to `https://127.0.0.1:9001` and then provide the admin token to authenticate. The admin token changes over time and can be (re)generated by exeucting `sudo k3s kubectl -n kubernetes-dashboard create token admin-user`.

#### Accessing Dashboard through Master Node

In case you want the dashboard to be accesable without the `kubectl proxy` or `kubectl port-forward`, then follow the below steps.

> Be aware though that there is a good reason why the dahsboard uses the ClusterIP by default and is not exposed outside the cluster.

```bash
# Install Ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/baremetal/deploy.yaml

# Change port type for the dashbaord service
kubectl edit service -n kubernetes-dashboard
> 'Opens vim and need to apply the following change:'
> type: ClusterIP
> # to 
> type: NodePort

# Inspect the services and find the node port, in this case 30342
kubectl get services -n kubernetes-dashboard
> NAME                   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
> kubernetes-dashboard   NodePort   <internal IP>   <none>        8080:30342/TCP   95m
```

Open the Dashboard in your browser by navigating to `https://<IP to master node>:<node port>`.

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

```bash
# Setup MQTT broker
helm repo add k8s-at-home https://k8s-at-home.com/charts/
kubectl create namespace mqtt
helm install mosquitto k8s-at-home/mosquitto -n mqtt
```

Then setup the Raspberry Pi monitoring (mostly taken from the [tutorial repo](https://github.com/alexortner/kubernetes-on-raspberry-pi/tree/main/apps/4_raspiMonitor)).

```bash
kubectl create namespace raspi-monitor
kubectl create -f ./raspberrypi-monitoring/daemonset_raspiMonitor.yaml

# Forward the port to make the data available for a MQTT client
kubectl port-forward service/mosquitto 9002:1883 --namespace mqtt
```

In this case I used the docker images from the tutorial, but in case you want to build your own:

```bash
cd raspberrypi-monitoring
docker build -t <repo>:raspi-monitor -f Dockerfile .
docker push <repo>:raspi-monitor
```

Then change the following in [raspberrypi-monitoring/deamonset_raspiMonitoring.yaml](./raspberrypi-monitoring/daemonset_raspiMonitor.yaml):

```yaml
    containers:
        - name: raspi-monitor
          image: <repo>:raspi-monitor
```

To verify that the monitoring is publishing the values, one can use the [MQTT Explorer](https://mqtt-explorer.com/). To connect the explorer to the cluster, another port forward needs to be set up: `kubectl port-forward service/mosquitto 9002:1883 --namespace mqtt`.

### 2.1 Hooking the Monitor to Grafana

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
- [K8s Dashboard setup](https://docs.k3s.io/installation/kube-dashboard)
- [K8s Dashboard Helm chart](https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard)
- [Ingress controller for bare metal clsuters](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal-clusters)
- [K8s port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
- [Docker images form the tutorial](https://hub.docker.com/r/tingelbuxe/k3s-meetup/tags)
- [MQTT Explorer](https://mqtt-explorer.com/)
- [MQTT tools - most of them are outdated](https://www.hivemq.com/mqtt-toolbox/)
