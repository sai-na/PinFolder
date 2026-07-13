# 📌 Pin to Sidebar - Finder Quick Action script (runs via Automator "Run Shell Script", zsh, input as arguments)
# Toggles each selected item in the Finder sidebar Favourites via the
# pinsidebar helper (LSSharedFileList API) bundled inside PinFolder.app.
BIN="/Applications/PinFolder.app/Contents/MacOS/pinsidebar"
[ -x "$BIN" ] || exit 0
for f in "$@"; do
  f="${f%/}"
  [ -n "$f" ] || continue
  "$BIN" toggle "$f"
done
