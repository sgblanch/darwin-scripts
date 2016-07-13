#!/bin/bash

set -eu
IFS=$'\n'

declare TMPDIR=$(mktemp -d)
declare OUTDIR

declare RED="\e[1;91m"
declare GREEN="\e[1;92m"
declare BLUE="\e[1;34m"
declare RESET="\e[0m"

warn() {
    printf "${RED}"
    printf "$@" 1>&2
    printf "${RESET}"
}

usage() {
    printf "usage: %s -o OUTDIR FILE ...\n\n" "$0"
    printf "$@"
    exit
}

cleanup() {
    [[ -z "${TMPDIR:-}" ]] && exit

    for mountpoint in $(mount | awk ' $1 != "map" { print $3 }' | grep "${TMPDIR}"); do
        hdiutil detach "${mountpoint}"
    done

    rm -r "${TMPDIR}" 2>/dev/null
}

parse_json() {
    python -c "import json,sys;print(json.load(sys.stdin)$1)"
}

package_app() {
    local app="${1}"

    local name=$(basename "${app}" ".app" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z]//g' )
    local iden=$(plutil -convert json -r -o - -- "${app}/Contents/Info.plist" | parse_json "['CFBundleIdentifier']")
    local vers=$(plutil -convert json -r -o - -- "${app}/Contents/Info.plist" | parse_json "['CFBundleShortVersionString']")

    printf "${BLUE}packaging '%s'\n${RESET}" $(basename "${app}")

    pkgbuild                                   \
            --install-location "/Applications" \
            --identifier "${iden}"             \
            --version "${vers}"                \
            --component "${app}"               \
            "${TMPDIR}/${name}-${vers}.pkg"

    productbuild                                      \
            --synthesize                              \
            --package "${TMPDIR}/${name}-${vers}.pkg" \
            "${TMPDIR}/${name}-${vers}.xml"

    productbuild                                           \
            --distribution "${TMPDIR}/${name}-${vers}.xml" \
            --package-path "${TMPDIR}"                     \
            "${OUTDIR}/${name}-${vers}.pkg"

    rm "${TMPDIR}/${name}-${vers}.pkg" "${TMPDIR}/${name}-${vers}.xml"
}

mount_dmg() {
    local dmg="${1}"
    local mountpoint

    mountpoint=$(hdiutil attach "${dmg}" -nobrowse -mountrandom "${TMPDIR}" <<< Y | awk -F '\t' '{print $3}' | grep -v '^$')

    printf "%s" "${mountpoint}"
}

umount_dmg() {
    local mountpoint="${1}"

    hdiutil detach "${mountpoint}" -quiet
}

handle_dmg() {
    local dmg="${1}"
    local mountpoint=$(mount_dmg "${dmg}")

    while read -rd '' app; do
        package_app "${app}"
    done < <(find "${mountpoint}" -depth 1 -name '.*' -prune -o -depth 1 -name '*.app' -print0)

    umount_dmg "${mountpoint}"
}

handle_zip() {
    local file="${1}"
    local tmpdir=$(mktemp -d)

    unzip -q "${file}" -d "${tmpdir}"

    while read -rd '' app; do
        package_app "${app}"
    done < <(find "${tmpdir}" -maxdepth 2 -name '.*' -prune -o -maxdepth 2 -name '*.app' -print0)

    rm -r "${tmpdir}"
}

main() {
    trap cleanup 1 2 3 6 ERR

    while getopts "o:" opt; do
        case "${opt}" in
            o)
                OUTDIR="${OPTARG}"
                ;;
            *)
                usage
                ;;
        esac
    done

    if [[ -z "${OUTDIR:-}" ]]; then
        usage "no output directory specified\n"
    fi

    if [[ ! -d "${OUTDIR}" ]]; then
        usage "'%s' is not a directory\n" "$OUTDIR"
    fi

    shift $((${OPTIND}-1))
    if [[ ${#@} -lt 1 ]]; then
        usage "no input files specified\n"
    fi

    for file in "$@"; do
        case "${file}" in
            *.dmg)
                printf "${GREEN}mounting '%s'\n${RESET}" "${file}"
                handle_dmg "${file}"
                ;;
            *.zip)
                printf "${GREEN}exploding '%s'\n${RESET}" "${file}"
                handle_zip "${file}"
                ;;
            *)
                warn "unhandled file: '%s'\n" "${file}"
                ;;
        esac
    done

    rm -r "${TMPDIR}"
}

main "$@"
