# OverlayFS Mode
# 0 - read-only but can still remount as read-write
# 1 - read-write default
# 2 - read-only locked (cannot remount as read-write)
# You can set to 2 after modify system partititons to avoid detection
export OVERLAY_MODE=2

# Set to true to enable legacy mode that mount overlayfs on subdirectories instead of root partititons
export OVERLAY_LEGACY_MOUNT=true

# If you are using KernelSU, set this to true to unmount KernelSU overlayfs
export DO_UNMOUNT_KSU=true

# set overlay.img size in megabytes, 500 set by default.
# this is only on fresh install.
export OVERLAY_SIZE=500

# list your modules that you want globally mounted
# some examples 
MODULE_LIST="/data/adb/modules/ViPER4Android-RE-Fork /data/adb/modules/acc /data/adb/modules/Adreno_Gpu_Driver /data/adb/modules/weebu-addon"
