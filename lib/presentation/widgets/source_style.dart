import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';

/// Identité visuelle d'une source, partagée entre les cartes de leads du chat
/// et l'écran Sources pour que l'utilisateur les associe d'un coup d'œil.
extension LeadSourceStyle on LeadSource {
  Color get color => switch (this) {
        LeadSource.boamp => AppColors.boamp,
        LeadSource.ted => AppColors.ted,
        LeadSource.linkedIn => AppColors.linkedIn,
        LeadSource.x => AppColors.x,
      };

  IconData get icon => switch (this) {
        LeadSource.boamp => Icons.account_balance_rounded,
        LeadSource.ted => Icons.public_rounded,
        LeadSource.linkedIn => Icons.work_rounded,
        LeadSource.x => Icons.alternate_email_rounded,
      };
}
