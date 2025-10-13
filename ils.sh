#!/bin/bash

# remove ANSI color codes
strip_ansi_colors() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# Interactive file browser
function ils() {
  # 1. Check for dependencies
  if ! command -v fzf &>/dev/null; then
    echo "Error: fzf (Fuzzy Finder) is required for this function."
    return 1
  fi
  if ! command -v file &>/dev/null; then
    echo "Error: 'file' utility is required for smart previewing."
    return 1
  fi

  local selected_line
  local selected_path
  local action
  local current_dir_path="$PWD"

  while true; do
    current_dir_path="$PWD"

    # Generate the filtered list and pipe it to fzf
    selected_line=$(
      {
        # Always include '..' for moving up
        echo ".."

        # List all non-hidden files/directories (excluding .tmp)
        for entry in *; do
          if [[ -e "$entry" && "$entry" != *".tmp" ]]; then
            ls -d --color=always "$entry" 2>/dev/null
          fi
        done
      } | fzf --ansi \
        --prompt="📁 $current_dir_path > " \
        --header="ENTER=cd/open | ESC=exit | TAB=preview | CTRL-O=open file" \
        --height 90% \
        --layout=reverse \
        --border=rounded \
        --preview-window=right:50%:wrap \
        --bind 'tab:toggle-preview' \
        --bind 'ctrl-o:execute-silent(xdg-open {} &)+abort' \
        --bind 'ctrl-e:execute(${EDITOR:-vim} {})+abort' \
        --expect=ctrl-q \
        --preview='
          # Clean the path
          CLEAN_PATH=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | xargs)
          
          # Display current location info
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "📍 Current: '"$PWD"'"
          echo "🎯 Selected: $CLEAN_PATH"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo
          
          if [ "$CLEAN_PATH" = ".." ]; then
            echo "⬆️  Go up to parent directory"
            echo
            echo "--- Parent Directory Contents ---"
            ls -Fh --color=always ../ 2>/dev/null | head -n 20
          elif [ -d "$CLEAN_PATH" ]; then
            # Directory info
            ITEM_COUNT=$(ls -A "$CLEAN_PATH" 2>/dev/null | wc -l)
            DIR_SIZE=$(du -sh "$CLEAN_PATH" 2>/dev/null | cut -f1)
            echo "📂 Directory"
            echo "   Items: $ITEM_COUNT"
            echo "   Size: $DIR_SIZE"
            echo
            echo "--- Contents ---"
            ls -Fh --color=always "$CLEAN_PATH" 2>/dev/null | head -n 30
          else
            # File info
            MIME_TYPE=$(file -b --mime-type "$CLEAN_PATH")
            FILE_SIZE=$(du -h "$CLEAN_PATH" 2>/dev/null | cut -f1)
            PERMISSIONS=$(ls -lh "$CLEAN_PATH" | awk "{print \$1}")
            MODIFIED=$(stat -c %y "$CLEAN_PATH" 2>/dev/null | cut -d"." -f1)
            
            echo "📄 File Information"
            echo "   Type: $MIME_TYPE"
            echo "   Size: $FILE_SIZE"
            echo "   Permissions: $PERMISSIONS"
            echo "   Modified: $MODIFIED"
            echo
            
            case "$MIME_TYPE" in
              text/* | application/json | application/xml | application/javascript | inode/x-empty )
                echo "--- Content Preview ---"
                bat --color=always --style=numbers --line-range=:50 "$CLEAN_PATH" 2>/dev/null || \
                head -n 50 "$CLEAN_PATH" 2>/dev/null || \
                echo "File content not readable."
                ;;
              image/* )
                echo "🖼️  Image file (use CTRL-O to open)"
                identify "$CLEAN_PATH" 2>/dev/null || echo "Image info not available"
                ;;
              application/pdf )
                echo "📕 PDF document (use CTRL-O to open)"
                pdfinfo "$CLEAN_PATH" 2>/dev/null || echo "PDF info not available"
                ;;
              application/zip | application/x-tar | application/gzip )
                echo "📦 Archive file"
                echo
                echo "--- Contents ---"
                case "$CLEAN_PATH" in
                  *.zip) unzip -l "$CLEAN_PATH" 2>/dev/null | head -n 20 ;;
                  *.tar.gz|*.tgz) tar -tzf "$CLEAN_PATH" 2>/dev/null | head -n 20 ;;
                  *.tar) tar -tf "$CLEAN_PATH" 2>/dev/null | head -n 20 ;;
                esac
                ;;
              * )
                echo "⚠️  Binary or non-previewable file"
                echo
                file "$CLEAN_PATH" 2>/dev/null
                ;;
            esac
          fi
        '
    )

    # Parse the result
    action=$(echo "$selected_line" | head -n 1)
    selected_path=$(echo "$selected_line" | tail -n 1 | strip_ansi_colors | xargs)

    # Handle
    if [ -z "$selected_path" ] || [ "$action" = "ctrl-q" ]; then
      echo "Navigation complete. Current directory: $PWD"
      return 0
    fi

    # Handle directory navigation
    if [ -d "$selected_path" ]; then
      cd "$selected_path" || {
        echo "Error: Cannot access directory: $selected_path"
        sleep 1
        continue
      }
      # Loop continues in new directory
    else
      # File selected
      echo
      echo "Selected file: $selected_path"
      echo "Current directory: $PWD"
      return 0
    fi
  done
}

# Optional: Quick navigation to common directories
function ilsq() {
  local target
  target=$(echo -e "$HOME\n$HOME/Downloads\n$HOME/Documents\n$HOME/Desktop\n/tmp\n/var/log" |
    fzf --prompt="Quick Navigate > " --height=40% --border=rounded)

  if [ -n "$target" ] && [ -d "$target" ]; then
    cd "$target" && ils
  fi
}
