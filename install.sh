#!/bin/bash


set -euo pipefail


fail()
{
	echo "ERROR: ${1:-Something wrong happened}"
	exit 1
}


trap fail ERR

SCRIPT_ROOT_PATH="$(dirname "$(realpath "$0")")"
VENV_DIR="$SCRIPT_ROOT_PATH/.venv"
VENV_ACTIVATE="$VENV_DIR/bin/activate"

echo "SCRIPT_ROOT_PATH: $SCRIPT_ROOT_PATH"
echo "VENV_DIR: $VENV_DIR"

if command -v uv >/dev/null; then
	uv self update
else
	curl -LsSf https://astral.sh/uv/install.sh | sh
fi

if command -v ruff >/dev/null; then
	uv tool upgrade ruff
else
	uv tool install ruff
fi

if [ -d "$VENV_DIR" ]; then
	rm -rf "$VENV_DIR"
fi

uv venv --directory "$SCRIPT_ROOT_PATH"
uv pip install -r "$SCRIPT_ROOT_PATH/requirements.txt"
# shellcheck disable=SC1090
. "$VENV_ACTIVATE"

(export bin_path=$HOME/.local/bin && curl -sfL https://direnv.net/install.sh | bash)
direnv allow "$SCRIPT_ROOT_PATH"

