MODDIR="${0%/*}"

set -o standalone

export MAGISKTMP="$(magisk --path)"

chmod 777 "$MODDIR/overlayfs_system"

OVERLAYDIR="/data/adb/overlay"
OVERLAYMNT="/dev/mount_overlayfs"
MODULEMNT="/dev/mount_loop"

# find writables
[ -w /cache ] && logfile=/cache/overlayfs.log
[ -w /debug_ramdisk ] && logfile=/debug_ramdisk/overlayfs.log

# overlay_system <writeable-dir>
. "$MODDIR/mode.sh"

# mv -fT "$logfile" "$logfile".bak
rm -rf "$logfile"
echo "--- Start debugging log ---" >"$logfile"
echo "init mount namespace: $(readlink /proc/1/ns/mnt)" >>"$logfile"
echo "current mount namespace: $(readlink /proc/self/ns/mnt)" >>"$logfile"

mkdir -p "$OVERLAYMNT"
mkdir -p "$OVERLAYDIR"
mkdir -p "$MODULEMNT"

mount -t tmpfs tmpfs "$MODULEMNT"

loop_setup() {
  unset LOOPDEV
  local LOOP
  local MINORX=1
  [ -e /dev/block/loop1 ] && MINORX=$(stat -Lc '%T' /dev/block/loop1)
  local NUM=0
  while [ $NUM -lt 2048 ]; do
    LOOP=/dev/block/loop$NUM
    [ -e $LOOP ] || mknod $LOOP b 7 $((NUM * MINORX))
    if losetup $LOOP "$1" 2>/dev/null; then
      LOOPDEV=$LOOP
      break
    fi
    NUM=$((NUM + 1))
  done
}

if [ -f "$OVERLAYDIR" ]; then
    loop_setup /data/adb/overlay
    if [ ! -z "$LOOPDEV" ]; then
        mount -o rw -t ext4 "$LOOPDEV" "$OVERLAYMNT"
        ln "$LOOPDEV" /dev/block/overlayfs_loop
    fi
fi

if ! "$MODDIR/overlayfs_system" --test --check-ext4 "$OVERLAYMNT"; then
    echo "unable to mount writeable dir" >>"$logfile"
    exit
fi

num=0

for i in $MODULE_LIST; do
    module_name="$(basename "$i")"
    if [ -d "$i" ] && [ ! -e "$i/disable" ] && [ ! -e "$i/remove" ]; then
        echo "magic_overlayfs: processing $i " >> /dev/kmsg #debug
        if [ -f "$i/overlay.img" ]; then
            loop_setup "$i/overlay.img"
            if [ ! -z "$LOOPDEV" ]; then
                echo "mount overlayfs for module: $module_name" >>"$logfile"
                mkdir -p "$MODULEMNT/$num"
                mount -o rw -t ext4 "$LOOPDEV" "$MODULEMNT/$num"
            fi
            num="$((num+1))"
        fi
        if [ "$KSU" == "true" ]; then
            mkdir -p "$MODULEMNT/$num"
            mount --bind "$i" "$MODULEMNT/$num"
            num="$((num+1))"
        fi
    fi
done

OVERLAYLIST=""

for i in "$MODULEMNT"/*; do
    [ ! -e "$i" ] && break;
    if [ -d "$i" ] && [ ! -L "$i" ] && "$MODDIR/overlayfs_system" --test --check-ext4 "$i"; then
        OVERLAYLIST="$i:$OVERLAYLIST"
    fi
done

mkdir -p "$OVERLAYMNT/upper"
rm -rf "$OVERLAYMNT/worker"
mkdir -p "$OVERLAYMNT/worker"

if [ ! -z "$OVERLAYLIST" ]; then
    export OVERLAYLIST="${OVERLAYLIST::-1}"
    echo "mount overlayfs list: [$OVERLAYLIST]" >>"$logfile"
fi


"$MODDIR/overlayfs_system" "$OVERLAYMNT" | tee -a "$logfile"

if [ ! -z "$MAGISKTMP" ]; then
    mkdir -p "$MAGISKTMP/overlayfs_mnt"
    mount --bind "$OVERLAYMNT" "$MAGISKTMP/overlayfs_mnt"
fi


umount -l "$OVERLAYMNT"
rmdir "$OVERLAYMNT"
umount -l "$MODULEMNT"
rmdir "$MODULEMNT"

rm -rf /dev/.overlayfs_service_unblock
echo "--- Mountinfo (post-fs-data) ---" >>"$logfile"
cat /proc/mounts >>"$logfile"
(
    # block until /dev/.overlayfs_service_unblock
    while [ ! -e "/dev/.overlayfs_service_unblock" ]; do
        sleep 1
    done
    rm -rf /dev/.overlayfs_service_unblock

    echo "--- Mountinfo (late_start) ---" >>"$logfile"
    cat /proc/mounts >>"$logfile"
) &

