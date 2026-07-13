# Pin on Top - Finder Quick Action script (runs via Automator "Run Shell Script", zsh, input as arguments)
# Toggle: creates a " 📌 <name>" symlink NEXT TO the item so the shortcut sorts
# to the top of a Name-sorted Finder list; run again (on the original or the
# shortcut) to remove it. The original item is never renamed or modified.
# The prefix starts with a SPACE: whitespace collates before punctuation, so the
# shortcut also beats names like ".parts" or "[Anime]" that outrank a bare 📌.
PIN=" 📌 "
for f in "$@"; do
  f="${f%/}"
  [ -n "$f" ] || continue
  [ -e "$f" ] || [ -L "$f" ] || continue
  dir="${f:h}"    # zsh modifiers, not dirname/basename: those eat trailing
  base="${f:t}"   # newlines in names and choke on leading dashes
  case "$base" in
    " 📌"*|"📌"*)
      # invoked on a pin shortcut itself (current or legacy prefix) -> unpin;
      # only ever delete a symlink, never a real item
      [ -L "$f" ] && rm -- "$f"
      ;;
    *)
      link="$dir/$PIN$base"
      legacy="$dir/📌 $base"
      if [ -L "$link" ]; then
        rm -- "$link"                # toggle off
      elif [ -L "$legacy" ]; then
        rm -- "$legacy"              # toggle off an old-style shortcut
      elif [ -e "$link" ]; then
        continue                     # a real item already owns that name: leave it alone
      else
        ln -s -- "$base" "$link"     # relative link, keeps working if the parent moves
      fi
      ;;
  esac
done
