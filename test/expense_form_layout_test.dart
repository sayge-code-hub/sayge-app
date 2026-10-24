import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sayge_app/core/auth/auth_local_storage.dart';
import 'package:sayge_app/core/auth/auth_session.dart';
import 'package:sayge_app/core/error/failures.dart';
import 'package:sayge_app/core/theme/app_theme.dart';
import 'package:sayge_app/features/auth/domain/entities/user.dart';
import 'package:sayge_app/features/expenses/domain/entities/expense.dart';
import 'package:sayge_app/features/expenses/domain/entities/expense_category.dart';
import 'package:sayge_app/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:sayge_app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:sayge_app/features/expenses/domain/usecases/expense_category_usecases.dart';
import 'package:sayge_app/features/expenses/domain/usecases/expense_usecases.dart';
import 'package:sayge_app/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:sayge_app/features/expenses/presentation/pages/expenses_page.dart';
import 'package:sayge_app/features/settings/domain/entities/client.dart';
import 'package:sayge_app/features/settings/domain/repositories/client_repository.dart';
import 'package:sayge_app/features/settings/domain/usecases/add_client.dart';
import 'package:sayge_app/features/settings/domain/usecases/client_lifecycle.dart';
import 'package:sayge_app/features/settings/domain/usecases/get_clients.dart';
import 'package:sayge_app/features/settings/presentation/bloc/clients/clients_bloc.dart';
import 'package:sayge_app/injection_container.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sl.registerSingleton<AuthSession>(
      AuthSession(
        storage: AuthLocalStorage(prefs),
        initialUser: const User(
          id: 'user-1',
          email: 'owner@sayge.test',
          roleId: 'role-owner',
          roleCode: 'owner',
          roleLabel: 'Owner',
        ),
      ),
    );
    sl.registerLazySingleton<ExpenseRepository>(_EmptyExpenses.new);
    sl.registerLazySingleton(() => GetExpensesUseCase(sl()));
    sl.registerLazySingleton(() => AddExpenseUseCase(sl()));
    sl.registerLazySingleton(() => UpdateExpenseUseCase(sl()));
    sl.registerLazySingleton(() => SetExpenseApprovalUseCase(sl()));
    sl.registerLazySingleton(() => UploadExpenseReceiptUseCase(sl()));
    sl.registerFactory(
      () => ExpensesBloc(
        getExpensesUseCase: sl(),
        addExpenseUseCase: sl(),
        updateExpenseUseCase: sl(),
        setExpenseApprovalUseCase: sl(),
        uploadExpenseReceiptUseCase: sl(),
      ),
    );
    sl.registerLazySingleton<ExpenseCategoryRepository>(_FixedCategories.new);
    sl.registerLazySingleton(() => GetExpenseCategoriesUseCase(sl()));
    sl.registerLazySingleton<ClientRepository>(_OneClient.new);
    sl.registerLazySingleton(() => GetClientsUseCase(sl()));
    sl.registerLazySingleton(() => AddClientUseCase(sl()));
    sl.registerLazySingleton(() => UpdateClientUseCase(sl()));
    sl.registerLazySingleton(() => SetClientActiveUseCase(sl()));
    sl.registerLazySingleton(() => DeleteClientUseCase(sl()));
    sl.registerFactory(
      () => ClientsBloc(
        getClientsUseCase: sl(),
        addClientUseCase: sl(),
        updateClientUseCase: sl(),
        setClientActiveUseCase: sl(),
        deleteClientUseCase: sl(),
      ),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('expense form places two fields on each row', (tester) async {
    await _openForm(tester, const Size(1440, 900));

    _expectSameRow(tester, 'Cost center', 'Expense date');
    _expectSameRow(tester, 'Expense made for', 'Amount');
    _expectSameRow(tester, 'Paid from', 'Category');

    final receipt = tester.getRect(
      find.byKey(const Key('expense-receipt-field')),
    );
    final category = tester.getTopLeft(find.text('Category'));
    final paidFrom = tester.getTopLeft(find.text('Paid from'));
    expect((receipt.left - paidFrom.dx).abs(), lessThan(2));
    expect(receipt.right, lessThan(category.dx));
  });

  testWidgets('expense form stacks fields on a narrow screen', (tester) async {
    await _openForm(tester, const Size(800, 900));

    final cost = tester.getTopLeft(find.text('Cost center'));
    final date = tester.getTopLeft(find.text('Expense date'));
    expect(date.dy, greaterThan(cost.dy + 20));
  });
}

Future<void> _openForm(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ExpensesPage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('New expense'));
  await tester.pumpAndSettle();
}

void _expectSameRow(WidgetTester tester, String left, String right) {
  final leftBox = tester.getRect(find.text(left));
  final rightBox = tester.getRect(find.text(right));
  expect((leftBox.top - rightBox.top).abs(), lessThan(2));
  expect(rightBox.left, greaterThan(leftBox.right));
}

class _EmptyExpenses implements ExpenseRepository {
  @override
  Future<Either<Failure, List<Expense>>> getExpenses() async => const Right([]);

  @override
  Future<Either<Failure, Expense>> addExpense(Expense expense) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Expense>> updateExpense(Expense expense) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Expense>> setApprovalStatus({
    required String expenseId,
    required ExpenseApprovalStatus status,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Expense>> uploadReceipt({
    required String expenseId,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
  }) {
    throw UnimplementedError();
  }
}

class _FixedCategories implements ExpenseCategoryRepository {
  @override
  Future<Either<Failure, List<ExpenseCategory>>> listCategories() async {
    return const Right([ExpenseCategory(id: 'cat_misc', name: 'Misc')]);
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> addCategory(String name) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> renameCategory({
    required String id,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> deleteCategory(String id) {
    throw UnimplementedError();
  }
}

class _OneClient implements ClientRepository {
  static const _client = Client(id: 'client-1', name: 'Mahindra Finance');

  @override
  Future<Either<Failure, List<Client>>> getClients() async =>
      const Right([_client]);

  @override
  Future<Either<Failure, Client>> addClient(Client client) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Client>> updateClient(Client client) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Client>> setClientActive({
    required String id,
    required bool isActive,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Client>> updateClientLogo({
    required String id,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> deleteClient(String id) {
    throw UnimplementedError();
  }
}
