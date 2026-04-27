import 'package:flutter/material.dart';

/// Aurora design system tokens — ported verbatim from styles.css.
/// Seed: #5B43D6 deep purple. macOS-density M3 reinterpretation.
class AuroraTokens {
  AuroraTokens._();

  // ---- Primary tonal palette ----
  static const p10 = Color(0xFF1D0A66);
  static const p20 = Color(0xFF2F1A8A);
  static const p25 = Color(0xFF3B22A0);
  static const p30 = Color(0xFF462DB6);
  static const p35 = Color(0xFF5239C5);
  static const p40 = Color(0xFF5B43D6); // seed
  static const p50 = Color(0xFF7560E3);
  static const p60 = Color(0xFF8E7DF0);
  static const p70 = Color(0xFFA89AFA);
  static const p80 = Color(0xFFC5BCFF);
  static const p90 = Color(0xFFE3DDFF);
  static const p95 = Color(0xFFF3EEFF);
  static const p98 = Color(0xFFFBF8FF);
  static const p99 = Color(0xFFFEFBFF);

  // ---- Secondary (muted purple-grey) ----
  static const s10 = Color(0xFF1C1830);
  static const s20 = Color(0xFF322D46);
  static const s30 = Color(0xFF494360);
  static const s40 = Color(0xFF615B78);
  static const s50 = Color(0xFF7A7392);
  static const s60 = Color(0xFF948DAD);
  static const s70 = Color(0xFFAFA7C8);
  static const s80 = Color(0xFFCAC2E4);
  static const s90 = Color(0xFFE6DFF8);
  static const s95 = Color(0xFFF4EEFF);

  // ---- Tertiary (warm rose) ----
  static const t10 = Color(0xFF2E1126);
  static const t20 = Color(0xFF46263C);
  static const t30 = Color(0xFF5F3C54);
  static const t40 = Color(0xFF79526C);
  static const t50 = Color(0xFF946A86);
  static const t60 = Color(0xFFB083A1);
  static const t70 = Color(0xFFCD9DBC);
  static const t80 = Color(0xFFEBB7D9);
  static const t90 = Color(0xFFFFD8EC);

  // ---- Neutral (cool, slight purple tint) ----
  static const n4 = Color(0xFF0C0B10);
  static const n6 = Color(0xFF121117);
  static const n10 = Color(0xFF1C1B1F);
  static const n12 = Color(0xFF211F24);
  static const n17 = Color(0xFF2B292E);
  static const n20 = Color(0xFF313034);
  static const n22 = Color(0xFF36343A);
  static const n24 = Color(0xFF3A383E);
  static const n30 = Color(0xFF48464C);
  static const n40 = Color(0xFF605E64);
  static const n50 = Color(0xFF79767D);
  static const n60 = Color(0xFF938F97);
  static const n70 = Color(0xFFAEAAB1);
  static const n80 = Color(0xFFC9C5CD);
  static const n87 = Color(0xFFDDD9E0);
  static const n90 = Color(0xFFE6E1E8);
  static const n92 = Color(0xFFECE7EE);
  static const n94 = Color(0xFFF1EDF4);
  static const n95 = Color(0xFFF4EFF7);
  static const n96 = Color(0xFFF7F2FA);
  static const n98 = Color(0xFFFCF8FD);
  static const n100 = Color(0xFFFFFFFF);

  // ---- Neutral variant ----
  static const nv30 = Color(0xFF49454F);
  static const nv50 = Color(0xFF79747E);
  static const nv60 = Color(0xFF938F99);
  static const nv80 = Color(0xFFCAC4D0);
  static const nv90 = Color(0xFFE7E0EC);

  // ---- Error ----
  static const e10 = Color(0xFF410002);
  static const e20 = Color(0xFF690005);
  static const e30 = Color(0xFF93000A);
  static const e40 = Color(0xFFBA1A1A);
  static const e50 = Color(0xFFDE3730);
  static const e60 = Color(0xFFFF5449);
  static const e70 = Color(0xFFFF897D);
  static const e80 = Color(0xFFFFB4AB);
  static const e90 = Color(0xFFFFDAD6);

  // ---- Level: Scrub (emerald) ----
  static const scrub30 = Color(0xFF006D3B);
  static const scrub40 = Color(0xFF008A4C);
  static const scrub50 = Color(0xFF1BA864);
  static const scrub80 = Color(0xFF71F2A6);
  static const scrub90 = Color(0xFF95FFC0);
  static const scrub95 = Color(0xFFC8FFD9);

  // ---- Level: Boilwash (amber) ----
  static const boil30 = Color(0xFF6F4400);
  static const boil40 = Color(0xFF8E5800);
  static const boil50 = Color(0xFFAD6E00);
  static const boil80 = Color(0xFFFFBA47);
  static const boil90 = Color(0xFFFFDDAE);
  static const boil95 = Color(0xFFFFEFD8);

  // ---- Level: Sandblast (crimson) ----
  static const sand30 = Color(0xFF8C0D20);
  static const sand40 = Color(0xFFB1252D);
  static const sand50 = Color(0xFFD33B40);
  static const sand80 = Color(0xFFFFB3B0);
  static const sand90 = Color(0xFFFFDAD7);
  static const sand95 = Color(0xFFFFEDEB);

  // ---- Level: Development (violet sibling of seed) ----
  static const dev30 = Color(0xFF4E2A8E);
  static const dev40 = Color(0xFF6741B6);
  static const dev50 = Color(0xFF815CD0);
  static const dev80 = Color(0xFFCABDFF);
  static const dev90 = Color(0xFFE7DEFF);
  static const dev95 = Color(0xFFF5EEFF);

  // ---- Shape ----
  static const shapeXs = 4.0;
  static const shapeSm = 8.0;
  static const shapeMd = 10.0;
  static const shapeLg = 12.0;
  static const shapeXl = 16.0;
  static const shapeFull = 999.0;

  // ---- Spacing ----
  static const sp1 = 4.0;
  static const sp2 = 8.0;
  static const sp3 = 12.0;
  static const sp4 = 16.0;
  static const sp5 = 20.0;
  static const sp6 = 24.0;
  static const sp7 = 32.0;
  static const sp8 = 40.0;
  static const sp9 = 56.0;
  static const sp10 = 72.0;

  // ---- Motion ----
  static const dShort1 = Duration(milliseconds: 50);
  static const dShort2 = Duration(milliseconds: 100);
  static const dShort4 = Duration(milliseconds: 200);
  static const dMedium2 = Duration(milliseconds: 300);
  static const dLong1 = Duration(milliseconds: 450);

  static const standardEasing = Cubic(0.2, 0, 0, 1);
}

/// Surface elevations expressed as ambient shadows.
class AuroraShadows {
  AuroraShadows._();

  static const light1 = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const light2 = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const light3 = <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const dark1 = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x52000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const dark2 = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x5C000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const dark3 = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x5C000000), blurRadius: 6, offset: Offset(0, 2)),
  ];
}
