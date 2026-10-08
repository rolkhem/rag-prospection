import 'package:flutter_test/flutter_test.dart';
import 'package:rag_prospection/data/models/lead_model.dart';
import 'package:rag_prospection/domain/entities/lead.dart';
import 'package:rag_prospection/domain/services/rag_prompt_builder.dart';

ScoredLead _lead(LeadSource source) => ScoredLead(
      score: 0.8,
      lead: Lead(
        id: '${source.name}-1',
        source: source,
        title: 'Infogérance du parc informatique',
        organization: 'Département du Gard',
        summary: 'Résumé',
        content: 'Contenu',
        sourceUrl: Uri.parse('https://annuaire-entreprises.data.gouv.fr/etablissement/22300001900073'),
        publishedAt: DateTime.utc(2023, 3, 1),
        deadline: DateTime.utc(2027, 3, 1),
      ),
    );

void main() {
  const builder = RagPromptBuilder();

  test('présente la fin d\'un marché attribué comme une échéance, pas une date limite', () {
    final prompt = builder.build(
      question: 'Renouvellements infogérance',
      leads: [_lead(LeadSource.decp)],
      now: DateTime.utc(2026, 10, 8),
    );

    expect(prompt.userPrompt, contains('type="Marché attribué (renouvellement)"'));
    expect(prompt.userPrompt, contains('Fin de marché estimée : 2027-03-01'));
    expect(prompt.userPrompt, isNot(contains('Date limite')));
    expect(prompt.systemInstruction, contains('n\'est PAS une consultation ouverte'));
  });

  test('conserve « Date limite » pour un appel d\'offres ouvert', () {
    final prompt = builder.build(
      question: 'Infogérance',
      leads: [_lead(LeadSource.boamp)],
      now: DateTime.utc(2026, 10, 8),
    );

    expect(prompt.userPrompt, contains('Date limite : 2027-03-01'));
  });

  test('le format wire de DECP est stable', () {
    expect(LeadSource.decp.wireValue, 'decp');
    expect(LeadSourceWire.fromWire('decp'), LeadSource.decp);
  });
}
