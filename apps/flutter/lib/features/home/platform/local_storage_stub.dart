import 'package:sim_app/features/home/platform/local_storage.dart';

final HomeLocalStorage _memory = MemoryHomeLocalStorage();

/// Desktop: no `localStorage` shared with React; preferences live for the
/// app session.
HomeLocalStorage createHomeLocalStorage() => _memory;
