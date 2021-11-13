// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http_parser;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'http_date.dart';

part '_http_parser_impl.dart';
part '_http_headers.dart';
part '_http_incoming.dart';

class ParsedHttpRequest extends Stream<Uint8List> {
  final _HttpIncoming _incoming;

  ParsedHttpRequest(this._incoming);

  String get method => _incoming.method as String;
  Uri? get uri => _incoming.uri;
  HttpHeaders get headers => _incoming.headers;

  @override
  StreamSubscription<Uint8List> listen(void onData(Uint8List event)?,
          {Function? onError, void onDone()?, bool? cancelOnError}) =>
      _incoming.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

class ParsedHttpResponse extends Stream<Uint8List> {
  final _HttpIncoming _incoming;

  ParsedHttpResponse(this._incoming);

  int get statusCode => _incoming.statusCode as int;
  String get reasonPhrase => _incoming.reasonPhrase as String;
  HttpHeaders get headers => _incoming.headers;

  @override
  StreamSubscription<Uint8List> listen(void onData(Uint8List event)?,
          {Function? onError, void onDone()?, bool? cancelOnError}) =>
      _incoming.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

Stream<ParsedHttpRequest> parseHttpRequestStream(Stream<Uint8List> data) {
  final parser = _HttpParser.requestParser();
  parser.listenToStream(data);

  final controller = StreamController<ParsedHttpRequest>();
  StreamSubscription? s;
  s = parser.listen((incoming) {
    s!.pause();
    controller.add(ParsedHttpRequest(incoming));
    s.resume();
  }, onError: controller.addError, onDone: controller.close);
  return controller.stream;
}

Stream<ParsedHttpResponse> parseHttpResponseStream(Stream<Uint8List> data) {
  final parser = _HttpParser.responseParser();
  parser.listenToStream(data);

  final controller = StreamController<ParsedHttpResponse>();
  StreamSubscription? s;
  s = parser.listen((incoming) {
    s!.pause();
    // TODO(bquinlan): Handle status 100!
    controller.add(ParsedHttpResponse(incoming));
  }, onError: controller.addError, onDone: controller.close);
  return controller.stream;
}
