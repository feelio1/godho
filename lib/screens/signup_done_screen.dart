import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/mascot_image.dart';

/// 가입 완료("펫클 앱 디자인" 캔버스 시안 SignupDone.dc.html) — 마스코트 +
/// 완료 문구 + 버튼 2개. 반려동물을 등록했으면 "첫 일기 쓰기" / "홈으로",
/// 등록하지 않았으면 "반려동물 등록하기" / "홈으로"(2차 업데이트 C). 실제
/// 이동은 호출부([onPrimary]/[onHome])가 맡는다 — 과장·유도 문구 없이 담백하게.
class SignupDoneScreen extends StatelessWidget {
  final bool hasPets;
  final VoidCallback onPrimary;
  final VoidCallback onHome;

  const SignupDoneScreen({super.key, required this.hasPets, required this.onPrimary, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 56, AppSpacing.page, 24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MascotImage(size: 140),
                    const SizedBox(height: 24),
                    const Text(
                      '가입이 끝났어요',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasPets
                          ? '이제 우리 아이의 일기와 진료기록을\n계정에 저장할 수 있어요.'
                          : '우리 아이를 등록하면 일기와 진료기록을\n계정에 저장할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
                  ),
                  child: Text(
                    hasPets ? '첫 일기 쓰기' : '반려동물 등록하기',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(onPressed: onHome, child: const Text('홈으로')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
