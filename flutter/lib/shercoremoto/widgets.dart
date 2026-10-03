// ShercoRemoto: shared look (colors, icons, loading ring).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'iconos_data.dart';

class SC {
  static const navy = Color(0xFF0B2B66);
  static const azul = Color(0xFF1673E0);
  static const azulOscuro = Color(0xFF0E4BB0);
  static const celeste = Color(0xFF39D0FF);
  static const verde = Color(0xFF1E9E5A);
  static const gris = Color(0xFFA3AEC2);

  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color fondo(BuildContext c) => dark(c) ? const Color(0xFF0E1626) : const Color(0xFFF3F6FB);
  static Color tarjeta(BuildContext c) => dark(c) ? const Color(0xFF152036) : Colors.white;
  static Color borde(BuildContext c) => dark(c) ? const Color(0xFF26334D) : const Color(0xFFDDE5F2);
  static Color texto(BuildContext c) => dark(c) ? const Color(0xFFE6ECF7) : const Color(0xFF14213D);
  static Color suave(BuildContext c) => dark(c) ? const Color(0xFF9AA8C2) : const Color(0xFF56627A);
  static Color chip(BuildContext c) => dark(c) ? const Color(0xFF1B3358) : const Color(0xFFE8F0FD);
}

String _hex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// One of the 53 icons by name; unknown names fall back to "Monitor".
class ShercoIcono extends StatelessWidget {
  final String nombre;
  final double size;
  final Color color;
  final double grosor;
  const ShercoIcono(this.nombre,
      {super.key, this.size = 20, required this.color, this.grosor = 1.8});

  @override
  Widget build(BuildContext context) {
    final d = kShercoIconos[nombre] ?? kShercoIconos['Monitor']!;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="${_hex(color)}" stroke-width="$grosor" stroke-linecap="round" '
      'stroke-linejoin="round"><path d="$d"/></svg>',
      width: size,
      height: size,
    );
  }
}

/// Logo with a spinning ring around it (app start and remote connection).
class ShercoAnillo extends StatefulWidget {
  final double size;
  const ShercoAnillo({super.key, this.size = 168});
  @override
  State<ShercoAnillo> createState() => _ShercoAnilloState();
}

class _ShercoAnilloState extends State<ShercoAnillo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce && _c.duration != const Duration(seconds: 3)) {
      _c.duration = const Duration(seconds: 3);
      _c.repeat();
    }
    return SizedBox(
      width: s,
      height: s,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(s, s), painter: _AnilloPainter(null)),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
              size: Size(s, s), painter: _AnilloPainter(_c.value)),
        ),
        SvgPicture.asset('assets/icon.svg', width: s * 0.57, height: s * 0.57),
      ]),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  final double? t;
  _AnilloPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.048;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    if (t == null) {
      p.color = Colors.white.withOpacity(0.12);
      canvas.drawArc(rect, 0, math.pi * 2, false, p);
    } else {
      p.color = SC.celeste;
      canvas.drawArc(rect, t! * math.pi * 2 - math.pi / 2, math.pi * 0.55, false, p);
    }
  }

  @override
  bool shouldRepaint(_AnilloPainter old) => old.t != t;
}

/// Full-window loading view: ring, app name and a pulsing status line.
class ShercoCargando extends StatefulWidget {
  final String texto;
  final String? subtitulo;
  final VoidCallback? onCancel;
  const ShercoCargando(
      {super.key, required this.texto, this.subtitulo, this.onCancel});
  @override
  State<ShercoCargando> createState() => _ShercoCargandoState();
}

class _ShercoCargandoState extends State<ShercoCargando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SC.navy,
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ShercoAnillo(),
        const SizedBox(height: 28),
        Text.rich(
          const TextSpan(children: [
            TextSpan(text: 'Sherco', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(
                text: 'Remoto',
                style: TextStyle(fontWeight: FontWeight.w400, color: Color(0xFF9CCBFF))),
          ]),
          style: const TextStyle(fontSize: 26, color: Colors.white),
        ),
        const SizedBox(height: 8),
        FadeTransition(
          opacity: Tween(begin: 0.55, end: 1.0).animate(_p),
          child: Text(widget.texto,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFC9D6EE))),
        ),
        if (widget.subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(widget.subtitulo!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9DB0D3))),
        ],
        if (widget.onCancel != null) ...[
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x59FFFFFF)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
            child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

/// Start screen: the loading view while the ShercoIT session is restored
/// (at least [minimo], at most [maximo]), then [child].
class ShercoArranque extends StatefulWidget {
  final Widget child;
  final Future<void> Function() tarea;
  final Duration minimo, maximo;
  const ShercoArranque(
      {super.key,
      required this.child,
      required this.tarea,
      this.minimo = const Duration(milliseconds: 2800),
      this.maximo = const Duration(seconds: 6)});
  @override
  State<ShercoArranque> createState() => _ShercoArranqueState();
}

class _ShercoArranqueState extends State<ShercoArranque> {
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    Future.wait([
      Future.delayed(widget.minimo),
      widget.tarea().timeout(widget.maximo, onTimeout: () {}).catchError((_) {}),
    ]).whenComplete(() {
      if (mounted) setState(() => _listo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _listo
          ? widget.child
          : const ShercoCargando(
              key: ValueKey('arranque'),
              texto: 'Conectando con el servidor de ShercoIT…'),
    );
  }
}
