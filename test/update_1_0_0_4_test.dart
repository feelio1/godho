import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petcliniccheck/models/pet.dart';
import 'package:petcliniccheck/models/pet_weight_band.dart';
import 'package:petcliniccheck/shop/models/product.dart';
import 'package:petcliniccheck/shop/option_split.dart';
import 'package:petcliniccheck/shop/recommend.dart';
import 'package:petcliniccheck/theme/app_colors.dart';
import 'package:petcliniccheck/theme/app_text_styles.dart';
import 'package:petcliniccheck/theme/app_theme.dart';
import 'package:petcliniccheck/utils/keep_words.dart';

ProductOption _o(String id, String name, {bool soldOut = false}) => ProductOption(id: id, name: name, soldOut: soldOut);

Product _product(
  String id, {
  List<PetTypeTag> petTypes = const [PetTypeTag.dog],
  List<LifeStageTag> lifeStages = const [],
}) => Product(
  id: id,
  sellerId: 'aggaeng',
  name: id,
  category: ProductCategory.treat,
  price: 1000,
  status: ProductStatus.active,
  petTypes: petTypes,
  lifeStages: lifeStages,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  group('J-1 테마 토큰', () {
    test('바뀐 색·새 색', () {
      expect(AppColors.borderInput, const Color(0xFF7B8694));
      expect(AppColors.textPlaceholder, const Color(0xFF5B6573));
      expect(AppColors.warmBackground, const Color(0xFFFFF6CC));
      expect(AppColors.diaryAccent, const Color(0xFF8A5A12));
      expect(AppColors.butter, const Color(0xFFFFE58A));
      expect(AppColors.navyTint, const Color(0xFF2F5F9E));
      expect(AppColors.onNavyCaption, const Color(0xFFD6E2F3));
      expect(AppColors.notebookLine, const Color(0xFFC5CCD6));
      expect(AppColors.softPanel, const Color(0xFFF1F3F6));
      // 그대로 두는 색.
      expect(AppColors.primary, const Color(0xFF1B4D8C));
      expect(AppColors.error, const Color(0xFF9A3324));
    });

    test('숫자는 IBM Plex Mono가 아니라 Sans KR + 자릿수 고정', () {
      final style = AppTextStyles.mono(size: 14);
      expect(style.fontFamily, 'IBM Plex Sans KR');
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('주요 버튼 56dp 알약, 보조 버튼 1.5px 네이비, 카드 그림자 없음·반지름 22, 하단 탭 알약', () {
      final theme = AppTheme.light();
      final filled = theme.filledButtonTheme.style!;
      expect(filled.minimumSize!.resolve({})!.height, 56);
      expect(filled.shape!.resolve({}), isA<StadiumBorder>());
      final outlined = theme.outlinedButtonTheme.style!;
      expect(outlined.side!.resolve({}), const BorderSide(color: AppColors.primary, width: 1.5));
      expect(theme.cardTheme.elevation, 0);
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(22));
      expect(theme.navigationBarTheme.indicatorColor, AppColors.feeRangeFill);
      expect(
        theme.navigationBarTheme.iconTheme!.resolve({})!.color,
        AppColors.textSecondary,
        reason: '안 선택 탭은 옅은 회색이 아니라 textSecondary',
      );
    });
  });

  group('J-2 낱말 단위 줄바꿈(keepWords)', () {
    test('공백이 아닌 글자 사이에만 보이지 않는 연결 문자를 넣는다', () {
      final out = keepWords('한 줄만 남겨');
      expect(out.replaceAll('⁠', ''), '한 줄만 남겨');
      expect(out.split(' ').length, 3);
      expect(out.contains('줄⁠만'), isTrue);
    });
  });

  group('J-2 쇼핑 추천 근거 문구', () {
    test('실제로 프로필로 고른 경우에만 "종 · 생애단계"', () {
      final adult = Pet(id: 'a', name: '구름이', species: PetSpecies.dog, birthday: DateTime(2022, 1, 1));
      final puppyOnly = _product('p', lifeStages: const [LifeStageTag.puppy]);
      final forAdult = _product('a', lifeStages: const [LifeStageTag.adult]);
      expect(recommendationBasisLabel([forAdult], [adult]), '강아지 · 성견');
      // 맞는 상품이 없어 일반 상품으로 채우는 경우·반려동물이 없는 경우는 근거 없음.
      expect(recommendationBasisLabel([puppyOnly], [adult]), isNull);
      expect(recommendationBasisLabel([forAdult], const []), isNull);
    });

    test('생일을 모르면 종만', () {
      const pet = Pet(id: 'c', name: '나비', species: PetSpecies.cat, weightBand: PetWeightBand.u5);
      expect(
        recommendationBasisLabel(
          [
            _product('c', petTypes: const [PetTypeTag.cat]),
          ],
          [pet],
        ),
        '고양이',
      );
    });
  });

  group('J-6 옵션 색상 → 사이즈 나누기', () {
    final options = [
      _o('o1', '그레이 / XS'),
      _o('o2', '그레이 / S'),
      _o('o3', '그레이 / L', soldOut: true),
      _o('o4', '베이지 / XS'),
      _o('o5', '베이지 / S'),
    ];

    test('"색 / 사이즈" 꼴이면 색·사이즈 순서대로 나눈다', () {
      final axes = OptionAxes.of(options)!;
      expect(axes.colors, ['그레이', '베이지']);
      expect(axes.sizes, ['XS', 'S', 'L']);
      expect(OptionAxes.find(options, '베이지', 'S')!.id, 'o5');
      // 베이지에는 L이 없다 → 화면에서 회색 "품절".
      expect(OptionAxes.find(options, '베이지', 'L'), isNull);
    });

    test('"/"가 없거나 한 종류뿐이면 나누지 않는다(지금처럼 한 줄 칩)', () {
      expect(OptionAxes.of([_o('a', '소'), _o('b', '대')]), isNull);
      expect(OptionAxes.of([_o('a', '그레이 / M')]), isNull);
    });

    test('치수 한 줄은 상품정보제공고시 \'치수\'에서, 꼴이 다르면 없음(추정 안 함)', () {
      const notice = '등길이/가슴둘레 XS 20/28 · S 25/34 · M 30/38 · L 35/44 · XL 40/48 cm (±3cm)';
      expect(sizeMeasureLine(notice, 'M'), 'M 사이즈는 등길이 30cm, 가슴둘레 38cm예요. 재는 방법에 따라 3cm쯤 다를 수 있어요.');
      expect(sizeMeasureLine(notice, '2XL'), isNull);
      expect(sizeMeasureLine('프리사이즈', 'M'), isNull);
      expect(sizeMeasureLine(null, 'M'), isNull);
    });
  });
}
