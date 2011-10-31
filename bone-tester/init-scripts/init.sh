#!/bin/bash

# BeagleBone automatic tester
# 
# This script should run automatically during init and run a setup of sub tasks
# each of which will test a specific component of the board.
# It is expected to be run with the board plugged into the test board.
# Test results should be displayed and/or reported to the testboard through GPIO

BONETESTER_DIR=/var/lib/bone-tester/
COMPONENT_DIR=${BONETESTER_DIR}/component/
LIB_DIR=${BONETESTER_DIR}/lib/

source ${LIB_DIR}/utils.sh

# Turn on USB host just incase
echo F > /proc/driver/musb_hdrc.1

if [ "x$(read_gpio 38)" != "x0" ] ; then
	bone_echo "bone tester: GPIO 38 (pin 3 connector A) is not grounded, aborting tests"
	exit 0
fi

bone_echo "Waiting for ttyUSB0"
while ! [ -e /dev/ttyUSB0 ] ; do bone_echo "" > /dev/null; done
stty -F /dev/ttyUSB0 115200

run_test() {
	if [ -z "$1" ] ; then
		bone_echo "run_test: Missing parameter"
		return 1
	fi
	time $COMPONENT_DIR/$1.sh
}

delete_uenv() {
	set -e
	mkdir /tmp/mnt
	mount /dev/mmcblk0p1 /tmp/mnt
	rm -f /tmp/mnt/uEnv.txt
	umount /tmp/mnt
	set +e
}

run_tests() {
	run_led_command init_leds
	run_led_command toggle_timer 3 300
	for test in $* ; do
		bone_echo "Running test: ${test}"
		run_test $test
		if [ $? -ne 0 ] ; then
			bone_echo "TEST FAILED: $test"
			run_led_command flash_all
			return $?
		fi
		bone_echo "---------------------------------------------------"
	done
	run_led_command turn_on_all
	bone_echo "All tests succeeded"
}

function run_led_command() {
	${BONETESTER_DIR}/lib/leds.sh $*
}

run_led_command stop_led_function

# systemd gadget-init service unit might insert usb modules, prepare for this
rmmod_all_usb_modules
rm /etc/udev/rules.d/70-persistent-net.rules

bone_echo "***************************************************"
run_tests \
    usb_loopback \
    ethernet \
    eeprom \
    pmic \
    memory 
bone_echo "***************************************************"

rm /etc/udev/rules.d/70-persistent-net.rules
halt
