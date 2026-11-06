#!/bin/bash
# usage: dl.sh name id [name id ...]
cd /c/Users/vinic/source/estel-games/games/pegue-o-ursinho/godot/art_source/pixellab/ui/icons
while [ $# -gt 1 ]; do curl -sS -o "$1.png" "https://api.pixellab.ai/mcp/map-objects/$2/download"; echo "$1,$2" >> ../_raw/ids.csv; shift 2; done
