// lib/features/resume/presentation/pages/resume_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/resume_provider.dart';
import '../../models/resume_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import 'resume_shared.dart' show ResumeShimmer, sb;

class ResumeListPage extends ConsumerStatefulWidget {
  const ResumeListPage({super.key});
  @override
  ConsumerState<ResumeListPage> createState() => _ResumeListPageState();
}

class _ResumeListPageState extends ConsumerState<ResumeListPage> {
  bool _searching = false;
  String _query = '';
  late final _searchCtrl = TextEditingController();
  late final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(resumeProvider.notifier).loadResumes());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    Future.delayed(const Duration(milliseconds: 80), _searchFocus.requestFocus);
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchCtrl.clear();
    });
    _searchFocus.unfocus();
  }

  List<Resume> _filtered(List<Resume> all) {
    if (_query.trim().isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((r) =>
            (r.title ?? '').toLowerCase().contains(q) ||
            (r.fileType ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController(text: file.name);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Name your resume',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style:
              TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1C20)),
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.description_outlined, color: AppColors.violet),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF3F5F9),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (!mounted || title == null) return;
    final ok = await ref
        .read(resumeProvider.notifier)
        .uploadResume(file, title: title);
    if (mounted) _snack(ok ? 'Uploaded!' : 'Upload failed', isError: !ok);
  }

  Future<void> _delete(int id, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'حذف السيرة؟' : 'Delete Resume?',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(isAr ? 'لا يمكن التراجع.' : 'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(resumeProvider.notifier).deleteResume(id);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.rose : AppColors.emerald,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  void _openFeature(String feature, List<Resume> resumes) {
    HapticFeedback.mediumImpact();
    if (resumes.isEmpty) {
      _snack('Upload a resume first', isError: true);
      return;
    }
    if (resumes.length == 1) {
      context.push('/resume/${resumes.first.id}/$feature');
      return;
    }
    _showPicker(resumes, feature);
  }

  void _showPicker(List<Resume> resumes, String feature) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
          resumes: resumes, isDark: isDark, isAr: isAr, feature: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumeProvider);
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final bg = isDark ? const Color(0xFF0F1219) : const Color(0xFFF3F5F9);
    final firstName = authState.user?.fullName.split(' ').first ?? '';
    final filtered = _filtered(state.resumes);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: MediaQuery.of(context).padding.top),

        // ── Header (search pattern from interview_list_page) ────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _searching
                ? _SearchBar(
                    key: const ValueKey('s'),
                    ctrl: _searchCtrl,
                    focus: _searchFocus,
                    isDark: isDark,
                    isAr: isAr,
                    onChanged: (v) => setState(() => _query = v),
                    onClose: _closeSearch)
                : Row(
                    key: const ValueKey('h'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (firstName.isNotEmpty)
                                Text(
                                    isAr
                                        ? 'مرحباً، $firstName'
                                        : 'Hello, $firstName',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.45)
                                            : Colors.black
                                                .withValues(alpha: 0.40))),
                              Text(isAr ? 'السيرة الذاتية' : 'Resume Hub',
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1C20))),
                            ]),
                        Row(children: [
                          // Search icon
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _openSearch();
                            },
                            child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.search_rounded,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.70)
                                        : Colors.black
                                            .withValues(alpha: 0.60))),
                          ),
                          const SizedBox(width: 10),
                          // Add — violet circle
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _upload();
                            },
                            child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: state.isUploading
                                      ? AppColors.violet.withValues(alpha: 0.5)
                                      : AppColors.violet,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.violet
                                            .withValues(alpha: 0.40),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6))
                                  ],
                                ),
                                child: state.isUploading
                                    ? const Padding(
                                        padding: EdgeInsets.all(13),
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 26)),
                          ),
                        ]),
                      ]),
          ),
        ),

        // ── Body ─────────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? _ListShimmer(isDark: isDark)
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(resumeProvider.notifier).loadResumes(),
                  color: AppColors.violet,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Stats card
                      SliverToBoxAdapter(
                          child: _StatsCard(
                              total: state.resumes.length,
                              parsed:
                                  state.resumes.where((r) => r.isParsed).length,
                              isDark: isDark,
                              isAr: isAr,
                              uploading: state.isUploading,
                              onAdd: state.isUploading ? null : _upload)),

                      // TOOLS label
                      SliverToBoxAdapter(
                          child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Text((isAr ? 'الأدوات' : 'TOOLS').toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.black.withValues(alpha: 0.35))),
                      )),

                      // 2×2 grid
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.22),
                          delegate: SliverChildListDelegate([
                            _FeatureCard(
                                icon: Icons.auto_fix_high_rounded,
                                label: isAr ? 'تحسين' : 'Enhance',
                                sub: isAr ? 'تحليل ذكي' : 'AI analysis',
                                color: AppColors.violet,
                                isDark: isDark,
                                locked: state.resumes.isEmpty,
                                onTap: () =>
                                    _openFeature('enhance', state.resumes)),
                            _FeatureCard(
                                icon: Icons.fact_check_rounded,
                                label: 'ATS Check',
                                sub: isAr ? 'درجة التوافق' : 'Compatibility',
                                color: const Color(0xFF10B981),
                                isDark: isDark,
                                locked: state.resumes.isEmpty,
                                onTap: () =>
                                    _openFeature('ats', state.resumes)),
                            _FeatureCard(
                                icon: Icons.compare_arrows_rounded,
                                label: isAr ? 'مطابقة' : 'Job Match',
                                sub: isAr ? 'قارن مع وظيفة' : 'vs job post',
                                color: const Color(0xFF0EA5E9),
                                isDark: isDark,
                                locked: state.resumes.isEmpty,
                                onTap: () =>
                                    _openFeature('match', state.resumes)),
                            _FeatureCard(
                                icon: Icons.draw_rounded,
                                label: isAr ? 'بناء' : 'Build',
                                sub: 'DOCX / PDF',
                                color: const Color(0xFFF59E0B),
                                isDark: isDark,
                                locked: false,
                                onTap: () =>
                                    _openFeature('build', state.resumes)),
                          ]),
                        ),
                      ),

                      // MY RESUMES label
                      SliverToBoxAdapter(
                          child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                (isAr ? 'سيرتي الذاتية' : 'MY RESUMES')
                                    .toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.35)
                                        : Colors.black
                                            .withValues(alpha: 0.35))),
                            if (state.resumes.isNotEmpty)
                              Text('${filtered.length}/${state.resumes.length}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.35)
                                          : Colors.black
                                              .withValues(alpha: 0.35))),
                          ],
                        ),
                      )),

                      // Content
                      if (state.error != null)
                        SliverToBoxAdapter(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _ErrorCard(
                              msg: state.error!,
                              isDark: isDark,
                              isAr: isAr,
                              onRetry: () => ref
                                  .read(resumeProvider.notifier)
                                  .loadResumes()),
                        ))
                      else if (state.resumes.isEmpty)
                        SliverToBoxAdapter(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _EmptyState(
                              isDark: isDark, isAr: isAr, onTap: _upload),
                        ))
                      else if (filtered.isEmpty && _query.isNotEmpty)
                        SliverToBoxAdapter(
                            child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Center(
                              child: Column(children: [
                            const SizedBox(height: 20),
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.20)),
                            const SizedBox(height: 12),
                            Text(isAr ? 'لا نتائج' : 'No results for "$_query"',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.40)
                                        : Colors.black
                                            .withValues(alpha: 0.40))),
                          ])),
                        ))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _ResumeCard(
                                resume: filtered[i],
                                index: i,
                                isDark: isDark,
                                isAr: isAr,
                                onTap: () =>
                                    context.push('/resume/${filtered[i].id}'),
                                onDelete: () => _delete(filtered[i].id,
                                    filtered[i].title ?? 'Resume'),
                              ),
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }
}

// ── Search bar (identical to interview_list_page) ───────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool isDark, isAr;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  const _SearchBar(
      {super.key,
      required this.ctrl,
      required this.focus,
      required this.isDark,
      required this.isAr,
      required this.onChanged,
      required this.onClose});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.violet.withValues(alpha: 0.28)),
          ),
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            onChanged: onChanged,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1C20)),
            decoration: InputDecoration(
              hintText: isAr ? 'ابحث عن سيرة ذاتية...' : 'Search resumes...',
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.28)),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 18, color: AppColors.violet.withValues(alpha: 0.55)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        )),
        const SizedBox(width: 10),
        GestureDetector(
            onTap: onClose,
            child: Text(isAr ? 'إلغاء' : 'Cancel',
                style: const TextStyle(
                    color: AppColors.violet,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
      ]);
}

// ── Stats card ──────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final int total, parsed;
  final bool isDark, isAr, uploading;
  final VoidCallback? onAdd;
  const _StatsCard(
      {required this.total,
      required this.parsed,
      required this.isDark,
      required this.isAr,
      required this.uploading,
      this.onAdd});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF5B2BE2), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF7B3FE4).withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Row(children: [
          Expanded(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                _S(isAr ? 'الكل' : 'TOTAL', '$total'),
                const _D(),
                _S(isAr ? 'محلَّل' : 'PARSED', '$parsed'),
                const _D(),
                _S(isAr ? 'معلَّق' : 'PENDING', '${total - parsed}'),
              ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: uploading ? null : onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ]),
      );
}

class _S extends StatelessWidget {
  final String l, v;
  const _S(this.l, this.v);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(v,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
        const SizedBox(height: 3),
        Text(l,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]);
}

class _D extends StatelessWidget {
  const _D();
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 36, color: Colors.white.withValues(alpha: 0.20));
}

// ── Feature card ────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final bool isDark, locked;
  final VoidCallback onTap;
  const _FeatureCard(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color,
      required this.isDark,
      required this.locked,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222C) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13)),
                          child: Icon(icon, color: color, size: 22)),
                      if (locked)
                        Icon(Icons.lock_rounded,
                            size: 13,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.22)
                                : Colors.black.withValues(alpha: 0.18)),
                    ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isDark
                              ? (locked
                                  ? Colors.white.withValues(alpha: 0.40)
                                  : Colors.white)
                              : (locked
                                  ? const Color(0xFF1A1C20)
                                      .withValues(alpha: 0.40)
                                  : const Color(0xFF1A1C20)))),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              color.withValues(alpha: locked ? 0.40 : 0.80))),
                ]),
              ]),
        ),
      );
}

// ── Resume card ─────────────────────────────────────────────────
class _ResumeCard extends StatelessWidget {
  final Resume resume;
  final int index;
  final bool isDark, isAr;
  final VoidCallback onTap, onDelete;
  const _ResumeCard(
      {required this.resume,
      required this.index,
      required this.isDark,
      required this.isAr,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + index * 60),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, 16 * (1 - v)), child: child)),
        child: Dismissible(
          key: Key('r_${resume.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: AppColors.rose, borderRadius: BorderRadius.circular(24)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 22),
            child: const Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 22),
          ),
          confirmDismiss: (_) async {
            onDelete();
            return false;
          },
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222C) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(children: [
                Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                        color: _col.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(_ico, color: _col, size: 22)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(resume.title ?? 'Untitled',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 7),
                      Row(children: [
                        _pill(
                            resume.isParsed
                                ? (isAr ? 'محلَّل' : 'Parsed')
                                : (isAr ? 'يحتاج تحليل' : 'Not Parsed'),
                            resume.isParsed
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B)),
                        ...[
                          const SizedBox(width: 6),
                          _pill(
                              resume.fileType!.toUpperCase(), AppColors.violet),
                        ],
                        if (resume.atsScore != null) ...[
                          const SizedBox(width: 6),
                          _pill('ATS ${resume.atsScore}%',
                              const Color(0xFF0EA5E9)),
                        ],
                        const Spacer(),
                        ...[
                          Icon(Icons.calendar_today_outlined,
                              size: 10,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.28)
                                  : Colors.black.withValues(alpha: 0.28)),
                          const SizedBox(width: 3),
                          Text(_date,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.28)
                                      : Colors.black.withValues(alpha: 0.28))),
                        ],
                      ]),
                    ])),
                const SizedBox(width: 8),
                Icon(
                    isAr
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.20)),
              ]),
            ),
          ),
        ),
      );

  String get _date {
    final d = resume.createdAt.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  Color get _col => resume.fileType.toLowerCase() == 'pdf'
      ? const Color(0xFFF43F5E)
      : const Color(0xFF0EA5E9);
  IconData get _ico => resume.fileType.toLowerCase() == 'pdf'
      ? Icons.picture_as_pdf_rounded
      : Icons.description_rounded;
  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6)),
        child: Text(t,
            style:
                TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

// ── Picker sheet ─────────────────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final List<Resume> resumes;
  final bool isDark, isAr;
  final String feature;
  const _PickerSheet(
      {required this.resumes,
      required this.isDark,
      required this.isAr,
      required this.feature});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D27) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Text(isAr ? 'اختر سيرة ذاتية' : 'Select a Resume',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: isDark ? Colors.white : const Color(0xFF1A1C20))),
          const SizedBox(height: 16),
          ...resumes.map((r) {
            final isPdf = r.fileType.toLowerCase() == 'pdf';
            final col =
                isPdf ? const Color(0xFFF43F5E) : const Color(0xFF0EA5E9);
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/resume/${r.id}/$feature');
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.10),
                          shape: BoxShape.circle),
                      child: Icon(
                          isPdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.description_rounded,
                          color: col,
                          size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(r.title ?? 'Resume',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1C20)))),
                  Icon(Icons.chevron_right_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.22)),
                ]),
              ),
            );
          }),
        ]),
      );
}

// ── Empty state ───────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark, isAr;
  final VoidCallback onTap;
  const _EmptyState(
      {required this.isDark, required this.isAr, required this.onTap});
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(children: [
          Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.09),
                  shape: BoxShape.circle),
              child: const Icon(Icons.description_outlined,
                  color: AppColors.violet, size: 36)),
          const SizedBox(height: 18),
          Text(isAr ? 'لا توجد سيرة ذاتية' : 'No resumes yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1C20))),
          const SizedBox(height: 8),
          Text(
              isAr
                  ? 'ارفع سيرتك لتفعيل جميع الأدوات'
                  : 'Upload a resume to unlock all features',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.40)
                      : Colors.black.withValues(alpha: 0.40))),
          const SizedBox(height: 22),
          GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                    color: AppColors.violet,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.violet.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ]),
                child: Text(isAr ? '+ رفع سيرة ذاتية' : '+ Upload Resume',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              )),
        ]),
      ));
}

// ── Error card ───────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String msg;
  final bool isDark, isAr;
  final VoidCallback onRetry;
  const _ErrorCard(
      {required this.msg,
      required this.isDark,
      required this.isAr,
      required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.rose),
        const SizedBox(height: 12),
        Text(isAr ? 'فشل التحميل' : 'Failed to load',
            style: const TextStyle(color: Colors.grey, fontSize: 15)),
        const SizedBox(height: 14),
        GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(14)),
              child: Text(isAr ? 'إعادة المحاولة' : 'Retry',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            )),
      ]));
}

// ── Shimmer for list page ─────────────────────────────────────────
class _ListShimmer extends StatelessWidget {
  final bool isDark;
  const _ListShimmer({required this.isDark});
  @override
  Widget build(BuildContext context) => ResumeShimmer(
      isDark: isDark,
      builder: (_, hi, lo, card) => SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header skeleton
              Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              sb(70, 11, lo, r: 5),
                              const SizedBox(height: 7),
                              sb(170, 28, hi, r: 8),
                            ]),
                        Row(children: [
                          sb(46, 46, lo, r: 14),
                          const SizedBox(width: 10),
                          sb(50, 50, hi, r: 25)
                        ]),
                      ])),
              const SizedBox(height: 16),
              // Stats card
              Container(
                  height: 88,
                  decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(26))),
              const SizedBox(height: 24),
              sb(54, 11, lo, r: 5), const SizedBox(height: 12),
              // 2x2 grid
              Row(children: [
                Expanded(child: _gridCard(card, hi, lo)),
                const SizedBox(width: 12),
                Expanded(child: _gridCard(card, hi, lo, w2: 72)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _gridCard(card, hi, lo, w2: 65)),
                const SizedBox(width: 12),
                Expanded(child: _gridCard(card, hi, lo, w2: 48)),
              ]),
              const SizedBox(height: 24),
              sb(90, 11, lo, r: 5), const SizedBox(height: 12),
              // Resume cards
              ...List.generate(
                  3,
                  (i) => Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ]),
                        child: Row(children: [
                          sb(50, 50, hi, r: 25),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                sb(i.isEven ? 140.0 : 110.0, 14, hi, r: 6),
                                const SizedBox(height: 8),
                                Row(children: [
                                  sb(52, 10, lo, r: 5),
                                  const SizedBox(width: 6),
                                  sb(38, 10, lo, r: 5),
                                  const Spacer(),
                                  sb(52, 10, lo, r: 5)
                                ]),
                              ])),
                          const SizedBox(width: 8),
                          sb(14, 14, lo, r: 7),
                        ]),
                      )),
            ]),
          ));

  Widget _gridCard(Color card, Color hi, Color lo, {double w2 = 60}) =>
      Container(
          height: 120,
          decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ]),
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                sb(42, 42, hi, r: 13),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  sb(w2, 13, hi, r: 6),
                  const SizedBox(height: 5),
                  sb(45, 10, lo, r: 5),
                ]),
              ]));
}
