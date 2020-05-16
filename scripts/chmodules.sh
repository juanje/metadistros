#!/bin/sh

KERNEL=2.4.22-meta

if [ -n "$1" ] ; then
  KERNEL=$1
fi

mount -o loop initrd /mnt/tmp/
cd /lib/modules/${KERNEL}/kernel/drivers/
for i in cloop loop ; do
  /bin/cp -f block/${i}.o /mnt/tmp/modules/
done
for i in `ls /mnt/tmp/modules/scsi/` ;	do
  find scsi/ -name "$i" -exec cp {} /mnt/tmp/modules/scsi \;
done
sync
umount /mnt/tmp/
