// ShercoRemoto: language, region and country, chosen on first run, and the
// licence agreement for that region.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../consts.dart';
import '../models/platform_model.dart';
import 'widgets.dart';

const _kRegion = 'shercoremoto-region'; // 'eu' | 'am'
const _kPais = 'shercoremoto-pais'; // ISO code
const _kAcuerdo = 'shercoremoto-acuerdo'; // '<region>-<lang>-v1' once accepted
const _kVersionAcuerdo = 'v1';

bool shercoIngles() =>
    bind.mainGetLocalOption(key: kCommConfKeyLang).toLowerCase().startsWith('en');

/// ISO code -> (Spanish, English) per region.
const Map<String, Map<String, (String, String)>> kShercoPaises = {
  'eu': {
    'ES': ('España', 'Spain'),
    'PT': ('Portugal', 'Portugal'),
    'FR': ('Francia', 'France'),
    'IT': ('Italia', 'Italy'),
    'DE': ('Alemania', 'Germany'),
    'NL': ('Países Bajos', 'Netherlands'),
    'BE': ('Bélgica', 'Belgium'),
    'IE': ('Irlanda', 'Ireland'),
    'AT': ('Austria', 'Austria'),
    'CH': ('Suiza', 'Switzerland'),
    'AD': ('Andorra', 'Andorra'),
    'GB': ('Reino Unido', 'United Kingdom'),
  },
  'am': {
    'VE': ('Venezuela', 'Venezuela'),
    'CO': ('Colombia', 'Colombia'),
    'MX': ('México', 'Mexico'),
    'AR': ('Argentina', 'Argentina'),
    'CL': ('Chile', 'Chile'),
    'PE': ('Perú', 'Peru'),
    'EC': ('Ecuador', 'Ecuador'),
    'PA': ('Panamá', 'Panama'),
    'DO': ('República Dominicana', 'Dominican Republic'),
    'CR': ('Costa Rica', 'Costa Rica'),
    'GT': ('Guatemala', 'Guatemala'),
    'UY': ('Uruguay', 'Uruguay'),
    'PY': ('Paraguay', 'Paraguay'),
    'BO': ('Bolivia', 'Bolivia'),
    'BR': ('Brasil', 'Brazil'),
    'PR': ('Puerto Rico', 'Puerto Rico'),
    'US': ('Estados Unidos', 'United States'),
    'CA': ('Canadá', 'Canada'),
  },
};

String shercoNombreRegion(String r, bool en) =>
    r == 'eu' ? (en ? 'Europe' : 'Europa') : (en ? 'Americas' : 'Américas');

/// "Europa · España", or '' before the first-run setup.
String shercoEtiquetaRegion() {
  final r = bind.mainGetLocalOption(key: _kRegion);
  final p = bind.mainGetLocalOption(key: _kPais);
  final pais = kShercoPaises[r]?[p];
  if (pais == null) return '';
  final en = shercoIngles();
  return '${shercoNombreRegion(r, en)} · ${en ? pais.$2 : pais.$1}';
}

bool shercoNecesitaConfigurar() {
  final r = bind.mainGetLocalOption(key: _kRegion);
  final lang = shercoIngles() ? 'en' : 'es';
  return r.isEmpty ||
      bind.mainGetLocalOption(key: _kAcuerdo) != '$r-$lang-$_kVersionAcuerdo';
}

/// First-run wizard: language, region + country, then the agreement.
class ShercoPrimerArranque extends StatefulWidget {
  final VoidCallback onListo;
  const ShercoPrimerArranque({super.key, required this.onListo});
  @override
  State<ShercoPrimerArranque> createState() => _ShercoPrimerArranqueState();
}

class _ShercoPrimerArranqueState extends State<ShercoPrimerArranque> {
  int _paso = 0;
  late bool _en = shercoIngles();
  late String _region = _inicialRegion();
  late String _pais = _inicialPais();
  bool _acepto = false;
  String _texto = '';

  String _inicialRegion() {
    final r = bind.mainGetLocalOption(key: _kRegion);
    return r.isEmpty ? 'eu' : r;
  }

  String _inicialPais() {
    final p = bind.mainGetLocalOption(key: _kPais);
    return kShercoPaises[_region]!.containsKey(p) ? p : kShercoPaises[_region]!.keys.first;
  }

  String t(String es, String en) => _en ? en : es;

  Future<void> _cargarAcuerdo() async {
    final f = 'assets/eula_${_region}_${_en ? 'en' : 'es'}.txt';
    try {
      final s = await rootBundle.loadString(f);
      if (mounted) setState(() => _texto = s);
    } catch (_) {
      if (mounted) setState(() => _texto = f);
    }
  }

  Future<void> _terminar() async {
    final lang = _en ? 'en' : 'es';
    await bind.mainSetLocalOption(key: _kRegion, value: _region);
    await bind.mainSetLocalOption(key: _kPais, value: _pais);
    await bind.mainSetLocalOption(key: _kAcuerdo, value: '$_region-$lang-$_kVersionAcuerdo');
    if (bind.mainGetLocalOption(key: kCommConfKeyLang) != lang) {
      await bind.mainSetLocalOption(key: kCommConfKeyLang, value: lang);
      bind.mainChangeLanguage(lang: lang);
    }
    widget.onListo();
  }

  Widget _opcion(String texto, bool sel, VoidCallback onTap) => Material(
        color: sel ? const Color(0xFFF0F6FF) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: sel ? SC.azul : const Color(0xFFC8D3E6), width: sel ? 2 : 1)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: sel ? SC.azul : const Color(0xFF8A96AD), size: 20),
              const SizedBox(width: 10),
              Text(texto,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF14213D))),
            ]),
          ),
        ),
      );

  Widget _contenido() {
    switch (_paso) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Idioma / Language',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF14213D))),
          const SizedBox(height: 16),
          _opcion('Español', !_en, () => setState(() => _en = false)),
          const SizedBox(height: 10),
          _opcion('English', _en, () => setState(() => _en = true)),
          const SizedBox(height: 14),
          Text(
              t('La aplicación y el acuerdo de licencia usarán este idioma. Podrás cambiarlo después en Ajustes.',
                  'The app and the license agreement will use this language. You can change it later in Settings.'),
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF56627A))),
        ]);
      case 1:
        final paises = kShercoPaises[_region]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Región y país', 'Region and country'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF14213D))),
          const SizedBox(height: 16),
          Row(children: [
            for (final r in ['eu', 'am']) ...[
              Expanded(
                  child: _opcion(shercoNombreRegion(r, _en), _region == r, () {
                setState(() {
                  _region = r;
                  _pais = kShercoPaises[r]!.keys.first;
                });
              })),
              if (r == 'eu') const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 16),
          Text(t('País', 'Country'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF3A4660))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _pais,
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 15, color: Color(0xFF14213D)),
            decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
            items: [
              for (final e in paises.entries)
                DropdownMenuItem(value: e.key, child: Text(_en ? e.value.$2 : e.value.$1)),
            ],
            onChanged: (v) => setState(() => _pais = v ?? _pais),
          ),
          const SizedBox(height: 14),
          Text(
              t('La región decide qué acuerdo de licencia se aplica. La región y el país aparecerán arriba en la aplicación.',
                  'The region decides which license agreement applies. Region and country will be shown at the top of the app.'),
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF56627A))),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${t('Acuerdo de licencia', 'License agreement')} · ${shercoNombreRegion(_region, _en)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF14213D))),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDE5F2))),
              child: SingleChildScrollView(
                child: SelectableText(_texto,
                    style: const TextStyle(fontSize: 12.5, height: 1.55, color: Color(0xFF3A4660))),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _acepto,
            onChanged: (v) => setState(() => _acepto = v == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: SC.azul,
            title: Text(t('He leído y acepto el acuerdo de licencia', 'I have read and accept the license agreement'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF14213D))),
          ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultimo = _paso == 2;
    return Container(
      color: SC.navy,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: SC.navy,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Text(t('Configurar ShercoRemoto', 'Set up ShercoRemoto'),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(t('Paso ${_paso + 1} de 3', 'Step ${_paso + 1} of 3'),
                    style: const TextStyle(color: Color(0xFFC9D6EE), fontSize: 12)),
              ]),
            ),
            Expanded(child: Padding(padding: const EdgeInsets.all(24), child: _contenido())),
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE5F2)))),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                if (_paso > 0)
                  OutlinedButton(
                      onPressed: () => setState(() => _paso--),
                      child: Text(t('Atrás', 'Back'))),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: SC.azul),
                  onPressed: ultimo && !_acepto
                      ? null
                      : () async {
                          if (ultimo) {
                            await _terminar();
                          } else {
                            setState(() => _paso++);
                            if (_paso == 2) await _cargarAcuerdo();
                          }
                        },
                  child: Text(ultimo ? t('Aceptar y continuar', 'Accept and continue') : t('Siguiente', 'Next')),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
