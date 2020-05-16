#!/bin/sh

# Gettext
export TEXTDOMAIN=hw-detect

export PATH="/isolinux/cdroot/sbin:/sbin:/bin:/usr/sbin:/usr/bin"

SPLASH="$1"

# Clear tty2
echo "c" > /dev/tty2

/sbin/getty 38400 tty2  >> /tmp/getty.log 2>&1 &

# set clock
hwclock -s

# / must be read-write in any case, starting from here
mount -o remount,rw / 2>/tmp/hw.log

# No kernel messages while probing modules
echo "0" > /proc/sys/kernel/printk


#progress: 3er tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 310 21 FCD123 -d /dev/fb0
fi

# ACPI Battery for laptop
modprobe battery > /tmp/hw.log 2>&1

# Detect and load kernel modules
test -f "/etc/modules" && rm -f /etc/modules > /tmp/hw.log 2>&1
PCIDB="/isolinux/cdroot/hwdata/pci.lst"
IDS=`cut -f 2 /proc/bus/pci/devices`
MODULE=""
for ID in $IDS ; do
  MODULE=`grep $ID $PCIDB 2> /tmp/hw.log | cut -f 2 `
  if [ -n "$MODULE" ]; then
    modprobe $MODULE >/tmp/hw.log 2>&1 && echo $MODULE >> /etc/modules
  fi
done 
:> /tmp/modules.ready

#progress: 3er tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 330 21 FCD123 -d /dev/fb0
fi

# Support for hotpluggable devices?
HOTPLUG=""

# KNOPPIX autoconfig
# First: PCMCIA Check/Setup
# This needs to be done before other modules are being loaded by hwsetup
modprobe pcmcia_core >/tmp/hw.log 2>&1
# Try Cardbus or normal PCMCIA socket drivers
modprobe yenta_socket >/tmp/hw.log 2>&1 && HOTPLUG="yes" || modprobe i82365 >/tmp/hw.log 2>&1 || modprobe tcic >/tmp/hw.log 2>&1
if [ "$?" != "0" ]
then
# No PCMCIA Bus present.
[ -n "$HOTPLUG" ] || rmmod pcmcia_core 2>/tmp/hw.log
else
  modprobe ds >/tmp/hw.log 2>&1
  cardmgr &>/tmp/hw.log && sleep 4
  export PCMCIA=1
  echo "PCMCIA=1" > /tmp/pcmcia
fi


#progress: 3er tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 360 21 FCD123 -d /dev/fb0
fi


# USB/Mouse Check/Setup
# This needs to be done before other modules are being loaded by hwsetup
modprobe usbcore  >/tmp/hw.log 2>&1
# We now try to load both USB modules, in case someone has 2 different
# controllers
FOUNDUSB=""
for u in usb-uhci usb-ohci; do modprobe "$u" >/tmp/hw.log 2>&1 && FOUNDUSB="yes"; done
if [ -n "$FOUNDUSB" ]; then
  HOTPLUG="yes"
  mount -o devmode=0666 -t usbdevfs none /proc/bus/usb >/tmp/hw.log 2>&1
else
    rmmod usbcore 2>/tmp/hw.log
fi


# We now try to load the firewire module
FOUNDFIREWIRE=""
modprobe ohci1394 >/tmp/hw.log 2>&1 && FOUNDFIREWIRE="yes"
if [ -n "$FOUNDFIREWIRE" ]; then
  HOTPLUG="yes"
fi

# Start hotplug manager for PCI/USB/Firewire/Cardbus
if [ -n "$HOTPLUG" -a -x /sbin/hotplug ]; then
  echo "/sbin/hotplug" > /proc/sys/kernel/hotplug ; sleep 3
fi


#progress: 3er tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 390 21 FCD123 -d /dev/fb0
fi

# Detect partitions and Make /etc/fstab
# Scan partitions
HOSTNAME=`grep ^HOSTNAME /isolinux/conf/var.conf | cut -d "=" -f 2`
SWAPFILE=""
if [ -f /proc/partitions ]; then
  partitions="Y"
  if [ -n "$partitions" ]; then
    fdisk -l | awk '/^\/dev\// {
     if ($2 == "*") 
   { print $1" "$6" "$7" "$8" "$9 } 
     else 
   { print $1" "$5" "$6" "$7" "$8" "$9 }
     }' | \
    while read p n t; do
      fnew=""
      case "$t" in *[Ee]xtend*|*[Hh]ibernation*) continue; ;; esac
      case "$t" in *[Ss]wap*)
      # We need the entry in /etc/fstab to do a clean "swapon/swapoff -a" later
        fnew="$p swap swap defaults 0 0"
        mkswap $p
        swapon $p 2>/tmp/hw.log && SWAPFILE="N" &&\
        echo "$fnew" >> /etc/fstab
        continue
        ;;
      esac
      case "$t" in 
        *[Nn][Tt][Ff][Ss]*) 
          fs="ntfs"
            mount=0
          ;;
        *FAT*)
          fs="vfat"
              mount=1
          ;;
        *)
          # Normal partition
          fs="ext2:ext3:reiserfs:xfs"
              mount=1
          ;;
        esac
      # Create mountdir
      d="/mnt/${p##*/}" 
      [ -d "$d" ] || mkdir -p $d
 
#      # Create swapfile
#      if [ -z "$SWAPFILE" ] && \
#        mount -o "dev=$p,fs=${fs}" -t supermount none $d 
#      then
#        if [ ! -f $d/$HOSTNAME.swp ]; then
#          head -c 128m /dev/zero > $d/$HOSTNAME.swp && \
#          mkswap $d/$HOSTNAME.swp
#          SWAPFILE="Y" && echo "$d $d/$HOSTNAME.swp" > /tmp/swapfile
#        fi
#        umount $d
#      fi
      
      options="dev=${p},fs=${fs},ro"
      if mount -o "${options}" -t supermount none $d ; then
          fnew="none $d  supermount   $options 0 0"
          echo "$fnew" >> /etc/fstab
          touch $d/$HOSTNAME.swp # Pre-test hack
          if swapon $d/$HOSTNAME.swp ; then
              fnew="$d/$HOSTNAME.swp swap swap defaults 0 0"
              echo "$fnew" >> /etc/fstab
          fi
      fi
    done

  fi
fi

# Add USB mount points
SDA=`grep sda /etc/fstab`
SDB=`grep sdb /etc/fstab`
NUM=0
if [ -z "$SDA" ]; then
    echo "none /mnt/usb$NUM supermount dev=/dev/sda1,fs=vfat,sync  0  0" >> /etc/fstab
    mkdir /mnt/usb$NUM && mount /mnt/usb$NUM
    NUM=$[NUM+1]
fi
if [ -z "$SDB" ]; then
  echo "none /mnt/usb$NUM supermount dev=/dev/sdb1,fs=vfat,sync  0  0" >> /etc/fstab
  mkdir /mnt/usb$NUM && mount /mnt/usb$NUM
fi

# Add Floppy mount point
echo "none /a: supermount dev=/dev/fd0,fs=vfat,sync  0  0" >> /etc/fstab
mkdir /a: && mount /a:

# Add Cdroms mount points
if [ -f "/proc/sys/dev/cdrom/info" ] ; then
  cds=$(grep "^drive name:" /proc/sys/dev/cdrom/info)
  cds=${cds#drive\ name\:}
  num=0
  for i in $cds ; do
    if [ ${i%?} = 'sr' ]; then
        i="scd${i#sr}"
    fi
    echo "none  /cdrom${num}  supermount  dev=/dev/${i},fs=iso9660  0  0" >> /etc/fstab
    mkdir /cdrom${num} && mount /cdrom${num}
    let num=$num+1
  done
fi

#progress: 3er tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 400 21 FCD123 -d /dev/fb0
fi

# Mount all partitions in fstab
MOUNTALL=`grep ^MOUNTALL /isolinux/conf/var.conf | cut -d "=" -f 2`
if [ "$MOUNTALL" = "Y" ]; then
  mount -a
fi


#progress: 3er tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 420 21 FCD123 -d /dev/fb0
fi

echo "6" > /proc/sys/kernel/printk

exit 0
