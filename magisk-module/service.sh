touch "${0%/*}/disable"
touch /dev/.overlayfs_service_unblock

. "${0%/*}/mode.sh"

# unmount KSU overlay
if [ "$DO_UNMOUNT_KSU" ]; then
    "${0%/*}/overlayfs_system" --unmount-ksu
    stop; start
fi

while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done
rm -rf "${0%/*}/disable"


until [ -d "/sdcard/Android" ]; do sleep 1; done

MODDIR="${0%/*}"


case $OVERLAY_MODE in
        0) mode="🔐❓" ;;
        1) mode="🔓💢" ;;
        2) mode="🔒✅" ;;
esac 

case $OVERLAY_LEGACY_MOUNT in
        true) mount="✅" ;;
        false) mount="❌" ;;
esac 

module_list_string=$(for i in $MODULE_LIST ; do [ -d $i ] && printf "$i " | sed 's|/data/adb/modules/||g' ; done)
string="description=mode: $mode | legacy_mount: $mount | size: $OVERLAY_SIZE"M" 💾 | modules: $module_list_string "
sed -i "s/^description=.*/$string/g" $MODDIR/module.prop

# EOF
