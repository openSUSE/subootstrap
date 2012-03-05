#!/bin/bash

ROOTFS=$1
DEV=${ROOTFS}/dev


#Disable udev
rm -rf ${DEV}
mkdir ${DEV}
mknod -m 666 ${DEV}/null c 1 3
mknod -m 666 ${DEV}/zero c 1 5
mknod -m 666 ${DEV}/random c 1 8
mknod -m 666 ${DEV}/urandom c 1 9
mkdir -m 755 ${DEV}/pts
mkdir -m 1777 ${DEV}/shm
mknod -m 666 ${DEV}/tty c 5 0
mknod -m 666 ${DEV}/tty0 c 4 0
mknod -m 666 ${DEV}/tty1 c 4 1
mknod -m 666 ${DEV}/tty2 c 4 2
mknod -m 666 ${DEV}/tty3 c 4 3
mknod -m 666 ${DEV}/tty4 c 4 4
mknod -m 600 ${DEV}/console c 5 1
mknod -m 666 ${DEV}/full c 1 7
mknod -m 600 ${DEV}/initctl p
mknod -m 666 ${DEV}/ptmx c 5 2


# copy resolv.conf from the host
cp /etc/resolv.conf $ROOTFS/etc

# mount proc sys and /dev/pts
mount -t proc none $ROOTFS/proc
mount -t sysfs none $ROOTFS/sys
mount -t devpts none $ROOTFS/dev/pts

# Generate a few needed files / directories :
touch $ROOTFS/etc/fstab
rm $ROOTFS/etc/mtab
ln -s $ROOTFS/proc/mounts /etc/mtab

# unmount proc sys and /dev/pts
mount -t proc none $ROOTFS/proc
mount -t sysfs none $ROOTFS/sys
mount -t devpts none $ROOTFS/dev/pts


cat <<EOF > $ROOTFS/config.suse
	lxc.utsname = openSUSE
	lxc.tty = 4
	lxc.network.type = veth
	lxc.network.flags = up
	lxc.network.link = br0
	lxc.network.name = eth0
	lxc.network.mtu = 1500
	lxc.network.ipv4 = 192.168.0.65/24
	lxc.rootfs = $ROOTFS
	lxc.mount = $ROOTFS/../fstab.suse
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
	# /dev/pts/* - pts namespaces are "coming soon"
	lxc.cgroup.devices.allow = c 136:* rwm
	lxc.cgroup.devices.allow = c 5:2 rwm
	# rtc
	lxc.cgroup.devices.allow = c 254:0 rwm
    EOF

cat <<EOF > $ROOTFS/fstab.suse
	none /lxc/rootfs.fedora/dev/pts devpts defaults 0 0
	none /lxc/rootfs.fedora/proc proc defaults 0 0
	none /lxc/rootfs.fedora/sys sysfs defaults 0 0
	#none /lxc/rootfs.fedora/var/lock tmpfs defaults 0 0
	#none /lxc/rootfs.fedora/var/run tmpfs defaults 0 0
	/etc/resolv.conf /lxc/rootfs.fedora/etc/resolv.conf none bind 0 0
    EOF



