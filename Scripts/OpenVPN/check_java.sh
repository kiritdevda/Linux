#!/bin/bash


##The config file where we specifiy the property which hold the java executable path


## The JAVA_VERSION variable has hold the value for java version
## this value must exactly match to version present when you hit java -version of the
## desired java you whish your application to run on. This script will filter out all
## other java version and let the application use the java version you have specified ## in JAVA_VERSION variable.
##BE VERY SPECIFIC WHILE YOU PROVIDE JAVA_VERSION VARIABLE A VALUE
## EXAMPLE:
## [root@ip-0.0.0.0 ~]# java -version
##
## O/P
##
## java version "1.7.0_80-ea"
## Java(TM) SE Runtime Environment (build 1.7.0_80-ea-b05)
## Java HotSpot(TM) 64-Bit Server VM (build 24.80-b07, mixed mode)
##
## In above we see that when we display java -version then we should provide java version in line one as it is with " "(Quotes)  " i.e like
## JAVA_VERSION="\"1.7.0_80-ea\""  and not like JAVA_VERSION="1.7.0_80-ea" as now " are not preserved
## back-slash is used to presereve "
## To Let user choose the version without any hard requirenment of version specifiy
## JAVA_VERSION=" "

JAVA_VERSION="\"1.7.0_80-ea\""

## To Let user choose the version without any hard requirenment of version to specifiy
## in script , hence the script will ask user to choose one of the java from available##  list of java present
 JAVA_VERSION=" "

## The script allows changes to property files properties as well 
## If we set CONFIG_FILE_CHANGES to 1 then the script uses values of PATH_CONFIG_FILE 
## to locate the path of configuration file  and replace the PROPERTY parameter in 
## config file to path of java executable found from script

CONFIG_FILE_CHANGES=1

## It contains the path of configuration file which hods a property which points to java executable. Using this script you can replace this PROPERTY value to java executable path pointing to the java version you would have set/choose in JAVA_VERSION variable
PATH_CONFIG_FILE="moofwd-push.cnf"

## The PROPERTY variable is name of the property in the PATH_CONFIG_FILE property file## which holds the path of executable that the application will use moving forward
## If property is already set but holds some other value  this script will over-ride
## the value to the path of java excutable found from script given the java version to be used

PROPERTY="PUSH_JAVA"

echo -e "Finding compaitable java.../n"

check_java(){
java_paths=(`find / -name java | while read -r line ;do 
if [ -f $line ];then 
	if [ -x $line ]; then 
		echo $line;
	fi;
fi;
done`)
#echo ${java_paths[0]}

Compatiable_Java=(`
for i in "${java_paths[@]}";do
		version="\`$i -version 2>&1 | awk '/version/{print $NF}'\`";
###Check it is not OpenJdk java
if [ "$JAVA_VERSION" != " " ];then
if [ "$version" == $JAVA_VERSION ]; then
	if [ -f $i ]; then
		if [ -h $i ];then
			printf "";
		else
			echo "$i";
		fi;
	fi;
else
	printf "";
fi;
else
	echo "$i";
fi;
done`)

#echo "Length of array : ${Compatiable_Java[@]}"

if [ "${#Compatiable_Java[@]}" -le "2" ]; then
for java_path in "${Compatiable_Java[@]}"
do
        JRE=`echo $java_path | grep "jre/bin/java" | wc -l`
        if [ "$JRE" == "1" ];then
                echo -e "Required Java_Version found at $java_path: Setting JRE_HOME to $java_path"
		JRE_JAVA_HOME="$java_path"
	
        fi
done
fi

if [ "$JRE_JAVA_HOME" == "" ];then
        Menu_Length="`expr ${#Compatiable_Java[@]} + 1`"
        echo -e "\n Cannot determine which java to set as default java for zubron please choose one which you would like zubron to run on\n"
        counter=0
        choice=0
        while true;do
                echo -e "\nChoose a Java Version which you want zubron to run on\n"
                echo "Press `expr ${#Compatiable_Java[@]} + 1` to exit "
                for java_path in "${Compatiable_Java[@]}"
                do
                        counter=`expr $counter + 1`
			RED='\033[0;35m'
			NC='\033[0m'
			jav_version=`$java_path -version 2>&1 | awk '/version/'`
                        echo -e "$counter. $java_path  ${RED}$jav_version${NC}"
                done
        read choice
        echo "choice is $choice"
        if [ "$choice" -le "$Menu_Length" ] && [ "$choice" -gt "0" ]; then
                 if [ "$choice" == "$Menu_Length" ];then
                        echo -e "Exiting..."
                        break
                else
                        choice=`expr $choice - 1`
                        JRE_JAVA_HOME=${Compatiable_Java[$choice]}
                        break
                fi
        fi
        counter=0
        done
fi

if [ "$JRE_JAVA_HOME" == "" ];then
        echo "Not able to set java... please download java from zubron at https://s3-us-west-2.amazonaws.com/moofwd-softwares/java7.zip and extract it"
	return 1
else
	return 0
fi
}

change_config(){
if [ -f $PATH_CONFIG_FILE ];then
line_number=(`cat -n $PATH_CONFIG_FILE | grep PUSH_JAVA | awk '{print $1;}'`)
JRE_HOME=`dirname $JRE_JAVA_HOME`
Insert="$PROPERTY=$JRE_HOME/java"
Line_number_length=${#line_number}
	if [ "$Line_number_length" != "0" ];then
		last_occurence="${line_number[-1]}"
			if [ "$last_occurence" != "" ];then
				sed -i "${last_occurence}d" $PATH_CONFIG_FILE
				file_length=`cat $PATH_CONFIG_FILE | wc -l`
				if [ "$file_length" -lt "$last_occurence" ];then
					echo "Setting $PROPERTY in $PATH_CONFIG_FILE to $Insert"
					echo "$Insert" >> $PATH_CONFIG_FILE
				else
					sed -i "${last_occurence}i $Insert" $PATH_CONFIG_FILE
				fi
			fi
	fi
else
	echo "Not able to find moofwd-push.cnf in current directory"
fi
}


check_java
if [ "$?" == "1" ]; then
	exit 1
else
	if [ -f $JRE_JAVA_HOME ];then
		JRE_HOME=`dirname $JRE_JAVA_HOME`
		export JRE_HOME=$JRE_HOME
		if [ "$CONFIG_FILE_CHANGES" == "1" ];then
			change_config
		fi
	fi
fi

