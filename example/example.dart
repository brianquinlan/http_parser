// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http_parser/http_parser.dart';

Future<void> main() async {
  final date = DateTime.utc(2014, 9, 9, 9, 9, 9);
  print(date); // 2014-09-09 09:09:09.000Z

  final httpDateFormatted = formatHttpDate(date);
  print(httpDateFormatted); // Tue, 09 Sep 2014 09:09:09 GMT

  final nowParsed = parseHttpDate(httpDateFormatted);
  print(nowParsed); // 2014-09-09 09:09:09.000Z

  final socket = await Socket.connect("example.com", 80);
  socket.write("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n");
  await socket.flush();

  StreamSubscription<ParsedHttpResponse>? subscription;
  subscription = parseHttpResponseStream(socket).listen((final response) {
    response.drain();
    if (response.statusCode != 200) {
      print("Bad response: ${response.statusCode} ${response.reasonPhrase}");
    }
    socket.close();
    subscription!.cancel();
  });
  await subscription.asFuture();
}
