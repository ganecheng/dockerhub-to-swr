#!/usr/bin/env bash
# ============================================================
# audio.cpp Docker multiplexer (prebuilt Vulkan release)
#
# Dispatches to the correct binary based on the first
# argument. All remaining arguments are forwarded verbatim.
# ============================================================
set -e

arg1="$1"
shift || true

if [[ "$arg1" == "cli" ]]; then
    exec ./audiocpp_cli "$@"
elif [[ "$arg1" == "server" ]]; then
    exec ./audiocpp_server "$@"
elif [[ "$arg1" == "gguf" ]]; then
    exec ./audiocpp_gguf "$@"
else
    echo "Unknown command: $arg1"
    echo ""
    echo "Available commands:"
    echo "  cli     Run audio tasks (TTS, ASR, VAD, VC, diar, etc.)"
    echo "  server  Run the HTTP server"
    echo "  gguf    Convert / inspect GGUF model packages"
    exit 1
fi