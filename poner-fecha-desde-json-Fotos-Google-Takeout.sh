#!/usr/bin/env bash
set -Eeuo pipefail

read -rp "Ruta del Google Takeout (fotos + .json, recursivo): " SRC
[[ -d "$SRC" ]] || { echo "Ruta no válida"; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "Falta jq. Instala: sudo apt-get install -y jq"; exit 1; }

fixed=0; skipped=0; invalid=0

# Extensiones conocidas (para emparejar por stem si el JSON no trae la extensión)
EXTS=(jpg jpeg png heic heif gif bmp tif tiff dng arw nef cr2 raf cr3 mp4 mov 3gp avi m4v mkv webm mts m2ts)
# Hermanos a los que copiar la fecha si comparten el mismo stem
SIB_EXTS=(mp4 mov 3gp m4v)

normalize_ts() {
  local ts="$1"
  ts="${ts%\"}"; ts="${ts#\"}"
  if [[ "$ts" =~ ^[0-9]{13,}$ ]]; then
    echo "${ts:0:10}"
  elif [[ "$ts" =~ ^[0-9]{10}$ ]]; then
    echo "$ts"
  else
    echo ""
  fi
}

find_local_one() { # dir, pattern (iname)
  find "$1" -maxdepth 1 -type f ! -iname "*.json" -iname "$2" -print -quit 2>/dev/null || true
}
find_global_one() { # root, pattern (iname)
  find "$1" -type f ! -iname "*.json" -iname "$2" -print -quit 2>/dev/null || true
}

find "$SRC" -type f -iname "*.json" -print0 | while IFS= read -r -d '' json; do
  # JSON inválido/vacío
  if [[ ! -s "$json" ]] || ! jq -e 'true' "$json" >/dev/null 2>&1; then
    echo "JSON inválido/vacío: $json"; ((invalid++)) || true; continue
  fi

  # Timestamp
  raw_ts="$(jq -r '(.photoTakenTime.timestamp // .creationTime.timestamp // .takenTime.timestamp // .modificationTime.timestamp // .timestamp // empty)' "$json")"
  ts="$(normalize_ts "$raw_ts")"
  if [[ -z "$ts" ]]; then
    echo "Sin timestamp: $json"; ((skipped++)) || true; continue
  fi

  dir="$(dirname -- "$json")"
  title="$(jq -r '.title // .fileName // empty' "$json")"

  target=""

  # 1) Por 'title' (local → global)
  if [[ -n "$title" && "$title" != "null" ]]; then
    if [[ -f "$dir/$title" ]]; then
      target="$dir/$title"
    else
      cand="$(find_local_one "$dir" "$title")"
      [[ -z "$cand" ]] && cand="$(find_global_one "$SRC" "$title")"
      [[ -n "$cand" ]] && target="$cand"
    fi
  fi

  # 2) Por nombre del JSON (quitando sufijos) y por stem+ext
  if [[ -z "$target" ]]; then
    base="$(basename -- "$json")"
    base="${base%.json}"
    base="${base%.supplemental-metadata}"
    if [[ -f "$dir/$base" ]]; then
      target="$dir/$base"
    else
      cand="$(find_local_one "$dir" "$base")"
      [[ -z "$cand" ]] && cand="$(find_global_one "$SRC" "$base")"
      if [[ -z "$cand" ]]; then
        stem="${base%.*}"
        for e in "${EXTS[@]}"; do
          cand="$(find_local_one "$dir" "${stem}.${e}")"
          [[ -z "$cand" ]] && cand="$(find_global_one "$SRC" "${stem}.${e}")"
          if [[ -n "$cand" ]]; then target="$cand"; break; fi
        done
      else
        target="$cand"
      fi
    fi
  fi

  if [[ -z "$target" ]]; then
    echo "No encuentro pareja para: $json"; ((skipped++)) || true; continue
  fi

  touch -d "@$ts" -- "$target"
  rel_target="$(realpath --relative-to="$SRC" "$target" 2>/dev/null || echo "$target")"
  ts_fmt="$(date -d "@$ts" '+%F %T')"
  printf 'OK   %-60s  %s\n' "$rel_target" "$ts_fmt"
  ((fixed++)) || true

  # Copiar fecha a hermanos (mismo stem) si NO tienen su propio JSON
  stem_name="$(basename -- "$target")"; stem_name="${stem_name%.*}"
  for e in "${SIB_EXTS[@]}"; do
    sib="$(find "$dir" -maxdepth 1 -type f -iname "${stem_name}.${e}" -print -quit 2>/dev/null || true)"
    [[ -z "$sib" ]] && continue
    [[ "$sib" -ef "$target" ]] && continue
    sib_base="$(basename -- "$sib")"
    if [[ -f "$dir/$sib_base.json" || -f "$dir/$sib_base.supplemental-metadata.json" ]]; then
      continue
    fi
    touch -d "@$ts" -- "$sib"
    rel_sib="$(realpath --relative-to="$SRC" "$sib" 2>/dev/null || echo "$sib")"
    printf 'PAIR %-60s  %s\n' "$rel_sib" "$ts_fmt"
  done
done

echo "-------------------------------------"
echo "Fechas ajustadas: $fixed | Sin tocar: $skipped | JSON inválidos: $invalid"
