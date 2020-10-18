#!/bin/bash

# generate ssh keys with:
# ssh-keygen -t ecdsa -b 521 -C "<Name of key owner>" -N "" -f <name des keyfiles>.key
# the easiest way is to do it directly in ~/.ssh directory

# this script is (as far as possible) idempotent. This means you can rerun it
# if you programmed an error and it will most probably work!

pi_hostname=$1
pi_new_user=$2
pi_keyfile=$3

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# this trick avoids additional scp logins
pi_authorized_keys=$(cat ${SCRIPT_DIR}/authorized_keys)
pi_sshd_config=$(cat ${SCRIPT_DIR}/sshd_config)        

function create_user {
    echo -n "
    if [ -z '\$(getent passwd $pi_new_user)' ]; then
        set -x
        echo '+++ New user: $pi_new_user +++'
        set +x
        useradd --uid 1114 --comment 'Doorpi system user' \
--create-home $pi_new_user &&
        usermod -a -G pi,adm,dialout,cdrom,sudo,audio,video,plugdev,\
games,users,input,netdev,gpio,i2c,spi $pi_new_user &&
        # move accesses from pi to new user
        mkdir -p ~$pi_new_user/.ssh &&
        chown $pi_new_user:$pi_new_user ~$pi_new_user/.ssh &&
        chmod 700 ~$pi_new_user/.ssh &&
        echo '$pi_authorized_keys' | tee ~$pi_new_user/.ssh/authorized_keys >/dev/null &&
        chown $pi_new_user:$pi_new_user ~$pi_new_user/.ssh/authorized_keys &&
        chmod 600 ~$pi_new_user/.ssh/authorized_keys
    else
        echo '--- Exist user: $pi_new_user ---'
    fi
    "
}


function setup_sshd_sudoers {
    echo -n "
    set -x
    echo '+++ Adapt sshd settings +++'
    set +x
    echo '$pi_sshd_config' | tee /etc/ssh/sshd_config > /dev/null
    sed -i -E 's/%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    systemctl restart sshd
    "
}


function remove_pi_user {
    echo -n "
    if [ -n '\$(getent passwd pi)' ]; then
        set -x
        echo '+++ Remove user pi +++'
        set +x
        deluser --force --remove-home pi
    else
        set -x
        echo '--- pi user already removed ---'
        set +x
    fi
    "
}


function setup_localisation {
    echo -n "
    set -x
    echo '+++ UTC, en and UTF-8 as default +++'
    set +x
    sed -ri -e 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
    echo 'LANG=de_DE.UTF-8' | sudo tee '/etc/default/locale' >/dev/null 
    echo '$pi_hostname' | tee /etc/hostname >/dev/null
    timedatectl set-timezone Europe/Berlin
    dpkg-reconfigure -f noninteractive tzdata locales
    "
}


function setup_updates {
    echo -n "
    set -x
    echo '+++ Patching and unattended upgrades (best for distributed pis) +++' 
    set +x
    apt-get -y install unattended-upgrades
    sed -ri 's/^.*Unattended-Upgrade::Automatic-Reboot.*;/Unattended-Upgrade::Automatic-Reboot \"true\";/g' /etc/apt/apt.conf.d/50unattended-upgrades
    dpkg-reconfigure -plow -f noninteractive unattended-upgrades
    apt-get -y update && apt-get -y upgrade
    apt -y autoremove
    "
}


function install_nodejs {
    echo -n "
    set -x
    echo '+++ Install NodeJS platform +++' 
    set +x
    apt-get install -y -qq --no-install-recommends ca-certificates curl git    
    # curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
    apt-get install -y nodejs
    apt-get -y update && apt-get -y upgrade
    npm install -g npm@latest
    "
}

function install_cncjs {
    echo -n "
    set -x
    echo '+++ Install CNCjs as non-root from git with updated dependencies +++' 
    set +x
    mkdir -p /home/$pi_new_user/cncin
    cp /tmp/cncrc /home/$pi_new_user/.cncrc
    mkdir -p /home/$pi_new_user/.local
    npm config set prefix /home/$pi_new_user/.local
    npm install -g cncjs
    "
}

function service_cncjs {
    echo -n "
    set -x
    echo '+++ Setup CNCjs non-root service +++' 
    set +x
    cp /tmp/cncjs@.service /etc/systemd/service/cncjs@$pi_new_user.service
    systemctl enable cncjs@$pi_new_user
    "
}



###
# As pi user, create a replacement user with
# - given, different name
# - only accessible by ssh key
# - and sudoing without password
#   (which now only prevents stupid root usage for commands)
# - and hardened ssh config (only with string ciphers)
#
# -o StrictHostKeyChecking=no      
ssh -T pi@$pi_hostname "
sudo --prompt='' -S -- /bin/bash -c \"
    $(create_user)
    $(setup_sshd_sudoers)
    pkill -u pi
    \"
"
# || echo "--- ok, pi user already inaccessible. ---"

###
# copy files and directory to tmp position for move later
scp -i $pi_keyfile \
  ${SCRIPT_DIR}/cncrc \
  ${SCRIPT_DIR}/cncjs@.service \
  $pi_new_user@$pi_hostname:/tmp

###
# with the replacement user, do different
# installations and hardenings
ssh -i $pi_keyfile $pi_new_user@$pi_hostname " 
sudo --prompt='' -S -- /bin/bash -c \"
    $(setup_localisation)
    $(setup_updates)
    ### start individual configuration
    $(install_nodejs)
    \"
"
ssh -i $pi_keyfile $pi_new_user@$pi_hostname " 
/bin/bash -c \"
    $(install_cncjs)
    \"
"
ssh -i $pi_keyfile $pi_new_user@$pi_hostname " 
sudo --prompt='' -S -- /bin/bash -c \"
    $(service_cncjs)
    ### end individual configuration
    $(remove_pi_user)
    ### reboot
    \"
"
