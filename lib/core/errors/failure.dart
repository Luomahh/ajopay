/// Sealed class representing all possible failure types across the app.
/// UI layers pattern-match on these to show appropriate messages.
sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Network connection issue. Please check your internet.',
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Something went wrong on our end. Please try again.',
  ]);
}

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'You do not have permission to do that.',
  ]);
}
