#!/bin/sh
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

# Author          : Juan Jesús Ojeda Croissier 
# Created On      : Wed Mar 18 15:37:12 2003
# Last Modified By: Juan Jesús Ojeda Croissier
# Last Modified On: Lun Jul 04 16:56:44 2003



ROOTDIR="/isolinux"
SBIN="$ROOTDIR/cdroot/sbin"
# Export ENV VARS and locales
. $ROOTDIR/conf/q.conf 
. $ROOTDIR/conf/var.conf

PARTED="cfdisk"

# We need /proc here, so mount it in case we skipped the bootfloppy
[ -f /proc/version ] || mount -t proc none /proc 2> /dev/null

# Read Commandline
export `cat /proc/cmdline`
export DISTRO

# Locales
. $ROOTDIR/conf/lang.conf
# Set default keyboard before interactive setup
[ -n "$KEYTABLE" ] && loadkeys -q $KEYTABLE

export PATH="$SBIN:/bin:/usr/bin:/sbin:/usr/sbin"

# Gettext
export TEXTDOMAINDIR=locale
export TEXTDOMAIN=init

#progress: 3er tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 300 21 FCD123 -d /dev/fb0
fi

#
# Comprobaciones
## ¿Se instala?
if [ "$1" = "--install" -o "$INSTALL" = "Y" ]; then
  INSTALL=Y
  QNEW=Y
  XCONF=N
  QSPLASH=N
  QINSTALL=N
  if [ "$2" = "X" ]; then
                #PARTED="qtparted"
    # Put "dialog" for ncurses or "xdialog" for X
    alias dialog="Xdialog"
  fi
else
  # Execute scripts for hardware detection in backend
  hw-detect.sh ${SPLASH} > /tmp/hw.log 2>&1 &
fi

# ¿Se preguntan los datos?
if [ "$INSTALL" = "Y" -a "$QNEW" = "Y" ]; then
  QPASS=Y
  QUSER=Y
  QHOST=Y
  QNET=Y
    MOUNTALL=N
else
    MOUNTALL=N
fi



#
# Funcion partitions()
partitions()
{
  #
  # Presentation
  #
  dialog --backtitle "$DISTRO" --title "Instalación de $DISTRO" \
  --msgbox "Este script ayuda en la instalación de $DISTRO \
  en el disco duro. Nótese que el Calzador está todavía en \
  desarrollo. El autor no toma ninguna responsabilidad \
  en caso de pérdida de datos o daño del hardware." 16 45
  
  #
  # Disks
  #
  # Tamaño de particiones: mind. 1.5 GB Filesystem, mind. 128 MB Swap.
  FSMIN=1500
  SWAPMIN=128
  # Tamaño total del Sistema descomprimido
  NCLOOPFSMIN=4400
  
  # Tamaño del initrd: 2.5 MB
  INSIZE=2500
  
  # Auswahl der Platte zum Partitionieren
  TMP="/tmp/partitions"
  NUMHD=0
  if [ -f /proc/partitions ] ; then
    while read x x x p x
    do
      case "$p" in
        hd?)
          if [ "`cat /proc/ide/$p/media`" = "disk" ] ; then
            echo "$p `tr ' ' _ </proc/ide/$p/model`" >> $TMP
            NUMHD=$[NUMHD+1]
          fi
          ;;
        sd?)
          x="`scsi_info /dev/$p | grep MODEL | tr ' ' _`"
          x=${x#*\"}
          x=${x%\"*}
          echo "$p $x" >> $TMP
          NUMHD=$[NUMHD+1]
          ;;
        *) ;;
      esac
    done < /proc/partitions
  fi
  HARDDISKS="`cat $TMP`"
  
  dialog --backtitle "$DISTRO" --title "Particionar el disco duro" \
  --radiolist "Seleccione un disco duro (La barra espaciadora selecciona):" 16 60 $NUMHD \
    $(echo "$HARDDISKS" | while read p model ; do echo "$p" "$model" off ; done) 2> $TMP
    
  HDCHOICE="`cat $TMP`"
  
  if [ -z "$HDCHOICE" ] ; then
    dialog --backtitle "$DISTRO" --title "Particionar el disco duro" --msgbox "No se ha seleccionado un disco duro. El script finalizará." 15 40
    rm -f $TMP
    exit 0
  fi
  
  # Abrimos un treminal para ver logs
  sbin/getty 38400 tty2  >> /tmp/getty.log 2>&1 &
  
  # Desmontamos la SWAp para que se pueda cambiar la tabla de particiones
  while [ -n "`swapon -s | grep dev`" ]; do
    sync
    swapoff -a >> /tmp/install.log 2>&1
  done
  
  dialog --backtitle "$DISTRO" --title "Particionar el disco duro" \
  --msgbox "Ha elegido el Disco duro /dev/$HDCHOICE. \
  Ahora se arrancará la herramienta ${PARTED} \
  de particionado." 15 40
  
  ${PARTED} /dev/$HDCHOICE 2>> /tmp/install.log
  
  PARTITIONS=`/sbin/fdisk -l | awk '/^\/dev\// {if ($2 == "*"){if ($6 == "83") \
  { print $1 };} else {if ($5 == "83") { print $1 };}}'`
  
  # Añadido por marti
  if [ -z $PARTITIONS ] ; then
    dialog --backtitle "$DISTRO" --title "Particionar el disco duro" \
    --msgbox "No se han detectado particiones compatibles con \
    Linux. Tendrá a que volver a particionar su disco duro. \
    El programa terminaraá." 15 40
    exit 1
  fi 
  
  TMP="/tmp/partition"
  rm -f $TMP 2> /dev/null
  
  NUMPART=0
  for i in $PARTITIONS
    do 
    NUMPART=$[NUMPART+1]
  done
  
  dialog --backtitle "$DISTRO" --title "Particionar el disco duro" \
  --radiolist "Seleccione una particion (La barra espaciadora selecciona):" 16 60 $NUMPART \
    $(for i in $PARTITIONS;  do echo "$i" "$i" off ; done) 2> $TMP
    
  PART="`cat $TMP`"
  
  if [ ! -b "$PART" ]; then
    echo "$PART no es una particion valida" > /tmp/ERROR
    exit 1
  fi
  
  install.sh $PART >> /tmp/install.log 2>&1 &
}

#progress: 4o tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 450 21 FCD123 -d /dev/fb0
fi                                                                      
                                      
#
# Language selection

if [ "$QLANG" = "Y" ]; then
  TEMPFILE="/tmp/menu"
  dialog --backtitle "$DISTRO" --title "Idioma / Language / Hizkuntza" --menu "" 15 100 6\
    es "Selecciona esta opción para continuar Español"\
    eu "Aukeratu hau Euskaraz jarraitzeko"\
    en "Choose this option to continue in english" 2>/tmp/menuitem.$$
    
  MENUITEM=`cat /tmp/menuitem.$$`  
  case $MENUITEM in
    es) LANGUAGE="es";;
    eu) LANGUAGE="eu";;
    en) LANGUAGE="en";;
      *) LANGUAGE="es";;
  esac

  # Locales
  . $ROOTDIR/conf/lang.conf
  # Set default keyboard before interactive setup
  [ -n "$KEYTABLE" ] && loadkeys -q $KEYTABLE

fi




#
# Presentation
#progress: 5o tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 500 21 FCD123 -d /dev/fb0
elif [ "$QSPLASH" = "Y" ]; then 
  dialog --backtitle "$DISTRO" \
    --infobox "`gettext -s "¡¡Bienvenido a $DISTRO!!\n\
    Esta es una distribución  de GNU/Linux que simplifica al máximo su uso e instalación .\
    La instalación se puede llevar a cabo en poco tiempo y de forma casi totalmente \
    automática. \n\
    También puede usar $DISTRO directamente desde el lector de CD-ROM\
    sin necesidad de modificar nada en su ordenador."`" 15 40  
fi

########

#
# INSTALL or LIVE
if [ "$QINSTALL" = "Y" ]; then 
  #
  # Install or Live
  TEMPFILE="/tmp/menu"
  rm -f $TEMPFILE 2> /dev/null
  dialog --backtitle "$DISTRO" \
    --clear --title "`gettext -s "Instalación o Live"`" \
      --menu "`gettext -s "¿Qué desea hacer Arrancar desde el CDROM,\
      o Instalar en el Disco Duro?"`" 20 51 4 \
      "Live"  "`gettext -s "Arrancar desde el CDROM"`" \
      "Install" "`gettext -s "Instalar en el Disco Duro"`" 2> $TEMPFILE
  
  RETVAL=$?
  
  CHOICE="$(cat $TEMPFILE)"
  if [ "$CHOICE" = "Install" ]; then
    INSTALL="Y"
    partitions
  fi

  # Cleaning
  rm -f $TEMPFILE 2> /dev/null
  
else 
  #Default option
  if [ "$INSTALL" = "Y" ]; then
    partitions
  fi
fi

#
# HOSTNAME 
if [ "$QHOST" = "Y" ]; then 
  TEMPFILE="/tmp/hostname"
  rm -f $TEMPFILE 2> /dev/null
  dialog --backtitle "$DISTRO" \
    --inputbox "`gettext -s "Tanto si va a instalar, como si va a arrancar\n\
    desde el CDROM, deberá elegir un nombre para el sistema. \n\
    ¿Cuál será el nombre de su equipo?"`" 12 50 $HOSTNAME 2> $TEMPFILE
    
  HOSTNAME="$(cat $TEMPFILE)"
  # Cleaning
  rm -f $TEMPFILE 2> /dev/null
fi


#
# USER
if [ "$QUSER" = "Y" ]; then 
  TEMPFILE="/tmp/user"
  rm -f $TEMPFILE 2> /dev/null
  # NAME
  dialog --backtitle "$DISTRO" \
    --inputbox "`gettext -s "Tanto si va a instalar, como si va a arrancar\n\
    desde el CDROM, deberá elegir un nombre de usuario en el sistema. \n\
    ¿Cuál será su nombre de Usuario?"`" 12 50 $USERNAME 2> $TEMPFILE
    
  USERNAME="$(cat $TEMPFILE)"
  
  # PASSWORD
  dialog --backtitle "$DISTRO" \
    --passwordbox "`gettext -s "Tanto si va a instalar, como si va a arrancar\n\
    desde el CDROM, deberá elegir una clave para el usuario $USERNAME. \n\
    Escriba la clave del usuario $USERNAME"`" 12 50 2> $TEMPFILE
    
  UPASSWORD="$(cat $TEMPFILE)"
  
  STARTUSER="$USERNAME"

  # Cleaning
  rm -f $TEMPFILE 2> /dev/null

fi


#
# ROOT PASSWORD 
if [ "$QPASS" = "Y" ]; then 
  TEMPFILE="/tmp/root"
  dialog --backtitle "$DISTRO" \
    --passwordbox "`gettext -s "Tanto si va a instalar, como si va a arrancar\n\
    desde el CDROM, deberá elegir una clave para el Administrador (root). \n\
    Escriba la clave del usuario root"`" 12 50 2> $TEMPFILE
    
  RPASSWORD="$(cat $TEMPFILE)"

  # Cleaning
  rm -f $TEMPFILE 2> /dev/null

fi


########
#
# START whith root user?
if [ "$ROOT" = "Y" ]; then
  STARTUSER="root"
fi



########


#
# NET 
# Bring up loopback interface now
ifconfig lo 127.0.0.1 up
if [ "$QNET" = "Y" ]; then 
  dialog --backtitle "$DISTRO" \
    --yesno "`gettext -s "¿Desea configurar su conexión de red?"`" 12 50 
    
  if [ $? = 0 ]; then
    NETCONF="Y"
  fi
fi
until [ -f "/tmp/modules.ready" ] ; do
  sleep 1
done
if [ "$NETCONF" = "Y" ]; then
  netconfig.sh >/tmp/net.log 2>&1
else
  if [ "$DHCP" = "Y" ]; then
    pump >/tmp/net.log 2>&1 &
  fi
fi


#
# XWINDOW
if [ "$QX" = "Y" ]; then 
  x-detect.sh > /tmp/xserver.log 2>&1
else
  #Default option
  if [ "$XCONF" = "Y" ]; then
    # Make XF86Config
    x-detect.sh > /tmp/xserver.log 2>&1
  fi
fi

#progress: 6o tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 560 21 FCD123 -d /dev/fb0
fi

########
if [ -f "/tmp/ERROR" ]; then
  INSTALL="N"
fi


#
# INSTALL or LIVE
if [ "$INSTALL" = "Y" ]; then
  dialog --backtitle "$DISTRO" --infobox "Se esta\
  terminando de instalar $DISTRO en su disco duro.\
  Espere unos minutos, en lo que se termina de instalar\
  y configurar." 0 0
  #execute the scripts in chroot
  if [ -f /tmp/netvars ]; then
    cat /tmp/netvars >> /tmp/var.conf
  fi
  echo "RPASSWORD=$RPASSWORD
USERNAME=$USERNAME
UPASSWORD=$UPASSWORD
HOSTNAME=$HOSTNAME" >> /tmp/var.conf
  exit 0
else
  make-user.sh root $RPASSWORD > /tmp/root.log 2>&1
  make-user.sh $USERNAME $UPASSWORD > /tmp/user.log 2>&1
  # set HOSTNAME
  hostname $HOSTNAME > /tmp/hostname.log 2>&1
  echo $HOSTNAME > /etc/hostname 2>> /tmp/hostname.log

  # set /etc/hosts
  echo "127.0.0.1       $HOSTNAME       localhost
::1             localhost       ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
ff02::3         ip6-allhosts" > /etc/hosts 2> /tmp/hosts.log
  # Si es un portatil quitamos la campana
        if [ -f "/tmp/pcmcia" ]; then
      rm -f /etc/inputrc
      cp -f /META/etc/inputrc /etc/
            echo "set bell-style none" >> /etc/inputrc
        fi
fi



#
# Boot LIVE
#
for i in 3 4 5 ; do
  /sbin/getty 38400 tty$i  2>> /tmp/getty.log &
done
  # Add hacks
  hacks.sh $USERNAME > /tmp/hacks.log 2>&1

#progress: 6o tramo
if [ "$SPLASH" = "Y" ] ; then
  progress 204 667 600 21 FCD123 -d /dev/fb0
  for TTY in 1 2 3 4 ; do
    splash -n -s -u $TTY /isolinux/cdroot/templates/bootsplash-1024x768.cfg > /tmp/splash.log 2>&1
  done
fi


if [ "$STARTX" = "Y" ]; then
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/X11"
  ${SBIN}/splash -s -u 0 /isolinux/cdroot/templates/bye.cfg &
  if [ -f "/home/$USERNAME/.xsession" ] ; then
    su -c "startx" $STARTUSER
  else
    su -c "xinit /usr/bin/x-session-manager" $STARTUSER 
  fi
  sleep 1
  sync
  swapoff -a && \
  if [ -f /tmp/swapfile ]; then
    FILE=($(< /tmp/swapfile))
    swapoff ${FILE[1]} && \
    umount $FILE && mount -o rw $FILE && \
    rm -f ${FILE[1]} && sync
  fi
  umount -a -d -f 2>> /dev/tty2
  halt
  
else
  su - $STARTUSER
  ${SBIN}/splash -s -u 0 /isolinux/cdroot/templates/bye.cfg
  sleep 2
  sync
  swapoff -a && \
  if [ -f /tmp/swapfile ]; then
    FILE=($(< /tmp/swapfile))
    swapoff ${FILE[1]} && \
    umount $FILE && mount -o rw $FILE && \
    rm -f ${FILE[1]} && sync
  fi
  umount -a -d -f 2>> /dev/tty2
  halt
fi
