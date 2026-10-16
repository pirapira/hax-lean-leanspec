#!/usr/bin/env bash
# One-construct probes of the hax-lean Python fragment. Usage: probe.sh <hax-lean dir> <out dir>
set -u
H=$1; S=$2; mkdir -p "$S"
hdr='"""p."""

from typing import Final
from catcrypt_py import Array, U32, U64, entry, field

F = field(2130706433)
N: Final = 4
'
probe() {
  printf '%s\n%s\n' "$hdr" "$2" > "$S/$1.py"
  python3.12 -I "$H/python/py2json.py" "$S/$1.py" -o "$S/$1.json"
  printf '%-12s ' "$1"
  out=$("$H/.lake/build/bin/haxpipeT" --python "$S/$1.json" --name P -o "$S/$1.lean" 2>&1 | head -1 | sed 's|.*json: ||')
  [ -f "$S/$1.lean" ] && echo accepted || echo "$out"
}
probe fzero     $'@entry\ndef f(a: F) -> F:\n    return a + F(0)'
probe fint      $'@entry\ndef f(a: F) -> F:\n    return a + 1'
probe pow       $'@entry\ndef f(a: F) -> F:\n    return a ** 3'
probe fdiv      $'@entry\ndef f(a: F, b: F) -> F:\n    return a / b'
probe finv      $'@entry\ndef f(a: F) -> F:\n    return a.inverse()'
probe intmod    $'@entry\ndef f(a: Array[F, N]) -> F:\n    r = a[0]\n    for i in range(N):\n        r = r + a[(i + 1) % N]\n    return r'
probe while_    $'@entry\ndef f(a: U64) -> U64:\n    while a > 0:\n        a = a - 1\n    return a'
probe list_     $'@entry\ndef f(a: U64) -> U64:\n    xs = [a, a]\n    return xs[0]'
probe arrlit    $'@entry\ndef f(a: U64) -> Array[U64, 2]:\n    return Array[U64, 2]([a, a])'
probe tuple_    $'def g(a: U64) -> tuple[U64, U64]:\n    return (a, a)'
probe class_    $'class C:\n    x: int\n\n@entry\ndef f(a: U64) -> U64:\n    return a'
probe early     $'@entry\ndef f(a: U64) -> U64:\n    if a > 1:\n        return a\n    return a'
probe raise_    $'@entry\ndef f(a: U64) -> U64:\n    if a > 1:\n        raise ValueError()\n    return a'
probe callee32  $'def g(a: Array[U32, N]) -> U32:\n    return a[0]\n\n@entry\ndef f(a: Array[U32, N]) -> U32:\n    return g(a)'
probe sevenargs $'@entry\ndef f(a: U64, b: U64, c: U64, d: U64, e: U64, g: U64, h: U64) -> U64:\n    return a'
probe deep      $'def g1(a: U64) -> U64:\n    return a\ndef g2(a: U64) -> U64:\n    return g1(a)\ndef g3(a: U64) -> U64:\n    return g2(a)\ndef g4(a: U64) -> U64:\n    return g3(a)\ndef g5(a: U64) -> U64:\n    return g4(a)\n@entry\ndef f(a: U64) -> U64:\n    return g5(a)'
probe bigarr    $'@entry\ndef f(a: Array[F, 1000]) -> F:\n    return a[0]'
