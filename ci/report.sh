#!/usr/bin/env bash
# Remonte les erreurs des logs sous forme d'annotations GitHub (lisibles sans télécharger les logs).
# Usage : ci/report.sh <niveau error|warning> <fichier> [titre]
level="$1"; file="$2"; title="${3:-$2}"
[ -f "$file" ] || exit 0
lines=$(grep -nE -A6 "What went wrong|error|Error:|e: |FAILED|Exception|Could not|Unresolved|requires|warning •|error •|info •" "$file" | head -80)
[ -z "$lines" ] && lines=$(tail -40 "$file")
msg=$(printf '%s' "$lines" | sed 's/%/%25/g' | awk 'BEGIN{ORS="%0A"} {print}')
echo "::${level} title=${title}::${msg}"
