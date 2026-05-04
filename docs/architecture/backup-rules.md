# BACKUP SAFETY

Reglas obligatorias para cualquier backup operado por el agente en Viax:

1. Nunca crear un `.tar.gz` sin validar que el contenido comprimido sea real.
2. Nunca usar redirecciones con `>` dentro de `ssh` si el quoting no fue validado de punta a punta.
3. Siempre crear artefactos temporales con `mktemp`.
4. Siempre validar el archivo temporal con `gzip -t` y `file` antes de moverlo al destino final.
5. Siempre registrar el tamaño final con `du -h` o `ls -lh`.
6. Si la validación falla, borrar el temporal inválido y detener la operación antes de tocar backups existentes.

Patrón correcto:

```bash
TMP_FILE=$(mktemp)
tar -czf "$TMP_FILE" carpeta/
gzip -t "$TMP_FILE"
file "$TMP_FILE"
du -h "$TMP_FILE"
mv "$TMP_FILE" destino.tar.gz
```

Patrón prohibido:

```bash
tar -czf archivo.tar.gz carpeta/ > archivo.tar.gz
```