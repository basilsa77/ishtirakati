import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/services/category_classifier.dart';
import 'package:ishtirakati/services/remote_catalog.dart';

void main() {
  test('يصنف الخدمات الشائعة محليًا بدل أخرى', () {
    expect(CategoryClassifier.suggest('Netflix').category, 'ترفيه ومشاهدة');
    expect(CategoryClassifier.suggest('NordVPN').category, 'اتصالات وإنترنت');
    expect(CategoryClassifier.suggest('باقة إنترنت المنزل').category, 'اتصالات وإنترنت');
    expect(CategoryClassifier.suggest('Apple One').category, 'إنتاجية وذكاء اصطناعي');
  });

  test('يفضل تصنيف الكتالوج البعيد عند توفره', () {
    final suggestion = CategoryClassifier.suggest(
      'خدمة مخصصة',
      remote: const [
        RemoteService(
          name: 'خدمة مخصصة',
          emoji: '🔖',
          category: 'مالية وفواتير',
          domain: '',
          manageUrl: '',
          priceHint: null,
        ),
      ],
    );
    expect(suggestion.category, 'مالية وفواتير');
    expect(suggestion.source, 'catalog');
  });
}
