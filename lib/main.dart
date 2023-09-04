import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '匿名加工 項目精査用',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String statusMessage = '';
  TextEditingController folderPathController = TextEditingController();
  TextEditingController outputPathController = TextEditingController();
  TextEditingController topCountController = TextEditingController();
  TextEditingController worstCountController = TextEditingController();
  TextEditingController minCountController = TextEditingController(); // 追加: 最小出現回数の入力フィールド

  Future<void> processCSVFiles(String folderPath, String outputPath, int topCount, int worstCount, int minCount) async {
    setState(() {
      statusMessage = 'Processing...';
    });

    List<FileSystemEntity> files = Directory(folderPath).listSync();

    for (FileSystemEntity file in files) {
      if (file is File && file.path.toLowerCase().endsWith('.csv')) {
        String filePath = file.path;
        await processSingleCSVFile(filePath, outputPath, topCount, worstCount, minCount);
      }
    }

    setState(() {
      statusMessage = 'Processing completed.';
    });
  }

  Future<void> processSingleCSVFile(String filePath, String outputPath, int topCount, int worstCount, int minCount) async {
    List<List<dynamic>> data = await File(filePath).openRead().transform(utf8.decoder).transform(CsvToListConverter()).toList();

    Map<String, Map<String, int>> columnCounts = {};
    Map<String, Set<String>> uniqueValues = {};

    for (var header in data[0]) {
      columnCounts[header] = {};
      uniqueValues[header] = Set<String>();
    }

    int processedRowCount = 0;

    for (var row in data.sublist(1)) {
      for (int column_index = 0; column_index < row.length; column_index++) {
        var column_header = data[0][column_index];
        var value = row[column_index].toString();
        columnCounts[column_header]?[value] = (columnCounts[column_header]?[value] ?? 0) + 1;

        uniqueValues[column_header]?.add(value);
      }

      processedRowCount++;

      if (processedRowCount % 10000 == 0) {
        setState(() {
          statusMessage = 'Processing: $filePath, Processed rows: $processedRowCount';
        });
        await Future.delayed(Duration(milliseconds: 1));
      }
    }

    String inputFileName = File(filePath).uri.pathSegments.last;
    String outputFileName = '${inputFileName.substring(0, inputFileName.length - 4)}□_${data[0].length}_columns_${processedRowCount}_rows.txt';
    String outputFilePath = '$outputPath/$outputFileName';

    File outputFile = File(outputFilePath);
    await outputFile.writeAsString('Processed data for file: ${File(filePath).uri.pathSegments.last}\n\n');
    var sortedColumnCounts = columnCounts.entries.toList()..sort((a, b) => b.value.values.reduce((a, b) => a + b).compareTo(a.value.values.reduce((a, b) => a + b)));
    for (var columnCount in sortedColumnCounts) {
      await outputFile.writeAsString('Column #${data[0].indexOf(columnCount.key) + 1}: ${columnCount.key}\n', mode: FileMode.append);
      var counts = columnCount.value;
      var sortedCounts = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      // トップとワーストの個数を出力
      for (var i = 0; i < sortedCounts.length; i++) {
        if (i < topCount || sortedCounts.length - i <= worstCount) {
          // 最小出現回数の指定があり、それを下回る場合は出力しない
          if (sortedCounts[i].value >= minCount) {
            await outputFile.writeAsString('  ${i + 1}. ${sortedCounts[i].key}: ${sortedCounts[i].value} times\n', mode: FileMode.append);
          }
        }
      }

      // ユニークな値の数を出力
      await outputFile.writeAsString('  Unique Values: ${uniqueValues[columnCount.key]?.length ?? 0}\n\n', mode: FileMode.append);
    }

    await Future.delayed(Duration(milliseconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('匿名加工 項目精査用(仮)ver2'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: folderPathController,
              decoration: InputDecoration(labelText: 'Folder Path'),
            ),
            TextField(
              controller: outputPathController,
              decoration: InputDecoration(labelText: 'Output Path'),
            ),
            TextField(
              controller: topCountController,
              decoration: InputDecoration(labelText: '上位何位まで出す？'),
            ),
            TextField(
              controller: worstCountController,
              decoration: InputDecoration(labelText: '下位何位まで出す？'),
            ),
            TextField(
              controller: minCountController, // 追加: 最小出現回数の入力フィールド
              decoration: InputDecoration(labelText: 'これ以上なら出力'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                int topCount = int.tryParse(topCountController.text) ?? 3;
                int worstCount = int.tryParse(worstCountController.text) ?? 3;
                int minCount = int.tryParse(minCountController.text) ?? 0; // 追加: デフォルトは0
                processCSVFiles(folderPathController.text, outputPathController.text, topCount, worstCount, minCount);
              },
              child: Text('処理開始'),
            ),
            SizedBox(height: 20),
            Text(
              statusMessage,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
