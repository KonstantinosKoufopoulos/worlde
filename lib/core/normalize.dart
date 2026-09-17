/// Official match-key normalize (Carolos / SCHEMA.md):
/// NFD → strip combining marks → uppercase Greek · len==5 · ς→Σ · reject non-Greek.
String? normalizeGreekWord(String input) {
  final nfd = _toNfd(input.trim());
  final buf = StringBuffer();

  for (final rune in nfd.runes) {
    if (_isCombiningMark(rune)) continue;

    final ch = String.fromCharCode(rune);
    final mapped = _mapToGreekUpper(ch);
    if (mapped == null) return null; // non-Greek
    buf.write(mapped);
  }

  final result = buf.toString();
  if (result.length != 5) return null;
  for (var i = 0; i < result.length; i++) {
    if (!_greekUpper.contains(result[i])) return null;
  }
  return result;
}

String? _mapToGreekUpper(String ch) {
  if (_greekUpper.contains(ch)) return ch;
  final fromLower = _lowerToUpper[ch];
  if (fromLower != null) return fromLower;
  // Dart toUpperCase for plain Greek α–ω
  final upper = ch.toUpperCase();
  if (upper == 'Σ' || ch == 'ς' || ch == 'σ') return 'Σ';
  if (_greekUpper.contains(upper)) return upper;
  return null;
}

bool _isCombiningMark(int rune) {
  if (rune >= 0x0300 && rune <= 0x036F) return true;
  if (rune >= 0x1AB0 && rune <= 0x1AFF) return true;
  if (rune >= 0x1DC0 && rune <= 0x1DFF) return true;
  if (rune >= 0x20D0 && rune <= 0x20FF) return true;
  if (rune >= 0xFE20 && rune <= 0xFE2F) return true;
  return false;
}

const _greekUpper = {
  'Α', 'Β', 'Γ', 'Δ', 'Ε', 'Ζ', 'Η', 'Θ', 'Ι', 'Κ', 'Λ', 'Μ',
  'Ν', 'Ξ', 'Ο', 'Π', 'Ρ', 'Σ', 'Τ', 'Υ', 'Φ', 'Χ', 'Ψ', 'Ω',
};

const _lowerToUpper = {
  'α': 'Α', 'β': 'Β', 'γ': 'Γ', 'δ': 'Δ', 'ε': 'Ε', 'ζ': 'Ζ',
  'η': 'Η', 'θ': 'Θ', 'ι': 'Ι', 'κ': 'Κ', 'λ': 'Λ', 'μ': 'Μ',
  'ν': 'Ν', 'ξ': 'Ξ', 'ο': 'Ο', 'π': 'Π', 'ρ': 'Ρ', 'σ': 'Σ',
  'ς': 'Σ', 'τ': 'Τ', 'υ': 'Υ', 'φ': 'Φ', 'χ': 'Χ', 'ψ': 'Ψ',
  'ω': 'Ω',
  'ά': 'Α', 'έ': 'Ε', 'ή': 'Η', 'ί': 'Ι', 'ό': 'Ο', 'ύ': 'Υ', 'ώ': 'Ω',
  'ϊ': 'Ι', 'ϋ': 'Υ', 'ΐ': 'Ι', 'ΰ': 'Υ',
  'Ά': 'Α', 'Έ': 'Ε', 'Ή': 'Η', 'Ί': 'Ι', 'Ό': 'Ο', 'Ύ': 'Υ', 'Ώ': 'Ω',
  'Ϊ': 'Ι', 'Ϋ': 'Υ',
};

/// Greek-focused NFD: decompose common precomposed letters to base + marks.
String _toNfd(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final decomp = _greekNfd[rune];
    if (decomp != null) {
      out.write(decomp);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

const _greekNfd = <int, String>{
  0x03AC: 'α\u0301',
  0x03AD: 'ε\u0301',
  0x03AE: 'η\u0301',
  0x03AF: 'ι\u0301',
  0x03CC: 'ο\u0301',
  0x03CD: 'υ\u0301',
  0x03CE: 'ω\u0301',
  0x03CA: 'ι\u0308',
  0x03CB: 'υ\u0308',
  0x0390: 'ι\u0308\u0301',
  0x03B0: 'υ\u0308\u0301',
  0x0386: 'Α\u0301',
  0x0388: 'Ε\u0301',
  0x0389: 'Η\u0301',
  0x038A: 'Ι\u0301',
  0x038C: 'Ο\u0301',
  0x038E: 'Υ\u0301',
  0x038F: 'Ω\u0301',
  0x03AA: 'Ι\u0308',
  0x03AB: 'Υ\u0308',
};

