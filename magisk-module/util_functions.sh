resize_img() {
    e2fsck -pf "$1" || return 1
    if [ "$2" ]; then
        resize2fs "$1" "$2" || return 1
    else
        resize2fs -M "$1" || return 1
    fi
    return 0
}

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

sizeof(){
    EXTRA="$2"
    [ -z "$EXTRA" ] && EXTRA=0
    [ "$EXTRA" -gt 0 ] || EXTRA=0
    size="$(du -s "$1" | awk '{ print $1 }')"
    # append more 20Mb
    size="$((size + EXTRA))"
    echo -n "$((size + 20000))"
}


handle() {
  if [ ! -L "/$1" ] && [ -d "/$1" ] && [ -d "$MODPATH/system/$1" ]; then
    rm -rf "$MODPATH/overlay/$1"
    mv -f "$MODPATH/overlay/system/$1" "$MODPATH/overlay"
    ln -s "../$1" "$MODPATH/overlay/system/$1"
  fi
}

create_ext4_image() {
    dd if=/dev/zero of="$1" bs=1024 count=100
    /system/bin/mkfs.ext4 "$1" && return 0
    return 1
}

support_overlayfs() {
	echo "This is not supported by this version."
	return 0
}
