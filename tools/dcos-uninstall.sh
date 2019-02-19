#!/bin/bash
echo ""
echo ""
echo "##################################"
echo "          DC/OS Uninstaller"
echo ""
echo "What this script does:"
echo "- This script will uninstall all DC/OS binaries, libraries, and log files"
echo "  from this machine: $HOSTNAME."
echo "- This script leaves behind an uninstallation log which details all of the"
echo "  files that were removed from the machine. The log(s) are located at:"
echo "  /var/log/dcos.uninstall.log"
echo "- After running the uninstallation script, this machine is left in a"
echo "  state where DC/OS can be cleanly installed again."
echo "- This script is intended to remove DC/OS from Master and Agent nodes and"
echo "  should not be used to uninstall a bootstrap node."
echo ""
echo "What this script does not do:"
echo "- If you are running this script on an agent node, you should gracefully"
echo "  stop any active workloads on this node. This script will proceed with"
echo "  the uninstallation of DC/OS even with running workloads. However, the"
echo "  exit will not be graceful to those active workloads. Also, the "
echo "  uninstaller may not be able to delete any local ephemeral storage of the"
echo "  active workload(s) due to file locking issues. Any errors in file removal"
echo "  are logged in the uninstaller log."
echo "- This script does not uninstall or alter Docker in any way."
echo "- This script does not modify any supplemental services or packages"
echo "  which might have been used to install or configure DC/OS like: NTP, yum,"
echo "  firewalld, nginx, resolv.conf, etc."
echo "- This script does not force a reboot after completion. It asks the user"
echo "  to perform a reboot."
echo ""
echo "##################################"
echo ""

#Terminal color highlighting (for those really important messages)
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

#set the location of the uninstall log
UNINSTALL_LOG="/var/log/$(date +"%FT%T").dcos.uninstall.log"

#Function to exit the uninstall script if a failure is detected in a command
exit_on_fail () {
  echo ""
  echo ""
  echo "Failure: "
  echo "$1"
  exit
}

#Function to generate a fancy progress bar
fancy_progress () {
  printf "["
        while kill -0 $1 2> /dev/null; do
          printf  "▓"
          sleep .25
        done
  printf "] process complete"
  #The wait commend below grabs the return code of the process which was backgrounded.
  wait $1
  if [ $? -ne 0 ]; then
     echo -e " but ${RED}$2${NC}"  #Sends the error message to the terminal in red.
     echo ""
     echo ""
     #send the error message to the uninstall log
     echo "ERROR: ****  $2  ****" >> $UNINSTALL_LOG
     read -p "Do you wish to continue with the uninstallation? (y/n) " CONTINUE_AFTER_FAIL
     case $CONTINUE_AFTER_FAIL in
       [yY]) echo""
             echo "continuing with the uninstallation at user request"
             #Send the continuation to the log file
             echo ">>>>>> User initiated continuation of the script after error." >> $UNINSTALL_LOG
             ;;
       *)    echo ""
             echo "aborting uninstaller"
             echo "ERROR: User aborted script after error \"$2\" was reported." >> $UNINSTALL_LOG
             exit_on_fail "$2"
             ;;
     esac
  fi
}

######
### This is the end of the function definitions and the beginning of the main program.
######

#Check to see if the command is being run under root permissions
if [ "$EUID" -ne 0 ]; then

   echo -e "${RED}*******************************"
   echo "*******************************"
   echo -e "${BLUE} Please run as root. Exiting."
   echo -e "${RED}*******************************"
   echo -e "*******************************${NC}"
   exit_on_fail "Not Root"
fi


#Prompt user to continue with DC/OS uninstallation
read -p "Do you wish to continue with the uninstallation of DC/OS? (y/n) " YES_FLAG
case $YES_FLAG in
  [yY]) echo ""
        echo "Creating uninstall log file at: $UNINSTALL_LOG"
        echo "################## DC/OS Uninstallation Log ######################" > $UNINSTALL_LOG & PID=$!
        fancy_progress $PID "Failed to write uninstall log file at $UNINSTALL_LOG"
        echo "" >> $UNINSTALL_LOG
        date >> $UNINSTALL_LOG
        echo $HOSTNAME >> $UNINSTALL_LOG
        echo ""
        echo ""

        echo "Stopping all DC/OS services (might take 1-2 minutes to complete on a DC/OS Master node)"
        systemctl stop dcos-* >/dev/null 2>/dev/null & PID=$!
        fancy_progress $PID "Failed Stopping DC/OS Services. is DC/OS running?"
        echo ""
        echo ""

        echo "Uninstalling pkgpanda"
        /opt/mesosphere/bin/dcos-shell /opt/mesosphere/bin/pkgpanda uninstall >/dev/null 2>/dev/null & PID=$!
        fancy_progress $PID "Failed to uninstall pkgpanda."
        echo ""
        echo ""

        echo "Removing all DC/OS binaries, libraries, and logs"
        rm -rfv /opt/mesosphere /var/lib/mesosphere /etc/mesosphere /var/lib/zookeeper /var/lib/mesos /var/lib/dcos /run/dcos /etc/profile.d/dcos.sh /etc/systemd/journald.conf.d/dcos.conf /etc/systemd/system/dcos* /etc/systemd/system/multi-user.target.wants/dcos-setup.service /etc/systemd/system/multi-user.target.wants/dcos.target /run/mesos /var/log/mesos /tmp/dcos /etc/rexray >> $UNINSTALL_LOG 2>>$UNINSTALL_LOG & PID=$!
        fancy_progress $PID "\nFailed to remove some DC/OS Files.\nSearch $UNINSTALL_LOG for the word \"cannot\" to see the failed files.\nYou will need to reboot the machine and manually delete those files."
        echo ""
        echo ""

        echo "Reloading system daemons"
        systemctl daemon-reload >/dev/null& PID=$!
        fancy_progress $PID "Failed reloading system daemons"

        echo ""
        echo ""
        echo ""
        echo ""
        echo -e "${RED}DC/OS Uninstallation Complete"
        echo -e "Please Restart the Machine${NC}"
        echo -e ""
        echo -e "Restarting the system will clean up any existing file locks which might cause problems for re-installing DC/OS. Also, the reboot will clear any advanced DC/OS networking configurations which might be invalid for re-installation."
        ;;

  [nN]) echo "Uninstallation aborted at request of user."
        ;;

  *)    echo "invalid choice. aborting uninstaller."
        ;;

esac

exit