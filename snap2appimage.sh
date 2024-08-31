#!/usr/bin/env sh
#
# Convert Snap package to AppImage. Usage:
#
# $ ./snap2appimage.sh skype
#
SNAP_PACKAGE="${1}"

if [ -z "${SNAP_PACKAGE}" ]; then
    echo "Usage: ./snap2appimage.sh snap-package-name"
    exit 1
fi

create_temporary_folder() {
    mkdir -p /tmp/snap2appimage && cd /tmp/snap2appimage || exit 1
}

download_appimagetool() {
    if ! test -f ./appimagetool; then
        wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
        chmod a+x ./appimagetool
    fi
}

download_snap_package() {
    if ! test -f ./*.snap; then
        wget "$(curl -H 'Snap-Device-Series: 16' http://api.snapcraft.io/v2/snaps/info/"${SNAP_PACKAGE}" --silent | sed 's/[()",{} ]/\n/g' | grep "^http" | head -1)"
    fi
}

extract_snap_package() {
    if ! test -d ./squashfs-root; then
        unsquashfs -f ./*.snap
    fi
}

# TEMPORARY DIRECTORY
mkdir -p tmp
cd ./tmp || exit 1

# DOWNLOAD APPIMAGETOOL
if ! test -f ./appimagetool; then
	wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
	chmod a+x ./appimagetool
fi

# DOWNLOAD THE SNAP PACKAGE
if ! test -f ./*.snap; then
	wget -q "$(curl -H 'Snap-Device-Series: 16' http://api.snapcraft.io/v2/snaps/info/skype --silent | sed 's/[()",{} ]/\n/g' | grep "^http" | head -1)"
fi

# EXTRACT THE SNAP PACKAGE AND CREATE THE APPIMAGE
unsquashfs -f ./*.snap
mkdir -p "${SNAP_PACKAGE}".AppDir
VERSION=$(cat ./squashfs-root/*.yaml | grep "^version" | head -1 | cut -c 10-)
mv ./squashfs-root/usr/share/skypeforlinux/* ./"${SNAP_PACKAGE}".AppDir/
mv ./squashfs-root/usr/share/pixmaps/skypeforlinux.png ./"${SNAP_PACKAGE}".AppDir/
mv ./squashfs-root/snap/gui/skypeforlinux.desktop ./"${SNAP_PACKAGE}".AppDir/
sed -i 's#${SNAP}/meta/gui/skypeforlinux.png#skypeforlinux#g; s#Network;Application;##g' ./"${SNAP_PACKAGE}".AppDir/*.desktop

cat >> ./"${SNAP_PACKAGE}".AppDir/AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD="${HERE}"
exec "${HERE}"/skypeforlinux "$@"
EOF
chmod a+x ./"${SNAP_PACKAGE}".AppDir/AppRun

ARCH=x86_64 ./appimagetool --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 20 ./"${SNAP_PACKAGE}".AppDir
cd ..
mv ./tmp/*.AppImage ./Skype-"$VERSION"-x86_64.AppImage

