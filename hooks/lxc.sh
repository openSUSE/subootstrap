#!/bin/sh
#
# lxc create
# Parameter:
#  NAME (name of the container)
#  ROOT (directory of the container)

#Color
green='\e[1;32m'
red='\e[0;31m'
normal='\033[0m'

function error
{
	suffix=$(date)
	echo -e "$red Error $1: $2 $normal"
	echo "$1::$suffix ($USER)::$2" >> lxc-logfile.log
	exit 1
}

DISTRO=12.1

configure_opensuse()
{
    rootfs=$1
    hostname=$2
    ETC=$rootfs/etc/systemd/system
   # set network as static, but everything is done by LXC outside the container
   cat <<EOF > $rootfs/etc/sysconfig/network/ifcfg-eth0
STARTMODE='auto'
BOOTPROTO='static'
EOF

   # set default route
   IP=$(/sbin/ip route | awk '/default/ { print $3 }')
   echo "default $IP - -" > $rootfs/etc/sysconfig/network/routes

   # create empty fstab
DEV="$rootfs/dev"

   touch $rootfs/etc/fstab

mknod -m 666 ${DEV}/null c 1 3
mknod -m 666 ${DEV}/zero c 1 5
mknod -m 666 ${DEV}/random c 1 8
mknod -m 666 ${DEV}/urandom c 1 9
mkdir -m 755 ${DEV}/pts
mkdir -m 1777 ${DEV}/shm
mknod -m 666 ${DEV}/tty c 5 0
mknod -m 600 ${DEV}/console c 5 1
mknod -m 666 ${DEV}/tty0 c 4 0
mknod -m 666 ${DEV}/full c 1 7
mknod -m 600 ${DEV}/initctl p
mknod -m 666 ${DEV}/ptmx c 5 2


    # create minimal /dev
#    mknod -m 666 $rootfs/dev/null c 1 3
#    mknod -m 666 $rootfs/dev/zero c 1 5
#    mknod -m 666 $rootfs/dev/random c 1 8
#    mknod -m 666 $rootfs/dev/urandom c 1 9
#    mkdir -m 755 $rootfs/dev/pts
#    mkdir -m 1777 $rootfs/dev/shm
#    mknod -m 666 $rootfs/dev/tty c 5 0
#    mknod -m 600 $rootfs/dev/console c 5 1
#    mknod -m 666 $rootfs/dev/tty0 c 4 0
#    mknod -m 666 $rootfs/dev/tty1 c 4 1
#    mknod -m 666 $rootfs/dev/tty2 c 4 2
#    mknod -m 666 $rootfs/dev/tty3 c 4 3
#    mknod -m 666 $rootfs/dev/tty4 c 4 4
#    ln -s null $rootfs/dev/tty10
#    mknod -m 666 $rootfs/dev/full c 1 7
#    mknod -m 666 $rootfs/dev/ptmx c 5 2
#    ln -s /proc/self/fd $rootfs/dev/fd
#    ln -s /proc/kcore $rootfs/dev/core
#    mkdir -m 755 $rootfs/dev/mapper
#    mknod -m 600 $rootfs/dev/mapper/control c 10 60
#    mkdir -m 755 $rootfs/dev/net
#    mknod -m 666 $rootfs/dev/net/tun c 10 200
#    mknod -m 600 $rootfs/dev/initctl p
#    mknod -m 600 $rootfs/dev/console c 5 1


for i in `systemctl --full | grep automount | awk '{print $1}'`
do
  systemctl stop $i
done


    # set the hostname
    cat <<EOF > $rootfs/etc/HOSTNAME
$hostname
EOF

    # do not use hostname from HOSTNAME variable
    cat <<EOF >> $rootfs/etc/sysconfig/cron
unset HOSTNAME
EOF

    # set minimal hosts
    cat <<EOF > $rootfs/etc/hosts
127.0.0.1 localhost $hostname
EOF

    # disable various services
    # disable yast->bootloader in container
    cat <<EOF > $rootfs/etc/sysconfig/bootloader
LOADER_TYPE=none
LOADER_LOCATION=none
EOF

    # cut down inittab
    cat <<EOF > $rootfs/etc/inittab
id:3:initdefault:
si::bootwait:/etc/init.d/boot
l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l6:6:wait:/etc/init.d/rc 6
ls:S:wait:/etc/init.d/rc S
~~:S:respawn:/sbin/sulogin
p6::ctrlaltdel:/sbin/init 6
p0::powerfail:/sbin/init 0
cons:2345:respawn:/sbin/mingetty --noclear console screen
c1:2345:respawn:/sbin/mingetty --noclear tty1 screen
EOF

    # set /dev/console as securetty
    cat << EOF >> $rootfs/etc/securetty
console
EOF

    cat <<EOF >> $rootfs/etc/sysconfig/boot
# disable root fsck
ROOTFS_FSCK="0"
ROOTFS_BLKDEV="/dev/null"
EOF


    # remove pointless services in a container
    chroot $rootfs /sbin/insserv -r -f boot.udev boot.loadmodules boot.device-mapper boot.clock boot.swap boot.klog kbd

    echo "Please change root-password !"
    echo "root:root" | chroot $rootfs chpasswd

    return 0
}

copy_configuration()
{
    path=$1
    rootfs=$2
    name=$3

    cat <<EOF >> $path/config
lxc.utsname = $name

lxc.tty = 4
lxc.pts = 1024
lxc.rootfs = $rootfs
lxc.mount  = $path/fstab

lxc.cgroup.devices.deny = a
# /dev/null and zero
lxc.cgroup.devices.allow = c 1:3 rwm
lxc.cgroup.devices.allow = c 1:5 rwm
# consoles
lxc.cgroup.devices.allow = c 5:1 rwm
lxc.cgroup.devices.allow = c 5:0 rwm
lxc.cgroup.devices.allow = c 4:0 rwm
lxc.cgroup.devices.allow = c 4:1 rwm
# /dev/{,u}random
lxc.cgroup.devices.allow = c 1:9 rwm
lxc.cgroup.devices.allow = c 1:8 rwm
lxc.cgroup.devices.allow = c 136:* rwm
lxc.cgroup.devices.allow = c 5:2 rwm
# rtc
lxc.cgroup.devices.allow = c 254:0 rwm
EOF

    cat <<EOF > $path/fstab
proc            $rootfs/proc         proc	nodev,noexec,nosuid 0 0
sysfs           $rootfs/sys          sysfs	defaults  0 0
EOF

    if [ $? -ne 0 ]; then
	error 40 "Failed to add configuration"
	return 1
    fi

    return 0
}

rootfs=$1
path="$1/.."

configure_opensuse $rootfs $name
if [ $? -ne 0 ]; then
    error 41 "Failed to configure opensuse for a container"
    exit 1
fi

copy_configuration $path $rootfs $name
if [ $? -ne 0 ]; then
    error 42 "Failed write configuration file"
    exit 1
fi
	
