#!/usr/bin/env bash
set -Eeuo pipefail

read -rp "Ruta del Google Takeout (fotos + .json, recursivo): " SRC
[[ -d "$SRC" ]] || { echo "Ruta no válida"; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "Falta jq. Instala: sudo apt-get install -y jq"; exit 1; }

fixed=0; skipped=0; invalid=0

# Foto + vídeo conocidos (para emparejar por 'stem' si el JSON no trae la extensión)
EXTS="jpg jpeg png heic heif gif bmp tif tiff dng arw nef cr2 raf cr3
      mp4 mov 3gp avi m4v mkv webm mts m2ts"

normalize_ts() {
  local ts="$1"
  ts="${ts%\"}"; ts="${ts#\"}"
  # si viene con milisegundos o punto, quédate con 10 dígitos
  if [[ "$ts" =~ ^[0-9]{13,}$ ]]; then
    echo "${ts:0:10}"
  elif [[ "$ts" =~ ^[0-9]{10}$ ]]; then
    echo "$ts"
  else
    echo ""
  fi
}

find_local_one() { # dir pattern (iname)
  find "$1" -maxdepth 1 -type f ! -iname "*.json" -iname "$2" -print -quit 2>/dev/null || true
}
find_global_one() { # root pattern (iname)
  find "$1" -type f ! -iname "*.json" -iname "$2" -print -quit 2>/dev/null || true
}

# Recorre recursivamente todos los JSON (también *.supplemental-metadata.json)
find "$SRC" -type f -iname "*.json" -print0 | while IFS= read -r -d '' json; do
  # JSON vacío o inválido → saltar
  if [[ ! -s "$json" ]] || ! jq -e 'true' "$json" >/dev/null 2>&1; then
    echo "JSON inválido/vacío: $json"; ((invalid++)) || true; continue
  fi

  # Timestamp (varios campos posibles)
  raw_ts="$(jq -r '(.photoTakenTime.timestamp // .creationTime.timestamp // .takenTime.timestamp // .modificationTime.timestamp // .timestamp // empty)' "$json")"
  ts="$(normalize_ts "$raw_ts")"
  if [[ -z "$ts" ]]; then
    echo "Sin timestamp: $json"; ((skipped++)) || true; continue
  fi

  dir="$(dirname -- "$json")"
  title="$(jq -r '.title // .fileName // empty' "$json")"

  target=""

  # 1) Emparejar por 'title' en el MISMO directorio (exacto/CI)
  if [[ -n "$title" && "$title" != "null" ]]; then
    [[ -f "$dir/$title" ]] && target="$dir/$title"
    [[ -z "$target" ]] && target="$(find_local_one "$dir" "$title")"
    # Si no está, buscar en TODO el árbol
    [[ -z "$target" ]] && target="$(find_global_one "$SRC" "$title")"
  fi

  # 2) Emparejar por nombre del JSON (quitando sufijos) en local y global
  if [[ -z "$target" ]]; then
    base="$(basename -- "$json")"
    base="${base%.json}"
    base="${base%.supplemental-metadata}"
    [[ -f "$dir/$base" ]] && target="$dir/$base"
    [[ -z "$target" ]] && target="$(find_local_one "$dir" "$base")"
    [[ -z "$target" ]] && target="$(find_global_one "$SRC" "$base")"
    # 2b) Probar por 'stem' + extensiones conocidas
    if [[ -z "$target" ]]; then
      stem="${base%.*}"
      for e in $EXTS; do
        cand="$(find_local_one "$dir" "${stem}.${e}")"
        [[ -z "$cand" ]] && cand="$(find_global_one "$SRC" "${stem}.${e}")"
        if [[ -n "$cand" ]]; then target="$cand"; break; fi
      done
    fi
  fi

  if [[ -z "$target" ]]; then
    echo "No encuentro pareja para: $json"; ((skipped++)) || true; continue
  fi

  touch -d "@$ts" -- "$target"
  printf 'OK  %-50s  %s\n' "$(realpath --relative-to="$SRC" "$target")" "$(date -d "@$ts" '+%F %T')"
  ((fixed++)) || true
done

echo "-------------------------------------"
echo "Fechas ajustadas: $fixed | Sin tocar: $skipped | JSON inválidos: $invalid"
