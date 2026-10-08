import '../../core/errors/exceptions.dart';
import '../../domain/entities/lead.dart';

/// Valeurs de `source` telles que stockées dans les métadonnées du vector
/// store. Découplées de `LeadSource.name` pour qu'un renommage Dart ne casse
/// pas silencieusement les filtres sur un index déjà peuplé.
extension LeadSourceWire on LeadSource {
  String get wireValue => switch (this) {
        LeadSource.boamp => 'boamp',
        LeadSource.ted => 'ted',
        LeadSource.decp => 'decp',
        LeadSource.linkedIn => 'linkedin',
        LeadSource.x => 'x',
      };

  static LeadSource fromWire(Object? raw) {
    final value = raw is String ? raw.trim().toLowerCase() : null;
    return switch (value) {
      'boamp' => LeadSource.boamp,
      'ted' => LeadSource.ted,
      'decp' => LeadSource.decp,
      'linkedin' => LeadSource.linkedIn,
      'x' || 'twitter' => LeadSource.x,
      // Pas de valeur par défaut : étiqueter un post X comme « BOAMP »
      // fausserait la qualification commerciale.
      _ => throw ParsingException('Source de lead inconnue : $raw'),
    };
  }
}

/// Modèle de données de la couche `data` : sérialisation JSON du [Lead]
/// (ingestion, métadonnées Pinecone / lignes Supabase pgvector).
class LeadModel extends Lead {
  const LeadModel({
    required super.id,
    required super.source,
    required super.title,
    required super.organization,
    required super.summary,
    required super.content,
    required super.sourceUrl,
    required super.publishedAt,
    super.deadline,
    super.estimatedBudget,
    super.region,
    super.sector,
  });

  factory LeadModel.fromEntity(Lead lead) {
    return LeadModel(
      id: lead.id,
      source: lead.source,
      title: lead.title,
      organization: lead.organization,
      summary: lead.summary,
      content: lead.content,
      sourceUrl: lead.sourceUrl,
      publishedAt: lead.publishedAt,
      deadline: lead.deadline,
      estimatedBudget: lead.estimatedBudget,
      region: lead.region,
      sector: lead.sector,
    );
  }

  /// Lève [ParsingException] si un champ indispensable est absent ou invalide.
  ///
  /// Les champs d'identité (id, source, URL) sont stricts car un lead sans
  /// lien vérifiable est inexploitable commercialement ; les champs
  /// descriptifs ont des valeurs de repli pour tolérer des sources partielles.
  factory LeadModel.fromJson(Map<String, dynamic> json) {
    final id = _string(json['id']);
    if (id == null) {
      throw const ParsingException('Lead sans identifiant.');
    }

    final sourceUrl = _httpUrl(json['source_url']);
    if (sourceUrl == null) {
      throw ParsingException('Lead $id : source_url absente ou non http(s).');
    }

    final content = _string(json['content']) ?? '';
    final summary = _string(json['summary']) ?? _excerpt(content, 280);

    return LeadModel(
      id: id,
      source: LeadSourceWire.fromWire(json['source']),
      title: _string(json['title']) ?? 'Opportunité sans titre',
      organization: _string(json['organization']) ?? 'Organisation non précisée',
      summary: summary,
      content: content.isEmpty ? summary : content,
      sourceUrl: sourceUrl,
      publishedAt: _date(json['published_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deadline: _date(json['deadline']),
      estimatedBudget: _double(json['estimated_budget']),
      region: _string(json['region']),
      sector: _string(json['sector']),
    );
  }

  /// Parse un résultat de recherche vectorielle dans les deux formats pris en
  /// charge :
  /// - Pinecone : `{ "id", "score", "metadata": { ...champs du lead } }`
  /// - Supabase RPC `match_leads` : `{ ...champs du lead, "similarity" }`
  static ScoredLead fromVectorMatch(Map<String, dynamic> match) {
    final metadata = match['metadata'];
    final payload = metadata is Map<String, dynamic>
        ? <String, dynamic>{'id': match['id'], ...metadata}
        : match;

    final score = _double(match['score']) ?? _double(match['similarity']);
    if (score == null) {
      throw ParsingException('Score de similarité absent pour ${match['id']}.');
    }

    return ScoredLead(
      lead: LeadModel.fromJson(payload),
      score: score.clamp(0.0, 1.0).toDouble(),
    );
  }

  /// Format d'écriture des métadonnées. Les `null` sont omis car Pinecone
  /// rejette les métadonnées de valeur nulle.
  Map<String, dynamic> toJson() {
    final budget = estimatedBudget;
    final limit = deadline;

    return <String, dynamic>{
      'id': id,
      'source': source.wireValue,
      'title': title,
      'organization': organization,
      'summary': summary,
      'content': content,
      'source_url': sourceUrl.toString(),
      'published_at': publishedAt.toUtc().toIso8601String(),
      if (limit != null) 'deadline': limit.toUtc().toIso8601String(),
      if (budget != null) 'estimated_budget': budget,
      if (region != null) 'region': region,
      if (sector != null) 'sector': sector,
    };
  }

  /// Texte servant à calculer l'embedding à l'ingestion. Titre, organisation
  /// et localisation sont inclus car les requêtes commerciales ciblent
  /// presque toujours un secteur et une zone géographique.
  String toEmbeddingText() {
    return [
      title,
      organization,
      if (sector != null) 'Secteur : $sector',
      if (region != null) 'Région : $region',
      summary,
    ].join('\n');
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _double(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s.replaceAll(',', '.')),
        _ => null,
      };

  static DateTime? _date(Object? value) {
    final raw = _string(value);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// N'accepte que http(s) : une URL `javascript:` ou `intent:` injectée dans
  /// une source scrapée serait sinon ouverte par `url_launcher`.
  static Uri? _httpUrl(Object? value) {
    final raw = _string(value);
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return null;
    return (uri.scheme == 'https' || uri.scheme == 'http') ? uri : null;
  }

  static String _excerpt(String text, int maxLength) {
    return text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';
  }
}
