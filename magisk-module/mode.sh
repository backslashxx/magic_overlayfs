# Set to true to enable legacy mode that mount overlayfs on subdirectories instead of root partititons
export OVERLAY_LEGACY_MOUNT=true

# If you are using KernelSU, set this to true to unmount KernelSU overlayfs
export DO_UNMOUNT_KSU=true

# list your modules that you want globally mounted
# some examples 
MODULE_LIST="/data/adb/modules/*"
