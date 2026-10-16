"""Poseidon permutation over KoalaBear, width 16, ported from leanSpec _permute_jit."""

from typing import Final
from catcrypt_py import Array, entry, field

F = field(2130706433)
W: Final = 16
HALF_F: Final = 4
RP: Final = 20
NRC: Final = 448
WW: Final = 256


def mds(s: Array[F, W], m: Array[F, WW]) -> Array[F, W]:
    r = s
    for i in range(W):
        acc = m[i * W] * s[0]
        for j in range(1, W):
            acc = acc + m[i * W + j] * s[j]
        r = r.set(i, acc)
    return r


@entry
def permute(s: Array[F, W], rc: Array[F, NRC], m: Array[F, WW]) -> Array[F, W]:
    st = s
    for r in range(HALF_F):
        for i in range(W):
            x = st[i] + rc[r * W + i]
            st = st.set(i, x * x * x)
        st = mds(st, m)
    for r in range(RP):
        for i in range(W):
            st = st.set(i, st[i] + rc[(HALF_F + r) * W + i])
        y = st[0]
        st = st.set(0, y * y * y)
        st = mds(st, m)
    for r in range(HALF_F):
        for i in range(W):
            x = st[i] + rc[(HALF_F + RP + r) * W + i]
            st = st.set(i, x * x * x)
        st = mds(st, m)
    return st
