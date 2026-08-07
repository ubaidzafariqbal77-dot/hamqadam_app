import '../../constants/app_constants.dart';

/// Centralised, reusable client-side validators. Each returns `null` when
/// valid or an error message otherwise, matching Flutter's validator contract.
class AppValidators {
  const AppValidators._();

  static final RegExp _email = RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
  // Accepts local (03001234567) and international (+920300...) formats.
  static final RegExp _phone = RegExp(r'^\+?[0-9]{7,15}$');
  // Letters (incl. common accents), spaces, hyphen and apostrophe only.
  static final RegExp _name = RegExp(r"^[A-Za-zÀ-ÿ]+(?:[ '\-][A-Za-zÀ-ÿ]+)*$");

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  /// First/last name: required, 2–50 chars, letters + space/hyphen/apostrophe,
  /// no digits or special characters.
  static String? personName(String? value, {String field = 'Name'}) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return '$field is required';
    if (v.length < 2) return '$field must be at least 2 characters';
    if (v.length > 50) return '$field must be under 50 characters';
    if (RegExp(r'[0-9]').hasMatch(v)) return '$field cannot contain numbers';
    if (!_name.hasMatch(v)) return "$field may only contain letters, spaces, - and '";
    return null;
  }

  static String? email(String? value, {bool isRequired = true}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? 'Email is required' : null;
    if (v.length > 255) return 'Email must be under 255 characters';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value, {bool isRequired = true}) {
    final String v = value?.trim().replaceAll(' ', '') ?? '';
    if (v.isEmpty) return isRequired ? 'Phone number is required' : null;
    if (!_phone.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  /// Normalises a Pakistani mobile number to local `03XXXXXXXXX` form, or
  /// returns null if it is not a valid PK mobile number.
  /// Accepts 03001234567, 923001234567, +923001234567.
  static String? normalizePakPhone(String? value) {
    String v = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (v.startsWith('+')) v = v.substring(1);
    if (v.startsWith('92')) v = '0${v.substring(2)}';
    // Must now be 11 digits, starting 03, with the mobile prefix 3.
    if (RegExp(r'^03[0-9]{9}$').hasMatch(v)) return v;
    return null;
  }

  /// Validator for a Pakistani mobile number field.
  static String? pakistaniPhone(String? value, {bool isRequired = true}) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) return isRequired ? 'Phone number is required' : null;
    if (normalizePakPhone(raw) == null) {
      return 'Enter a valid Pakistani mobile number';
    }
    return null;
  }

  /// Strong password: 8+ chars, upper, lower, number, special char, no spaces.
  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters';
    if (v.contains(' ')) return 'Password cannot contain spaces';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Add a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add a number';
    if (!RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-\[\];'/`~+=\\]''').hasMatch(v)) {
      return r'Add a special character (e.g. @ # $ !)';
    }
    return null;
  }

  /// Password must not match the user's email, name or phone (case-insensitive).
  static String? passwordNotPersonal(
    String? password, {
    required List<String> against,
  }) {
    final String p = (password ?? '').trim().toLowerCase();
    if (p.isEmpty) return null;
    for (final String other in against) {
      final String o = other.trim().toLowerCase();
      if (o.isNotEmpty && o == p) {
        return 'Password must not match your email, name or phone';
      }
    }
    return null;
  }

  /// Referral code: optional, max 20 chars, alphanumeric.
  static String? referralCode(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (v.length > 20) return 'Referral code must be under 20 characters';
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(v)) {
      return 'Referral code may only contain letters and numbers';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? minLength(String? value, int min, {String field = 'This field'}) {
    if ((value ?? '').trim().length < min) return '$field must be at least $min characters';
    return null;
  }

  static String? maxLength(String? value, int max, {String field = 'This field'}) {
    if ((value ?? '').trim().length > max) return '$field must be under $max characters';
    return null;
  }

  static String? numeric(String? value, {bool isRequired = true, String field = 'Value'}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? '$field is required' : null;
    if (double.tryParse(v) == null) return '$field must be a number';
    return null;
  }

  static String? integer(String? value, {bool isRequired = true, String field = 'Value'}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? '$field is required' : null;
    if (int.tryParse(v) == null) return '$field must be a whole number';
    return null;
  }

  static String? positiveNumber(String? value, {bool isRequired = true, String field = 'Value'}) {
    final String? base = numeric(value, isRequired: isRequired, field: field);
    if (base != null) return base;
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (double.parse(v) < 0) return '$field cannot be negative';
    return null;
  }

  /// Numeric value that must fall within [min, max].
  static String? numberInRange(
    String? value,
    num min,
    num max, {
    bool isRequired = true,
    String field = 'Value',
  }) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? '$field is required' : null;
    final num? n = num.tryParse(v);
    if (n == null) return '$field must be a number';
    if (n < min || n > max) return '$field must be between $min and $max';
    return null;
  }

  static String? year(String? value, {bool isRequired = true, String field = 'Year'}) {
    final String? base = integer(value, isRequired: isRequired, field: field);
    if (base != null) return base;
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final int y = int.parse(v);
    final int nowYear = DateTime.now().year;
    if (y < 1950 || y > nowYear) return '$field must be between 1950 and $nowYear';
    return null;
  }

  static String? dateOfBirth(DateTime? value) {
    if (value == null) return 'Date of birth is required';
    final DateTime now = DateTime.now();
    if (value.isAfter(now)) return 'Date of birth cannot be in the future';
    final int age = _ageFrom(value, now);
    if (age < AppConstants.minAgeYears) {
      return 'You must be at least ${AppConstants.minAgeYears} years old';
    }
    if (age > AppConstants.maxAgeYears) return 'Please enter a valid date of birth';
    return null;
  }

  static int _ageFrom(DateTime dob, DateTime now) {
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  static String? listRequired(List<dynamic>? value, {String field = 'Selection'}) {
    if (value == null || value.isEmpty) return '$field is required';
    return null;
  }

  static String? dropdownRequired(Object? value, {String field = 'This field'}) {
    if (value == null) return 'Please select $field';
    return null;
  }

  /// min must not exceed max (for age/height/income ranges).
  static String? minNotAboveMax(num? min, num? max, {String label = 'Minimum'}) {
    if (min == null || max == null) return null;
    if (min > max) return '$label cannot exceed the maximum';
    return null;
  }

  static String? url(String? value, {bool isRequired = false}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? 'URL is required' : null;
    final Uri? uri = Uri.tryParse(v);
    if (uri == null || !uri.isAbsolute) return 'Enter a valid URL';
    return null;
  }

  static String? fileExtension(String? path, List<String> allowed, {String field = 'File'}) {
    if (path == null || path.isEmpty) return null;
    final String ext = path.split('.').last.toLowerCase();
    if (!allowed.contains(ext)) {
      return '$field type must be: ${allowed.join(', ')}';
    }
    return null;
  }

  static String? fileSize(int? bytes, int maxBytes, {String field = 'File'}) {
    if (bytes == null) return null;
    if (bytes > maxBytes) {
      return '$field must be under ${(maxBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return null;
  }
}
