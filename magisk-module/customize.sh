# tired of clearing out old overlay brah
rm -rf /data/adb/overlay
rm -rf /data/adb/overlay.xz
if [ ${KSU} != true ] ; then
	abort 'This is modified for KernelSU only. Bye.'
fi

SKIPUNZIP=1

if [ "$BOOTMODE" ] && [ "$KSU" ]; then
    ui_print "- Installing from KernelSU app"
    ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    ui_print "- Please note that KernelSU modules mount will make"
    ui_print "  your system partitions unable to mount as rw"
    ui_print "- If you are using KernelSU, "
    ui_print "  please unmount all ksu overlayfs"
    ui_print "  when you want to modify system partitions"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    ui_print "- Installing from Magisk app"
else
    ui_print "*********************************************************"
    ui_print "! Install from recovery is not supported"
    ui_print "! Please install from KernelSU or Magisk app"
    abort    "*********************************************************"
fi

loop_setup() {
  unset LOOPDEV
  local LOOP
  local MINORX=1
  [ -e /dev/block/loop1 ] && MINORX=$(stat -Lc '%T' /dev/block/loop1)
  local NUM=0
  while [ $NUM -lt 1024 ]; do
    LOOP=/dev/block/loop$NUM
    [ -e $LOOP ] || mknod $LOOP b 7 $((NUM * MINORX))
    if losetup $LOOP "$1" 2>/dev/null; then
      LOOPDEV=$LOOP
      break
    fi
    NUM=$((NUM + 1))
  done
}

randdir="$TMPDIR/.$(head -c21 /dev/urandom | base64)"
mkdir -p "$randdir"

ABI="$(getprop ro.product.cpu.abi)"

# Fix ABI detection
if [ "$ABI" == "armeabi-v7a" ]; then
  ABI32=armeabi-v7a
elif [ "$ABI" == "arm64" ]; then
  ABI32=armeabi-v7a
elif [ "$ABI" == "x86" ]; then
  ABI32=x86
elif [ "$ABI" == "x64" ] || [ "$ABI" == "x86_64" ]; then
  ABI=x86_64
  ABI32=x86
fi

unzip -oj "$ZIPFILE" "libs/$ABI/overlayfs_system" -d "$TMPDIR" 1>&2
chmod 777 "$TMPDIR/overlayfs_system"

if ! $TMPDIR/overlayfs_system --test; then
    ui_print "! Kernel doesn't support overlayfs, are you sure?"
    abort
fi


ui_print "- Extract files"

unzip -oj "$ZIPFILE" post-fs-data.sh \
                     service.sh \
                     util_functions.sh \
                     mode.sh \
                     mount.sh \
                     uninstall.sh \
                     module.prop \
                     "libs/$ABI/overlayfs_system" \
                     -d "$MODPATH"
unzip -oj "$ZIPFILE" util_functions.sh  -d "/data/adb/modules/${MODPATH##*/}"

ui_print "- Setup module"

chmod 777 "$MODPATH/overlayfs_system"

. $MODPATH/mode.sh


touch $MODPATH/skip_mount

ui_print
