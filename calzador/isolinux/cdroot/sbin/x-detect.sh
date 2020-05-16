#!/bin/sh

####
# Deteccion
#
# Frecuencia horizontal, vertical y Modelines del Monitor
HREFRESH="$(ddcxinfo -hsync 2> /tmp/xserver.log)"
VREFRESH="$(ddcxinfo -vsync 2>> /tmp/xserver.log)"
MODELINES="$(ddcxinfo -modelines 2>> /tmp/xserver.log)"
MOUSEDEV="$(mdetect 2>> /tmp/xserver.log  | grep ^/dev )"

# Buscar Driver de la tarjeta de video
CARDS="/isolinux/cdroot/hwdata/cards.lst"
IDS=`cut -f 2 /proc/bus/pci/devices 2>> /tmp/xserver.log`
DRIVER="vesa"
FOUND=""
for ID in $IDS ; do
  FOUND=`grep $ID $CARDS | cut -f 2  2>> /tmp/xserver.log`
  if [ -n "$FOUND" ]; then
    DRIVER="$FOUND"
  fi
done 
####

####
# Comprobaciones
#
ROOT="/"
if [ -n "$1" ]; then
  ROOT="$1"
fi
ROOT="${ROOT}/etc/X11"
if [ ! -d "$ROOT" ]; then
  mkdir -p "$ROOT"
fi
XF86Config="${ROOT}/XF86Config-4"
if [ "$VMWARE" = "Y" ]; then
  DRIVER="vesa"
fi
if [ -z "$XKEYBOARD" ]; then
  XKEYBOARD="es"
fi
if [ -z "$HREFRESH" -o "$HREFRESH" = "0-0" ]; then
  HREFRESH="31.5 - 57"
fi
if [ -z "$VREFRESH" -o "$VREFRESH" = "0-0" ]; then
  VREFRESH="50 - 90"
fi

# MOUSE
case "$MOUSEDEV" in
  /dev/ttyS?)
    MOUSECONF="
Section \"InputDevice\"
  Identifier  \"Generic Mouse Serial\"
  Driver    \"mouse\"
  Option    \"CorePointer\"
  Option    \"Device\"    \"${MOUSEDEV}\"
  Option    \"Protocol\"    \"Microsoft\"
  Option    \"Emulate3Buttons\"  \"true\"
  Option    \"ZAxisMapping\"    \"4 5\"
EndSection
    "
    MOUSETYPE="  InputDevice  \"Generic Mouse Serial\""
    ;;
  /dev/psaux)
    MOUSECONF="
Section \"InputDevice\"
  Identifier  \"Generic Mouse PS/2\"
  Driver      \"mouse\"
  Option    \"CorePointer\"
  Option      \"Protocol\" \"PS/2\"
  Option      \"Device\" \"/dev/psaux\"
  Option      \"Emulate3Buttons\" \"true\"
  Option      \"Emulate3Timeout\" \"70\"
  Option      \"ZAxisMapping\"  \"4 5\"
  Option      \"SendCoreEvents\"  \"true\"
EndSection
    "
    MOUSETYPE="  InputDevice  \"Generic Mouse PS/2\""
    ;;

  *)
    MOUSECONF="
Section \"InputDevice\"
  Identifier  \"Generic Mouse Serial\"
  Driver    \"mouse\"
  Option    \"Device\"    \"/dev/ttyS0\"
  Option    \"Protocol\"    \"Microsoft\"
  Option    \"Emulate3Buttons\"  \"true\"
  Option    \"ZAxisMapping\"    \"4 5\"
EndSection

Section \"InputDevice\"
  Identifier  \"Generic Mouse PS/2\"
  Driver      \"mouse\"
  Option    \"CorePointer\"
  Option      \"Protocol\" \"PS/2\"
  Option      \"Device\" \"/dev/psaux\"
  Option      \"Emulate3Buttons\" \"true\"
  Option      \"Emulate3Timeout\" \"70\"
  Option      \"ZAxisMapping\"  \"4 5\"
  Option      \"SendCoreEvents\"  \"true\"
EndSection

Section \"InputDevice\"
  Identifier  \"Generic Mouse USB\"
  Driver    \"mouse\"
  Option    \"SendCoreEvents\"  \"true\"
  Option    \"Device\"    \"/dev/input/mice\"
  Option    \"Protocol\"    \"ImPS/2\"
  Option    \"Emulate3Buttons\"  \"true\"
  Option    \"ZAxisMapping\"    \"4 5\"
EndSection
    "
    MOUSETYPE="  InputDevice  \"Generic Mouse Serial\"
  InputDevice  \"Generic Mouse PS/2\"
  InputDevice  \"Generic Mouse USB\""
    ;;
esac

  
####


####
# Escribir el archivo /etc/X11/XF86Config-4
#
cat >"$XF86Config" <<EOF
Section "Files"
  FontPath  "unix/:7100"      # local font server
  # if the local font server has problems, we can fall back on these
  FontPath  "/usr/lib/X11/fonts/Type1"
  FontPath  "/usr/lib/X11/fonts/CID"
  FontPath  "/usr/lib/X11/fonts/Speedo"
  FontPath  "/usr/lib/X11/fonts/misc"
  FontPath  "/usr/lib/X11/fonts/cyrillic"
  FontPath  "/usr/lib/X11/fonts/100dpi"
  FontPath  "/usr/lib/X11/fonts/75dpi"
EndSection

Section "Module"
#  Load  "GLcore"
  Load  "bitmap"
  Load  "dbe"
#  Load  "ddc"
  Load  "dri"
  Load  "extmod"
  Load  "glx"
  Load  "int10"
  Load  "record"
  Load  "speedo"
  Load  "type1"
  Load  "vbe"
  Load  "xtt"
EndSection

Section "InputDevice"
  Identifier  "Generic Keyboard"
  Driver    "keyboard"
  Option    "CoreKeyboard"
  Option    "XkbRules"  "xfree86"
  Option    "XkbModel"  "pc105"
  Option    "XkbLayout"  "${XKEYBOARD}"
EndSection

Section "ServerFlags"
  Option "AllowMouseOpenFail"  "true"
EndSection

${MOUSECONF}

Section "Device"
  Identifier  "Generic Video Card"
  Driver    "${DRIVER}"
EndSection

Section "Monitor"
  Identifier  "Generic Monitor"
  HorizSync  ${HREFRESH}
  VertRefresh  ${VREFRESH}
  Option    "DPMS"
$MODELINES
EndSection

Section "Screen"
  Identifier  "Default Screen"
  Device    "Generic Video Card"
  Monitor    "Generic Monitor"
  DefaultDepth  16
  SubSection "Display"
    Depth    1
    Modes    "1024x768" "800x600" "640x480"
  EndSubSection
  SubSection "Display"
    Depth    4
    Modes    "1024x768" "800x600" "640x480"
  EndSubSection
  SubSection "Display"
    Depth    8
    Modes    "1024x768" "800x600" "640x480"
  EndSubSection
  SubSection "Display"
    Depth    15
    Modes    "1024x768" "800x600" "640x480"
  EndSubSection
  SubSection "Display"
    Depth    16
    Modes    "1024x768" "800x600" "640x480"
  EndSubSection
  SubSection "Display"
    Depth    24
    Modes    "1024x768" "800x600" "640x480"
  EndSubSection
EndSection

Section "ServerLayout"
  Identifier  "Default Layout"
  Screen    "Default Screen"
  InputDevice  "Generic Keyboard"
${MOUSETYPE}
EndSection

Section "DRI"
  Mode  0666
EndSection
EOF

####
