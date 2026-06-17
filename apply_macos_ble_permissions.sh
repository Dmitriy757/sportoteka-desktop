#!/bin/bash
set -euo pipefail

ROOT="${1:-.}"
ENTITLEMENTS=(
  "macos/Runner/DebugProfile.entitlements"
  "macos/Runner/Release.entitlements"
)
INFO_PLIST="macos/Runner/Info.plist"

add_or_replace_bool() {
  local plist="$1"
  local key="$2"
  local value="$3"
  /usr/libexec/PlistBuddy -c "Delete :${key}" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :${key} bool ${value}" "$plist"
}

add_or_replace_string() {
  local plist="$1"
  local key="$2"
  local value="$3"
  /usr/libexec/PlistBuddy -c "Delete :${key}" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :${key} string ${value}" "$plist"
}

echo "== Sportoteka macOS Bluetooth permission patch =="

for rel in "${ENTITLEMENTS[@]}"; do
  file="${ROOT}/${rel}"
  if [[ ! -f "$file" ]]; then
    echo "WARN: ${rel} не найден. Пропускаю."
    continue
  fi
  add_or_replace_bool "$file" "com.apple.security.device.bluetooth" "true"
  echo "OK: добавлен Bluetooth entitlement в ${rel}"
done

info="${ROOT}/${INFO_PLIST}"
if [[ ! -f "$info" ]]; then
  echo "WARN: ${INFO_PLIST} не найден. Добавь ключи вручную в Info.plist."
else
  add_or_replace_string "$info" "NSBluetoothAlwaysUsageDescription" "Sportoteka использует Bluetooth для поиска и подключения спортивных GPS-трекеров."
  add_or_replace_string "$info" "NSBluetoothPeripheralUsageDescription" "Sportoteka использует Bluetooth для подключения спортивных GPS-трекеров."
  echo "OK: добавлены Bluetooth usage descriptions в ${INFO_PLIST}"
fi

echo ""
echo "Готово. Теперь пересобери macOS release и новый DMG:"
echo "  flutter clean"
echo "  flutter pub get"
echo "  flutter build macos --release"
echo ""
echo "После установки нового DMG открой macOS: System Settings → Privacy & Security → Bluetooth и разреши Sportoteka, если появится в списке."
