import 'package:sim_api/src/storage/shared_web_state.dart';

/// Desktop has no `localStorage` shared with React: values stay in memory.
SharedWebState createSharedWebState() => MemorySharedWebState();
