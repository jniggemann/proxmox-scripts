#!/bin/bash
#title           :create_alpine_whoogle.bash
#description     :Will create a tiny alpine-whoogle LXC on your proxmox host
#author          :https://github.com/jniggemann/proxmox-scripts
#date            :20230324
#version         :0.3
#license         :GPL v2
#==============================================================================

# You may change these settings
DISKSIZE="0.2"      # This means 0.2GB
RAM="256"           # This is an upper limit, LXC containers only use the RAM they need anyway.
HOSTNAME="whoogle3" # This will be the new hostname, set it to whatever you like

##################################
### No changes below this point###
##################################

# Create the new container
create_container() {
  pct create $NEXTID local:vztmpl/$TEMPLATE -arch amd64 \
    -cores 1 -memory $RAM -net0 bridge=vmbr0,name=eth0,ip=dhcp,firewall=1 \
    -rootfs local-lvm:$DISKSIZE -swap 0 -ostype alpine -hostname $HOSTNAME -unprivileged 1 \
    -features keyctl=1,nesting=1 -start 1 >/dev/null ||
    exit "❌  There was a problem and I could not create your container."
}

# Configure the newly-created container and install the software
configure_container() {
  # stop container's syslog and disable it. Also set root password to empty
  lxc-attach -n "$NEXTID" -e -- ash -c "/etc/init.d/syslog stop;rc-update del syslog boot;passwd -d root" >/dev/null 2>&1

  # install pip3, install whoogle and its service file, start whoogle
  lxc-attach -n "$NEXTID" -e -- ash -c "apk add --no-cache py3-pip;pip3 install --no-cache-dir brotli >/dev/null;pip3 install --no-cache-dir whoogle-search >/dev/null" >/dev/null 2>&1
  lxc-attach -n "$NEXTID" -e -- ash -c "echo '#!/sbin/openrc-run

        depend() {
            need net
        }

        command=\"/usr/bin/whoogle-search\"
        command_args=\"--host 0.0.0.0\"
        command_background=true
        pidfile=\"/run/\${RC_SVCNAME}/pid\"

        start_pre() {
        # Make sure that our dir exists
            checkpath --directory --mode 0775 /run/\${RC_SVCNAME}
        }' > /etc/init.d/whoogle" >/dev/null

  lxc-attach -n "$NEXTID" -e -- ash -c "chmod 755 /etc/init.d/whoogle;/etc/init.d/whoogle start" >/dev/null

}

# Print IP once we're done
print_final_message() {
  IP=$(lxc-attach "$NEXTID" ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
  echo -e "${BGreen}All done, your new minimal whoogle search instance is available at${Color_Off} ${BYellow}http://$IP:5000${Color_Off}."
}

# Which is the latest available alpine template?
select_template() {
  #       pveam update
  TEMPLATE=$(pveam available -section system | grep alpine | awk '{print $2'} | sort -r | head -1)
}

# Look for first storage where templates can be stored
get_first_storage() {
  STORAGE=$(pvesm status --enabled --content vztmpl | tail -n +2 | awk '{print $1}')
}

# Check if template is already there
check_template_available() {
  TEMPLATEAVAILABLE=$(pveam list $STORAGE | grep $TEMPLATE)

  # Is the template in the storage?
  if [ -z "$TEMPLATEAVAILABLE" ]; then
    # No, we need to download it
    echo -e " ${BYellow}*${Color_Off} Template not found in first template storage ($STORAGE). I'll download it and then create the container, give me a minute."
    pveam download $STORAGE $TEMPLATE >/dev/null || exit "❌  There was a problem and I could not download the template."
  else
    # Yes, we can proceed
    echo -e " ${BGreen}*${Color_Off} Template found, creating container. Hang on, we're almost there."
  fi
}

# Add note to LXC
add_description() {
  pct set "$NEXTID" -description "# Minimal Whoogle-Alpine LXC
https://github.com/jniggemann/proxmox-scripts"
}

# main program

# Set color variables
BGreen='\033[1;32m'  # Green
BYellow='\033[1;33m' # Yellow
Color_Off='\033[0m'  # Text Reset

# Get the next free ID
NEXTID=$(pvesh get /cluster/nextid)

echo -e "Will now install ${BYellow}whoogle${Color_Off}..."
select_template
echo -e " ${BGreen}*${Color_Off} ${BYellow}$TEMPLATE${Color_Off} is the most recent alpine template. We'll use it."
get_first_storage
check_template_available
create_container
configure_container
echo -e " ${BGreen}*${Color_Off} container created and configured"
add_description
print_final_message
