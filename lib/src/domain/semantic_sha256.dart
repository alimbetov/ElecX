import 'dart:convert';

/// Dependency-free SHA-256 for canonical semantic fingerprints.
///
/// This is not an authentication primitive. It exists so semantic identity does
/// not depend on platform APIs or a package whose version could affect the semantic
/// contract surface.
String semanticSha256Hex(String value) {
  final bytes = <int>[...utf8.encode(value)];
  final bitLength = bytes.length * 8;
  bytes.add(0x80);
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xff);
  }

  final state = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];

  for (var offset = 0; offset < bytes.length; offset += 64) {
    final words = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      final base = offset + i * 4;
      words[i] = ((bytes[base] << 24) |
              (bytes[base + 1] << 16) |
              (bytes[base + 2] << 8) |
              bytes[base + 3]) &
          _mask32;
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotateRight(words[i - 15], 7) ^
          _rotateRight(words[i - 15], 18) ^
          (words[i - 15] >> 3);
      final s1 = _rotateRight(words[i - 2], 17) ^
          _rotateRight(words[i - 2], 19) ^
          (words[i - 2] >> 10);
      words[i] = (words[i - 16] + s0 + words[i - 7] + s1) & _mask32;
    }

    var a = state[0];
    var b = state[1];
    var c = state[2];
    var d = state[3];
    var e = state[4];
    var f = state[5];
    var g = state[6];
    var h = state[7];

    for (var i = 0; i < 64; i++) {
      final sum1 =
          _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
      final choose = (e & f) ^ ((~e) & g);
      final temp1 =
          (h + sum1 + choose + _roundConstants[i] + words[i]) & _mask32;
      final sum0 =
          _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (sum0 + majority) & _mask32;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & _mask32;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & _mask32;
    }

    state[0] = (state[0] + a) & _mask32;
    state[1] = (state[1] + b) & _mask32;
    state[2] = (state[2] + c) & _mask32;
    state[3] = (state[3] + d) & _mask32;
    state[4] = (state[4] + e) & _mask32;
    state[5] = (state[5] + f) & _mask32;
    state[6] = (state[6] + g) & _mask32;
    state[7] = (state[7] + h) & _mask32;
  }

  return state.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
}

const int _mask32 = 0xffffffff;

int _rotateRight(int value, int bits) =>
    ((value >> bits) | ((value << (32 - bits)) & _mask32)) & _mask32;

const List<int> _roundConstants = [
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];
