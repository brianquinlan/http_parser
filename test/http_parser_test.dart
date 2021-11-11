// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:async';

void main() {
  group('parse', () {
    test('parses the example date', () async {
      final parser = HttpParser.responseParser();
      final b = [File('test/plain_response').readAsBytesSync()];
      parser.listenToStream(Stream.fromIterable(b));
      final Completer<Object?> c = Completer();
      StreamSubscription? s;
      int? statusCode;
      s = parser.listen((incoming) {
        statusCode = incoming.statusCode;
        expect(statusCode, equals(200));
        s!.pause();
        expect(statusCode, equals(200));
        if (incoming.statusCode == 200) {
          print(incoming.headers);
          incoming.listen((data) {
            print(new String.fromCharCodes(data));
          });
        }
        c.complete();
//        s!.resume();
      }, onError: (dynamic error, StackTrace stackTrace) {
        c.complete(error);
      }, onDone: () {
        c.complete(555);
      });
      final d = await c.future;
//      expect(d, equals(555));
      expect(statusCode, equals(200));
    });
  });
}
