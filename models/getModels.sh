#!/usr/bin/env bash
# Download OpenPose network weights from the locations listed in model_sources.txt.
#
#   models/getModels.sh                 # body25 + face + hand (the defaults)
#   models/getModels.sh --all           # every model
#   models/getModels.sh coco mpi        # just these
#   models/getModels.sh --sources FILE  # use another sources list
#
# This script never uploads anything and the repository does not host weights.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
SOURCES="model_sources.txt"

declare -A DEST=(
    [body25]="pose/body_25/pose_iter_584000.caffemodel"
    [coco]="pose/coco/pose_iter_440000.caffemodel"
    [mpi]="pose/mpi/pose_iter_160000.caffemodel"
    [face]="face/pose_iter_116000.caffemodel"
    [hand]="hand/pose_iter_102000.caffemodel"
)
ALL=(body25 coco mpi face hand)
DEFAULT=(body25 face hand)

selected=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) selected=("${ALL[@]}") ;;
        --sources) SOURCES="${2:?--sources needs a file}"; shift ;;
        -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        body25|coco|mpi|face|hand) selected+=("$1") ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
[[ ${#selected[@]} -eq 0 ]] && selected=("${DEFAULT[@]}")
[[ -f "$SOURCES" ]] || { echo "Sources file not found: $SOURCES" >&2; exit 2; }

if command -v curl >/dev/null; then
    fetch() { curl -fL --retry 3 --connect-timeout 20 -C - -o "$2" "$1"; }
elif command -v wget >/dev/null; then
    fetch() { wget -c -O "$2" "$1"; }
else
    echo "Need curl or wget." >&2; exit 1
fi

sha_of() { sha256sum "$1" | cut -d' ' -f1; }

download_model() {
    local name="$1" dest="${DEST[$1]}" part
    part="${dest}.part"
    mkdir -p "$(dirname "$dest")"

    # Candidate mirrors for this model: "<sha> <url>" per line, in file order.
    mapfile -t candidates < <(awk -v n="$name" '!/^[[:space:]]*(#|$)/ && $1==n {print $2" "$3}' "$SOURCES")
    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "[$name] no source listed in $SOURCES" >&2; return 1
    fi

    # Already present and matching a known checksum? Nothing to do.
    if [[ -s "$dest" ]]; then
        local have; have="$(sha_of "$dest")"
        for c in "${candidates[@]}"; do
            [[ "${c%% *}" != "-" && "${c%% *}" == "$have" ]] && { echo "[$name] already present and verified: $dest"; return 0; }
        done
        echo "[$name] $dest exists but is not verified; keeping it (delete it to re-download)."
        return 0
    fi

    for c in "${candidates[@]}"; do
        local sha="${c%% *}" url="${c#* }"
        echo "[$name] trying $url"
        if fetch "$url" "$part"; then
            if [[ "$sha" != "-" ]]; then
                if [[ "$(sha_of "$part")" != "$sha" ]]; then
                    echo "[$name] CHECKSUM MISMATCH from $url, discarding." >&2
                    rm -f "$part"; continue
                fi
                echo "[$name] checksum OK"
            else
                echo "[$name] WARNING: no checksum on record for this source; file is unverified."
            fi
            mv "$part" "$dest"
            echo "[$name] saved to models/$dest"
            return 0
        fi
        rm -f "$part"
        echo "[$name] failed, trying next source." >&2
    done
    echo "[$name] ALL SOURCES FAILED. Add a working mirror to $SOURCES." >&2
    return 1
}

fail=0
for m in "${selected[@]}"; do download_model "$m" || fail=1; done
exit $fail
