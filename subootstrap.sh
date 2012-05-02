#!/bin/bash/

#ubootstrap
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
echo "Usage: subootstrap SID [path] [-h] [-A]"
echo " SID Version of the openSUSE OS"
echo " path Path where the filesystem should be stored"
echo " -h Use userscript"
echo " -A Set the architecture of the new System [x86 or x86_64]"
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

if [ "$1" = "-l" ]; then
kiwi -l
  exit 1
fi

SID=$1
shift

path=$1
shift

while getopts h:A:l o
do case "$o" in
h ) hook="$OPTARG";;
A ) arch="$OPTARG";;
esac
done

echo $hook

if [ "$SID" = "" ]; then
error 10 "SID command is miss."
exit 1
fi

echo -e "Build filesystem..."

name="suse-$SID"

if [ -d "$path/$name" ]; then
while answer != y||n
do
echo -e "Directory already exist. Override this folder? (y/n)"
read answer
done
if [ "$answer" = "n" ]; then
echo -en "New name for the folder: "
read name
fi
fi


if [ "$path" != "" ]; then
mkdir -p $path/$name
build="$path/$name"
else
build=$(mktemp -d)
fi


if [ "$arch" != "x86" ]; then
setarch="--target-arch $arch"
fi

sudo kiwi --prepare suse-$SID --root $build $setarch

if [ $? -ne 0 ]; then
echo -e $failed
error 30 "kiwi has thrown an error. You may need higher permission. For more use --help"
exit 1
fi


echo -e "Build filesystem...$don"

name="openSUSE-$SID-$arch"

if [ "$hook" != "" ]; then

echo -e "Use hook script..."

bash $SCRIPTPATH/hooks/$hook.sh $build/../cache opensuse-$SID $build

if [ $? -ne 0 ]; then
echo -e $failed
exit 1
fi

echo -e "Use hook script...$don"
fi