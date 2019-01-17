Marathon/Marathon-on-Marathon (MoM) Planning and Design

#  

Arthur Johnson, 

Solutions Architect, Mesosphere

[ajohnson@mesosphere.io](mailto:ajohnson@mesosphere.io) 

## Using Marathon, a Summary

Many environments implement ‘service marathon’ to segment workloads in their current production environments. It is via Marathon-on-Marathon (MoM) that is able to achieve high task count with segregation for workloads for their containerized work environment. 

Implementation details: 

Tasks are started via ‘service marathons’ and will exist in their own name-spaced environment consuming resources only available within that particular namespace. It is via this segregation that enables environments to achieve 1000s of tasks with isolation in their DC/OS environments. 

Within these unique ‘service marathons’ (MoMs) we are able to set variables in the service-marathon.json such as: (names have been changed to protect implementation specific details)

MOM_GROUP: "unique_mom_group",

MON_APP: "unique_app_per_group",

HOST_TARGET: "host-service-marathon.mesos"

These ‘service marathon’ instances are instantiated from the main Marathon, also referred to as the ‘Platform Marathon" and are reserved resources such as: 

"instances": 1,

      "cpus": 2,

      "mem": 8192,

      "disk": 0,

      "executor": "",

      "constraints": [],

      "uris": [

        "file:///docker.tar.gz",

        "file:///opt/confighost/logging/forwarder/forwarder.tar.gz"

Within these unique configuration parameters, customers are also able to set network segregation and individual host resources, such as: 

"network": "BRIDGE",

          "portMappings": [

            {

              "containerPort": 22,

              "hostPort": 0,

              "servicePort": 20406,

              "protocol": "tcp",

              "labels": {}

            }

          ],

          "privileged": false,

          "parameters": [

            {

              "key": "add-host",

              "value": "node-44a84216a939:1x.1xx.1x.1"

            },

            {

              "key": "add-host",

              "value": "node-44a84216626e:1x.1xx.1x.1"

            },

            {

              "key": "add-host",

              "value": "node-44a84216af0d:1x.1xx.1x.1"

{

              "key": "dns-search",

              "value": "mon-marathon-service.mesos"

            }

{... This list can continue adding 100s of agent hosts for use in this service marathon… }

A key feature here is that the service marathons are launched by the platform Marathon and will receive the same resource offer provisioning and service as other tasks within the greater cluster environment, while then additionally being serviced by their own scheduler within their individual domain. 

Another key feature in this ‘nested design’ is that service discovery, network allocation, and app-to-app connectivity is contained within a single isolated (soft) environment instead of co-mingling with all tasks running in the ‘cluster-at-large’. A caveat here is that if developers write apps with service discovery and configuration existing for one particular marathon, these apps need to be made aware of a different or new marathon, if they are moved between various service marathons. For example, let’s say an existing MoM reaches it’s limit of 8000 tasks (just speculative that this is the limit) and it is decided that 50% of these apps will move/migrate to a new MoM, these apps will need to be updated/re-tooled to become aware of the new namespace of that new MoM. This may seem tedious, but apps can be designed to self-discover the environment they are running from.. 

Within the individual Service Marathons (MoM) we also have the ability to set fine grained constraints, that are specific to that individual MoM: 

"env": {

        "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",

        "MON_GROUP": "someapp",

        "CASS_RPC_PORT": "13042",

        "CLUSTER_NAME": "theapp-PROD-C1-MM",

        "MON_LOC": "vc-ont-cass",

        "SSRE_GROUP_ID": "appcloud-core",

        "CASS_SEEDS": "1x.1xx.4x.1,10.1xx.2x.1,10.2xx.4x.1,1x.1xx.2x.1,10.1xx.1x.1,10.18x.1x.1",

        "ZABBIX_LISTEN_PORT": "10050",

        "MON_APP": "mmcassandraseed2",

        "CASS_SSL_STORAGE_PORT": "13044",

        "MODE": "FS",

        "ETCD_PIPE_ID": "beta-1",

        "MON_CONTACT": "ssredevops@customer.com",

        "AMPQ_IP": "10.2x.2x.1",

        "MON_SVC": "appcloud",

        "CASS_DC_PRIMARY": "OMH",

        "MMCASSANDRASEED1_HOST": "mmcassandraseed1-cass-dc8-appcloud-core.mon-marathon-service.mesos",

        "CASS_DC_SECONDARY": "PMN",

        "SSRE_INSTANCE_ID": "cass-dc8",

        "CASS_DC": "PMN",

        "AMPQ_PORT": "5671",

        "CASS_NATIVE_TRANSPORT_PORT": "13045",

        "ZABBIX_PROXY": "vc-mon-zabbix-proxy-dc8.mon-marathon-service.mesos.clustername",

        "SSRE_DOMAIN_SUFFIX": "mon-marathon-service.mesos",

        "CASS_RACK": "RACK-2",

        "MMCASSANDRASEED2_HOST": "mmcassandraseed2-cass-dc8-appcloud-core.mon-marathon-service.mesos",

        "CASS_STORAGE_PORT": "13043",

        "ETCD_TTL": "30",

        "MON_LOGLEVEL": "6",

        "ETCD_WRITE_INTERVAL": "20"

      },

## Design Considerations 

There are planning and design considerations while considering MoM implementations: 

* Consider dividing application workload between multiple Service-Marathons

* If a child service marathon goes down, all tasks within that service marathon are affected and may potentially require restart

* MoMs will run out of resources in highly consumed environments. It is recommended provisioning workloads between multiple MoMs in very busy environments 

By default, Marathon provides the following features for tasks survivorbility: 

* Marathon supports a high availability mode of operation by default. High availability mode allows applications to continue running if an individual instance becomes unavailable. This is accomplished by running several Marathon instances that point to the same ZooKeeper quorum. ZooKeeper is used to perform leader election in the event that the currently leading Marathon instance fails.

* Application groups: Applications can be nested into a n-ary tree, with groups as branches and applications as leaves. Application Groups are used to partition multiple applications into manageable sets

* Applications can have dependencies. If the dependencies are defined in the application specification, then Marathon keeps track of the correct order of action for starting, stopping and upgrading the applications.

* Dependencies can be expressed on the level of applications and on the level of application groups. If a dependency is expressed on the level of groups, this dependency is inherited by all transitive groups and all transitive applications of this group.

* Dependencies can be expressed either by absolute or by relative path.

* Group Scaling: A whole group can be scaled. The instance count of all transitive applications is changed accordingly

## Authorization and Access Control: 

Marathon currently only can support this level of segmentation while being deployed on DC/OS and taking advantage of finer grained access controls. This is done by creating advanced ACL groups in the native Marathon instance (Platform Marathon). By using Advanced ACL Groups you can control customized access to applications at app-team or individual user level. 

# Generic Design, Management, and Caveats for Marathon (MoM)

*A planning and Design Primer for Marathon Deployments*

## Design for Deploying MoM Instances 

DC/OS comes pre-packaged with a native Marathon instance ready to be installed and configured on-top of the Mesos layer within the DC/OS architecture. 

However, there may be needs to run a non-native instance of Marathon (within Marathon) with isolated roles, reservations, and security. 

To deploy a non-native Marathon, you will need a custom tarball from Mesosphere and installing it will be a custom configuration- the non-native tarball includes additional plug-ins to support secrets, auth, and fine grained access control. 

*The following are prerequisites for deploying a non-native Marathon*: 

* DC/OS and DC/OS CLI

* Private Docker registry for your DC/OS environment 

*The following are design considerations* for the cluster and your custom non-native Marathon implementation- some of these items are critical and if changes are desired they may require a cluster re-configuration (e.g. reinstall). 

* Create a service account for the non-native Marathon 

* Identify if permissions will be required- Permissions can only be assigned in a cluster deployed with "Strict Security Mode" defined and a Marathon Service Account will be created

    * Desiring permissions and having the cluster installed with security either disabled or permissively set will require reinstalling the cluster! 

    * Clusters configured with Security Mode set to disabled or permissive may still have a Marathon Service Account, but these service accounts will not have "permissions" (tacit service actors w/o actual permissions)

* Decide whether Mesos resources are statically or dynamically assigned for the non-native Marathon 

* Decide whether stateful services are required in the environment. Stateful services will drive other requirements such as:

    * Dynamic reservations with labels

    * Persistent volumes 

    * Access to dedicated resources wherever the task may run in the cluster (e.g. volumes are cluster accessible)

*Design decisions for the Marathon config.json*:

There are some choices to be made prior to installing the non-native Marathon, there are variables that will need to be set reflecting the purpose and intention of the installed non-native Marathon. 

* Non-native-Marathon: the name of the newly installed Marathon framework 

* Service-account-id: id for the non-native Marathon 

* Secret-name: secret for the Marathon (if configured) 

* myRole: Mesos-role 

* Repo: the private Docker repo 

* Tag: Docker tag 

* Linux-user: the user which the framework will be run (e.g. nobody, core, centos) 

## Tuning and Workload Considerations for MoM

There are quite a few knobs and switches that can be utilized in tuning for Marathon. Here are some aspects outlined by the perspective of end-users and application support. 

### *Application Definition*

In the end-users MoM environment, applications run as tasks that are scheduled by Marathon and these tasks run on nodes (agents). Within the Mesos construct, these applications are frameworks, and these can be apps such as Marathon, Cassandra, etc. Marathon schedules individual tasks to run on slave nodes and these tasks can be run in a variety of pre-defined conditions. The slave nodes which are running your tasks, orchestrated by Marathon, can be tagged based on rack, type of storage, host parameters, etc. These constraints are used when the tasks (containers) are launched. 

### *Application Scalability* 

Scaling apps up or down can be accomplished with the Marathon UI. Initially tasks are started and configured by the JSON definitions that describe how they will run. The JSON definitions configure things like: repository to load from, resources for the app, number of instances to start, commands to execute. In scaling, Marathon will distribute these containers (tasks) on slave nodes based on specified parameters. Additionally, you can also have auto-scaling enabled and multi-tiered scaling defined by using application groups. 

### *Auto-Scaling*

Marathon (MoM) continuously monitors the number of instances of tasks/containers running and if one of them fails it will reschedule that task on another slave node. Auto-scaling can also be achieved by using resource metrics and will allow the application to scale as demand increases. 

### *High Availability*

Containers and tasks can be scheduled without constraints, or, conversely with constraints pinning apps to individual nodes as needs may require unique resources on a particular node (e.g. access to that floppy drive). You can also define constraints such that app A resides on Node X and app B resides on Node Y and the two shall never cross. A fundamental principle of high availability is: you should have at least as many slave nodes as containers/tasks you want to run. Or, the ability to handle the workload running on one node in the event it suffers a failure. Then, think about how many nodes may fail within the cluster-- build the environment accordingly (support just a single node failure, multi-node, a whole rack, a region, an entire data center, etc.). It’s important to note that high availability for both Mesos and Marathon is supported using ZooKeeper; ZooKeeper provides the mechanism for leader election for both Mesos and Marathon and maintains cluster state. 

### *Load Balancing*

In a DC/OS deployment, users may choose to provide application load balancing via Marathon-LB. Marathon-LB is a pre-packaged option within DC/OS and can be deployed in a single click. With load balancing, host ports can be mapped to multiple container ports thus serving as a front-end for other applications or end-users within the environment. 

### *Health Checks*

Health checks can be done in a variety of manners. Some checks can be specified to be run against the application tasks-- health check requests are available in a variety of protocols including HTTP, TCP, etc. Monitoring of application and framework endpoints can easily be scripted and added to external monitoring systems. 

### *Storage*

Persistent storage can be achieved in two different manners: local persistent volumes and external storage such as AWS EBS. If local persistent storage is required, then apps/tasks should be defined to start/restart on the same node (using a constraint), using the same previously configured/used volume. 

### *Networking*

Networking in the DC/OS MoM environment can be configured either in host mode or bridged mode. In host mode, host ports are used by apps/containers. This, while workable, may lead to port conflicts on a particular host. In bridge mode, the container ports are bridged to host ports using port mapping. The host ports can be dynamically assigned at the time of app/container deployment. 

### *Service Discovery*

In each MoM, there will be a unique name space, using the name of the MoM in that namespace. Service discovery within a MoM (DC/OS for that matter) are done via named "VIPs" which are auto-generated DNS records that are associated with IPs and ports of applications/containers. These DNS records are automatically assigned by Mesos-DNS -- Optional VIPs can be created and requests that the VIPs be load balanced can also be achieved. 

## Operational Considerations - Upgrades and Maintenance 

There are several operational considerations prior to deploying your non-native Marathon that need to decided. The non-native Marathon instance should reflect the needs of the group in which is deployed for; this will include resources assigned, the nature the resources are assigned (static or passive) and the users that are allowed access to the non-native Marathon. 

Operationally speaking, you will need to create DC/OS users for your non-native Marathon and then grant them access to their individual Marathon instance. End-users will be able to access their Marathon instance (the UI) by accessing the system at: 

*http://<master-public-ip-addr>/service/<service-name>* (where service-name is the name of your non-native Marathon)

End-users access your non-native Marathons are considered ‘tenants’ and the area in which they access is their segmented private tenant area. From here you may decide to implement quotas, different reservation types, and additional Mesos roles. By implementing reservations, you are creating a service level for your end-users and guaranteeing that resources are available for them within their separate environment.  

*Upgrades and Maintenance*: 

There are as many choices in performing upgrades and care must be taken if the environment is implemented in a HA (highly available) setup. If the environment is not highly available, the end-users must be made aware that their task state will be lost within Marathon. 

Upgrades in general should be prefaced with backing up ZooKeeper state prior to upgrading to be able to downgrade in the event that is required. ZooKeeper cannot be backed up while tasks are actively running so it is sufficient to create a tar of the /var/lib/dcos/exhibitor directory (this location will be dependent upon the version of DC/OS!) 

*Upgrading a non-HA Marathon*: 

* Stop tasks and tear down the existing Marathon (remove) 

* Install the new version of Marathon, like an initial installation 

* Start the new version and monitor logs 

Upgrading a HA Marathon: 

Because HA Marathon is Marathon + N Marathons, you will stop and tear down all instances of Marathon except for one running Marathon. This Marathon will become the leader. Another consideration is how many tasks will this surviving Marathon now have to handle? Make sure adequate resources are available in order to accommodate the additional workload! 

* Remove the existing Marathons except one (to be leader)

* Install the new Marathon on a Master Node that has the old stopped version 

* Start the new instance of Marathon 

* Stop the last node running the deprecated / older version, remove, etc. The new version of Marathon will now become the leader 

* Monitor logs to make sure there are no errors or failures 

* Repeat on other nodes as necessary

* Start all other instances of Marathon and make sure they build a quorum 

## Conclusion: Caveats and Known Issues

One caveat that needs to be considered during deployment is that when choosing static reservations the agents on nodes need to be stopped and restarted. This will result in all tasks running on a particular agent to be killed (lost). Prior to static reservation initiation tasks should be moved to other nodes which will not be reserved for the non-native Marathon. 

When you choose dynamic reservations, guarantees that resources are readily available are not possible. If there aren’t any or enough resources at the time users start tasks, they will be presented to their framework as they are released from other tasks and made available. 

Another known issue that is common in mis-configured or poorly planned environments is "Stuck App or Pod" in deployments. Apps and pods fail to deploy when there aren’t sufficient resource offers to fulfill the needs of the application/pod. Sometimes there aren’t enough resources currently available, other instances of this might be caused when there is too much load on the system and care was not given to the longevity (duration) of tasks and their required resources. As other tasks complete, enough resources may become available to begin running these stuck deployments. 

A common caveat that does not work well in web-scale environments is when an app requires a specific host port. In general, this is not recommended as your app will depend on a particular host port which in turn will constrain scheduling. Marathon can only use offers that are required for the app, if they are available for the app. And, by default, all resources (ports) are not offered by the agent. For example, if your app requires port 1024, then it has to be specifically made available from an agent that will run the app. 

