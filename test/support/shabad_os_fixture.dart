import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rows cut from the real Shabad OS database: every Gurmukhi line on Ang 668
/// and Ang 877, and the meanings of the shabads R5B (Ang 668) and XQM (Ang
/// 877). The tables and columns are the database's own.
final shabadOsFixture = jsonDecode(
  File('test/fixtures/shabad_os_sample.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Rows cut the same way for 7 November 2026: every Gurmukhi line on Ang 946
/// (pauris 69 to 73 of Sidh Gosht) and the title lines at the start of the
/// bani Sidh Gosht, on Ang 938, with the bani rows.
final shabadOsSidhGosht = jsonDecode(
  File('test/fixtures/shabad_os_sidh_gosht.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The rows of one table of [fixture], none when it has no such table.
List<Map<String, dynamic>> shabadOsRows(
  String table, [
  Map<String, dynamic>? fixture,
]) =>
    ((fixture ?? shabadOsFixture)[table] as List? ?? const [])
        .cast<Map<String, dynamic>>();

/// Whether the `sqlite3` command line tool runs here. The tests that read a
/// database need it.
bool get hasSqlite {
  try {
    return Process.runSync('sqlite3', ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

String _sql(Object? value) {
  if (value == null) return 'NULL';
  if (value is num) return '$value';
  return "'${(value as String).replaceAll("'", "''")}'";
}

/// A small SQLite file in [dir], with the tables and columns of the real
/// database and the rows of [fixture], [shabadOsFixture] by default.
File buildShabadOsDatabase(Directory dir, {Map<String, dynamic>? fixture}) {
  final file = File('${dir.path}/master.sqlite');
  final sql = StringBuffer('''
CREATE TABLE asset_lines (asset_id text, line_id text, type text, data text, additional text, priority integer);
CREATE TABLE authors (id text PRIMARY KEY NOT NULL, name text, other_names text);
CREATE TABLE line_groups (id text PRIMARY KEY NOT NULL, author_id text, section_id text, section_order integer);
CREATE TABLE lines (id text PRIMARY KEY NOT NULL, line_group_id text, line_group_order integer);
CREATE TABLE sections (id text PRIMARY KEY NOT NULL, source_id text, source_order integer, name text, description text);
CREATE TABLE banis (id text PRIMARY KEY NOT NULL, name text);
CREATE TABLE bani_lines (bani_id text, line_id text, section_order integer, line_order integer);
BEGIN;
''');
  for (final table in [
    'authors',
    'line_groups',
    'lines',
    'sections',
    'asset_lines',
    'banis',
    'bani_lines',
  ]) {
    for (final row in shabadOsRows(table, fixture)) {
      final names = row.keys.join(', ');
      final values = row.values.map(_sql).join(', ');
      sql.writeln('INSERT INTO $table ($names) VALUES ($values);');
    }
  }
  sql.writeln('COMMIT;');
  final script = File('${dir.path}/build.sql')
    ..writeAsStringSync(sql.toString());
  final result = Process.runSync('sqlite3', [
    file.path,
    '.read ${script.path}',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return file;
}
