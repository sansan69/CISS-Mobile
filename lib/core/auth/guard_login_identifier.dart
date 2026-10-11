/// Classifies the identifier entered by a guard without treating employee IDs
/// containing digits as telephone numbers.
abstract final class GuardLoginIdentifier {
  static final RegExp _acceptedPhoneCharacters = RegExp(r'^[0-9\s()+-]+$');
  static final RegExp _phoneDigits = RegExp(r'^\d{8,15}$');

  /// A value is a phone number only when every character is accepted in a
  /// phone number and its normalized digit form is 8–15 digits long.
  static bool isPhoneNumber(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || !_acceptedPhoneCharacters.hasMatch(trimmed)) {
      return false;
    }
    final digits = trimmed.replaceAll(RegExp(r'\D+'), '');
    return _phoneDigits.hasMatch(digits);
  }

  /// Query parameters used when carrying a typed identifier into PIN setup.
  /// This keeps setup prefill aligned with login request classification.
  static Map<String, String> setupQueryParameters(String input) {
    final identifier = input.trim();
    if (identifier.isEmpty) return const <String, String>{};
    return <String, String>{
      isPhoneNumber(identifier) ? 'phoneNumber' : 'employeeId': identifier,
    };
  }
}
