"""Compare poseidon16.py (run with catcrypt_py) against leanSpec's Poseidon(PARAMS_16)."""

import random

from catcrypt_py import Array
from lean_spec.spec.crypto.koalabear import Fp, P
from lean_spec.spec.crypto.poseidon import PARAMS_16, Poseidon

import poseidon16 as p16

F = p16.F
assert F.p == P
row = [int(x) for x in PARAMS_16.mds_first_row]
# Circulant expansion as in leanSpec: C[i][j] = row[(j - i) mod n], flattened row-major.
mds = Array[F, 256]([F(row[(j - i) % 16]) for i in range(16) for j in range(16)])
rc = Array[F, 448]([F(int(x)) for x in PARAMS_16.round_constants])
engine = Poseidon(PARAMS_16)

random.seed(0)
for _ in range(20):
    state = [random.randrange(P) for _ in range(16)]
    reference = [int(x) for x in engine.permute([Fp(v) for v in state])]
    ported = p16.permute(Array[F, 16]([F(v) for v in state]), rc, mds)
    assert reference == [x._r for x in ported], state
print("port matches leanSpec on 20 random states")
