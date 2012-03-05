#!/bin/sh
#
# subootstrap
#

VERSION="0.0.1(alpha)"

#Color
green='\e[1;32m'
red='\e[0;31m'
normal='\033[0m'

#Standard Variables
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=`dirname "$SCRIPT"`


failed="$red[failed]$normal"
don="$green[done]$normal"
config="tmp/config.tmp"

arch="x86"

function help
{
	echo "Usage: subootstrap SID [path]"
	echo "	-h	Use userscript"
	echo "	-A 	Set the architecture of the new System [x86 or x86_64]"
	exit 1
}

function version
{
	echo "subootstrap version $VERSION"
	exit 1
}

function error
{
	suffix=$(date)
	echo -e "$red Error $1: $2 $normal"
	echo "$1::$suffix ($USER)::$2" >> logfile.log
	clean
}

function clean
{
	sudo rm -rf $build
}


options=$(getopt -o h,A,p -l hook,arch,path: -- "$@")

SID=$1
path=$2

echo $SID

if [ "$SID" = "" ]; then
	error 10 "SID command is miss."
	exit 1
fi

#Check if OS Build exist local
echo -en "Checking system..."

os="/usr/share/kiwi/image/vmxboot/suse-$SID"

if [ ! -d "$os" ]; then
	echo -e "$failed"
	error 20 "This version of openSUSE ist not supported."
	exit 1
fi

echo -e "$don"

echo -en "Build filesystem..."

if [ "$path"!= "" ]; then
	mkdir -p $path/suse-$SID
	build=$path/suse-$SID
else	
	build=$(mktemp -d)
fi

if [ "$arch" != "x86" ]; then
	setarch="--target-arch $arch"
fi

sudo kiwi --prepare $os --root $build $setarch

if [ $? -ne 0 ]; then
	echo -e $failed
	error 30 "kiwi has thrown an error. You may need higher permission. For more use --help"
	exit 1
fi


echo -e $don

name="openSUSE-$SID-$arch"

if [ "$hook" != "" ]; then
	echo -en "Use hook script..."

	DPID=$(bash $SCRIPTPATH/hooks/$hook.sh $build)

	if [ "$DPID" != "" ]; then
		echo -e $failed	
		exit 1
	fi

	echo -e $don
fi
