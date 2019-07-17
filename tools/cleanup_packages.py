import requests
import argparse
import sys

requests.packages.urllib3.disable_warnings()

parser = argparse.ArgumentParser(description="Removes unused DC/OS Pkgpanda packages")
parser.add_argument("--master_host", required=True, help="DC/OS master hostname")
parser.add_argument("--token", required=True, help="auth token")
parser.add_argument("--clean_agents", action="store_true", help="clean up agents")
parser.add_argument("--insecure", action="store_true", help="proceed with insecure connections")
args = parser.parse_args()

master_host  = args.master_host
token        = args.token
clean_agents = args.clean_agents
verify_cert  = not args.insecure

headers = {"Authorization": "token=" + token}

def fetch_all_pkg(url):
    all_pkg_url = url + "/pkgpanda/repository/"
    r = requests.get(all_pkg_url, verify=verify_cert, headers=headers)
    if r.status_code != 200:
        print("ERROR: Cannot fetch list of all packages. Status code: {0}".format(r.status_code))
        print(r.text)
        sys.exit(1)
    return r.json()

def fetch_active_pkg(url):
    active_pkg_url = url + "/pkgpanda/active/"
    r = requests.get(active_pkg_url, verify=verify_cert, headers=headers)
    if r.status_code != 200:
        print("ERROR: Cannot fetch list of active packages. Status code: {0}".format(r.status_code))
        print(r.text)
        sys.exit(2)
    return r.json()

def calc_inactive_pkg(all_pkg, active_pkg):
    active_pkg = set(active_pkg)
    return [pkg for pkg in all_pkg if pkg not in active_pkg]

def delete_pkg(url, pkgs):
    delete_pkg_url = url + "/pkgpanda/repository/"
    n_success = 0
    n_fail = 0
    print('Deleting packages from host "{0}"'.format(url))
    for pkg in pkgs:
        r = requests.delete(url=delete_pkg_url + pkg, verify=verify_cert, headers=headers)
        if r.status_code == 200 or r.status_code == 202 or r.status_code == 204:
            n_success += 1
            print(".", end='')
        else:
            n_fail += 1
            print("X", end='')
    print()
    print("Successfully deleted: {0}".format(n_success))
    print("Failed to delete:     {0}".format(n_fail))

def clean(url): 
    print("Cleaning {0}".format(url))
    all_pkg = fetch_all_pkg(url)
    active_pkg = fetch_active_pkg(url)
    inactive_pkg = calc_inactive_pkg(all_pkg, active_pkg)

    print("All packages:      {0}".format(len(all_pkg)))
    print("Active packages:   {0}".format(len(active_pkg)))
    print("Inactive packages: {0}".format(len(inactive_pkg)))

    if len(inactive_pkg) != 0:
        delete_pkg(url, inactive_pkg)

def fetch_agents(url):
    agents_url = url + "/mesos/slaves"
    r = requests.get(agents_url, verify=verify_cert, headers=headers)
    if r.status_code != 200:
        print("ERROR: Cannot fetch list of agents. Status code: {0}".format(r.status_code))
        print(r.text)
        sys.exit(3)
    agents = r.json()["slaves"]
    hostnames = [agent["hostname"] for agent in agents]
    print("Agents found: {0}".format(len(hostnames)))
    return hostnames

# Main
master_url = "https://{0}".format(master_host)
clean(master_url)
print()
if clean_agents:
    hostnames = fetch_agents(master_url)
    print()
    for hostname in hostnames:
        clean("https://{0}:61002".format(hostname))
        print()