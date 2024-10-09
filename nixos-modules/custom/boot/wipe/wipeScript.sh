# shellcheck shell=sh
mkdir -p /mnt

# We first mount the btrfs root to /mnt
# so we can manipulate btrfs subvolumes.
mount -o subvol=/ /dev/disk/by-label/nixos /mnt

# Figure out the next snapshot number to put in /prev.
# shellcheck disable=SC2012
num="$(ls /mnt/prev | sort -n | tail -1)"
num="$((num + 1))"

# While we're tempted to just delete /root and create
# a new snapshot from /root-blank, /root is already
# populated at this point with a number of subvolumes,
# which makes `btrfs subvolume delete` fail.
# So, we remove them first.
#
# /root contains subvolumes:
# - /root/var/lib/portables
# - /root/var/lib/machines
#
# I suspect these are related to systemd-nspawn, but
# since I don't use it I'm not 100% sure.
# Anyhow, deleting these subvolumes hasn't resulted
# in any issues so far, except for fairly
# benign-looking errors from systemd-tmpfiles.
btrfs subvolume list -o /mnt/root |
cut -f9 -d' ' |
while read -r subvolume; do
  echo "deleting /$subvolume subvolume..."
  btrfs subvolume delete "/mnt/$subvolume"
done &&
echo "snapshotting /root to /prev/$num" &&
btrfs subvolume snapshot -r /mnt/root "/mnt/prev/$num" &&
echo "deleting /root subvolume..." &&
btrfs subvolume delete /mnt/root

echo "restoring blank /root subvolume..."
btrfs subvolume snapshot /mnt/root-blank /mnt/root

# Once we're done rolling back to a blank snapshot,
# we can unmount /mnt and continue on the boot process.
umount /mnt
