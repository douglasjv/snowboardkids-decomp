#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
python=python3
if command -v python3.12 >/dev/null 2>&1; then
    python=python3.12
fi

if [ ! -x "$root/.venv/bin/python" ]; then
    "$python" -m venv "$root/.venv"
fi
"$root/.venv/bin/python" -m pip install -r "$root/requirements.txt"

case "$(uname -s)" in
    Darwin) ido_platform=macos ;;
    *) ido_platform=linux ;;
esac

ido_dir="$root/tools/ido-recomp/$ido_platform"
if [ ! -x "$ido_dir/cc" ]; then
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    ido_archive="$temp_dir/ido.tar.gz"
    curl -L --fail --retry 3 \
        "https://github.com/decompals/ido-static-recomp/releases/download/v1.0/ido-5.3-recomp-${ido_platform}.tar.gz" \
        -o "$ido_archive"
    case "$ido_platform" in
        macos) ido_sha256=6f007f4d4734e9e2bb19f332454788f05700188fff90bdbdf640e006b4bb0a77 ;;
        linux) ido_sha256=87fc6e0e5ccf7154b48efdfe15462b1b7e1be561a2abdad36585fa88f8c91909 ;;
    esac
    echo "$ido_sha256  $ido_archive" | shasum -a 256 --check
    mkdir -p "$ido_dir"
    tar xf "$ido_archive" -C "$ido_dir"
fi

if [ "$(uname -s)" = Darwin ] && [ ! -x "$root/tools/binutils/bin/mips64-elf-ld" ]; then
    temp_dir=${temp_dir:-$(mktemp -d)}
    trap 'rm -rf "$temp_dir"' EXIT
    archive="$temp_dir/binutils-2.37.tar.xz"
    source_dir="$temp_dir/binutils-2.37"
    build_dir="$temp_dir/build"
    curl -L --fail --retry 3 \
        https://ftp.gnu.org/gnu/binutils/binutils-2.37.tar.xz \
        -o "$archive"
    echo "820d9724f020a3e69cb337893a0b63c2db161dadcb0e06fc11dc29eb1e84a32c  $archive" | shasum -a 256 --check
    mkdir -p "$source_dir" "$build_dir"
    tar xf "$archive" -C "$source_dir" --strip-components=1
    (
        cd "$build_dir"
        "$source_dir/configure" \
            --target=mips64-elf \
            --with-arch=vr4300 \
            --disable-debug \
            --disable-dependency-tracking \
            --disable-silent-rules \
            --disable-gold \
            --disable-multilib \
            --disable-nls \
            --disable-rpath \
            --disable-werror \
            --with-system-zlib \
            --prefix="$root/tools/binutils"
        make -j4
        make install
    )
fi

git -C "$root" submodule sync --recursive
git -C "$root" submodule update --init --recursive
echo "Local Snowboard Kids decompilation toolchain is ready."
