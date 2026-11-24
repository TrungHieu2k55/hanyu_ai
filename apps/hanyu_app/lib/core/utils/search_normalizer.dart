String normalizeSearch(String value) {
  const groups = {
    'a': 'àáảãạăằắẳẵặâầấẩẫậāǎ',
    'e': 'èéẻẽẹêềếểễệēě',
    'i': 'ìíỉĩịīǐ',
    'o': 'òóỏõọôồốổỗộơờớởỡợōǒ',
    'u': 'ùúủũụưừứửữựūǔǖǘǚǜü',
    'y': 'ỳýỷỹỵ',
    'd': 'đ',
  };
  var result = value
      .toLowerCase()
      .trim()
      .replaceAll('u:', 'u')
      .replaceAll('v', 'u');
  for (final entry in groups.entries) {
    for (final rune in entry.value.runes) {
      result = result.replaceAll(String.fromCharCode(rune), entry.key);
    }
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}
