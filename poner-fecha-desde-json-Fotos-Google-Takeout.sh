#!/usr/bin/env bash
set -Eeuo pipefail

read -rp "Ruta del Google Takeout (fotos + .json): " SRC
[[ -d "$SRC" ]] || { echo "Ruta no válida"; exit 1; }

# Requiere jq
command -v jq >/dev/null 2>&1 || { echo "Falta jq. Instala: sudo apt-get install -y jq"; exit 1; }

fixed=0; skipped=0; invalid=0

normalize_ts() {
  local ts="$1"
  ts="${ts%\"}"; ts="${ts#\"}"             # por si viene entre comillas
  [[ "$ts" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  # Si tiene 13+ dígitos (milisegundos), usa los 10 primeros (segundos)
  if [[ ${#ts} -ge 13 ]]; then
    echo "${ts:0:10}"
  else
    echo "$ts"
  fi
}

# Recorre todos los .json (también los *.supplemental-metadata.json)
find "$SRC" -type f -iname "*.json" -print0 | while IFS= read -r -d '' json; do
  # Saltar JSON vacíos/no válidos
  if [[ ! -s "$json" ]] || ! jq -e 'true' "$json" >/dev/null 2>&1; then
    echo "JSON inválido o vacío: $json"
    ((invalid++)) || true
    continue
  fi

  raw_ts="$(jq -r '(.photoTakenTime.timestamp // .creationTime.timestamp // .takenTime.timestamp // .modificationTime.timestamp // .timestamp // empty)' "$json")"
  ts="$(normalize_ts "$raw_ts")"
  if [[ -z "$ts" ]]; then
    echo "Sin timestamp: $json"
    ((skipped++)) || true
    continue
  fi

  dir="$(dirname -- "$json")"
  title="$(jq -r '.title // .fileName // empty' "$json")"

  target=""
  # 1) Emparejar por 'title'
  if [[ -n "$title" && "$title" != "null" ]]; then
    if [[ -f "$dir/$title" ]]; then
      target="$dir/$title"
    else
      cand="$(find "$dir" -maxdepth 1 -type f -iname "$title" -print -quit 2>/dev/null || true)"
      [[ -n "$cand" ]] && target="$cand"
    fi
  fi
  # 2) Emparejar por nombre del json
  if [[ -z "$target" ]]; then
    base="$(basename -- "$json")"
    base="${base%.json}"
    base="${base%.supplemental-metadata}"
    if [[ -f "$dir/$base" ]]; then
      target="$dir/$base"
    else
      cand="$(find "$dir" -maxdepth 1 -type f -iname "$base" -print -quit 2>/dev/null || true)"
      [[ -n "$cand" ]] && target="$cand"
    fi
  fi

  if [[ -z "$target" ]]; then
    echo "No encuentro el fichero para: $json"
    ((skipped++)) || true
    continue
  fi

  touch -d "@$ts" -- "$target"
  printf 'OK  %-40s  %s\n' "$(basename -- "$target")" "$(date -d "@$ts" '+%F %T')"
  ((fixed++)) || true
done

echo "-------------------------------------"
echo "Fechas ajustadas: $fixed | Sin tocar: $skipped | JSON inválidos: $invalid"
