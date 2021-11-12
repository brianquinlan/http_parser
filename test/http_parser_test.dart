// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

Stream<Uint8List> stringToStream(String s) =>
    Stream.fromIterable([Uint8List.fromList(utf8.encode(s))]);

Future<String> streamToString(Stream<Uint8List> s) async =>
    String.fromCharCodes((await s.toList()).expand((i) => i));

Future<List<int>> streamToInts(Stream<Uint8List> s) async =>
    (await s.toList()).expand((i) => i).toList();

void main() {
  group('status line', () {
    test('HTTP 1.0', () async {
      const data = 'HTTP/1.0 200 OK\r\n\r\nTest';

      final s = parseHttpResponseStream(stringToStream(data));
      s.listen((ParsedHttpResponse event) {
        expect(event.statusCode, equals(200));
        expect(event.reasonPhrase, equals("OK"));
      });
      Future(() => null).onError((error, stackTrace) => null);
    });
    test('HTTP 1.1', () async {
      const data = 'HTTP/1.1 200 OK\r\n\r\nTest';

      final s = parseHttpResponseStream(stringToStream(data));
      s.listen((ParsedHttpResponse event) {
        expect(event.statusCode, equals(200));
        expect(event.reasonPhrase, equals("OK"));
      });
    });
    test('no http version', () async {
      const data = '200 OK\r\n\r\nTest';

      final s = parseHttpResponseStream(stringToStream(data));
      s.listen((ParsedHttpResponse event) {
        fail('expected parse failure, got $event');
      }, onError: (e) => expect(e, const TypeMatcher<HttpException>()));
    });
  });
  group('content', () {
    test('text content', () async {
      const data = 'HTTP/1.1 200 OK\r\n\r\nTest';

      final s = parseHttpResponseStream(stringToStream(data));
      s.listen((ParsedHttpResponse event) async {
        expect(event.statusCode, equals(200));
        expect(event.reasonPhrase, equals("OK"));
        expect(await streamToString(event), equals("Test"));
      });
    });

    test('binary content', () async {
      final data = [for (var i = 0; i < 256; i++) i];
      final response =
          Uint8List.fromList(utf8.encode('HTTP/1.1 200 OK\r\n\r\n') + data);

      final s = parseHttpResponseStream(Stream.fromIterable([response]));
      s.listen((ParsedHttpResponse event) async {
        expect(event.statusCode, equals(200));
        expect(event.reasonPhrase, equals("OK"));
        expect(await streamToInts(event), equals(data));
      });
    });
  });
}
