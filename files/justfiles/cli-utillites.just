# Justfile para instalar solo herramientas CLI con Homebrew

cli-bogdan-dev:
    #!/usr/bin/env bash

    # Lista de fórmulas CLI a instalar
    FORMULAS=(
    tmux
    fzf
    ripgrep
    )

    echo "Instalando herramientas CLI..."
    for formula in "${FORMULAS[@]}"; do
    echo "→ Instalando $formula"
    brew install "$formula"
    done

    echo "Todo listo para ser un terminal wizard."
