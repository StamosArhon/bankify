import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl_standalone.dart';
import 'package:logging/logging.dart';

import 'package:timezone/data/latest.dart' as tz;

import 'package:bankify/app.dart';
import 'package:bankify/log_privacy.dart';

void main() async {
  Logger.root.level = computeRootLogLevel(debugLoggingEnabled: false);
  Logger.root.onRecord.listen((LogRecord record) {
    developer.log(
      sanitizeLogText(record.message),
      time: record.time,
      sequenceNumber: record.sequenceNumber,
      level: record.level.value,
      name: record.loggerName,
      zone: record.zone,
      error: sanitizeLogObject(record.error),
      stackTrace: sanitizeLogStackTrace(record.stackTrace),
    );
  });
  tz.initializeTimeZones();
  Intl.defaultLocale = await findSystemLocale();
  await initializeDateFormatting();
  return runApp(const BankifyApp());
}
