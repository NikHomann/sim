import 'package:dio/dio.dart';

/// No `fetch` outside the browser: native platforms stream through
/// `IOHttpClientAdapter` already.
HttpClientAdapter? createFetchStreamAdapter() => null;
