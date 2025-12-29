 #!/usr/bin/env bash
 set -euo pipefail

 # Script para mover random-wallpaper.sh a su ubicación final y darle permisos de ejecución

 mkdir -p /usr/local/bin
 cp /usr/bin/random-wallpaper.sh /usr/local/bin/random-wallpaper.sh
 chmod +x /usr/local/bin/random-wallpaper.sh
 rm /usr/bin/random-wallpaper.sh # Eliminar la copia temporal
