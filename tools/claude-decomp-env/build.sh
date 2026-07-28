#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <file.c> [opt_flag]"
    exit 1
fi

INPUT="$(realpath "$1")"
OPT_FLAG="${2:--O2}"
INPUT_DIR="$(cd "$(dirname "$1")" && pwd -P)"
INPUT_STEM="$(basename "${1%.c}")"
OBJECT_OUTPUT="$INPUT_DIR/$INPUT_STEM.o"
ANNOTATED_OUTPUT="$INPUT_DIR/${INPUT_STEM}_annotated.s"
OBJECT_DUMP="${1%.c}_object_dump.s"
WORKSPACE="$(pwd -P)"

LOCK_DIR=
if command -v flock >/dev/null 2>&1; then
    exec 9>"$WORKSPACE/.build.lock"
    flock 9
else
    LOCK_DIR="$WORKSPACE/.build.lock.d"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "ERROR: another matching build holds $LOCK_DIR"
        exit 1
    fi
fi

if grep -q "INCLUDE_ASM\|GLOBAL_ASM" "$INPUT"; then
    echo "ERROR: The C file contains an assembly include."
    echo "Write C code that compiles to matching assembly instead."
    exit 1
fi

SOURCE_SNAPSHOT="$(mktemp "$WORKSPACE/.build-source.XXXXXX.c")"
cleanup() {
    rm -f -- "$SOURCE_SNAPSHOT"
    if [ -n "${MATCH_BACKUP_TMP:-}" ]; then
        rm -f -- "$MATCH_BACKUP_TMP"
    fi
    if [ -n "$LOCK_DIR" ]; then
        rmdir "$LOCK_DIR"
    fi
}
trap cleanup EXIT
cp -- "$INPUT" "$SOURCE_SNAPSHOT"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_PATH/../.." && pwd)"

LOCAL_CROSS="$PROJECT_ROOT/tools/binutils/bin/mips64-elf-"
if [ -x "${LOCAL_CROSS}as" ]; then
    CROSS="$LOCAL_CROSS"
else
    CROSS="mips-linux-gnu-"
fi
if ! command -v "${CROSS}as" >/dev/null 2>&1 && [ ! -x "${CROSS}as" ]; then
    CROSS="mips64-linux-gnu-"
fi
if ! command -v "${CROSS}as" >/dev/null 2>&1 && [ ! -x "${CROSS}as" ]; then
    CROSS="mips64-elf-"
fi

AS="${CROSS}as"
OBJDUMP="${CROSS}objdump"
OBJCOPY="${CROSS}objcopy"
NM="${CROSS}nm"
case "$(uname -s)" in
    Darwin) IDO_PLATFORM=macos ;;
    *) IDO_PLATFORM=linux ;;
esac
CC="$PROJECT_ROOT/tools/ido-recomp/$IDO_PLATFORM/cc"
ASM_PROC="$PROJECT_ROOT/tools/asm-processor/build.py"

ASFLAGS=(-G 0 -I "$PROJECT_ROOT/include" -mips3 -mabi=32)
C_DEFINES=(-DLANGUAGE_C -D_LANGUAGE_C -D_MIPS_SZLONG=32 -DNDEBUG \
    -DCOMPILING_LIBULTRA -DBUILD_VERSION=VERSION_I -DF3DEX_GBI)
CFLAGS=(-c "$OPT_FLAG" -mips1 -G 0 -non_shared -fullwarn -Xcpluscomm \
    -nostdinc -Wab,-r4300_mul -woff 649,838,712,516 \
    -I"$PROJECT_ROOT" -I"$PROJECT_ROOT/include" -I"$PROJECT_ROOT/include/PR" \
    -I"$PROJECT_ROOT/src/ultra/audio" -I"$PROJECT_ROOT/src/ultra/libc" \
    "${C_DEFINES[@]}")

pushd "$PROJECT_ROOT" >/dev/null

python3 "$ASM_PROC" "$CC" -- "$AS" "${ASFLAGS[@]}" -- "${CFLAGS[@]}" -o "$OBJECT_OUTPUT" "$SOURCE_SNAPSHOT"
"$OBJCOPY" --remove-section .mdebug "$OBJECT_OUTPUT"

{
    "$OBJDUMP" -drz --line-numbers --source "$OBJECT_OUTPUT" > "$ANNOTATED_OUTPUT"
} 2>/dev/null || true

popd >/dev/null

if ! "$NM" "$OBJECT_OUTPUT" 2>/dev/null | grep -q ' T '; then
    echo "ERROR: Compiled object has no text symbols. Check for type conflicts or include issues."
    "$NM" "$OBJECT_OUTPUT" 2>/dev/null || true
    exit 1
fi

python3 ./objdump.py target.o > target_object_dump.s
python3 ./objdump.py "$OBJECT_OUTPUT" > "$OBJECT_DUMP"
echo "Raw decompiled assembly of $1: $OBJECT_DUMP"
echo "Decompiled assembly of $1 with C annotations: $ANNOTATED_OUTPUT"

python3 ./normalize_asm.py target_object_dump.s > target_object_dump_normalized.s
python3 ./normalize_asm.py "$OBJECT_DUMP" > "${1%.c}_object_dump_normalized.s"
diff -u --suppress-common-lines target_object_dump_normalized.s "${1%.c}_object_dump_normalized.s" > "${1%.c}_diff" || true
echo "Comparison with target file: ${1%.c}_diff"

SCORE_OUTPUT=$(python3 dist.py target.o "$OBJECT_OUTPUT" --stack-diffs)
echo "$SCORE_OUTPUT"

MATCH_PERCENT=$(echo "$SCORE_OUTPUT" | sed -n 's/^Score: \([0-9.]*\)%.*/\1/p')
DIFFERENCE_COUNT=$(echo "$SCORE_OUTPUT" | sed -n 's/^Score: .* (\([0-9][0-9]*\) differences).*/\1/p')
SCORER_EXACT=$(echo "$SCORE_OUTPUT" | sed -n 's/^Exact match: \(yes\|no\)$/\1/p')
NORMALIZED_EXACT=no
if cmp -s target_object_dump_normalized.s "${1%.c}_object_dump_normalized.s"; then
    NORMALIZED_EXACT=yes
fi

TRUE_MATCH=no
if [ "$SCORER_EXACT" = yes ] && [ "$DIFFERENCE_COUNT" = 0 ] && [ "$NORMALIZED_EXACT" = yes ]; then
    TRUE_MATCH=yes
fi

echo "Verified exact match: $TRUE_MATCH"

if [ "$TRUE_MATCH" = yes ]; then
    SOURCE_HASH=$(shasum -a 256 "$SOURCE_SNAPSHOT" | awk '{print $1}')
    SOURCE_STEM="$(basename "${INPUT%.c}")"
    MATCH_DIR="$WORKSPACE/.matches"
    MATCH_BACKUP="$MATCH_DIR/${SOURCE_STEM}-${SOURCE_HASH}.c"
    MATCH_BACKUP_REL=".matches/${SOURCE_STEM}-${SOURCE_HASH}.c"

    mkdir -p "$MATCH_DIR"
    if [ -e "$MATCH_BACKUP" ]; then
        if ! cmp -s "$SOURCE_SNAPSHOT" "$MATCH_BACKUP"; then
            echo "ERROR: Exact-match archive hash collision at $MATCH_BACKUP"
            exit 1
        fi
    else
        MATCH_BACKUP_TMP="$(mktemp "$MATCH_DIR/.archive.XXXXXX")"
        cp -- "$SOURCE_SNAPSHOT" "$MATCH_BACKUP_TMP"
        mv -- "$MATCH_BACKUP_TMP" "$MATCH_BACKUP"
        MATCH_BACKUP_TMP=""
    fi

    echo "Exact-match source archived: $MATCH_BACKUP_REL"
fi

if [[ $1 =~ base_[0-9]+ ]] && [ -n "$MATCH_PERCENT" ]; then
    if [ "$TRUE_MATCH" = yes ]; then
        echo "$MATCH_BACKUP_REL 100.000% exact sha256=$SOURCE_HASH source=$(basename "$INPUT")" >> match_log.txt
    else
        echo "$1 ${MATCH_PERCENT}%" >> match_log.txt
    fi

    STALL_INFO=$(awk '
    {
        gsub(/%/, "", $2)
        total++
        if ($2 + 0 > best + 0) {
            best = $2 + 0
            best_file = $1
            best_at = total
        }
    }
    END {
        since = total - best_at
        if (since >= 20) {
            printf "%d %s %.1f\n", since, best_file, best
        }
    }' match_log.txt)

    if [ -n "$STALL_INFO" ]; then
        read -r SINCE BEST_FILE BEST_SCORE <<< "$STALL_INFO"
        echo "No progress in $SINCE attempts (best: ${BEST_SCORE}% at $BEST_FILE). STOP and report your findings."
    fi
fi
