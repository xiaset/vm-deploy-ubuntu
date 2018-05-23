#!/bin/bash
set +e
usage()
{
cat << EOF
usage: $0 options
This script run the test1 or test2 over a machine.
OPTIONS:
   --mem
   --cpu
   --disk
   --ip
   --mask
   --gw
   --dns
   --br
   --vmname
   --erp
   --vg
EOF
}
OPTS=`getopt -o h --long mem:,cpu:,disk:,ip:,mask:,gw:,dns:,br:,vmname:,erp:,vg:,help -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"
while true; do
  case "$1" in
    --mem ) MEMORY="$2"; shift; shift ;;
    --cpu ) CPU="$2"; shift; shift ;;
    --disk ) DISK="$2"; shift; shift ;;
    --ip) IPADDR="$2"; shift; shift ;;
    --mask) NETMASK="$2"; shift; shift ;;
    --gw) GATEWAY="$2"; shift; shift ;;
    --dns) DNS="$2"; shift; shift ;;
    --br) BRIDGE="$2"; shift; shift ;;
    --vmname) VM_NAME="$2"; shift; shift ;;
    --erp) ENCRYPTED_ROOT_PASSWORD="$2"; shift; shift ;;
    --vg) VG="$2"; shift; shift ;;
    -h | --help) usage; shift;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done
test -z "$MEMORY" && echo "Option --mem required" && exit 1
test -z "$CPU" && echo "Option --cpu required" && exit 1
test -z "$DISK" && echo "Option --disk required" && exit 1
test -z "$IPADDR" && echo "Option --ip required" && exit 1
test -z "$NETMASK" && echo "Option --mask required" && exit 1
test -z "$GATEWAY" && echo "Option --gw required" && exit 1
test -z "$DNS" && echo "Option --dns required" && exit 1
test -z "$BRIDGE" && echo "Option --br required" && exit 1
test -z "$VM_NAME" && echo "Option --vmname required" && exit 1
test -z "$ENCRYPTED_ROOT_PASSWORD" && echo "Option --erp (encrypted root password) required" && exit 1
test -z "$VG" && echo "Option --vg required" && exit 1
TEMPFILE=`mktemp -d`
SKIP=`awk '/^__SEEDFILE__/ { print NR + 1; exit 0; }' $0`
THIS=`pwd`/$0
tail -n +$SKIP $THIS > $TEMPFILE/preseed.cfg
virsh vol-create-as $VG $VM_NAME-disk0 $DISK
virt-install -d --name=$VM_NAME --ram $MEMORY --vcpus $CPU --cpu host-passthrough --disk vol=$VG/$VM_NAME-disk0,bus=virtio,cache=none,format=raw --network bridge=$BRIDGE,model=virtio --vnc --vnclisten="0.0.0.0" --accelerate --location=http://mirror.neolabs.kz/ubuntu/dists/xenial-updates/main/installer-amd64/ --extra-args="auto=true text file=file:/preseed.cfg passwd/root-password-crypted=$ENCRYPTED_ROOT_PASSWORD netcfg/get_ipaddress=$IPADDR netcfg/get_netmask=$NETMASK netcfg/get_gateway=$GATEWAY netcfg/get_nameservers=$DNS netcfg/disable_autoconfig=true netcfg/get_hostname=$VM_NAME" --initrd-inject $TEMPFILE/preseed.cfg
virsh autostart $VM_NAME
rm -r $TEMPFILE
exit 0
__SEEDFILE__
## Options to set on the command line
d-i debian-installer/locale string en_US.UTF-8
d-i console-setup/ask_detect boolean false
d-i console-setup/layout string USA
d-i localechooser/supported-locales en_US.UTF-8 ru_RU.UTF-8
#d-i debian-installer/language string en
#d-i debian-installer/country string RU
d-i netcfg/confirm_static boolean true
d-i time/zone string Etc/UTC
d-i clock-setup/utc-auto boolean true
d-i clock-setup/utc boolean true
d-i kbd-chooser/method select American English
d-i base-installer/kernel/override-image string linux-server
d-i debconf debconf/frontend select Noninteractive
d-i pkgsel/install-language-support boolean false
tasksel tasksel/first multiselect
d-i partman-auto/disk string /dev/vda
d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
#d-i partman-lvm/device_remove_lvm_span boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto-lvm/guided_size string max
d-i partman-auto-lvm/new_vg_name string system
d-i partman-auto/choose_recipe select custom-lvm
d-i partman-auto/expert_recipe string custom-lvm :: \
100 700 512 ext2 $primary{ } $bootable{ } method{ format } format{ } use_filesystem{ } filesystem{ ext2 } mountpoint{ /boot } . \
100 600 18432 lvm $defaultignore{ } $primary{ } device{ /dev/vda2 } method{ lvm } vg_name{ system } . \
100 500 8192 ext4 $lvmok{ } in_vg{ system } method{ lvm } format{ } use_filesystem{ } filesystem{ ext4 } mountpoint{ / } . \
100 400 512 linux-swap lv_name{ swap } $lvmok{ } in_vg{ system } method{ swap } format{ } . \
100 300 1024 ext4 $lvmok{ } in_vg{ system } method{ lvm } format{ } use_filesystem{ } filesystem{ ext4 } mountpoint{ /tmp } . \
100 200 -1 ext4 $lvmok{ } in_vg{ system } method{ lvm } format{ } use_filesystem{ } filesystem{ ext4 } mountpoint{ /var } . \
100 100 -1 lvm $defaultignore{ } $primary{ } device{ /dev/vda3 } method{ lvm } vg_name{ shared } .
# This makes partman automatically partition without confirmation, provided
# that you told it what to do using one of the methods above.
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_new_label boolean true
d-i partman/confirm_nooverwrite boolean true
# The default is to mount by UUID, but you can also choose "traditional" to
# use traditional device names, or "label" to try filesystem labels before
# falling back to UUIDs.
d-i partman/mount_style select traditional
# Default user, change
d-i passwd/root-login boolean true
d-i passwd/make-user boolean false
d-i user-setup/encrypt-home boolean false
d-i user-setup/allow-password-weak boolean true
## minimum is puppet and ssh and ntp
# Individual additional packages to install
d-i pkgsel/include string openssh-server ntp rsync less vim ethtool curl strace
# Whether to upgrade packages after debootstrap.
# Allowed values: none, safe-upgrade, full-upgrade
d-i pkgsel/upgrade select full-upgrade
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i finish-install/reboot_in_progress note
#For the update
d-i pkgsel/update-policy select none
# debconf-get-selections --install
#Use mirror
d-i apt-setup/use_mirror boolean true
d-i mirror/country string manual
choose-mirror-bin mirror/protocol string http
choose-mirror-bin mirror/http/hostname string mirror.neolabs.kz
choose-mirror-bin mirror/http/directory string /ubuntu
choose-mirror-bin mirror/suite select xenial
choose-mirror-bin mirror/http/proxy string
#d-i mirror/suite string xenial
#d-i mirror/protocol string http
#d-i mirror/http/hostname string http://mirror.neolabs.kz
#d-i mirror/http/directory string /ubuntu
#d-i mirror/http/proxy string
d-i preseed/late_command   string  echo d-i netcfg/get_ipaddress string \
			$(ip addr | grep 'inet ' | grep global | cut -d ' ' -f 6 | sed 's/\/.*//') \
			> /tmp/static_net.cfg && \
			debconf-set-selections /tmp/static_net.cfg && \
			echo d-i netcfg/disable_autoconfig boolean true > /tmp/static_net.cfg && \
			debconf-set-selections /tmp/static_net.cfg && kill-all-dhcp; netcfg; \
			in-target sed -i s/PermitRootLogin\ prohibit\-password/PermitRootLogin\ yes/ /etc/ssh/sshd_config;
