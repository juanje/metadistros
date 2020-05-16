#!/bin/sh
# Author          : Raúl Sánchez Sánchez  
# Created On      : Thu Mar 25 12:00:15 2003
# Last Modified By: Juan Jesús Ojeda Croissier
# Last Modified On: Wed May 28 17:48:44 2003
#
# USAGE: 
#    $ make-user.sh username password
# username: the name of new user or root
# password: password of user. Without this password
# make one entry without password in /etc/shadow

# Gettext
export TEXTDOMAINDIR=locale
export TEXTDOMAIN=make-user

#
# USER no ROOT
if [ -z "$3" ]; then
  if [ "$1" != "root" ]; then
    /usr/sbin/useradd -m -d /home/$1 $1
    /usr/sbin/adduser $1 audio
    /usr/sbin/addgroup wheel
    /usr/sbin/adduser $1 wheel
  fi
else
  if [ "$1" != "root" ]; then
    chroot $3 /usr/sbin/useradd -m -d /home/$1 $1
    chroot $3 /usr/sbin/adduser $1 audio
    chroot $3 /usr/sbin/addgroup wheel
    chroot $3 /usr/sbin/adduser $1 wheel
    if [ -f "/mnt/home/$1/.primera_vez" ]; then
      cd $3/home/$1/.nautilus/metafiles/
      mv file\:%2F%2F%2Fhome%2F*%2F.gnome-desktop.xml file\:%2F%2F%2Fhome%2F$1%2F.gnome-desktop.xml
      rm -f $3/home/$1/.primera_vez
    fi
    for i in `ls $3/mnt/` ; do
      ln -s $3/mnt/$i $3/home/$1/$i
    done
    ln -s $3/floppy $3/home/$1/disquete
    for i in `ls $3/ | grep cdrom` ; do
       ln -s $3/$i $3/home/$1/$i
    done
  fi
fi

if [ -z "$3" ]; then
  echo "$1:$2" > /tmp/passwd
  
  # Putting the password
  /usr/sbin/chpasswd < /tmp/passwd
  
  # Cleaning
  rm -f /tmp/passwd
else
  chroot $3 echo "$1:$2" > /tmp/passwd
  
  # Putting the password
  chroot $3 /usr/sbin/chpasswd < /tmp/passwd
  
  # Cleaning
  rm -f /mnt/tmp/passwd
fi
