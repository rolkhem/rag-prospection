import 'package:equatable/equatable.dart';

enum LeadCategory {
  publicTender(label: 'Appel d\'offres public'),
  socialSignal(label: 'Signal réseau social');

  const LeadCategory({required this.label});

  final String label;
}

enum LeadSource {
  boamp(label: 'BOAMP', category: LeadCategory.publicTender),
  ted(label: 'TED', category: LeadCategory.publicTender),
  linkedIn(label: 'LinkedIn', category: LeadCategory.socialSignal),
  x(label: 'X', category: LeadCategory.socialSignal);

  const LeadSource({required this.label, required this.category});

  final String label;
  final LeadCategory category;
}

/// Opportunité commerciale normalisée, quelle que soit sa provenance.
///
/// Un modèle unique (plutôt qu'une hiérarchie AppelOffre / PostSocial) permet
/// au vector store et au prompt builder de traiter toutes les sources de la
/// même façon ; les champs spécifiques à une famille sont simplement nullables.
class Lead extends Equatable {
  const Lead({
    required this.id,
    required this.source,
    required this.title,
    required this.organization,
    required this.summary,
    required this.content,
    required this.sourceUrl,
    required this.publishedAt,
    this.deadline,
    this.estimatedBudget,
    this.region,
    this.sector,
  });

  final String id;
  final LeadSource source;
  final String title;

  /// Acheteur public pour un appel d'offres, entreprise/auteur pour un post.
  final String organization;
  final String summary;
  final String content;
  final Uri sourceUrl;
  final DateTime publishedAt;

  /// Date limite de remise des offres (appels d'offres uniquement).
  final DateTime? deadline;

  /// Montant estimé en euros HT, si l'avis le précise.
  final double? estimatedBudget;
  final String? region;
  final String? sector;

  bool isExpiredAt(DateTime now) {
    final limit = deadline;
    return limit != null && limit.isBefore(now);
  }

  @override
  List<Object?> get props => [
        id,
        source,
        title,
        organization,
        summary,
        content,
        sourceUrl,
        publishedAt,
        deadline,
        estimatedBudget,
        region,
        sector,
      ];
}

/// Lead accompagné de son score de similarité cosinus pour une requête donnée.
///
/// Le score est volontairement hors de [Lead] : il dépend de la question posée,
/// pas de l'opportunité elle-même.
class ScoredLead extends Equatable {
  const ScoredLead({required this.lead, required this.score});

  final Lead lead;
  final double score;

  @override
  List<Object?> get props => [lead, score];
}
