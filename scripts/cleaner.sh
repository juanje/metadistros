#!/bin/sh
PWD=`pwd`

usage()
{
  echo "Uso: ${0##*/} [directorio]"
  cat <<OPTIONS

        --help  Muestra esta ayuda y sale.
  [directorio]  Directorio en donde estan las 
      fuentes de la distribucion

  ejemplos:
    ./cleaner.sh /mnt/source/
    ./cleaner.sh /Linex/

OPTIONS
}

error()
{
  echo "ERROR:"
  echo
  case $1 in
    0)
      echo "Debe poner algun argumento"
      break
      ;;
    1)
      echo "$2 no es un directorio valido"
      break
      ;;
    *)
      break
      ;;
  esac
  echo
  usage
  exit 0
}

if [ -n "$1" ]; then
  case $1 in
    --help)
      usage
      exit 0
      ;;
    *)
      if [ -d "$1" ]; then
        cd $1
        rm -fr tmp/* etc/mtab root/.bash_history 
        rm -f root/.viminfo etc/X11/XF86Config*
        rm -f dev/cdrom dev/mouse
        ln -s /proc/mounts etc/mtab
        cd var
        rm -f log/* log/*/* tmp/* spool/* 2> /dev/null
        cd $PWD

        # Eliminar los usuarios de /etc/passwd y /etc/group
        TEMP_FILE="/tmp/users"
        for FILE in passwd group
        do
          :> $TEMP_FILE
          cat $1/etc/$FILE | while read LINE
          do
            if [  -n "`echo  $LINE | grep audio`" ] ; then
              echo "audio:x:29:" >> $TEMP_FILE
            elif [  -n "`echo  $LINE | grep wheel `" ] ; then
              echo "wheel:x:103:" >> $TEMP_FILE
            elif [ `echo $LINE | cut -d : -f 3` -lt 999 ] ; then
              echo $LINE >> $TEMP_FILE
            fi
          done

          # usar cat para no alterar los permisos
          cat $TEMP_FILE > $1/etc/$FILE
        done
        rm -f $TEMP_FILE
        rm -fr $1/home/*

        # Desmontar el /proc/
        umount $1/proc 2> /dev/null

        echo "$1 limpio"
      else
        error 1 $1
      fi
      break
      ;;
  esac
else
  error 0
fi
