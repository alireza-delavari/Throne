#!/bin/bash
# FINAL_UBUNTU20_COMPAT_CONTAINER_SAFE_NO_WAYLAND_FORCE_V2
set -euo pipefail

rm -rf "$DEST"
mkdir -p "$DEST"

#### copy binary ####
cp "$GITHUB_WORKSPACE/build/Throne" "$DEST"

#### copy Throne.png ####
cp "$GITHUB_WORKSPACE/res/public/Throne.png" "$DEST"

#### copy Go artifacts ####
cd download-artifact
cd *"$DEST_SUFFIX"
tar xvzf artifacts.tgz -C ../../
cd ../..

if [ -f "$DEST/updater" ]; then
  chmod +x "$DEST/updater"
else
  echo "No Linux updater bundled; continuing without updater."
fi

export APPIMAGE_EXTRACT_AND_RUN=1

wget -O "linuxdeploy-$ARCH.AppImage" "https://github.com/linuxdeploy/linuxdeploy/releases/latest/download/linuxdeploy-$ARCH.AppImage"
wget -O "linuxdeploy-plugin-qt-$ARCH.AppImage" "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/latest/download/linuxdeploy-plugin-qt-$ARCH.AppImage"
chmod +x "linuxdeploy-$ARCH.AppImage" "linuxdeploy-plugin-qt-$ARCH.AppImage"

# Keep the package focused on X11/XCB for Ubuntu 20.04 compatibility.
# Do not force Wayland plugins: some Qt packages do not provide libqwayland.so,
# and bundling Wayland plugins can introduce extra system dependencies.
export EXTRA_QT_PLUGINS="iconengines;"
export EXTRA_PLATFORM_PLUGINS=""

./linuxdeploy-$ARCH.AppImage --appdir "$DEST" --executable "$DEST/Throne" --plugin qt
rm -f "linuxdeploy-$ARCH.AppImage" "linuxdeploy-plugin-qt-$ARCH.AppImage"

cd "$DEST"
rm -rf ./usr/translations ./usr/bin ./usr/share ./apprun-hooks

# fix plugins rpath
rm -rf ./usr/plugins
mkdir -p ./usr/plugins/platforms

cp "$QT_PLUGIN_PATH/platforms/libqxcb.so" ./usr/plugins/platforms/

for plugin_dir in platformthemes imageformats iconengines tls; do
  if [ -d "$QT_PLUGIN_PATH/$plugin_dir" ]; then
    cp -r "$QT_PLUGIN_PATH/$plugin_dir" ./usr/plugins/
  fi
done

for plugin in \
  ./usr/plugins/platforms/libqxcb.so \
  ./usr/plugins/platformthemes/libqgtk3.so \
  ./usr/plugins/platformthemes/libqxdgdesktopportal.so; do
  if [ -f "$plugin" ]; then
    patchelf --set-rpath '$ORIGIN/../../lib' "$plugin"
  fi
done

# fix extra libs
shopt -s nullglob
mkdir -p ./usr/lib2
ls ./usr/lib/
LIBS_TO_KEEP=(
  ./usr/lib/libQt*
  ./usr/lib/libxcb-cursor*
  ./usr/lib/libxcb-util*
  ./usr/lib/libicuuc*
  ./usr/lib/libicui18n*
  ./usr/lib/libicudata*
)
if [ "${#LIBS_TO_KEEP[@]}" -eq 0 ]; then
  echo "No libraries matched packaging keep list."
  exit 1
fi
cp "${LIBS_TO_KEEP[@]}" ./usr/lib2/
rm -rf ./usr/lib
mv ./usr/lib2 ./usr/lib
shopt -u nullglob

# fix executable rpath
cd "$DEST"
patchelf --set-rpath '$ORIGIN/usr/lib' ./Throne

# handle debug info
objcopy --only-keep-debug "$DEST/Throne" "$DEST/Throne.debug"
strip --strip-debug --strip-unneeded "$DEST/Throne"
objcopy --add-gnu-debuglink="$DEST/Throne.debug" "$DEST/Throne"
