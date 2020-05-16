# Arrancar servicios
for i in cupsys fam
do
  if [ -f "/etc/init.d/$i" ]; then
    /etc/init.d/$i start
  fi
done

# Icono de instalacion en el escritorio
cp -fp /isolinux/cdroot/templates/Install.desktop /home/$1/Desktop/
cp -fp /isolinux/cdroot/templates/install.png /tmp/

# Posibilitar que el grupo wheel no necesite poner clave en el "su"
rm -f /etc/pam.d/su 
cp -fp /isolinux/cdroot/templates/su /etc/pam.d/

# Dispositivos en el home
for i in `(ls /mnt/ | grep -v test)` ; do
  ln -s /mnt/$i /home/$1/
done
for i in "/a:" /cdrom? ; do
  if [ $i != '/cdrom?' ]; then
    ln -s $i /home/$1/
  fi
done

# Aspecto del escritorio
rm -f /home/$1/.nautilus/metafiles/file\:%2F%2F%2Fhome%2F*%2F.gnome-desktop.xml
rm -f /home/$1/.nautilus/metafiles/file\:%2F%2F%2Fhome%2F*%2FDesktop.xml
cp -a /isolinux/cdroot/templates/file\:%2F%2F%2Fhome%2F*%2FDesktop.xml /home/$1/.nautilus/metafiles/file\:%2F%2F%2Fhome%2F$1%2FDesktop.xml
cp -a /isolinux/cdroot/templates/x-nautilus-desktop:%2F%2F%2F.xml /home/$1/.nautilus/metafiles/

# Evitar que salte el Screensaver
rm -f /home/$1/.xscreensaver

# Para arrancar una sesion de X 
#rm -f /home/$1/.xsession
#cp -fa /isolinux/cdroot/templates/.xsession /home/$1/

# Permisos adecuados en el HOME
chown -R $1.users /home/$1/

