// lib/features/resume/presentation/pages/resume_builder_page.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/locale/app_strings.dart';
import '../../../../shared/widgets/background_painter.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../providers/resume_provider.dart';

class ResumeBuilderPage extends ConsumerStatefulWidget {
  final int? sourceResumeId;
  const ResumeBuilderPage({super.key, this.sourceResumeId});
  @override
  ConsumerState<ResumeBuilderPage> createState() => _ResumeBuilderPageState();
}

class _ResumeBuilderPageState extends ConsumerState<ResumeBuilderPage>
    with TickerProviderStateMixin {
  _BuildMode? _mode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
        extendBody: true,
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        bottomNavigationBar: const AppBottomNav(currentIndex: 2),
        body: Stack(children: [
          const BackgroundPainter(),
          SafeArea(
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOutCubic)),
                          child: child)),
                  child: _mode == null
                      ? _ModeSelector(
                          key: const ValueKey('mode'),
                          isDark: isDark,
                          s: s,
                          isAr: isAr,
                          sourceResumeId: widget.sourceResumeId,
                          onSelect: (m) => setState(() => _mode = m))
                      : _mode == _BuildMode.manual
                          ? _ManualBuilder(
                              key: const ValueKey('manual'),
                              isDark: isDark,
                              s: s,
                              isAr: isAr,
                              onBack: () => setState(() => _mode = null))
                          : _AIBuilder(
                              key: const ValueKey('ai'),
                              isDark: isDark,
                              s: s,
                              isAr: isAr,
                              sourceResumeId: widget.sourceResumeId,
                              onBack: () => setState(() => _mode = null)))),
        ]));
  }
}

enum _BuildMode { manual, ai }

// ── MODE SELECTOR ─────────────────────────────────────────────────────────────
class _ModeSelector extends StatelessWidget {
  final bool isDark, isAr;
  final int? sourceResumeId;
  final AppStrings s;
  final ValueChanged<_BuildMode> onSelect;
  const _ModeSelector(
      {super.key,
      required this.isDark,
      required this.isAr,
      required this.sourceResumeId,
      required this.s,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.go('/resume')),
              const SizedBox(width: 4),
              Text(s.builderTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18)),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero banner
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                                    AppColors.violet.withValues(alpha: 0.15),
                                    AppColors.cyan.withValues(alpha: 0.08)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppColors.violet.withValues(alpha: 0.2))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✨', style: TextStyle(fontSize: 32)),
                                const SizedBox(height: 8),
                                Text(
                                    isAr
                                        ? 'أنشئ سيرتك الذاتية المثالية'
                                        : 'Build Your Perfect Resume',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20)),
                                const SizedBox(height: 6),
                                Text(
                                    isAr
                                        ? 'اختر الطريقة التي تريد بها إنشاء سيرتك.\nكلا الخيارين ينتجان ملفات DOCX و PDF احترافية.'
                                        : 'Choose how you want to create your resume.\nBoth options produce professional DOCX & PDF files.',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
                                        height: 1.5)),
                              ])),
                      const SizedBox(height: 28),
                      Text(s.builderSelectPath,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.grey)),
                      const SizedBox(height: 14),
                      _ModeCard(
                          emoji: '📝',
                          title: s.builderFillSelf,
                          subtitle: s.builderManualSub,
                          description: isAr
                              ? 'أدخل معلوماتك خطوة بخطوة — التواصل والخبرة والتعليم والمهارات والمشاريع. تحكم كامل في كل كلمة.'
                              : 'Enter your information step by step — contact, experience, education, skills, projects. Full control over every word.',
                          features: isAr
                              ? [
                                  'مُعبّأة من السيرة المحللة',
                                  'عدّل كل حقل بحرية',
                                  'معاينة قبل التحميل'
                                ]
                              : [
                                  'Pre-filled from parsed resume',
                                  'Edit every field freely',
                                  'Preview before downloading'
                                ],
                          accentColor: AppColors.violet,
                          isDark: isDark,
                          onTap: () => onSelect(_BuildMode.manual)),
                      const SizedBox(height: 16),
                      _ModeCard(
                          emoji: '🤖',
                          title: s.builderLetAi,
                          subtitle: s.builderAiSub,
                          description: isAr
                              ? 'الذكاء يقرأ محتوى سيرتك المحللة ويكتب سيرة ذاتية احترافية مخصصة للدور والأسلوب المختار.'
                              : 'AI reads your parsed resume content and writes a polished, professional resume tailored to your target role and tone.',
                          features: isAr
                              ? [
                                  'اختر الدور المستهدف والقطاع',
                                  'اختر الأسلوب: احترافي / جريء / تقني',
                                  'الذكاء يعيد الكتابة لتأثير أقصى'
                                ]
                              : [
                                  'Choose target role & industry',
                                  'Select tone: Professional / Aggressive / Technical',
                                  'AI rewrites for maximum impact'
                                ],
                          accentColor: AppColors.emerald,
                          isDark: isDark,
                          badge: sourceResumeId != null
                              ? s.builderResLoaded
                              : null,
                          onTap: () => onSelect(_BuildMode.ai)),
                    ]))),
      ]);
}

class _ModeCard extends StatelessWidget {
  final String emoji, title, subtitle, description;
  final List<String> features;
  final Color accentColor;
  final bool isDark;
  final String? badge;
  final VoidCallback onTap;
  const _ModeCard(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.description,
      required this.features,
      required this.accentColor,
      required this.isDark,
      required this.onTap,
      this.badge});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: accentColor.withValues(alpha: 0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14)),
                  child: Text(emoji, style: const TextStyle(fontSize: 24))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(subtitle,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ])),
              if (badge != null) ...[
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(badge!,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900))),
              ],
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: accentColor),
            ]),
            const SizedBox(height: 14),
            Text(description,
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 12, height: 1.5)),
            const SizedBox(height: 14),
            ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: accentColor, size: 14),
                  const SizedBox(width: 8),
                  Text(f,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]))),
          ])));
}

// ── MANUAL BUILDER ────────────────────────────────────────────────────────────
class _ManualBuilder extends ConsumerStatefulWidget {
  final bool isDark, isAr;
  final AppStrings s;
  final VoidCallback onBack;
  const _ManualBuilder(
      {super.key,
      required this.isDark,
      required this.isAr,
      required this.s,
      required this.onBack});
  @override
  ConsumerState<_ManualBuilder> createState() => _ManualBuilderState();
}

class _ManualBuilderState extends ConsumerState<_ManualBuilder>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _downloading = false;
  String _selectedTemplate = 'professional';
  String _selectedFormat = 'docx';

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _linkedin = TextEditingController();
  final _github = TextEditingController();
  final _summary = TextEditingController();

  final List<Map<String, TextEditingController>> _experience = [];
  final List<Map<String, TextEditingController>> _education = [];
  final _skillInput = TextEditingController();
  final List<String> _skills = [];
  final List<Map<String, TextEditingController>> _projects = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _addExp();
    _addEdu();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _name,
      _email,
      _phone,
      _location,
      _linkedin,
      _github,
      _summary,
      _skillInput
    ]) {
      c.dispose();
    }
    for (final e in [..._experience, ..._education, ..._projects]) {
      for (final c in e.values) c.dispose();
    }
    super.dispose();
  }

  void _addExp() => _experience.add({
        'title': TextEditingController(),
        'company': TextEditingController(),
        'duration': TextEditingController(),
        'description': TextEditingController()
      });

  void _addEdu() => _education.add({
        'degree': TextEditingController(),
        'institution': TextEditingController(),
        'year': TextEditingController(),
        'gpa': TextEditingController()
      });

  void _addProject() => _projects.add({
        'name': TextEditingController(),
        'technologies': TextEditingController(),
        'description': TextEditingController()
      });

  Map<String, dynamic> _buildData() => {
        'name': _name.text.trim(),
        'contact_info': {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'location': _location.text.trim(),
          'linkedin': _linkedin.text.trim(),
          'github': _github.text.trim()
        },
        'summary': _summary.text.trim(),
        'experience': _experience
            .where((e) => e['title']!.text.isNotEmpty)
            .map((e) => {
                  'title': e['title']!.text,
                  'company': e['company']!.text,
                  'duration': e['duration']!.text,
                  'description': e['description']!.text
                })
            .toList(),
        'education': _education
            .where((e) => e['degree']!.text.isNotEmpty)
            .map((e) => {
                  'degree': e['degree']!.text,
                  'institution': e['institution']!.text,
                  'year': e['year']!.text,
                  'gpa': e['gpa']!.text
                })
            .toList(),
        'skills': _skills,
        'projects': _projects
            .where((p) => p['name']!.text.isNotEmpty)
            .map((p) => {
                  'name': p['name']!.text,
                  'technologies': p['technologies']!.text,
                  'description': p['description']!.text
                })
            .toList(),
      };

  Future<void> _download() async {
    final s = widget.s;
    final isAr = widget.isAr;
    if (_name.text.trim().isEmpty) {
      _snack(s.builderNameFirst, isError: true);
      _tabs.animateTo(0);
      return;
    }
    setState(() => _downloading = true);
    final service = ref.read(resumeServiceProvider);
    final data = _buildData();
    Uint8List? bytes;
    String ext;
    if (_selectedFormat == 'pdf') {
      bytes = await service.buildAndDownloadPdf(data, _selectedTemplate);
      ext = 'pdf';
    } else {
      bytes = await service.buildAndDownloadDocx(data, _selectedTemplate);
      ext = 'docx';
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    if (bytes != null) {
      _triggerDownload(bytes,
          '${_name.text.trim().replaceAll(' ', '_').toLowerCase()}_resume.$ext');
      _snack(s.builderDownloadOk);
    } else {
      _snack(s.builderDownloadFail, isError: true);
    }
  }

  void _triggerDownload(Uint8List bytes, String filename) {
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    (web.HTMLAnchorElement()
          ..href = url
          ..download = filename)
        .click();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.rose : AppColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final isAr = widget.isAr;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: widget.onBack),
            const SizedBox(width: 4),
            Text(s.builderManualHeader,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            _FormatToggle(
                selected: _selectedFormat,
                onChanged: (f) => setState(() => _selectedFormat = f)),
          ])),
      ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                  color: widget.isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.8),
                  child: TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      indicatorColor: AppColors.violet,
                      labelColor: AppColors.violet,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 10),
                      tabs: [
                        Tab(text: isAr ? 'التواصل' : 'CONTACT'),
                        Tab(text: isAr ? 'الخبرة' : 'EXPERIENCE'),
                        Tab(text: isAr ? 'التعليم' : 'EDUCATION'),
                        Tab(text: isAr ? 'المهارات' : 'SKILLS'),
                        Tab(text: isAr ? 'المشاريع' : 'PROJECTS'),
                      ])))),
      Expanded(
          child: TabBarView(controller: _tabs, children: [
        _contactTab(s, isAr),
        _experienceTab(s, isAr),
        _educationTab(s, isAr),
        _skillsTab(s, isAr),
        _projectsTab(s, isAr),
      ])),
      _BottomBar(
          isDark: widget.isDark,
          selectedTemplate: _selectedTemplate,
          loading: _downloading,
          format: _selectedFormat,
          s: s,
          isAr: isAr,
          onTemplateChanged: (t) => setState(() => _selectedTemplate = t),
          onDownload: _download),
    ]);
  }

  Widget _contactTab(AppStrings s, bool isAr) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(s.builderPersonalInfo),
        _field(_name, isAr ? 'الاسم الكامل *' : 'Full Name *',
            Icons.person_rounded),
        _field(_email, isAr ? 'البريد الإلكتروني' : 'Email Address',
            Icons.email_rounded),
        _field(
            _phone, isAr ? 'رقم الهاتف' : 'Phone Number', Icons.phone_rounded),
        _field(_location, isAr ? 'المدينة / الدولة' : 'City / Country',
            Icons.location_on_rounded),
        _field(_linkedin, 'LinkedIn URL', Icons.link_rounded),
        _field(_github, 'GitHub URL', Icons.code_rounded),
        const SizedBox(height: 8),
        _sectionLabel(s.builderProfSummary),
        _field(
            _summary,
            isAr
                ? 'اكتب ملخصاً مهنياً من 2-3 جمل...'
                : 'Write a 2-3 sentence summary of your profile...',
            Icons.notes_rounded,
            maxLines: 4),
      ]));

  Widget _experienceTab(AppStrings s, bool isAr) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(children: [
        ..._experience.asMap().entries.map((e) {
          final i = e.key;
          final ctrls = e.value;
          return _SectionCard(
              title: '${isAr ? "الخبرة" : "Experience"} ${i + 1}',
              accentColor: AppColors.violet,
              isDark: widget.isDark,
              onDelete: _experience.length > 1
                  ? () => setState(() {
                        for (final c in _experience[i].values) {
                          c.dispose();
                        }
                        _experience.removeAt(i);
                      })
                  : null,
              child: Column(children: [
                _tf(ctrls['title']!, isAr ? 'المسمى الوظيفي *' : 'Job Title *'),
                _tf(ctrls['company']!, isAr ? 'اسم الشركة' : 'Company Name'),
                _tf(
                    ctrls['duration']!,
                    isAr
                        ? 'المدة (مثال: يناير 2022 – الآن)'
                        : 'Duration (e.g. Jan 2022 – Present)'),
                _tf(
                    ctrls['description']!,
                    isAr
                        ? 'المسؤوليات والإنجازات...'
                        : 'Responsibilities & achievements...',
                    maxLines: 4),
              ]));
        }),
        const SizedBox(height: 8),
        _addButton(isAr ? 'إضافة خبرة' : 'Add Experience',
            () => setState(() => _addExp())),
      ]));

  Widget _educationTab(AppStrings s, bool isAr) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(children: [
        ..._education.asMap().entries.map((e) {
          final i = e.key;
          final ctrls = e.value;
          return _SectionCard(
              title: '${isAr ? "التعليم" : "Education"} ${i + 1}',
              accentColor: AppColors.cyan,
              isDark: widget.isDark,
              onDelete: _education.length > 1
                  ? () => setState(() {
                        for (final c in _education[i].values) {
                          c.dispose();
                        }
                        _education.removeAt(i);
                      })
                  : null,
              child: Column(children: [
                _tf(ctrls['degree']!,
                    isAr ? 'الشهادة / المؤهل *' : 'Degree / Qualification *'),
                _tf(ctrls['institution']!,
                    isAr ? 'الجامعة / المؤسسة' : 'University / Institution'),
                Row(children: [
                  Expanded(
                      child: _tf(ctrls['year']!,
                          isAr ? 'سنة التخرج' : 'Graduation Year')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tf(ctrls['gpa']!,
                          isAr ? 'المعدل (اختياري)' : 'GPA (optional)')),
                ]),
              ]));
        }),
        const SizedBox(height: 8),
        _addButton(isAr ? 'إضافة تعليم' : 'Add Education',
            () => setState(() => _addEdu())),
      ]));

  Widget _skillsTab(AppStrings s, bool isAr) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(s.builderYourSkills),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _skillInput,
                  onSubmitted: (_) => _addSkill(),
                  style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 13),
                  decoration: InputDecoration(
                      hintText: s.builderTypeSkill,
                      filled: true,
                      fillColor: widget.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12)))),
          const SizedBox(width: 10),
          GestureDetector(
              onTap: _addSkill,
              child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.violet,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20))),
        ]),
        const SizedBox(height: 20),
        if (_skills.isEmpty)
          Center(
              child: Text(s.builderNoSkills,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)))
        else
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills
                  .asMap()
                  .entries
                  .map((e) => _SkillPill(
                      label: e.value,
                      onRemove: () => setState(() => _skills.removeAt(e.key))))
                  .toList()),
        const SizedBox(height: 24),
        _sectionLabel(s.builderQuickAdd),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Python',
              'Flutter',
              'FastAPI',
              'React',
              'JavaScript',
              'TypeScript',
              'SQL',
              'Git',
              'Docker',
              'AWS',
              'Machine Learning',
              'TensorFlow'
            ]
                .where((sk) => !_skills.contains(sk))
                .map((sk) => GestureDetector(
                    onTap: () => setState(() => _skills.add(sk)),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_rounded,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(sk, style: const TextStyle(fontSize: 11)),
                        ]))))
                .toList()),
      ]));

  void _addSkill() {
    final val = _skillInput.text.trim();
    if (val.isNotEmpty && !_skills.contains(val)) {
      setState(() {
        _skills.add(val);
        _skillInput.clear();
      });
    }
  }

  Widget _projectsTab(AppStrings s, bool isAr) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(children: [
        ..._projects.asMap().entries.map((e) {
          final i = e.key;
          final ctrls = e.value;
          return _SectionCard(
              title: '${isAr ? "المشروع" : "Project"} ${i + 1}',
              accentColor: AppColors.amber,
              isDark: widget.isDark,
              onDelete: () => setState(() {
                    for (final c in _projects[i].values) {
                      c.dispose();
                    }
                    _projects.removeAt(i);
                  }),
              child: Column(children: [
                _tf(ctrls['name']!, isAr ? 'اسم المشروع *' : 'Project Name *'),
                _tf(
                    ctrls['technologies']!,
                    isAr
                        ? 'التقنيات (مثال: Flutter، FastAPI، PostgreSQL)'
                        : 'Technologies (e.g. Flutter, FastAPI, PostgreSQL)'),
                _tf(ctrls['description']!,
                    isAr ? 'وصف مختصر...' : 'Brief description...',
                    maxLines: 3),
              ]));
        }),
        const SizedBox(height: 8),
        _addButton(isAr ? 'إضافة مشروع' : 'Add Project',
            () => setState(() => _addProject())),
      ]));

  Widget _sectionLabel(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
              color: Colors.grey)));

  Widget _field(TextEditingController c, String hint, IconData icon,
          {int maxLines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
              controller: c,
              maxLines: maxLines,
              style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 13),
              decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(icon, size: 18, color: AppColors.violet),
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.violet.withValues(alpha: 0.5))),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12))));

  Widget _tf(TextEditingController c, String hint, {int maxLines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
              controller: c,
              maxLines: maxLines,
              style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 12),
              decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 11),
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10))));

  Widget _addButton(String label, VoidCallback onTap) => OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.violet,
          side: BorderSide(color: AppColors.violet.withValues(alpha: 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)));
}

// ── AI BUILDER ────────────────────────────────────────────────────────────────
class _AIBuilder extends ConsumerStatefulWidget {
  final bool isDark, isAr;
  final int? sourceResumeId;
  final AppStrings s;
  final VoidCallback onBack;
  const _AIBuilder(
      {super.key,
      required this.isDark,
      required this.isAr,
      required this.sourceResumeId,
      required this.s,
      required this.onBack});
  @override
  ConsumerState<_AIBuilder> createState() => _AIBuilderState();
}

class _AIBuilderState extends ConsumerState<_AIBuilder> {
  final _roleCtrl = TextEditingController();
  String _selectedTone = 'professional';
  String _selectedTemplate = 'professional';
  String _selectedFormat = 'docx';
  bool _generating = false;
  bool _done = false;
  String? _errorMsg;

  @override
  void dispose() {
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final s = widget.s;
    final isAr = widget.isAr;
    if (_roleCtrl.text.trim().isEmpty) {
      _snack(s.builderNameFirst, isError: true);
      return;
    }
    final resumeId = widget.sourceResumeId;
    if (resumeId == null) {
      _snack(s.builderNoResume, isError: true);
      return;
    }
    setState(() {
      _generating = true;
      _errorMsg = null;
    });
    final service = ref.read(resumeServiceProvider);
    Uint8List? bytes;
    String ext;
    if (_selectedFormat == 'pdf') {
      bytes = await service.aiGenerateAndDownloadPdf(
          resumeId: resumeId,
          targetRole: _roleCtrl.text.trim(),
          tone: _selectedTone,
          templateId: _selectedTemplate);
      ext = 'pdf';
    } else {
      bytes = await service.aiGenerateAndDownloadDocx(
          resumeId: resumeId,
          targetRole: _roleCtrl.text.trim(),
          tone: _selectedTone,
          templateId: _selectedTemplate);
      ext = 'docx';
    }
    if (!mounted) return;
    setState(() => _generating = false);
    if (bytes != null) {
      final filename =
          '${_roleCtrl.text.trim().replaceAll(' ', '_').toLowerCase()}_${_selectedTone}_resume.$ext';
      final blob = web.Blob([bytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      (web.HTMLAnchorElement()
            ..href = url
            ..download = filename)
          .click();
      setState(() => _done = true);
      _snack(s.builderAiDownloadOk);
    } else {
      setState(() => _errorMsg = isAr
          ? 'فشل الإنشاء. هل سيرتك محللة؟'
          : 'Generation failed. Is the resume parsed?');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.rose : AppColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final isAr = widget.isAr;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: widget.onBack),
            const SizedBox(width: 4),
            Text(s.builderAiHeader,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            _FormatToggle(
                selected: _selectedFormat,
                onChanged: (f) => setState(() => _selectedFormat = f)),
          ])),
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    AppColors.emerald.withValues(alpha: 0.2))),
                        child: Row(children: [
                          const Text('🤖', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(s.builderAiInfo,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13)),
                                Text(
                                    isAr
                                        ? 'وسيعيد كتابتها احترافياً للدور المستهدف.'
                                        : 'and rewrite it professionally for your target role.',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11)),
                              ])),
                        ])),
                    const SizedBox(height: 24),
                    _label(s.designTargetRole),
                    TextField(
                        controller: _roleCtrl,
                        style: TextStyle(
                            color:
                                widget.isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                            hintText: isAr
                                ? 'مثال: مطور Flutter، عالم بيانات...'
                                : 'e.g. Flutter Developer, Data Scientist...',
                            prefixIcon: const Icon(Icons.work_rounded,
                                color: AppColors.violet, size: 18),
                            filled: true,
                            fillColor: widget.isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14))),
                    const SizedBox(height: 24),
                    _label(s.designTone),
                    const SizedBox(height: 10),
                    Row(children: [
                      _ToneCard(
                          tone: 'professional',
                          emoji: '💼',
                          label: s.designProfessional,
                          desc:
                              isAr ? 'متوازن واحترافي' : 'Polished & balanced',
                          selected: _selectedTone == 'professional',
                          color: AppColors.violet,
                          onTap: () =>
                              setState(() => _selectedTone = 'professional')),
                      const SizedBox(width: 10),
                      _ToneCard(
                          tone: 'aggressive',
                          emoji: '🔥',
                          label: s.designAggressive,
                          desc: isAr
                              ? 'جريء وموجّه للإنجاز'
                              : 'Bold & achievement-driven',
                          selected: _selectedTone == 'aggressive',
                          color: AppColors.rose,
                          onTap: () =>
                              setState(() => _selectedTone = 'aggressive')),
                      const SizedBox(width: 10),
                      _ToneCard(
                          tone: 'technical',
                          emoji: '⚙️',
                          label: s.designTechnical,
                          desc: isAr
                              ? 'مهارات وأدوات تقنية'
                              : 'Skill & tool focused',
                          selected: _selectedTone == 'technical',
                          color: AppColors.cyan,
                          onTap: () =>
                              setState(() => _selectedTone = 'technical')),
                    ]),
                    const SizedBox(height: 24),
                    _label(isAr ? 'قالب السيرة الذاتية' : 'Resume Template'),
                    const SizedBox(height: 10),
                    ...const [
                      (
                        'professional',
                        '💼',
                        'Professional',
                        'Classic corporate layout'
                      ),
                      ('modern', '🚀', 'Modern', 'Clean tech design'),
                      ('minimal', '⚡', 'Minimal', 'ATS-first, no frills'),
                    ].map((t) => _TemplateTile(
                        id: t.$1,
                        emoji: t.$2,
                        name: t.$3,
                        desc: t.$4,
                        selected: _selectedTemplate == t.$1,
                        isDark: widget.isDark,
                        onTap: () => setState(() => _selectedTemplate = t.$1))),
                    const SizedBox(height: 28),
                    if (_errorMsg != null)
                      Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: AppColors.rose.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppColors.rose.withValues(alpha: 0.3))),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.rose, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(_errorMsg!,
                                    style: const TextStyle(
                                        color: AppColors.rose))),
                          ])),
                    if (_done)
                      Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.emerald
                                      .withValues(alpha: 0.3))),
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.emerald, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(s.builderAiDownloadOk,
                                    style: const TextStyle(
                                        color: AppColors.emerald,
                                        fontWeight: FontWeight.bold))),
                          ])),
                    _GenerateButton(
                        loading: _generating,
                        done: _done,
                        format: _selectedFormat,
                        s: s,
                        isAr: isAr,
                        onTap: _generate),
                  ]))),
    ]);
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
              color: Colors.grey)));
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final bool isDark;
  final VoidCallback? onDelete;
  final Widget child;
  const _SectionCard(
      {required this.title,
      required this.accentColor,
      required this.isDark,
      required this.child,
      this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: accentColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: accentColor)),
          const Spacer(),
          if (onDelete != null)
            IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.rose, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 14),
        child,
      ]));
}

class _SkillPill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _SkillPill({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.violet)),
        const SizedBox(width: 6),
        GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 14, color: AppColors.violet.withValues(alpha: 0.7))),
      ]));
}

class _ToneCard extends StatelessWidget {
  final String tone, emoji, label, desc;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ToneCard(
      {required this.tone,
      required this.emoji,
      required this.label,
      required this.desc,
      required this.selected,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
      child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? color : Colors.white12,
                      width: selected ? 2 : 1)),
              child: Column(children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: selected ? color : null)),
                const SizedBox(height: 2),
                Text(desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
              ]))));
}

class _TemplateTile extends StatelessWidget {
  final String id, emoji, name, desc;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _TemplateTile(
      {required this.id,
      required this.emoji,
      required this.name,
      required this.desc,
      required this.selected,
      required this.isDark,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: selected
                  ? AppColors.violet.withValues(alpha: 0.1)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.violet : Colors.white12,
                  width: selected ? 2 : 1)),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13)),
                  Text(desc,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ])),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.violet, size: 20),
          ])));
}

class _FormatToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FormatToggle({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ['docx', 'pdf'].map((f) {
            final isSel = selected == f;
            return GestureDetector(
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: isSel ? AppColors.violet : Colors.transparent,
                        borderRadius: BorderRadius.circular(7)),
                    child: Text(f.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isSel ? Colors.white : Colors.grey))));
          }).toList()));
}

class _BottomBar extends StatelessWidget {
  final bool isDark, loading;
  final String selectedTemplate, format;
  final AppStrings s;
  final bool isAr;
  final ValueChanged<String> onTemplateChanged;
  final VoidCallback onDownload;
  const _BottomBar(
      {required this.isDark,
      required this.loading,
      required this.selectedTemplate,
      required this.format,
      required this.s,
      required this.isAr,
      required this.onTemplateChanged,
      required this.onDownload});
  @override
  Widget build(BuildContext context) => ClipRRect(
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.9),
                  border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Text(s.builderTemplate,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(width: 10),
                  ...[
                    ('professional', '💼'),
                    ('modern', '🚀'),
                    ('minimal', '⚡')
                  ].map((t) => GestureDetector(
                      onTap: () => onTemplateChanged(t.$1),
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: selectedTemplate == t.$1
                                  ? AppColors.violet
                                  : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                              '${t.$2} ${t.$1[0].toUpperCase()}${t.$1.substring(1)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: selectedTemplate == t.$1
                                      ? Colors.white
                                      : Colors.grey))))),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                        onPressed: loading ? null : onDownload,
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Icon(
                                format == 'pdf'
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.download_rounded,
                                size: 18),
                        label: Text(loading
                            ? s.builderGenerating
                            : '${isAr ? "تحميل" : "Download"} ${format.toUpperCase()}'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.violet,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))))),
              ]))));
}

class _GenerateButton extends StatelessWidget {
  final bool loading, done, isAr;
  final String format;
  final AppStrings s;
  final VoidCallback onTap;
  const _GenerateButton(
      {required this.loading,
      required this.done,
      required this.format,
      required this.s,
      required this.isAr,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
              gradient: loading || done
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF0891B2)]),
              color: loading
                  ? Colors.grey.shade800
                  : done
                      ? AppColors.emerald
                      : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: loading || done
                  ? []
                  : [
                      BoxShadow(
                          color: AppColors.emerald.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
            else if (done)
              const Icon(Icons.check_rounded, color: Colors.white, size: 22)
            else
              const Text('🤖', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
                loading
                    ? s.builderAiWriting
                    : done
                        ? s.builderDownloaded
                        : '${s.builderGenAi} (${format.toUpperCase()})',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
          ])));
}
