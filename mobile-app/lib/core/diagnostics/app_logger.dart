import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  
  late final Logger _logger;
  File? _logFile;
  bool _initialized = false;

  AppLogger._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
    );
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app_diagnostics_logs.txt');
      
      // If log file exceeds 1MB, clear/rotate it to prevent consuming storage
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > 1024 * 1024) { // 1 MB
          await _logFile!.writeAsString('');
        }
      } else {
        await _logFile!.create(recursive: true);
      }
    } catch (e) {
      // Fallback silently to console-only logging if filesystem access fails
      print('Failed to initialize local file logger: $e');
    }

    _initialized = true;
  }

  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('DEBUG', message, error, stackTrace);
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('INFO', message, error, stackTrace);
  }

  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('WARNING', message, error, stackTrace);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _writeToLogFile('ERROR', message, error, stackTrace);
  }

  void _writeToLogFile(String level, String message, dynamic error, StackTrace? stackTrace) {
    if (_logFile == null) return;
    
    // In production we only write Warning and Error logs to the file on disk
    if (level != 'WARNING' && level != 'ERROR') return;

    final timestamp = DateTime.now().toIso8601String();
    var logLine = '[$timestamp] [$level] $message';
    if (error != null) {
      logLine += '\nError: $error';
    }
    if (stackTrace != null) {
      logLine += '\nStackTrace:\n$stackTrace';
    }
    logLine += '\n';

    // Append to file asynchronously
    _logFile!.writeAsString(logLine, mode: FileMode.append, flush: true).catchError((e) {
      print('Error writing to log file: $e');
    });
  }

  Future<File?> getLogFile() async {
    if (!_initialized) await init();
    return _logFile;
  }

  Future<void> clearLogs() async {
    if (!_initialized) await init();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}
