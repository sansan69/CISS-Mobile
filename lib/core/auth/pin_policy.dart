/// Guard PIN policy.
///
/// Existing guards may still have a 4- or 5-digit PIN issued before this
/// policy existed, so sign-in deliberately keeps accepting 4–6 digits. New
/// PINs must be exactly 6 digits and must not be trivially guessable.
library;

const int kGuardPinLength = 6;

const Set<String> _commonPins = <String>{
  '000000',
  '111111',
  '121212',
  '112233',
  '123123',
  '123321',
  '123456',
  '147258',
  '159357',
  '222222',
  '333333',
  '444444',
  '520131',
  '555555',
  '654321',
  '666666',
  '777777',
  '888888',
  '999999',
};

/// Returns true when [pin] is a valid new guard PIN.
bool isValidNewGuardPin(String pin) => validateNewGuardPin(pin) == null;

/// Returns a user-facing validation message, or null when [pin] is acceptable.
String? validateNewGuardPin(String pin) {
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
    return 'Enter a 6-digit PIN.';
  }
  if (_isRepeatedDigit(pin) || _isSequential(pin) || _isRepeatingPattern(pin)) {
    return 'Choose a stronger 6-digit PIN (avoid repeated or sequential digits).';
  }
  if (_commonPins.contains(pin)) {
    return 'Choose a stronger 6-digit PIN (avoid common PINs).';
  }
  return null;
}

bool _isRepeatedDigit(String pin) => pin.split('').toSet().length == 1;

bool _isSequential(String pin) {
  var ascending = true;
  var descending = true;
  for (var i = 1; i < pin.length; i++) {
    final previous = pin.codeUnitAt(i - 1);
    final current = pin.codeUnitAt(i);
    if (current != previous + 1) ascending = false;
    if (current != previous - 1) descending = false;
  }
  return ascending || descending;
}

/// Rejects patterns such as 121212, 123123, 112233 and 454545.
bool _isRepeatingPattern(String pin) {
  for (final size in <int>[2, 3]) {
    if (pin.length % size != 0) continue;
    final unit = pin.substring(0, size);
    if (unit * (pin.length ~/ size) == pin) return true;
  }
  return false;
}
