import 'dart:async';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

/// Authentication state
enum AuthState {
  unknown,
  unauthenticated,
  authenticated,
  confirmSignUp,
  confirmSignIn,
  resetPassword,
}

/// User information
class AuthUser {
  final String userId;
  final String email;
  final String? name;

  AuthUser({
    required this.userId,
    required this.email,
    this.name,
  });
}

/// Authentication result
class AuthResult {
  final bool success;
  final String? message;
  final AuthState? nextStep;

  AuthResult({
    required this.success,
    this.message,
    this.nextStep,
  });

  factory AuthResult.success({String? message, AuthState? nextStep}) {
    return AuthResult(success: true, message: message, nextStep: nextStep);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(success: false, message: message);
  }
}

/// Authentication service using AWS Cognito
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _authStateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateStream => _authStateController.stream;

  AuthState _currentState = AuthState.unknown;
  AuthState get currentState => _currentState;

  String? _pendingEmail;

  /// Initialize and check current auth state
  Future<AuthState> checkAuthState() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        _updateState(AuthState.authenticated);
      } else {
        _updateState(AuthState.unauthenticated);
      }
    } catch (e) {
      safePrint('Error checking auth state: $e');
      _updateState(AuthState.unauthenticated);
    }
    return _currentState;
  }

  /// Get current authenticated user
  Future<AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final attributes = await Amplify.Auth.fetchUserAttributes();

      String? email;
      String? name;

      for (final attr in attributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          email = attr.value;
        } else if (attr.userAttributeKey == AuthUserAttributeKey.name) {
          name = attr.value;
        }
      }

      return AuthUser(
        userId: user.userId,
        email: email ?? '',
        name: name,
      );
    } catch (e) {
      safePrint('Error getting current user: $e');
      return null;
    }
  }

  /// Sign up with email and password
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final userAttributes = <AuthUserAttributeKey, String>{
        AuthUserAttributeKey.email: email,
      };

      if (name != null && name.isNotEmpty) {
        userAttributes[AuthUserAttributeKey.name] = name;
      }

      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );

      if (result.isSignUpComplete) {
        return AuthResult.success(
          message: 'Account created successfully',
          nextStep: AuthState.unauthenticated,
        );
      } else {
        _pendingEmail = email;
        _updateState(AuthState.confirmSignUp);
        return AuthResult.success(
          message: 'Please check your email for verification code',
          nextStep: AuthState.confirmSignUp,
        );
      }
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Sign up failed: $e');
    }
  }

  /// Confirm sign up with verification code
  Future<AuthResult> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );

      if (result.isSignUpComplete) {
        _pendingEmail = null;
        _updateState(AuthState.unauthenticated);
        return AuthResult.success(
          message: 'Email verified successfully. Please sign in.',
          nextStep: AuthState.unauthenticated,
        );
      } else {
        return AuthResult.failure('Confirmation failed');
      }
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Confirmation failed: $e');
    }
  }

  /// Resend confirmation code
  Future<AuthResult> resendConfirmationCode(String email) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
      return AuthResult.success(message: 'Verification code sent');
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Failed to resend code: $e');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        _updateState(AuthState.authenticated);
        return AuthResult.success(
          message: 'Signed in successfully',
          nextStep: AuthState.authenticated,
        );
      } else {
        // Handle MFA or other challenges
        final nextStep = result.nextStep.signInStep;
        switch (nextStep) {
          case AuthSignInStep.confirmSignUp:
            _pendingEmail = email;
            _updateState(AuthState.confirmSignUp);
            return AuthResult.success(
              message: 'Please verify your email first',
              nextStep: AuthState.confirmSignUp,
            );
          case AuthSignInStep.confirmSignInWithTotpMfaCode:
          case AuthSignInStep.confirmSignInWithSmsMfaCode:
            _updateState(AuthState.confirmSignIn);
            return AuthResult.success(
              message: 'Please enter MFA code',
              nextStep: AuthState.confirmSignIn,
            );
          default:
            return AuthResult.failure('Additional verification required');
        }
      }
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Sign in failed: $e');
    }
  }

  /// Confirm sign in with MFA code
  Future<AuthResult> confirmSignIn(String mfaCode) async {
    try {
      final result = await Amplify.Auth.confirmSignIn(
        confirmationValue: mfaCode,
      );

      if (result.isSignedIn) {
        _updateState(AuthState.authenticated);
        return AuthResult.success(
          message: 'Signed in successfully',
          nextStep: AuthState.authenticated,
        );
      } else {
        return AuthResult.failure('MFA verification failed');
      }
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('MFA verification failed: $e');
    }
  }

  /// Sign out
  Future<AuthResult> signOut() async {
    try {
      await Amplify.Auth.signOut();
      _updateState(AuthState.unauthenticated);
      return AuthResult.success(message: 'Signed out successfully');
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Sign out failed: $e');
    }
  }

  /// Request password reset
  Future<AuthResult> resetPassword(String email) async {
    try {
      await Amplify.Auth.resetPassword(username: email);
      _pendingEmail = email;
      _updateState(AuthState.resetPassword);
      return AuthResult.success(
        message: 'Password reset code sent to your email',
        nextStep: AuthState.resetPassword,
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Password reset failed: $e');
    }
  }

  /// Confirm password reset with code and new password
  Future<AuthResult> confirmResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: code,
      );
      _pendingEmail = null;
      _updateState(AuthState.unauthenticated);
      return AuthResult.success(
        message: 'Password reset successful. Please sign in.',
        nextStep: AuthState.unauthenticated,
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('Password reset failed: $e');
    }
  }

  /// Get pending email (for confirmation flows)
  String? get pendingEmail => _pendingEmail;

  void _updateState(AuthState state) {
    _currentState = state;
    _authStateController.add(state);
  }

  String _getAuthErrorMessage(AuthException e) {
    if (e is UserNotConfirmedException) {
      return 'Please verify your email address';
    } else if (e is UserNotFoundException) {
      return 'No account found with this email';
    } else if (e is NotAuthorizedServiceException) {
      return 'Incorrect email or password';
    } else if (e is UsernameExistsException) {
      return 'An account with this email already exists';
    } else if (e is InvalidPasswordException) {
      return 'Password does not meet requirements';
    } else if (e is CodeMismatchException) {
      return 'Invalid verification code';
    } else if (e is LimitExceededException) {
      return 'Too many attempts. Please try again later';
    } else if (e.message.toLowerCase().contains('expired')) {
      return 'Verification code has expired';
    } else {
      return e.message;
    }
  }

  void dispose() {
    _authStateController.close();
  }
}
