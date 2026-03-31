// lib/features/resume/presentation/pages/resume_list_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/resume_provider.dart';
import '../../models/resume_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/locale/app_strings.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../../../shared/widgets/background_painter.dart';
import '../../../auth/screens/login_screen.dart'; // Re-using GlassCard
import '../../../../shared/widgets/skeleton_widgets.dart';
import '../../../../shared/widgets/transitions.dart';

class ResumeListPage extends ConsumerStatefulWidget {
  const ResumeListPage({super.key});
  @override
  ConsumerState<ResumeListPage> createState() => _ResumeListPageState();
}

class _ResumeListPageState extends ConsumerState<ResumeListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(resumeProvider.notifier).loadResumes());
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;
    final title = await _showTitleDialog(file.name);
    if (!mounted) return;
    if (title == null) return;
    final success = await ref
        .read(resumeProvider.notifier)
        .uploadResume(file, title: title);
    if (mounted) {
      final s = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? s.resumeUploadedOk : s.resumeUploadFailed),
        backgroundColor: success ? AppColors.emerald : AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<String?> _showTitleDialog(String filename) async {
    final controller = TextEditingController(text: filename);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(s.resumeNameTitle,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Title',
            prefixIcon:
                const Icon(Icons.description_outlined, color: AppColors.violet),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(s.resumeUpload),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(int id, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(s.resumeDeleteTitle,
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text('"$title" — ${s.resumeDeleteBody}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(resumeProvider.notifier).deleteResume(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: Stack(
        children: [
          const BackgroundPainter(),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Premium Sticky App Bar ────────────────────────────────────
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: 120,
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: FlexibleSpaceBar(
                      centerTitle: false,
                      titlePadding: const EdgeInsetsDirectional.only(
                          start: 20, bottom: 16),
                      title: Text(s.resumeTitle,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5)),
                      background: Container(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Boxed Refresh Button
                  GestureDetector(
                    onTap: () =>
                        ref.read(resumeProvider.notifier).loadResumes(),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05)),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          size: 20,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),

              // ── Loading Skeleton ──────────────────────────────────────────
              if (state.isLoading) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _SkeletonBlock(
                        height: 100, radius: 28, isDark: isDark), // Stats
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _SkeletonBlock(
                        height: 80, radius: 24, isDark: isDark), // Upload Card
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(top: 24),
                  sliver: SliverToBoxAdapter(child: ResumeListSkeleton()),
                ),
              ]

              // ── Error State ───────────────────────────────────────────────
              else if (state.error != null)
                SliverFillRemaining(
                  child: Center(child: Text(state.error!)),
                )

              // ── Success State ─────────────────────────────────────────────
              else ...[
                if (state.resumes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _PremiumStatsBar(
                          resumes: state.resumes, isDark: isDark, s: s),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: TapScale(
                      onTap: state.isUploading ? () {} : _pickAndUpload,
                      child: _ModernUploadCard(
                          isDark: isDark,
                          isUploading: state.isUploading,
                          s: s,
                          onTap: state.isUploading ? null : _pickAndUpload),
                    ),
                  ),
                ),
                if (state.resumes.isEmpty)
                  SliverFillRemaining(
                      child: _EmptyState(
                          isDark: isDark, onUpload: _pickAndUpload, s: s))
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Text(s.resumeManagement.toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 1.5)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _StaggeredItem(
                          index: i,
                          child: _SwipeableCard(
                            resume: state.resumes[i],
                            isDark: isDark,
                            onTap: () =>
                                context.push('/resume/${state.resumes[i].id}'),
                            onDelete: () => _confirmDelete(state.resumes[i].id,
                                state.resumes[i].title ?? 'Resume'),
                          ),
                        ),
                        childCount: state.resumes.length,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ★ COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonBlock extends StatelessWidget {
  final double height, radius;
  final bool isDark;
  const _SkeletonBlock(
      {required this.height, required this.radius, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _PremiumStatsBar extends StatelessWidget {
  final List<Resume> resumes;
  final bool isDark;
  final AppStrings s;
  const _PremiumStatsBar(
      {required this.resumes, required this.isDark, required this.s});

  @override
  Widget build(BuildContext context) {
    final analyzed = resumes.where((r) => r.analysisScore != null).length;
    final atsScores = resumes
        .where((r) => r.atsScore != null)
        .map((r) => r.atsScore!)
        .toList();
    final avgAts = atsScores.isEmpty
        ? 0
        : (atsScores.reduce((a, b) => a + b) / atsScores.length).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0C4A6E)]
              : [const Color(0xFF4C1D95), const Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(children: [
        _statItem('${resumes.length}', s.resumeTotal, AppColors.violetLt),
        _divider(),
        _statItem('$analyzed', s.resumeAnalyzed2, AppColors.emerald),
        _divider(),
        _statItem('$avgAts%', s.resumeAvgAts, AppColors.cyan),
      ]),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
        child: Column(children: [
          Text(v,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 4),
          Text(l.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ]),
      );
  Widget _divider() => Container(width: 1, height: 30, color: Colors.white10);
}

class _ModernUploadCard extends StatelessWidget {
  final bool isDark, isUploading;
  final VoidCallback? onTap;
  final AppStrings s;
  const _ModernUploadCard(
      {required this.isDark,
      required this.isUploading,
      required this.onTap,
      required this.s});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.cyan, Color(0xFF0891B2)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: isUploading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isUploading ? s.resumeUploading : s.resumeUpload,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87)),
            Text(s.resumeUploadSub,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ]),
        ),
        const Icon(Icons.add_circle_outline_rounded, color: AppColors.cyan),
      ]),
    );
  }
}

class _SwipeableCard extends StatelessWidget {
  final Resume resume;
  final bool isDark;
  final VoidCallback onTap, onDelete;
  const _SwipeableCard(
      {required this.resume,
      required this.isDark,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('res_${resume.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: AppColors.rose, borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_sweep_rounded,
            color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: TapScale(
          onTap: onTap,
          child: GlassCard(
            isDark: isDark,
            child: Row(children: [
              _FileIcon(fileType: resume.fileType ?? 'pdf'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resume.title ?? 'Untitled Resume',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _miniBadge(resume.statusLabel, resume.statusColor),
                        if (resume.atsScore != null) ...[
                          const SizedBox(width: 8),
                          _miniBadge('ATS ${resume.atsScore}%', AppColors.cyan),
                        ]
                      ]),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

class _FileIcon extends StatelessWidget {
  final String fileType;
  const _FileIcon({required this.fileType});
  @override
  Widget build(BuildContext context) {
    final isPdf = fileType.toLowerCase() == 'pdf';
    final color = isPdf ? const Color(0xFFEF4444) : AppColors.cyan;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Icon(
          isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
          color: color,
          size: 22),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onUpload;
  final AppStrings s;
  const _EmptyState(
      {required this.isDark, required this.onUpload, required this.s});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_rounded,
              size: 64, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 16),
          Text(s.resumeNoResumes,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          Text(s.resumeNoResumesSub,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          TapScale(
            onTap: onUpload,
            child: ElevatedButton(
              onPressed: onUpload,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              child: Text(s.resumeSelectFile,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      );
}

class _StaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredItem({required this.index, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + index * 60),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
            opacity: v,
            child:
                Transform.translate(offset: Offset(0, (1 - v) * 18), child: c)),
        child: child,
      );
}
