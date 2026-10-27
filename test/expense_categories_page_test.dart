import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/error/failures.dart';
import 'package:sayge_app/core/theme/app_theme.dart';
import 'package:sayge_app/features/expenses/domain/entities/expense_category.dart';
import 'package:sayge_app/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:sayge_app/features/expenses/domain/usecases/expense_category_usecases.dart';
import 'package:sayge_app/features/expenses/presentation/bloc/categories/expense_categories_bloc.dart';
import 'package:sayge_app/features/settings/presentation/pages/expense_categories_page.dart';
import 'package:sayge_app/features/settings/presentation/pages/settings_hub_page.dart';
import 'package:sayge_app/injection_container.dart';

class _MemoryCategories implements ExpenseCategoryRepository {
  final categories = <ExpenseCategory>[
    const ExpenseCategory(id: 'cat_misc', name: 'Misc', sortOrder: 0),
  ];

  @override
  Future<Either<Failure, List<ExpenseCategory>>> listCategories() async {
    return Right(List<ExpenseCategory>.of(categories));
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> addCategory(
    String name,
  ) async {
    categories.add(
      ExpenseCategory(
        id: 'cat_${categories.length}',
        name: name.trim(),
        sortOrder: categories.length,
      ),
    );
    return Right(List<ExpenseCategory>.of(categories));
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> renameCategory({
    required String id,
    required String name,
  }) async {
    final index = categories.indexWhere((category) => category.id == id);
    categories[index] = ExpenseCategory(
      id: id,
      name: name.trim(),
      sortOrder: categories[index].sortOrder,
    );
    return Right(List<ExpenseCategory>.of(categories));
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> deleteCategory(
    String id,
  ) async {
    categories.removeWhere((category) => category.id == id);
    return Right(List<ExpenseCategory>.of(categories));
  }
}

void main() {
  late _MemoryCategories repository;

  setUp(() {
    repository = _MemoryCategories();
    sl.registerLazySingleton<ExpenseCategoryRepository>(() => repository);
    sl.registerLazySingleton(() => GetExpenseCategoriesUseCase(sl()));
    sl.registerLazySingleton(() => AddExpenseCategoryUseCase(sl()));
    sl.registerLazySingleton(() => RenameExpenseCategoryUseCase(sl()));
    sl.registerLazySingleton(() => DeleteExpenseCategoryUseCase(sl()));
    sl.registerFactory(
      () => ExpenseCategoriesBloc(
        getCategories: sl(),
        addCategory: sl(),
        renameCategory: sl(),
        deleteCategory: sl(),
      ),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('settings hub includes Categories', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 1200)),
          child: const SettingsHubPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);

    // Desktop hub uses 4 columns — first row stays on one baseline.
    final firstRow = [
      'Invite employee',
      'Manage invites',
      'Manage clients',
      'Company Details',
    ];
    final tops = firstRow
        .map((label) => tester.getTopLeft(find.text(label)).dy)
        .toList();
    for (final top in tops) {
      expect((top - tops.first).abs(), lessThan(2));
    }

    // Billing starts the second row.
    final billingTop = tester.getTopLeft(find.text('Billing')).dy;
    expect(billingTop, greaterThan(tops.first + 2));
  });

  testWidgets('categories can be added and renamed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ExpenseCategoriesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Misc'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Enter a category name.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Travel');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Misc'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Office');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Misc'), findsNothing);
  });
}
