// ShercoRemoto: share a computer (name + ID, never the password).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'widgets.dart';

const kShercoEnlaceBase = 'https://shercoremoto.shercoit.com/c/';

String _idLimpio(String id) => id.replaceAll(' ', '');

String _idBonito(String id) {
  final s = _idLimpio(id);
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String shercoEnlaceContacto(String id, String nombre) {
  final n = nombre.trim();
  return '$kShercoEnlaceBase${_idLimpio(id)}${n.isEmpty ? '' : '?n=${Uri.encodeQueryComponent(n)}'}';
}

String _mensaje(String id, String nombre, bool ingles) {
  final enlace = shercoEnlaceContacto(id, nombre);
  final n = nombre.trim().isEmpty ? '' : '${nombre.trim()} · ';
  return ingles
      ? 'Here is my ShercoRemoto computer:\n$n ID ${_idBonito(id)}\nAdd it to your ShercoRemoto: $enlace'
      : 'Te comparto mi equipo de ShercoRemoto:\n$n ID ${_idBonito(id)}\nAñádelo a tu ShercoRemoto: $enlace';
}

void _aviso(BuildContext context, String texto) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 2)));
}

/// Opens the share menu for a computer.
Future<void> mostrarCompartir(BuildContext context, String id, String nombre,
    {bool ingles = false}) async {
  final msg = _mensaje(id, nombre, ingles);
  final opciones = <(String, String, Future<void> Function())>[
    (
      'Copiar',
      ingles ? 'Copy ID' : 'Copiar ID',
      () async {
        await Clipboard.setData(ClipboardData(text: _idLimpio(id)));
        if (context.mounted) _aviso(context, ingles ? 'ID copied' : 'ID copiado');
      }
    ),
    (
      'Whatsapp',
      ingles ? 'Send via WhatsApp' : 'Enviar por WhatsApp',
      () => launchUrlString('https://wa.me/?text=${Uri.encodeComponent(msg)}',
          mode: LaunchMode.externalApplication)
    ),
    (
      'Telegram',
      ingles ? 'Send via Telegram' : 'Enviar por Telegram',
      () => launchUrlString(
          'https://t.me/share/url?url=${Uri.encodeComponent(shercoEnlaceContacto(id, nombre))}'
          '&text=${Uri.encodeComponent(msg.split('\n').take(2).join('\n'))}',
          mode: LaunchMode.externalApplication)
    ),
    (
      'Enlace',
      ingles ? 'Copy contact link' : 'Copiar enlace de contacto',
      () async {
        await Clipboard.setData(ClipboardData(text: shercoEnlaceContacto(id, nombre)));
        if (context.mounted) _aviso(context, ingles ? 'Link copied' : 'Enlace copiado');
      }
    ),
  ];
  await showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(ingles ? 'Share this computer' : 'Compartir este equipo'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
              ingles
                  ? 'Only the name and ID are shared. The password is never shared.'
                  : 'Solo se comparte el nombre y el ID. La contraseña nunca se comparte.',
              style: TextStyle(fontSize: 13, color: SC.suave(ctx))),
        ),
        for (final o in opciones)
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await o.$3();
            },
            child: Row(children: [
              _icono(o.$1, ctx),
              const SizedBox(width: 14),
              Text(o.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SelectableText(shercoEnlaceContacto(id, nombre),
              style: TextStyle(fontSize: 12, color: SC.suave(ctx), fontFamily: 'monospace')),
        ),
      ],
    ),
  );
}

Widget _icono(String clave, BuildContext c) {
  switch (clave) {
    case 'Whatsapp':
      return const Icon(Icons.chat_rounded, color: Color(0xFF1E9E5A), size: 20);
    case 'Telegram':
      return const Icon(Icons.send_rounded, color: Color(0xFF1E88C7), size: 20);
    case 'Enlace':
      return Icon(Icons.link_rounded, color: SC.suave(c), size: 20);
    default:
      return const Icon(Icons.copy_rounded, color: SC.azul, size: 20);
  }
}
