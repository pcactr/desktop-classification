#!/bin/bash

###############################################################################
##                                                                           ##
## UNCLASSIFIED                                                              ##
##                                                                           ##
###############################################################################

## Desktop Classification Labels v0.2.1
##
## requires:
## * ImageMagick
## optional:
## * classification-banner [https://github.com/fcaviggia/classification-banner]
## * xorg-x11-server-utils
##
## References: 
## * DoDM 5200.01
## * EO 13526
## * ICD 710
##

DCLVERSION='0.2.1'

LOGNAME=${LOGNAME}
ASUSER=${ASUSER}

## some pre-checks
if [[ $EUID -ne 0 ]]
then
  echo "ERROR: this script must be run as root"
  exit 1
fi

if [[ ! -e /bin/logger ]]; then
  ## If we cannot log, throw MacOS errors from 1984
  echo "ERROR: An error of type 1 has occurred"
  exit 1
else
  /bin/logger -t dcl "${LOGNAME} executed DCL as ${ASUSER}"
fi

## check for classification-banner
BANNERCFG='/etc/classification-banner'
if [[ -e /usr/local/bin/classification-banner.py ]]; then
  BANNERBIN='/usr/local/bin/classification-banner.py'
elif [[ -e /opt/classification-banner/classification-banner.py ]]; then
  BANNERBIN='/opt/classification-banner/classification-banner.py'
else
  echo "WARN: classification-banner not found"
fi

## function to ask for classification settings
classificationConfig () {
 ## FIXME: support JOINT classifications
 echo "Set the highest classification level of the system: "
 echo " 1. UNCLASSIFIED"
 echo " 2. CONFIDENTIAL"
 echo " 3. SECRET"
 echo " 4. TOP SECRET"
 echo ""
 read CLASSIFICATION
 
 case $CLASSIFICATION in
  1)
   CLASSIFICATION='UNCLASSIFIED'
   CAVEAT=''
   SHORT='UNCLASSIFIED'
   FGCOLOR='White'
   FGHEX='#FFFFFF'
   BGCOLOR='Green'
   BGHEX='#006600'
   ;;
  2)
   CLASSIFICATION='CONFIDENTIAL'
   CAVEAT=''
   SHORT='CONFIDENTIAL'
   FGCOLOR='White'
   FGHEX='#FFFFFF'
   BGCOLOR='Blue'
   BGHEX='#0000FF'
   ;;
  3)
   CLASSIFICATION='SECRET'
   CAVEAT=''
   SHORT='SECRET'
   FGCOLOR='White'
   FGHEX='#FFFFFF'
   BGCOLOR='Red'
   BGHEX='#FF0000'
   ;;
  4)
   CLASSIFICATION='TOP SECRET'
   CAVEAT=''
   SHORT='TOP SECRET'
   FGCOLOR='Black'
   FGHEX='#000000'
   BGCOLOR='Orange'
   BGHEX='#FF9900'
   ;;
  *)
   echo "ERROR: invalid selection"
   exit 1
   ;;
 esac
 
 if [[ ${CLASSIFICATION} == "UNCLASSIFIED" ]]
 then
   PRELINE=''
   echo "Set the CUI markings: "
   echo " 1. None"
   echo " 2. For Official Use Only"
   read CUI
   case $CUI in
     2)
      CAVEAT="For Official Use Only"
      SHORT="${SHORT}//FOUO"
      ;;
     *)
      ;;
   esac
 fi
 
 if [[ ${CLASSIFICATION} == "CONFIDENTIAL" ]] || [[ ${CLASSIFICATION} == "SECRET" ]] || [[ ${CLASSIFICATION} == "TOP SECRET" ]]
 then
   echo "Set the compartmentalization: "
   echo " 1. None"
   echo " 2. ${CLASSIFICATION}//SCI"
   read COMPARTMENT
   case $COMPARTMENT in
     2)
      PRELINE='SENSITIVE COMPARTMENTED INFORMATION'
      SHORT="${SHORT}//SCI"
      FGCOLOR='Black'
      FGHEX='#000000'
      BGCOLOR='Yellow'
      BGHEX='#FFFF00'
      ;;
     *)
      PRELINE='THIS INFORMATION SYSTEM IS CLASSIFIED'
      ;;
   esac
 
   echo "Set the dissemination control markings: "
   echo " 1. None"
   echo " 2. No Foreign (NOFORN)"
   echo " 3. Releasable to [...] (REL TO ...)"
  
   read RELEASABILITY
   case $RELEASABILITY in
     2)
      CAVEAT="Not Releasable to Foreign Nationals"
      SHORT="${SHORT}//NOFORN"
      ;;
     3)
      ## This doesn't have input validation right now...
      echo " Enter comma-separated releasable-to locations (ex. NATO, UK, ROK): "
      read REL
      CAVEAT="Releasable to USA, ${REL}"
      SHORT="${SHORT}//REL TO ${REL}"
      ;;
     *)
      ;;
 esac
 fi
}

## function to build the background
imagickBg () {
 convert -size ${RES} \
 xc: -sparse-color barycentric \
 "0,0 black -%w,%h black %w,%h ${BGCOLOR}" \
 "${CLASSIFICATION}.png"
 convert "${CLASSIFICATION}.png" \
 -fill ${FGCOLOR} \
 -gravity center \
 -family Arial \
 -pointsize 24 \
 -weight 800 \
 -draw "text 0,248 '${PRELINE}'" \
 -family Arial \
 -kerning '3.0' \
 -pointsize 80 \
 -weight 800 \
 -draw "text 0,300 '${CLASSIFICATION}'" \
 -family Arial \
 -pointsize 20 \
 -kerning '0.0' \
 -weight 200 \
 -draw "text 0,338 '${CAVEAT}'" \
 "${CLASSIFICATION}.png"
 mv "${CLASSIFICATION}.png" "/usr/share/backgrounds/${CLASSIFICATION}.png"
 chmod 444 "/usr/share/backgrounds/${CLASSIFICATION}.png"
 /sbin/restorecon "/usr/share/backgrounds/${CLASSIFICATION}.png"
 echo -e "File written to: /usr/share/backgrounds/${CLASSIFICATION}.png\n"
 /bin/logger -t dcl "${LOGNAME} generated /usr/share/backgrounds/${CLASSIFICATION}.png as ${ASUSER}"
}

## function to configure classification-banner
bannerConfig () {
  ## backup existing configuration file
  mv ${BANNERCFG} ${BANNERCFG}.bak 2>/dev/null
  ## FIXME: need interactive options to not blindly set some of these settings
  echo -e "message='${SHORT}'" > ${BANNERCFG}
  echo -e "fgcolor='${FGHEX}'" >> ${BANNERCFG}
  echo -e "bgcolor='${BGHEX}'" >> ${BANNERCFG}
  echo -e "show_top=True" >> ${BANNERCFG}
  echo -e "show_bottom=False" >> ${BANNERCFG}
  echo -e "opacity='0.80'" >> ${BANNERCFG}
  echo -e "esc=False" >> ${BANNERCFG}
  echo -e "sys_info=True" >> ${BANNERCFG}
  chmod 444 ${BANNERCFG}
  /sbin/restorecon ${BANNERCFG}
  echo -e "File written to: ${BANNERCFG} \n"
  /bin/logger -t dcl "${LOGNAME} generated ${BANNERCFG} as ${ASUSER}"
}

## interactive start
echo -e "## DCL ${DCLVERSION}\n\n"

## FIXME: unknown support for GDM 3.x
## check for GDM 2.x
rpm -q gdm 2>/dev/null | egrep -q 'gdm-2\.[0-9]+\.[0-9]+-[0-9]+\.el6\.(i686|x86_64)'
if ! [[ $? -eq 0 ]]; then
  echo "ERROR: gdm version is unknown"
  read -p "Unknown results may occur. Do you wish to proceed? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    /bin/logger -t dcl "${LOGNAME} initiated DCL with unknown GDM version as ${ASUSER}"
  else
    echo "\nExiting on unknown GDM version"
    exit 1
  fi
fi

## try to detect current resolution
if [[ -e /usr/bin/xrandr ]] && [[ $(/usr/bin/xrandr 2>/dev/null) && "$?" == "0" ]]
then
  res=$(xrandr 2>/dev/null| awk '/\*/ {print $1}' | uniq)
  echo "Screen resolution detected at: ${RES}"
else
  echo "ERROR: xrandr resolution lookup failed."
  echo "Attempting to continue in manual mode..."
  echo "Enter resolution (ex. 1024x768 or 1920x1080): "
  read RES
  ## could not get a pure bash parameter substitution working properly here
  XRES=$(echo ${RES}|cut -dx -f1)
  YRES=$(echo ${RES}|cut -dx -f2)
  ## currently configured ImageMagick text sizes only work well on >=1024x768
  ## no other sanity checking on resolution size
  if [[ ${XRES} -ge 1024 ]] && [[ ${YRES} -ge 768 ]]
    then
    echo "Resolution set to: ${RES}"
  else
    echo "ERROR: Resolution unsupported."
    exit 1
  fi
fi

## build config
classificationConfig && \
  /bin/logger -t dcl "${LOGNAME} configured system classification at ${SHORT} as ${ASUSER}"

## build background and configure gconf
if [ -e /usr/bin/convert ] && [ -n "${RES}" ]; then
  imagickBg
  if [[ "$?" == "0" ]]; then
    echo "Configuring gconf settings"
    ## Always show background
    gconftool-2 --direct \
    --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
    --type bool \
    --set /desktop/gnome/background/draw_background true
    ## Always show classification background
    gconftool-2 --direct \
    --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
    --type string \
    --set /desktop/gnome/background/picture_filename "/usr/share/backgrounds/${CLASSIFICATION}.png"
    find /etc/gconf/gconf.xml.mandatory -type d -exec chmod 755 {} \;
    find /etc/gconf/gconf.xml.mandatory -type f -exec chmod go+r {} \;
  fi
fi

## build banner config
if [ -e ${BANNERBIN} ]; then
  bannerConfig
fi

## restart GDM
GETRUN=$(runlevel|awk '{print $2}')
if [[ ${GETRUN} -eq 5 ]] && [[ -n $DISPLAY ]]; then
 read -p "Do you wish to restart the GUI? " -n 1 -r
 if [[ $REPLY =~ ^[Yy]$ ]]; then
  /bin/logger -t dcl "${LOGNAME} initiated GDM restart as ${ASUSER}"
  su - ${LOGNAME} -c "gnome-session-save --silent --kill" 1>/dev/null
 else
  echo -e "\nThe GUI must be restarted to reflect the changes."
 fi
else
 echo -e "\nThe GUI must be restarted to reflect the changes."
fi

###############################################################################
##                                                                           ##
## UNCLASSIFIED                                                              ##
##                                                                           ##
###############################################################################
