#!/bin/sh

# Directorios que se van a usar:
 # directorio donde esta descoprimida la distro(Knoppix modificada) -> unos 2 Gb
SOURCES=/mnt/sources
 # directorio con el que se va a crear la iso final. Contiene el boot.img -> entre 600 y 650 Mb
MASTER=/mnt/master
 # directorio en donde se va a guardar la iso final, el cd para tostar  -> entre 600 y 650 Mb
ISODIR=/mnt/iso

#Nombre de la Distribucion
DISTRO=Metadistro
VER=0.1

usage()
{
  echo "Uso: ${0##*/} [accion]"
  cat <<OPTIONS

--help  Muestra esta ayuda y sale.

accion
  -m, meta    Crea una imagen de la distribucion.
  -c, cloop    Crea una imagen ISO comprimida.
  -i, iso      Crea la imagen ISO final.
  -b, grabar          Graba en un CD la ISO final.
  -a, todo               Realiza todas las anteriores
  
opciones
  --clean    Elimina todos los archivos intermedios
  --blank    Opcion para "grabar". Borra el CD-RW antes de grabar

ejemplos: 
  ./${0##*/} cloop
  ./${0##*/} iso
  ./${0##*/} grabar
  ./${0##*/} -a

OPTIONS
}


# Comprobaciones
if [ ! -d "$SOURCES" ] ; then
  echo "No existe el directorio $SOURCES"
  exit 0
fi

if [ ! -d "$MASTER" ] ; then
  echo "No existe el directorio $MASTER"
  exit 0
fi

if [ ! -d "$ISODIR" ] ; then
  mkdir -p $ISODIR
fi


# Opiones
# Mira las opciones introducidas por linea de comandos
if [ $# != 0 ] ; then
  while true ; do
    case "$1" in 
      --help)
        usage
        exit 0
        ;;
      -m|meta)
        META="Y"
        shift
        ;;
      -c|cloop)
        CLOOP="Y"
        shift
        ;;
      -i|iso)
        ISO="Y"
        shift
        ;;
      -b|grabar)
        BURN="Y"
        shift
        ;;
      -a|todo)
        META="Y"
        CLOOP="Y"
        ISO="Y"
        BURN="Y"
        shift
        ;;
      --clean)
        CLEAN="Y"
        shift
        ;;
      --blank)
        BLANK="Y"
        shift
        ;;
      *)
        break
        ;;
    esac
  done
else
  echo "Uso: ${0##*/} [accion]..."
  echo "Ejecuta ${0##*/} --help para mas informacion."
  exit 1
fi


if [ "$META" = "Y" ]; then
  # Primero crea una imagen ISO de la distro
  mkisofs  -R -L -allow-multidot -l -V "${DISTRO} iso9660 filesystem" \
  -o $ISODIR/${DISTRO}.iso -hide-rr-moved -v $SOURCES
fi

sleep 2

if [ "$CLOOP" = "Y" ]; then

  rm -f $MASTER/META/META.cloop
  # Despues comprime la imagen y crea una imagen comprimida
  create_compressed_fs $ISODIR/${DISTRO}.iso  65536 > $MASTER/META/META.cloop
  
  if [ "$CLEAN" = "Y" ]; then
    # Borra la imagen ISO de la distro
    rm -rf $ISODIR/${DISTRO}.iso
  fi
  sync
  sleep 2

fi


if [ "$ISO" = "Y" ]; then 

  # Ahora crea el la imagen ISO final con lo que haya en el directorio $MASTER.
  #Y crea el sector de arranque 
  /bin/cp -f /usr/lib/syslinux/isolinux.bin $MASTER/isolinux/
  mkisofs -l -r -J -V "${DISTRO}" -hide-rr-moved -v -b isolinux/isolinux.bin \
  -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
  -o $ISODIR/${DISTRO}-${VER}.iso $MASTER
  
  # Borra la imagen comprimida de la distro
  if [ "$CLEAN" = "Y" ]; then
    if [ "$CLOOP" = "Y" ]; then
      rm -fr $MASTER/META/META.cloop
    else
      rm -fr $MASTER/META/META
    fi
  fi
  
  sleep 2

fi


if [ "$BURN" = "Y" ]; then

  # Ahora se tuesta el CD
  BUS=`cdrecord --scanbus 2> /dev/null |  awk '{if ( $1 ~ /^[0-9]/ ) {if ($3 !~ /*/) {print $1} exit}}'`
  
  if [ "$BLANK" = "Y" ]; then
    # Si es un regrabable (muy recomendable para hacer pruebas) se borra.
    cdrecord dev=$BUS blank=all
  fi
  
   # Y ahora se tuesta. Se puede cambiar la velocidad de la grabacion, si tu grabadora te lo permite
  cdrecord -v dev=$BUS $ISODIR/${DISTRO}-${VER}.iso
  
  if [ "$CLEAN" = "Y" ]; then
    # Se borra la imagen ISO final
    rm -fr $ISODIR/${DISTRO}-${VER}.iso
  fi

fi
