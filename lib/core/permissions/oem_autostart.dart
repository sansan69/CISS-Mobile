/// Vendor-specific background-survival recipes.
///
/// Android sandboxes background execution differently on every Chinese OEM
/// build, so the same "allow CISS to keep running" instruction cannot be
/// written once. The sibling CISS-AMS app carries this guidance as
/// manufacturer branches (a Huawei "Protected App" dialog, an Oppo permission
/// prompt, REA evidence `ev_ac973383…`); this table replaces those branches
/// with data so the copy stays translatable and testable.
///
/// [OemGuide.component] is the settings package the native bridge targets.
/// Opening it still goes through `DeviceCompatService`, which already falls
/// back to the app detail screen when the vendor component is missing.
class OemGuide {
  const OemGuide({
    required this.manufacturer,
    required this.brand,
    required this.aliases,
    required this.pathKey,
    this.component,
  });

  /// Canonical key for this vendor, e.g. `xiaomi`.
  final String manufacturer;

  /// Display label used inside the guide copy, e.g. `Xiaomi`.
  final String brand;

  /// `Build.MANUFACTURER` values (lower-cased substrings) that map here.
  final List<String> aliases;

  /// [AppStrings] key for the settings path a user must walk.
  final String pathKey;

  /// Settings package the native bridge opens, when the vendor has one.
  final String? component;

  bool get hasComponent => component != null;

  /// Ordered steps: the vendor path, then the actions that are the same on
  /// every brand.
  List<String> get stepKeys => <String>[
    pathKey,
    'readinessOemStepSelect',
    'readinessOemStepUnrestrict',
    'readinessOemStepVerify',
  ];
}

/// Every vendor the app can walk the user through.
const List<OemGuide> oemGuides = <OemGuide>[
  OemGuide(
    manufacturer: 'xiaomi',
    brand: 'Xiaomi',
    aliases: <String>['xiaomi', 'redmi', 'poco'],
    pathKey: 'readinessOemPathXiaomi',
    component: 'com.miui.securitycenter',
  ),
  OemGuide(
    manufacturer: 'oppo',
    brand: 'Oppo',
    aliases: <String>['oppo', 'realme'],
    pathKey: 'readinessOemPathOppo',
    component: 'com.coloros.safecenter',
  ),
  OemGuide(
    manufacturer: 'oneplus',
    brand: 'OnePlus',
    aliases: <String>['oneplus'],
    pathKey: 'readinessOemPathOnePlus',
    component: 'com.oneplus.security',
  ),
  OemGuide(
    manufacturer: 'vivo',
    brand: 'Vivo',
    aliases: <String>['vivo', 'iqoo'],
    pathKey: 'readinessOemPathVivo',
    component: 'com.vivo.permissionmanager',
  ),
  OemGuide(
    manufacturer: 'huawei',
    brand: 'Huawei',
    aliases: <String>['huawei', 'honor'],
    pathKey: 'readinessOemPathHuawei',
    component: 'com.huawei.systemmanager',
  ),
  OemGuide(
    manufacturer: 'samsung',
    brand: 'Samsung',
    aliases: <String>['samsung'],
    pathKey: 'readinessOemPathSamsung',
    component: 'com.samsung.android.lool',
  ),
];

/// Recipe used when the vendor has no dedicated guide (Pixel, Nothing, …).
const OemGuide genericOemGuide = OemGuide(
  manufacturer: 'generic',
  brand: 'Android',
  aliases: <String>[],
  pathKey: 'readinessOemPathGeneric',
);

/// Matches `Build.MANUFACTURER` case-insensitively, including the sub-brand
/// names vendors report (Redmi, POCO, iQOO, Honor, realme). Returns null when
/// no guide covers the vendor.
OemGuide? oemGuideFor(String manufacturer) {
  final value = manufacturer.trim().toLowerCase();
  if (value.isEmpty) return null;
  for (final guide in oemGuides) {
    for (final alias in guide.aliases) {
      if (value.contains(alias)) return guide;
    }
  }
  return null;
}

/// Never leaves the caller without the generic recipe.
OemGuide oemGuideForOrGeneric(String manufacturer) =>
    oemGuideFor(manufacturer) ?? genericOemGuide;
