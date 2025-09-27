#!/usr/bin/env bash
set -Eeuo pipefail

# Requiere jdupes
command -v jdupes >/dev/null 2>&1 || { echo "Falta jdupes. Instala: sudo apt-get install -y jdupes"; exit 1; }

read -r -p "Ruta a CONSERVAR (primera): " KEEP
read -r -p "Ruta a LIMPIAR (segunda): " OTHER

[[ -d "$KEEP"  ]] || { echo "No existe: $KEEP";  exit 1; }
[[ -d "$OTHER" ]] || { echo "No existe: $OTHER"; exit 1; }
[[ "$KEEP" != "$OTHER" ]] || { echo "Las rutas no pueden ser iguales."; exit 1; }

echo "Conservaré los archivos en: $KEEP"
echo "Borraré duplicados idénticos de: $OTHER (cuando existan también en $KEEP)"
read -r -p "¿Continuar? Escribe SI para confirmar: " OK
[[ "$OK" == "SI" ]] || { echo "Cancelado."; exit 0; }

# Importante: KEEP primero para que jdupes conserve esos archivos
jdupes -r -d -N "$KEEP" "$OTHER"
