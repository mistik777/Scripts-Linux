#!/usr/bin/env bash
set -euo pipefail

DEST_BASE="/media/luis/XXXXXXX/COPIA_FOTOS/ordenadas"  #Ruta absoluta donde van todas las carpetas por años

read -r -p "Ruta ORIGEN (recursivo): " SRC
[[ -d "$SRC" ]] || { echo "Ruta no válida"; exit 1; }

# Evitar que el destino esté dentro del origen (para no auto-incluirlo en la búsqueda)
if [[ "$(readlink -f "$DEST_BASE")" == "$(readlink -f "$SRC")"* ]]; then
  echo "El destino está dentro del origen. Elige otra carpeta origen." >&2
  exit 1
fi

# Extensiones a ordenar (añade/quita si quieres)
IMGVID_REGEX='.*\.\(jpg\|jpeg\|png\|heic\|heif\|gif\|bmp\|tif\|tiff\|dng\|arw\|nef\|cr2\|raf\|cr3\|pef\|srw\|orf\|rw2\|mp4\|mov\|3gp\|m4v\|mkv\|webm\|avi\)'

mover_archivo() {
  local src="$1"
  # Año por mtime
  local epoch year ts name ext dest_dir dest i
  epoch="$(stat -c %Y -- "$src" 2>/dev/null || stat -f %m -- "$src")"
  year="$(date -d "@$epoch" +%Y 2>/dev/null || echo 1979)"
  ts="$(date -d "@$epoch" +%Y%m%d-%H%M%S 2>/dev/null || echo 19790101-000000)"

  dest_dir="${DEST_BASE}/${year}"
  mkdir -p -- "$dest_dir"

  local base; base="$(basename -- "$src")"
  if [[ "$base" == *.* ]]; then
    name="${base%.*}"; ext=".${base##*.}"
  else
    name="$base"; ext=""
  fi
  dest="${dest_dir}/${base}"

  if [[ -e "$dest" ]]; then
    if cmp -s -- "$src" "$dest"; then
      # Duplicado idéntico: elimina el origen
      rm -- "$src"
      echo "DUP  $(realpath --relative-to="$SRC" "$src" 2>/dev/null || echo "$src")"
      return
    else
      # Contenido distinto: conflicto → renombrar con sufijo
      dest="${dest_dir}/${name}__CONFLICT-${ts}${ext}"
      i=1
      while [[ -e "$dest" ]]; do
        dest="${dest_dir}/${name}__CONFLICT-${ts}_$i${ext}"
        ((i++))
      done
      echo "CFL  ${base} -> $(basename -- "$dest")"
    fi
  fi

  mv -- "$src" "$dest"
  echo "OK   $(realpath --relative-to="$SRC" "$dest" 2>/dev/null || echo "$dest")"
}

export -f mover_archivo
export DEST_BASE SRC

# Busca y mueve (recursivo), ignorando JSON y basura de macOS
find "$SRC" \
  -type f \
  ! -name "*.json" \
  ! -name "._*" \
  -iregex "$IMGVID_REGEX" \
  -print0 | xargs -0 -I{} bash -c 'mover_archivo "$@"' _ {}

echo "Hecho."
