#!/bin/bash



configure_opensuse()
{
    rootfs=$1
    hostname=$2

   # set network as static, but everything is done by LXC outside the container
   cat <<EOF > $rootfs/etc/sysconfig/network/ifcfg-eth0
STARTMODE='auto'
BOOTPROTO='static'
EOF

   # set default route
   IP=$(/sbin/ip route | awk '/default/ { print $3 }')
   echo "default $IP - -" > $rootfs/etc/sysconfig/network/routes

   # create empty fstab
   touch $rootfs/etc/fstab

    # create minimal /dev
    mknod -m 666 $rootfs/dev/random c 1 8
    mknod -m 666 $rootfs/dev/urandom c 1 9
    mkdir -m 755 $rootfs/dev/pts
    mkdir -m 1777 $rootfs/dev/shm
    mknod -m 666 $rootfs/dev/tty c 5 0
    mknod -m 600 $rootfs/dev/console c 5 1
    mknod -m 666 $rootfs/dev/tty0 c 4 0
    mknod -m 666 $rootfs/dev/tty1 c 4 1
    mknod -m 666 $rootfs/dev/tty2 c 4 2
    mknod -m 666 $rootfs/dev/tty3 c 4 3
    mknod -m 666 $rootfs/dev/tty4 c 4 4
    ln -s null $rootfs/dev/tty10
    mknod -m 666 $rootfs/dev/full c 1 7
    mknod -m 666 $rootfs/dev/ptmx c 5 2
    ln -s /proc/self/fd $rootfs/dev/fd
    ln -s /proc/kcore $rootfs/dev/core
    mkdir -m 755 $rootfs/dev/mapper
    mknod -m 600 $rootfs/dev/mapper/control c 10 60
    mkdir -m 755 $rootfs/dev/net
    mknod -m 666 $rootfs/dev/net/tun c 10 200

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
    chroot $rootfs /sbin/insserv -no-reload -r -f boot.udev boot.loadmodules boot.device-mapper boot.clock boot.swap boot.klog kbd


    return 0
}

install_opensuse()
{
    cache="$1"

 
    mkdir $cache/partial-packages
 
    zypper --quiet --root $cache --non-interactive --gpg-auto-import-keys update
    zypper refresh
    zypper --root $cache --reposd-dir $cache/etc/zypp/repos.d --non-interactive in --auto-agree-with-licenses --download-only lxc patterns-openSUSE-base sysvinit-init

    cat > $cache/opensuse.conf << EOF
Preinstall: aaa_base bash coreutils diffutils
Preinstall: filesystem fillup glibc grep insserv libacl1 libattr1
Preinstall: libbz2-1 libgcc46 libxcrypt libncurses5 pam
Preinstall: permissions libreadline6 rpm sed tar zlib libselinux1
Preinstall: liblzma5 libcap2 libpcre0
Preinstall: libpopt0 libelf1 liblua5_1

RunScripts: aaa_base

Support: zypper
Support: patterns-openSUSE-base
Support: lxc
Prefer: sysvinit-init

Ignore: patterns-openSUSE-base:patterns-openSUSE-yast2_install_wf
EOF
 

   CLEAN_BUILD=1 BUILD_ROOT="$cache" BUILD_DIST="$cache/opensuse.conf" /usr/lib/build/init_buildsystem --clean --cachedir $cache/partial-packages --repository $cache/var/cache/zypp/packages/repo-oss/suse/$arch --repository $cache/var/cache/zypp/packages/repo-oss/suse/noarch
    

#chroot $cache zypper --quiet --non-interactive ar http://download.opensuse.org/distribution/$DISTRO/repo/oss repo-oss
zypper --root $cache --quiet --non-interactive ar http://download.opensuse.org/distribution/$DISTRO/repo/oss repo-oss

    #zypper --root $cache --quiet --non-interactive ar http://download.opensuse.org/update/$DISTRO/ update
    chroot $cache rpm -e patterns-openSUSE-base
    umount $cache/proc
# really clean the image
    rm -fr $cache/{.build,.guessed_dist,.srcfiles*,installed-pkg}
    rm -fr $cache/dev
# make sure we have a minimal /dev
    mkdir -p "$cache/dev"
    mknod -m 666 $cache/dev/null c 1 3
    mknod -m 666 $cache/dev/zero c 1 5
# create mtab symlink
    rm -f $cache/etc/mtab
    ln -sf /proc/self/mounts $cache/etc/mtab

if [ $? -ne 0 ]; then
 echo "Failed to download the rootfs, aborting."
	return 1
fi

rm -fr "$cache"
    mv "$1" "$1/rootfs"
    echo "Download complete."

    return 0
}


copy_configuration()
{
    path=$1
    rootfs=$2
    name=$3

    mkdir $path

    cat > $path/config << EOF
lxc.utsname = $name

lxc.tty = 4
lxc.pts = 1024
lxc.rootfs = $rootfs
lxc.mount = $path/fstab

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

    cat > $path/fstab << EOF
proc $rootfs/proc proc nodev,noexec,nosuid 0 0
sysfs $rootfs/sys sysfs defaults 0 0
EOF

if [ $? -ne 0 ]; then
	echo "Failed to add configuration"
	return 1
fi

return 0
}

clean()
{
    cache="/var/cache/lxc/opensuse"

    if [ ! -e $cache ]; then
exit 0
    fi

    # lock, so we won't purge while someone is creating a repository
    (
flock -n -x 200
if [ $? != 0 ]; then
echo "Cache repository is busy."
exit 1
fi

echo -n "Purging the download cache..."
rm --preserve-root --one-file-system -rf $cache && echo "Done." || exit 1
exit 0

    ) 200>/var/lock/subsys/lxc
}

usage()
{
    cat <<EOF
$1 -h|--help -p|--path=<path> --clean
EOF
    return 0
}

rootfs=$3
path=$1
name=$2

#declare -a arc
#arc=(`echo ${2//./}`} # | tr "-" " "`)
#DISTRO=${$arc[0]}
#eval set -- "$options"


#type zypper > /dev/null
#if [ $? -ne 0 ]; then
#echo "'zypper' command is missing"
#    exit 1
#fi

if [ -z "$path" ]; then
    echo "'path' parameter is required"
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
echo "This script should be run as 'root'"
    exit 1
fi


install_opensuse $path
if [ $? -ne 0 ]; then
echo "failed to install opensuse"
    exit 1
fi

configure_opensuse $rootfs $name
if [ $? -ne 0 ]; then
echo "failed to configure opensuse for a container"
    exit 1
fi


copy_configuration $path $rootfs $name
if [ $? -ne 0 ]; then
echo "failed write configuration file"
    exit 1
fi

if [ ! -z $clean ]; then
clean || exit     exit 0
fi