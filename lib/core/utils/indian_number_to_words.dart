/// Indian numbering: converts an integer amount to words (e.g. for net pay).
abstract final class IndianNumberToWords {
  static const _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  static String convert(num amount) {
    final n = amount.round();
    if (n == 0) return 'Zero Only';
    if (n < 0) return 'Minus ${convert(-n)}';

    final parts = <String>[];
    var remaining = n;

    void add(int value, String label) {
      if (value <= 0) return;
      parts.add('${_twoDigits(value)} $label');
    }

    add(remaining ~/ 10000000, 'Crore');
    remaining %= 10000000;
    add(remaining ~/ 100000, 'Lakh');
    remaining %= 100000;
    add(remaining ~/ 1000, 'Thousand');
    remaining %= 1000;
    add(remaining ~/ 100, 'Hundred');
    remaining %= 100;
    if (remaining > 0) {
      parts.add(_twoDigits(remaining));
    }

    return '${parts.join(' ')} Only';
  }

  static String _twoDigits(int n) {
    if (n < 20) return _ones[n];
    final t = _tens[n ~/ 10];
    final o = _ones[n % 10];
    return o.isEmpty ? t : '$t-$o';
  }
}
