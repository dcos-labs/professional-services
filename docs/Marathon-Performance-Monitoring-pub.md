Marathon/Mesos Performance Monitoring  

*October 30, 2017*

*[ajohnson@mesosphere.i*o](mailto:ajohnson@mesosphere.io)

[[TOC]]

# Health of Marathon

There are several components to monitor within a DC/OS cluster but perhaps one of the most important, if deployed, is Marathon. Overall monitoring of the environment will be useful to track changes and deviations within the environment overtime, and monitoring Marathon will indicate when there are problems on the horizon for managing tasks within the cluster environment. 

Monitoring should utilize historic data points so that an entire perspective of health within the cluster can be understood. Monitoring should be an ongoing effort so that operators know what the cluster operates like both in normal scenarios and when under load or experiencing issues. 

There are currently two types of metrics in DC/OS, via Marathon and Mesos:

* Gauges: these are metrics that provide current state when queried 

* Counters: have metrics that are cumulative and include both past and present results. It should be understood that these metrics will not persist across failovers within the environment 

Additionally, Marathon has a timer metric that determines how long an event has been ongoing/taking place. 

## Marathon Performance and Configuration Data

As previously mentioned, monitoring of Marathon and other sub components should be implemented before issues exist- this gives operators a perspective of what constitutes ‘normal’ performance within their cluster environment. Frequently, in identifying issues within an environment, operators report that what they considered normal operations was actually >85% consumed resources underload. Most certainly, we don’t want to consider an environment that is near resource exhaustion as ‘normal’. It puts the operators and Mesosphere in a reactive position without a clear picture as to what has been happening or is currently happening within the cluster. 

Performance metrics and configuration data should be collected in an ongoing fashion, and most certainly prior to any major event within the cluster. If you are going to perform an upgrade, or deploy a large scale new app, collect performance data both prior, during, and post the activity! 

 ** In the pre-upgrade and deployment data collection phase, *and during changes to an environment,* log levels should be set to informational so there will be plenty of log data in the event RCA needs to be conducted during the entire process. 

Next, let’s look at some quick ways we can implement baseline measurements within the environment purely from a DC/OS perspective: 

### Collect details from end-points

There are different levels at which to capture state-- from configuration of the cluster, to ongoing performance of the cluster, to ongoing performance and configuration of the underlying operating environment. First we’ll look at the Marathon/Mesos layers. 

1. Implement monitoring loop for gathering Marathon metrics. These monitoring loops run as ‘tasks’ from within DC/OS. Just like you would launch an app within the cluster.  

<table>
  <tr>
    <td>## Example 1: Monitoring a mon-marathon
# 
while sleep 1; do echo; date; curl mon-marathon-service.containerip.dcos.thisdcos.directory:8080/metrics; done > metrics.log</td>
  </tr>
  <tr>
    <td>while sleep 1; do echo; date; curl mon-marathon-service.mesos:22223/metrics; done > metrics2.log </td>
  </tr>
  <tr>
    <td>## Example 2: Monitoring mesos metrics continuously over a sleep 5 loop
# 
while sleep 5; do
> echo "";
> date;
> curl leader.mesos:8080/metrics;
> echo "--------------------new line----------------------";
> done >metrics-leader-mesos.log
</td>
  </tr>
</table>


2. Implement task on DC/OS cluster to monitor Marathon state: 

<table>
  <tr>
    <td>## Example 3: loop collecting mesos metrics from a task, writing to a log 
## This is useful when you might not have access to the underlying 
## environment 
#
{
  "id": "/mon-marathon-service-metrics-curl-history",
  "cmd": "while sleep 5; do echo; date; curl mon-marathon-service.mesos:22223/metrics | jq .; done",
  "cpus": 0.1,
  "mem": 32,
  "disk": 0,
  "instances": 1,
  "container": {
    "type": "MESOS",
    "volumes": []
  },
  "env": {
    "CONTAINER_LOGGER_MAX_STDOUT_SIZE": "100mb",
    "CONTAINER_LOGGER_LOGROTATE_STDOUT_OPTIONS": "rotate 9\ncompress"
  },
  "portDefinitions": []
}</td>
  </tr>
</table>


 

### Journalctl Logs 

All too often, performance and other related issues will stem from underlying configuration parameters or resource constraints within the supporting host operating system environment. Understanding what the OE (Operating Environment) challenges and existing configuration are is key to understanding and speculating how an app might perform on DC/OS. 

In modern Linux environments, both journalctl and systemctl will be the most useful to capture log and configuration data (respectively). 

Let’s say that I wanted to look at all dcos-marathon activity since yesterday until now to understand what a 12 + hour period of normal operations was within my environment, using journalctl I can request that information: 

journalctl -fu dcos-marathon --since yesterday --until now >capture.to.log

Even in the smallest environments, be prepared for copious output from that command. From here you would want to search for ERRORs or INFO, or a key string that might indicate a problem and/or constraint within the system. 

**INFO**: Provides the most verbose logging:

10-30 15:47:14,036] INFO  No match for:004cefa7-46db-4120-a6ab-64baaa5dc368-O545 from:10.0.5.6 reason:No offers wanted (mesosphere.marathon.core.matcher.manager.impl.OfferMatcherManagerActor:marathon-akka.actor.default-dispatcher-153)

Oct 30 15:47:14 ip-10-0-7-92.us-west-2.compute.internal marathon.sh[5912]: [2017-10-30 15:47:14,669] INFO  Received health result for app [/marathon-user] version [2017-10-30T15:01:23.303Z]: [Healthy(instance [marathon-user.marathon-326b2f94-bd83-11e7-b1d5-e2a61b3a8b73],2017-10-30T15:01:23.303Z,2017-10-30T15:47:14.669Z,true)] (mesosphere.marathon.core.health.impl.HealthCheckActor:marathon-akka.actor.default-dispatcher-153)

**WARNING**: Provides the next scope level of detail with messages that maybe concerning but also might be false negatives:

Oct 30 14:44:42 ip-10-0-7-92.us-west-2.compute.internal bootstrap[5381]: [WARNING] Certificate was not found

Oct 30 14:45:11 ip-10-0-7-92.us-west-2.compute.internal marathon.sh[5912]: [AppClassLoader@55f96302] warning javax.* types are not being woven because the weaver option '-Xset:weaveJavaxPackages=true' has not been specified

Oct 30 14:45:16 ip-10-0-7-92.us-west-2.compute.internal marathon.sh[5912]: WARNING: Logging before InitGoogleLogging() is written to STDERR

**ERROR**: Provides actual error notices as they are written to the system detailing which subsystems are encountering the error: 

Oct 30 14:44:45 ip-10-0-7-92.us-west-2.compute.internal bootstrap[5381]:     raise HTTPError(http_error_msg, response=self)

Oct 30 14:44:45 ip-10-0-7-92.us-west-2.compute.internal bootstrap[5381]: requests.exceptions.HTTPError: 409 Client Error: Conflict for url: http://127.0.0.1:8101/acs/api/v1/acls/dcos:mesos:agent:task

Oct 30 14:45:12 ip-10-0-7-92.us-west-2.compute.internal marathon.sh[5912]: [2017-10-30 14:45:12,901] INFO  Opening socket connection to server ip-10-0-7-92.us-west-2.compute.internal/10.0.7.92:2181. Will not attempt to authenticate using SASL (unknown error) (org.apache.zookeeper.ClientCnxn:JMX exporting thread-SendThread(ip-10-0-7-92.us-west-2.compute.internal:2181))

Perhaps you want to capture everything pertaining to dcos-* users? The following will perform this capture with some extracts for Marathon and interesting focus on dcos-*:

journalctl -fu dcos-* --since yesterday --until now >capture.to.log

<table>
  <tr>
    <td>dcos-marathon</td>
    <td>-- Logs begin at Tue 2017-08-29 12:41:13 UTC. --
Aug 29 13:56:21 ip-10-0-4-177.us-west-2.compute.internal marathon.sh[13594]: [2017-08-29 13:56:21,049] INFO  Proxying request to GET http://10.0.7.221:8080/v2/leader from 10.0.4.177:8080 (mesosphere.marathon.api.JavaUrlConnectionRequestForwarder$:qtp1075314220-130)
Aug 29 13:56:21 ip-10-0-4-177.us-west-2.compute.internal marathon.sh[13594]: [2017-08-29 13:56:21,052] INFO  127.0.0.1 - - [29/Aug/2017:13:56:21 +0000] "GET https://127.0.0.1:8443/v2/leader HTTP/1.1" 200 28 "-" "lua-resty-http/0.09 (Lua) ngx_lua/10005"  (mesosphere.chaos.http.ChaosRequestLog$$EnhancerByGuice$$22ce23a3:qtp1075314220-130)
Aug 29 13:56:51 ip-10-0-4-177.us-west-2.compute.internal marathon.sh[13594]: [2017-08-29 13:56:51,108] INFO  Proxying request to GET http://10.0.7.221:8080/v2/apps?embed=apps.tasks&label=DCOS_SERVICE_NAME from 10.0.4.177:8080 (mesosphere.marathon.api.JavaUrlConnectionRequestForwarder$:qtp1075314220-191)
Aug 29 13:56:51 ip-10-0-4-177.us-west-2.compute.internal marathon.sh[13594]: [2017-08-29 13:56:51,116] INFO  127.0.0.1 - - [29/Aug/2017:13:56:51 +0000] "GET https://127.0.0.1:8443/v2/apps?embed=apps.tasks&label=DCOS_SERVICE_NAME HTTP/1.1" 200 15763 "-" "lua-resty-http/0.09 (Lua) ngx_lua/10005"  (mesosphere.chaos.http.ChaosRequestLog$$EnhancerByGuice$$22ce23a3:qtp1075314220-191)</td>
  </tr>
  <tr>
    <td>dcos*</td>
    <td>-- Logs begin at Tue 2017-08-29 12:41:13 UTC. --
Aug 29 13:59:13 ip-10-0-4-177.us-west-2.compute.internal nginx[22054]: ip-10-0-4-177.us-west-2.compute.internal nginx: 100.0.1.74 - - [29/Aug/2017:13:59:13 +0000] "GET /service/marathon/v2/groups?_timestamp=1504015153635&embed=group.groups&embed=group.apps&embed=group.pods&embed=group.apps.deployments&embed=group.apps.counts&embed=group.apps.tasks&embed=group.apps.taskStats&embed=group.apps.lastTaskFailure HTTP/1.1" 200 28128 "https://34.223.226.122/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"
Aug 29 13:59:13 ip-10-0-4-177.us-west-2.compute.internal bouncer.sh[11616]: [170829-13:59:13.739] [12422:Thread-10] [bouncer.app.auth.Login] INFO: Trigger login procedure for uid `dcos_mesos_dns`
Aug 29 13:59:13 ip-10-0-4-177.us-west-2.compute.internal bouncer.sh[11616]: [170829-13:59:13.739] [12422:Thread-10] [bouncer.app.auth.Login] INFO: Service login: UID refers to a known service account.
Aug 29 13:59:13 ip-10-0-4-177.us-west-2.compute.internal bouncer.sh[11616]: [170829-13:59:13.739] [12422:Thread-10] [bouncer.app.auth.Login] INFO: Service login: validate service login JWT using the service's public key
Aug 29 13:59:13 ip-10-0-4-177.us-west-2.compute.internal bouncer.sh[11616]: [170829-13:59:13.740] [12422:Thread-10] [bouncer.app.auth.Login] WARNING: long-lived service login token (> 10 minutes)
Aug 29 13:59:13 ip-10-0-4-177.us-west-2.compute.internal bouncer.sh[11616]: [170829-13:59:13.740] [12422:Thread-10] [bouncer.app.crypt] INFO: Generate auth token with payload `{'exp': 1504447153, 'uid': 'dcos_mesos_dns'}`</td>
  </tr>
</table>


### Systemctl logs 

Systemctl can be used to inspect and control the state of the systemd system and service manager which manages the ‘units’ within the system. Systemctl is very frequently used to start|stop|status units within a given operating environment. 

We usually refer to the output of systemctl when it is suspected that a service has an issue, or when something that is supposed to be started and available does not answer requests. As such, we may find the following useful in ‘grepping’ for reasons why a system is not performing or operating as expected: 

<table>
  <tr>
    <td>Systemctl status dcos*</td>
  </tr>
  <tr>
    <td>core@ip-10-0-7-92 ~ $ sudo systemctl status dcos*
● dcos-history.service - DC/OS History: caches and exposes historical system stat
   Loaded: loaded (/opt/mesosphere/packages/dcos-history--23de88ddc1a5f9018dd11b2
   Active: active (running) since Mon 2017-10-30 14:44:30 UTC; 3h 41min ago
  Process: 5294 ExecStartPre=/opt/mesosphere/bin/bootstrap dcos-history (code=exi
  Process: 5202 ExecStartPre=/bin/ping -c1 leader.mesos (code=exited, status=0/SU
 Main PID: 5316 (gunicorn)
    Tasks: 3
   Memory: 45.2M
      CPU: 52.186s
   CGroup: /system.slice/dcos-history.service
           ├─5316 /opt/mesosphere/packages/python--5a4285ff7296548732203950bf73d3
           └─5331 /opt/mesosphere/packages/python--5a4285ff7296548732203950bf73d3</td>
  </tr>
  <tr>
    <td>Systemctl show dcos-marathon</td>
  </tr>
  <tr>
    <td>core@ip-10-0-7-92 ~ $ sudo systemctl show dcos-marathon
Type=simple
Restart=always
NotifyAccess=none
RestartUSec=15s
TimeoutStartUSec=1min 30s
TimeoutStopUSec=1min 30s
RuntimeMaxUSec=infinity
WatchdogUSec=0
WatchdogTimestamp=Mon 2017-10-30 14:45:05 UTC
WatchdogTimestampMonotonic=284605293
FailureAction=none
PermissionsStartOnly=yes
RootDirectoryStartOnly=no
RemainAfterExit=no
GuessMainPID=yes
MainPID=5912
ControlPID=0
. . . </td>
  </tr>
  <tr>
    <td>systemctl status dcos* |grep -i failed</td>
  </tr>
  <tr>
    <td>Oct 30 14:44:19 ip-10-0-7-92.us-west-2.compute.internal mesos-dns[5180]: ERROR: 2017/10/30 14:44:19 generator.go:173: Failed to fetch state.json. Error:  No more masters eligible for state.json query
Oct 30 14:44:26 ip-10-0-7-92.us-west-2.compute.internal mesos-dns[5180]: ERROR: 2017/10/30 14:44:26 generator.go:173: Failed to fetch state.json. Error:  No more masters eligible for state.json query
Oct 30 14:44:26 ip-10-0-7-92.us-west-2.compute.internal mesos-dns[5180]: ERROR: 2017/10/30 14:44:26 generator.go:173: Failed to fetch state.json. Error:  No more masters eligible for state.json query
           ├─5057 /opt/mesosphere/packages/networking_api--462289865bff33ff4b2d05</td>
  </tr>
</table>


#### Continuing... Metrics Names and Required Endpoints: 

Many times, in troubleshooting environments, the operators are asked, "What changed? What’s different about today than yesterday? Did you make a modification to the environment? Did someone else make a modification?" While there are many possible answers to these questions, as long as the integrity of the system is intact, the answers can frequently be found in analyzing the before and after state of a given cluster. 

Perhaps one of the most useful and fruitful places to do this digging is through "Marathon Metrics" These metrics can be extracted from the system by fetching the metrics from: 

[https://<masterPublicIP>/marathon/metrics](https://masterIP/marathon/metrics) → 

The metrics return to use via a webpage with Key/Value pairs denoting various configured parameters and states within the environment. Here are some findings of key interest. Depending on the situation being analyzed, some values will obviously be of more interest than others.

At the time of this writing, it is rumored that Marathon metrics are being deprecated in favor of Mesos metrics. Nonetheless, whichever environment, garnering details from both sides of the fence will assist in problem determination. Shown below are some key metrics for both Marathon and Mesos:  

<table>
  <tr>
    <td>Marathon Metrics Name</td>
    <td>Value</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.uptime</td>
    <td>5221988 (~87 min) (value/60000=Nmin) (uptime of the main Marathon)</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.leaderDuration</td>
    <td>5220641 
(length of time the current leader has been the leader) </td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.app.count</td>
    <td>4
(total number of apps)</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.group.count</td>
    <td>1
(total number of groups)</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.task.running.count</td>
    <td>4
(total number of running tasks)</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.task.staged.count</td>
    <td>0
(staging tasks, can indicate issues)</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.core.task.update.impl.ThrottlingTaskStatusUpdateProcessor.queued</td>
    <td>0 
(queued tasks, that are being throttled)</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.core.task.update.impl.ThrottlingTaskStatusUpdateProcessor.processing</td>
    <td>0
(queued tasks that have entered the processing (starting) state) </td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.core.task.update.impl.TaskStatusUpdateProcessorImpl.publishFuture</td>
    <td>"count": 57,"max": 0.033368508000000005,"mean": 0.006840424377251375,"min": 0.002051402,"p50": 0.006769763000000001,"p75": 0.0069256510000000005,"p95": 0.008879717,"p98": 0.008879717,"p99": 0.008879717,"p999": 0.008879717,"stddev": 0.0011669870451647593,"m15_rate": 0.011587662061348307,"m1_rate": 0.0001628140806256395,"m5_rate": 0.008062093079665834,"mean_rate": 0.010915351211037795,"duration_units": "seconds","rate_units": "calls/second"</td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.core.launcher.impl.OfferProcessorImpl.incomingOffers</td>
    <td>"count": 38,"m15_rate": 0.007533606193102653,"m1_rate": 0.016531615665440882,"m5_rate": 0.009152129629021469,"mean_rate": 0.007277410942256791,"units": "events/second"
(incoming resources to be offered to tasks) </td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.MarathonScheduler.resourceOffers</td>
    <td>"count": 34,"max": 0.00484972,"mean": 0.00013228407690996707,"min": 0.00008738700000000001,"p50": 0.000114722,"p75": 0.000150264,"p95": 0.000150264,"p98": 0.000150264,"p99": 0.000150264,"p999": 0.000150264,"stddev": 0.000017805424128699182,"m15_rate": 0.00977782791715119,"m1_rate": 0.01724510775597864,"m5_rate": 0.009202480851037077,"mean_rate": 0.008437793103876991,"duration_units": "seconds","rate_units": "calls/second"
(actual resource offers to tasks) </td>
  </tr>
  <tr>
    <td>service.mesosphere.marathon.MarathonScheduler.statusUpdate</td>
    <td>"count": 57,"max": 0.00190416,"mean": 0.00008020949416247715,"min": 0.000058959,"p50": 0.000075134,"p75": 0.000077107,"p95": 0.000135357,"p98": 0.000135357,"p99": 0.000135357,"p999": 0.000135357,"stddev": 0.000022402519958529,"m15_rate": 0.0233327072903664,"m1_rate": 0.00016281408062563977,"m5_rate": 0.008063751105565007,"mean_rate": 0.014233950114168777,"duration_units": "seconds","rate_units": "calls/second"</td>
  </tr>
  <tr>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>Mesos Metrics Name</td>
    <td>Value</td>
  </tr>
  <tr>
    <td><URI/focus/detail></td>
    <td>Curl http://<Internal-Master-IP:5050>/focus</td>
  </tr>
  <tr>
    <td>files/debug</td>
    <td>curl http://10.0.4.177:5050/files/debug |jq</td>
  </tr>
  <tr>
    <td>/var/lib/dcos/mesos/log/mesos-master.log</td>
    <td>Native on host (master)</td>
  </tr>
  <tr>
    <td>/flags</td>
    <td>curl http://10.0.4.177:5050/flags |jq .</td>
  </tr>
  <tr>
    <td>/frameworks</td>
    <td>curl http://10.0.4.177:5050/frameworks |jq</td>
  </tr>
  <tr>
    <td>/health</td>
    <td><masterPrivIP>:5050/health</td>
  </tr>
  <tr>
    <td>/machine/down & /machine/up</td>
    <td></td>
  </tr>
  <tr>
    <td>/roles</td>
    <td>curl http://10.0.4.177:5050/roles |jq</td>
  </tr>
  <tr>
    <td>/slaves</td>
    <td>curl http://10.0.4.177:5050/slaves |jq</td>
  </tr>
  <tr>
    <td>/state</td>
    <td>curl http://10.0.4.177:5050/state |jq</td>
  </tr>
  <tr>
    <td>/state-summary</td>
    <td>curl http://10.0.4.177:5050/state-summary</td>
  </tr>
  <tr>
    <td>/tasks</td>
    <td>curl http://10.0.4.177:5050/tasks.json |jq</td>
  </tr>
  <tr>
    <td>/metrics/snapshot</td>
    <td>curl http://10.0.4.177:5050/metrics/snapshot |jq</td>
  </tr>
  <tr>
    <td>/system/stats.json</td>
    <td>curl http://10.0.4.177:5050/system/stats.json |jq</td>
  </tr>
</table>


## Health Checks

This section runs health checks against the DC/OS cluster (and components) in the pre-upgrade or pre-deployment (app) state. Any failures must be remediated before making changes in the environment.

### Marathon Health Checks

Health Checks: 

* The default health check employs Mesos’ knowledge of the task state TASK_RUNNING => healthy.

* Marathon provides a health member of the task resource via the [REST API](https://mesosphere.github.io/marathon/docs/rest-api.html), so you can add a health check to your application definition.

<table>
  <tr>
    <td>{
  "path": "/api/health",
  "portIndex": 0,
  "protocol": "HTTP",
  "gracePeriodSeconds": 300,
  "intervalSeconds": 60,
  "timeoutSeconds": 20,
  "maxConsecutiveFailures": 3,
  "ignoreHttp1xx": false
}

TCP Health Check:
{
  "portIndex": 0,
  "protocol": "TCP",
  "gracePeriodSeconds": 300,
  "intervalSeconds": 60,
  "timeoutSeconds": 20,
  "maxConsecutiveFailures": 0
}

Command Health Check: 
{
  "protocol": "COMMAND",
  "command": { "value": "curl -f -X GET http://$HOST:$PORT0/health" },
  "gracePeriodSeconds": 300,
  "intervalSeconds": 60,
  "timeoutSeconds": 20,
  "maxConsecutiveFailures": 3
}


Readiness Checks: 
"readinessChecks": [
  {
    "name": "readinessCheck",
    "protocol": "HTTP",
    "path": "/",
    "portName": "http-api",
    "intervalSeconds": 30,
    "timeoutSeconds": 10,
    "httpStatusCodesForReady": [ 200 ],
    "preserveLastResponse": false
  }
]</td>
  </tr>
</table>


#### Check Marathon/Mesos - CLI 

From the operating environment, logged into a master, you can run the following commands to verify the well being and health of Marathon/Mesos:

<table>
  <tr>
    <td>Step</td>
    <td>Command</td>
  </tr>
  <tr>
    <td>1</td>
    <td>curl leader.mesos:8080/v2/leader</td>
  </tr>
  <tr>
    <td>2</td>
    <td>Leader IP: </td>
  </tr>
  <tr>
    <td>3</td>
    <td>curl leader.mesos:8080/v2/info | jq .</td>
  </tr>
  <tr>
    <td>4</td>
    <td>Leader Info: </td>
  </tr>
</table>


#### Count apps deployed on Marathon

<table>
  <tr>
    <td>Step</td>
    <td>Command</td>
  </tr>
  <tr>
    <td>1</td>
    <td>curl leader.mesos:8080/v2/apps|jq .apps[].id|wc -l</td>
  </tr>
  <tr>
    <td>2</td>
    <td>Running Apps: </td>
  </tr>
</table>


#### Mesos Master Health Check - Replog Status Equal to 1

<table>
  <tr>
    <td>Step</td>
    <td>Command</td>
  </tr>
  <tr>
    <td>1</td>
    <td>On a master, run shell code:

#!/bin/bash 
for master in $(host master.mesos | cut -d " " -f 4); do ssh $master -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -SsL "curl $master:5050/metrics/snapshot | jq . | grep registrar/log/recovered";done</td>
  </tr>
  <tr>
    <td>2</td>
    <td>Output: </td>
  </tr>
</table>


# Conclusion

Every implementation of DC/OS and cluster is different from any other- even systems which are created in likeness of another will have slight nuances from the parent environment. In considering performance related aspects to any DC/OS cluster, no assumptions can be made and each individual environment will have to undergo the required performance analysis to understand the exact nature of issues, performance, capacity, and capabilities for growth and stress. What constitutes good health in one scenario might be sub-par performance in another - understanding the underlying resources, how they are provisioned, and how they are ultimately consumed will vary on a case-by-case example. 

# Additional Resources

[https://mesosphere.github.io/marathon/docs/metrics.html](https://mesosphere.github.io/marathon/docs/metrics.html)

Query the current metrics via the /metrics HTTP endpoint or configure the metrics to report periodically to:

* graphite via --reporter_graphite

* datadog via --reporter_datadog

* statsd via --reporter_datadog (datadog reports supports statsd)

Dropdown metrics, admin guide: 

[http://metrics.dropwizard.io/3.2.3/manual/index.html](http://metrics.dropwizard.io/3.2.3/manual/index.html)

**Debug Flags**

* **v0.8.2** --logging_level (Optional): Set the logging level of the application. Use one of off, fatal, error, warn, info, debug, trace, all.

* **v0.13.0** --[disable_]tracing (Optional. Default: disabled): Enable tracing for all service method calls. Log a trace message around the execution of every service method.

* **v1.2.0** --logstash (Optional. Default: disabled): Report logs over the network in JSON format as defined by the given endpoint in (udp|tcp|ssl)://<host>:<port> format.

