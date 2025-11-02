// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: avoid_print
// generated

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:csv/csv.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('export')
    ..addCommand('import');

  parser.commands['export']!
    ..addOption(
      'source-arb',
      defaultsTo: 'lib/l10n/intl_en_CA.arb',
      help: 'Path to the source ARB file to export from.',
    )
    ..addOption(
      'csv-file',
      defaultsTo: 'scripts/translations.csv',
      help: 'Path to the master CSV file to create or update.',
    );

  parser.commands['import']!
    ..addOption('csv-file', defaultsTo: 'scripts/translations.csv', help: 'Path to the master CSV file to import from.')
    ..addOption('l10n-dir', defaultsTo: 'lib/l10n', help: 'Path to the l10n directory to output new ARB files.')
    ..addOption(
      'source-lang',
      defaultsTo: 'en',
      help: 'The source language to exclude from import (e.g., "en", "en_CA").',
    );

  try {
    final results = parser.parse(arguments);

    if (results.command == null) {
      print('Usage: dart translate.dart <command> [arguments]');
      print('\nAvailable commands:');
      print('  export    Export strings from a source ARB file to a CSV');
      print('  import    Import translations from a CSV file and generate new ARB files');
      exit(1);
    }

    switch (results.command!.name) {
      case 'export':
        runExport(results.command!);
        break;
      case 'import':
        runImport(results.command!);
        break;
    }
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

void runExport(ArgResults args) {
  print('--- Running Export ---');
  final sourceArbPath = args['source-arb'] as String;
  final csvPath = args['csv-file'] as String;

  print('Loading source ARB: $sourceArbPath');
  final sourceData = loadJsonFile(sourceArbPath);
  if (sourceData.isEmpty) {
    print('Error: Source ARB file is empty or not found: $sourceArbPath');
    exit(1);
  }

  // Parse locale from source ARB filename
  final filename = sourceArbPath.split('/').last;
  final namePart = filename.split('.').first;
  final localeParts = namePart.split('_');
  if (localeParts.length < 2) {
    print('Error: Could not parse locale from filename: $filename');
    print('Expected format: intl_LOCALE.arb (e.g., intl_en.arb, intl_en_CA.arb)');
    exit(1);
  }

  final sourceLocale = localeParts.sublist(1).join('_');
  print('Detected source locale: $sourceLocale');

  print('Loading existing CSV (if any): $csvPath');
  final (existingCsvData, existingHeaders) = loadCsvFile(csvPath);
  final existingDataMap = {for (final row in existingCsvData) row['id']!: row};

  // Define the new CSV headers
  final newHeaders = ['id', 'description', sourceLocale];
  for (final header in existingHeaders) {
    if (!newHeaders.contains(header)) {
      newHeaders.add(header);
    }
  }

  final newCsvData = <Map<String, String>>[];
  final sourceKeys = sourceData.keys.where((key) => !key.startsWith('@')).toList();

  print('Processing ${sourceKeys.length} keys from source ARB...');

  for (final key in sourceKeys) {
    final sourceText = sourceData[key].toString();
    final metadata = sourceData['@$key'];
    final description = metadata is Map ? (metadata['description']?.toString() ?? '') : '';

    var row = <String, String>{};
    // If key already exists in CSV, start with that to preserve translations
    if (existingDataMap.containsKey(key)) {
      row = Map.from(existingDataMap[key]!);
    }

    // Update/set the core data from the ARB
    row['id'] = key;
    row['description'] = description;
    row[sourceLocale] = sourceText;

    newCsvData.add(row);
  }

  print('Saving ${newCsvData.length} rows to CSV: $csvPath');
  saveCsvFile(csvPath, newHeaders, newCsvData);
  print('--- Export Complete ---');
}

void runImport(ArgResults args) {
  print('--- Running Import ---');
  final csvPath = args['csv-file'] as String;
  final l10nDir = args['l10n-dir'] as String;
  final sourceLang = args['source-lang'] as String;

  print('Loading CSV: $csvPath');
  final (data, headers) = loadCsvFile(csvPath);
  if (data.isEmpty) {
    print('Error: CSV file is empty or not found: $csvPath');
    exit(1);
  }

  // Identify target language columns
  final sourceLangLower = sourceLang.toLowerCase();
  final langCols = headers.where((h) => !['id', 'description', sourceLangLower].contains(h.toLowerCase())).toList();

  if (langCols.isEmpty) {
    print('Warning: No target language columns found in CSV (e.g., "fr", "ru_RU"). No files generated.');
    return;
  }

  print('Found target languages: ${langCols.join(", ")}');

  for (final lang in langCols) {
    final targetArbData = <String, dynamic>{};
    targetArbData['@@locale'] = lang;

    var stringsImported = 0;
    for (final row in data) {
      final key = row['id'];
      final translatedText = row[lang];

      // Only add the string if a translation exists for this language
      if (translatedText != null && translatedText.isNotEmpty) {
        targetArbData[key!] = translatedText;
        // Also add the metadata (description) for context
        targetArbData['@$key'] = {'description': row['description'] ?? ''};
        stringsImported++;
      }
    }

    if (stringsImported > 0) {
      final targetFilePath = '$l10nDir/intl_$lang.arb';
      print('Saving $stringsImported strings to: $targetFilePath');
      saveJsonFile(targetFilePath, targetArbData);
    } else {
      print('Skipping $lang: No translations found in CSV.');
    }
  }

  print('--- Import Complete ---');
}

Map<String, dynamic> loadJsonFile(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return {};
  }
  try {
    final content = file.readAsStringSync();
    return json.decode(content) as Map<String, dynamic>;
  } catch (e) {
    print('Warning: Could not decode JSON from $filePath. Starting fresh.');
    return {};
  }
}

void saveJsonFile(String filePath, Map<String, dynamic> data) {
  final file = File(filePath);
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(data));
}

(List<Map<String, String>>, List<String>) loadCsvFile(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return ([], []);
  }
  try {
    final content = file.readAsStringSync();
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) {
      return ([], []);
    }

    final headers = rows.first.map((e) => e.toString()).toList();
    final data = <Map<String, String>>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j].toString();
      }
      data.add(map);
    }

    return (data, headers);
  } catch (e) {
    print('Warning: Could not read CSV $filePath. Error: $e');
    return ([], []);
  }
}

void saveCsvFile(String filePath, List<String> headers, List<Map<String, String>> data) {
  try {
    final rows = <List<String>>[headers];
    for (final map in data) {
      final row = headers.map((h) => map[h] ?? '').toList();
      rows.add(row);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    file.writeAsStringSync(csv);
  } catch (e) {
    print('Error: Could not write CSV $filePath. Error: $e');
    exit(1);
  }
}
