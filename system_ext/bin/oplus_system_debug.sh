#!/system/bin/sh

cmd="$1"

#init mount debugfs, sepolicy denied
#setprop ro.product.debugfs_restrictions.enabled false
#mount -t debugfs debugfs /sys/kernel/debug
#chmod 0755 /sys/kernel/debug
#setprop persist.dbg.keep_debugfs_mounted true

function enable_ftrace() {

}

case "$cmd" in
    "enable_ftrace")
        enable_ftrace
        ;;
    *)
        /system_ext/bin/oplus_system_debug "$cmd"
        ;;
esac
