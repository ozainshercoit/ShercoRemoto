// ShercoRemoto: client of the ShercoIT API (docs/shercoremoto-api.md in the shercoit repo).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/platform_model.dart';
import 'secure_store.dart';

/// Default API. The local option `shercoremoto-api` overrides it without a rebuild.
const kShercoApiDefault = 'https://test.shercoit.com/api/shercoremoto';

class ShercoApiError implements Exception {
  final int status;
  final String codigo;
  final String message;
  ShercoApiError(this.status, this.codigo, this.message);
  @override
  String toString() => message.isNotEmpty ? message : codigo;
}

class ShercoUser {
  final String id, name, username, rol;
  ShercoUser(this.id, this.name, this.username, this.rol);
  factory ShercoUser.fromJson(Map<String, dynamic> j) => ShercoUser(
      '${j['id'] ?? ''}', '${j['name'] ?? ''}', '${j['username'] ?? ''}',
      '${j['rol'] ?? ''}');
}

class ShercoDeviceCode {
  final String codigoDispositivo, codigoUsuario, url;
  final int intervalo, expiraEn;
  ShercoDeviceCode(this.codigoDispositivo, this.codigoUsuario, this.url,
      this.intervalo, this.expiraEn);
}

class ShercoEquipo {
  final String id, grupoId, idRemoto, nombre, icono;
  final int orden;
  ShercoEquipo(this.id, this.grupoId, this.idRemoto, this.nombre, this.icono,
      this.orden);
  factory ShercoEquipo.fromJson(Map<String, dynamic> j, String grupoId) =>
      ShercoEquipo('${j['id']}', '${j['grupoId'] ?? grupoId}',
          '${j['idRemoto'] ?? ''}', '${j['nombre'] ?? ''}',
          '${j['icono'] ?? 'Monitor'}', (j['orden'] as num?)?.toInt() ?? 0);
}

class ShercoGrupo {
  final String id, nombre, icono;
  final int orden;
  final List<ShercoEquipo> equipos;
  ShercoGrupo(this.id, this.nombre, this.icono, this.orden, this.equipos);
  factory ShercoGrupo.fromJson(Map<String, dynamic> j) {
    final id = '${j['id']}';
    return ShercoGrupo(
        id,
        '${j['nombre'] ?? ''}',
        '${j['icono'] ?? 'Carpeta'}',
        (j['orden'] as num?)?.toInt() ?? 0,
        ((j['equipos'] as List?) ?? [])
            .map((e) => ShercoEquipo.fromJson(e as Map<String, dynamic>, id))
            .toList());
  }
}

/// Session state: tokens, user, heartbeat. One per Flutter engine (each window
/// reads the same encrypted tokens from the local options).
class ShercoAuth {
  ShercoAuth._();
  static final ShercoAuth instance = ShercoAuth._();

  final user = ValueNotifier<ShercoUser?>(null);
  final pedirLogin = ValueNotifier<bool>(true);

  String? _access;
  DateTime _accessExpires = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _latido;
  Future<bool>? _refreshing;

  String get base {
    final o = bind.mainGetLocalOption(key: 'shercoremoto-api').trim();
    return (o.isNotEmpty ? o : kShercoApiDefault).replaceAll(RegExp(r'/+$'), '');
  }

  String get loginBase => base.replaceAll(RegExp(r'/api/shercoremoto$'), '');

  bool get loggedIn => user.value != null;

  String? get _refresh => ShercoSecureStore.read('refresh');
  String? get _sesionId => ShercoSecureStore.read('sesion');

  // ---------- HTTP ----------

  Future<dynamic> _send(String method, String path,
      {Object? body, bool auth = false, bool retried = false}) async {
    final uri = Uri.parse('$base$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      if (_access == null ||
          DateTime.now().isAfter(_accessExpires.subtract(const Duration(seconds: 60)))) {
        if (!await refresh()) throw ShercoApiError(401, 'sesion_cerrada', '');
      }
      headers['Authorization'] = 'Bearer $_access';
    }
    late http.Response r;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      r = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 20)));
    } on TimeoutException {
      throw ShercoApiError(0, 'sin_conexion',
          'No se puede contactar con ShercoIT. Revisa la conexión a internet.');
    } on SocketException {
      throw ShercoApiError(0, 'sin_conexion',
          'No se puede contactar con ShercoIT. Revisa la conexión a internet.');
    }
    final text = utf8.decode(r.bodyBytes);
    dynamic json;
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } catch (_) {}
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return json;
    final codigo = json is Map ? '${json['codigo'] ?? ''}' : '';
    var message = json is Map ? json['message'] : null;
    if (message is List) message = message.join('\n');
    final err = ShercoApiError(r.statusCode, codigo, '${message ?? ''}');
    if (auth && !retried && r.statusCode == 401 && codigo == 'token_invalido') {
      _access = null;
      return _send(method, path, body: body, auth: true, retried: true);
    }
    if (auth &&
        ((r.statusCode == 401 &&
                (codigo == 'sesion_cerrada' || codigo == 'usuario_inactivo')) ||
            (r.statusCode == 403 && codigo == 'sin_acceso'))) {
      await _clearLocal();
    }
    throw err;
  }

  // ---------- Startup ----------

  /// Reads the settings and restores a saved session. Never throws.
  Future<void> init() async {
    try {
      final a = await _send('GET', '/ajustes');
      if (a is Map) pedirLogin.value = a['pedirLogin'] != false;
    } catch (_) {
      // offline: keep requiring login, the cached session still works below
    }
    if (_refresh == null) return;
    try {
      final yo = await _send('GET', '/yo', auth: true);
      user.value = ShercoUser.fromJson(yo as Map<String, dynamic>);
      _startLatido();
    } catch (_) {}
  }

  // ---------- Login ----------

  Future<void> _store(Map<String, dynamic> j) async {
    _access = '${j['accessToken']}';
    _accessExpires = DateTime.now()
        .add(Duration(seconds: (j['expiresIn'] as num?)?.toInt() ?? 900));
    await ShercoSecureStore.write('refresh', '${j['refreshToken']}');
    if (j['sesionId'] != null) {
      await ShercoSecureStore.write('sesion', '${j['sesionId']}');
    }
    if (j['user'] is Map) {
      user.value = ShercoUser.fromJson(j['user'] as Map<String, dynamic>);
    }
  }

  Future<void> _afterLogin() async {
    try {
      final myId = await bind.mainGetMyId();
      final version = await bind.mainGetVersion();
      await _send('POST', '/sesiones',
          body: {
            'equipoNombre': Platform.localHostname,
            'equipoId': myId.replaceAll(' ', ''),
            'version': version
          },
          auth: true);
    } catch (_) {}
    _startLatido();
  }

  /// Throws [ShercoApiError]; `codigo == 'totp_requerido'` asks for the 6-digit code.
  Future<void> loginPassword(String username, String password,
      {String? totp}) async {
    final j = await _send('POST', '/auth/login', body: {
      'username': username,
      'password': password,
      if (totp != null && totp.isNotEmpty) 'totp': totp,
      'equipoNombre': Platform.localHostname,
    });
    await _store(j as Map<String, dynamic>);
    await _afterLogin();
  }

  Future<ShercoDeviceCode> startBrowserLogin() async {
    final j = await _send('POST', '/auth/dispositivo',
        body: {'equipoNombre': Platform.localHostname}) as Map<String, dynamic>;
    return ShercoDeviceCode(
        '${j['codigoDispositivo']}',
        '${j['codigoUsuario']}',
        '${j['url']}',
        (j['intervalo'] as num?)?.toInt() ?? 5,
        (j['expiraEn'] as num?)?.toInt() ?? 600);
  }

  /// Returns true when approved, false while pending; throws when refused or expired.
  Future<bool> pollBrowserLogin(ShercoDeviceCode code) async {
    final r = await http
        .post(Uri.parse('$base/auth/dispositivo/token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'codigoDispositivo': code.codigoDispositivo}))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 202) return false;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode == 200) {
      await _store(j as Map<String, dynamic>);
      await _afterLogin();
      return true;
    }
    throw ShercoApiError(r.statusCode, j is Map ? '${j['codigo'] ?? ''}' : '',
        j is Map ? '${j['message'] ?? ''}' : '');
  }

  Future<bool> refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final rt = _refresh;
    if (rt == null) return false;
    try {
      final j = await _send('POST', '/auth/refresh', body: {'refreshToken': rt});
      await _store(j as Map<String, dynamic>);
      return true;
    } on ShercoApiError catch (e) {
      if (e.status == 401 || e.status == 403) await _clearLocal();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout', auth: true);
    } catch (_) {}
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    _latido?.cancel();
    _latido = null;
    _access = null;
    user.value = null;
    await ShercoSecureStore.write('refresh', null);
    await ShercoSecureStore.write('sesion', null);
  }

  void _startLatido() {
    _latido?.cancel();
    _latido = Timer.periodic(const Duration(minutes: 3), (_) async {
      final s = _sesionId;
      if (s == null) return;
      try {
        await _send('POST', '/sesiones/$s/latido', auth: true);
      } catch (_) {}
    });
  }

  // ---------- Groups ----------

  Future<List<ShercoGrupo>> grupos() async {
    final j = await _send('GET', '/grupos', auth: true) as List;
    return j.map((e) => ShercoGrupo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> crearGrupo(String nombre, String icono) =>
      _send('POST', '/grupos', body: {'nombre': nombre, 'icono': icono}, auth: true);

  Future<void> editarGrupo(String id, {String? nombre, String? icono}) =>
      _send('PATCH', '/grupos/$id',
          body: {if (nombre != null) 'nombre': nombre, if (icono != null) 'icono': icono},
          auth: true);

  Future<void> borrarGrupo(String id) =>
      _send('DELETE', '/grupos/$id', auth: true);

  Future<void> crearEquipo(String grupoId, String idRemoto, String nombre,
          String icono) =>
      _send('POST', '/grupos/$grupoId/equipos',
          body: {
            'idRemoto': idRemoto.replaceAll(' ', ''),
            'nombre': nombre,
            'icono': icono
          },
          auth: true);

  Future<void> editarEquipo(String grupoId, String equipoId,
          {String? nombre, String? icono, String? idRemoto, String? moverA}) =>
      _send('PATCH', '/grupos/$grupoId/equipos/$equipoId',
          body: {
            if (nombre != null) 'nombre': nombre,
            if (icono != null) 'icono': icono,
            if (idRemoto != null) 'idRemoto': idRemoto.replaceAll(' ', ''),
            if (moverA != null) 'grupoId': moverA,
          },
          auth: true);

  Future<void> borrarEquipo(String grupoId, String equipoId) =>
      _send('DELETE', '/grupos/$grupoId/equipos/$equipoId', auth: true);

  // ---------- Connection log ----------

  /// Logs the start of a connection; the id is kept per peer so the window
  /// that ends the connection (another Flutter engine) can close it.
  Future<void> conexionInicio(String idRemoto, String tipo) async {
    if (!loggedIn && _refresh == null) return;
    try {
      final j = await _send('POST', '/conexiones',
          body: {'idRemoto': idRemoto.replaceAll(' ', ''), 'tipo': tipo},
          auth: true);
      if (j is Map && j['conexionId'] != null) {
        await bind.mainSetLocalOption(
            key: 'shercoremoto-conexion-$tipo-${idRemoto.replaceAll(' ', '')}',
            value: '${j['conexionId']}');
      }
    } catch (_) {}
  }

  Future<void> conexionFin(String idRemoto, String tipo) async {
    final key = 'shercoremoto-conexion-$tipo-${idRemoto.replaceAll(' ', '')}';
    final id = bind.mainGetLocalOption(key: key);
    if (id.isEmpty) return;
    await bind.mainSetLocalOption(key: key, value: '');
    try {
      await _send('POST', '/conexiones/$id/fin', auth: true);
    } catch (_) {}
  }
}
