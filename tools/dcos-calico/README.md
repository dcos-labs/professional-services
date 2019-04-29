# dcos-calico

## Introduction

DC/OS has support for CNI pluginsand Data Services (based on the DC/OS SDK) are able to use this CNI-Based virtual networks: https://docs.mesosphere.com/1.12/networking/SDN/cni-plugins/)

If you want use Calico, you can start out testing the community supported packages of etcd and calico. The guide for that is: https://docs.projectcalico.org/v2.6/getting-started/mesos/installation/dc-os/framework I tested these packages, but they were failing to deploy in DC/OS Strict mode and are created for demo purposes anyway.

## Setup Guide

To keep the rule design simple and powerful, each application should get its own profile and respective role named after the application.

1. [Setup Calico](./calico-secure)
1. [Test: Simple Webserver](./webserver)
1. [Test: VIPs](./vip)
1. [Test: Marathon-LB](./marathon-lb)
1. [Test: Edge-LB](./edge-lb)
1. [Test: Spark + Kafka](./spark)
1. [Test: Elastic](./elastic)

### Documentation

- [Mesosphere Enterprise DC/OS](https://docs.mesosphere.com/)
- [Calico Policy](https://docs.projectcalico.org/v2.4/reference/calicoctl/resources/policy)
