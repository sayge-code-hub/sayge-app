import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_session.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
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
import 'features/hrms/data/datasources/employee_remote_datasource.dart';
import 'features/hrms/data/repositories/employee_repository_impl.dart';
import 'features/hrms/domain/repositories/employee_repository.dart';
import 'features/hrms/domain/usecases/add_employee.dart';
import 'features/hrms/domain/usecases/get_employees.dart';
import 'features/hrms/domain/usecases/update_employee.dart';
import 'features/hrms/presentation/bloc/add_employee/add_employee_bloc.dart';
import 'features/hrms/presentation/bloc/employees/employees_bloc.dart';
import 'features/payroll/presentation/bloc/payroll_bloc.dart';
import 'features/settings/data/datasources/client_remote_datasource.dart';
import 'features/settings/data/repositories/client_repository_impl.dart';
import 'features/settings/domain/repositories/client_repository.dart';
import 'features/settings/domain/usecases/add_client.dart';
import 'features/settings/domain/usecases/get_clients.dart';
import 'features/settings/presentation/bloc/clients/clients_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  await dotenv.load(fileName: '.env');

  if (!AppConfig.hasSupabase) {
    throw StateError(
      'Supabase is required. Copy .env.example to .env and set '
      'SUPABASE_URL and SUPABASE_ANON_KEY.',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  sl.registerLazySingleton(() => AuthSession());

  sl.registerFactory(() => LoginBloc(loginUseCase: sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );

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

  sl.registerFactory(() => PayrollBloc(getEmployeesUseCase: sl()));

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
