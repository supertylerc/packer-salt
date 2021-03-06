function setup_yum() {
  # superylterc: We explicitly set version to 2017.7.1 due to a caching bug in
  #              2017.7.2.  Once 2017.7.3 is cut, we will upgrade.
  rpm --import https://repo.saltstack.com/yum/redhat/7/x86_64/archive/2017.7.1/SALTSTACK-GPG-KEY.pub

  readarray saltstack_repo <<'  EOF'
    [saltstack-repo]
    name=SaltStack repo for RHEL/CentOS $releasever
    baseurl=https://repo.saltstack.com/yum/redhat/$releasever/$basearch/archive/2017.7.1
    enabled=1
    gpgcheck=1
    gpgkey=https://repo.saltstack.com/yum/redhat/$releasever/$basearch/archive/2017.7.1/SALTSTACK-GPG-KEY.pub
  EOF
  printf '%s' "${saltstack_repo[@]##    }" > /etc/yum.repos.d/saltstack.repo

  yum -y clean expire-cache
  yum -y update
}

function dependencies() {
  # supertylerc: had trouble with some of these being installed during kickstart
  #              possibly due to them being unavailable from the net intsall?
  yum -y install \
    perl \
    cpp \
    libselinux-python \
    cifs-utils \
    patch \
    glibc-headers \
    glibc-devel \
    gcc \
    bzip2 \
    dkms \
    wget \
    vim \
    kernel-headers \
    kernel-devel \
    zlib-devel \
    openssl-devel \
    readline-devel
}

function guest_additions() {
  mkdir /tmp/vbox
  mount -o loop /home/vagrant/VBoxGuestAdditions_*.iso /tmp/vbox
  sh /tmp/vbox/VBoxLinuxAdditions.run
  umount /tmp/vbox
  rm /home/vagrant/VBoxGuestAdditions_*.iso
  rm -rf /tmp/vbox
}

function install() {
  # supertylerc: Install all of the Salt packages, plus `git` and
  #              `python-setuptools` so we can install `pip` and
  #              `GitPython` later.
  yum -y install \
    salt-minion \
    salt-master \
    salt-api \
    salt-ssh \
    salt-cloud \
    git \
    python-setuptools
  easy_install pip
  # supertylerc: Install GitPython so that the Salt Master can use the various
  #              git backends.
  pip install GitPython

  # supertylerc: Create some opinionated directories.
  mkdir -p /srv/salt/
  mkdir -p /srv/pillar/
  mkdir -p /etc/salt/master.d/

  # supertylerc: We can't be sure that the VM will want to be a Salt Master,
  #              so we stop it and prevent it from starting on boot.
  systemctl stop salt-master
  systemctl disable salt-master

  # supertylerc: We can be fairly certain that a minion is desired, even if this
  #              is a Salt Master.  If a minion isn't desired, the end user can
  #              always stop and disable it.
  systemctl restart salt-minion
  systemctl enable salt-minion
}

function backup() {
  # supertylerc: we use the `salt-masterless` provisioner, which may overwrite
  #              the default configs.  We back them up here and restore them
  #              later in the `cleanup.sh` script.
  cp /etc/salt/master /etc/salt/master.bak
  cp /etc/salt/minion /etc/salt/minion.bak
}

function setup_ssh_key() {
  mkdir -p /home/vagrant/.ssh/
  curl -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub
  chmod 0700 /home/vagrant/.ssh/
  chmod 0600 /home/vagrant/.ssh/authorized_keys
  chown -R vagrant:vagrant /home/vagrant/.ssh/
}

function setup_napalm() {
  echo "127.0.0.1 salt.example.com" >> /etc/hosts
  echo "127.0.0.1 salt" >> /etc/hosts

  hostnamectl set-hostname salt.example.com

  pip install napalm-base napalm-junos napalm-nxos napalm-iosxr

  firewall-cmd --permanent --zone=public --add-port=4505-4506/tcp
  firewall-cmd --reload

  hostname > /etc/salt/minion_id
}

function main() {
  local image="${1}"
  setup_ssh_key
  setup_yum
  dependencies
  guest_additions
  install
  backup
  if [[ "${image}" == "napalm" ]]; then
    setup_napalm
  fi
}

main "${1}"
