#!/usr/bin/env sh
MODDIR="${0%/*}"

[ -w /dev ] && master_folder=/dev
[ -w /mnt ] && master_folder=/mnt
[ -w /mnt/vendor ] && master_folder=/mnt/vendor

chmod 777 "$MODDIR/overlayfs_system"


OVERLAYMNT="${master_folder}/mount"
MODULEMNT="${master_folder}/module"
node_folder="${master_folder}/node"
mkdir -p $node_folder

logfile=/debug_ramdisk/overlayfs.log


# overlay_system <writeable-dir>
. "$MODDIR/mode.sh"


echo "--- Start debugging log ---" >"$logfile"
echo "init mount namespace: $(readlink /proc/1/ns/mnt)" >>"$logfile"
echo "current mount namespace: $(readlink /proc/self/ns/mnt)" >>"$logfile"

mkdir -p "$OVERLAYMNT"
mkdir -p "$MODULEMNT"

mount -t tmpfs tmpfs "$MODULEMNT"

num=0

for i in $MODULE_LIST; do
    module_name="$(basename "$i")"
    if [ -d "$i" ] && [ ! -e "$i/disable" ] && [ ! -e "$i/remove" ] && [ ! -e "$i/skip_mount" ]; then
        echo "magic_overlayfs: processing $i " >> /dev/kmsg #debug
        mkdir -p "$MODULEMNT/$num"
        mount --bind "$i" "$MODULEMNT/$num"
        /data/adb/ksu/bin/ksu_susfs add_sus_mount "$MODULEMNT/$num" > /dev/null 2>&1 
        num="$((num+1))"
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
# best time here
for i in $(grep "magic_overlayfs" /proc/mounts | cut -f2 -d " "); do /data/adb/ksu/bin/ksu_susfs add_sus_mount $i > /dev/null 2>&1 ; done

# cleanup
umount -l "$OVERLAYMNT"
umount -l "$MODULEMNT"
rmdir "$OVERLAYMNT"
rmdir "$MODULEMNT"
# not needed anymore
rm -rf $OVERLAYDIR 

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
    for i in $(grep "magic_overlayfs" /proc/mounts | cut -f2 -d " "); do /data/adb/ksu/bin/ksu_susfs add_sus_mount $i > /dev/null 2>&1 ; done
    echo "--- Mountinfo (post cleanup) ---" >>"$logfile"
    cat /proc/mounts >>"$logfile"    
) &


# EOF
