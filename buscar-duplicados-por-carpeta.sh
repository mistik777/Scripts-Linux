#!/bin/bash

# Solicitar el año de la carpeta donde buscar duplicados. Se entiende que tienes las fotos separadas por años en carpetas.
read -p "Introduce el año (por ej 2023): " year

# Verificar que el año no esté vacío (año equivale a carpeta)
if [[ -z "$year" ]]; then
    echo "Error: Debes introducir un año válido."
    exit 1
fi

# Buscar duplicados y guarda el resultado en un txt con el año
rdfind -outputname duplicados-$year.txt /mnt/server/Fotos/$year

# Archivo de resultados de rdfind
DUPLICATES_FILE="duplicados-$year.txt"
DEST_DIR="/mnt/server/Fotos/zz-duplicados/$year/"

# Verificar que el archivo de duplicados existe
if [[ ! -f "$DUPLICATES_FILE" ]]; then
    echo "Error: No se encontró el archivo $DUPLICATES_FILE"
    exit 1
fi

# Crear el directorio de destino si no existe
mkdir -p "$DEST_DIR"

# Contador de ficheros
total_found=0
total_moved=0

# Leer y mover archivos duplicados del txt que ha generado rdfind
grep "DUPTYPE_WITHIN_SAME_TREE" "$DUPLICATES_FILE" | while IFS= read -r line; do
    # Extraer la ruta completa del archivo manteniendo los espacios y eliminando números antes de la ruta
    file=$(echo "$line" | sed -e 's/^.*[0-9]\{1,\} //')

    # Verificar si el archivo existe
    if [[ -f "$file" ]]; then
        total_found = $((total_found + 1))
        echo "Moviendo: \"$file\" -> \"$DEST_DIR\""
        mv "$file" "$DEST_DIR"
        total_moved = $((total_moved + 1))
    else
        echo "Advertencia: Archivo no encontrado: \"$file\""
    fi
done

# Resumen

echo "$total_found ficheros duplicados"
echo "$total_moved ficheros movidos"

echo "Proceso completado."
