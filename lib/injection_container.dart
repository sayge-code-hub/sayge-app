import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'core/auth/auth_local_storage.dart';
import 'core/auth/auth_session.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/entities/user.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/dms/data/datasources/document_remote_datasource.dart';
import 'features/dms/data/repositories/document_repository_impl.dart';
import 'features/dms/domain/repositories/document_repository.dart';
import 'features/dms/domain/usecases/add_document.dart';
import 'features/dms/domain/usecases/get_dms_entities.dart';
import 'features/dms/domain/usecases/get_documents.dart';
import 'features/dms/presentation/bloc/dms/dms_bloc.dart';
import 'features/expenses/data/datasources/expense_remote_datasource.dart';
import 'features/expenses/data/repositories/expense_repository_impl.dart';
import 'features/expenses/domain/repositories/expense_repository.dart';
import 'features/expenses/domain/usecases/expense_usecases.dart';
import 'features/expenses/presentation/bloc/expenses_bloc.dart';
import 'features/hrms/data/datasources/employee_purchase_order_remote_datasource.dart';
import 'features/hrms/data/datasources/employee_remote_datasource.dart';
import 'features/hrms/data/repositories/employee_purchase_order_repository_impl.dart';
import 'features/hrms/data/repositories/employee_repository_impl.dart';
import 'features/hrms/domain/repositories/employee_purchase_order_repository.dart';
import 'features/hrms/domain/repositories/employee_repository.dart';
import 'features/hrms/domain/usecases/add_employee.dart';
import 'features/hrms/domain/usecases/employee_purchase_order_usecases.dart';
import 'features/hrms/domain/usecases/get_employees.dart';
import 'features/hrms/domain/usecases/update_employee.dart';
import 'features/hrms/presentation/bloc/add_employee/add_employee_bloc.dart';
import 'features/hrms/presentation/bloc/employee_po/employee_po_bloc.dart';
import 'features/hrms/presentation/bloc/employees/employees_bloc.dart';
import 'features/invoices/data/datasources/invoice_remote_datasource.dart';
import 'features/invoices/data/repositories/invoice_repository_impl.dart';
import 'features/invoices/domain/repositories/invoice_repository.dart';
import 'features/invoices/domain/usecases/invoice_usecases.dart';
import 'features/invoices/presentation/bloc/invoices_bloc.dart';
import 'features/payroll/presentation/bloc/payroll_bloc.dart';
import 'features/proposals/data/datasources/proposal_remote_datasource.dart';
import 'features/proposals/data/repositories/proposal_repository_impl.dart';
import 'features/proposals/domain/repositories/proposal_repository.dart';
import 'features/proposals/domain/usecases/proposal_usecases.dart';
import 'features/proposals/presentation/bloc/proposals_bloc.dart';
import 'features/settings/data/datasources/client_remote_datasource.dart';
import 'features/settings/data/datasources/invite_employee_remote_datasource.dart';
import 'features/settings/data/datasources/settings_remote_datasource.dart';
import 'features/settings/data/repositories/client_repository_impl.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/repositories/client_repository.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/domain/usecases/add_client.dart';
import 'features/settings/domain/usecases/get_clients.dart';
import 'features/settings/domain/usecases/settings_usecases.dart';
import 'features/settings/presentation/bloc/clients/clients_bloc.dart';
import 'features/settings/presentation/bloc/company_details/company_details_bloc.dart';
import 'features/settings/presentation/bloc/ledger/ledger_bloc.dart';
import 'features/settings/presentation/bloc/roles/roles_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  await dotenv.load(fileName: 'assets/config/app.env');

  if (!AppConfig.hasSupabase) {
    throw StateError(
      'Supabase is required. Set SUPABASE_URL and SUPABASE_ANON_KEY in '
      'assets/config/app.env.',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final authStorage = AuthLocalStorage(prefs);
  sl.registerLazySingleton<AuthLocalStorage>(() => authStorage);

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );

  final restoredUser = await _restoreAuthUser(
    storage: authStorage,
    remote: sl<AuthRemoteDataSource>(),
  );
  sl.registerLazySingleton(
    () => AuthSession(storage: authStorage, initialUser: restoredUser),
  );

  sl.registerFactory(() => LoginBloc(loginUseCase: sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));

  sl.registerFactory(
    () => ClientsBloc(
      getClientsUseCase: sl(),
      addClientUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetClientsUseCase(sl()));
  sl.registerLazySingleton(() => AddClientUseCase(sl()));
  sl.registerLazySingleton<ClientRemoteDataSource>(
    () => ClientRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ClientRepository>(
    () => ClientRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<SettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetCompanyDetailsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCompanyDetailsUseCase(sl()));
  sl.registerLazySingleton(() => GetRolesUseCase(sl()));
  sl.registerLazySingleton(() => GetActivityLogUseCase(sl()));
  sl.registerLazySingleton(() => InviteEmployeeRemoteDataSource());
  sl.registerFactory(
    () => CompanyDetailsBloc(
      getCompanyDetailsUseCase: sl(),
      updateCompanyDetailsUseCase: sl(),
    ),
  );
  sl.registerFactory(() => RolesBloc(getRolesUseCase: sl()));
  sl.registerFactory(() => LedgerBloc(getActivityLogUseCase: sl()));

  sl.registerFactory(() => EmployeesBloc(getEmployeesUseCase: sl()));
  sl.registerFactory(
    () => AddEmployeeBloc(
      addEmployeeUseCase: sl(),
      updateEmployeeUseCase: sl(),
      getClientsUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetEmployeesUseCase(sl()));
  sl.registerLazySingleton(() => AddEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateEmployeeUseCase(sl()));
  sl.registerLazySingleton<EmployeeRemoteDataSource>(
    () => EmployeeRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(
    () => EmployeePoBloc(
      getPosUseCase: sl(),
      createPoUseCase: sl(),
      getDownloadUrlUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetEmployeePurchaseOrdersUseCase(sl()));
  sl.registerLazySingleton(() => GetAllEmployeePurchaseOrdersUseCase(sl()));
  sl.registerLazySingleton(() => CreateEmployeePurchaseOrderUseCase(sl()));
  sl.registerLazySingleton(
    () => GetEmployeePurchaseOrderDownloadUrlUseCase(sl()),
  );
  sl.registerLazySingleton<EmployeePurchaseOrderRemoteDataSource>(
    () => EmployeePurchaseOrderRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<EmployeePurchaseOrderRepository>(
    () => EmployeePurchaseOrderRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(() => PayrollBloc(getEmployeesUseCase: sl()));

  sl.registerFactory(
    () => ExpensesBloc(
      getExpensesUseCase: sl(),
      addExpenseUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetExpensesUseCase(sl()));
  sl.registerLazySingleton(() => AddExpenseUseCase(sl()));
  sl.registerLazySingleton<ExpenseRemoteDataSource>(
    () => ExpenseRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(
    () => InvoicesBloc(
      getInvoicesUseCase: sl(),
      createInvoiceUseCase: sl(),
      updateInvoiceUseCase: sl(),
      getAllPosUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetInvoicesUseCase(sl()));
  sl.registerLazySingleton(() => CreateInvoiceUseCase(sl()));
  sl.registerLazySingleton(() => UpdateInvoiceUseCase(sl()));
  sl.registerLazySingleton<InvoiceRemoteDataSource>(
    () => InvoiceRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<InvoiceRepository>(
    () => InvoiceRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(
    () => ProposalsBloc(
      getProposalsUseCase: sl(),
      createProposalUseCase: sl(),
      updateProposalUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetProposalsUseCase(sl()));
  sl.registerLazySingleton(() => CreateProposalUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProposalUseCase(sl()));
  sl.registerLazySingleton<ProposalRemoteDataSource>(
    () => ProposalRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ProposalRepository>(
    () => ProposalRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerFactory(
    () => DmsBloc(
      getDmsEntitiesUseCase: sl(),
      getDocumentsUseCase: sl(),
      addDocumentUseCase: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetDmsEntitiesUseCase(sl()));
  sl.registerLazySingleton(() => GetDocumentsUseCase(sl()));
  sl.registerLazySingleton(() => AddDocumentUseCase(sl()));
  sl.registerLazySingleton<DocumentRemoteDataSource>(
    () => DocumentRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<DocumentRepository>(
    () => DocumentRepositoryImpl(remoteDataSource: sl()),
  );
}

/// Restores app user when Supabase still has a valid session.
Future<User?> _restoreAuthUser({
  required AuthLocalStorage storage,
  required AuthRemoteDataSource remote,
}) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    await storage.clear();
    return null;
  }

  final cached = storage.readUser();
  if (cached != null && cached.id == session.user.id) {
    return cached;
  }

  final fresh = await remote.restoreSession();
  if (fresh == null) {
    await storage.clear();
    return null;
  }
  await storage.saveUser(fresh);
  return fresh;
}
