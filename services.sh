#!/bin/bash

MAINSAIL_RELEASE="2.0.1"
FLUIDD_RELEASE="1.16.2"

DEFAULT_INTERFACE="fluidd"
#DEFAULT_INTERFACE="mainsail"

########### end of configuration ##################

DEFAULT_INTERFACE_NAME=$DEFAULT_INTERFACE
DEFAULT_INTERFACE_DIR=$DEFAULT_INTERFACE

[[ $DEFAULT_INTERFACE = "fluidd" ]] && DEFAULT_INTERFACE_RELEASE=$FLUIDD_RELEASE || DEFAULT_INTERFACE_RELEASE=$MAINSAIL_RELEASE
[[ $DEFAULT_INTERFACE = "fluidd" ]] && DEFAULT_INTERFACE_URL="https://github.com/cadriel/fluidd/releases/download/v${DEFAULT_INTERFACE_RELEASE}/${DEFAULT_INTERFACE_DIR}.zip"\
				     || DEFAULT_INTERFACE_URL="https://github.com/meteyou/mainsail/releases/download/v${DEFAULT_INTERFACE_RELEASE}/${DEFAULT_INTERFACE_DIR}.zip"

ACTIONS=("init" "refresh" "build" "klipper-init" "klipper-config" "start" "stop" "restart" "logs")

show_usage() {
	echo "usage: $0 <action> [parameters]" 
	echo "available actions: "
	for i in ${ACTIONS[@]}; do
		echo " " $i" "
	done
	echo ""
	
}

set_variables() {
	PRINTER_CGROUP="'c 188:* rmw'"
	SENSORS_CGROUP="'c 166:* rmw'"
	WEBCAM_CGROUP="'c 81:* rmw'"
	PRINTER_ACCESS="-v /dev:/dev --device-cgroup-rule=$PRINTER_CGROUP --device-cgroup-rule=$SENSORS_CGROUP --device-cgroup-rule=$WEBCAM_CGROUP"
	LOG_MOUNT="--mount type=bind,source=$(pwd)/runtime/logs,target=/logs"
	SDCARD_MOUNT="--mount type=bind,source=$(pwd)/runtime/sdcard,target=/sdcard"
	TMP_MOUNT="--mount type=bind,source=$(pwd)/runtime/tmp,target=/tmp"
	MOONRAKER_MOUNT="--mount type=bind,source=$(pwd)/runtime/config,target=/moonraker/config"
	KLIPPER_MOUNT="--mount type=bind,source=$(pwd)/runtime/config,target=/klipper/config"
	USERID=$(id -u)
	GROUPID=$(id -g)
	USER_ARGS="--user $UID:$GID"
	BUILD_ARGS="--build-arg UID=$USERID --build-arg GID=$GROUPID"
}

check_and_update(){	
	echo -n "checking for klipper source ..."
	[ -d "klipper_docker/klipper" ] \
		&& echo -n "present, refreshing..." && git pull>/dev/null 
	echo "done"

	echo -n "checking for moonraker source ..."
	[ -d "moonraker_docker/moonraker" ] \
		&&  echo -n "present, refreshing..." \
		&& git pull>/dev/null 
	echo "done"

	echo -n "checking for ${DEFAULT_INTERFACE_NAME} source ..."
	[ -d "${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR}" ] \
		&&  echo -n "present, refreshing..." \
		&& wget -q -O ${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR}.zip ${DEFAULT_INTERFACE_URL} >/dev/null\
		&& echo -n "... unzipping ..." \
		&& unzip -d ${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR} -o ./${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR}.zip >/dev/null
	echo "done"
}

check_and_download() {
	echo -n "checking for klipper source ..."
	[ ! -d "klipper_docker/klipper" ] \
		&& echo -n "not present, cloning..." && git clone https://github.com/KevinOConnor/klipper.git klipper_docker/klipper>/dev/null 
	echo "done"

	echo -n "checking for moonraker source ..."
	[ ! -d "moonraker_docker/moonraker" ] \
		&&  echo -n "not present, cloning..." \
		&& git clone https://github.com/Arksine/moonraker.git moonraker_docker/moonraker>/dev/null 
	echo "done"

	echo -n "checking for ${DEFAULT_INTERFACE_NAME} source ..."
	[ ! -d "${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR}" ] \
		&&  echo -n "not present, downloading..." \
		&& wget -O ${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR}.zip ${DEFAULT_INTERFACE_URL} >/dev/null\
		&& echo -n "... unzipping ..." \
		&& unzip -d ${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR} -o ./${DEFAULT_INTERFACE_DIR}_docker/${DEFAULT_INTERFACE_DIR}.zip >/dev/null
	echo "done"
}

build_klipper() { 
	echo "Building klipper"
	docker build $BUILD_ARGS ./klipper_docker -t klipper
}

build_moonraker() { 
	echo "building moonraker"
	docker build $BUILD_ARGS ./moonraker_docker -t moonraker
}

build_ui() { 
	echo "Building ${DEFAULT_INTERFACE_NAME}:"
	docker build ./${DEFAULT_INTERFACE_DIR}_docker -t ${DEFAULT_INTERFACE_DIR}
}

create_network(){
	docker network create --subnet=172.18.0.0/26 klipmoonsail
}

klipper_init() {
	echo "running only klipper for first-time config and flashing" 
	eval "docker run -it --rm --name klipper-build $PRINTER_ACCESS klipper /bin/bash"
}

klipper_config() {
	echo "running a shell for klipper configuring and flashing" 
	eval "docker run -it --rm --name klipper-build $PRINTER_ACCESS $LOG_MOUNT $TMP_MOUNT $SDCARD_MOUNT $KLIPPER_MOUNT klipper /bin/bash"
}

start_klipper() {
	echo -n "Starting klipper ... "
	COMMAND="docker run --rm -d --name klipper $PRINTER_ACCESS $USER_ARGS $LOG_MOUNT $TMP_MOUNT $SDCARD_MOUNT $KLIPPER_MOUNT \
		--net klipmoonsail --hostname klipper.local --ip 172.18.0.23 klipper"
	echo $COMMAND
	eval "$COMMAND"
	echo done
}
start_moonraker() {
	echo -n "Starting moonraker ... "
	docker run --rm -d --name moonraker \
		$USER_ARGS $LOG_MOUNT $TMP_MOUNT $SDCARD_MOUNT $MOONRAKER_MOUNT \
		--net klipmoonsail  --hostname apiserver.local --ip 172.18.0.22 moonraker 
	echo done
}

start_ui() {
	echo -n "Starting ${DEFAULT_INTERFACE_NAME} ... "
	docker run --rm -d --name ${DEFAULT_INTERFACE_DIR} -p 8080:80 --net klipmoonsail  --hostname ${DEFAULT_INTERFACE_DIR}.local --ip 172.18.0.21  ${DEFAULT_INTERFACE_DIR} 
	echo done
}	

action_logs () {
	tail -f runtime/logs/*log
}

action_run(){
	if [[ "$#" -eq "0" ]]; then
		echo "no container specified, running all"
		start_klipper
		start_moonraker
		start_ui
		exit	
	fi
	while [[ 0 -lt $#  ]]; do
		if [[ "$1" == "klipper" ]]; then
			start_klipper
		elif [[ "$1" == "ui" ]]; then
			start_ui
		elif [[ "$1" == "moonraker" ]]; then
			start_moonraker
		else
			echo "ERROR: invalid container name: $1"
			show_usage
		fi
		shift
	done
	exit
}

action_build() {
	echo "building image(s)"
	
	if [[ "$#" -eq "0" ]]; then
		echo "no container specified, building all"
		build_klipper
		build_moonraker
		build_ui
		exit	
	fi
	while [[ 0 -lt $#  ]]; do
		if [[ "$1" == "klipper" ]]; then
			build_klipper
		elif [[ "$1" == "ui" ]]; then
			build_ui
		elif [[ "$1" == "moonraker" ]]; then
			build_moonraker
		else
			echo "ERROR: invalid container name: $1"
			show_usage
		fi
		shift
	done
	exit

}


action_init() {
	check_and_download
	build_klipper
	create_network
	klipper_init
	echo "if all is correct, you should be able to run klipmoonsail now: $0 run"
}

action_stop(){
	for i in "klipper" "moonraker"; do
		echo -n "stopping $1: "
		docker stop $i
	done
	
	echo -n "stopping ui: "
	docker stop $DEFAULT_INTERFACE_DIR
}

action_restart(){
	action_stop
	start_klipper
	start_moonraker
	start_ui
}

if [[ $# -lt 1 ]]; then
	show_usage
	exit 1
fi
ACTION=$1
shift
PARAMETERS=$*

if [[ " ${ACTIONS[@]} " =~ " ${ACTION} " ]]; then
	
	set_variables
	if [[ "refresh" == "$ACTION" ]]; then
		check_and_update
	fi
	if [[ "init" == "$ACTION" ]]; then
		action_init $PARAMETERS
	fi
	if [[ "start" == "$ACTION" ]]; then
		action_run $PARAMETERS
	fi
	if [[ "build" == "$ACTION" ]]; then
		action_build $PARAMETERS
	fi
	if [[ "klipper-init" == "$ACTION" ]]; then
		klipper_init $PARAMETERS
	fi
	
	if [[ "klipper-config" == "$ACTION" ]]; then
		klipper_config $PARAMETERS
	fi
	if [[ "stop" == "$ACTION" ]]; then
		action_stop
	fi
	if [[ "start" == "$ACTION" ]]; then
		action_start $PARAMETERS
	fi
	if [[ "restart" == "$ACTION" ]]; then
		action_restart
	fi
	if [[ "logs" == "$ACTION" ]]; then
		action_logs
	fi
fi


echo "all done"

