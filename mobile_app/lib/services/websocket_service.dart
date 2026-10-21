import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/connection_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal() {
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
  }

  WebSocketChannel? _channel;
  late StreamController<Map<String, dynamic>> _messageController;
  ConnectionConfig? _currentConnection;
  String? _authToken;
  bool _isConnected = false;

  // Keep-alive / auto-reconnect state
  static const _pingEvery = Duration(seconds: 20);
  static const _maxBackoff = Duration(seconds: 30);
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  ConnectionConfig? _lastConfig;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;
  ConnectionConfig? get currentConnection => _currentConnection;

  Future<bool> connect(ConnectionConfig config) async {
    _manualDisconnect = false;
    _lastConfig = config;
    _reconnectAttempts = 0;
    return _connectOnce(config);
  }

  Future<bool> _connectOnce(ConnectionConfig config) async {
    try {
      _teardown();

      // Create WebSocket connection
      String wsUrl = config.serverUrl.replaceFirst('http', 'ws') + '/ws';
      
      // For web deployment, use the current host's IP with WebSocket port
      if (kIsWeb && wsUrl.contains('localhost')) {
        final currentHost = Uri.base.host;
        wsUrl = 'ws://$currentHost:64008/ws';
      }
      
      print('🔗 WebSocketService: Connecting to $wsUrl');
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      
      // Message controller is already created in constructor

      // Listen to incoming messages
      // Events from a replaced socket must not touch the new connection's state.
      channel.stream.listen(
        (data) {
          if (!identical(channel, _channel)) return;
          print('📨 WebSocketService: Raw data received: $data');
          try {
            final message = jsonDecode(data) as Map<String, dynamic>;
            print('🎯 WebSocketService: Parsed JSON: $message');
            _handleIncomingMessage(message);
          } catch (e) {
            print('❌ WebSocketService: Error parsing WebSocket message: $e');
            print('📄 WebSocketService: Raw data that failed: $data');
          }
        },
        onError: (error) {
          if (!identical(channel, _channel)) return;
          print('💥 WebSocketService: WebSocket error: $error');
          _handleConnectionError(error);
        },
        onDone: () {
          if (!identical(channel, _channel)) return;
          print('🔌 WebSocketService: WebSocket connection closed');
          _handleDisconnection();
        },
      );

      // Authenticate
      final authSuccess = await _authenticate(config.username, config.password);
      if (authSuccess) {
        _currentConnection = config.copyWith(isConnected: true);
        _isConnected = true;
        _reconnectAttempts = 0;
        _startPing();
        return true;
      } else {
        _teardown();
        return false;
      }
    } catch (e) {
      print('Connection failed: $e');
      _teardown();
      return false;
    }
  }

  Future<bool> _authenticate(String username, String password) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;

    // Listen for auth response
    subscription = _messageController.stream.listen((message) {
      print('Auth response received: $message'); // Debug log
      
      if (message['type'] == 'auth-success') {
        _authToken = message['token'];
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(true);
        }
      } else if (message['type'] == 'error' && !completer.isCompleted) {
        print('Auth error: ${message['message']}'); // Debug log
        subscription.cancel();
        completer.complete(false);
      }
    });

    // Wait a bit for WebSocket to be ready
    await Future.delayed(const Duration(milliseconds: 100));

    // Send auth request
    print('Sending auth request for user: $username'); // Debug log
    _sendMessage({
      'type': 'auth',
      'username': username,
      'password': password,
    });

    // Wait for response with timeout
    try {
      return await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Auth timeout: $e'); // Debug log
      subscription.cancel();
      return false;
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    print('🔍 WebSocketService: Raw message received: $message');
    
    // Add timestamp if not present
    message['receivedAt'] = DateTime.now().toIso8601String();
    
    print('🔄 WebSocketService: Forwarding message to AppState: $message');
    
    // Forward to listeners
    _messageController.add(message);
    
    print('✅ WebSocketService: Message forwarded successfully');
  }

  void _handleConnectionError(dynamic error) {
    _messageController.add({
      'type': 'error',
      'message': 'Connection error: $error',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _handleDisconnection() {
    _pingTimer?.cancel();
    final wasConnected = _isConnected;
    _isConnected = false;
    _currentConnection = _currentConnection?.copyWith(isConnected: false);
    _messageController.add({
      'type': 'system',
      'message': 'Disconnected from server',
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Only auto-reconnect a link that was established; failed first attempts
    // are reported to the caller of connect() instead.
    if (wasConnected) _scheduleReconnect();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingEvery, (_) => sendPing());
  }

  void _scheduleReconnect() {
    final config = _lastConfig;
    if (_manualDisconnect || config == null) return;
    _reconnectTimer?.cancel();

    final seconds = (1 << _reconnectAttempts.clamp(0, 5).toInt());
    final delay = Duration(seconds: seconds) > _maxBackoff
        ? _maxBackoff
        : Duration(seconds: seconds);
    _reconnectAttempts++;

    _messageController.add({
      'type': 'system',
      'message': 'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...',
      'timestamp': DateTime.now().toIso8601String(),
    });

    _reconnectTimer = Timer(delay, () async {
      if (_manualDisconnect) return;
      final ok = await _connectOnce(config);
      if (ok) {
        _messageController.add({
          'type': 'system',
          'message': 'Reconnected to server.',
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        _scheduleReconnect();
      }
    });
  }

  Future<void> sendCommand(String command) async {
    print('📤 WebSocketService: Sending command: "$command"');
    
    if (!_isConnected || _channel == null) {
      print('❌ WebSocketService: Cannot send command - not connected');
      throw Exception('Not connected to server');
    }

    final message = {
      'type': 'command',
      'command': command,
    };
    
    print('📋 WebSocketService: Command message: $message');
    _sendMessage(message);
  }

  Future<void> startClaudeSession() async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to server');
    }

    _sendMessage({
      'type': 'claude-start',
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null) return;
    
    try {
      final jsonString = jsonEncode(message);
      _channel!.sink.add(jsonString);
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void sendPing() {
    _sendMessage({
      'type': 'ping',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// User-initiated disconnect: stops keep-alive and auto-reconnect.
  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _teardown();
  }

  void _teardown() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    // Don't close the message controller to keep the stream alive for reconnections
    
    _channel = null;
    _authToken = null;
    _isConnected = false;
    _currentConnection = _currentConnection?.copyWith(isConnected: false);
  }

  // Health check
  Future<bool> checkHealth(String serverUrl) async {
    try {
      final response = await Future.delayed(
        const Duration(seconds: 5),
        () => throw TimeoutException('Health check timeout'),
      );
      return false; // Would implement actual HTTP health check
    } catch (e) {
      return false;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}