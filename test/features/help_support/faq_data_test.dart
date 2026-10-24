import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/router/app_router.dart';
import 'package:vital_up/features/help_support/data/datasources/faq_data.dart';
import 'package:vital_up/features/help_support/domain/entities/faq_item.dart';
import 'package:vital_up/features/help_support/presentation/pages/help_support_page.dart';

void main() {
  test('every article action opens a real route and ids are unique', () {
    final router = AppRouter.router;
    for (final faq in kFaqDatabase) {
      if (faq.actionRoute == null) continue;
      expect(
        () => router.namedLocation(faq.actionRoute!),
        returnsNormally,
        reason: '${faq.id} links to missing route "${faq.actionRoute}"',
      );
      expect(faq.actionLabel, isNotNull, reason: faq.id);
    }
    final ids = kFaqDatabase.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every category except All has articles', () {
    for (final category in FaqCategory.values.skip(1)) {
      expect(
        kFaqDatabase.any((f) => f.category == category),
        isTrue,
        reason: category.name,
      );
    }
  });

  test('articles are plain text (the card shows no markdown)', () {
    for (final faq in kFaqDatabase) {
      expect(faq.answer.contains('**'), isFalse, reason: faq.id);
      expect(faq.answer.contains('→'), isFalse, reason: faq.id);
    }
  });

  group('searchFaqs', () {
    List<String> ids(String query, {FaqCategory c = FaqCategory.all}) => [
      for (final f in searchFaqs(kFaqDatabase, query, category: c)) f.id,
    ];

    test('empty query lists the category', () {
      expect(ids('').length, kFaqDatabase.length);
      expect(ids('  ', c: FaqCategory.sleep), ['slp_1', 'slp_2']);
    });

    test('matches each word, not the whole phrase', () {
      expect(ids('sleep not syncing').first, 'snc_1');
      expect(ids('how do I log water'), contains('hyd_1'));
      expect(ids('cancel my subscription'), contains('app_3'));
      expect(ids('delete account'), contains('acc_2'));
      expect(ids('forgot password'), contains('acc_3'));
    });

    test('word starts only: "ml" is not found inside "html"', () {
      expect(ids('html'), isEmpty);
      expect(ids('ml'), contains('hyd_1'));
    });

    test('no match gives an empty list', () {
      expect(ids('quantum physics'), isEmpty);
    });
  });
}
