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
import '../../../../shared/widgets/background_painter.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import '../../providers/resume_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class ResumeBuilderPage extends ConsumerStatefulWidget {
  /// If [sourceResumeId] is provided, AI mode pre-loads parsed data from that resume.
  final int? sourceResumeId;
  const ResumeBuilderPage({super.key, this.sourceResumeId});

  @override
  ConsumerState<ResumeBuilderPage> createState() => _ResumeBuilderPageState();
}

class _ResumeBuilderPageState extends ConsumerState<ResumeBuilderPage>
    with TickerProviderStateMixin {
  // ── Mode selection ──────────────────────────────────────────────────────
  _BuildMode? _mode; // null = not chosen yet

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: Stack(
        children: [
          const BackgroundPainter(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              child: _mode == null
                  ? _ModeSelector(
                      key: const ValueKey('mode'),
                      isDark: isDark,
                      sourceResumeId: widget.sourceResumeId,
                      onSelect: (m) => setState(() => _mode = m),
                    )
                  : _mode == _BuildMode.manual
                      ? _ManualBuilder(
                          key: const ValueKey('manual'),
                          isDark: isDark,
                          onBack: () => setState(() => _mode = null),
                        )
                      : _AIBuilder(
                          key: const ValueKey('ai'),
                          isDark: isDark,
                          sourceResumeId: widget.sourceResumeId,
                          onBack: () => setState(() => _mode = null),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BuildMode { manual, ai }

// ─────────────────────────────────────────────────────────────────────────────
// MODE SELECTOR SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final bool isDark;
  final int? sourceResumeId;
  final ValueChanged<_BuildMode> onSelect;
  const _ModeSelector(
      {super.key,
      required this.isDark,
      required this.sourceResumeId,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── App bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.go('/resume'),
            ),
            const SizedBox(width: 4),
            const Text('Resume Builder',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.violet.withValues(alpha: 0.15),
                        AppColors.cyan.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.violet.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      const Text(
                        'Build Your Perfect Resume',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose how you want to create your resume.\nBoth options produce professional DOCX & PDF files.',
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                const Text('SELECT YOUR PATH',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.grey)),
                const SizedBox(height: 14),

                // ── Option 1: Manual ──
                _ModeCard(
                  emoji: '📝',
                  title: 'Fill It Yourself',
                  subtitle: 'Manual Builder',
                  description:
                      'Enter your information step by step — contact, experience, education, skills, projects. Full control over every word.',
                  features: const [
                    'Pre-filled from parsed resume',
                    'Edit every field freely',
                    'Preview before downloading',
                  ],
                  accentColor: AppColors.violet,
                  isDark: isDark,
                  onTap: () => onSelect(_BuildMode.manual),
                ),

                const SizedBox(height: 16),

                // ── Option 2: AI ──
                _ModeCard(
                  emoji: '🤖',
                  title: 'Let AI Build It',
                  subtitle: 'AI Resume Generator',
                  description:
                      'AI reads your parsed resume content and writes a polished, professional resume tailored to your target role and tone.',
                  features: const [
                    'Choose target role & industry',
                    'Select tone: Professional / Aggressive / Technical',
                    'AI rewrites for maximum impact',
                  ],
                  accentColor: AppColors.emerald,
                  isDark: isDark,
                  badge: sourceResumeId != null ? 'Resume loaded' : null,
                  onTap: () => onSelect(_BuildMode.ai),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji, title, subtitle, description;
  final List<String> features;
  final Color accentColor;
  final bool isDark;
  final String? badge;
  final VoidCallback onTap;

  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.features,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: accentColor.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
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
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: accentColor),
              ],
            ),
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
                  ]),
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL BUILDER
// ─────────────────────────────────────────────────────────────────────────────

class _ManualBuilder extends ConsumerStatefulWidget {
  final bool isDark;
  final VoidCallback onBack;
  const _ManualBuilder({super.key, required this.isDark, required this.onBack});

  @override
  ConsumerState<_ManualBuilder> createState() => _ManualBuilderState();
}

class _ManualBuilderState extends ConsumerState<_ManualBuilder>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _downloading = false;
  String _selectedTemplate = 'professional';
  String _selectedFormat = 'docx';

  // Contact
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _linkedin = TextEditingController();
  final _github = TextEditingController();
  final _summary = TextEditingController();

  // Dynamic sections
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
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _linkedin.dispose();
    _github.dispose();
    _summary.dispose();
    _skillInput.dispose();
    for (final e in _experience) {
      for (final c in e.values) {
        c.dispose();
      }
    }
    for (final e in _education) {
      for (final c in e.values) {
        c.dispose();
      }
    }
    for (final p in _projects) {
      for (final c in p.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addExp() => _experience.add({
        'title': TextEditingController(),
        'company': TextEditingController(),
        'duration': TextEditingController(),
        'description': TextEditingController(),
      });

  void _addEdu() => _education.add({
        'degree': TextEditingController(),
        'institution': TextEditingController(),
        'year': TextEditingController(),
        'gpa': TextEditingController(),
      });

  void _addProject() => _projects.add({
        'name': TextEditingController(),
        'technologies': TextEditingController(),
        'description': TextEditingController(),
      });

  Map<String, dynamic> _buildData() => {
        'name': _name.text.trim(),
        'contact_info': {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'location': _location.text.trim(),
          'linkedin': _linkedin.text.trim(),
          'github': _github.text.trim(),
        },
        'summary': _summary.text.trim(),
        'experience': _experience
            .where((e) => e['title']!.text.isNotEmpty)
            .map((e) => {
                  'title': e['title']!.text,
                  'company': e['company']!.text,
                  'duration': e['duration']!.text,
                  'description': e['description']!.text,
                })
            .toList(),
        'education': _education
            .where((e) => e['degree']!.text.isNotEmpty)
            .map((e) => {
                  'degree': e['degree']!.text,
                  'institution': e['institution']!.text,
                  'year': e['year']!.text,
                  'gpa': e['gpa']!.text,
                })
            .toList(),
        'skills': _skills,
        'projects': _projects
            .where((p) => p['name']!.text.isNotEmpty)
            .map((p) => {
                  'name': p['name']!.text,
                  'technologies': p['technologies']!.text,
                  'description': p['description']!.text,
                })
            .toList(),
      };

  Future<void> _download() async {
    if (_name.text.trim().isEmpty) {
      _snack('Please enter your name first', isError: true);
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
      _snack('✅ Resume downloaded!');
    } else {
      _snack('❌ Download failed', isError: true);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: widget.onBack),
            const SizedBox(width: 4),
            const Text('Manual Builder',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            _FormatToggle(
              selected: _selectedFormat,
              onChanged: (f) => setState(() => _selectedFormat = f),
            ),
          ]),
        ),

        // ── Tab bar ──
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
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                tabs: const [
                  Tab(text: 'CONTACT'),
                  Tab(text: 'EXPERIENCE'),
                  Tab(text: 'EDUCATION'),
                  Tab(text: 'SKILLS'),
                  Tab(text: 'PROJECTS'),
                ],
              ),
            ),
          ),
        ),

        // ── Tab content ──
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _contactTab(),
              _experienceTab(),
              _educationTab(),
              _skillsTab(),
              _projectsTab(),
            ],
          ),
        ),

        // ── Bottom bar: template + download ──
        _BottomBar(
          isDark: widget.isDark,
          selectedTemplate: _selectedTemplate,
          loading: _downloading,
          onTemplateChanged: (t) => setState(() => _selectedTemplate = t),
          onDownload: _download,
          format: _selectedFormat,
        ),
      ],
    );
  }

  // ── Tab: Contact ────────────────────────────────────────────────────────

  Widget _contactTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Personal Information'),
            _field(_name, 'Full Name *', Icons.person_rounded, required: true),
            _field(_email, 'Email Address', Icons.email_rounded),
            _field(_phone, 'Phone Number', Icons.phone_rounded),
            _field(_location, 'City / Country', Icons.location_on_rounded),
            _field(_linkedin, 'LinkedIn URL', Icons.link_rounded),
            _field(_github, 'GitHub URL', Icons.code_rounded),
            const SizedBox(height: 8),
            _sectionLabel('Professional Summary'),
            _field(_summary, 'Write a 2-3 sentence summary of your profile...',
                Icons.notes_rounded,
                maxLines: 4),
          ],
        ),
      );

  // ── Tab: Experience ─────────────────────────────────────────────────────

  Widget _experienceTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: [
            ..._experience.asMap().entries.map((e) {
              final i = e.key;
              final ctrls = e.value;
              return _SectionCard(
                title: 'Experience ${i + 1}',
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
                  _tf(ctrls['title']!, 'Job Title *'),
                  _tf(ctrls['company']!, 'Company Name'),
                  _tf(ctrls['duration']!,
                      'Duration  (e.g. Jan 2022 – Present)'),
                  _tf(ctrls['description']!,
                      'Responsibilities & achievements...',
                      maxLines: 4),
                ]),
              );
            }),
            const SizedBox(height: 8),
            _addButton('Add Experience', () => setState(() => _addExp())),
          ],
        ),
      );

  // ── Tab: Education ──────────────────────────────────────────────────────

  Widget _educationTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: [
            ..._education.asMap().entries.map((e) {
              final i = e.key;
              final ctrls = e.value;
              return _SectionCard(
                title: 'Education ${i + 1}',
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
                  _tf(ctrls['degree']!, 'Degree / Qualification *'),
                  _tf(ctrls['institution']!, 'University / Institution'),
                  Row(children: [
                    Expanded(child: _tf(ctrls['year']!, 'Graduation Year')),
                    const SizedBox(width: 10),
                    Expanded(child: _tf(ctrls['gpa']!, 'GPA (optional)')),
                  ]),
                ]),
              );
            }),
            const SizedBox(height: 8),
            _addButton('Add Education', () => setState(() => _addEdu())),
          ],
        ),
      );

  // ── Tab: Skills ─────────────────────────────────────────────────────────

  Widget _skillsTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Your Skills'),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _skillInput,
                  onSubmitted: (_) => _addSkill(),
                  style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type a skill and press Add...',
                    filled: true,
                    fillColor: widget.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addSkill,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.violet,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            if (_skills.isEmpty)
              Center(
                child: Text('No skills added yet',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills
                    .asMap()
                    .entries
                    .map((e) => _SkillPill(
                          label: e.value,
                          onRemove: () =>
                              setState(() => _skills.removeAt(e.key)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 24),
            _sectionLabel('Quick Add — Common Skills'),
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
                'TensorFlow',
              ]
                  .where((s) => !_skills.contains(s))
                  .map((s) => GestureDetector(
                        onTap: () => setState(() => _skills.add(s)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(s, style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      );

  void _addSkill() {
    final val = _skillInput.text.trim();
    if (val.isNotEmpty && !_skills.contains(val)) {
      setState(() {
        _skills.add(val);
        _skillInput.clear();
      });
    }
  }

  // ── Tab: Projects ───────────────────────────────────────────────────────

  Widget _projectsTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: [
            ..._projects.asMap().entries.map((e) {
              final i = e.key;
              final ctrls = e.value;
              return _SectionCard(
                title: 'Project ${i + 1}',
                accentColor: AppColors.amber,
                isDark: widget.isDark,
                onDelete: () => setState(() {
                  for (final c in _projects[i].values) c.dispose();
                  _projects.removeAt(i);
                }),
                child: Column(children: [
                  _tf(ctrls['name']!, 'Project Name *'),
                  _tf(ctrls['technologies']!,
                      'Technologies (e.g. Flutter, FastAPI, PostgreSQL)'),
                  _tf(ctrls['description']!, 'Brief description...',
                      maxLines: 3),
                ]),
              );
            }),
            const SizedBox(height: 8),
            _addButton('Add Project', () => setState(() => _addProject())),
          ],
        ),
      );

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
                color: Colors.grey)),
      );

  Widget _field(TextEditingController c, String hint, IconData icon,
          {int maxLines = 1, bool required = false}) =>
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
                borderSide:
                    BorderSide(color: AppColors.violet.withValues(alpha: 0.5))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );

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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      );

  Widget _addButton(String label, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.violet,
          side: BorderSide(color: AppColors.violet.withValues(alpha: 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AI BUILDER
// ─────────────────────────────────────────────────────────────────────────────

class _AIBuilder extends ConsumerStatefulWidget {
  final bool isDark;
  final int? sourceResumeId;
  final VoidCallback onBack;

  const _AIBuilder(
      {super.key,
      required this.isDark,
      required this.sourceResumeId,
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
    if (_roleCtrl.text.trim().isEmpty) {
      _snack('Please enter your target role', isError: true);
      return;
    }
    final resumeId = widget.sourceResumeId;
    if (resumeId == null) {
      _snack('No resume selected — go back and open a resume first',
          isError: true);
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
        templateId: _selectedTemplate,
      );
      ext = 'pdf';
    } else {
      bytes = await service.aiGenerateAndDownloadDocx(
        resumeId: resumeId,
        targetRole: _roleCtrl.text.trim(),
        tone: _selectedTone,
        templateId: _selectedTemplate,
      );
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
      _snack('✅ AI Resume downloaded!');
    } else {
      setState(() => _errorMsg = 'Generation failed. Is the resume parsed?');
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.rose : AppColors.emerald,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: widget.onBack),
            const SizedBox(width: 4),
            const Text('AI Resume Generator',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            _FormatToggle(
              selected: _selectedFormat,
              onChanged: (f) => setState(() => _selectedFormat = f),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info banner ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.emerald.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI will read your full parsed resume',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 13)),
                            Text(
                              'and rewrite it professionally for your target role.',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Target Role ──
                _label('Target Role / Job Title'),
                TextField(
                  controller: _roleCtrl,
                  style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'e.g. Flutter Developer, Data Scientist...',
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
                        horizontal: 14, vertical: 14),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Tone selector ──
                _label('Writing Tone'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ToneCard(
                      tone: 'professional',
                      emoji: '💼',
                      label: 'Professional',
                      desc: 'Polished & balanced',
                      selected: _selectedTone == 'professional',
                      color: AppColors.violet,
                      onTap: () =>
                          setState(() => _selectedTone = 'professional'),
                    ),
                    const SizedBox(width: 10),
                    _ToneCard(
                      tone: 'aggressive',
                      emoji: '🔥',
                      label: 'Aggressive',
                      desc: 'Bold & achievement-driven',
                      selected: _selectedTone == 'aggressive',
                      color: AppColors.rose,
                      onTap: () => setState(() => _selectedTone = 'aggressive'),
                    ),
                    const SizedBox(width: 10),
                    _ToneCard(
                      tone: 'technical',
                      emoji: '⚙️',
                      label: 'Technical',
                      desc: 'Skill & tool focused',
                      selected: _selectedTone == 'technical',
                      color: AppColors.cyan,
                      onTap: () => setState(() => _selectedTone = 'technical'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Template ──
                _label('Resume Template'),
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
                      onTap: () => setState(() => _selectedTemplate = t.$1),
                    )),

                const SizedBox(height: 28),

                // ── Error ──
                if (_errorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.rose, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_errorMsg!,
                              style: const TextStyle(color: AppColors.rose))),
                    ]),
                  ),

                // ── Success state ──
                if (_done)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.emerald, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text(
                              '✅ Your AI resume was generated and downloaded!',
                              style: TextStyle(
                                  color: AppColors.emerald,
                                  fontWeight: FontWeight.bold))),
                    ]),
                  ),

                // ── Generate button ──
                _GenerateButton(
                  loading: _generating,
                  done: _done,
                  format: _selectedFormat,
                  onTap: _generate,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
                color: Colors.grey)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final bool isDark;
  final VoidCallback? onDelete;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.accentColor,
    required this.isDark,
    required this.child,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SkillPill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _SkillPill({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.violet)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 14, color: AppColors.violet.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _ToneCard extends StatelessWidget {
  final String tone, emoji, label, desc;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToneCard({
    required this.tone,
    required this.emoji,
    required this.label,
    required this.desc,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
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
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final String id, emoji, name, desc;
  final bool selected, isDark;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.id,
    required this.emoji,
    required this.name,
    required this.desc,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.violet.withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.violet : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
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
        ]),
      ),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FormatToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['docx', 'pdf'].map((f) {
          final isSelected = selected == f;
          return GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.violet : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                f.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool isDark, loading;
  final String selectedTemplate, format;
  final ValueChanged<String> onTemplateChanged;
  final VoidCallback onDownload;

  const _BottomBar({
    required this.isDark,
    required this.loading,
    required this.selectedTemplate,
    required this.format,
    required this.onTemplateChanged,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.9),
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Template row
              Row(
                children: [
                  const Text('Template:',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              '${t.$2} ${t.$1[0].toUpperCase()}${t.$1.substring(1)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: selectedTemplate == t.$1
                                      ? Colors.white
                                      : Colors.grey)),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 10),
              // Download button
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
                      ? 'Generating...'
                      : 'Download ${format.toUpperCase()}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final bool loading, done;
  final String format;
  final VoidCallback onTap;

  const _GenerateButton(
      {required this.loading,
      required this.done,
      required this.format,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  ? 'AI is writing your resume...'
                  : done
                      ? 'Downloaded! Generate Again?'
                      : 'Generate AI Resume (${format.toUpperCase()})',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
