import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/datasources/admin_shop_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/coffee_shop_remote_datasource.dart';
import 'data/datasources/comment_remote_datasource.dart';
import 'data/datasources/location_local_datasource.dart';
import 'data/repositories/admin_shop_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/coffee_shop_repository_impl.dart';
import 'data/repositories/comment_repository_impl.dart';
import 'data/repositories/commerce_repository_impl.dart';
import 'data/repositories/social_repository_impl.dart';
import 'data/services/street_pass_billing.dart';
import 'data/repositories/location_repository_impl.dart';
import 'domain/repositories/admin_shop_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/coffee_shop_repository.dart';
import 'domain/repositories/comment_repository.dart';
import 'domain/repositories/commerce_repository.dart';
import 'domain/repositories/social_repository.dart';
import 'domain/repositories/location_repository.dart';
import 'domain/usecases/coffee_shop_usecases.dart';
import 'domain/usecases/location_usecases.dart';
import 'presentation/blocs/admin/admin_bloc.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/comment/comment_bloc.dart';
import 'presentation/blocs/detail/detail_bloc.dart';
import 'presentation/blocs/explore/explore_bloc.dart';
import 'presentation/blocs/location/location_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  sl.registerLazySingleton<FirebaseDatabase>(() => FirebaseDatabase.instance);
  sl.registerLazySingleton<FirebaseFunctions>(
      () => FirebaseFunctions.instanceFor(region: 'asia-southeast2'));

  // google_sign_in hanya untuk signOut
  final googleSignIn = GoogleSignIn.instance;
  await googleSignIn.initialize();
  sl.registerLazySingleton<GoogleSignIn>(() => googleSignIn);

  sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), googleSignIn: sl()),
  );
  sl.registerLazySingleton<CoffeeShopRemoteDataSource>(
        () => CoffeeShopRemoteDataSourceImpl(firestore: sl()),
  );
  sl.registerLazySingleton<LocationLocalDataSource>(
        () => LocationLocalDataSourceImpl(prefs: sl()),
  );
  sl.registerLazySingleton<CommentRemoteDataSource>(
        () => CommentRemoteDataSourceImpl(firestore: sl(), rtdb: sl()),
  );
  sl.registerLazySingleton<AdminShopDataSource>(
        () => AdminShopDataSourceImpl(firestore: sl(), storage: sl(), rtdb: sl()),
  );

  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<CoffeeShopRepository>(
        () => CoffeeShopRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<LocationRepository>(
        () => LocationRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<CommentRepository>(
        () => CommentRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<AdminShopRepository>(
        () => AdminShopRepositoryImpl(dataSource: sl()),
  );

  sl.registerLazySingleton<SocialRepository>(
        () => SocialRepositoryImpl(firestore: sl(), storage: sl()),
  );
  sl.registerLazySingleton<CommerceRepository>(
        () => CommerceRepositoryImpl(firestore: sl(), functions: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<StreetPassBilling>(
        () => StreetPassBilling(functions: sl())..start(),
  );

  sl.registerLazySingleton(() => GetNearbyShops(sl()));
  sl.registerLazySingleton(() => GetFeaturedShops(sl()));
  sl.registerLazySingleton(() => GetShopById(sl()));
  sl.registerLazySingleton(() => SearchShops(sl()));
  sl.registerLazySingleton(() => GetCurrentLocation(sl()));
  sl.registerLazySingleton(() => GetLastSavedLocation(sl()));

  sl.registerLazySingleton(
        () => AuthBloc(authRepository: sl())..add(AuthStarted()),
  );
  sl.registerFactory(() => ExploreBloc(getNearbyShops: sl(), searchShops: sl()));
  sl.registerFactory(() => DetailBloc(getShopById: sl()));
  sl.registerFactory(() => LocationBloc(
    getCurrentLocation: sl(),
    getLastSavedLocation: sl(),
  ));
  sl.registerFactory(() => CommentBloc(repository: sl()));
  sl.registerFactory(() => AdminBloc(repository: sl()));
}