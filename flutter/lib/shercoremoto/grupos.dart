// ShercoRemoto: shared groups of computers (ShercoIT API) with list,
// thumbnail and tile views and custom names and icons.
import 'package:flutter/material.dart';

import '../common.dart' hide Dialog;
import '../common/formatter/id_formatter.dart';
import 'api.dart';
import 'compartir.dart';
import 'region.dart';
import 'iconos_data.dart';
import 'login.dart';
import 'widgets.dart';

enum _Vista { lista, miniaturas, mosaico }

/// Right-hand area of the home page: a sidebar with "Recientes y favoritos"
/// (the existing peer tabs, [peerTabs]) and the shared groups.
class ShercoEquiposPanel extends StatefulWidget {
  final Widget peerTabs;
  const ShercoEquiposPanel({super.key, required this.peerTabs});
  @override
  State<ShercoEquiposPanel> createState() => _ShercoEquiposPanelState();
}

class _ShercoEquiposPanelState extends State<ShercoEquiposPanel> {
  List<ShercoGrupo> _grupos = [];
  String? _sel; // null = recent and favourites
  _Vista _vista = _Vista.lista;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ShercoAuth.instance.user.addListener(_onUser);
    _cargar();
  }

  @override
  void dispose() {
    ShercoAuth.instance.user.removeListener(_onUser);
    super.dispose();
  }

  void _onUser() {
    if (!mounted) return;
    if (ShercoAuth.instance.loggedIn) {
      _cargar();
    } else {
      setState(() {
        _grupos = [];
        _sel = null;
      });
    }
  }

  Future<void> _cargar() async {
    if (!ShercoAuth.instance.loggedIn) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final g = await ShercoAuth.instance.grupos();
      if (!mounted) return;
      setState(() {
        _grupos = g;
        if (_sel != null && !g.any((x) => x.id == _sel)) _sel = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _accion(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) showToast('$e');
    }
    await _cargar();
  }

  ShercoGrupo? get _grupo =>
      _sel == null ? null : _grupos.where((g) => g.id == _sel).firstOrNull;

  // ---------------- Sidebar ----------------

  Widget _itemLateral(String icono, String nombre, bool activo, VoidCallback onTap,
      {String? total}) {
    final c = activo ? SC.navy : SC.texto(context);
    return Material(
      color: activo ? SC.chip(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            ShercoIcono(icono, size: 18, color: SC.dark(context) && activo ? Colors.white : c),
            const SizedBox(width: 10),
            Expanded(
                child: Text(nombre,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SC.dark(context) && activo ? Colors.white : c))),
            if (total != null)
              Text(total,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: SC.suave(context))),
          ]),
        ),
      ),
    );
  }

  Widget _lateral() {
    final logged = ShercoAuth.instance.loggedIn;
    return Container(
      width: 220,
      decoration: BoxDecoration(
          border: Border(right: BorderSide(color: SC.borde(context)))),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _itemLateral('Reloj', 'Recientes y favoritos', _sel == null,
            () => setState(() => _sel = null)),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 4, 6),
          child: Row(children: [
            Expanded(
                child: Text('MIS GRUPOS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: SC.suave(context)))),
            if (logged)
              IconButton(
                tooltip: 'Nuevo grupo',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 18, color: SC.azul),
                onPressed: _nuevoGrupo,
              ),
          ]),
        ),
        Expanded(
          child: !logged
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Inicia sesión para ver los grupos compartidos de ShercoIT.',
                        style: TextStyle(fontSize: 13, height: 1.5, color: SC.suave(context))),
                    const SizedBox(height: 10),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: SC.azul),
                        onPressed: () => mostrarLoginSherco(context),
                        child: const Text('Iniciar sesión')),
                  ]),
                )
              : _cargando && _grupos.isEmpty
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                  : ListView(children: [
                      for (final g in _grupos)
                        _itemLateral(g.icono, g.nombre, _sel == g.id,
                            () => setState(() => _sel = g.id),
                            total: '${g.equipos.length}'),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(_error!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFFC0392B))),
                        ),
                    ]),
        ),
        if (logged) ...[
          Divider(color: SC.borde(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(ShercoAuth.instance.user.value?.name ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: () => ShercoAuth.instance.logout(),
                child: const Text('Cerrar sesión')),
          ),
        ],
      ]),
    );
  }

  // ---------------- Dialogs ----------------

  Future<String?> _elegirIcono(String para, String actual) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Elegir icono', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('Para $para · ${kShercoIconos.length} iconos',
                  style: TextStyle(fontSize: 13, color: SC.suave(ctx))),
              const SizedBox(height: 14),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final n in kShercoIconos.keys)
                  Tooltip(
                    message: n,
                    child: Material(
                      color: n == actual ? SC.azul : SC.fondo(ctx),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(ctx).pop(n),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Center(
                              child: ShercoIcono(n,
                                  size: 22, color: n == actual ? Colors.white : SC.texto(ctx))),
                        ),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<String?> _pedirTexto(String titulo, String etiqueta, {String inicial = ''}) {
    final c = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(labelText: etiqueta),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim())),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: SC.azul),
              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<bool> _confirmar(String texto) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Borrar')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _nuevoGrupo() async {
    final nombre = await _pedirTexto('Nuevo grupo', 'Nombre del grupo');
    if (nombre == null || nombre.isEmpty) return;
    final icono = await _elegirIcono('el grupo $nombre', 'Carpeta') ?? 'Carpeta';
    await _accion(() => ShercoAuth.instance.crearGrupo(nombre, icono));
  }

  Future<void> _anadirEquipo(ShercoGrupo g) async {
    final idC = TextEditingController();
    final nomC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Añadir equipo a ${g.nombre}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: idC,
              autofocus: true,
              inputFormatters: [IDTextInputFormatter()],
              decoration: const InputDecoration(labelText: 'ID del equipo')),
          const SizedBox(height: 10),
          TextField(controller: nomC, decoration: const InputDecoration(labelText: 'Nombre')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: SC.azul),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Añadir')),
        ],
      ),
    );
    if (ok != true || idC.text.trim().isEmpty) return;
    final nombre = nomC.text.trim().isEmpty ? idC.text.trim() : nomC.text.trim();
    final icono = await _elegirIcono(nombre, 'Monitor') ?? 'Monitor';
    await _accion(() => ShercoAuth.instance.crearEquipo(g.id, idC.text, nombre, icono));
  }

  Future<void> _mover(ShercoGrupo g, ShercoEquipo e) async {
    final destino = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Mover ${e.nombre} a…'),
        children: [
          for (final o in _grupos.where((x) => x.id != g.id))
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(o.id),
              child: Row(children: [
                ShercoIcono(o.icono, size: 18, color: SC.texto(ctx)),
                const SizedBox(width: 10),
                Text(o.nombre),
              ]),
            ),
        ],
      ),
    );
    if (destino == null) return;
    await _accion(() => ShercoAuth.instance.editarEquipo(g.id, e.id, moverA: destino));
  }

  // ---------------- Computers ----------------

  Widget _menuEquipo(ShercoGrupo g, ShercoEquipo e) {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: Icon(Icons.more_vert, size: 18, color: SC.suave(context)),
      onSelected: (v) async {
        switch (v) {
          case 'archivos':
            connect(context, e.idRemoto, isFileTransfer: true);
          case 'compartir':
            await mostrarCompartir(context, e.idRemoto, e.nombre, ingles: shercoIngles());
          case 'renombrar':
            final n = await _pedirTexto('Renombrar equipo', 'Nombre', inicial: e.nombre);
            if (n != null && n.isNotEmpty) {
              await _accion(() => ShercoAuth.instance.editarEquipo(g.id, e.id, nombre: n));
            }
          case 'icono':
            final i = await _elegirIcono(e.nombre, e.icono);
            if (i != null) await _accion(() => ShercoAuth.instance.editarEquipo(g.id, e.id, icono: i));
          case 'mover':
            await _mover(g, e);
          case 'borrar':
            if (await _confirmar('¿Quitar ${e.nombre} del grupo ${g.nombre}?')) {
              await _accion(() => ShercoAuth.instance.borrarEquipo(g.id, e.id));
            }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'archivos', child: Text('Transferir archivos')),
        PopupMenuItem(value: 'compartir', child: Text('Compartir')),
        PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
        PopupMenuItem(value: 'icono', child: Text('Cambiar icono')),
        PopupMenuItem(value: 'mover', child: Text('Mover a otro grupo')),
        PopupMenuItem(value: 'borrar', child: Text('Quitar del grupo')),
      ],
    );
  }

  Widget _botonIcono(ShercoGrupo g, ShercoEquipo e, double caja, double icono) {
    return Tooltip(
      message: 'Cambiar icono',
      child: Material(
        color: SC.chip(context),
        borderRadius: BorderRadius.circular(caja / 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(caja / 4),
          onTap: () async {
            final i = await _elegirIcono(e.nombre, e.icono);
            if (i != null) await _accion(() => ShercoAuth.instance.editarEquipo(g.id, e.id, icono: i));
          },
          child: SizedBox(
              width: caja,
              height: caja,
              child: Center(child: ShercoIcono(e.icono, size: icono, color: SC.azul))),
        ),
      ),
    );
  }

  Widget _tarjeta({required Widget child, VoidCallback? onDoubleTap}) => Material(
        color: SC.tarjeta(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), side: BorderSide(color: SC.borde(context))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onDoubleTap: onDoubleTap, child: child),
      );

  Widget _lista(ShercoGrupo g) {
    return ListView.separated(
      itemCount: g.equipos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = g.equipos[i];
        return _tarjeta(
          onDoubleTap: () => connect(context, e.idRemoto),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              _botonIcono(g, e, 38, 19),
              const SizedBox(width: 14),
              Expanded(
                  flex: 3,
                  child: Text(e.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              Expanded(
                  flex: 2,
                  child: Text(formatID(e.idRemoto),
                      style: TextStyle(fontSize: 13, color: SC.suave(context)))),
              TextButton(
                  onPressed: () => connect(context, e.idRemoto),
                  style: TextButton.styleFrom(
                      backgroundColor: SC.chip(context), foregroundColor: SC.azul),
                  child: const Text('Conectar', style: TextStyle(fontWeight: FontWeight.w700))),
              _menuEquipo(g, e),
            ]),
          ),
        );
      },
    );
  }

  Widget _rejilla(ShercoGrupo g, {required bool mini}) {
    return LayoutBuilder(builder: (_, cons) {
      final ancho = mini ? 210.0 : 150.0;
      final cols = (cons.maxWidth / ancho).floor().clamp(1, 8);
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: mini ? 1.1 : 0.95),
        itemCount: g.equipos.length,
        itemBuilder: (_, i) {
          final e = g.equipos[i];
          if (mini) {
            return _tarjeta(
              onDoubleTap: () => connect(context, e.idRemoto),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Container(
                    color: SC.chip(context),
                    child: Center(child: ShercoIcono(e.icono, size: 44, color: SC.azul, grosor: 1.4)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(formatID(e.idRemoto),
                            style: TextStyle(fontSize: 12, color: SC.suave(context))),
                      ]),
                    ),
                    _menuEquipo(g, e),
                  ]),
                ),
              ]),
            );
          }
          return _tarjeta(
            onDoubleTap: () => connect(context, e.idRemoto),
            child: Stack(children: [
              Positioned(right: 0, top: 0, child: _menuEquipo(g, e)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _botonIcono(g, e, 52, 26),
                    const SizedBox(height: 8),
                    Text(e.nombre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(formatID(e.idRemoto),
                        style: TextStyle(fontSize: 11, color: SC.suave(context))),
                  ]),
                ),
              ),
            ]),
          );
        },
      );
    });
  }

  Widget _contenidoGrupo(ShercoGrupo g) {
    final vistas = [
      (_Vista.lista, 'Lista', Icons.view_list_rounded),
      (_Vista.miniaturas, 'Miniaturas', Icons.grid_view_rounded),
      (_Vista.mosaico, 'Mosaico', Icons.apps_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Tooltip(
            message: 'Cambiar icono del grupo',
            child: Material(
              color: SC.azul,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final i = await _elegirIcono('el grupo ${g.nombre}', g.icono);
                  if (i != null) await _accion(() => ShercoAuth.instance.editarGrupo(g.id, icono: i));
                },
                child: SizedBox(
                    width: 44, height: 44, child: Center(child: ShercoIcono(g.icono, size: 22, color: Colors.white))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                    child: Text(g.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: 'Renombrar grupo',
                    icon: Icon(Icons.edit_outlined, size: 16, color: SC.suave(context)),
                    onPressed: () async {
                      final n = await _pedirTexto('Renombrar grupo', 'Nombre', inicial: g.nombre);
                      if (n != null && n.isNotEmpty) {
                        await _accion(() => ShercoAuth.instance.editarGrupo(g.id, nombre: n));
                      }
                    }),
                IconButton(
                    tooltip: 'Borrar grupo',
                    icon: Icon(Icons.delete_outline, size: 16, color: SC.suave(context)),
                    onPressed: () async {
                      if (await _confirmar('¿Borrar el grupo ${g.nombre} y sus ${g.equipos.length} equipos?')) {
                        await _accion(() => ShercoAuth.instance.borrarGrupo(g.id));
                      }
                    }),
              ]),
              Text('${g.equipos.length} ${g.equipos.length == 1 ? 'equipo' : 'equipos'}',
                  style: TextStyle(fontSize: 13, color: SC.suave(context))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        // Second row so a narrow window never squeezes the group name
        LayoutBuilder(builder: (_, cons) {
          final compacto = cons.maxWidth < 520;
          return Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_Vista>(
                showSelectedIcon: false,
                segments: [
                  for (final v in vistas)
                    ButtonSegment(
                        value: v.$1,
                        tooltip: v.$2,
                        label: compacto ? null : Text(v.$2),
                        icon: Icon(v.$3, size: 16)),
                ],
                selected: {_vista},
                onSelectionChanged: (s) => setState(() => _vista = s.first),
              ),
              FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: SC.azul),
                  onPressed: () => _anadirEquipo(g),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Añadir equipo')),
            ],
          );
        }),
        const SizedBox(height: 14),
        Expanded(
          child: g.equipos.isEmpty
              ? Center(
                  child: Text('Este grupo aún no tiene equipos. Pulsa «Añadir equipo».',
                      style: TextStyle(color: SC.suave(context))))
              : switch (_vista) {
                  _Vista.lista => _lista(g),
                  _Vista.miniaturas => _rejilla(g, mini: true),
                  _Vista.mosaico => _rejilla(g, mini: false),
                },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _grupo;
    return ValueListenableBuilder(
      valueListenable: ShercoAuth.instance.user,
      builder: (_, __, ___) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _lateral(),
        Expanded(child: g == null ? widget.peerTabs : _contenidoGrupo(g)),
      ]),
    );
  }
}
