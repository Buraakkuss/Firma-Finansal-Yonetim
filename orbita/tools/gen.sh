#!/usr/bin/env bash
# Tum magaza gorsellerini yeniden uretir.  Kullanim:  bash tools/gen.sh
set -e
CHROME="${CHROME:-/opt/pw-browsers/chromium-1194/chrome-linux/chrome}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets"
FLAGS="--headless=new --no-sandbox --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --virtual-time-budget=4000"

# Headless pencere yuksekligi ile gercek viewport arasindaki farki olc (chrome surumune gore degisir)
PROBE="$(mktemp /tmp/vpXXXX.html)"
cat > "$PROBE" <<'PEOF'
<!doctype html><meta charset="utf-8"><title>x</title>
<script>document.title='VP:'+window.innerWidth+'x'+window.innerHeight;</script>
PEOF
DELTA=$("$CHROME" $FLAGS --window-size=600,800 --dump-dom "file://$PROBE" 2>/dev/null \
        | grep -o 'VP:[0-9]*x[0-9]*' | head -1 | sed 's/.*x//' | awk '{print 800-$1}')
rm -f "$PROBE"
[ -z "$DELTA" ] && DELTA=0
echo "viewport farki: ${DELTA}px"

TMPSHOT="$(mktemp /tmp/shotXXXX.png)"
shot(){ # $1=out  $2=W  $3=H  $4=url  $5=extra
  "$CHROME" $FLAGS $5 --window-size="$2,$(( $3 + DELTA ))" --screenshot="$TMPSHOT" "$4" >/dev/null 2>&1
  node "$ROOT/tools/pngcrop.js" "$TMPSHOT" "$1" "$2" "$3"
}

rm -rf "$OUT/android"
mkdir -p "$OUT/screenshots" "$OUT/android"

# --- ikonlar ---
shot "$OUT/icon-1024.png" 1024 1024 "file://$ROOT/tools/icon.html?s=1024"
shot "$OUT/icon-512.png"   512  512 "file://$ROOT/tools/icon.html?s=512"
shot "$OUT/feature-graphic-1024x500.png" 1024 500 "file://$ROOT/tools/icon.html?w=1024&h=500&wide=1"
# Android res agaci (dogrudan android/app/src/main/res icine kopyalanabilir)
set -- "mdpi 48 108" "hdpi 72 162" "xhdpi 96 216" "xxhdpi 144 324" "xxxhdpi 192 432"
for ENTRY in "$@"; do
  D=$(echo $ENTRY | cut -d' ' -f1); L=$(echo $ENTRY | cut -d' ' -f2); F=$(echo $ENTRY | cut -d' ' -f3)
  mkdir -p "$OUT/android/res/mipmap-$D"
  shot "$OUT/android/res/mipmap-$D/ic_launcher.png" $L $L "file://$ROOT/tools/icon.html?s=$L"
  shot "$OUT/android/res/mipmap-$D/ic_launcher_round.png" $L $L \
       "file://$ROOT/tools/icon.html?s=$L&round=1" "--default-background-color=00000000"
  shot "$OUT/android/res/mipmap-$D/ic_launcher_foreground.png" $F $F \
       "file://$ROOT/tools/icon.html?s=$F&bg=0&scale=0.62" "--default-background-color=00000000"
done

mkdir -p "$OUT/android/res/mipmap-anydpi-v26" "$OUT/android/res/values"
cat > "$OUT/android/res/mipmap-anydpi-v26/ic_launcher.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XEOF
cp "$OUT/android/res/mipmap-anydpi-v26/ic_launcher.xml" "$OUT/android/res/mipmap-anydpi-v26/ic_launcher_round.xml"
cat > "$OUT/android/res/values/ic_launcher_background.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0D1330</color>
</resources>
XEOF

# --- acilis ekrani (splash) ---
shot "$OUT/splash-2732.png" 2732 2732 "file://$ROOT/tools/icon.html?s=2732&scale=0.34"

# --- magaza ekran goruntuleri ---
G="file://$ROOT/www/index.html?shot=1"
declare -a SH=(
 "play=90&score=8&headline=ONE%20TAP%20TO%20JUMP%20ORBIT&sub=that%20is%20the%20entire%20game"
 "play=260&score=17&perfect=1&headline=NAIL%20THE%20PERFECT%20JUMP&sub=perfect%20landing%20%3D%20double%20points"
 "play=420&score=24&headline=DODGE%20THE%20RED%20ARCS&sub=they%20spin%20faster%20every%20planet"
 "play=560&score=31&headline=IT%20NEVER%20STOPS%20SPEEDING%20UP&sub=how%20far%20can%20you%20get"
 "menu=1&diff=hard&best=41&headline=FREE%20AND%20FULLY%20OFFLINE&sub=no%20account%20%C2%B7%20no%20sign-up"
)
i=1
for Q in "${SH[@]}"; do
  shot "$OUT/screenshots/android-$i-1080x1920.png" 1080 1920 "$G&$Q"
  shot "$OUT/screenshots/ios67-$i-1290x2796.png"   1290 2796 "$G&$Q"
  i=$((i+1))
done
rm -f "$TMPSHOT"
echo "Uretildi:"; find "$OUT" -name "*.png" | wc -l
