class Validators {
  Validators._();

  static String normalizePhone(String value) {
    final digits = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    return RegExp(r'^0[789]\d{9}$').hasMatch(digits)
        ? '+234${digits.substring(1)}'
        : digits;
  }

  static String? phone(String? value) =>
      RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalizePhone(value ?? ''))
      ? null
      : 'Enter a valid phone number, e.g. 08012345678 or +2348012345678';

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Enter your full name';
    }
    return null;
  }
}
