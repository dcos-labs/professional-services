![image alt text](image_0.png)

**Migrating Applications in Mesos - DC/OS** 

Rev 1.0 

*Arthur Johnson*

*Solutions Architect, Mesosphere*

*ajohnson@mesosphere.io*

# The Beginning: DC/OS as a Deployment System and Execution Platform

## A Deployment System

Building or migrating apps to a DC/OS environment can consider the new platform as both a deployment system and as an Execution Platform. By leveraging DC/OS, operators can put simple applications that test the durability of being within containers, in a DC/OS framework which can then be dynamically managed across an entire cluster. To take a simple app which was deployed on a physical or virtual machine and then deploy it in a distributed architecture, such as, DC/OS offers an entire new world of possibilities which we’ll investigate in this paper. 

In traditional deployments, apps use static configuration descriptions while in DC/OS each framework holding applications can be a recipe or set of roles describing how the applications should utilize the underlying resources within a given / configured cluster. The framework will include all the information and logic to install, start, monitor, and use an application. This change gives the app resiliency over it’s static configuration which would lead to time-intensive management changes affecting application run-time and availability. Applications in a framework will follow the same deployment pattern, for example, a web server, then a single framework can manage them all via an orchestration element such as Marathon. 

Since each framework is a live running program itself, it can make decisions on demand reacting to changing workloads and cluster conditions. As the environment changes, so can the deployment mechanism and run-time state of an application. And, since the framework deployment system runs constantly, it can notice and adapt to failures in real-time, automatically starting new services as previous ones fail or incur errors. 

## As an Execution Platform

DC/OS can also be an execution platform-- rather than creating 3rd party PaaS solutions and creating spoke’d clusters, for each ‘big data’ analysis technology, you can have DC/OS manage it all as a single cluster, or as an application running within a single cluster. With a DC/OS cluster as the foundation, you can easily launch whatever frameworks you require to provide whatever functionality is needed, either now, on demand, or as new needs and requirements arise. 

Applications that run within DC/OS, on Mesos, are called frameworks. Frameworks themselves have two parts: the controller portion, which is called the scheduler and the worker portion which is called the executor. 

Frameworks are run on DC/OS by the scheduler (e.g. Marathon). A scheduler is a process that can speak the Mesos protocol, such as Marathon and gather the required resources to run a particular application, or set of applications. When a scheduler first starts, it connects to the Mesos layer within DC/OS so it can utilize the clusters resources. As a scheduler runs, it makes additional requests to Mesos to launch executors as the need arises. The complete flexibility for a scheduler is what makes the DC/OS platform so powerful-- the schedulers can launch tasks based on resource availability, changing workloads, or even, external triggers.  

When a scheduler needs to do work, it will launch an executor. The executor is the schedulers worker for a given framework. The scheduler then decides to send one or more tasks to the executor which will work on these tasks independently. The executor will send status updates to the scheduler when the task is complete, or when errors occur. 

By default, DC/OS - Mesos slave agents/processes will auto-detect the CPUS, memory, and disks on the machine and expose them all to Mesos masters, available to any role. The slave will reserve 1GB, or 50% of detected memory, whichever is smaller. Likewise, it will reserve 5GB or 50%, or whichever is smaller for available disks. 

# Porting an Existing Application to Mesos 

Using existing frameworks, such as Marathon, it is possible to easily port some legacy apps to DC/OS. Most applications in common modern data centers fall into two categories: a) applications which respond to requests, and b) applications that perform actions at particular times. 

A simple example app that easily ported to DC/OS is an HTTPd server, or an HTTP based application. In migrating apps like this, you can take immediate advantage of DC/OS’s scalability and resilience ending up with a system that can automatically heal and recover from common failure scenarios. Besides improving the resiliency of an application, we can also improve the isolation of the application’s components. This alone will help to achieve a better quality of service without having to build this directly on virtual machines that will have their own dependencies and complexity. Marathon can be used to host the HTTP-based application and can therefore offer lots of additional functionality that wouldn’t normally be possible in the app without a lot of re-engineering effort. 

By leveraging Marathon as the deployment platform, you have the ability to port your app to a powerful PaaS type of infrastructure all contained within the DC/OS environment. Marathon is a native application included with DC/OS and can be used for scheduling most applications or tasks within the environment. 

Within the features of Marathon, we find the following: 

* All backend processes will be able to run on any machine, and our Mesos framework will handle spinning up new instances of the backend when our existing instances fail or incur an error forcing a restart 

* We can host static assets, fast-responding endpoints, dangerous endpoints, and API capabilities in different containers to improve isolation

* We can make it easy to deploy a new version, or to rollback, and to do so in a matter of seconds 

* We can implement auto-scaling, for scaling up or down as needs increase (or decrease) for the application 

With Marathon, you are able to specify a command line execution, or a Docker image, defining the number of CPUs, amount of memory, and the number of instances it will start for the task with the pre-defined resources. 

Marathon itself, can be configured to run in a highly-available fashion by configuring 2 or more instances, sharing some basic parameters such as: 

* --master <instance_name>

* --framework-name

* --zk <instance_name>

* --https-port <port#> 

A simple example of a ported HTTPd-based application to DC/OS would be to host your environment configuration and content files via a container such as "SimpleHTTPServer" (Python based). This application will serve the files in the directory from which it was started. For example: 

**python -m SimpleHTTPServer 8000** 

//Run a simple python httpd server answering on port 8000 

To make the association as to how this app will run from within Marathon, on DC/OS, it is fairly simple-- your application will run as "**marathon.httpsimpleserver.com:8000**"

## Setup the Environment

The first step in setting up this environment is to create a simple JSON descriptor for the application: 

**{ **

**	"cmd": "python -m SimpleHTTPServer 21500",**

**	"cpus": 0.5,**

**	"mem": 50,**

**	"instances": 5,**

**	"id": "simpleHTTPServer",**

**	"ports": [21500],**

**	"requirePorts": true**

**	"uris": [**

**		"http://theapproplocationserver/uri/with/python.tar.gz"**

**	]**

**}**

Once the app description has been saved in JSON, and started as a task via Marathon, it is them possible to query the running application within the system: 

**curl marathon.example.com:8000/v2/apps/simpleHTTPServer |python -m json.tool **

When queried, the returning data will be the exact same data we got when we created the application, that is, what is in the JSON description for the application. However, the difference now is that our application has had time to start running and we can see information on the tasks running for the application: 

**"tasks": [**

**	{**

**		"appID": "/simpleHTTPServer",**

**		"host": "10.10.1.10",**

**		"id": "simpleHTTPServer.734557b5-0ae7-11e5-baa7-567847afe9899",**

**		"ports": [ 21500 ],**

**		"stagedAt": "<time-date-stamp>",**

**		"startedAt": "<TD-Stamp>",**

**		"version": "<TD-Stamp>""**

**	}**

**],**

**"tasksHealthy" : 1,** 

// ID: is the Mesos-TaskID. This is constructed by adding a unique per-task UUID to the application's ID which allows for convenient discovery with the Mesos UI or CLI 

### Scaling the application: 

If you would like to scale the application, that is possible by both the DC/OS UI and by implementing a curl command to scale the application: 

**curl -X PUT -H 'Content-Type: application/json' marathon.example.com:8080/v2/apps --data '{"instances": 10}'**

Like-wise you can scale it down by defining the required number of 'instances' for the instances definition. 

### Constraints (App Placement) 

Constraints can be supported on where the application is launched and the associated resources required to run the app. These constraints can be driven either by the hostname of the slave, or any slave attribute (Mesos defined). Constraints are provided in an array to the application; each constraint is itself an array of two or three elements, depending on whether  there's an argument. 

Constraints in use today, in common DC/OS deployments: 

* **GROUP_BY**

    * Use this to spread your application equitably across hosts which have a matching attribute: 

	**"constraints": [["hostname", "GROUP_BY"]]** 

* **UNIQUE** 

    * Every instance of the application has a different value for the UNIQUE definition. 

	**"constaints": [["hostname", "UNIQUE"]]**

* **CLUSTER** 

    * Allows apps to be grouped together by some definition, and there must be a configured option to the definitions, such, architecture, rack num, location, hardware configuration, etc. 

	**"constraints": [["cpu_arch", "CLUSTER", "x86"]]**

* **LIKE** 

    * Applications on run on slaves that have the same attribute, they are, alike / like 

	**"constraints": [["cpu_arch", "LIKE", "m4.xlarge"]]**

* **UNLIKE** 

    * A complement of LIKE, allows to avoid running on certain slaves that are not alike. 

	**"constraints": [["dmz", "UNLIKE", "true"]]**

* Additionally, you can also group constraints building complex lists of definition of where, how, and isolation for the application: 

	**"constraints": [["dmz", "UNLIKE", "true"],**

**					[hostname", "GROUP_BY",]]**

## Running Dockerized Applications: 

DC/OS comes already prepared to run Dockerized applications, and calling such applications is simply done by calling the container (pull request), and input the details for the app JSON. 

Running Dockerized applications allows for legacy apps to be first Dockerized, then imported and run in such a contained state which will carry over any of their required configuration information from their previous environment. To include Dockerized apps in your JSON: 

	**"container": {**

**		"type": "DOCKER",**

**		"docker": {**

**			"image": "group/image",**

**			"network": "HOST"**

**			}**

**		}**

**	}**

## Mounting Host Volumes (Legacy Datastores) 

Sometimes applications will require data that is unique to the application environment, or access to a directory that won't be destroyed at a certain time interval. This requirement can be met by implementing access to storage and this storage can be universally presented to all nodes in the cluster, or defined and made available on a per-node basis. For example, some nodes may have access to a SAN and you want the application to access data on the SAN-- this can be accommodated via combining a constraint, and then making sure that the particular host has the correctly mounted volumes. In the app JSON definition, it is simple to create this scenario: 

**{**

**		"container": {**

**			"type": "DOCKER",**

**			"docker": {**

**				"image": "group/image",**

**				"network": "HOST"**

**				},**

**				"volumes": [**

**					{**

**						"containerPath": "/var/hostlib",**

**						"hostPath": "/usr/lib",**

**						"mode": "RO"**

**					},**

**					{**

**						"containerPath": "/var/scratch",**

**						"hostPath": "/mount/ssd",**

**						"mode": "RW"**

**					}**

**				]**

**			}**

**		}**

**}**

## Health Checks

This check is valuable in querying the application to make sure it's in a better state than just "running". Marathon might believe an application is healthy because it is running, but in actuality the application might be suffering a wait state in networking, or a interruption in service preventing it from actually service requests. 

There are three basic (additional) health checks that can be utilized: command-based, HTTP, and TCP 

**Health Check JSON:** 

**{**

**	"gracePeriodSeconds": 300,**

**	"intervalSeconds": 60,**

**	"maxConsecutiveFailures": 3,**

**	"timeoutSeconds": 30**

**}**

**HTTP Checks:** 

HTTP Checks validate if doing a GET on a particular route results in a successful HTTP status code. 

**{**

**	"protocol": "HTTP",**

**	"path": "/healthcheck",**

**	"portIndex": 0**

**}**

**TCP Checks:** 

Checks whether it's possible to open a successful TCP connection to the task. 

**{**

**	"protocol": "TCP",**

**	"portIndex": 0**

**}**

## Additional Considerations for Porting Legacy Apps to Mesos/DC/OS: 

### DNS

DNS Changes and updates can take several seconds to propagate. Some applications cache DNS resolutions forever meaning they'll never see DNS changes). Unless you write a custom client library that can use SRV records, DNS doesn't provide a simple solution to running multiple apps on the same server but with different or randomly assigned ports. 

### Centralized Load Balancing 

Centralization can make it tricky and tedious to securely isolate applications from one another: in order to isolate the applications, you must configure Nginx or HAProxy rules for the specific isolation requirements. 

# Conclusion

DC/OS provides many elements to make traditional apps more robust and resilient without having to re-work a lot of underlying code. A good place to start is to consider which apps can be containerized and then how these containers can be deployed from within DC/OS. Breaking the silo/physical/virtual host paradigm allows for a much richer app environment and a better end-user experience for customers to those apps. Not all apps can easily be containerized and migrated to DC/OS- in some cases, figuring out how to refactor the app will be required and then migrating/port various components to containers and ultimately DC/OS will present a longer roadmap to modernization. 

