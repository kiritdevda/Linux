#!/bin/bash

PEM_FILE_PATH=/usr/bin/PEM/Von-Connect-Key.pem
OpenVPN_Home=/usr/local/openvpn
OpenVPN_Binary_Path=/usr/local/openvpn/sbin/openvpn
Tar_Extract_Folder=/tmp/openvpn/
OpenVPN_Version_Command="$OpenVPN_Binary_Path --version"
OpenVPN_KEY_Directory=/etc/openvpn/keys/
OpenVPN_Symlink_Path=/usr/bin/openvpn
PID_FILE=/etc/openvpn/keys/pid

##Variables to add routing entry i.e this ip will will route their traffic through tunnel(tun0) rather then default device (eth0)

IP_Routed="12.0.7.6"
network_ip_vpn="10.8.0"
tunnnel_interface="tun0"

install_openvpn(){
#Check whether root user is running the script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo -e "Going to install OpenVpn...\n"
echo -e  "Installing required dependencies\n"

#PEM_FILE_PATH=/usr/bin/PEM/Von-Connect-Key.pem
#OpenVPN_Home=/usr/local/openvpn
#OpenVPN_Binary_Path=/usr/local/openvpn/sbin/openvpn
#Tar_Extract_Folder=/tmp/openvpn/
#OpenVPN_Version_Command="$OpenVPN_Binary_Path --version"
#OpenVPN_KEY_Directory=/etc/openvpn/keys/
#OpenVPN_Symlink_Path=/usr/bin/openvpn

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
	rm -rf $Tar_Extract_Folder
else
	ln -s $OpenVPN_Binary_Path $OpenVPN_Symlink_Path
	rm -rf $Tar_Extract_Folder
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
}
##Clean up After Installation

start_openvpn(){
OpenVpn_Proces=(`ps -ef | grep openvpn | grep -v grep |awk '{print $2}'`)

Number_Of_OpenVpn_Tunnels=`ifconfig | grep 10.8.0 | wc -l`

echo "Number_Of_OpenVpn_Tunnels = $Number_Of_OpenVpn_Tunnels"

Number_Of_OpenVpn_Proces="${#OpenVpn_Proces[@]}"

if [ $Number_Of_OpenVpn_Tunnels == "0" ];then
if [ -f "$OpenVPN_Binary_Path" ]; then
	echo "In start openvpn"
	$OpenVPN_Binary_Path $OpenVPN_KEY_Directory/client.conf &
	echo $!  > $PID_FILE
else
	echo "NO openvpn found at path $OpenVPN_Binary_Path "
	while true; do
   	 	read -p "Do you wish to install OpenVPN? [y/n] :" yn
    		case $yn in
        	[Yy]* ) install_openvpn
			if [ -f "$OpenVPN_Binary_Path" ];then
				$OpenVPN_Binary_Path $OpenVPN_KEY_Directory/client.conf &
				echo $!  > $PID_FILE
				break
			else
				echo "It seems Installation didn't work out"
				echo "Plaese check with System administrator"
				break
			fi;;
        	[Nn]* ) exit;;
        	* ) echo "Please answer yes or no.";;
    	esac
	done
fi
else
	echo "Already a vpn tunnel has been established"
	exit 1
fi
}

add_route(){
IP_Array=(`ifconfig  | awk '/10.8.0/{print substr($3,7)}'`)
Total_tunnels="${#IP_Array[@]}"
tunnnel_interface="tun0"
if [ $Total_tunnels == "1" ];then
			echo "`route add -host $IP_Routed gw ${IP_Array[0]} dev $tunnnel_interface`"
else
		echo "There are multiple VPN connection to same vpn server please remove all and only keep one connection active to single vpn server"
fi
}

stop_openvpn(){
echo "Stopping Openvpn ..."
OpenVpn_Proces=(`ps -ef | grep openvpn | grep -v grep |awk '{print $2}'`)

Number_Of_OpenVpn_Tunnels=`ifconfig | grep 10.8.0 | wc -l`
if [ $Number_Of_OpenVpn_Tunnels == "1" ];then
	if [ -f $PID_FILE ];then
		kill -9 "`cat $PID_FILE`"
		rm -f $PID_FILE
	else
		echo "Openvpn process is runnig however pid file is missing "
		echo "try to kill the openvpn process manually"
	fi
else
	echo "OpenVpn is not running"
fi
}

usage(){
echo ""
echo "[start | --start]  	to start openvpn"
echo "[stop | --stop] 		to stop openvpn"
echo "[install | --install] 	to install openvpn"
echo "[help | --help | -help] 	for help "
echo ""
echo "EXAMPLE:"
echo -e "./Install_Openvpn --start to start openvpn\n"
}

if [ "$1" != "" ]; then
    case $1 in
        install | --install )   install_openvpn
                                ;;
        start | --start )    start_openvpn
				sleep 15
                                add_route
                                ;;
        help | --help | -help )           usage
                                exit
                                ;;
	stop | --stop )		stop_openvpn
				;;
        * )                     usage
                                exit 1
    esac
    shift
else
	echo -e "\nPlease provide parameter"
	usage
fi

