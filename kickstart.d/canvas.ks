# Kickstart file for Korora Remix Canvas (GNOME) x86_64
# To use this for 32bit build, :4,$s/x86_64/i386/g
# and build with 'setarch i686 livecd-creator ...'

#
# KP:DESCRIPTION:START
#
# var KP_RELEASE_META_LABEL=canvas
#
#
# KP:DESCRIPTION:END
#

%include %%KP_KICKSTART_DIR%%/canvas-base.ks
#%include %%KP_KICKSTART_DIR%%/fedora-live-minimization.ks
#%include %%KP_KICKSTART_DIR%%/fedora-livecd-desktop.ks

#
# PACKAGES
#

%packages

#
# Live CD specific stuff
@anaconda-tools
anaconda
fpaste
kernel
#kernel-modules-extra
memtest86+
nss-mdns

#
#Install 3rd party repo releases
adobe-release
google-chrome-release
google-earth-release
google-talkplugin-release
rpmfusion-free-release
rpmfusion-nonfree-release

#
# (RE)BRANDING
elementary-icon-theme
#grub2-starfield-theme
korora-extras
korora-release
korora-logos
-korora-release-notes
korora-settings-gnome
korora-welcome
#korora-videos
plymouth-theme-korora

#
# Fonts
@fonts
#dejavu-sans-fonts
#dejavu-sans-mono-fonts
#dejavu-serif-fonts
##gnu-free-mono-fonts
##gnu-free-sans-fonts
##gnu-free-serif-fonts
#liberation-mono-fonts
#liberation-sans-fonts
#liberation-serif-fonts

#
# Canvas specific packages

@base-x
@core
@critical-path-gnome
@guest-desktop-agents
@hardware-support
#@input-methods
alsa-utils
bash-completion
bridge-utils
chrony
cups
empathy
evince
evolution
evolution-mapi
evolution-ews
file-roller
file-roller-nautilus
firefox
firewall-config
font-manager
fprintd-pam
gedit
gnome-documents
gnome-initial-setup
gnome-screenshot
#gnome-shell-extension-weather
#gnome-shell-extension-alternative-status-menu
#gnome-shell-extension-xrandr-indicator
#gnome-shell-extension-presentation-mode
gnome-shell-extension-drive-menu
gnome-shell-extension-user-theme
gnome-shell-extension-places-menu
gnome-tweak-tool
gnome-user-docs
gparted
gucharmap
gvfs-archive
gvfs-goa
gvfs-gphoto2
gvfs-mtp
gvfs-smb
pharlap
#jockey-gtk
#jockey-selinux
#jockey-akmods
libproxy-networkmanager
mlocate
mozilla-adblock-plus
mozilla-downthemall
mozilla-flashblock
mozilla-xclear
nautilus-sendto
net-tools
network-manager-applet
NetworkManager-l2tp
NetworkManager-openconnect
NetworkManager-openswan
NetworkManager-openvpn
NetworkManager-pptp
NetworkManager-vpnc
#NetworkManager-wimax
PackageKit-browser-plugin
PackageKit-command-not-found
PackageKit-gstreamer-plugin
PackageKit-gtk3-module
PackageKit-yum-plugin
prelink
rhythmbox
seahorse
setroubleshoot
shotwell
simple-scan
spice-server
spice-vdagent
strongswan
system-config-printer
system-config-printer-udev
tar
totem
totem-nautilus
totem-mozplugin
wget
yum-updatesd

%end

%post

echo -e "\n*****\nPOST SECTION\n*****\n"

# KP - build out of kernel modules (so it's not done on first boot)
echo -e "\n***\nBUILDING AKMODS\n***"
/usr/sbin/akmods --force

# KP - import keys
echo -e "\n***\nIMPORTING KEYS\n***"
for x in 18 19 20
do
  for y in fedora-$x-primary fedora-$x-secondary google-chrome google-earth google-talkplugin virtualbox adobe rpmfusion-free-fedora-$x-primary rpmfusion-nonfree-fedora-$x-primary korora-$x-primary korora-$x-secondary
  do
    KEY="/etc/pki/rpm-gpg/RPM-GPG-KEY-${y}"
    if [ -r "${KEY}" ];
    then
      rpm --import "${KEY}" && echo "IMPORTED: $KEY (${y})"
    else
      echo "IMPORT KEY NOT FOUND: $KEY (${y})"
    fi
  done
done

# KP - start yum-updatesd
systemctl enable yum-updatesd.service

# KP - update locate database
/usr/bin/updatedb

# KP - let's run prelink (makes things faster)
echo -e "***\nPRELINKING\n****"
/usr/sbin/prelink -av -mR -q

# KP
# live image setup is done by fedora-live-base.ks, such as:
#   - create user
# live imate modification is done in this init script, such as:
#   - set autologin,
#   - enable installer
cat >> /etc/rc.d/init.d/livesys << EOF


# disable updates plugin
cat >> /usr/share/glib-2.0/schemas/org.gnome.settings-daemon.plugins.updates.gschema.override << FOE
[org.gnome.settings-daemon.plugins.updates]
active=false
FOE

# don't run gnome-initial-setup
mkdir ~liveuser/.config
touch ~liveuser/.config/gnome-initial-setup-done

# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
  # need to move it to anaconda.desktop to make shell happy
  mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

  cat >> /usr/share/glib-2.0/schemas/org.korora.gschema.override << FOE
[org.gnome.shell]
favorite-apps=['firefox.desktop', 'evolution.desktop', 'vlc.desktop', 'shotwell.desktop', 'libreoffice-writer.desktop', 'nautilus.desktop', 'gnome-documents.desktop', 'anaconda.desktop']
FOE
fi

# KP - disable screensaver locking
cat >> /usr/share/glib-2.0/schemas/org.gnome.desktop.screensaver.gschema.override << FOE
[org.gnome.desktop.screensaver]
lock-enabled=false
FOE

# KP - hide the lock screen option
cat >> /usr/share/glib-2.0/schemas/org.gnome.desktop.lockdown.gschema.override << FOE
[org.gnome.desktop.lockdown]
disable-lock-screen=true
FOE

# KP - ensure liveuser desktop exists
mkdir ~liveuser/Desktop

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up auto-login
cat > /etc/gdm/custom.conf << FOE
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=liveuser
FOE

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# KP - don't let prelink run on the live image
#sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink # actually this forces prelink to run to undo prelinking (see /etc/sysconfig/prelink)
mv /usr/sbin/prelink /usr/sbin/prelink-disabled
rm /etc/cron.daily/prelink

# KP - un-mute sound card (fixes some issues reported)
amixer set Master 85% unmute 2>/dev/null
amixer set PCM 85% unmute 2>/dev/null
pactl set-sink-mute 0 0
pactl set-sink-volume 0 50000

# KP - turn off screensaver
gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory --type bool --set /apps/gnome-screensaver/idle_activation_enabled false

# KP - disable yum update service
systemctl --no-reload disable yum-updatesd.service 2> /dev/null || :
systemctl stop yum-updatesd.service 2> /dev/null || :

# KP - disable jockey from autostarting
rm /etc/xdg/autostart/jockey*

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/

EOF

%end
