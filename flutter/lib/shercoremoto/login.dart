// ShercoRemoto: sign in with a ShercoIT account (password + TOTP, or browser).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'api.dart';
import 'widgets.dart';

String _mensaje(Object e) {
  if (e is ShercoApiError) {
    switch (e.codigo) {
      case 'credenciales':
        return 'Usuario o contraseña incorrectos. Tras 5 intentos la cuenta se bloquea 15 minutos.';
      case 'totp_incorrecto':
        return 'El código de verificación no es correcto.';
      case 'usar_navegador':
        return 'Tu cuenta usa llave de acceso: inicia sesión con el navegador.';
      case 'sin_acceso':
        return 'Tu usuario no tiene permiso para usar ShercoRemoto. Pide acceso a un administrador.';
      case 'denegado':
        return 'Se rechazó el inicio de sesión en el navegador.';
      case 'codigo_caducado':
      case 'codigo_usado':
      case 'codigo_no_valido':
        return 'El código ha caducado. Vuelve a intentarlo.';
      case 'sin_conexion':
        return e.message;
    }
    if (e.status == 429) return 'Demasiados intentos. Espera un minuto.';
    if (e.message.isNotEmpty) return e.message;
  }
  return 'No se pudo iniciar sesión. Inténtalo de nuevo.';
}

/// Shows the sign-in dialog; true once signed in.
Future<bool> mostrarLoginSherco(BuildContext context) async {
  final r = await showDialog<bool>(
      context: context, barrierDismissible: false, builder: (_) => const _LoginDialog());
  return r == true;
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _totp = TextEditingController();
  bool _pideTotp = false, _ocupado = false;
  String? _error;
  ShercoDeviceCode? _codigo;
  Timer? _sondeo;

  @override
  void dispose() {
    _sondeo?.cancel();
    _usuario.dispose();
    _clave.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_usuario.text.trim().isEmpty || _clave.text.isEmpty) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await ShercoAuth.instance.loginPassword(_usuario.text.trim(), _clave.text,
          totp: _pideTotp ? _totp.text.trim() : null);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (e is ShercoApiError && e.codigo == 'totp_requerido') {
        setState(() => _pideTotp = true);
      } else {
        setState(() => _error = _mensaje(e));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _navegador() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final c = await ShercoAuth.instance.startBrowserLogin();
      setState(() => _codigo = c);
      await launchUrlString(c.url);
      final limite = DateTime.now().add(Duration(seconds: c.expiraEn));
      _sondeo = Timer.periodic(Duration(seconds: c.intervalo), (t) async {
        if (DateTime.now().isAfter(limite)) {
          t.cancel();
          if (mounted) {
            setState(() {
              _codigo = null;
              _ocupado = false;
              _error = 'El código ha caducado. Vuelve a intentarlo.';
            });
          }
          return;
        }
        try {
          if (await ShercoAuth.instance.pollBrowserLogin(c)) {
            t.cancel();
            if (mounted) Navigator.of(context).pop(true);
          }
        } catch (e) {
          if (e is ShercoApiError && e.status == 0) return; // network blip: keep polling
          t.cancel();
          if (mounted) {
            setState(() {
              _codigo = null;
              _ocupado = false;
              _error = _mensaje(e);
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        _ocupado = false;
        _error = _mensaje(e);
      });
    }
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final suave = SC.suave(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Iniciar sesión',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  'Para conectarte a otros equipos necesitas una cuenta de ShercoIT autorizada para ShercoRemoto.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: suave)),
              const SizedBox(height: 20),
              if (_codigo != null) ...[
                Text('Autoriza este equipo en la ventana del navegador. Comprueba que el código coincide:',
                    style: TextStyle(fontSize: 13, height: 1.5, color: suave)),
                const SizedBox(height: 12),
                Center(
                  child: SelectableText(_codigo!.codigoUsuario,
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 3)),
                ),
                const SizedBox(height: 12),
                const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: () => launchUrlString(_codigo!.url),
                    child: const Text('Abrir el navegador otra vez')),
              ] else ...[
                TextField(
                    controller: _usuario,
                    autofocus: true,
                    enabled: !_ocupado,
                    autofillHints: const [AutofillHints.username],
                    decoration: _deco('Usuario')),
                const SizedBox(height: 12),
                TextField(
                    controller: _clave,
                    obscureText: true,
                    enabled: !_ocupado,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _entrar(),
                    decoration: _deco('Contraseña')),
                if (_pideTotp) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: _totp,
                      autofocus: true,
                      enabled: !_ocupado,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _entrar(),
                      decoration: _deco('Código de verificación (6 dígitos)')),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _ocupado ? null : _entrar,
                  style: FilledButton.styleFrom(
                      backgroundColor: SC.azul,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text(_pideTotp ? 'Verificar' : 'Entrar',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : _navegador,
                  icon: ShercoIcono('Mundo', size: 16, color: SC.texto(context)),
                  label: const Text('Iniciar sesión con el navegador'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: SC.texto(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!,
                    style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13, height: 1.4)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gate before connecting to another computer. True when allowed.
Future<bool> shercoPuedeConectar(BuildContext context) async {
  final auth = ShercoAuth.instance;
  if (!auth.pedirLogin.value) return true;
  if (auth.loggedIn) return true;
  if (await auth.refresh()) {
    try {
      await auth.init();
    } catch (_) {}
    if (auth.loggedIn) return true;
  }
  if (!context.mounted) return false;
  return mostrarLoginSherco(context);
}
