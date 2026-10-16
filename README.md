# hax-lean Python front on leanSpec: experiment report

Run on 2026-10-16.

> **Provenance:** everything in this repository (README, scripts, the Poseidon port, the probes)
> was written and run by Claude Code (Claude Opus 5.5). A human gave the prompts and did not edit
> the output. The prompts, verbatim, typos included:
>
> 1. "please try https://github.com/spitters/hax-lean/tree/master/python on
>    https://github.com/leanEthereum/leanSpec and tell me about any blockers briefly. Check out
>    repos as needed."
> 2. "okay, please pist your findings in a public gist in a reprodicible descriptions. the blocker
>    list near the too"
> 3. "oh a new reo might be easier"
> 4. "readme near the top should explain the whole repo comes from claude code and the original
>    prompts"

I tried [spitters/hax-lean `python/`](https://github.com/spitters/hax-lean/tree/master/python)
on [leanEthereum/leanSpec](https://github.com/leanEthereum/leanSpec).

The tool accepts no leanSpec file as written. A hand port of one kernel, the width-16 Poseidon
permutation, goes through the whole pipeline. The port matches leanSpec's output under CPython,
`haxpipeT` extracts it, and the generated Lean file compiles.

## Blockers (most serious first)

1. **The fragment is much smaller than the spec.** leanSpec is written with Pydantic/SSZ classes,
   numpy/numba, lists, `while`, `raise`, early `return`, tuples and `hashlib`, and all of these are
   refused. Only imports from `typing` and `catcrypt_py` are allowed, so every real file fails at
   its first `import`. Only small arithmetic kernels can be ported, and only by hand. The extracted
   code is then a re-statement of the spec rather than the spec itself.
2. **No array constants.** Module-level constants can only be integers, and there are no array
   literals. Poseidon's 448 round constants and its MDS matrix have to be entry parameters. An entry
   takes at most 6 parameters, so a kernel with more inputs has to be split up.
3. **Missing field and index operations:**
   - `F(0)` is refused; `a + 1` works.
   - `**`, `/` and `.inverse()` are refused, so there is no field inversion.
   - `%` on index arithmetic is refused. The circulant MDS `row[(j - i) % n]` had to be passed in
     already expanded.
4. **Bytes and hashing are blocked.** Helper (non-entry) functions can't take arrays of
   `U8`/`U16`/`U32`, which blocks SHA3/SHAKE (XMSS PRF) and SHA-256 SSZ Merkleization. Calls can't
   nest more than 4 deep, which is tight for the XMSS chain, tree and sponge layers.
5. **Small issues:**
   - `py2json.py` needs Python 3.12 exactly and refuses 3.14.
   - `lake exe haxpipeT` prints build warnings before its own output, so the scripts call
     `.lake/build/bin/haxpipeT` directly.
   - `lake build haxpipeT` doesn't build the `.olean` files the generated module imports, and a
     restore from the shared Lake artifact cache skipped them too. `run.sh` builds those modules
     explicitly with `LAKE_ARTIFACT_CACHE=false`.

### Probe results (`probe.sh`, one construct each)

```
fzero        check: Hax.Py.RefusalKind.forwardCall at 11:15 (F)
fint         accepted
pow          check: Hax.Py.RefusalKind.operator at 11:11
fdiv         check: Hax.Py.RefusalKind.operator at 11:11
finv         check: Hax.Py.RefusalKind.method at 11:11 (inverse)
intmod       check: Hax.Py.RefusalKind.operator at 13:18
while_       read: While at 11:4: statement outside the subset
list_        read: List at 11:9: expression outside the subset
arrlit       read: List at 11:25: expression outside the subset
tuple_       check: Hax.Py.RefusalKind.tupleAnnotation at 9:17 (g)
class_       read: ClassDef at 9:0: statement outside the subset
early        check: Hax.Py.RefusalKind.returnNotLast at 12:8
raise_       read: Raise at 12:8: statement outside the subset
callee32     check: Hax.Py.RefusalKind.calleeArray at 9:0 (g)
sevenargs    check: Hax.Py.RefusalKind.entryAbi at 10:0 (f)
deep         check: Hax.Py.RefusalKind.callDepth at 20:0 (f)
bigarr       accepted
```

## Reproduce

Requirements: git, elan/lake (hax-lean pins `leanprover/lean4:v4.33.1`), `python3.12`, `uv`.
Pinned commits: hax-lean `c9e9d5c9`, leanSpec `0b7d33ec`.

```sh
git clone https://github.com/pirapira/hax-lean-leanspec && cd hax-lean-leanspec
bash run.sh work      # clones, builds haxpipeT, runs steps 1 to 3 below
```

What `run.sh` does:

1. Runs `py2json.py` and `haxpipeT` on unmodified `koalabear.py`, `crypto/poseidon.py` and
   `xmss/prf.py`. `py2json` succeeds. `haxpipeT` stops at the first import:

   ```
   ERROR koalabear.json: read: Import at 3:0: statement outside the subset
   ERROR poseidon.json: read: Import at 14:0: statement outside the subset
   ERROR prf.json: read: Import at 3:0: statement outside the subset
   ```

2. Runs `check_port.py`, which compares `poseidon16.py` (executed with `catcrypt_py`) with
   leanSpec's `Poseidon(PARAMS_16).permute` on 20 random states. It then extracts the port with
   `haxpipeT --python` and compiles the generated `Poseidon16.lean` with `lake env lean`.
3. Runs `probe.sh`, which produces the table above.

## Files

- `poseidon16.py`: hand port of leanSpec's `_permute_jit` (width 16, 4+20+4 rounds, x^3 S-box)
  into the fragment. The round constants and the flattened 16x16 MDS matrix are parameters.
- `check_port.py`: differential test of the port against leanSpec.
- `probe.sh`: one-construct probes of the fragment.
- `run.sh`: the whole reproduction.
