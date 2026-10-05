import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../widgets/mascot_image.dart';

/// 가입 완료("펫클 앱 디자인" 캔버스 시안 SignupDone.dc.html) — 마스코트
/// + 완료 문구 + "시작하기"(홈까지 전부 pop). "첫 진료기록 남기기"는
/// 아직 반려동물 문서 id를 모르는 시점(가입 직후 1프레임)이라 섣불리
/// 특정 화면을 열지 않고, 홈으로 보낸 뒤 사용자가 진료기록 탭에서
/// 직접 시작하게 한다 — 과장·유도 문구 없이 담백하게.
class SignupDoneScreen extends StatelessWidget {
  final VoidCallback onDone;

  const SignupDoneScreen({super.key, required this.onDone});

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
                    const Text(
                      '이제 우리 아이의 진료기록과 예약을\n계정에 저장할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
                  ),
                  child: const Text('시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
