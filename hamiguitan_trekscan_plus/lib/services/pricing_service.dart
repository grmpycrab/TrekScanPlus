import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../utils/app_logger.dart';

// ---------------------------------------------------------------------------
// Value objects
// ---------------------------------------------------------------------------

class CategoryPricing {
  final String displayName;

  /// Whole-number percentage, e.g. 50 means 50 % off base price.
  final int discountPercent;
  final String notes;

  const CategoryPricing({
    required this.displayName,
    required this.discountPercent,
    this.notes = '',
  });

  factory CategoryPricing.fromMap(Map<String, dynamic> d) => CategoryPricing(
    displayName: d['displayName'] as String? ?? '',
    discountPercent: (d['discount'] as num?)?.toInt() ?? 0,
    notes: d['notes'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'discount': discountPercent,
    'notes': notes,
  };
}

class ServicePricing {
  final double porter;
  final double guide;
  final double scientist;

  const ServicePricing({
    required this.porter,
    required this.guide,
    required this.scientist,
  });

  factory ServicePricing.fromMap(Map<String, dynamic> d) => ServicePricing(
    porter: (d['porter'] as num?)?.toDouble() ?? 500,
    guide: (d['guide'] as num?)?.toDouble() ?? 1000,
    scientist: (d['scientist'] as num?)?.toDouble() ?? 1500,
  );

  Map<String, dynamic> toMap() => {
    'porter': porter,
    'guide': guide,
    'scientist': scientist,
  };

  static const ServicePricing defaults = ServicePricing(
    porter: 500,
    guide: 1000,
    scientist: 1500,
  );
}

class SeasonalRules {
  /// MM-DD, e.g. "07-01"
  final String offSeasonStart;

  /// MM-DD, e.g. "09-30"
  final String offSeasonEnd;

  final List<String> allowedBookingTypes;

  const SeasonalRules({
    required this.offSeasonStart,
    required this.offSeasonEnd,
    required this.allowedBookingTypes,
  });

  factory SeasonalRules.fromMap(Map<String, dynamic> d) => SeasonalRules(
    offSeasonStart: d['offSeasonStart'] as String? ?? '07-01',
    offSeasonEnd: d['offSeasonEnd'] as String? ?? '09-30',
    allowedBookingTypes: List<String>.from(
      d['allowedBookingTypes'] as List? ??
          ['special_trek', 'government_official', 'research_trek'],
    ),
  );

  Map<String, dynamic> toMap() => {
    'offSeasonStart': offSeasonStart,
    'offSeasonEnd': offSeasonEnd,
    'allowedBookingTypes': allowedBookingTypes,
  };

  static const SeasonalRules defaults = SeasonalRules(
    offSeasonStart: '07-01',
    offSeasonEnd: '09-30',
    allowedBookingTypes: [
      'special_trek',
      'government_official',
      'research_trek',
    ],
  );
}

/// Full pricing configuration loaded from Firestore `pricingVersions` (active version).
class PricingConfig {
  final double basePricePerPerson;
  final Map<String, CategoryPricing> categories;
  final ServicePricing services;
  final SeasonalRules seasonalRules;
  final int version;
  final DateTime? updatedAt;

  const PricingConfig({
    required this.basePricePerPerson,
    required this.categories,
    required this.services,
    required this.seasonalRules,
    this.version = 1,
    this.updatedAt,
  });

  factory PricingConfig.fromMap(Map<String, dynamic> d) {
    final cats = <String, CategoryPricing>{};
    if (d['categories'] is Map) {
      (d['categories'] as Map).forEach((k, v) {
        cats[k as String] =
            CategoryPricing.fromMap(Map<String, dynamic>.from(v as Map));
      });
    }
    return PricingConfig(
      basePricePerPerson:
          (d['basePricePerPerson'] as num?)?.toDouble() ?? 3000,
      categories: cats,
      services: d['services'] != null
          ? ServicePricing.fromMap(
              Map<String, dynamic>.from(d['services'] as Map),
            )
          : ServicePricing.defaults,
      seasonalRules: d['seasonalRules'] != null
          ? SeasonalRules.fromMap(
              Map<String, dynamic>.from(d['seasonalRules'] as Map),
            )
          : SeasonalRules.defaults,
      version: ((d['versionNumber'] ?? d['version']) as num?)?.toInt() ?? 1,
      updatedAt: d['updatedAt'] is Timestamp
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'basePricePerPerson': basePricePerPerson,
    'categories': categories.map((k, v) => MapEntry(k, v.toMap())),
    'services': services.toMap(),
    'seasonalRules': seasonalRules.toMap(),
    'version': version,
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
  };

  static PricingConfig get defaults => PricingConfig(
    basePricePerPerson: 3000,
    categories: const {
      'student': CategoryPricing(
        displayName: 'Student',
        discountPercent: 50,
        notes: '50% discount',
      ),
      'senior_citizen': CategoryPricing(
        displayName: 'Senior Citizen',
        discountPercent: 20,
        notes: '20% discount',
      ),
      'davao_oriental_resident': CategoryPricing(
        displayName: 'Davao Oriental Resident',
        discountPercent: 50,
        notes: '50% discount',
      ),
      'ocfdo': CategoryPricing(
        displayName: 'OCFDO Member',
        discountPercent: 67,
        notes: '67% discount (≈ ₱2,000)',
      ),
      'children_8_15': CategoryPricing(
        displayName: 'Children (8–15)',
        discountPercent: 50,
        notes: '50% discount',
      ),
      'mfsm': CategoryPricing(
        displayName: 'MFSM Member',
        discountPercent: 25,
        notes: '25% discount (≈ ₱750)',
      ),
      'outside_davao_oriental': CategoryPricing(
        displayName: 'Outside Davao Oriental',
        discountPercent: 0,
        notes: 'Full price',
      ),
    },
    services: ServicePricing.defaults,
    seasonalRules: SeasonalRules.defaults,
  );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Firestore-backed dynamic pricing service.
///
/// Subscribes to the active version in `pricingVersions` (where status == 'active')
/// and keeps the config live via a real-time Firestore snapshot listener.
/// Falls back to a SharedPreferences cache or hardcoded defaults when offline.
///
/// Usage:
/// ```dart
/// await PricingService.instance.init();
/// final price = PricingService.instance.calculateMemberPrice('student');
/// ```
class PricingService {
  PricingService._();
  static final PricingService instance = PricingService._();

  static const _cacheKey = 'pricing_config_v2';
  static const _collection = 'pricingVersions';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PricingConfig _config = PricingConfig.defaults;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _initialized = false;

  /// The currently active pricing configuration.
  PricingConfig get config => _config;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initialise the service: load cached config then start real-time sync.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromCache();
    _startRealtimeSync();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Calculation API
  // ---------------------------------------------------------------------------

  /// Base price before any category discount.
  double get basePricePerPerson => _config.basePricePerPerson;

  /// Discount percentage (0–100) for [category].  Returns 0 for unknown categories.
  int getDiscountPercent(String category) =>
      _config.categories[category]?.discountPercent ?? 0;

  /// Effective per-person price after applying the category discount.
  double calculateMemberPrice(String category) {
    final discount = getDiscountPercent(category);
    return _config.basePricePerPerson * (1 - discount / 100);
  }

  /// Price for a single porter (per member who requests one).
  double get porterPrice => _config.services.porter;

  /// Price for a group-level tour guide.
  double get guidePrice => _config.services.guide;

  /// Price for a group-level scientist.
  double get scientistPrice => _config.services.scientist;

  /// Seasonal rules as configured in Firestore.
  SeasonalRules get seasonalRules => _config.seasonalRules;

  /// Whether [date] falls in the restricted off-season window.
  bool isOffSeason(DateTime date) {
    final mmdd = '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final start = _config.seasonalRules.offSeasonStart; // e.g. "07-01"
    final end = _config.seasonalRules.offSeasonEnd; // e.g. "09-30"
    return mmdd.compareTo(start) >= 0 && mmdd.compareTo(end) <= 0;
  }

  /// Whether [trekType] is permitted during the off-season.
  bool isAllowedInOffSeason(String trekType) =>
      _config.seasonalRules.allowedBookingTypes.contains(trekType);

  /// Category display name, e.g. "Student".  Falls back to [category] if missing.
  String getCategoryDisplayName(String category) =>
      _config.categories[category]?.displayName ?? category;

  /// All categories with their pricing info.
  Map<String, CategoryPricing> get allCategories => _config.categories;

  /// Computes the total cost for a list of members plus optional group services.
  ///
  /// - [porterPerMember] — list of booleans parallel to [members]; true means
  ///   that member requested a porter.
  /// - [guideIncluded] — a single group-level tour guide.
  /// - [scientistIncluded] — a single group-level scientist.
  GroupPricingSummary calculateGroupTotal({
    required List<Member> members,
    List<bool>? porterPerMember,
    bool guideIncluded = false,
    bool scientistIncluded = false,
  }) {
    final porterFlags = porterPerMember ?? List.filled(members.length, false);
    var memberSubtotal = 0.0;
    var porterSubtotal = 0.0;

    final breakdowns = <MemberPriceBreakdown>[];

    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      final memberCost = calculateMemberPrice(m.category);
      final porterCost =
          (i < porterFlags.length && porterFlags[i]) ? porterPrice : 0.0;
      memberSubtotal += memberCost;
      porterSubtotal += porterCost;
      breakdowns.add(
        MemberPriceBreakdown(
          member: m,
          baseCost: basePricePerPerson,
          discountPercent: getDiscountPercent(m.category),
          memberCost: memberCost,
          porterCost: porterCost,
        ),
      );
    }

    final guideCost = guideIncluded ? guidePrice : 0.0;
    final scientistCost = scientistIncluded ? scientistPrice : 0.0;

    return GroupPricingSummary(
      memberBreakdowns: breakdowns,
      memberSubtotal: memberSubtotal,
      porterSubtotal: porterSubtotal,
      guideCost: guideCost,
      scientistCost: scientistCost,
      grandTotal: memberSubtotal + porterSubtotal + guideCost + scientistCost,
    );
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _config = PricingConfig.fromMap(map);
        AppLogger.d('PricingService: loaded from cache (v${_config.version})');
      }
    } catch (e) {
      AppLogger.w('PricingService: cache load failed — using defaults: $e');
    }
  }

  void _startRealtimeSync() {
    _subscription = _db
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (s, _) => s.data()!,
          toFirestore: (d, _) => d,
        )
        .snapshots()
        .listen(
          _onRemoteUpdate,
          onError: (Object e) =>
              AppLogger.w('PricingService: Firestore stream error: $e'),
        );
  }

  Future<void> _onRemoteUpdate(QuerySnapshot<Map<String, dynamic>> snap) async {
    if (snap.docs.isEmpty) return;
    try {
      final data = snap.docs.first.data();
      final remote = PricingConfig.fromMap(data);
      if (remote.version >= _config.version) {
        _config = remote;
        AppLogger.i(
          'PricingService: config updated to v${_config.version} '
          '(base ₱${_config.basePricePerPerson})',
        );
        await _saveToCache(data);
      }
    } catch (e) {
      AppLogger.w('PricingService: failed to parse remote config: $e');
    }
  }

  Future<void> _saveToCache(Map<String, dynamic> rawData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Strip Timestamps (not JSON-serialisable) before caching.
      final sanitised = _sanitiseForJson(rawData);
      await prefs.setString(_cacheKey, jsonEncode(sanitised));
    } catch (e) {
      AppLogger.w('PricingService: cache write failed: $e');
    }
  }

  /// Recursively replaces Timestamp values with ISO-8601 strings so the map
  /// can be passed through jsonEncode without a type error.
  dynamic _sanitiseForJson(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key: _sanitiseForJson(e.value),
      };
    }
    if (value is List) return value.map(_sanitiseForJson).toList();
    return value;
  }
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Per-member price breakdown used in the summary sheet.
class MemberPriceBreakdown {
  final Member member;
  final double baseCost;
  final int discountPercent;
  final double memberCost;
  final double porterCost;

  const MemberPriceBreakdown({
    required this.member,
    required this.baseCost,
    required this.discountPercent,
    required this.memberCost,
    required this.porterCost,
  });

  double get subtotal => memberCost + porterCost;
  double get discountAmount => baseCost - memberCost;
}

/// Aggregated pricing result for a group booking.
class GroupPricingSummary {
  final List<MemberPriceBreakdown> memberBreakdowns;
  final double memberSubtotal;
  final double porterSubtotal;
  final double guideCost;
  final double scientistCost;
  final double grandTotal;

  const GroupPricingSummary({
    required this.memberBreakdowns,
    required this.memberSubtotal,
    required this.porterSubtotal,
    required this.guideCost,
    required this.scientistCost,
    required this.grandTotal,
  });

  int get memberCount => memberBreakdowns.length;
  double get serviceSubtotal => porterSubtotal + guideCost + scientistCost;
}
