/// The business-level validation failures supported by subscription amount
/// fields. Parsing and validation stay outside widgets so the quick and full
/// forms cannot drift apart.
enum AmountInputIssue { empty, invalid, zero, negative }

extension AmountInputIssueX on AmountInputIssue {
  String get localizationKey => switch (this) {
    AmountInputIssue.empty => 'v17AmountRequired',
    AmountInputIssue.invalid => 'v17AmountInvalid',
    AmountInputIssue.zero => 'v17AmountZero',
    AmountInputIssue.negative => 'v17AmountNegative',
  };
}

class AmountInputValidation {
  const AmountInputValidation.valid(this.value) : issue = null;

  const AmountInputValidation.invalid(this.issue) : value = null;

  final double? value;
  final AmountInputIssue? issue;

  bool get isValid => issue == null && value != null;
}

/// Parses a user-entered amount without relying on the device locale.
///
/// Both Latin and Arabic/Persian digits are accepted. A single dot, comma,
/// Arabic comma, or Arabic decimal separator is treated as the decimal mark.
/// Conventional grouped values such as `1,234.56`, `1.234,56`, and
/// `1٬234٫56` are also accepted after their grouping has been validated.
/// Unsupported syntax, exponents, malformed grouping, and non-finite values
/// are rejected.
double? parseLocalizedAmount(String input) {
  var value = input.trim();
  if (value.isEmpty) return null;

  const easternDigits = '٠١٢٣٤٥٦٧٨٩';
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  for (var index = 0; index < 10; index++) {
    value = value
        .replaceAll(easternDigits[index], '$index')
        .replaceAll(persianDigits[index], '$index');
  }
  value = value
      .replaceAll('\u00a0', '')
      .replaceAll('\u202f', '')
      .replaceAll(' ', '')
      .replaceAll('−', '-');

  var sign = '';
  if (value.startsWith('-')) {
    sign = '-';
    value = value.substring(1);
  } else if (value.startsWith('+')) {
    value = value.substring(1);
  }
  if (value.isEmpty || value.contains(RegExp(r'[+-]'))) return null;

  final arabicDecimalIndex = value.lastIndexOf('٫');
  final dotIndex = value.lastIndexOf('.');
  final commaIndex = _lastIndexOfEither(value, ',', '،');
  final decimalIndex =
      arabicDecimalIndex >= 0
          ? arabicDecimalIndex
          : dotIndex >= 0 && commaIndex >= 0
          ? (dotIndex > commaIndex ? dotIndex : commaIndex)
          : _singleDecimalIndex(value, dotIndex, commaIndex);

  final integerPart =
      decimalIndex < 0 ? value : value.substring(0, decimalIndex);
  final fractionPart =
      decimalIndex < 0 ? '' : value.substring(decimalIndex + 1);
  if (fractionPart.contains(RegExp(r'[.,،٫٬]'))) return null;
  if (fractionPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fractionPart)) {
    return null;
  }
  if (!_validIntegerPart(integerPart)) return null;

  final digits = integerPart.replaceAll(RegExp(r'[.,،٬]'), '');
  if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) return null;
  final normalized =
      '$sign$digits${fractionPart.isEmpty ? '' : '.$fractionPart'}';
  final parsed = double.tryParse(normalized);
  return parsed != null && parsed.isFinite ? parsed : null;
}

AmountInputValidation validateAmountInput(String input) {
  if (input.trim().isEmpty) {
    return const AmountInputValidation.invalid(AmountInputIssue.empty);
  }
  final value = parseLocalizedAmount(input);
  if (value == null) {
    return const AmountInputValidation.invalid(AmountInputIssue.invalid);
  }
  if (value == 0) {
    return const AmountInputValidation.invalid(AmountInputIssue.zero);
  }
  if (value < 0) {
    return const AmountInputValidation.invalid(AmountInputIssue.negative);
  }
  return AmountInputValidation.valid(value);
}

int _lastIndexOfEither(String value, String first, String second) {
  final firstIndex = value.lastIndexOf(first);
  final secondIndex = value.lastIndexOf(second);
  return firstIndex > secondIndex ? firstIndex : secondIndex;
}

int _singleDecimalIndex(String value, int dotIndex, int commaIndex) {
  final separatorIndex = dotIndex >= 0 ? dotIndex : commaIndex;
  if (separatorIndex < 0) return -1;
  final separator = value[separatorIndex];
  final normalizedSeparator = separator == '،' ? ',' : separator;
  final matches = RegExp(
    normalizedSeparator == '.' ? r'[.]' : r'[,،]',
  ).allMatches(value);
  return matches.length == 1 ? separatorIndex : -1;
}

bool _validIntegerPart(String value) {
  if (value.isEmpty) return true;
  if (value.contains('٫')) return false;
  final separators = RegExp(r'[.,،٬]').allMatches(value).toList();
  if (separators.isEmpty) return RegExp(r'^\d+$').hasMatch(value);

  final groups = value.split(RegExp(r'[.,،٬]'));
  if (groups.any(
    (group) => group.isEmpty || !RegExp(r'^\d+$').hasMatch(group),
  )) {
    return false;
  }
  if (groups.first.length > 3) return false;
  return groups.skip(1).every((group) => group.length == 3);
}
