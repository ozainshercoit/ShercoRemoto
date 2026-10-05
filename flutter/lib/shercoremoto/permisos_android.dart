// ShercoRemoto (Android): first-run screen that asks for every permission the
// app needs to be controlled remotely, one after another from a single button.
// Android does not allow granting them at install time; for unattended
// deployment, web/files/instalar-android.cmd grants them over ADB instead.
import 'package:flutter/material.dart';

import '../common.dart';
import '../consts.dart';
import '../models/platform_model.dart';
import 'region.dart';
import 'widgets.dart';

const _kPermisosHechos = 'shercoremoto-permisos-android'; // 'v1' once shown

bool shercoPermisosAndroidPendiente() =>
    bind.mainGetLocalOption(key: _kPermisosHechos) != 'v1';

/// Region + agreement (when still needed), then the permissions screen.
class ShercoAsistenteAndroid extends StatefulWidget {
  final VoidCallback onListo;
  const ShercoAsistenteAndroid({super.key, required this.onListo});
  @override
  State<ShercoAsistenteAndroid> createState() => _ShercoAsistenteAndroidState();
}

class _ShercoAsistenteAndroidState extends State<ShercoAsistenteAndroid> {
  late bool _region = shercoNecesitaConfigurar();

  @override
  Widget build(BuildContext context) {
    if (_region) {
      return ShercoPrimerArranque(onListo: () {
        if (shercoPermisosAndroidPendiente()) {
          setState(() => _region = false);
        } else {
          widget.onListo();
        }
      });
    }
    return ShercoPermisosAndroid(onListo: widget.onListo);
  }
}

enum _Estado { pendiente, ok, no }

class _Permiso {
  final IconData icono;
  final String es, en, detalleEs, detalleEn;
  final bool opcional;
  final Future<bool> Function() comprobar;
  final Future<void> Function() pedir;
  _Estado estado = _Estado.pendiente;
  _Permiso(this.icono, this.es, this.en, this.detalleEs, this.detalleEn,
      this.comprobar, this.pedir,
      {this.opcional = false});
}

class ShercoPermisosAndroid extends StatefulWidget {
  final VoidCallback onListo;
  const ShercoPermisosAndroid({super.key, required this.onListo});
  @override
  State<ShercoPermisosAndroid> createState() => _ShercoPermisosAndroidState();
}

class _ShercoPermisosAndroidState extends State<ShercoPermisosAndroid>
    with WidgetsBindingObserver {
  final _en = shercoIngles();
  bool _trabajando = false;
  bool _arranque = true;
  late final List<_Permiso> _permisos;

  String t(String es, String en) => _en ? en : es;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final server = gFFI.serverModel;
    _permisos = [
      _Permiso(
          Icons.notifications_active_outlined,
          'Notificaciones',
          'Notifications',
          'Avisa cuando alguien se conecta a este equipo.',
          'Tells you when someone connects to this device.',
          () async =>
              androidVersion < 33 ||
              await AndroidPermissionManager.check(kAndroid13Notification),
          () => server.checkRequestNotificationPermission()),
      _Permiso(
          Icons.battery_charging_full_outlined,
          'Funcionar en segundo plano',
          'Run in the background',
          'Evita que Android cierre ShercoRemoto para ahorrar batería.',
          'Stops Android from closing ShercoRemoto to save battery.',
          () => AndroidPermissionManager.check(
              kRequestIgnoreBatteryOptimizations),
          () => AndroidPermissionManager.request(
              kRequestIgnoreBatteryOptimizations)),
      _Permiso(
          Icons.picture_in_picture_alt_outlined,
          'Mostrar sobre otras apps',
          'Display over other apps',
          'Mantiene el servicio activo y permite arrancar al encender.',
          'Keeps the service alive and allows starting at boot.',
          () => AndroidPermissionManager.check(kSystemAlertWindow),
          () => AndroidPermissionManager.request(kSystemAlertWindow)),
      _Permiso(
          Icons.mic_none_outlined,
          'Micrófono y sonido',
          'Microphone and sound',
          'Para enviar el sonido del equipo. Es opcional.',
          'To send the device sound. Optional.',
          () => AndroidPermissionManager.check(kRecordAudio),
          () => AndroidPermissionManager.request(kRecordAudio),
          opcional: true),
      _Permiso(
          Icons.touch_app_outlined,
          'Control remoto',
          'Remote control',
          'En Accesibilidad, activa «ShercoRemoto Control» para que el técnico pueda tocar la pantalla.',
          'In Accessibility, turn on "ShercoRemoto Control" so the technician can tap the screen.',
          () async => gFFI.serverModel.inputOk,
          _pedirAccesibilidad),
      _Permiso(
          Icons.screen_share_outlined,
          'Compartir la pantalla',
          'Share the screen',
          'Inicia el servicio. Android pedirá confirmación para grabar la pantalla.',
          'Starts the service. Android will ask to confirm screen recording.',
          () async => gFFI.serverModel.isStart,
          _iniciarServicio),
    ];
    gFFI.serverModel.addListener(_alCambiarServidor);
    gFFI.invokeMethod('check_service');
    _refrescar().whenComplete(() {
      if (mounted) setState(() => _arranque = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gFFI.serverModel.removeListener(_alCambiarServidor);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refrescar();
  }

  void _alCambiarServidor() => _refrescar();

  Future<void> _refrescar() async {
    for (final p in _permisos) {
      bool ok = false;
      try {
        ok = await p.comprobar();
      } catch (_) {}
      if (ok) {
        p.estado = _Estado.ok;
      } else if (p.estado == _Estado.ok) {
        p.estado = _Estado.pendiente;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _pedirAccesibilidad() async {
    final seguir = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(t('Activar el control remoto', 'Turn on remote control')),
              content: Text(t(
                  'Se abrirá Accesibilidad. Busca «ShercoRemoto Control» (a veces dentro de «Aplicaciones instaladas» o «Servicios descargados»), actívalo y vuelve a ShercoRemoto.\n\n'
                      'Si Android dice «Ajuste restringido», abre la información de la app ShercoRemoto, toca el menú ⋮ y elige «Permitir ajustes restringidos»; después vuelve a intentarlo.',
                  'Accessibility will open. Find "ShercoRemoto Control" (sometimes under "Installed apps" or "Downloaded services"), turn it on and come back to ShercoRemoto.\n\n'
                      'If Android says "Restricted setting", open the ShercoRemoto app info, tap the ⋮ menu and choose "Allow restricted settings", then try again.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(t('Ahora no', 'Not now'))),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(t('Abrir Accesibilidad', 'Open Accessibility'))),
              ],
            ));
    if (seguir == true) {
      AndroidPermissionManager.startAction(kActionAccessibilitySettings);
    }
  }

  Future<void> _iniciarServicio() async {
    if (!gFFI.serverModel.isStart) await gFFI.serverModel.startService();
  }

  Future<void> _activarArranque() async {
    final bateria = await AndroidPermissionManager.check(
        kRequestIgnoreBatteryOptimizations);
    final encima = await AndroidPermissionManager.check(kSystemAlertWindow);
    if (bateria && encima) {
      await gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, true);
    }
  }

  /// Asks for each missing permission in order. Accessibility leaves the app,
  /// so the chain stops there and the button resumes it on return.
  Future<void> _concederTodo() async {
    if (_trabajando) return;
    setState(() => _trabajando = true);
    try {
      for (final p in _permisos) {
        if (await p.comprobar()) {
          p.estado = _Estado.ok;
          continue;
        }
        if (p.pedir == _pedirAccesibilidad) {
          await _activarArranque();
          await _pedirAccesibilidad();
          break;
        }
        await p.pedir();
        final ok = await p.comprobar();
        p.estado = ok ? _Estado.ok : _Estado.no;
        if (mounted) setState(() {});
      }
      await _activarArranque();
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _terminar() async {
    await _activarArranque();
    await bind.mainSetLocalOption(key: _kPermisosHechos, value: 'v1');
    widget.onListo();
  }

  bool get _todoOk =>
      _permisos.every((p) => p.opcional || p.estado == _Estado.ok);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SC.fondo(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Row(children: [
                  const ShercoIcono('Escudo', size: 30, color: SC.azul),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(t('Permisos de ShercoRemoto', 'ShercoRemoto permissions'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: SC.texto(context)))),
                ]),
                const SizedBox(height: 10),
                Text(
                    t('Para que un técnico pueda ver y controlar este equipo, concede estos permisos una sola vez. Pulsa el botón y acepta cada aviso de Android.',
                        'So a technician can see and control this device, grant these permissions once. Tap the button and accept each Android prompt.'),
                    style: TextStyle(color: SC.suave(context), height: 1.4)),
                const SizedBox(height: 18),
                for (final p in _permisos) _fila(p),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: SC.azul,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _trabajando || _arranque ? null : _concederTodo,
                  icon: _trabajando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(_todoOk
                      ? t('Todo listo', 'All set')
                      : t('Conceder permisos', 'Grant permissions')),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _trabajando ? null : _terminar,
                  child: Text(_todoOk
                      ? t('Continuar', 'Continue')
                      : t('Continuar sin terminar (se pueden conceder luego)',
                          'Continue anyway (you can grant them later)')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fila(_Permiso p) {
    final (Color color, IconData icono, String texto) = switch (p.estado) {
      _Estado.ok => (SC.verde, Icons.check_circle, t('Concedido', 'Granted')),
      _Estado.no => (
          Colors.orange,
          Icons.error_outline,
          p.opcional ? t('Opcional', 'Optional') : t('Falta', 'Missing')
        ),
      _Estado.pendiente => (
          SC.gris,
          Icons.radio_button_unchecked,
          p.opcional ? t('Opcional', 'Optional') : t('Pendiente', 'Pending')
        ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: SC.tarjeta(context),
          border: Border.all(color: SC.borde(context)),
          borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: SC.chip(context), borderRadius: BorderRadius.circular(10)),
          child: Icon(p.icono, color: SC.azul),
        ),
        title: Text(_en ? p.en : p.es,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: SC.texto(context))),
        subtitle: Text(_en ? p.detalleEn : p.detalleEs,
            style: TextStyle(color: SC.suave(context), fontSize: 12.5)),
        trailing: Tooltip(
            message: texto, child: Icon(icono, color: color, size: 26)),
        onTap: _trabajando || p.estado == _Estado.ok
            ? null
            : () async {
                await p.pedir();
                await _refrescar();
              },
      ),
    );
  }
}
