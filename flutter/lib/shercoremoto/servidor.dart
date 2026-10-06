// ShercoRemoto: server selector. "ShercoRemoto" is the built-in server;
// "RustDesk público" uses RustDesk's public ID/relay server and key so this
// client can connect to stock RustDesk clients. Only one at a time.
import 'package:flutter/material.dart';

import '../models/platform_model.dart';
import 'region.dart';
import 'widgets.dart';

const _kModo = 'shercoremoto-servidor'; // 'sherco' | 'publico'
const kShercoServidorPublico = 'rs-ny.rustdesk.com';
const kShercoClavePublica = 'OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=';

/// Notifies every selector on screen when the mode changes.
final ValueNotifier<String> shercoModoServidor = ValueNotifier<String>(_leerModo());

String _leerModo() {
  final guardado = bind.mainGetLocalOption(key: _kModo);
  if (guardado == 'publico' || guardado == 'sherco') return guardado;
  final custom = bind.mainGetOption(key: 'custom-rendezvous-server');
  return custom.contains('rustdesk.com') ? 'publico' : 'sherco';
}

/// Switches server without reinstalling. Options go one by one, as the stock
/// server dialog does.
Future<void> shercoCambiarServidor(String modo) async {
  final publico = modo == 'publico';
  await bind.mainSetOption(
      key: 'custom-rendezvous-server', value: publico ? kShercoServidorPublico : '');
  await bind.mainSetOption(key: 'relay-server', value: '');
  await bind.mainSetOption(key: 'api-server', value: '');
  await bind.mainSetOption(key: 'key', value: publico ? kShercoClavePublica : '');
  await bind.mainSetLocalOption(key: _kModo, value: modo);
  shercoModoServidor.value = modo;
}

/// "ShercoRemoto" or "RustDesk público", for labels.
String shercoNombreServidor() =>
    shercoModoServidor.value == 'publico'
        ? (shercoIngles() ? 'Public RustDesk' : 'RustDesk público')
        : 'ShercoRemoto';

class ShercoSelectorServidor extends StatelessWidget {
  /// Compact version for the narrow left pane and phones.
  final bool compacto;
  const ShercoSelectorServidor({super.key, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final en = shercoIngles();
    return ValueListenableBuilder<String>(
      valueListenable: shercoModoServidor,
      builder: (context, modo, _) {
        Future<void> elegir(String? nuevo) async {
          if (nuevo == null || nuevo == modo) return;
          await shercoCambiarServidor(nuevo);
          if (!context.mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
              content: Text(nuevo == 'publico'
                  ? (en
                      ? 'Public RustDesk server selected. Your ID and password may differ there.'
                      : 'Servidor público de RustDesk. Tu ID y contraseña pueden ser distintos allí.')
                  : (en ? 'ShercoRemoto server selected.' : 'Servidor de ShercoRemoto.')),
              duration: const Duration(seconds: 3)));
        }

        final dropdown = DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: modo,
            isDense: true,
            isExpanded: true,
            onChanged: elegir,
            items: [
              const DropdownMenuItem(value: 'sherco', child: Text('ShercoRemoto')),
              DropdownMenuItem(
                  value: 'publico', child: Text(en ? 'Public RustDesk' : 'RustDesk público')),
            ],
          ),
        );
        return Container(
          margin: EdgeInsets.symmetric(horizontal: compacto ? 0 : 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: SC.tarjeta(context),
              border: Border.all(color: SC.borde(context)),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.dns_outlined, size: 18, color: SC.azul),
            const SizedBox(width: 8),
            Text(en ? 'Server' : 'Servidor',
                style: TextStyle(color: SC.suave(context), fontSize: 13)),
            const SizedBox(width: 10),
            Expanded(child: dropdown),
          ]),
        );
      },
    );
  }
}
