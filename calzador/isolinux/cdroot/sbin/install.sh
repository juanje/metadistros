#!/bin/sh

FSCHOICE="$1"
MOUNTPOINT="/mnt"
SWCHOICE=`/sbin/fdisk -l | awk '/^\/dev\// {if ($2 != "*") {if ($5 == "82") { print $1 }}}'`


# Formatear particion
if [ ! -b "$FSCHOICE" ]; then
  echo "$FSCHOICE no es una partición valida" > /tmp/ERROR
  exit 1
fi
echo 5
echo "XXX Formateando $FSCHOICE..... XXX"
mkfs.ext3 $FSCHOICE > /tmp/mkfs.log 2>&1

# Creando particion SWAP
echo "XXX Creando partición SWAP..... XXX"
echo 25
mkswap $SWCHOICE > /tmp/mkswap.log 2>&1
echo "XXX Activando partición SAWP..... XXX"
swapon $SWCHOICE > /tmp/swapon.log 2>&1


# Montarla
echo "XXX Montando $FSCHOICE en $MOUNTPOINT..... XXX"
mount -t ext3 $FSCHOICE $MOUNTPOINT >> /tmp/mount.log 2>&1

# Copiar distro al disco
echo 30
echo "XXX Copiando la distribución al disco..... XXX"
TOTAL=`du -s /META/ | cut -f 1`
TOTAL=${TOTAL%M}
(cp -af /META/* $MOUNTPOINT/ > /tmp/cp_meta.log 2>&1 ; touch /tmp/cp_end) &
while [ ! -f "/tmp/cp_end" ]; do
  TAM=`du -s $MOUNTPOINT/ | cut -f 1`
  TAM=${TAM%M}
  echo $((($TAM * 50/ $TOTAL) + 30))
  sleep 2
done

echo 80
#
# Kernel and Modules
#
echo "XXX Copiando el Kernel y los modulos..... XXX"
cp -f /cdrom/isolinux/vmlinuz $MOUNTPOINT/boot/vmlinuz-`uname -r`
cp -a /lib/modules/* $MOUNTPOINT/lib/modules/


#
# MOUSE and CDROM links
#
echo "XXX Creando enlaces a los dispositivos..... XXX"
if [ -f /etc/sysconfig/mouse ] ; then
  x="`grep DEVICE= /etc/sysconfig/mouse`"
  x=${x#*/dev/}
  MOUSEDEV=${x%\"*}
fi
[ -z "$MOUSEDEV" ] && MOUSEDEV="psaux"
(cd $MOUNTPOINT/dev ; ln -sf $MOUSEDEV mouse)

# CDROMs
mkdir -p /tmp/cdroms

# Buscar CDroms
NUM=""
NSCSI=0
for i in 0 1 2 ; do
  for j in a b c d ; do
    CD=`cat /proc/ide/ide$i/hd$j/media 2> /dev/null`
    if [ "$CD" = "cdrom" ]; then
      echo "hd$j" > /tmp/cdroms/cdrom$NUM
      (cd $MOUNTPOINT/dev ; ln -sf scd$NSCSI cdrom$NUM )
      NSCSI=$[NSCSI+1]
      NUM=$[NUM+1]
    fi
  done
done



#
# Check for pcmcia
#
if [ ! -f "/tmp/pcmcia" ]; then
  chroot $MOUNTPOINT update-rc.d -f pcmcia remove >> /tmp/pcmcia.log 2>&1
else
  echo "set bell-style none" >> $MOUNTPOINT/etc/inputrc
fi


#
# CREATE /etc/modules
#
echo "XXX Creando archivos de configuración..... XXX"
TMP="/tmp/modules"
cat <<EOF >$TMP
# /etc/modules: kernel modules to load at boot time.
#
# This file should contain the names of kernel modules that are
# to be loaded at boot time, one per line.  Comments begin with
# a #, and everything on the line after them are ignored.

EOF
modules=`tail +1 /proc/modules | grep -v '\[.*\]' | grep -v loop | grep -v squashfs | cut -d " " -f 1`
for mod in $modules
do
  echo $mod >>$TMP    
done
cp -f $TMP $MOUNTPOINT/etc/modules
    
    
#
# CREATE /etc/fstab
#
echo 85
cat <<EOF >$MOUNTPOINT/etc/fstab
# /etc/fstab: static file system information.
#
# The following is an example. Please see fstab(5) for further details.
# Please refer to mount(1) for a complete description of mount options.
#
# Format:
#  <file system>         <mount point>   <type>  <options>      <dump>  <pass>
$FSCHOICE  /  ext3  defaults,errors=remount-ro  0  1
EOF
if [ $SWCHOICE != none ] ; then
  echo "$SWCHOICE  none  swap  sw  0  0" >> $MOUNTPOINT/etc/fstab
fi
cat <<EOF >>$MOUNTPOINT/etc/fstab
proc  /proc  proc  defaults  0  0
none    /proc/bus/usb   usbdevfs        rw      0 0
none /a: supermount dev=/dev/fd0,fs=vfat,sync  0  0
EOF

# CDroms
for i in `ls /tmp/cdroms` ; do 
  echo "
none /$i supermount dev=/dev/$i,fs=iso9660,ro  0  0"  >> $MOUNTPOINT/etc/fstab
  mkdir -p $MOUNTPOINT/$i
done



# Add USB mount points
SDA=`grep sda /etc/fstab | grep -v usb`
SDB=`grep sdb /etc/fstab | grep -v usb`
NUM=0
if [ -z "$SDA" ]; then
  echo "
none /mnt/usb$NUM supermount dev=/dev/sda1,fs=vfat,sync  0  0" >> $MOUNTPOINT/etc/fstab

  mkdir $MOUNTPOINT/mnt/usb$NUM
  NUM=$[NUM+1]
fi
if [ -z "$SDB" ]; then
  echo "
none /mnt/usb$NUM supermount dev=/dev/sdb1,fs=vfat,sync  0  0" >> $MOUNTPOINT/etc/fstab

  mkdir $MOUNTPOINT/mnt/usb$NUM
fi


#
# COPY /etc/X11/XF86Config*
#
if [ -f "/etc/X11/XF86Config" ]; then
  cp -af /etc/X11/XF86Config $MOUNTPOINT/etc/X11/XF86Config
fi

if [ -f "/etc/X11/XF86Config-4" ]; then
  cp -af /etc/X11/XF86Config-4 $MOUNTPOINT/etc/X11/XF86Config-4
fi


sync

#
# BOOTLOADER
#
#
echo "XXX Configurando el grub..... XXX"
echo 90
if [  -f "/sbin/grub" -o -f "/sbin/grub-install" ] ; then
  if [ ! -d "/mnt/boot/grub" ] ; then
    mkdir -p /mnt/boot/grub > /tmp/grub.log 2>&1 &
  fi
  # Eliminar archivos antariores
  rm -f /mnt/boot/grub/device.map > /tmp/grub.log 2>&1 &
  rm -f /mnt/boot/grub/menu.lst > /tmp/grub.log 2>&1 &
  # Eliminar mensajes del kernel mientras se detectan dispositivos
  echo "0" > /proc/sys/kernel/printk
  # Crear el devices.map 
  grub-install --root-directory=/mnt $FSCHOICE > /tmp/grub-install.log 2>&1
  # Crear el menu.lst
  grub-config.sh $FSCHOICE > /tmp/grub.log 2>&1 &
  # Volver a activas lo mensajes del Kernel
  echo "6" > /proc/sys/kernel/printk

  # Ahora el nombre en formato GRUB
  DRIVE=${FSCHOICE%[0-9]}
  let PART=${FSCHOICE#$DRIVE}-1
  GRUB_DEV=`grep $DRIVE /mnt/boot/grub/device.map | cut -c2-4`
  ROOT="(${GRUB_DEV},${PART})"
  chroot /mnt/ grub --batch --device-map=/boot/grub/device.map <<EOT
root    $ROOT
setup   (hd0)
quit
EOT
  echo "XXX Grub configurado XXX"
else
  #FIXME Configurar el lilo
  echo "Configurar lilo"
fi

echo 95
ROOT=$MOUNTPOINT

echo "XXX Se está \
terminando de instalar $DISTRO en su disco duro. \
Espere un momento, en lo que se termina de instalar \
y configurar. XXX"  
while [ ! -f "/tmp/var.conf" ]; do
  sleep 1
done
. /tmp/var.conf

echo 98 
make-user.sh root $RPASSWORD $ROOT > /tmp/root.log 2>&1
make-user.sh $USERNAME $UPASSWORD $ROOT > /tmp/user.log 2>&1
# set HOSTNAME
chroot $ROOT hostname $HOSTNAME > /tmp/hostname.log 2>&1
echo $HOSTNAME > $ROOT/etc/hostname 2>> /tmp/hostname.log

# set /etc/hosts
echo "127.0.0.1       $HOSTNAME       localhost
::1             localhost       ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
ff02::3         ip6-allhosts" > $ROOT/etc/hosts 2> /tmp/hosts.log

# set /etc/network/interfaces
echo "auto lo
iface lo inet loopback" > $ROOT/etc/network/interfaces 2> /tmp/interfaces.log
if [ "$DHCP" = "Y" ]; then
  echo "auto    eth0
iface eth0 inet dhcp" >> $ROOT/etc/network/interfaces 2> /tmp/interfaces.log
else
    echo "auto    eth0
iface eth0 inet static
address $IP
netmask $NETMASK
broadcast $BROADCAST
gateway $GATEWAY" >> $ROOT/etc/network/interfaces 2> /tmp/interfaces.log
  echo "search
nameserver $DNS" > $ROOT/etc/resolv.conf 2> /tmp/resolv.log
fi
echo 100
# Arrancar la distro desde el disco
rm -f /mnt/etc/mtab
touch /mnt/etc/mtab
sync
swapoff -a 2>> /tmp/swapoff.log
umount /mnt 2>> /tmp/install.log
sync
echo 101
