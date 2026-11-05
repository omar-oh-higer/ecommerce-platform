import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shop_core/shop_core.dart';
import 'package:shop_mobile/features/auth/login_page.dart';
import 'package:shop_mobile/features/cart/cart_cubit.dart';
import 'package:shop_mobile/features/orders/checkout_cubit.dart';
import 'package:shop_mobile/features/orders/checkout_page.dart';

class MockOrders extends Mock implements OrdersRepository {}

class MockAuthRepo extends Mock implements AuthRepository {}

class MemStorage implements CartStorage {
  @override
  Future<String?> read(String userKey) async => null;
  @override
  Future<void> write(String userKey, String json) async {}
}

Product watch() => const Product(
      id: 3,
      name: 'Smart Watch',
      description: '',
      price: Money(14900),
      stock: Stock(status: StockStatus.inStock, quantity: 5),
    );

Future<(CartCubit, CheckoutCubit, MockOrders)> pumpCheckout(WidgetTester tester) async {
  final orders = MockOrders();
  final cart = CartCubit(MemStorage());
  await cart.bindUser(1);
  cart.add(watch(), quantity: 2);
  final checkout = CheckoutCubit(orders, cart);
  await tester.pumpWidget(MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cart),
        BlocProvider.value(value: checkout),
        BlocProvider(create: (_) => UnreadCountCubit(_NoSource())),
      ],
      child: const CheckoutPage(),
    ),
  ));
  return (cart, checkout, orders);
}

class _NoSource implements NotificationSource {
  @override
  Stream<int> get unreadCount => const Stream.empty();
  @override
  void start() {}
  @override
  void stop() {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => registerFallbackValue(<OrderLine>[]));

  testWidgets('409 lists what is really available and keeps the order un-placed', (tester) async {
    final (cart, _, orders) = await pumpCheckout(tester);
    when(() => orders.place(any())).thenThrow(const InsufficientStockFailure('x', [
      StockProblem(productId: 3, name: 'Smart Watch', requested: 2, available: 1),
    ]));

    await tester.tap(find.text('Place order'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Not enough stock'), findsOneWidget);
    expect(find.textContaining('only 1 available (you asked for 2)'), findsOneWidget);
    expect(find.text('Update my cart'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget, reason: 'the button becomes a retry');
    expect(cart.state.items.single.quantity, 2, reason: 'cart untouched until the user chooses');
  });

  testWidgets('503 says nothing was changed and the cart was kept', (tester) async {
    final (cart, _, orders) = await pumpCheckout(tester);
    when(() => orders.place(any())).thenThrow(const ServiceUnavailableFailure(
        'Stock service is temporarily unavailable. Nothing was changed, please try again shortly.'));

    await tester.tap(find.text('Place order'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Cannot place the order right now'), findsOneWidget);
    expect(find.textContaining('Your cart was kept'), findsOneWidget);
    expect(cart.state.items, isNotEmpty);
  });

  testWidgets('429 shows the wait time', (tester) async {
    final (_, _, orders) = await pumpCheckout(tester);
    when(() => orders.place(any()))
        .thenThrow(const RateLimitedFailure('Too many attempts.', retryAfter: Duration(seconds: 42)));

    await tester.tap(find.text('Place order'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Try again in 42 s'), findsOneWidget);
  });

  testWidgets('the button is disabled while the order is being sent (no double order)', (tester) async {
    final (_, _, orders) = await pumpCheckout(tester);
    // The server has not answered yet.
    when(() => orders.place(any())).thenAnswer((_) => Completer<Order>().future);

    await tester.tap(find.text('Place order'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    verify(() => orders.place(any())).called(1);
  });

  group('login page', () {
    late MockAuthRepo repo;
    late AuthCubit cubit;

    Future<void> pumpLogin(WidgetTester tester) async {
      repo = MockAuthRepo();
      cubit = AuthCubit(repo);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(value: cubit, child: const LoginPage()),
      ));
    }

    testWidgets('wrong password shows the message', (tester) async {
      await pumpLogin(tester);
      when(() => repo.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const InvalidCredentialsFailure('Wrong email or password.'));
      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'bad');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Wrong email or password.'), findsOneWidget);
    });

    testWidgets('rate limit shows the countdown', (tester) async {
      await pumpLogin(tester);
      when(() => repo.login(email: any(named: 'email'), password: any(named: 'password'))).thenThrow(
          const RateLimitedFailure('Too many attempts. Please wait a moment and try again.',
              retryAfter: Duration(seconds: 37)));
      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'x');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('try again in 37 s'), findsOneWidget);
    });

    testWidgets('empty form is blocked before any request', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
      verifyNever(() => repo.login(email: any(named: 'email'), password: any(named: 'password')));
    });
  });
}
