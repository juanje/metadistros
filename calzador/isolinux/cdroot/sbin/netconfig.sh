#!/bin/sh
#
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

# Author          : Israel Santana Alemán
# Created On      : Miér Jul 03 15:37:12 2003
# Last Modified By: Israel Santana Alemán
# Last Modified On: Sáb Jul 05 01:18:00 2003


ROOTDIR="/isolinux"

var="/tmp/var"
tmp="/tmp/net"
# Añadiendole soporte de Gettext
export TEXTDOMAINDIR=locale
export TEXTDOMAIN=netconfiG

  dialog  --backtitle "$DISTRO" --title "`gettext -s "Configuración de red"`" --menu \
    "`gettext -s "Vamos a configurar la red. Puede usar DHCP para configurar la red de una forma \
    automática (siempre que exista un servidor DHCP), o puede configurar la tarjeta de red \
    manualmente, Eliga una opción:"`" 20 60 7  "DHCP" "`gettext -s "Usar DHCP para configurar la red"`" \
    "Manual" "`gettext -s "Configurar la red manualmente"`" 2> $var
  # No cambiar la valor de DHCP en el diálogo anterior puesto que lo usa en el if siguiente
  # Please, don't change "DHCP" in this dialog since is used in the next if
  mynetsel=`cat $var`
  if [ "$mynetsel" = "DHCP" ] ; then
    pump
    # Cleaning
    echo "DHCP=Y" > /tmp/netvars 2> /tmp/netconf.log
    rm -f $tmp
    rm -f $var
    exit 0
  fi
    dialog  --backtitle "$DISTRO" --title "`gettext "Dirección IP"`" --inputbox "`gettext \ 
      "Por favor, introduzca la dirección IP"`" 0 0 "$IP" 2> $tmp
    IP=`cat $tmp`
    dialog --backtitle "$DISTRO" --title "`gettext -s "Broadcast"`" --inputbox \
      "`gettext "Por favor, introduzva el broadcast de su red"`" 0 0 "$BROADCAST" 2> $tmp
    BROADCAST=`cat $tmp`
    dialog --backtitle "$DISTRO" --title "`gettext -s ·"Máscara de red"`" --inputbox \
      "`gettext -s "Por favor, introduzca la máscara de red"`" \
       0 0 "$NETMASK" 2> $tmp
    NETMASK=`cat $tmp`
    dialog --backtitle "$DISTRO" --title "`gettext -s "Puerta de enlace"`" --inputbox \
      "`gettext -s "Por favor, introduzca su puerta de enlace"`" \
      0 0 "$GATEWAY" 2> $tmp
    GATEWAY=`cat $tmp`
  if [ "$DNS" = "" ] ; then
    dialog --backtitle "$DISTRO" --title "`gettext -s "Servidor DNS"`" --inputbox \
      "`gettext -s "Por favor, su servidor DNS (sólo uno por favor)"`" \
       0 0 "$DNS" 2> $tmp
    DNS=`cat $tmp`
    /bin/echo "$DNS nameserver" > /etc/resolv.conf
  else
    /bin/echo "$DNS nameserver" > /etc/resolv.conf
    /bin/echo "$DNS2 nameserver" >> /etc/resolv.conf
  fi
  /sbin/ifconfig eth0 $IP broadcast $BROADCAST netmask $NETMASK
  if [ "$GATEWAY" != "" ] ; then
    /sbin/route add default gw $GATEWAY dev eth0 netmask 0.0.0.0 metric 1  
  fi
  
  # Cleaning
  rm -f $tmp
  rm -f $var
  
  # Export vars
    echo "
DHCP=N
IP=$IP
BROADCAST=$BROADCAST
NETMASK=$NETMASK
GATEWAY=$GATEWAY
DNS=$DNS" > /tmp/netvars 2> /tmp/netconf.log
