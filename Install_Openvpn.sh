#!/bin/bash

#Check whether root user is running the script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo -e "Going to install OpenVpn...\n"
echo -e  "Installing required dependencies\n"

PEM_FILE_PATH=/usr/bin/PEM/Von-Connect-Key.pem
OpenVPN_Home=/usr/local/openvpn
OpenVPN_Binary_Path=/usr/local/openvpn/sbin/openvpn
Tar_Extract_Folder=/tmp/openvpn/
OpenVPN_Version_Command="$OpenVPN_Binary_Path --version"
OpenVPN_KEY_Directory=/etc/openvpn/keys/
OpenVPN_Symlink_Path=/usr/bin/openvpn

yum install -y pam-devel gcc gcc-c++ openssl-devel lzo-devel
if [ -e ./openvpn-2.3.11.tar.gz ]; then
	echo -e "The OpenVpn souce tar is already downloaded...."
else
	wget https://swupdate.openvpn.org/community/releases/openvpn-2.3.11.tar.gz
fi

if [ -e $OpenVPN_Binary_Path ]; then
	echo "OpenVPN seems to be already installed verifying the installer and symlinks are proper or not"
	$OpenVPN_Version_Command
		if [ "$?" -eq "1" ]; then
			echo "Openvpn already is been installed at path $OpenVPN_Binary_Path"
			exit 2
		fi
else
	if [ -d $Tar_Extract_Folder ]; then
		echo "It seems OpenVpn Source has already been extracted to directory $Tar_Extract_Folder  Verifying the extract"
		Size=`du  --max-depth=0  $Tar_Extract_Folder/openvpn-2.3.11/ | awk '{print $1;}'`
		if [ $Size -eq "5792"]; then
			echo "It seems Openvpn is properly extraced continuing with Installation ..."
		else
			echo "The extract doesn't seems to be proper re-extracting"
			rm -rf $Tar_Extract_Folder
			mkdir -p $Tar_Extract_Folder
			tar -zxvf openvpn-2.3.11.tar.gz -C $Tar_Extract_Folder
		fi
	else
		mkdir -p $Tar_Extract_Folder
		tar -zxvf openvpn-2.3.11.tar.gz -C $Tar_Extract_Folder
	fi
echo -e "Begining to Install Openvpn\n"

mkdir -p $OpenVPN_Home
cd $Tar_Extract_Folder/openvpn-2.3.11/
./configure --prefix=$OpenVPN_Home
make
make install

#Check whether symlink is present or not, if not then create one
#ln -s /path/to/file /path/to/symlink
if [ -L $OpenVPN_Symlink_Path ]; then 
	echo -e "Symlink for openvpn already exsists ..."
else
	ln -s $OpenVPN_Binary_Path $OpenVPN_Symlink_Path
fi

## Check whether installation worked properly
$OpenVPN_Version_Command
if [ "$?" -eq "1" ]; then
        echo -e "Openvpn is been installed succesefully at path OpenVPN_Home\n"
#             exit 0
else
	echo "There seems to be problem in installation of OpenVPN Please remove $OpenVPN_Home and run the script again"
fi
fi

echo -e "\nChecking for keys and certificates ...\n"
## Code to Bring keys.tar from vpn server

if [ -d $OpenVPN_KEY_Directory ]; then 
	echo -e "\n $OpenVPN_KEY_Directory is present ... Checking for required client.key , client.conf ,client.crt and ca.crt files\n"
else
	mkdir -p $OpenVPN_KEY_Directory
fi


if [ -e $OpenVPN_KEY_Directory/keys.tar ]; then
	if [ [ -e $OpenVPN_KEY_Directory/ca.crt ] && [ -e $OpenVPN_KEY_Directory/client.crt ] && [ -e $OpenVPN_KEY_Directory/client.key ] && [ -e $OpenVPN_KEY_Directory/client.conf ] ]; then
		echo "\n Required keys are already present\n"
	else
		echo "\n some of the keys seems to be missing trying to Get the keys"
		cd $OpenVPN_KEY_Directory
		tar -xvf keys.tar
	fi
else
	scp -i $PEM_FILE_PATH ec2-user@54.183.191.43:/etc/openvpn/keys/keys.tar $OpenVPN_KEY_Directory
	cd  $OpenVPN_KEY_Directory
	tar -xvf  keys.tar
fi

##Clean up After Installation


 echo -e "\n Installation is complete with all instraller and configuration files in place \n"
 echo -e "\n OpenVpn Canm be connected using below Command : \n"
 echo -e "\n openvpn $OpenVPN_KEY_Directory/client.conf"
