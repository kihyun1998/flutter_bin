#!/bin/bash
# Builds nested bundles and compares where macOS places each executable with
# where flutter_bin resolves the same path.
set -eu
T="$RUNNER_TEMP/Contents"   # a folder named Contents above the bundle
rm -rf "$T"; mkdir -p "$T"
swiftc -O -o "$RUNNER_TEMP/owner" .github/probe-45/owner.swift

# bundle <dir> <id> <exe> <plist-subdir>
bundle() {
  local dir="$1" id="$2" exe="$3" sub="$4"
  mkdir -p "$dir/$sub" "$dir/Contents/MacOS"
  cat > "$dir/$sub/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$id</string>
<key>CFBundleName</key><string>$id</string>
<key>CFBundleExecutable</key><string>$exe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PL
  cp "$RUNNER_TEMP/owner" "$dir/Contents/MacOS/$exe"
}

O="$T/Outer.app"
bundle "$O" probe.outer outer Contents
bundle "$O/Contents/Helpers/Helper.app" probe.helper helper Contents
bundle "$O/Contents/Library/LoginItems/Login.app" probe.login login Contents
bundle "$O/Contents/Frameworks/F.framework/Versions/A/Helpers/FH.app" probe.fwhelper fwhelper Contents
bundle "$O/Contents/PlugIns/Ext.appex" probe.appex ext Contents
# A versioned framework: Info.plist under Resources, binary at the top.
F="$O/Contents/Frameworks/F.framework"
mkdir -p "$F/Versions/A/Resources"
cat > "$F/Versions/A/Resources/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>probe.framework</string>
<key>CFBundleName</key><string>probe.framework</string>
<key>CFBundleExecutable</key><string>F</string>
<key>CFBundlePackageType</key><string>FMWK</string>
</dict></plist>
PL
cp "$RUNNER_TEMP/owner" "$F/Versions/A/F"
ln -s A "$F/Versions/Current"
ln -s Versions/Current/F "$F/F"
ln -s Versions/Current/Resources "$F/Resources"

EXES=(
  "$O/Contents/MacOS/outer"
  "$O/Contents/Helpers/Helper.app/Contents/MacOS/helper"
  "$O/Contents/Library/LoginItems/Login.app/Contents/MacOS/login"
  "$O/Contents/Frameworks/F.framework/Versions/A/Helpers/FH.app/Contents/MacOS/fwhelper"
  "$O/Contents/PlugIns/Ext.appex/Contents/MacOS/ext"
)
DIRS=(
  "$O"
  "$O/Contents/Helpers/Helper.app"
  "$O/Contents/Library/LoginItems/Login.app"
  "$O/Contents/Frameworks/F.framework/Versions/A/Helpers/FH.app"
  "$O/Contents/PlugIns/Ext.appex"
  "$F"
  "$O/Contents"
  "$O/Contents/Info.plist"
)

echo "== macOS: Bundle.main of each executable"
for e in "${EXES[@]}"; do echo -n "$e	"; "$e"; done
echo "== macOS: Bundle(path:)"
"$RUNNER_TEMP/owner" "${DIRS[@]}" "${EXES[@]}"
echo "== flutter_bin: resolveInfoPlistPath and the productName read"
dart run .github/probe-45/resolve.dart "${EXES[@]}" "${DIRS[@]}"

echo "== Installed apps: CFBundleShortVersionString shape and CFBundleGetInfoString"
total=0; nonthree=0; getinfo=0
while IFS= read -r -d '' app; do
  p="$app/Contents/Info.plist"; [ -f "$p" ] || continue
  total=$((total+1))
  v=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$p" 2>/dev/null || echo '<absent>')
  if ! [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then nonthree=$((nonthree+1)); echo "shape	$v	$app"; fi
  if /usr/libexec/PlistBuddy -c 'Print :CFBundleGetInfoString' "$p" >/dev/null 2>&1; then getinfo=$((getinfo+1)); echo "getinfo	$app"; fi
done < <(find /Applications /System/Applications /System/Library/CoreServices -maxdepth 3 -name '*.app' -type d -print0 2>/dev/null)
echo "apps=$total not-three-integers=$nonthree with-CFBundleGetInfoString=$getinfo"
sw_vers
