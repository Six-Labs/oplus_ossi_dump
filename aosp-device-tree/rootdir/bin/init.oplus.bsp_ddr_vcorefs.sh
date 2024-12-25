#!/system/bin/sh

#=============================================================================
#persist.debug.ddr.vcorefs.config
#testing_phase=`getprop persist.debug.ddr.vcorefs.config`
#=============================================================================
#### ORDER or RANDOM
RANDOM_STRESS=1
#### wait latency for each DVFS finish (0.1=100ms, 0.001=1ms) 600 = 60s
T_DVFS_INTERVAL=0.1
ntest=600
echo " ***** STARTING DVFS STRESS ***** "
echo "=== modem shutdown ==="
muxreport 3

platform=`getprop ro.board.platform`

if [ x"$platform" = x"mt6877" ] || [ x"$platform" = x"mt6833" ]; then
    DVFSRC_PATH="/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/"
else
    DVFSRC_PATH="/sys/kernel/helio-dvfsrc/"
fi

NUM_DVFSRC_OPP=$(($(cat ${DVFSRC_PATH}dvfsrc_num_opps)-1))

do_ddr_vcorefs_switch(){
	if [ $1 -gt 10 ]
	then
		setprop persist.debug.ddr.vcorefs.low.freq true
	else
		setprop persist.debug.ddr.vcorefs.low.freq false
	fi
	echo $1 > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
}

do_ddr_vcorefs_random(){

	echo " ***** STARTING DVFS STRESS ***** "
	echo 1 > ${DVFSRC_PATH}dvfsrc_enable

	#Disable MMDVFS and keep lowest freq (for mt6877)
	echo 1 > /sys/module/mmdvfs_pmqos/parameters/mmdvfs_enable
	if [ x"$platform" = x"mt6877" ]; then
		echo 2 > /sys/module/mmdvfs_pmqos/parameters/force_step
	else
		echo 3 > /sys/module/mmdvfs_pmqos/parameters/force_step
	fi
	muxreport 3
	#Disable hold vcore whenever UFS access storage
	echo 0 > /proc/ufs_perf

	#Let SCP in low freq
	echo opp 0 > /proc/scp_dvfs/scp_dvfs_ctrl

	#Let APU in low freq
	if [ -f /d/apusys/power ]; then
		echo dvfs_debug 4 > /d/apusys/power
	fi

	for i in $(seq 1 ${ntest})
	do
		sleep $T_DVFS_INTERVAL
		fix_opp=$(($RANDOM%$NUM_DVFSRC_OPP))
		fix_opp=$(($fix_opp))
		if [ x"$platform" = x"mt6877" ]; then
			#Disable vcore 0.55v
			if [[ $fix_opp -ne 14 && $fix_opp -ne 19 && $fix_opp -ne 24 && $fix_opp -ne 29 ]]; then
				echo $fix_opp > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
			fi
		else
			echo $fix_opp > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
		fi
		cat ${DVFSRC_PATH}dvfsrc_dump | grep -e uv -e khz
	done
}

do_ddr_vcorefs_max(){
	echo 1 > ${DVFSRC_PATH}dvfsrc_enable
	echo 0 > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
	echo 0 > ${DVFSRC_PATH}dvfsrc_enable
	for i in $(seq 1 ${ntest})
	do
		sleep $T_DVFS_INTERVAL
		cat ${DVFSRC_PATH}dvfsrc_dump | grep -e uv -e khz
	done
}

do_ddr_vcorefs_min(){
	echo 1 > ${DVFSRC_PATH}dvfsrc_enable
	echo "Disable MMDVFS and keep lowest freq (for mt6877)"
	echo 1 > /sys/module/mmdvfs_pmqos/parameters/mmdvfs_enable
	if [ x"$platform" = x"mt6877" ]; then
		echo 2 > /sys/module/mmdvfs_pmqos/parameters/force_step
	else
		echo 3 > /sys/module/mmdvfs_pmqos/parameters/force_step
	fi

	echo "=== modem shutdon ==="
	shell muxreport 3

	echo "Disable hold vcore whenever UFS access storage"
	echo 0 > /proc/ufs_perf

	echo "Let SCP in low freq"
	echo opp 0 > /proc/scp_dvfs/scp_dvfs_ctrl

	#Let APU in low freq
	if [ -f /d/apusys/power ]; then
		echo "Let APU in low freq"
		echo dvfs_debug 4 > /d/apusys/power
	fi

	#echo "fix vcore 0.55v and dram 1866M"
	#echo "fix vcore 0.58v and dram 800M"
	if [ x"$platform" = x"mt6877" ]; then
		echo "fix vcore 0.6v and dram 800M"
		echo 28 > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
	else
		echo $NUM_DVFSRC_OPP > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
	fi

	echo 0 > ${DVFSRC_PATH}dvfsrc_enable
	for i in $(seq 1 ${ntest})
	do
		sleep $T_DVFS_INTERVAL
		cat ${DVFSRC_PATH}dvfsrc_dump | grep -e uv -e khz
	done
}

do_ddr_vcorefs_longstep_random(){
	echo 1 > ${DVFSRC_PATH}dvfsrc_enable
	echo "do_ddr_vcorefs_longstep_random"
	echo "Disable MMDVFS and keep lowest freq (for mt6877)"
	echo 1 > /sys/module/mmdvfs_pmqos/parameters/mmdvfs_enable
	if [ x"$platform" = x"mt6877" ]; then
		echo 2 > /sys/module/mmdvfs_pmqos/parameters/force_step
	else
		echo 3 > /sys/module/mmdvfs_pmqos/parameters/force_step
	fi

	echo "=== modem shutdon ==="
	shell muxreport 3

	echo "Disable hold vcore whenever UFS access storage"
	echo 0 > /proc/ufs_perf

	echo "Let SCP in low freq"
	echo opp 0 > /proc/scp_dvfs/scp_dvfs_ctrl

	#Let APU in low freq
	if [ -f /d/apusys/power ]; then
		echo "Let APU in low freq"
		echo dvfs_debug 4 > /d/apusys/power
	fi

	fix_opp=$(($RANDOM%$NUM_DVFSRC_OPP))
	for i in $(seq 1 ${ntest})
	do
		sleep $T_DVFS_INTERVAL
		L_step=$(($RANDOM%5))
		fix_opp=$(($fix_opp+10+$L_step))
		fix_opp=$(($fix_opp%$NUM_DVFSRC_OPP))
		if [ x"$platform" = x"mt6877" ]; then
			#Disable vcore 0.55v
			if [[ $fix_opp -ne 14 && $fix_opp -ne 19 && $fix_opp -ne 24 && $fix_opp -ne 29 ]]; then
				echo $fix_opp > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
			fi
		else
			echo $fix_opp > ${DVFSRC_PATH}dvfsrc_force_vcore_dvfs_opp
		fi
		cat ${DVFSRC_PATH}dvfsrc_dump | grep -e uv -e khz
	done
}


enable_ddr_vcorefs_test(){
	while [ 1 ]
	do
		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		if [ "$ddr_testphase" = "done" ]; then
			break
		fi
		setprop persist.debug.ddr.vcorefs.config random
		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		echo "ddr_testphase:$ddr_testphase."
		if [ "$ddr_testphase" = "random" ]; then
			do_ddr_vcorefs_random
		fi

		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		if [ "$ddr_testphase" = "done" ]; then
			break
		fi
		setprop persist.debug.ddr.vcorefs.config max
		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		echo "ddr_testphase:$ddr_testphase."
		if [ "$ddr_testphase" = "max" ]; then
			do_ddr_vcorefs_max
		fi

		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		if [ "$ddr_testphase" = "done" ]; then
			break
		fi
		setprop persist.debug.ddr.vcorefs.config min
		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		echo "ddr_testphase:$ddr_testphase."
		if [ "$ddr_testphase" = "min" ]; then
			do_ddr_vcorefs_min
		fi

		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		if [ "$ddr_testphase" = "done" ]; then
			break
		fi
		setprop persist.debug.ddr.vcorefs.config longstep
		ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
		echo "ddr_testphase:$ddr_testphase."
		if [ "$ddr_testphase" = "longstep" ]; then
			do_ddr_vcorefs_longstep_random
		fi
	done
	echo "The ddr_vcorefs_test is done and PASS if no exception occurred."
}

enable_ddr_vcorefs_manual(){
	ddr_testphase=`getprop persist.debug.ddr.vcorefs.config`
	while [ 1 ]
	do
		if [ "$ddr_testphase" != "done" ]; then
			break
		fi
		ddr_manualphase=`getprop persist.debug.ddr.vcorefs.manual`
		echo "ddr_manualphase:$ddr_manualphase."
		if [ "$ddr_manualphase" = "random" ]; then
			do_ddr_vcorefs_random
		elif [ "$ddr_manualphase" = "max" ]; then
			do_ddr_vcorefs_max
		elif [ "$ddr_manualphase" = "min" ]; then
			do_ddr_vcorefs_min
		elif [ "$ddr_manualphase" = "longstep" ]; then
			do_ddr_vcorefs_longstep_random
		elif [ "$ddr_manualphase" = "done" ]; then
			break
		else
			sleep 10
		fi
	done
	echo "The enable_ddr_vcorefs_manual is done and PASS if no exception occurred."
}


enable_ddr_vcorefs_test
enable_ddr_vcorefs_manual

