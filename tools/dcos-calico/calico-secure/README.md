# Setup Calico on DC/OS Enterprise

## Notes

This entire process is meant to be relatively automatable - you can basically put each file into a shell file and run it via ansible/chef/automation tool of choice. Overall, most of these can be run multiple times, but not all of them (specifically, restarting docker and the various sytemd units shouldn't be run multiple times). Do your own testing. You can find an Ansible playbook [here](./calico-secure.yml).

Depending on whether your docker config has `overlay` configured in the systemd unit or elsewhere, you'll have to consider removing the `overlay` line from /etc/docker/daemon.json - the command to do this is commented out in this script. If you're deploying on Mesosphere-provided AMIs, you may have to uncomment this command (so it gets automa†ically removed) from both enable-masters and enable-agents.

 This sets up a default pool of 192.168.0.0/16 (which supports something like 65k containers). You want to change this to meet the following requirements:
-Size the subnet accordingly
-Use a subnet that doesn't overlap with your environment.
This is configured in an environment variable that gets propagated to /etc/calico/ippool.json - if you need to change it, change it in the original env variable, or change it directly in the file prior to setting up the ip pool.

## Process

0: Stand up your DC/OS cluster. This whole process assumes DC/OS enterprise with permissive or strict (in order to use the DC/OS CA)

1a: Create env.export on all nodes. This will set up environment variables, and is used by other scripts

1b: Generate certs on all nodes

1c: Generate systemd units (and accompanying env files) on all nodes

1d: Generate conf files on all nodes

2: Run the package install on all nodes. This downloads all binaries and packages

3: On all masters, run the enable-masters commands. This starts all processes. Note that depending on whether your docker config has `overlay` configured in the systemd unit or elsewhere, you'll have to consider removing the `overlay` line from /etc/docker/daemon.json

4: On one master, run the commands from set-up-pool. This creates a cluster-wide Calico IP pool, used for all containers.

5: On all agents (private and public), run the enable-agents commands. This starts all processes.
