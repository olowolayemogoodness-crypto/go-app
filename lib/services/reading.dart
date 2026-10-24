import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

class Book {
  final String id, title, file;
  int pages, lastPage;
  Set<int> counted;
  Book({required this.id, required this.title, required this.file, required this.pages, this.lastPage = 1, Set<int>? counted})
      : counted = counted ?? {};

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'file': file, 'pages': pages, 'lastPage': lastPage, 'counted': counted.toList()};

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: '${j['id']}',
        title: '${j['title']}',
        file: '${j['file']}',
        pages: (j['pages'] as num?)?.toInt() ?? 0,
        lastPage: (j['lastPage'] as num?)?.toInt() ?? 1,
        counted: {for (final x in (j['counted'] as List? ?? const [])) (x as num).toInt()},
      );
}

/// Local PDF library plus honest page counting. PDFs stay on the phone;
/// only the number of pages read each day goes to Firestore.
class Reading {
  static const _key = 'books_v1';
  static const minSeconds = 12; // a page counts after this much real, active time on it
  static const idleSeconds = 60; // no touch for this long pauses the timer
  static const dailyCap = 150;

  static Future<Directory> _dir() async {
    final d = await getApplicationDocumentsDirectory();
    final b = Directory('${d.path}/books');
    if (!await b.exists()) await b.create(recursive: true);
    return b;
  }

  static Future<String> pathOf(Book b) async => '${(await _dir()).path}/${b.file}';

  static Future<List<Book>> library() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return [];
      return [for (final j in jsonDecode(raw) as List) Book.fromJson(Map<String, dynamic>.from(j as Map))];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<Book> l) async {
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final b in l) b.toJson()]));
  }

  static Future<Book> add(String src, String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final file = '$id.pdf';
    final dest = '${(await _dir()).path}/$file';
    await File(src).copy(dest);
    final doc = await PdfDocument.openFile(dest);
    final n = doc.pagesCount;
    await doc.close();
    final title = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final b = Book(id: id, title: title, file: file, pages: n);
    final l = await library();
    l.insert(0, b);
    await _write(l);
    return b;
  }

  static Future<void> update(Book b) async {
    final l = await library();
    final i = l.indexWhere((x) => x.id == b.id);
    if (i >= 0) l[i] = b;
    await _write(l);
  }

  static Future<void> remove(Book b) async {
    final l = await library();
    l.removeWhere((x) => x.id == b.id);
    await _write(l);
    try {
      final f = File(await pathOf(b));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static String dayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static DocumentReference<Map<String, dynamic>>? _today() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.doc('users/$uid/reading/${dayKey()}');
  }

  /// Pages credited today, live.
  static Stream<int> pagesToday() {
    final r = _today();
    if (r == null) return Stream.value(0);
    return r.snapshots().map((s) => (s.data()?['pages'] as num?)?.toInt() ?? 0);
  }

  /// Credits one verified page. Returns today's total.
  static Future<int> credit(Book b, int page) async {
    b.counted.add(page);
    b.lastPage = page;
    await update(b);
    final r = _today();
    if (r == null) return 0;
    try {
      final cur = ((await r.get()).data()?['pages'] as num?)?.toInt() ?? 0;
      if (cur >= dailyCap) return cur;
      await r.set({'pages': FieldValue.increment(1), 'updatedAtMs': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));
      final n = cur + 1;
      await Api.completeReadingToday(n);
      return n;
    } catch (e) {
      debugPrint('Credit failed: $e');
      return 0;
    }
  }
}
