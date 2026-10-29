#!/usr/bin/env bash
# One user-facing switch for the private UCX + NIXL + NIXLBench stack.
set -Eeuo pipefail
WORKSPACE=${WORKSPACE:-/workspace/projects/nixl-ucx}
TCP_PROFILING=${TCP_PROFILING:-off}
case "$TCP_PROFILING" in
    on) enabled=1; meson_enabled=true ;;
    off) enabled=0; meson_enabled=false ;;
    *) echo 'TCP_PROFILING must be on or off' >&2; exit 2 ;;
esac
if [[ "${1:-incremental}" != incremental ]]; then
    echo 'Profiling wrapper currently supports incremental builds only' >&2
    exit 2
fi
ucx="$WORKSPACE/src/ucx"
prefix="$WORKSPACE/install/ucx"
stamp="$WORKSPACE/build/tcp-profile-mode"
JOBS=${JOBS:-8}
mkdir -p "$WORKSPACE/build"
if [[ ! -f "$stamp" ]] || [[ "$(cat "$stamp")" != "$TCP_PROFILING" ]]; then
    (
        cd "$ucx"
        # Only generated build outputs, never source or local edits.
        if [[ -f Makefile ]]; then make clean; fi
        ./autogen.sh
        CPPFLAGS="${CPPFLAGS:-} -DUCS_TCP_PROFILE_ENABLED=$enabled" \
            ./contrib/configure-release-mt --prefix="$prefix" \
                --enable-shared --disable-static --disable-doxygen-doc \
                --enable-optimizations --enable-cma --enable-devel-headers \
                --enable-mt --with-cuda="${CUDA_HOME:-/usr/local/cuda}" \
                --with-verbs --with-dm
    )
    printf '%s\n' "$TCP_PROFILING" > "$stamp"
fi
make -C "$ucx" -j"$JOBS"
make -C "$ucx" install
for component in nixl nixlbench; do
    source="$WORKSPACE/src/nixl"
    if [[ "$component" == nixlbench ]]; then source="$source/benchmark/nixlbench"; fi
    # Existing Meson build state predates the added developer option. Refresh
    # the option definitions before passing the new option on its command line.
    meson setup --reconfigure "$WORKSPACE/build/$component" "$source"
    meson setup --reconfigure "$WORKSPACE/build/$component" "$source" \
        -Dtcp_profile="$meson_enabled" -Ducx_path="$prefix"
done
export JOBS
/usr/local/bin/build-in-pod "${1:-incremental}"
printf 'TCP_PROFILING=%s\n' "$TCP_PROFILING" >> "$WORKSPACE/artifacts/manifest.txt"
