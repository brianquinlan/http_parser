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
  group('request', () {
    test('GET, no body', () {
      const data = 'GET /foo/bar HTTP/1.0\r\n\r\n';

      final s = parseHttpRequestStream(stringToStream(data));
      s.listen((ParsedHttpRequest event) async {
        expect(event.method, equals('GET'));
        expect(event.uri, equals(Uri(path: "/foo/bar")));
        expect(await streamToString(event), equals(""));
      });
    });

    test('POST, text body', () {
      const data =
          'POST /foo/bar HTTP/1.1\r\nContent-Length: 10\r\n\r\n1234567890';

      final s = parseHttpRequestStream(stringToStream(data));
      s.listen((ParsedHttpRequest event) async {
        expect(event.method, equals('POST'));
        expect(event.uri, equals(Uri(path: "/foo/bar")));
        expect(event.headers.contentLength, equals(10));
        expect(event.headers.chunkedTransferEncoding, isFalse);
        expect(await streamToString(event), equals("1234567890"));
      });
    });
  });
  test('POST, chunked text', () async {
    const data = 'POST /foo/bar HTTP/1.1\r\n'
        'Transfer-Encoding: chunked\r\n'
        '\r\n'
        '5\r\n'
        'Hello\r\n'
        '1\r\n'
        ' \r\n'
        '6\r\n'
        'World!\r\n'
        '0\r\n'
        '\r\n';

    final s = parseHttpRequestStream(stringToStream(data));
    // Use this style everywhere.
    await for (final event in s) {
      expect(event.method, equals('POST'));
      expect(event.uri, equals(Uri(path: "/foo/bar")));
      expect(event.headers.contentLength, equals(-1));
      expect(event.headers.chunkedTransferEncoding, isTrue);
      expect(await streamToString(event), equals("Hello World!"));
    }
  });

  test('POST, keep alive and two requests', () async {
    const data = 'POST /foo/bar HTTP/1.1\r\n'
        'Connection: keep-alive\r\n'
        'Content-Length: 5\r\n'
        '\r\n'
        'Hello'
        'POST /foo/bar HTTP/1.1\r\n'
        'Connection: close\r\n'
        'Content-Length: 6\r\n'
        '\r\n'
        'World!';

    final s = parseHttpRequestStream(stringToStream(data));
    var i = 0;
    await for (final event in s) {
      expect(await streamToString(event),
          i++ == 0 ? equals("Hello") : equals("World!"));
    }
  });

  test('POST, keep alive and two requests but body not read', () async {
    const data = 'POST /foo/bar HTTP/1.1\r\n'
        'Connection: keep-alive\r\n'
        'Content-Length: 5\r\n'
        '\r\n'
        'Hello'
        'PUT /foo/bar HTTP/1.1\r\n'
        'Connection: close\r\n'
        'Content-Length: 6\r\n'
        '\r\n'
        'World!';

    final s = parseHttpRequestStream(stringToStream(data));
    await s
        .timeout(const Duration(seconds: 2))
        .listen((ParsedHttpRequest event) async {
      expect(event.method, equals("POST"));
    }).asFuture(); // Do this everywhere!
  });

  group('response', () {
    group('status line', () {
      test('HTTP 1.0', () async {
        const data = 'HTTP/1.0 200 OK\r\n\r\nTest';

        final s = parseHttpResponseStream(stringToStream(data));
        s.listen((ParsedHttpResponse event) {
          expect(event.statusCode, equals(200));
          expect(event.reasonPhrase, equals("OK"));
        });
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
  });
}
