import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../data/app_settings.dart';
import '../models/app_user.dart';
import '../models/hospital_status.dart';
import '../notifications/notification_service.dart';
import '../providers/auth_provider.dart';
import '../providers/bundle_provider.dart';
import '../providers/fee_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/auth_error_message.dart';
import '../utils/external_links.dart';
import '../widgets/legal_markdown_view.dart';

/// 설정 화면(Settings.dc.html) — 기기 로컬 설정 + "계정" 섹션(회원 탈퇴).
/// 회원 탈퇴는 로그인 상태에서만 보인다(지시서 E) — 되돌릴 수 없는 작업이라
/// 2단계 확인을 거친다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _notificationsEnabled;
  LocationPermission? _locationPermission;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
    _loadLocationPermission();
  }

  Future<void> _loadNotificationSetting() async {
    final enabled = await const AppSettings().notificationsEnabled();
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  /// 읽기 전용 상태 확인 — 권한 다이얼로그를 띄우지 않는다(CLAUDE.md:
  /// 위치 권한은 "주변 병원" 진입 시에만 요청).
  Future<void> _loadLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() => _locationPermission = permission);
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    setState(() => _notificationsEnabled = value);
    await const AppSettings().setNotificationsEnabled(value);
    if (!value) {
      await NotificationService.instance.cancelAll();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? '예약 알림을 켰습니다.' : '예약 알림을 껐습니다. 예약된 알림을 모두 취소했습니다.'),
      ),
    );
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await NotificationService.instance.sendTestNotification();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '1분 뒤 테스트 알림이 울립니다. 안 오면 알림 권한·배터리 최적화 설정을 확인해주세요.'
              : '테스트 알림을 예약하지 못했습니다. 알림 권한을 확인해주세요.',
        ),
      ),
    );
  }

  /// "1분 뒤 테스트 알림"이 안 올 때, 문제가 초기화·채널·권한 쪽인지
  /// 스케줄링(예약) 쪽인지 갈라보는 즉시 알림(스프린트 15 지시서 1).
  Future<void> _sendImmediateTestNotification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await NotificationService.instance.showImmediateTestNotification();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '즉시 알림을 보냈습니다. 지금 바로 안 보이면 이 기기에서 알림 권한이 꺼져 있는지 확인해주세요.'
              : '즉시 알림을 보내지 못했습니다. 알림 권한을 확인해주세요.',
        ),
      ),
    );
  }

  Future<void> _resetFeeWeight(BuildContext context) async {
    ref.read(feeWeightProvider.notifier).reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('시세 조회에 쓰던 체중 입력값을 초기화했습니다.')),
    );
  }

  /// 회원 탈퇴 전체 흐름: 강한 경고 → 체크 확인 → 실제 삭제. 삭제 순서가
  /// 중요하다 — Firestore(본인 데이터)를 먼저 지운 뒤 Auth 계정을 지운다.
  /// 반대로 하면 Auth 계정이 없어진 순간 보안 규칙상 본인 데이터에 더는
  /// 쓸 수 없어 Firestore 정리가 막힌다. Auth 삭제가 `requires-recent-login`
  /// 로 실패하면 로그인 수단에 맞게 재인증한 뒤 다시 시도한다.
  Future<void> _confirmAndDeleteAccount(BuildContext context, String uid) async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '계정과 저장된 진료기록·예약·저장한 병원이 모두 삭제되며 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('계속', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (step1 != true || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _DeleteAccountConfirmDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    await _performAccountDeletion(context, uid);
  }

  Future<void> _performAccountDeletion(BuildContext context, String uid) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 16),
            Text('탈퇴 처리 중…'),
          ],
        ),
      ),
    );

    String? errorMessage;
    try {
      await ref.read(userRepositoryProvider).deleteAllUserData(uid);
      if (!context.mounted) return;
      await _deleteAuthAccountWithReauth(context, uid);
    } on FirebaseAuthException catch (e) {
      errorMessage = authErrorMessage(e);
    } on _ReauthNotSupportedException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = '탈퇴에 실패했어요. 잠시 후 다시 시도해주세요. ($e)';
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // 처리 중 다이얼로그 닫기

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('탈퇴가 완료됐습니다.')),
    );
  }

  /// Auth 계정 삭제를 시도하고, `requires-recent-login`이면 로그인 수단에
  /// 맞게 재인증한 뒤 한 번 더 시도한다. 카카오(현재 Firebase 세션으로
  /// 이어지지 않아 실제로는 도달하지 않음)나 수단을 알 수 없는 경우는
  /// 재인증 방법이 없어 안내만 하고 멈춘다(크래시 금지).
  Future<void> _deleteAuthAccountWithReauth(BuildContext context, String uid) async {
    final authRepo = ref.read(authRepositoryProvider);
    try {
      await authRepo.deleteCurrentUser();
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
    }

    final profile = await ref.read(currentUserProfileProvider.future);
    final loginType = profile?.loginType;

    switch (loginType) {
      case LoginType.google:
        await authRepo.reauthenticateWithGoogle();
      case LoginType.apple:
        await authRepo.reauthenticateWithApple();
      case LoginType.email:
        if (!context.mounted) {
          throw const _ReauthNotSupportedException('보안을 위해 다시 로그인한 뒤 탈퇴해주세요.');
        }
        final password = await _promptPassword(context);
        if (password == null) {
          throw const _ReauthNotSupportedException('탈퇴가 취소됐습니다. 다시 시도해주세요.');
        }
        final email = ref.read(authStateProvider).value?.email ?? profile?.email;
        if (email == null) {
          throw const _ReauthNotSupportedException('이메일 정보를 확인할 수 없어요. 보안을 위해 다시 로그인한 뒤 탈퇴해주세요.');
        }
        await authRepo.reauthenticateWithEmail(email, password);
      case LoginType.kakao:
      case null:
        throw const _ReauthNotSupportedException('보안을 위해 다시 로그인한 뒤 탈퇴해주세요.');
    }

    await authRepo.deleteCurrentUser();
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('다시 로그인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('보안을 위해 비밀번호를 다시 입력해주세요.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(hintText: '비밀번호'),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  static String _locationPermissionLabel(LocationPermission? permission) {
    switch (permission) {
      case LocationPermission.always:
        return '항상 허용';
      case LocationPermission.whileInUse:
        return '앱 사용 중 허용';
      case LocationPermission.denied:
        return '거부됨';
      case LocationPermission.deniedForever:
        return '거부됨 (기기 설정에서 다시 켤 수 있어요)';
      case LocationPermission.unableToDetermine:
        return '확인할 수 없음';
      case null:
        return '확인 중…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(bundleProvider).value;
    final generatedAt = bundle?.generatedAt;
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: '알림',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('예약 알림'),
                subtitle: const Text('진료 예약에 등록한 알림을 울릴지 정합니다. 꺼두면 예약된 알림을 모두 취소합니다.'),
                value: _notificationsEnabled ?? true,
                onChanged: _notificationsEnabled == null ? null : _setNotificationsEnabled,
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                '알림이 실제로 울리는지 확인하고 싶다면 아래 버튼을 사용하세요. 알림 권한과 정확한 시각 '
                '알림 권한을 이 시점에 함께 확인·요청합니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _sendTestNotification(context),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('1분 뒤 테스트 알림 보내기'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _sendImmediateTestNotification(context),
                  icon: const Icon(Icons.bolt_outlined),
                  label: const Text('즉시 테스트 알림 보내기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '위치',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('위치 권한'),
                subtitle: Text(_locationPermissionLabel(_locationPermission)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Geolocator.openAppSettings(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '이 기기의 데이터',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('시세 입력값 초기화'),
                subtitle: const Text('진료비 시세 조회에 쓰던 체중 선택값을 기본값으로 되돌립니다.'),
                trailing: OutlinedButton(
                  onPressed: () => _resetFeeWeight(context),
                  child: const Text('초기화'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (uid != null) ...[
            const SizedBox(height: 16),
            _SettingsSection(
              title: '계정',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('회원 탈퇴'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmAndDeleteAccount(context, uid),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              generatedAt != null ? '데이터 기준일 ${DateFormat('yyyy.MM.dd').format(generatedAt)}' : '데이터 기준일 확인 불가',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// 재인증 방법이 없거나(알 수 없는 로그인 수단) 사용자가 재인증을
/// 취소했을 때 — [FirebaseAuthException]이 아니라 이 앱이 만든 안내용
/// 예외라 `authErrorMessage`를 거치지 않고 [message]를 그대로 보여준다.
class _ReauthNotSupportedException implements Exception {
  final String message;
  const _ReauthNotSupportedException(this.message);

  @override
  String toString() => message;
}

/// 회원 탈퇴 2단계 확인 — 체크를 해야만 "탈퇴"가 눌린다. 실수로 바로
/// 눌러 지워지는 일을 막는다.
class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  State<_DeleteAccountConfirmDialog> createState() => _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState extends State<_DeleteAccountConfirmDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('정말 탈퇴하시겠어요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('반려동물 정보, 진료기록, 예약, 저장한 병원이 모두 삭제되며 복구할 수 없어요.'),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _acknowledged = !_acknowledged),
            child: Row(
              children: [
                Checkbox(
                  value: _acknowledged,
                  onChanged: (value) => setState(() => _acknowledged = value ?? false),
                ),
                const Expanded(child: Text('삭제된 데이터는 복구할 수 없다는 것을 확인했습니다.')),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
        TextButton(
          onPressed: _acknowledged ? () => Navigator.of(context).pop(true) : null,
          child: const Text('탈퇴', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 데이터 출처(Sources.dc.html) — 수치는 전부 실제 번들에서 계산한다.
/// 시안에는 "[갱신 주기]"처럼 아직 모르는 값을 괄호로 비워둔 자리가
/// 있는데, 추정해서 채우지 않고 CLAUDE.md 원칙 5대로 "확인 불가"라고
/// 솔직히 쓴다.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(bundleProvider).value;
    final feeBundle = ref.watch(feeBundleProvider).value;
    final hospitals = bundle?.hospitals ?? const [];
    final openCount = hospitals.where((h) => h.status == HospitalStatus.open).length;
    final closedCount = hospitals.where((h) => h.status == HospitalStatus.closed).length;
    final noCoordCount = hospitals.where((h) => h.lat == null || h.lng == null).length;
    final noCoordPct = hospitals.isEmpty ? null : (noCoordCount / hospitals.length * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('데이터 출처')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '펫클의 병원 정보와 시세는 모두 공개된 공공데이터를 가공한 것이에요.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _SourceCard(
            title: '동물병원 인허가 정보',
            rows: [
              _SourceRow('제공', bundle?.source ?? '확인 불가'),
              const _SourceRow('항목', '상호 · 주소 · 전화 · 인허가일 · 폐업일 · 영업상태 · 좌표'),
              _SourceRow(
                '수록',
                hospitals.isEmpty ? '확인 불가' : '${hospitals.length}곳 (영업 $openCount · 폐업 $closedCount)',
                mono: true,
              ),
              _SourceRow(
                '기준일',
                bundle?.generatedAt != null ? DateFormat('yyyy.MM.dd').format(bundle!.generatedAt!) : '확인 불가',
                mono: true,
              ),
              const _SourceRow('갱신', '확인 불가'),
            ],
          ),
          const SizedBox(height: 12),
          _SourceCard(
            title: '동물병원 진료비 정보',
            rows: [
              _SourceRow('제공', feeBundle?.source ?? '확인 불가'),
              const _SourceRow('항목', '진찰 · 백신 · 검사 · 영상 · 입원 · 예방 항목별 공개 가격'),
              const _SourceRow('표시', '시도·시군구별 중간값과 최소–최대'),
              _SourceRow(
                '기준',
                feeBundle?.baseDate != null ? DateFormat('yyyy.MM').format(feeBundle!.baseDate!) : '확인 불가',
                mono: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SourceCard(
            title: '펫클이 가공하는 방식',
            rows: const [],
            children: [
              _HowStep(1, '같은 주소에서 이름만 바뀌어 이어진 등록은 하나로 묶어 보여드려요. 펼치면 원래 기록을 모두 볼 수 있어요.'),
              _HowStep(
                2,
                noCoordPct != null
                    ? '좌표가 없는 병원(약 $noCoordPct%)은 지도에서만 빠지고, 검색과 상세에는 그대로 나와요.'
                    : '좌표가 없는 병원은 지도에서만 빠지고, 검색과 상세에는 그대로 나와요.',
              ),
              const _HowStep(3, '가격을 공개한 병원이 1곳뿐인 항목은 범위 없이 참고용으로 표시해요.'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('정보가 실제와 다르다면 알려주세요.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => ExternalLinks.emailContact(context, 'miyaongshop@gmail.com'),
            child: const Text(
              '정보 수정 요청하기',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow {
  final String label;
  final String value;
  final bool mono;

  const _SourceRow(this.label, this.value, {this.mono = false});
}

class _SourceCard extends StatelessWidget {
  final String title;
  final List<_SourceRow> rows;
  final List<Widget> children;

  const _SourceCard({required this.title, required this.rows, this.children = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(row.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: row.mono ? AppTextStyles.mono(size: 13, color: AppColors.textPrimary) : const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  final int index;
  final String text;

  const _HowStep(this.index, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Text('$index', style: AppTextStyles.mono(size: 11, color: AppColors.primaryTextTone)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5))),
        ],
      ),
    );
  }
}

/// 개인정보처리방침·이용약관 공용 틀 — assets/legal/*.md를 읽어 그대로
/// 보여준다(지시서 F: 본문을 줄이거나 바꿔 쓰지 않는다. 【...】 같은
/// 자리표시자도 그대로 노출 — 출시 시 이 에셋 파일만 교체하면 반영된다).
class _LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const _LegalDocumentScreen({required this.title, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$title을 불러오지 못했습니다.', style: Theme.of(context).textTheme.bodyMedium),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LegalMarkdownView(markdown: snapshot.data!),
          );
        },
      ),
    );
  }
}

/// 개인정보처리방침.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: '개인정보처리방침',
      assetPath: 'assets/legal/privacy_policy.md',
    );
  }
}

/// 이용약관.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: '이용약관',
      assetPath: 'assets/legal/terms_of_service.md',
    );
  }
}

/// 이용안내(About.dc.html) — "펫클이 하지 않는 것"·"화면에 나오는 말"은
/// CLAUDE.md 절대 원칙(평가 금지, 출처 필수, 확인 안 됨을 솔직히)을 그대로
/// 사용자에게 설명하는 화면이라 시안 문구를 거의 그대로 옮긴다. "운영
/// 방식"만 실제로 구현된 것(하단 광고)만 남기고, 아직 넣지 않은 펫보험
/// 제휴 링크는 언급하지 않는다(있지도 않은 기능을 안내하지 않기 위해).
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용안내')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GuideSection(
            title: '펫클은 이런 앱이에요',
            child: const Text(
              '정부 공공데이터를 바탕으로 동물병원의 개원 시기, 같은 주소의 인허가 기록, 지역 진료비 시세를 보여드려요. '
              '판단은 보호자님이 하실 수 있도록 사실만 정리해요.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: '펫클이 하지 않는 것',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NoItem('병원을 평가하거나 점수·순위를 매기지 않아요'),
                _NoItem('리뷰를 받지 않아요. 외부 지도 서비스로 연결만 해요'),
                _NoItem('병원으로부터 광고비나 수수료를 받지 않아요'),
                _NoItem('병원 진료 예약을 대신 접수하지 않아요'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: '화면에 나오는 말',
            child: const Column(
              children: [
                _TermRow('운영 N년차', '인허가 개원일부터 데이터 기준일까지의 기간이에요.'),
                _TermRow('인허가 상태', '지자체에 신고된 상태예요. 지금 문을 열었는지를 실시간으로 알려주지는 않아요.'),
                _TermRow('같은 주소 기록', '같은 주소에 등록된 인허가 이력이에요. 운영자가 같다는 뜻은 아니에요.'),
                _TermRow('지역 중간값', '지역 병원이 공개한 가격을 순서대로 놓았을 때 가운데 값이에요.'),
                _TermRow('표본', '그 항목의 가격을 공개한 병원 수예요. 적을수록 참고용으로 봐주세요.', showDivider: false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: '운영 방식',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '앱 하단 광고로 운영해요. 광고는 병원 정보·시세 표시 방식에 영향을 주지 않아요.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SourcesScreen()),
                  ),
                  child: const Text(
                    '데이터 출처 보기',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _GuideSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NoItem extends StatelessWidget {
  final String text;

  const _NoItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.remove, size: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4))),
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  final String term;
  final String description;
  final bool showDivider;

  const _TermRow(this.term, this.description, {this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: showDivider
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderCard)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}
