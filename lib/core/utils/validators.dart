abstract final class Validators {
  static const String allowedEmailDomain = 'sayge.in';

  /// Validates the local part only; domain is fixed to [allowedEmailDomain].
  static String? emailLocalPart(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final localPart = value.trim().toLowerCase();
    if (localPart.contains('@') || localPart.contains(' ')) {
      return 'Enter your username only';
    }

    final localPartRegex = RegExp(r'^[a-z0-9._%+\-]+$');
    if (!localPartRegex.hasMatch(localPart)) {
      return 'Enter a valid email username';
    }

    return null;
  }

  static String composeEmail(String localPart) {
    return '${localPart.trim().toLowerCase()}@$allowedEmailDomain';
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final email = value.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    if (!email.endsWith('@$allowedEmailDomain')) {
      return 'Only @$allowedEmailDomain emails are allowed';
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

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
