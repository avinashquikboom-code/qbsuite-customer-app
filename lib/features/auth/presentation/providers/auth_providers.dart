import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/session_store.dart';
import '../../data/api_auth_repository.dart';
import '../../data/auth_service.dart';
import '../../domain/auth_repository.dart';
import '../../domain/session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => ApiAuthRepository(AuthService(ref.watch(dioProvider)), ref.watch(sessionStoreProvider)));
// Subscriptions are disposed automatically when their provider is disposed.
final sessionEventsProvider = StreamProvider<Session?>((ref) => ref.watch(sessionStoreProvider).changes);
