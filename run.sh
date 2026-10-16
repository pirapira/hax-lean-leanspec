#!/usr/bin/env bash
# Reproduce everything. Needs: git, elan/lake, python3.12, uv. Usage: bash run.sh [workdir]
set -euxo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(realpath -m "${1:-work}"); mkdir -p "$W"; cd "$W"
[ -d hax-lean ] || git clone https://github.com/spitters/hax-lean
[ -d leanSpec ] || git clone https://github.com/leanEthereum/leanSpec
git -C hax-lean checkout -q c9e9d5c9e8a1e504df978fe2f80c046a66641031
git -C leanSpec checkout -q 0b7d33ecbc9ee2435759c92de4da4d08d7faf1c8
# The generated file imports these modules; `lake build haxpipeT` alone does not build their
# .olean files, and a restore from the shared Lake artifact cache can skip them, hence the env var.
(cd hax-lean && LAKE_ARTIFACT_CACHE=false lake build haxpipeT HaxLean.Runtime HaxLean.AST HaxLean.TExpr HaxLean.Semantics HaxLean.Secrecy)
X=$W/hax-lean/.lake/build/bin/haxpipeT   # called directly: `lake exe` prints build warnings first
mkdir -p out

# 1. Unmodified leanSpec files: py2json works, haxpipeT refuses at the first import.
for f in crypto/koalabear.py crypto/poseidon.py crypto/xmss/prf.py; do
  b=$(basename $f .py)
  python3.12 -I hax-lean/python/py2json.py leanSpec/src/lean_spec/spec/$f -o out/$b.json
  "$X" --python out/$b.json --name X -o out/$b.lean || true
done

# 2. Hand port of the width-16 Poseidon permutation.
(cd leanSpec && uv sync -q)
(cd leanSpec && PYTHONPATH="$HERE:$W/hax-lean/python" uv run python "$HERE/check_port.py")
python3.12 -I hax-lean/python/py2json.py "$HERE/poseidon16.py" -o out/poseidon16.json
"$X" --python out/poseidon16.json --name Poseidon16 -o out/Poseidon16.lean
(cd hax-lean && lake env lean "$W/out/Poseidon16.lean")
echo "Poseidon16.lean compiles"

# 3. Fragment probes.
bash "$HERE/probe.sh" "$W/hax-lean" "$W/out/probe"
