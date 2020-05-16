#! /bin/sh
# Crea el archivo menu.lst de GRUB para su sistema
# Copyright (C) 2002 A.Ullán-J.L.Redrejo.
#
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
###########################################################
# Variables
KERNEL=`uname -r`

###########################################################
# empieza el trabajo de localizar discos, particiones y sistemas
for i in a b c d e f g
do
  DISCO=hd$i
  esta=`grep $DISCO /mnt/boot/grub/device.map | cut -c12-14`
  if [ -n "$esta" ]; then 
    fdisk -l /dev/$DISCO | grep ^/dev >> /tmp/salfdisk
  fi
done
# SCSI
for i in a b c d e f g
do
  DISCO=sd$i
  esta=`grep $DISCO /mnt/boot/grub/device.map | cut -c12-14`
  if [ -n "$esta" ]; then
    fdisk -l /dev/$DISCO | grep ^/dev >> /tmp/salfdisk
  fi
done
########################
# función para convertir las unidades y particiones en
# formato GRUB. uso: convierte tipo disco parte
TIPOL=""
DISCOL=""
PARTIL=""
convierte () {
  # Ahora el nombre en formato GRUB
  DRIVE=$1$2
  NUMERO=`grep $DRIVE /mnt/boot/grub/device.map | cut -c2-4`
  let PART=$3-1
  NOMBRE="(${NUMERO},${PART})"
  if [ "$1" = "sd" ]; then
    INFORME="SCSI"
  else 
    INFORME="IDE"
  fi
}
# fin de funcion

#
# lineas para la Distro
rm -f /mnt/boot/grub/menu.lst
SOS=1
echo "
timeout 8
default 0
fallback 1
" >> /mnt/boot/grub/menu.lst
# veamos Linux
TIPOL=`echo $1 | cut -c6-7`
DISCOL=`echo $1 | cut -c8-8`
PARTIL=`echo $1 | cut -c9-9`
convierte "$TIPOL" "$DISCOL" "$PARTIL"
nucleo=`ls /mnt/boot/ | grep vmlinuz | grep $KERNEL`
# Parametros scsi
PARAMS=" "
for i in /tmp/cdroms/* ; do
  DEV=`cat $i`
  PARAMS=$PARAMS"$DEV=ide-scsi "
done

echo "
title Linux ($DISTRO)
root $NOMBRE
kernel /boot/$nucleo root=/dev/${TIPOL}${DISCOL}${PARTIL} ${PARAMS}" >> /mnt/boot/grub/menu.lst

#
# lineas de WIN
win () {
  let SOS=SOS+1
  echo "##########################
title $TITULO en Disco $INFORME $TIPOD$DISCO$PARTI $TIPOP
rootnoverify $NOMBRE
makeactive
chainloader +1 " >> /mnt/boot/grub/menu.lst
}
# fin de la función win
#
# otros sistemas operativos
otros_so () {
  # uso: otros_so linea_de_fichero_dev/XXXX
  # empezamos con los Win en FAT32
  TIPOD=`cat $1 | grep FAT32 | cut -c6-7`
  DISCO=`cat $1 | grep FAT32 | cut -c8-8`
  PARTI=`cat $1 | grep FAT32 | cut -c9-9`
  TIPOP=FAT32
  if [ -z $DISCO ]; then
    :
  else
    convierte "$TIPOD" "$DISCO" "$PARTI"
    mount -o ro /dev/"$TIPOD""$DISCO""$PARTI" /mnt/mnt
      if [ -f /mnt/mnt/boot.ini ]; then
        BUSCA=`cat /mnt/mnt/boot.ini | grep Windows | grep XP`
        if [ -z "$BUSCA" ]; then
          TITULO="WINDOWS 2000 "
          win
        else
          TITULO="WINDOWS XP "
          win
        fi
      else
        if [ -f /mnt/mnt/autoexec.bat ]; then
          TITULO="WINDOWS 9X"
          win
        fi
      fi
    umount /mnt/mnt
  fi
  # Win en NTFS
  #
  TIPOD=`cat $1 | grep NTFS | cut -c6-7`
  DISCO=`cat $1 | grep NTFS | cut -c8-8`
  PARTI=`cat $1 | grep NTFS | cut -c9-9`
  TIPOP=NTFS
  if [ -z $DISCO ]; then
    :
  else
    convierte "$TIPOD" "$DISCO" "$PARTI"
    mount -o ro /dev/"$TIPOD""$DISCO""$PARTI" /mnt/mnt
      if [ -f /mnt/mnt/boot.ini ]; then
        BUSCA=`cat /mnt/mnt/boot.ini | grep Windows | grep XP`
        if [ -z "$BUSCA" ]; then
          TITULO="WINDOWS 2000 "
          win
        else
          TITULO="WINDOWS XP "
          win
        fi
      fi
    umount /mnt/mnt
  fi
  #
  # otros linux
  #
  TIPOD=`cat $1 | grep Linux | grep 83 | cut -c6-7`
  DISCO=`cat $1 | grep Linux | grep 83 | cut -c8-8`
  PARTI=`cat $1 | grep Linux | grep 83 | cut -c9-9`
  if [ -z $DISCO ]; then
      :
  else
    convierte "$TIPOD" "$DISCO" "$PARTI"
    mount -t ext2 -o ro /dev/"$TIPOD""$DISCO""$PARTI" /mnt/mnt/
    if [ -d /mnt/mnt/boot ]; then
      ls /mnt/mnt/boot | grep vmlinuz > /tmp/ficheros
      wc -l /tmp/ficheros | cut -c7-7 > /tmp/filas
      nfilas=`sed -n 1,1p  /tmp/filas | head --bytes=1`
      for i in `seq 1 $nfilas`;
      do
        sed -n "$i","$i"p /tmp/ficheros > /tmp/fila
        KERNEL=`cat /tmp/fila`
        NUMERACION=`cat /tmp/fila | cut -c8-22`
        if [ -f /mnt/boot/initrd.img"$NUMERACION" ]; then
          LINEA2="initrd /boot/initrd.img"$NUMERACION""
        fi
        otrolinux
      done
    fi
    umount /mnt/mnt
  fi
}
#
otrolinux () {
  let SOS=SOS+1
  echo "
title Linux en Disco $INFORME "$TIPOD""$DISCO""$PARTI" Kernel"$NUMERACION"
root $NOMBRE
kernel /boot/$KERNEL root=/dev/"$TIPOD""$DISCO""$PARTI"
  $LINEA2 " >> /mnt/boot/grub/menu.lst
}

#
############################################################3
# trabajo con salfdisk 
wc /tmp/salfdisk | cut -c6-7 > /tmp/lineas
nlineas=`sed -n 1,1p  /tmp/lineas | head --bytes=2`
for i in `seq 1 $nlineas`;
do
  sed -n "$i","$i"p /tmp/salfdisk > /tmp/linea
  PRIMEROS=`cat /tmp/linea | head -c9`
  if [  "$PRIMEROS" = "/dev/"$TIPOL""$DISCOL""$PARTIL"" ]; then
    :
  else
    PRIMEROS=`cat /tmp/linea | head -c5`
    if [ "$PRIMEROS" = "/dev/" ]; then
        otros_so /tmp/linea
    fi
  fi
done
if [ $SOS -gt 1 ]; then 
  sed -e 's/timeout 1/timeout 12/g' /mnt/boot/grub/menu.lst > /tmp/menut.tmp
  mv -f /tmp/menut.tmp /mnt/boot/grub/menu.lst
fi
echo "SO encontrados: $SOS"
rm -f /tmp/salfdisk
rm -f /tmp/filas
rm -f /tmp/ficheros
rm -f /tmp/lineas
rm -f /tmp/linea
rm -f /tmp/fila
