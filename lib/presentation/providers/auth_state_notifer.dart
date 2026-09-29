import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/backend/authenticator.dart';
import '../../data/models/login_state.dart';

final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, LoginState>(
  (ref) => AuthStateNotifier(),
);

class AuthStateNotifier extends StateNotifier<LoginState> {
  AuthStateNotifier()
      : super(const Authenticator().isAlreadyLoggedIn
            ? LoginState.success
            : LoginState.idle);

  final _authenticator = const Authenticator();

  Future<void> loginWithGoogle() async {
    state = LoginState.loading;
    try {
      final result = await _authenticator.loginWithGoogle();
      if (result == LoginState.success) {
        state = LoginState.success;
      } else {
        state = LoginState.error;
      }
    } catch (e) {
      state = LoginState.error;
    }
  }

  Future<void> logOut() async {
    state = LoginState.loading;
    await _authenticator.logOut();
    state = LoginState.idle;
  }
}

// class AuthStateNotifier extends StateNotifier<AuthState> {
//   final _authenticator = const Authenticator();

//   // Constructor initializes the state and checks if the user is already logged in
//   AuthStateNotifier() : super(const AuthState.unknown()) {
//     if (_authenticator.isAlreadyLoggedIn) {
//       // If the user is already logged in, update the state to reflect that
//       state = AuthState(
//         result: AuthResult.success,
//         isLoading: false,
//         userId: _authenticator.userId,
//       );
//     }
//   }

//   Future<void> logOut() async {
//     state = state.copiedWithIsLoading(true);
//     await _authenticator.logOut();
//     state = const AuthState.unknown();
//   }

//   Future<void> loginWithGoogle() async {
//     state = state.copiedWithIsLoading(true);
//     final result = await _authenticator.loginWithGoogle();
//     final userId = _authenticator.userId;
//     if (result == AuthResult.success && userId != null) {
//       await saveUserInfo(userId: userId);
//     }
//     // Update the state based on the result of the login attempt
//     state = AuthState(
//       result: result,
//       isLoading: false,
//       userId: userId,
//     );
//   }

//   // Method to save user information
//   Future<void> saveUserInfo({required String? userId}) => _userInfoStorage.saveUserInfo(
//         userId: userId,
//         displayName: _authenticator.disaplyName,
//         email: _authenticator.email,
//       );
// }
