#!/system/bin/sh

nandswap_tool=/product/bin/nandswap_tool
swapfile_path=/data/nandswap/swapfile
nandswap_sz_bytes=0
swap_size_mb=0
fn_enable=false
data_type=erofs
prop_condition="persist.sys.oplus.nandswap.condition"
prop_nandswap_err="persist.sys.oplus.nandswap.err"
prop_nandswap_curr="persist.sys.oplus.nandswap.swapsize.curr"
prop_nandswap_size="persist.sys.oplus.nandswap.swapsize"
cfg_nandswap_path="/odm/etc/nandswap.cfg"
zram_increase=0
hybridswap_has_insmod=0
hybridswap_init=0
zram2ufs_ratio=30
zram_critical_threshold=0
threshold_wakeup_hybridswapd="0 0 0 0"
nandswap_sz_gb=0
dd_mb_cnt=0
mem_total=0
zram_increase_limit=3072
vm_swappiness=160
direct_swappiness=0
comp_algorithm="lz4"
emmc_device=0

function configure_platform_parameters()
{
    product_id=`getprop ro.boot.prjname`
	case "$product_id" in
		"20131"|"20133"|"20255"|"20257"|"20181"|"20355"|"21081"|"212A1"|"21851"|"21876"|"20827"|"20831"|"21061"|"21015"|"21217"|"21861"|"21862"|"21863"|"21143"|"22801"|"21007"|"20171"|"20353"|"21881"|"21882"|"21127"|"21305")
			if [[ $mem_total -gt 6291456 ]]; then
				comp_algorithm="zstd"
				swap_size_mb=5632
				zram_increase_limit=2048
				vm_swappiness=200
				direct_swappiness=0
			fi
			;;
		"20255"|"20257"|"20131"|"20133")
			if [[ $mem_total -gt 6291456 ]]; then
				comp_algorithm="zstd"
				swap_size_mb=5632
				zram_increase_limit=2048
				vm_swappiness=200
				direct_swappiness=0
			fi
			;;
		"22282"|"22283")
			if [[ $mem_total -gt 6291456 ]]; then
				swap_size_mb=5632
				zram_increase_limit=2048
 				direct_swappiness=0
			fi
			;;
		"21121"|"21301")
			if [[ $mem_total -gt 6291456 ]]; then
				direct_swappiness=0
				swap_size_mb=5120
				zram_increase_limit=2048
			fi
			;;
		"20767"|"20761"|"20762"|"20764")
			if [[ $mem_total -lt 6291456 ]]; then
				vm_swappiness=160
				direct_swappiness=0
			fi
			;;
		"226AD"|"226AE"|"226AF"|"226B0")
			if [[ $mem_total -gt 6291456 ]]; then
				comp_algorithm="lz4"
				swap_size_mb=5632
				zram_increase_limit=2048
				direct_swappiness=60
			fi
			if [[ $mem_total -le 4194304 ]]; then
				comp_algorithm="zstd"
				direct_swappiness=60
			fi
			;;
		"2269C"|"2269D"|"2269E")
			if [[ $mem_total -le 4194304 ]]; then
				comp_algorithm="lz4"
				vm_swappiness=160
				direct_swappiness=60
			fi
			;;
		"21690"|"21691"|"21692")
			if [[ $mem_total -le 4194304 ]]; then
				direct_swappiness=60
			fi
			;;
		"22083"|"22084")
			if [[ $mem_total -gt 4194304 ]]; then
				direct_swappiness=60
			fi
			;;
		*)
			echo -e "***WARNING***: Invalid SoC ID"
			;;
	esac
}

function configure_hybridswap_parameters()
{
	if [ $mem_total -le 3145728 ]; then
		zram2ufs_ratio=30
		threshold_wakeup_hybridswapd="200 100 200 512"
	elif [ $mem_total -le 4194304 ]; then
		zram2ufs_ratio=30
		threshold_wakeup_hybridswapd="200 100 200 512"
		# threshold_wakeup_hybridswapd="1200 1000 1200 716"
	elif [ $mem_total -le 6291456 ]; then
		zram2ufs_ratio=20
		threshold_wakeup_hybridswapd="2000 1600 2000 1536"
	else
		zram2ufs_ratio=15
		threshold_wakeup_hybridswapd="2200 1800 2200 1536"
	fi
	if [ $emmc_device -eq 1 ]; then
		zram2ufs_ratio=5
	fi
	dd_mb_cnt=$(expr $swap_size_mb \* $zram2ufs_ratio \/ 100)
	local eswap_size_mb=$(expr $nandswap_sz_gb \* 1024)
	if [ $eswap_size_mb -lt $dd_mb_cnt ]; then
		dd_mb_cnt=$eswap_size_mb
	fi
	zram_critical_threshold=$(expr $swap_size_mb \- 128)
}

function configure_zram_parameters()
{
	echo $comp_algorithm > /sys/block/zram0/comp_algorithm
	if [ -f /sys/block/zram0/disksize ]; then
		if [ -f /sys/block/zram0/use_dedup ]; then
			echo 1 > /sys/block/zram0/use_dedup
		fi

		if [ $swap_size_mb -gt 0 ]; then
			echo "swap_size_mb was already defined"
		elif [ $mem_total -le 524288 ]; then
			#config 384MB zramsize with ramsize 512MB
			swap_size_mb=384
		elif [ $mem_total -le 1048576 ]; then
			#config 768MB zramsize with ramsize 1GB
			swap_size_mb=768
		elif [ $mem_total -le 2097152 ]; then
			#config 1GB+256MB zramsize with ramsize 2GB
			swap_size_mb=1280
		elif [ $mem_total -le 3145728 ]; then
			#config 1GB+512MB zramsize with ramsize 3GB
			swap_size_mb=1536
		elif [ $mem_total -le 4194304 ]; then
			#config 2GB+512MB zramsize with ramsize 4GB
			swap_size_mb=2560
		elif [ $mem_total -le 6291456 ]; then
			#config 3GB zramsize with ramsize 6GB
			swap_size_mb=3072
		elif [ $mem_total -le 12582912 ]; then
			#config 5GB zramsize with ramsize 8GB and 12GB
			swap_size_mb=5632
			zram_increase_limit=2048
		else
			#config 7GB zramsize with ramsize 16GB or larger devices
			swap_size_mb=7680
			zram_increase_limit=2048
		fi

		zram_increase=$(expr $nandswap_sz_bytes \/ 1024 \/ 1024)
		if [ $zram_increase -gt $zram_increase_limit ]; then
			zram_increase=$zram_increase_limit
		fi

		if [[ "$fn_enable" == "false" || $hybridswap_has_insmod -eq 0 ]]; then
			zram_increase=0
		fi

		disksize=$(expr $swap_size_mb \+ $zram_increase)
		echo "$disksize""M" > /sys/block/zram0/disksize
	fi

	if [ $hybridswap_has_insmod -eq 1 ]; then
		configure_hybridswap_parameters
	fi
}

function configure_swappiness()
{
	kernel_version=`uname -r`
	oplus_path=oplus_healthinfo

	if [[ "$kernel_version" == "5.1"* ]]; then
		oplus_path=oplus_mem
	fi

	if [ "$fn_enable" == "true" -a "$nandswap_sz_bytes" != "0" -a $hybridswap_has_insmod -eq 1 ]; then
		echo "direct_swappiness=${direct_swappiness}" > /proc/${oplus_path}/swappiness_para
		echo "vm_swappiness=${vm_swappiness}" > /proc/${oplus_path}/swappiness_para
	else
		echo "direct_swappiness=${direct_swappiness}" > /proc/${oplus_path}/swappiness_para
	fi
}

function zram_init()
{
	local magic=32758

	if [ $# -eq 1 ]; then
		magic=$1
	fi

	configure_swappiness

	mkswap /dev/block/zram0
	swapon /dev/block/zram0 -p $magic
}

function write_nandswap_err()
{
	setprop $prop_nandswap_err $1
	setprop $prop_condition false
}

function configure_nandswap_parameters()
{
	init=`getprop sys.oplus.nandswap.init`
	[ "$init" == "true" ] && exit

	setprop sys.oplus.nandswap.init true

	data_type=`mount |grep -E " /data " |awk '{print $5}'`
	[ $data_type != "f2fs" ] && [ $data_type != "ext4" ] && write_nandswap_err 1001 && return 22

	is_ufs=`find /sys/bus/platform/devices/ |grep ufshc`
	if [ ! -n "$is_ufs" ]; then
		prjname=`getprop ro.boot.prjname`
		if [ -n "$prjname" ]; then
			case $prjname in
				"2133"[0-9])
					emmc_device=1
					;;
				"21107")
					emmc_device=1
					;;
				"2136"[1-3])
					emmc_device=1
					;;
				"2125"[1-4])
					emmc_device=1
					;;
				"2037"[5-9])
					emmc_device=1
					;;
				"2037A")
					emmc_device=1
					;;
				"2287"[5-6])
					emmc_device=1
					;;
				"22081")
					emmc_device=1
					;;
				"2226"[1-6])
					emmc_device=1
					;;
				"226A"[D-F])
					emmc_device=1
					;;
				"226B0")
					emmc_device=1
					;;
				*)
					write_nandswap_err 1002
					return 22
			esac
		else
			write_nandswap_err 1002
			return 22
		fi
	fi

	if [ -f /sys/block/zram0/hybridswap_core_enable ]; then
		hybridswap_has_insmod=1
	fi

	$nandswap_tool -r ${cfg_nandswap_path}
	condition=`getprop $prop_condition`
	[ "$condition" == "true" ] || return 22

	nandswap_sz_gb=`getprop $prop_nandswap_size`
	nandswap_sz_bytes=$(expr $nandswap_sz_gb \* 1024 \* 1024 \* 1024)

	dev_life=`getprop persist.sys.oplus.nandswap.devlife`
	if [ "$dev_life" == "false" ]; then
		if [ -f /sys/block/zram0/hybridswap_dev_life ]; then
			echo 1 > /sys/block/zram0/hybridswap_dev_life
		elif [ -f /proc/nandswap/dev_life ]; then
			echo 1 > /proc/nandswap/dev_life
		fi
	else
		if [ -f "/proc/nandswap/fn_enable" ] && [ $avail -gt $threshold ]; then
			[ "$condition" == "true" ] && fn_enable=`getprop "persist.sys.oplus.nandswap"`
			echo 0 > /proc/nandswap/dev_life
		fi
	fi

	return 0
}

function check_swapfile()
{
	if [ "$data_type" == "f2fs" ]; then
		check_pin=`$nandswap_tool -g $swapfile_path |awk '{print $2}'`
		[ "$check_pin" == "pinned" ] || ( rm -rf $swapfile_path && return 22 )
	fi

	check_size=`ls -al $swapfile_path |awk '{print $5}'`
	[ "$check_size" == "$nandswap_sz_bytes" ] || ( rm -rf $swapfile_path && return 22 )

	return 0
}

function nandswap_init()
{
	touch $swapfile_path
	swap_offset=0
	swap_size=$(expr $nandswap_sz_gb \* 1024 \* 1024 \* 1024)

	[ "$data_type" == "f2fs" ] && $nandswap_tool -s1 $swapfile_path
	if [[ $hybridswap_has_insmod -eq 1 ]]; then
		dd if=/dev/zero of=$swapfile_path bs=1M count=$dd_mb_cnt
		swap_offset=$(expr $dd_mb_cnt \* 1024 \* 1024)
		swap_size=$(expr $swap_size \- $swap_offset)
	fi
	fallocate -l ${swap_size} -o $swap_offset $swapfile_path

	check_swapfile
	if [ $? -eq 22 ]; then
		write_nandswap_err 1003
		return 22
	fi

	for i in {0..2} ; do
		losetup -f
		sleep 1
		loop_device=$(losetup -f -s $swapfile_path 2>&1)
		loop_device_ret=`echo $loop_device |awk -Floop '{print $1}'`
		if [ "$loop_device_ret" == "/dev/block/" ]; then
			break
		fi
		sleep 1
	done
	[ "$loop_device_ret" != "/dev/block/" ] && rm -rf $swapfile_path && write_nandswap_err 1003 && return 22

	set_dio=`$nandswap_tool -l $loop_device |awk '{print $2}'`
	if [ "$set_dio" == "success" ]; then
		if [ $hybridswap_has_insmod -eq 1 ]; then
			zram_init
			chmod o+w `ls -l /sys/block/zram0/hybridswap_* | grep ^'\-rw\-' | awk '{print $NF}'`
			echo "3 0 99 0 0 0 100 399 60 0 0 400 499 50 0 0 " > /dev/memcg/memory.swapd_memcgs_param
			echo 400 > /dev/memcg/memory.app_score
			echo 300 > /dev/memcg/apps/memory.app_score
			echo root > /dev/memcg/memory.name
			echo apps > /dev/memcg/apps/memory.name
			# FIXME: set system memcg pata in init.kernel.post_boot-lahaina.sh temporary
			# echo 500 > /dev/memcg/system/memory.app_score
			# echo systemserver > /dev/memcg/system/memory.name
			echo "$threshold_wakeup_hybridswapd" > /dev/memcg/memory.avail_buffers
			echo $zram_critical_threshold > /dev/memcg/memory.zram_critical_threshold
			echo 50 > /dev/memcg/memory.swapd_max_reclaim_size
			echo "1000 50" > /dev/memcg/memory.swapd_shrink_parameter
			echo 5000 > /dev/memcg/memory.max_skip_interval
			echo 50 > /dev/memcg/memory.reclaim_exceed_sleep_ms
			echo 60 > /dev/memcg/memory.cpuload_threshold
			echo 30 > /dev/memcg/memory.max_reclaimin_size_mb
			echo 80 > /dev/memcg/memory.zram_wm_ratio
			echo 512 > /dev/memcg/memory.empty_round_skip_interval
			echo 20 > /dev/memcg/memory.empty_round_check_threshold
			echo 1 > /sys/block/zram0/hybridswap_loglevel
			echo -n $loop_device > /sys/block/zram0/hybridswap_loop_device
			echo 1 > /sys/block/zram0/hybridswap_enable
			echo "0-3" > /dev/memcg/memory.swapd_bind
			echo "$zram_increase" > /sys/block/zram0/hybridswap_zram_increase
			#Qun.Lin@AD.Performancee, 2022/4/4, change cfg to mq-deadline
			loop_device_num=`echo $loop_device |awk -F/ '{print $4}'`
			echo mq-deadline > /sys/block/$loop_device_num/queue/scheduler
			hybridswap_init=1
		elif [ -f /proc/nandswap/fn_enable ]; then
			mkswap $loop_device
			# 2020 is just a magic number, must be consistent with the definition SWAP_NANDSWAP_PRIO in include/linux/swap.h
			swapon $loop_device -p 2020
			echo 1 > /proc/nandswap/fn_enable
		else
			zram_init
			write_nandswap_err 1004
			losetup -d $loop_device
			rm -rf $swapfile_path
		fi
	else
		zram_init
		losetup -d $loop_device
		rm -rf $swapfile_path
	fi

	return 0;
}

function main()
{
	mem_total_str=`cat /proc/meminfo |grep MemTotal`
	mem_total=${mem_total_str:16:8}
	fn_enable=`getprop persist.sys.oplus.nandswap`

	if [ -z $mem_total ]; then
		echo -e "read meminfo failed\n"
		exit -1
	fi
	if [ $mem_total -le 3145728 ]; then
		comp_algorithm=zstd
		vm_swappiness=180
		direct_swappiness=0
	fi
	configure_platform_parameters

	configure_nandswap_parameters
	ret=$?
	if [ $ret -eq 22 ]; then
		nandswap_sz_bytes=0
		configure_zram_parameters
		setprop $prop_nandswap_curr 0
		zram_init
		exit
	fi

	configure_zram_parameters
	if [ "$fn_enable" == "true" -a "$nandswap_sz_bytes" != "0" ]; then
		nandswap_init
	else
		setprop $prop_nandswap_curr 0
	fi
	zram_init

	setprop persist.sys.oplus.hybridswap_app_memcg false
	if [ $hybridswap_init -eq 1 ]; then
		kernel_version=`uname -r`
		if [[ "$kernel_version" == "5.1"* ]]; then
			setprop persist.sys.oplus.hybridswap_app_uid_memcg true
		fi
		setprop persist.sys.oplus.hybridswap_app_memcg true
	fi
}

main
