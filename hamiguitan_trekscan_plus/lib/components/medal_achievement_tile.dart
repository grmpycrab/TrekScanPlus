import 'package:flutter/material.dart';

// ── MedalTier ─────────────────────────────────────────────────────────────────

enum MedalTier { bronze, silver, gold, platinum }

extension MedalTierX on MedalTier {
  String get displayName {
    switch (this) {
      case MedalTier.bronze:   return 'Bronze';
      case MedalTier.silver:   return 'Silver';
      case MedalTier.gold:     return 'Gold';
      case MedalTier.platinum: return 'Platinum';
    }
  }
}

MedalTier medalTierFromString(String value) {
  switch (value.toLowerCase()) {
    case 'silver':   return MedalTier.silver;
    case 'gold':     return MedalTier.gold;
    case 'platinum': return MedalTier.platinum;
    default:         return MedalTier.bronze;
  }
}

// ── Tier palettes (metallic light simulation) ─────────────────────────────────

class _Palette {
  final List<Color> ribbon;
  final List<Color> rim;
  final List<Color> face;
  final Color highlight;
  final Color deep;

  const _Palette({
    required this.ribbon,
    required this.rim,
    required this.face,
    required this.highlight,
    required this.deep,
  });
}

_Palette _paletteFor(MedalTier tier) {
  switch (tier) {
    case MedalTier.silver:
      return const _Palette(
        ribbon: [Color(0xFF6E7E8F), Color(0xFFD0D8E4), Color(0xFF8E9AAF)],
        rim: [Color(0xFFDDE3EA), Color(0xFFB8C2CC), Color(0xFF8E9AAF), Color(0xFFD4D9E0)],
        face: [Color(0xFFCDD4DC), Color(0xFFECF0F4), Color(0xFF9AAABB)],
        highlight: Color(0xFFF6F8FA),
        deep: Color(0xFF3A4A58),
      );
    case MedalTier.gold:
      return const _Palette(
        ribbon: [Color(0xFF996515), Color(0xFFFFD700), Color(0xFFB8860B)],
        rim: [Color(0xFFFFF0A0), Color(0xFFFFD700), Color(0xFFB8860B), Color(0xFFFFE566)],
        face: [Color(0xFFFFCC00), Color(0xFFFFF4B0), Color(0xFFCC9900)],
        highlight: Color(0xFFFFFDE8),
        deep: Color(0xFF6A4500),
      );
    case MedalTier.platinum:
      return const _Palette(
        ribbon: [Color(0xFF4C1D95), Color(0xFFBB8FFF), Color(0xFF7C3AED)],
        rim: [Color(0xFFE9D5FF), Color(0xFF9B59D6), Color(0xFF6D28D9), Color(0xFFD4B0FF)],
        face: [Color(0xFFBB8FFF), Color(0xFFEDD5FF), Color(0xFF8B5CF6)],
        highlight: Color(0xFFF8F0FF),
        deep: Color(0xFF1E0A60),
      );
    case MedalTier.bronze:
      return const _Palette(
        ribbon: [Color(0xFF7A4010), Color(0xFFE8A060), Color(0xFF9A5C1A)],
        rim: [Color(0xFFF0C090), Color(0xFFCD7F32), Color(0xFF9A5C1A), Color(0xFFE8A060)],
        face: [Color(0xFFD4843A), Color(0xFFF4C080), Color(0xFFAA5A18)],
        highlight: Color(0xFFFFF0E0),
        deep: Color(0xFF4A1800),
      );
  }
}

// BT.709 luminance coefficients — Skia colour-matrix pipeline (hardware-accelerated)
const _kGreyscaleMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
];

// ── MedalAchievementTile ──────────────────────────────────────────────────────
//
// Atomic reusable component shared by the badge grid (badge_display.dart) and
// the profile achievement overlay (profile_screen.dart).
//
// Layout (top → bottom):
//   1. Multi-tone woven fabric suspension ribbon  [showRibbon]
//      — middle stop blended from Theme.colorScheme.primary
//   2. Geometric anchor split-ring loop connector [showRibbon]
//   3. Multi-layer stamped-coin metallic disk     [always]
//      — SweepGradient rim + angled face + radial intaglio + specular arc
//
// Locked state: BT.709 greyscale ColorFiltered wrapper + static alpha overlay.
// No BackdropFilter / ImageFilter used — 120Hz scroll-safe.

class MedalAchievementTile extends StatelessWidget {
  const MedalAchievementTile({
    super.key,
    required this.tier,
    required this.icon,
    required this.label,
    required this.isLocked,
    this.diskSize = 44,
    this.showRibbon = true,
  });

  final MedalTier tier;
  final IconData icon;
  final String label;
  final bool isLocked;
  final double diskSize;
  final bool showRibbon;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final p = _paletteFor(tier);

    return Semantics(
      label: label,
      child: RepaintBoundary(
        child: ColorFiltered(
          colorFilter: isLocked
              ? const ColorFilter.matrix(_kGreyscaleMatrix)
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showRibbon) ...[
                _Ribbon(palette: p, themeColor: primary, diskSize: diskSize),
                _Loop(palette: p, diskSize: diskSize),
              ],
              _Disk(palette: p, icon: icon, diskSize: diskSize),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ribbon ────────────────────────────────────────────────────────────────────
// Multi-stop lateral gradient: outer stops from tier palette, middle stop from
// Theme.colorScheme.primary so the ribbon stays on-brand across app themes.

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.palette,
    required this.themeColor,
    required this.diskSize,
  });

  final _Palette palette;
  final Color themeColor;
  final double diskSize;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final w = diskSize * 0.30;
    final h = diskSize * 0.22;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            p.ribbon[2],
            themeColor.withValues(alpha: 0.85),
            p.ribbon[1],
            themeColor.withValues(alpha: 0.75),
            p.ribbon[2],
          ],
          stops: const [0.0, 0.20, 0.50, 0.80, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: p.deep.withValues(alpha: 0.30),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
          BoxShadow(
            color: p.highlight.withValues(alpha: 0.22),
            blurRadius: 1,
            offset: const Offset(-0.5, -0.5),
          ),
        ],
      ),
    );
  }
}

// ── Loop ──────────────────────────────────────────────────────────────────────
// Oval ring connector (anchor split-ring geometry).

class _Loop extends StatelessWidget {
  const _Loop({required this.palette, required this.diskSize});

  final _Palette palette;
  final double diskSize;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final w = diskSize * 0.14;
    final h = diskSize * 0.11;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(w * 0.5),
        border: Border.all(color: p.rim[0], width: diskSize * 0.025),
        boxShadow: [
          BoxShadow(
            color: p.deep.withValues(alpha: 0.50),
            blurRadius: 3,
            offset: const Offset(0.5, 1.5),
          ),
          BoxShadow(
            color: p.highlight.withValues(alpha: 0.45),
            blurRadius: 1.5,
            offset: const Offset(-0.5, -0.5),
          ),
        ],
      ),
    );
  }
}

// ── Disk ──────────────────────────────────────────────────────────────────────
// Five-layer stamped-coin disc:
//   1. SweepGradient outer rim  — rotates specular around circumference
//   2. Linear-gradient convex face — primary light path across surface
//   3. RadialGradient recessed field — intaglio relief (deepens at rim)
//   4. Embossed icon
//   5. Specular glint arc (IgnorePointer, top-left)

class _Disk extends StatelessWidget {
  const _Disk({
    required this.palette,
    required this.icon,
    required this.diskSize,
  });

  final _Palette palette;
  final IconData icon;
  final double diskSize;

  @override
  Widget build(BuildContext context) {
    final s = diskSize;
    final p = palette;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer 1 — outer metallic rim
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [...p.rim, p.rim.first],
                stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.deep.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(2, 5),
                ),
                BoxShadow(
                  color: p.highlight.withValues(alpha: 0.40),
                  blurRadius: 5,
                  offset: const Offset(-2, -2),
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(3, 7),
                ),
              ],
            ),
          ),
          // Layer 2 — raised convex face
          Container(
            width: s * 0.80,
            height: s * 0.80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: const Alignment(-0.65, -0.85),
                end: const Alignment(0.65, 0.85),
                colors: p.face,
              ),
              boxShadow: [
                BoxShadow(
                  color: p.deep.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(1.5, 2.5),
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: p.highlight.withValues(alpha: 0.60),
                  blurRadius: 3,
                  offset: const Offset(-1.5, -1.5),
                  spreadRadius: -1,
                ),
              ],
            ),
          ),
          // Layer 3 — recessed intaglio field
          Container(
            width: s * 0.58,
            height: s * 0.58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.20, -0.30),
                radius: 0.95,
                colors: [
                  p.face[1].withValues(alpha: 0.90),
                  p.face[0].withValues(alpha: 0.80),
                  p.deep.withValues(alpha: 0.22),
                ],
                stops: const [0.0, 0.60, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.deep.withValues(alpha: 0.45),
                  blurRadius: 5,
                  spreadRadius: 1,
                  offset: const Offset(1, 1.5),
                ),
              ],
            ),
          ),
          // Layer 4 — embossed icon
          Icon(icon, size: s * 0.30, color: p.highlight),
          // Layer 5 — specular glint arc
          Positioned(
            top: s * 0.09,
            left: s * 0.14,
            child: IgnorePointer(
              child: Container(
                width: s * 0.26,
                height: s * 0.08,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(s * 0.04),
                  gradient: LinearGradient(
                    colors: [
                      p.highlight.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
