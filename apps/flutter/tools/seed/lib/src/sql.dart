import 'dart:convert';

/// SQL literal helpers. Values are inlined (psql takes the script on stdin, no
/// parameters), so every string goes through [lit]. `standard_conforming_strings`
/// is on by default, so backslashes inside JSON stay literal.
String lit(String value) => "'${value.replaceAll("'", "''")}'";

String jsonb(Object? value) => '${lit(jsonEncode(value))}::jsonb';

/// For `json` (not `jsonb`) columns such as `workflow.variables` and `environment.variables`.
String json(Object? value) => '${lit(jsonEncode(value))}::json';

String boolean({required bool value}) => value ? 'true' : 'false';

String idList(Iterable<String> ids) => ids.map(lit).join(', ');

/// `insert into <table> (<cols>) values (<row>), (<row>) ...`.
String insert(String table, List<String> columns, List<List<String>> rows) {
  final values = rows.map((r) => '  (${r.join(', ')})').join(',\n');
  return 'insert into $table (${columns.join(', ')}) values\n$values;';
}
