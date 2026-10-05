import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/global_banner_ad.dart';
import '../models/signup_pet.dart';
import '../providers/auth_provider.dart';
import '../providers/effective_pets_provider.dart';
import '../providers/saved_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/external_links.dart';
import 'account_pet_actions.dart';
import 'account_ui.dart';
import 'info_screens.dart';
import 'login_screen.dart';
import 'saved_screen.dart';

const String _contactEmail = 'miyaongshop@gmail.com';
const String _appVersion = '1.0.0';

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// 내 정보 탭("디자인 1단계" 지시서 2) — 홈의 계정 배지가 열던
/// account_menu_sheet.dart 바텀시트(반려동물 관리+로그아웃)를 이
/// 탭 화면으로 옮기고, 저장한 병원·설정·이용안내·출처·방침/약관·
/// 문의하기까지 한곳에 모았다. 로그인 여부는 게이팅이 아니라 상태
/// 표시일 뿐이라, 게스트도 안내 메뉴는 그대로 쓸 수 있다.
class MyInfoScreen extends ConsumerWidget {
  const MyInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보'), automaticallyImplyLeading: false),
      body: user == null ? const _GuestBody() : _LoggedInBody(user: user),
    );
  }
}

/// 게스트 — 로그인 유도 카드 + 안내 메뉴. 앱 전체는 로그인 없이도 그대로
/// 쓸 수 있다는 점을 안내 문구에서 분명히 한다(CLAUDE.md 게이팅 금지).
class _GuestBody extends StatelessWidget {
  const _GuestBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.cardLarge),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '로그인하지 않았어요',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  '로그인하면 진료기록·예약·저장한 병원이 계정에 백업돼 휴대폰을 바꿔도 이어서 볼 수 있어요. '
                  '검색과 시세는 지금처럼 로그인 없이 쓸 수 있어요.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => _push(context, const LoginScreen()),
                    child: const Text('로그인 · 가입'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const _GuestInfoFooter(),
      ],
    );
  }
}

/// 공통 "안내" 섹션(설정·이용안내·데이터 출처·개인정보처리방침·이용약관·
/// 문의하기) + 버전 + 광고. 게스트/로그인 양쪽 몸통 맨 끝에 붙인다.
class _GuestInfoFooter extends StatelessWidget {
  const _GuestInfoFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionHeader('안내'),
        _MenuRow(title: '설정', onTap: () => _push(context, const SettingsScreen())),
        _MenuRow(title: '이용안내', onTap: () => _push(context, const GuideScreen())),
        _MenuRow(title: '데이터 출처', onTap: () => _push(context, const SourcesScreen())),
        _MenuRow(title: '개인정보처리방침', onTap: () => _push(context, const PrivacyPolicyScreen())),
        _MenuRow(title: '이용약관', onTap: () => _push(context, const TermsScreen())),
        _MenuRow(
          title: '문의하기',
          trailingText: _contactEmail,
          showChevron: false,
          onTap: () => ExternalLinks.emailContact(context, _contactEmail),
        ),
        const SizedBox(height: AppSpacing.section),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('버전 $_appVersion', style: TextStyle(fontSize: 12, color: AppColors.textPlaceholder)),
        ),
        const SizedBox(height: 12),
        const GlobalBannerAd(inline: true),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// 로그인 상태 — 프로필(이름·이메일·로그인 수단), 반려동물 관리, 내
/// 데이터(저장한 병원·설정), 안내, 로그아웃. 반려동물 추가/수정은 기존
/// [AccountPetActions]를 그대로 재사용해(진료기록 화면과 동일 로직)
/// [accountSignupPetsProvider]가 전역으로 갱신되므로 다른 화면에도 즉시
/// 반영된다.
class _LoggedInBody extends ConsumerWidget {
  final User user;

  const _LoggedInBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = user.uid;
    final name = accountLabel(user);
    final email = user.email ?? '';
    final loginType = ref.watch(currentUserProfileProvider).value?.loginType;
    final petsAsync = ref.watch(accountSignupPetsProvider);
    final savedCount = ref.watch(savedHospitalsProvider).value?.length;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryTextTone),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name님', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(email, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (loginType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    loginType.badgeLabel,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryTextTone),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const _SectionHeader('반려동물'),
        petsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('불러오지 못했습니다: $error', style: const TextStyle(color: AppColors.textSecondary)),
          ),
          data: (pets) => Column(
            children: [
              for (final pet in pets) _PetRow(pet: pet, uid: uid),
              _MenuRow(
                title: '반려동물 추가',
                leadingIcon: Icons.add,
                showChevron: false,
                onTap: () => AccountPetActions.add(context, ref, uid),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const _SectionHeader('내 데이터'),
        _MenuRow(
          title: '저장한 병원',
          trailingText: savedCount?.toString(),
          onTap: () => _push(context, const SavedScreen()),
        ),
        _MenuRow(title: '설정', onTap: () => _push(context, const SettingsScreen())),
        const SizedBox(height: AppSpacing.section),
        const _SectionHeader('안내'),
        _MenuRow(title: '이용안내', onTap: () => _push(context, const GuideScreen())),
        _MenuRow(title: '데이터 출처', onTap: () => _push(context, const SourcesScreen())),
        _MenuRow(title: '개인정보처리방침', onTap: () => _push(context, const PrivacyPolicyScreen())),
        _MenuRow(title: '이용약관', onTap: () => _push(context, const TermsScreen())),
        _MenuRow(
          title: '문의하기',
          trailingText: _contactEmail,
          showChevron: false,
          onTap: () => ExternalLinks.emailContact(context, _contactEmail),
        ),
        const Divider(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    // _LoggedInBody는 ConsumerWidget이라 pop 등으로 사라지면
                    // ref가 폐기된다 — 여기서는 pop하지 않으니 안전하지만,
                    // 다른 화면과 같은 관례로 AuthRepository를 먼저 꺼내
                    // 넘긴다("로그아웃 버그 수정" 지시서 A의 패턴 재사용).
                    final authRepo = ref.read(authRepositoryProvider);
                    confirmAndSignOut(context, authRepo);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                ),
              ),
              const Text('버전 $_appVersion', style: TextStyle(fontSize: 12, color: AppColors.textPlaceholder)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const GlobalBannerAd(inline: true),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 10),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textLabel),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String title;
  final String? trailingText;
  final IconData? leadingIcon;
  final bool showChevron;
  final VoidCallback onTap;

  const _MenuRow({
    required this.title,
    this.trailingText,
    this.leadingIcon,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 14),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: leadingIcon != null ? AppColors.primaryTextTone : AppColors.textPrimary,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(trailingText!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 4),
            ],
            if (showChevron) const Icon(Icons.chevron_right, size: 20, color: AppColors.textPlaceholder),
          ],
        ),
      ),
    );
  }
}

/// 반려동물 한 줄 — 사진(있으면)·이름·종류/품종/체중/생년월 + "수정"
/// (전체 폼, 삭제는 그 안에서). 빠른 삭제 아이콘은 두지 않는다(참고
/// 이미지와 동일 — 삭제는 수정 화면을 거친다).
class _PetRow extends ConsumerWidget {
  final SignupPet pet;
  final String uid;

  const _PetRow({required this.pet, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = pet.name?.trim().isNotEmpty == true ? pet.name!.trim() : pet.species.label;
    final subtitle = '${pet.species.label} · ${pet.breed} · ${pet.weightKg}kg · ${pet.birth}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceMutedLight,
            backgroundImage: pet.photoUrl != null ? NetworkImage(pet.photoUrl!) : null,
            child: pet.photoUrl == null ? const Icon(Icons.pets, color: AppColors.textPlaceholder) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => AccountPetActions.editOrDelete(context, ref, uid, pet),
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }
}
