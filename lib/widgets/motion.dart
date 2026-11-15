import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Token gerak ala Material 3 Expressive.
class Motion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration slower = Duration(milliseconds: 560);

  /// Kurva standar M3 (emphasized decelerate) untuk masuk.
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1);

  /// Kurva standar untuk keluar / perubahan kecil.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Sedikit "mantul" untuk elemen yang dipilih / diperluas.
  static const Curve spring = SpringCurve(stiffness: 210, damping: 20);
}

/// Kurva berbasis simulasi pegas — memberi kesan M3 Expressive, bukan easing
/// linear biasa.
class SpringCurve extends Curve {
  const SpringCurve({
    this.mass = 1,
    this.stiffness = 180,
    this.damping = 18,
    this.normalize = true,
  });

  final double mass;
  final double stiffness;
  final double damping;
  final bool normalize;

  @override
  double transformInternal(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final simulation = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0,
      1,
      0,
    );
    // Durasi kurva dianggap 1 detik; petakan t ke detik simulasi.
    final x = simulation.x(t * 0.85);
    return normalize ? x.clamp(0.0, 1.0) : x;
  }
}

/// Umpan balik saat elemen ditekan: mengecil sedikit + haptic halus.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.onTap == null ? null : (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: widget.onTap == null ? null : (_) => _setDown(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!.call();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.fast,
        curve: Motion.spring,
        child: widget.child,
      ),
    );
  }
}

/// Muncul dengan fade + naik + skala, delay bertingkat antar item.
class Stagger extends StatelessWidget {
  const Stagger({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.maxDelay = const Duration(milliseconds: 320),
    this.slide = 18,
    this.duration = Motion.slow,
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration maxDelay;
  final double slide;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    // Mode hemat animasi: langsung tampil, tanpa geser/skala.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final raw = step * index;
    final delay = raw > maxDelay ? maxDelay : raw;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: Motion.emphasized,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * slide),
          child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}

/// Angka yang beranimasi saat nilainya berubah (mis. ukuran storage).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = Motion.slow,
    this.curve = Motion.emphasized,
  });

  final num value;
  final String Function(num value) format;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// Transisi "shared axis": konten lama memudar & bergeser, konten baru masuk.
class SharedAxisSwitcher extends StatelessWidget {
  const SharedAxisSwitcher({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.duration = Motion.base,
    this.reverse = false,
  });

  final Widget child;
  final Axis axis;
  final Duration duration;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final offset = axis == Axis.horizontal ? Offset(0.06, 0) : Offset(0, 0.04);
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.standard,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.emphasized,
          reverseCurve: Motion.standard,
        );
        final entering = animation.status != AnimationStatus.reverse;
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: entering
                  ? (reverse ? -offset : offset)
                  : (reverse ? offset : -offset),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// IndexedStack yang menjaga state tiap tab, tapi menganimasikan perpindahan
/// (fade-through + skala halus).
class AnimatedIndexedStack extends StatefulWidget {
  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = Motion.base,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late int _current = widget.index;
  double _direction = 1;

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack old) {
    super.didUpdateWidget(old);
    if (widget.index != _current) {
      _direction = widget.index > _current ? 1 : -1;
      _current = widget.index;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (i != widget.index)
            widget.children[i]
          else
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = Motion.emphasized.transform(_c.value);
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.985 + 0.015 * t,
                    child: Transform.translate(
                      offset: Offset((1 - t) * 14 * _direction, 0),
                      child: child,
                    ),
                  ),
                );
              },
              child: widget.children[i],
            ),
      ],
    );
  }
}

/// Route dengan transisi shared-axis (fade + geser + skala halus) supaya
/// perpindahan antar layar terasa mengalir, bukan "pindah halaman" kaku.
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  SharedAxisPageRoute({
    required this.builder,
    super.settings,
    this.duration = const Duration(milliseconds: 380),
    this.reverseDuration = const Duration(milliseconds: 280),
    this.axis = Axis.vertical,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Motion.emphasized,
              reverseCurve: Motion.standard,
            );
            final begin = axis == Axis.vertical
                ? const Offset(0, 0.05)
                : const Offset(0.05, 0);
            final secondaryCurve = CurvedAnimation(
              parent: secondary,
              curve: Motion.standard,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero)
                    .animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1, end: 0.85)
                        .animate(secondaryCurve),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 1, end: 0.98)
                          .animate(secondaryCurve),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        );

  final WidgetBuilder builder;
  final Duration duration;
  final Duration reverseDuration;
  final Axis axis;
}

/// Transisi halaman untuk `pageTransitionsTheme`: fade + geser kecil di semua
/// platform, sehingga push/pop bawaan pun ikut halus.
class MotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const MotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.emphasized,
      reverseCurve: Motion.standard,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.02, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.99, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// Getaran halus untuk aksi kecil (dipanggil manual).
void tapFeedback() => HapticFeedback.selectionClick();

/// Distorsi skala kecil saat elemen muncul / dipilih.
double popScale(double t) {
  final eased = Motion.spring.transform(t.clamp(0.0, 1.0));
  return 0.94 + 0.06 * eased;
}

/// Pembulatan "squircle" sederhana untuk container besar.
BorderRadius squircle(double radius) => BorderRadius.only(
      topLeft: Radius.circular(radius * 1.02),
      topRight: Radius.circular(radius * 0.98),
      bottomLeft: Radius.circular(radius * 0.98),
      bottomRight: Radius.circular(radius * 1.02),
    );

/// Jarak horisontal antar halaman, dipakai tab bar.
double tabOffset(int from, int to) => (to - from).toDouble() * math.pi;

/// Posisi kartu dialog di layar.
enum DialogAnchor { center, top, bottom }

/// Gaya masuk bottom sheet.
enum SheetVariant {
  /// Pegas naik dari bawah + fade (default).
  slide,

  /// Skala 0.96 → 1 + fade tanpa geser — cocok untuk panel aksi ringkas.
  fadeThrough,
}

/// Rect global sebuah widget, dipakai untuk animasi "tumbuh dari titik tekan".
Rect? globalRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero);
  return origin & box.size;
}

/// Bungkus deretan baris sheet/dialog supaya muncul bertingkat dengan
/// [Stagger]. Dipakai untuk daftar aksi di sheet.
List<Widget> staggered(
  Iterable<Widget> children, {
  int start = 0,
  Duration step = const Duration(milliseconds: 24),
  double slide = 10,
}) {
  final list = children.toList(growable: false);
  return [
    for (var i = 0; i < list.length; i++)
      Stagger(
        index: start + i,
        step: step,
        slide: slide,
        duration: Motion.base,
        child: list[i],
      ),
  ];
}

/// Dialog bergaya "popup" Material Expressive: latar diblur, kartu masuk dengan
/// skala pegas 0.94 → 1 + fade-through, bukan fade datar seperti dialog bawaan.
///
/// [alignment] menentukan arah geser 12 px (ke atas untuk `top`, ke bawah untuk
/// `bottom`, tanpa geser untuk `center`) sekaligus posisi kartu di layar.
Future<T?> showExpressiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  DialogAnchor alignment = DialogAnchor.center,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: reduceMotion ? Motion.fast : Motion.slow,
    pageBuilder: (context, animation, secondaryAnimation) => _DialogPage(
      animation: animation,
      alignment: alignment,
      reduceMotion: reduceMotion,
      builder: builder,
    ),
    transitionBuilder: (context, animation, secondary, child) => child,
  );
}

class _DialogPage extends StatelessWidget {
  const _DialogPage({
    required this.animation,
    required this.alignment,
    required this.reduceMotion,
    required this.builder,
  });

  final Animation<double> animation;
  final DialogAnchor alignment;
  final bool reduceMotion;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    // Fade-through: konten muncul sambil membesar, jadi opacity-nya cepat
    // selesai sebelum skala pegasnya mendarat.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Motion.emphasized),
      reverseCurve: Motion.standard,
    );
    final spring = CurvedAnimation(
      parent: animation,
      curve: Motion.spring,
      reverseCurve: Motion.standard,
    );
    final scrim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: Motion.standard),
      reverseCurve: Motion.standard,
    );

    final anchor = switch (alignment) {
      DialogAnchor.center => Alignment.center,
      DialogAnchor.top => const Alignment(0, -0.72),
      DialogAnchor.bottom => const Alignment(0, 0.72),
    };
    final dy = switch (alignment) {
      DialogAnchor.center => 0.0,
      DialogAnchor.top => -12.0,
      DialogAnchor.bottom => 12.0,
    };

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: scrim,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
              ),
            ),
          ),
        ),
        Align(
          alignment: anchor,
          child: AnimatedBuilder(
            animation: spring,
            builder: (context, child) {
              final t = spring.value.clamp(0.0, 1.0);
              final scale = reduceMotion ? 1.0 : 0.94 + 0.06 * t;
              final offset = reduceMotion ? 0.0 : dy * (1 - t);
              return Opacity(
                opacity: reduceMotion ? fade.value : t,
                child: Transform.translate(
                  offset: Offset(0, offset),
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
            // AlertDialog/Dialog mengisi layar lalu memusatkan kartunya sendiri,
            // jadi posisinya diatur lewat dialogTheme agar [alignment] berlaku.
            child: Theme(
              data: Theme.of(context).copyWith(
                dialogTheme:
                    Theme.of(context).dialogTheme.copyWith(alignment: anchor),
              ),
              child: builder(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet dengan kurva pegas + latar diblur, meniru rasa popup iOS.
///
/// [variant] memilih gaya masuk: [SheetVariant.slide] (naik + fade) atau
/// [SheetVariant.fadeThrough] (skala + fade tanpa geser). Kalau [origin]
/// diberikan (biasanya rect widget yang ditekan), sheet tumbuh dari titik itu
/// — pendekatan kasar "container transform" tanpa Hero.
Future<T?> showExpressiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  SheetVariant variant = SheetVariant.slide,
  Rect? origin,
  bool barrierDismissible = true,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final duration = reduceMotion
      ? Motion.fast
      : (variant == SheetVariant.slide ? Motion.slow : Motion.base);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => _SheetPage(
      animation: animation,
      variant: variant,
      origin: origin,
      reduceMotion: reduceMotion,
      useSafeArea: useSafeArea,
      builder: builder,
    ),
    transitionBuilder: (context, animation, secondary, child) => child,
  );
}

class _SheetPage extends StatefulWidget {
  const _SheetPage({
    required this.animation,
    required this.variant,
    required this.origin,
    required this.reduceMotion,
    required this.useSafeArea,
    required this.builder,
  });

  final Animation<double> animation;
  final SheetVariant variant;
  final Rect? origin;
  final bool reduceMotion;
  final bool useSafeArea;
  final WidgetBuilder builder;

  @override
  State<_SheetPage> createState() => _SheetPageState();
}

class _SheetPageState extends State<_SheetPage> {
  double _drag = 0;

  void _onDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (_drag > 90 || v > 650) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    final variant = widget.variant;
    final origin = widget.origin;
    final reduceMotion = widget.reduceMotion;
    final useSafeArea = widget.useSafeArea;
    final builder = widget.builder;
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.75, curve: Motion.emphasized),
      reverseCurve: Motion.standard,
    );
    final spring = CurvedAnimation(
      parent: animation,
      curve: Motion.spring,
      reverseCurve: Motion.standard,
    );
    final scrim = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: Motion.standard),
      reverseCurve: Motion.standard,
    );

    final surface = Transform.translate(
      offset: Offset(0, _drag),
      child: GestureDetector(
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (d) => setState(() {
          _drag = (_drag + d.delta.dy).clamp(0.0, 400.0);
        }),
        onVerticalDragEnd: _onDragEnd,
        child: Opacity(
          opacity: (1 - _drag / 400).clamp(0.4, 1.0),
          child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: useSafeArea
            // Ruang ekstra di bawah supaya baris terakhir tidak menempel ke
            // gesture bar / tepi layar.
            ? SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  // Napas di atas & bawah isi sheet; konten sheet sendiri
                  // tidak lagi menempel ke sudut lengkung.
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
                  child: builder(context),
                ),
              )
            : builder(context),
      ),
        ),
      ),
      ),
    );

    Widget motion;
    if (reduceMotion) {
      // Mode tanpa animasi: cukup fade singkat, tanpa geser/skala.
      motion = FadeTransition(opacity: scrim, child: surface);
    } else if (origin != null) {
      motion = _OriginGrow(
        origin: origin!,
        animation: spring,
        fade: fade,
        child: surface,
      );
    } else if (variant == SheetVariant.fadeThrough) {
      motion = AnimatedBuilder(
        animation: spring,
        builder: (context, child) {
          final t = spring.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: fade.value,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
            ),
          );
        },
        child: surface,
      );
    } else {
      motion = AnimatedBuilder(
        animation: spring,
        builder: (context, child) {
          final t = spring.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: fade.value,
            child: Transform.translate(
              offset: Offset(0, 72 * (1 - t)),
              child: child,
            ),
          );
        },
        child: surface,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: scrim,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.34)),
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: motion),
      ],
    );
  }
}

/// Sheet yang tumbuh dari rect [origin] (mis. baris yang ditekan): pusat sheet
/// dimulai di pusat rect itu dengan skala 0.9, lalu mengembang ke tempatnya.
class _OriginGrow extends StatefulWidget {
  const _OriginGrow({
    required this.origin,
    required this.animation,
    required this.fade,
    required this.child,
  });

  final Rect origin;
  final Animation<double> animation;
  final Animation<double> fade;
  final Widget child;

  @override
  State<_OriginGrow> createState() => _OriginGrowState();
}

class _OriginGrowState extends State<_OriginGrow> {
  final GlobalKey _box = GlobalKey();
  Size _size = Size.zero;
  Offset _global = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final box = _box.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final size = box.size;
    final global = box.localToGlobal(Offset.zero);
    if (size == _size && global == _global) return;
    setState(() {
      _size = size;
      _global = global;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _box,
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: (context, child) {
          final t = widget.animation.value.clamp(0.0, 1.0);
          if (_size.isEmpty) {
            return Opacity(opacity: widget.fade.value, child: child);
          }
          final centre = Offset(_size.width / 2, _size.height / 2);
          final from = widget.origin.center - _global;
          final delta = (from - centre) * (1 - t);
          return Opacity(
            opacity: widget.fade.value,
            child: Transform.translate(
              offset: delta,
              child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
