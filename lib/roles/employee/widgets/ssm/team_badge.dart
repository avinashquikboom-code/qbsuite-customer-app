import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

class TeamBadge extends StatelessWidget {
  final String teamName;

  const TeamBadge({super.key, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final isTeamA = teamName.contains('Team A');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTeamA ? AppColors.primaryLight : const Color(0xFFF9F5FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        teamName,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isTeamA ? AppColors.primaryDark : const Color(0xFF6941C6),
        ),
      ),
    );
  }
}
