# 📌 Pin - Finder Quick Action script (runs via Automator "Run Shell Script", zsh, input as arguments)
# Appends each selected item's path to ~/.pinned-folders (the PinFolder
# menu-bar app database), skipping paths already present.
p="$HOME/.pinned-folders"
p=${p:A}   # follow a symlinked pins file
# heal a file whose last line lacks a newline so the append can't glue onto it
[ -s "$p" ] && [ -n "$(tail -c1 "$p")" ] && printf '\n' >> "$p"
for f in "$@"; do
  f="${f%/}"
  [ -n "$f" ] || continue
  case "$f" in *$'\n'*) continue ;; esac   # the line-based DB cannot represent these
  # printf, not echo: zsh's echo mangles backslashes in names
  grep -qxF -- "$f" "$p" 2>/dev/null || printf '%s\n' "$f" >> "$p"
done
