// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http_parser;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http_parser/src/http_date.dart';

part '_http_parser_impl.dart';
part '_http_headers.dart';
part '_http_incoming.dart';

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
