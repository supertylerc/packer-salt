#!/bin/bash -eux

function clean_yum() {
  yum -y remove \
    cpp \
    kernel-devel \
    kernel-headers
  yum clean all
  rm -rf /var/cache/yum
}

function zero() {
  # Zero out the rest of the free space using dd, then delete the written file.
  dd if=/dev/zero of=/EMPTY bs=1M
  rm -f /EMPTY

  # Add `sync` so Packer doesn't quit too early, before the large file is deleted.
  sync
}

function restore_configs() {
  mv /etc/salt/master.bak /etc/salt/master
  mv /etc/salt/minion.bak /etc/salt/minion
}

function clean_salt() {
  rm -rf /etc/salt/master.d/*
  rm -rf /srv/salt/*
  rm -rf /srv/pillar/*
}

function finalize_napalm() {
  systemctl restart salt-master
  systemctl enable salt-master
}

function main() {
  clean_yum
  clean_salt
  restore_configs
  if [[ "${1}" == "napalm" ]]; then
    finalize_napalm
  fi
  zero
}

main "${1}"
