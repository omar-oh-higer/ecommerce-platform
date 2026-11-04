import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_core/shop_core.dart';

class MockRepo extends Mock implements AuthRepository {}

void main() {
  late MockRepo repo;
  const customer = User(id: 1, name: 'C', email: 'c@x.y', role: UserRole.customer);
  const admin = User(id: 2, name: 'A', email: 'a@x.y', role: UserRole.admin);

  setUp(() => repo = MockRepo());

  blocTest<AuthCubit, AuthState>(
    'login success',
    build: () {
      when(() => repo.login(email: 'c@x.y', password: 'pw')).thenAnswer((_) async => customer);
      return AuthCubit(repo);
    },
    act: (c) => c.login(' c@x.y ', 'pw'),
    expect: () => [const AuthLoading(), const Authenticated(customer)],
  );

  blocTest<AuthCubit, AuthState>(
    'login failure keeps the failure for the form',
    build: () {
      when(() => repo.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const InvalidCredentialsFailure('Wrong email or password.'));
      return AuthCubit(repo);
    },
    act: (c) => c.login('c@x.y', 'bad'),
    expect: () => [
      const AuthLoading(),
      const Unauthenticated(failure: InvalidCredentialsFailure('Wrong email or password.')),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'admin-only app rejects a customer and signs them out',
    build: () {
      when(() => repo.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => customer);
      when(() => repo.logout()).thenAnswer((_) async {});
      return AuthCubit(repo)..adminOnly = true;
    },
    act: (c) => c.login('c@x.y', 'pw'),
    expect: () => [const AuthLoading(), isA<Unauthenticated>()],
    verify: (_) => verify(() => repo.logout()).called(1),
  );

  blocTest<AuthCubit, AuthState>(
    'start restores a stored session',
    build: () {
      when(() => repo.restoreSession()).thenAnswer((_) async => admin);
      return AuthCubit(repo);
    },
    act: (c) => c.start(),
    expect: () => [const Authenticated(admin)],
  );

  blocTest<AuthCubit, AuthState>(
    'expired session flag',
    build: () => AuthCubit(repo),
    act: (c) => c.sessionExpired(),
    expect: () => [const Unauthenticated(sessionExpired: true)],
  );
}
