#!/bin/sh

# Path de la imagen comprimida de la Metadistro
# Suponiendo que este montado el CD en /cdrom
IMAGE="/cdrom/META/META*"
CLOOP="/lib/modules/`uname -r`/kernel/drivers/block/cloop.o"

test()
{
  if [ ! -f "$1" ]; then
    echo "No existe el archivo $1"
    echo "Compruebe su sistema"
    exit 0
  fi
}

for i in tmp sources ; do
  if [ ! -d "/mnt/$i" ] ; then
    mkdir -p /mnt/$i
  fi
done

for i in $IMAGE $CLOOP ; do 
  if [ ! -f "$i" ]; then
    echo "ERROR: No existe el archivo $i"
    echo
    exit 0
  fi
done

# Se monta la distro
insmod $CLOOP file=$IMAGE
mount -o ro /dev/cloop /mnt/tmp/

# Copiamos la distribucion descomprimida al directorio en donde trabajaremos con ella.
cp -a /mnt/tmp/* /mnt/sources/

sync

# Se desmonta la imagen
umount /mnt/tmp

# Se elimina el modulo del cloop
rmmod cloop


