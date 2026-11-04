import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../errors/app_failure.dart';
import '../models/user.dart';
import 'auth_repository.dart';

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

/// App just started, checking the stored token.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.failure, this.sessionExpired = false});

  /// Last login/register failure, for showing errors on the form.
  final AppFailure? failure;
  final bool sessionExpired;

  @override
  List<Object?> get props => [failure, sessionExpired];
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;
  @override
  List<Object?> get props => [user];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthUnknown());

  final AuthRepository _repo;

  /// Dashboard sets this to `true` so customers cannot enter it.
  bool adminOnly = false;

  Future<void> start() async {
    final user = await _repo.restoreSession().catchError((_) => null);
    emit(_accept(user));
  }

  Future<void> login(String email, String password) => _run(
      () => _repo.login(email: email.trim(), password: password));

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) =>
      _run(() => _repo.register(
            name: name.trim(),
            email: email.trim(),
            password: password,
            passwordConfirmation: passwordConfirmation,
          ));

  Future<void> logout() async {
    await _repo.logout();
    emit(const Unauthenticated());
  }

  /// Called by the network layer when refreshing the token failed.
  void sessionExpired() => emit(const Unauthenticated(sessionExpired: true));

  Future<void> _run(Future<User> Function() action) async {
    emit(const AuthLoading());
    try {
      final user = await action();
      if (adminOnly && !user.isAdmin) {
        await _repo.logout();
        emit(const Unauthenticated(
            failure: ForbiddenFailure('This area is for administrators only.')));
        return;
      }
      emit(Authenticated(user));
    } on AppFailure catch (f) {
      emit(Unauthenticated(failure: f));
    }
  }

  AuthState _accept(User? user) {
    if (user == null || (adminOnly && !user.isAdmin)) {
      return const Unauthenticated();
    }
    return Authenticated(user);
  }
}
