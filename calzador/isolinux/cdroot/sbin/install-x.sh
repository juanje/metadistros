#!/bin/sh

ROOTDIR="/isolinux"
SBIN="$ROOTDIR/cdroot/sbin"
# Export ENV VARS and locales
. $ROOTDIR/conf/q.conf 
. $ROOTDIR/conf/var.conf


# Read Commandline
export `cat /proc/cmdline`
export DISTRO

# Locales
. $ROOTDIR/conf/lang.conf
# Set default keyboard before interactive setup
[ -n "$KEYTABLE" ] && loadkeys -q $KEYTABLE

export PATH="$SBIN:/bin:/usr/bin:/sbin:/usr/sbin"


#
# Comprobaciones
PARTED="qtparted"
rm -f /tmp/var.conf

# ¿Se preguntan los datos?
if [ "$QNEW" = "Y" ]; then
  QPASS=Y
  QUSER=Y
  QHOST=Y
  QNET=Y
  MOUNTALL=N
else
  MOUNTALL=N
fi



#
# Funcions

#
# Presentation
#
inicio()
{
  Xdialog --stdout --wrap --wizard --title "Instalación de ${DISTRO}" \
  --backtitle "Bienvenida" \
  --msgbox "Este programa ayuda en la instalación de $DISTRO \
  en el disco duro. Nótese que está todavía en \
  desarrollo. Si no sabe lo que hace puede perder la información de su ordenador" 16 45
  
  parted
}

#
# Disks
#
parted()
{
  # Desmontamos la SWAP para que se pueda cambiar la tabla de particiones
  while [ -n "`swapon -s | grep dev`" ]; do
    sync
    swapoff -a >> /tmp/install.log 2>&1
  done
  
  # Desmonta todas las particiones encontradas
  ERROR=""
  for i in /mnt/[sh]d* ; do
    umount $i && sync || ERROR="$i"
  done
  
  if [ -n "$ERROR" ]; then
    Xdialog --wrap --title "Instalación de ${DISTRO}" \
    --backtitle "ERROR" \
    --infobox  "No se pudo desmontar la partición ${ERROR}.\
    Se cerrará el instalador. Contacte con su administrador" 0 0 4000
    exit 1
  fi
  
  Xdialog --stdout --wrap --wizard --title "Instalación de ${DISTRO}" \
  --backtitle "Particionar el disco duro" \
  --msgbox "Ahora se arrancará una herramienta \
  con la que podrá particionar su disco duro.\n \
  Si no sabe lo que es una partición debería abandonar la instalación." 15 40
  
  ${PARTED}  2>> /tmp/install.log
  
  pselect
}


pselect()
{
  PARTITIONS=`/sbin/fdisk -l | awk '/^\/dev\// {if ($2 == "*"){if ($6 == "83") \
  { print $1 };} else {if ($5 == "83") { print $1 };}}'`
  
  if [ -z "$PARTITIONS" ]; then
    Xdialog --wrap --title "Instalación de ${DISTRO}" \
    --backtitle "ERROR" \
    --infobox  "No tiene ninguna partición de Linux, no se podrá instalar.\
    Compruebe su disco y vuelva a intentarlo" 0 0 4000
    parted
  fi
  
  NUMPART=0
  for i in $PARTITIONS; do 
    NUMPART=$[NUMPART+1]
  done
  
  PART=`Xdialog --stdout --wrap --wizard --title "Instalación de ${DISTRO}" \
  --backtitle "Particionar el disco duro" \
  --radiolist "Seleccione una partición :" 16 60 $NUMPART \
    $(for i in $PARTITIONS;  do echo "$i" "$i" off ; done)`
    
  case $? in
    0)
      if [ ! -b "$PART" ]; then
        Xdialog --wrap --title "Instalación de ${DISTRO}" \
        --backtitle "ERROR"\
        --infobox  "$PART no es una partición valida" 0 0 4000
        pselect
      fi
      ;;
    1|255)
      Xdialog --wrap--title "Instalación de ${DISTRO}" \
      --backtitle "ERROR"\
      --infobox "Ha salido de la aplicación" 0 0 5000
      exit 1
      ;;
    3)
      parted
      ;;
  esac
  echo "PART=$PART" >> /tmp/var.conf
  
  host
}


#
# HOSTNAME
host()
{ 
  HOSTNAME=`Xdialog --stdout --wrap --wizard --title "Instalación de ${DISTRO}" \
    --backtitle "Nombre del equipo" \
    --inputbox "Tanto si va a instalar, como si va a arrancar \
    desde el CDROM, deberá elegir un nombre para el sistema.  \
    ¿Cuál será el nombre de su equipo?" 12 50 $HOSTNAME`
  
  ret=$?
  case $ret in
    1|255)
      Xdialog --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Terminar" --infobox "Cerrando aplicación" 0 0 4000
      exit 0
      ;;
    3)
      pselect
      ;;
  esac
  
  echo "HOSTNAME=$HOSTNAME" >> /tmp/var.conf
  
  user
}


user()
{
  OK=0
  while [ "$OK" = 0 ]; do
  USER=`Xdialog --stdout --wrap --wizard --title "Instalación de ${DISTRO}" \
      --separator "|" \
      --backtitle "Login" \
      --left --password --password \
      --3inputsbox "Introduzca el nombre del usuario y \
                  su contraseña:" 20 60 \
             "Usuario:" "${USERNAME}" \
          "Contraseña:" "" \
              "Repita la contraseña:" ""`
  
  ret=$?
  case $ret in
    0)
        USERNAME=`echo $USER | awk -F"|" '{print $1}'` 
    PASS1=`echo $USER | awk -F"|" '{print $2}'`
    PASS2=`echo $USER | awk -F"|" '{print $3}'`
    if [ "$PASS1" != "$PASS2" ]; then
      Xdialog --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "ERROR" \
      --infobox "Las contraseñas no son iguales, repita la operación, por favor." 0 0 5000
          OK=0
      else
          OK=1
    UPASSWORD="$PASS1"
      fi
      ;;
    
    1|255)
      Xdialog --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Terminar" --infobox "Cerrando aplicación" 0 0 4000
      exit 0
      ;;
    3)
      host
      ;;
  esac
  
  done
  echo "USERNAME=$USERNAME
  UPASSWORD=$UPASSWORD" >> /tmp/var.conf
  
  proot
}


proot()
{
  OK=0
  while [ "$OK" = 0 ]; do
  PROOT=`Xdialog --stdout --wrap --wizard --title "Instalación de ${DISTRO}" \
      --separator "|" \
      --backtitle "Login Root" \
      --left --password --password \
      --2inputsbox "Introduzca una contraseña para el \
          usuario administrador:" 20 60 \
          "Contraseña:" "" \
          "Repita la contraseña:" ""`
  
  
  ret=$?
  case $ret in
    0)
      PASS1=`echo $PROOT | awk -F"|" '{print $1}'`
      PASS2=`echo $PROOT | awk -F"|" '{print $2}'`
      if [ "$PASS1" != "$PASS2" ]; then
        Xdialog --wrap --title "Instalación de ${DISTRO}" \
        --backtitle "ERROR"  \
        --infobox "Las contraseñas no son iguales, repita la operación, por favor." 0 0 5000
        OK=0
      else
        RPASSWORD="$PASS1"
        OK=1
      fi
      ;;
    
    1|255)
      Xdialog --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Terminar" --infobox "Cerrando aplicación" 0 0 4000
      exit 0
      ;;
    3)
      user
      OK=0
      ;;
  esac
  
  done
  echo "RPASSWORD=$RPASSWORD" >> /tmp/var.conf
  
  netconf
}



########


#
# NET 
# Bring up loopback interface now
netconf()
{
  ifconfig lo 127.0.0.1 up
  if [ "$QNET" = "Y" ]; then 
    Xdialog --wrap --wizard --title "Instalación de ${DISTRO}"  \
    --backtitle "Configuración de red" --yesno \
    "¿Desea configurar su conexión de red?" 12 50 
      
    case $? in
      0)
        NETCONF="Y"
        ;;
      1)
        NETCONF="N"
        ;;
      255)
        Xdialog --wrap --title "Instalación de ${DISTRO}" \
        --backtitle "Terminar" --infobox "Cerrando aplicación" 0 0 4000
        exit 0
        ;;
      3)
        proot
        ;;
    esac
  fi
  if [ "$NETCONF" = "Y" ]; then
    var="/tmp/var"
    tmp="/tmp/net"
  
    Xdialog --stdout --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Configuración de red" --menu \
      "Vamos a configurar la red. Puede usar DHCP para configurar la red de una forma \
      automática (siempre que exista un servidor DHCP), o puede configurar la tarjeta de red \
      manualmente.\n Eliga una opción:" 20 60 7  "DHCP" "Usar DHCP para configurar la red" \
      "Manual" "Configurar la red manualmente" > $var
  
    if [ "$?" = 1 -o "$?" = 255 ]; then
      Xdialog --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Terminar" --infobox "Cerrando aplicación" 0 0 4000
      exit 0
    fi
  
    mynetsel=`cat $var`
    if [ "$mynetsel" = "DHCP" ] ; then
      echo "DHCP=Y" >> /tmp/var.conf
      # Cleaning
      rm -f $tmp
      rm -f $var
    else
      Xdialog --stdout --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Dirección IP"  \ 
      --inputbox "Por favor, introduzca la dirección IP" 0 0 "$IP" > $tmp
      IP=`cat $tmp`
      Xdialog --stdout --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Broadcast" \
      --inputbox  "Por favor, introduzca el broadcast de su red" 0 0 "$BROADCAST" > $tmp
      BROADCAST=`cat $tmp`
      Xdialog --stdout --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Máscara de red"  \
      --inputbox  "Por favor, introduzca la máscara de red" \
         0 0 "$NETMASK" > $tmp
      NETMASK=`cat $tmp`
      Xdialog --stdout --wrap --title "Instalación de ${DISTRO}" \
      --backtitle "Puerta de enlace"  \
      --inputbox  "Por favor, introduzca su puerta de enlace" \
        0 0 "$GATEWAY" > $tmp
      GATEWAY=`cat $tmp`
      if [ "$DNS" = "" ] ; then
        Xdialog --stdout --wrap --title "Instalación de ${DISTRO}" \
        --backtitle "Servidor DNS"  \
        --inputbox  "Por favor, su servidor DNS (sólo uno por favor)" \
           0 0 "$DNS" > $tmp
        DNS=`cat $tmp`
      fi
      
      # Cleaning
      rm -f $tmp
      rm -f $var
      
      # Export vars
      echo "DHCP=N
IP=$IP
BROADCAST=$BROADCAST
NETMASK=$NETMASK
GATEWAY=$GATEWAY
DNS=$DNS" >> /tmp/var.conf
      fi
  else
    if [ "$DHCP" = "Y" ]; then
      echo "DHCP=Y" >> /tmp/var.conf
    fi
  fi
}

#
# Empieza la Instalacion
#
inicio


Xdialog --wrap --title "Instalación de ${DISTRO}" --no-buttons \
--backtitle "Instalación" --infobox "A continuación se instalará la distribución al disco.\n \
Este proceso puede llevar entre 5 y 30 minutos. Cuando termine se reiniciará el ordenador" 16 60 5000

install.sh $PART 2>> /tmp/install.log  | \
Xdialog --wrap --title "Instalación de ${DISTRO}" \
--backtitle "Instalación" --gauge "A continuación se instalará la distribución al disco.\n \
Este proceso puede llevar entre 5 y 30 minutos. Cuando termine se reiniciará el ordenador" 16 60

Xdialog --wrap --title "Instalación de ${DISTRO}" --no-buttons \
--backtitle "Fin de la Instalación" --infobox "Ha terminado la instalación. Ahora se reiniciará su ordenador.\n No se olvide de sacar el CD antes de que arranque." 16 60 6000

reboot
