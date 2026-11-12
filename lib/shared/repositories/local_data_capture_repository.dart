import 'dart:math';


import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';

/// Local in-memory repository for Data Capture / Lead Extraction.
///
/// Fully powers:
/// - Data Capture search & extraction (Google Discovery & Google Places demo layer)
/// - Captured results view & business result cards
/// - Single result "Add Lead" flow
/// - Multi-result "Import Selected Leads" flow
///
/// Zero backend HTTP/API requests are made.
class LocalDataCaptureRepository {
  static final LocalDataCaptureRepository instance =
      LocalDataCaptureRepository._internal();

  LocalDataCaptureRepository._internal() {
    _cachedHistory = _initInitialHistory();
  }

  late final List<ExtractionJobRecord> _cachedHistory;
  int _dynamicTotalLeadsCaptured = 48;
  int _dynamicTotalExtractions = 8;
  int _dynamicTotalSearches = 14;
  static const int _dynamicQuotaLimit = 1000;

  void clearCache() {
    _cachedHistory.clear();
    _dynamicTotalSearches = 0;
  }

  Future<bool> checkAccess() async {
    return true;
  }

  Future<DataCaptureUsage> getUsageSummary() async {
    final remaining = max(0, _dynamicQuotaLimit - _dynamicTotalExtractions);
    return DataCaptureUsage(
      totalExtractions: _dynamicTotalExtractions,
      totalLeadsCaptured: _dynamicTotalLeadsCaptured,
      totalGoogleApiCalls: _dynamicTotalExtractions,
      quotaLimit: _dynamicQuotaLimit,
      quotaRemaining: remaining,
      searches: _dynamicTotalSearches,
    );
  }

  /// Extracts verified businesses locally using category & location templates
  Future<ExtractionJobRecord> extractPlaces({
    required String keyword,
    required String location,
    int maxResults = 20,
    String? requestId,
  }) async {
    final cleanKeyword = keyword.trim();
    final cleanLocation = location.trim();

    // Check if an existing cached job matches this search
    final existingMatch = _cachedHistory
        .cast<ExtractionJobRecord?>()
        .firstWhere(
          (j) =>
              j?.keyword.toLowerCase() == cleanKeyword.toLowerCase() &&
              j?.location.toLowerCase().contains(cleanLocation.toLowerCase()) ==
                  true,
          orElse: () => null,
        );

    if (existingMatch != null && existingMatch.places.isNotEmpty) {
      _dynamicTotalSearches++;
      return existingMatch;
    }

    final places = _buildCategoryPlaces(
      cleanKeyword,
      cleanLocation,
      maxResults,
    );
    final jobRecord = ExtractionJobRecord(
      jobId:
          'job_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}',
      keyword: cleanKeyword,
      location: cleanLocation,
      requestedResults: maxResults,
      capturedResults: places.length,
      createdAt: DateTime.now(),
      places: places,
    );

    _cachedHistory.insert(0, jobRecord);
    _dynamicTotalExtractions++;
    _dynamicTotalSearches++;
    return jobRecord;
  }

  /// Imports selected business records into LocalLeadRepository
  Future<ImportResultSummary> importToLeads({
    required String jobId,
    List<String>? placeIds,
    List<CapturedBusiness>? places,
  }) async {
    List<CapturedBusiness> placesToImport = [];

    if (places != null && places.isNotEmpty) {
      placesToImport = places;
    } else {
      // Find from history
      for (final job in _cachedHistory) {
        if (job.jobId == jobId) {
          final targetSet = placeIds != null
              ? Set<String>.from(placeIds)
              : null;
          placesToImport = job.places.where((p) {
            if (targetSet != null) {
              return targetSet.contains(p.googlePlaceId);
            }
            return p.isSelected;
          }).toList();
          break;
        }
      }
    }

    final summary = ImportResultSummary(
      totalRequested: placesToImport.length,
      imported: placesToImport.length,
      skippedDuplicates: 0,
      message: 'Captured places imported successfully.',
      records: placesToImport
          .map((p) => ImportedRecordResult(
                googlePlaceId: p.googlePlaceId,
                businessName: p.businessName,
                imported: true,
                duplicate: false,
                leadId: 1,
              ))
          .toList(),
    );

    // Mark places as imported in cached history
    _markPlacesImported(
      jobId,
      placeIds ?? placesToImport.map((p) => p.googlePlaceId).toList(),
    );
    _dynamicTotalLeadsCaptured += summary.imported;

    return summary;
  }

  /// Converts a single Data Capture record to a CRM Lead locally
  Future<Map<String, dynamic>> createLeadFromPlace(
    dynamic id, {
    String? captureRequestId,
    CapturedBusiness? business,
  }) async {
    CapturedBusiness? target = business;
    if (target == null) {
      for (final job in _cachedHistory) {
        for (final p in job.places) {
          if (p.id?.toString() == id.toString() ||
              p.googlePlaceId == id.toString()) {
            target = p;
            break;
          }
        }
        if (target != null) break;
      }
    }

    if (target == null) {
      throw Exception('Data Capture record ($id) not found.');
    }

    target.isImported = true;
    target.isSelected = false;

    final leadId = 'place_${DateTime.now().millisecondsSinceEpoch}';

    return {
      'success': true,
      'leadId': leadId,
      'lead': {'id': leadId, 'businessName': target.businessName},
      'message': 'Record captured successfully.',
    };
  }

  void _markPlacesImported(String jobId, List<String> placeIds) {
    final targetSet = Set<String>.from(placeIds);
    for (final job in _cachedHistory) {
      if (job.jobId == jobId) {
        for (final p in job.places) {
          if (targetSet.contains(p.googlePlaceId) || p.isSelected) {
            p.isImported = true;
            p.isSelected = false;
          }
        }
      }
    }
  }

  static List<ExtractionJobRecord> _initInitialHistory() {
    return [
      ExtractionJobRecord(
        jobId: 'job_001',
        keyword: 'Gym & Fitness Center',
        location: 'Alkapuri, Vadodara',
        requestedResults: 15,
        capturedResults: 15,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        places: _buildCategoryPlaces(
          'Gym & Fitness Center',
          'Alkapuri, Vadodara',
          15,
        ),
      ),
      ExtractionJobRecord(
        jobId: 'job_002',
        keyword: 'Software Companies',
        location: 'OP Road, Vadodara',
        requestedResults: 20,
        capturedResults: 20,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        places: _buildCategoryPlaces(
          'Software Companies',
          'OP Road, Vadodara',
          20,
        ),
      ),
      ExtractionJobRecord(
        jobId: 'job_003',
        keyword: 'Hospitals & Clinics',
        location: 'Gotri, Vadodara',
        requestedResults: 12,
        capturedResults: 12,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        places: _buildCategoryPlaces(
          'Hospitals & Clinics',
          'Gotri, Vadodara',
          12,
        ),
      ),
      ExtractionJobRecord(
        jobId: 'job_004',
        keyword: 'Salon & Spa Lounge',
        location: 'Sayajigunj, Vadodara',
        requestedResults: 14,
        capturedResults: 14,
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        places: _buildCategoryPlaces(
          'Salon & Spa Lounge',
          'Sayajigunj, Vadodara',
          14,
        ),
      ),
    ];
  }

  static List<CapturedBusiness> _buildCategoryPlaces(
    String keyword,
    String location,
    int count,
  ) {
    final lowerKw = keyword.toLowerCase();
    List<String> templates;
    List<String> samplePhotos;

    if (lowerKw.contains('gym') ||
        lowerKw.contains('fitness') ||
        lowerKw.contains('crossfit')) {
      templates = [
        'Gold\'s Gym & Fitness Hub',
        'Talwalkars Fitness Studio',
        'Anytime Fitness 24/7',
        'Cult.fit Pro Arena',
        'Fitness First Luxury Gym',
        'Snap Fitness Health Club',
        'Powerhouse Gym & Spa',
        'BodyKraft Crossfit Arena',
        'Pulse Cardio & Strength Studio',
        'Iron Paradise Health Club',
      ];
      samplePhotos = const [];
    } else if (lowerKw.contains('hospital') ||
        lowerKw.contains('clinic') ||
        lowerKw.contains('health') ||
        lowerKw.contains('medical') ||
        lowerKw.contains('doctor') ||
        lowerKw.contains('dental')) {
      templates = [
        'Apex Multi-Speciality Hospital',
        'Apollo Spectra Care Center',
        'LifeLine Medical Hospital & ICU',
        'Sterling Healthcare Diagnostics',
        'Fortis MedCentre & Clinics',
        'CareWell Family Clinic & Lab',
        'Pulse Medicare Super Speciality',
        'Sunrise Children & General Hospital',
        'Medanta Comprehensive Clinic',
        'Paramount Health & Surgical Centre',
      ];
      samplePhotos = const [];
    } else if (lowerKw.contains('restaurant') ||
        lowerKw.contains('cafe') ||
        lowerKw.contains('food') ||
        lowerKw.contains('dining') ||
        lowerKw.contains('bistro') ||
        lowerKw.contains('hotel')) {
      templates = [
        'The Grand Heritage Restaurant',
        'Urban Spice Kitchen & Grill',
        'Barbeque Nation Dining Hub',
        'Saffron Fine Dine & Banquets',
        'Mocha Bistro & Artisan Cafe',
        'Tandoor Box Family Restaurant',
        'Mainland Treats & Continental',
        'Blue Sky Rooftop Lounge',
        'The Royal Courtyard Eatery',
        'Flavours & Bites Gourmet Kitchen',
      ];
      samplePhotos = const [];
    } else if (lowerKw.contains('software') ||
        lowerKw.contains('tech') ||
        lowerKw.contains('it') ||
        lowerKw.contains('digital') ||
        lowerKw.contains('cloud') ||
        lowerKw.contains('ai')) {
      templates = [
        'Tata Consultancy Services Hub',
        'Infosys Technology Campus',
        'Cognizant Digital Solutions',
        'Wipro Cloud Innovations',
        'Zenith Infotech Systems',
        'Apex Software Labs & Consulting',
        'NextGen Technologies',
        'BlueChip Cloud Solutions',
        'InnoWave Enterprise Software',
        'CyberPulse Digital Labs',
      ];
      samplePhotos = const [];
    } else if (lowerKw.contains('salon') ||
        lowerKw.contains('spa') ||
        lowerKw.contains('beauty')) {
      templates = [
        'Enrich Salon & Luxury Spa',
        'Jawed Habib Hair & Beauty Lounge',
        'Lakme Salon & Bridal Studio',
        'VLCC Wellness & Beauty Centre',
        'Tony & Guy Hairdressing Hub',
        'O2 Unisex Spa & Wellness',
        'Glamour Touch Beauty Lounge',
        'The Mirror Luxury Parlour',
        'Glow & Grace Skin Clinic & Spa',
        'Urban Silhouette Hair Studio',
      ];
      samplePhotos = const [];
    } else {
      templates = [
        '$keyword Hub & Enterprises',
        'Prime $keyword Specialists',
        'Royal $keyword Centre',
        'Apex $keyword & Services',
        'The Grand $keyword Studio',
        'Metro $keyword Solutions',
        'NextGen $keyword Associates',
        'Gold Standard $keyword Group',
        'Elite $keyword & Commercial Works',
        'Pinnacle $keyword Agency',
      ];
      samplePhotos = const [];
    }

    return List.generate(count, (index) {
      final baseName = templates[index % templates.length];
      final name =
          baseName.replaceAll(r'$keyword', keyword) +
          (index >= templates.length ? ' Unit ${index + 1}' : '');
      final cleanId = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final placeId = 'ChIJ_${cleanId}_$index';
      final rating = (4.2 + (index % 8) * 0.1);
      final reviews = 45 + (index * 29) % 450;
      final cleanDomain = name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );

      return CapturedBusiness(
        id: index + 1,
        googlePlaceId: placeId,
        sourceRecordId: placeId,
        sourceUrl: 'https://www.$cleanDomain.in',
        businessName: name,
        category: keyword,
        address:
            '${101 + index * 12}, Commercial Complex, Near Central Circle, $location, Gujarat, India',
        phone:
            '+91 98${200 + (index * 47) % 700} ${10000 + (index * 533) % 89999}',
        email: 'info@$cleanDomain.in',
        website: 'https://www.$cleanDomain.in',
        rating: double.parse(rating.toStringAsFixed(1)),
        reviewCount: reviews,
        latitude: 22.3072 + (index * 0.002),
        longitude: 73.1812 + (index * 0.002),
        googleMapsUrl:
            'https://maps.google.com/?q=${Uri.encodeComponent(name)}+${Uri.encodeComponent(location)}',
        businessStatus: 'OPERATIONAL',
        capturedAt: DateTime.now(),
        isSelected: true,
        isImported: false,
        photos: samplePhotos,
        socialMedia: {
          'instagram': 'https://instagram.com/$cleanDomain',
          'facebook': 'https://facebook.com/$cleanDomain',
          'linkedin': 'https://linkedin.com/company/$cleanDomain',
        },
      );
    });
  }
}
