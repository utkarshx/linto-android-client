import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:linto_flutter_client/client/mqttClientWrapper.dart';
import 'package:linto_flutter_client/logic/customtypes.dart';
import 'package:linto_flutter_client/client/apiroutes.dart';

class LinTOClient {

  final String APIROUTES = "/auths";
  final String APIAUTHSUFFIX = "/login";
  final String APISCOPES = "/scopes";
  final String APIPREFIX = "/overwatch";

  String _token;
  String _refreshToken;
  // TODO expiring time
  String _authServURI;
  String _selectedScope;
  String _login;
  String _password;
  String _mqttHost;
  String _mqttPort;
  String _mqttLogin;
  String _mqttPassword;
  bool _mqttUseLogin;
  String _subscribingTopic;
  String _publishingTopic;
  String _sessionID;

  List<dynamic>  _authRoutes;
  Map<String, dynamic> _authRoute;

  bool _authentificated = false;

  MQTTClientWrapper mqttClient;

  String get login {
    return _login;
  }

  String get server {
    return _authServURI;
  }

  String get currentScope {
    return _selectedScope;
  }

  bool get isConnected {
    return _authentificated;
  }

  set onMQTTMsg(MsgCallback cb) {
    mqttClient.onMessage = cb;
  }


  /// Retrieve last used login from config file
  Future<String> getLastUser() async {
    String content =  await rootBundle.loadString('assets/config/config.json');
    var data = json.decode(content);
    String lastlog = data['client']['last_login'];
    return lastlog;
  }
  /// Retrieve last used server from config file
  Future<String> getLastServer() async {
    String content =  await rootBundle.loadString('assets/config/config.json');
    var data = json.decode(content);
    String lastlog = data['client']['last_server'];
    return lastlog;
  }

  /// Ask server at [server] which authentication method are available.
  Future<List<dynamic>> requestRoutes(String server) async {
    Map<String, String> requestHeaders = {
      'Content-type': 'application/json',
      'Accept': 'application/json'};
    var response;
    try {
      response = await http.get("$server$APIPREFIX$APIROUTES",
          headers: requestHeaders).timeout(Duration(seconds: 5));
    } on TimeoutException catch (_) {
      throw ClientErrorException('0x0009');
    } on SocketException catch (_) {
      throw ClientErrorException('0x0010');
    }
    switch(response.statusCode) {
      case 200: {
        _authServURI = server;
        var routes;
        try {
          routes = jsonDecode(utf8.decode(response.body.runes.toList()));
        } on Exception catch(_) {
          throw ClientErrorException('0x0007');
        }
        _authRoutes = routes;
        return routes;
      }
      break;

      case 401: {
        throw ClientErrorException('0x0002');
      }
      break;

      case 404: {
        throw ClientErrorException('0x0008');
      }
      break;

      default: {
        throw ClientErrorException('0xFFFF');
      }
      break;
    }

  }

  void setAuthRoute(Map<String, dynamic> route) {
    _authRoute = route;
  }
  
  /// Ask authentification API at [authServURI]
  /// Return Future<List> containing the success as a boolean and a error message if the authentification failed
  Future<bool> requestAuthentification(String login, String password) async {
    print("Sending auth request at $_authServURI$APIPREFIX${_authRoute['basePath']}$APIAUTHSUFFIX : $login *******");
    Map<String, String> requestHeaders = {
      'Content-type': 'application/json',
      'Accept': 'application/json'};
    var response;
    try {
      response = await http.post("$_authServURI$APIPREFIX${_authRoute['basePath']}$APIAUTHSUFFIX",
          headers: requestHeaders,
          body: jsonEncode({"username": login, "password" : password})).timeout(Duration(seconds: 5));
    } on TimeoutException catch (_) {
      throw ClientErrorException('0x0009');
    } on SocketException catch (_) {
      throw ClientErrorException('0x0010');
    }
    print('Response status: ${response.statusCode}');
    switch(response.statusCode) {

      case 202: {
        try {
          print('Response status: ${response.statusCode}');
          print('Response body: ${response.body}');
          var res = json.decode(response.body);

          var userInfo = res["user"];
          _sessionID = userInfo["session_id"];
          _token = userInfo["auth_token"];
          _refreshToken = userInfo["refresh_token"];
          _sessionID = userInfo["session_id"];
          var mqttInfo = res["mqtt"];
          _mqttHost = mqttInfo["mqtt_host"];
          _mqttPort = mqttInfo["mqtt_port"];
          _mqttLogin = mqttInfo["mqtt_login"];
          _mqttPassword = mqttInfo["mqtt_password"];
          _mqttUseLogin = mqttInfo["mqtt_use_login"];

        } on Exception catch (_) {
          throw ClientErrorException('0x0007');
        }
        _login = login;
        _password = password;
        return true;
      }
      break;

      case 401: {
        throw ClientErrorException('0x0002');
      }
      break;

      case 404: {
        throw ClientErrorException('0x0008');
      }
      break;

      default: {
        throw ClientErrorException('0xFFFF');
      }
      break;
    }
  }

  /// Request scopes from the server
  /// Throws [ClientErrorException] if an error is encountered.
  Future<Map<String, dynamic>> requestScopes() async {
    print("Requesting scopes from server ...");
    Map<String, String> requestHeaders = { 'Content-type': 'application/json', 'Accept': 'application/json', 'Authorization' : 'Token $_token'  };
    var response;
    try {
      response = await http.get("$_authServURI$APIPREFIX${_authRoute['basePath']}$APISCOPES", headers: requestHeaders);
    } on TimeoutException catch (_) {
      throw ClientErrorException('0x0009');
    } on SocketException catch (_) {
      throw ClientErrorException('0x0010');
    }
    switch(response.statusCode) {
      case 200: {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        Map<String, dynamic> res = json.decode(response.body);
        if (! res.keys.contains('scopes')) {
          throw ClientErrorException('0x0007');
        }
        return res['scopes'];
      }
      break;

      case 401: {
        print(response.body);
        throw ClientErrorException('0x0004');
      }
      break;

      case 404: {
        throw ClientErrorException('0x0008');
      }
      break;

      default: {
        throw ClientErrorException('0xFFFF');
      }
      break;
    }
  }

  Future<bool> setScope(String scope) async{
    _selectedScope = scope;
    await connectToBroker();
    _authentificated =  mqttClient.connectionState == MQTTCurrentConnectionState.CONNECTED;
    return _authentificated;
  }

  void connectToBroker() async {
    String topic = "$_selectedScope/tolinto/$_login";
    mqttClient = MQTTClientWrapper((msg) => print("Error : $msg"), (msg) => print("Message ! $msg"));
    await mqttClient.setupClient(_mqttHost, _mqttPort, _login, topic);
  }

  void sendMessage(Map<String, dynamic> message) {
    mqttClient.publish(message);
  }
}