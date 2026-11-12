import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';

import 'package:quickboom_crm_customer/shared/models/lead_model.dart';

/// One image source for lead cards and lead details.
class LeadBusinessImage extends StatelessWidget {
  static final Set<String> _logged = {};
  final LeadModel lead;
  final double size;
  final double radius;
  final String? initials;
  final double initialsFontSize;

  const LeadBusinessImage({super.key, required this.lead, this.size = 72, this.radius = 12, this.initials, this.initialsFontSize = 22});

  String _thumbnail(String url) {
    if (!url.contains('/data-capture/photo') || url.contains('maxWidth=')) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}maxWidth=256&maxHeight=256';
  }

  Widget _placeholder() {
    if (initials != null) {
      final label = initials!.trim().isEmpty ? 'L' : initials!.trim();
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: GoogleFonts.outfit(fontSize: initialsFontSize, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFE8F7ED), borderRadius: BorderRadius.circular(radius)),
      child: Icon(Remix.store_2_line, size: size * 0.38, color: const Color(0xFF16A34A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = lead.imageUrl;
    if (url == null || url.isEmpty) {
      if (kDebugMode && (lead.googlePlaceId ?? '').isNotEmpty) {
        debugPrint('[LEAD_IMAGE] leadId=${lead.id} placeId=${lead.googlePlaceId} photoAvailable=false');
        debugPrint('[LEAD_IMAGE] id=${lead.id} name=${lead.displayName} source=none url=missing');
      }
      return _placeholder();
    }
    final google = url.contains('/data-capture/photo');
    final image = google
        ? Image.network(
            _thumbnail(url),
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null ? _loaded(child, url, google) : _loading(),
            errorBuilder: (_, _, _) => _failed(),
          )
        : CachedNetworkImage(
            imageUrl: _thumbnail(url),
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: 256,
            memCacheHeight: 256,
            placeholder: (_, _) => _loading(),
            errorWidget: (_, _, _) => _failed(),
            imageBuilder: (context, provider) => _loaded(Image(image: provider, width: size, height: size, fit: BoxFit.cover), url, google),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }

  Widget _loading() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: initials != null ? const Color(0xFFF1F5F9) : const Color(0xFFE8F7ED),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: initials != null ? const Color(0xFF64748B) : const Color(0xFF16A34A)),
      ),
    );
  }

  Widget _failed() {
    if (kDebugMode) debugPrint('[LEAD_IMAGE] leadId=${lead.id} placeId=${lead.googlePlaceId ?? ''} imageLoadStatus=failed');
    return _placeholder();
  }

  Widget _loaded(Widget image, String url, bool google) {
    if (kDebugMode && _logged.add('${lead.id}|$url')) {
      debugPrint('[LEAD_IMAGE] leadId=${lead.id} placeId=${lead.googlePlaceId ?? ''} photoAvailable=true');
      debugPrint('[LEAD_IMAGE] imageSource=${google ? 'google_places' : 'upload'}');
      debugPrint('[LEAD_IMAGE] imageLoadStatus=success');
    }
    final credit = lead.photoCredits.isEmpty ? '' : lead.photoCredits.first.trim();
    if (!google || credit.isEmpty) return image;
    return Stack(fit: StackFit.expand, children: [
      image,
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: ColoredBox(
          color: const Color(0x99000000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(credit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 8, height: 1.1)),
          ),
        ),
      ),
    ]);
  }
}
