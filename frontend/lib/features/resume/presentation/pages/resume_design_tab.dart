// lib/features/resume/presentation/pages/resume_design_tab.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/screens/login_screen.dart'; // GlassCard, PrimaryButton
import '../../providers/resume_provider.dart';
import '../../models/resume_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _Template {
  final String id, name, description, emoji;
  final Color accent;
  const _Template({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.accent,
  });
}

const _templates = [
  _Template(
    id: 'professional',
    name: 'Professional',
    description: 'Classic corporate layout — trusted by Fortune 500 recruiters',
    emoji: '💼',
    accent: Color(0xFF2C3E50),
  ),
  _Template(
    id: 'modern',
    name: 'Modern',
    description: 'Clean contemporary design — perfect for tech & startups',
    emoji: '🚀',
    accent: Color(0xFF2980B9),
  ),
  _Template(
    id: 'minimal',
    name: 'Minimal',
    description: 'Maximum ATS compatibility — no frills, pure content',
    emoji: '⚡',
    accent: Color(0xFF27AE60),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MODE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _DesignMode { manual, ai }

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class ResumeDesignTab extends ConsumerStatefulWidget {
  final Resume resume;
  final bool isDark;

  const ResumeDesignTab({
    super.key,
    required this.resume,
    required this.isDark,
  });

  @override
  ConsumerState<ResumeDesignTab> createState() => _ResumeDesignTabState();
}

class _ResumeDesignTabState extends ConsumerState<ResumeDesignTab>
    with SingleTickerProviderStateMixin {
  // ── Mode: null = not chosen yet ────────────────────────────────────────────
  _DesignMode? _mode;

  // ── Shared ─────────────────────────────────────────────────────────────────
  String _selectedTemplate = 'professional';
  bool _generating = false;
  int _step = 0; // 0=template 1=edit 2=preview

  late TabController _editTabs;

  // ── Editable controllers ───────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();

  List<Map<String, dynamic>> _experience = [];
  List<Map<String, dynamic>> _education = [];
  List<String> _skills = [];
  List<Map<String, dynamic>> _projects = [];
  List<String> _certifications = [];
  bool _dataLoaded = false;

  // ── AI mode ─────────────────────────────────────────────────────────────
  final _roleCtrl = TextEditingController();
  String _selectedTone = 'professional';
  bool _aiGenerating = false;
  bool _aiDone = false;

  @override
  void initState() {
    super.initState();
    _editTabs = TabController(length: 5, vsync: this);
    _loadFromResume();
  }

  @override
  void dispose() {
    _editTabs.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _linkedinCtrl.dispose();
    _githubCtrl.dispose();
    _summaryCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING — name bug fixed: never use r.title (it's the filename)
  // ─────────────────────────────────────────────────────────────────────────

  void _loadFromResume() {
    final r = widget.resume;
    final dynamic rDyn = r;
    final rawContact = r.contactInfo;
    final contact =
        (rawContact is Map<String, dynamic>) ? rawContact : <String, dynamic>{};

    // Name ONLY from contact_info.name — r.title is the filename!
    final rawName = contact['name']?.toString().trim() ?? '';
    final looksLikeFilename = rawName.toLowerCase().contains('.pdf') ||
        rawName.toLowerCase().contains('.docx') ||
        rawName.contains('_CV') ||
        rawName.contains('_cv') ||
        rawName.length > 50;
    _nameCtrl.text = looksLikeFilename ? '' : rawName;

    _emailCtrl.text = contact['email']?.toString() ?? '';
    _phoneCtrl.text = contact['phone']?.toString() ?? '';
    _locationCtrl.text = contact['location']?.toString() ?? '';
    _linkedinCtrl.text = contact['linkedin']?.toString() ?? '';
    _githubCtrl.text = contact['github']?.toString() ?? '';

    final summary = contact['summary']?.toString() ?? '';
    _summaryCtrl.text = summary;

    // Experience
    final rawExp = r.experience;
    if (rawExp is List && rawExp.isNotEmpty) {
      _experience = rawExp
          .map((e) => e is Map<String, dynamic>
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{})
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (_experience.isEmpty) _experience = [_emptyExp()];

    // Education
    final rawEdu = r.education;
    if (rawEdu is List && rawEdu.isNotEmpty) {
      _education = rawEdu
          .map((e) => e is Map<String, dynamic>
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{})
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (_education.isEmpty) _education = [_emptyEdu()];

    // Skills
    final rawSkills = r.skills;
    if (rawSkills is List) {
      _skills = rawSkills
          .map((s) {
            if (s is String) return s;
            if (s is Map) return s['name']?.toString() ?? '';
            return s.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Projects & certifications via dynamic (may not be exposed as getters)
    dynamic rawProj;
    dynamic rawCerts;
    try {
      rawProj = rDyn.projects;
    } catch (_) {}
    try {
      rawCerts = rDyn.certifications;
    } catch (_) {}

    if (rawProj is List) {
      _projects = rawProj
          .map((p) => p is Map<String, dynamic>
              ? Map<String, dynamic>.from(p)
              : <String, dynamic>{})
          .where((p) => p.isNotEmpty)
          .toList();
    }

    if (rawCerts is List) {
      _certifications = rawCerts
          .map<String>((c) {
            if (c is String) return c;
            if (c is Map) {
              final n = c['name']?.toString() ?? '';
              final iss = c['issuer']?.toString() ?? '';
              return iss.isNotEmpty ? '$n | $iss' : n;
            }
            return c.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }

    setState(() => _dataLoaded = true);
  }

  Map<String, dynamic> _emptyExp() =>
      {'title': '', 'company': '', 'duration': '', 'description': ''};
  Map<String, dynamic> _emptyEdu() =>
      {'degree': '', 'institution': '', 'year': '', 'gpa': ''};

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD RESUME DATA
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _buildResumeData() {
    final name = _nameCtrl.text.trim();
    return {
      'name': name.isNotEmpty ? name : 'Your Name',
      'contact_info': {
        'name': name.isNotEmpty ? name : 'Your Name',
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'linkedin': _linkedinCtrl.text.trim(),
        'github': _githubCtrl.text.trim(),
      },
      'summary': _summaryCtrl.text.trim(),
      'experience': _experience
          .where((e) => (e['title'] ?? '').toString().isNotEmpty)
          .toList(),
      'education': _education
          .where((e) => (e['degree'] ?? '').toString().isNotEmpty)
          .toList(),
      'skills': _skills,
      'projects': _projects
          .where((p) => (p['name'] ?? '').toString().isNotEmpty)
          .toList(),
      'certifications': _certifications,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DOWNLOAD (Manual)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _download() async {
    if (_generating) return;
    setState(() => _generating = true);
    final service = ref.read(resumeServiceProvider);
    final data = _buildResumeData();

    final bytes = await service.generateResumeWithData(
      widget.resume.id,
      _selectedTemplate,
      data,
    );

    if (!mounted) return;
    setState(() => _generating = false);

    if (bytes != null) {
      _triggerDownload(
        bytes,
        '${data['name'].toString().replaceAll(' ', '_').toLowerCase()}_resume.docx',
      );
      _snack('✅ Resume downloaded!');
    } else {
      _snack('❌ Download failed — check backend', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI GENERATE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _aiGenerate() async {
    if (_roleCtrl.text.trim().isEmpty) {
      _snack('Please enter your target role', isError: true);
      return;
    }
    setState(() {
      _aiGenerating = true;
      _aiDone = false;
    });

    final service = ref.read(resumeServiceProvider);
    final bytes = await service.aiGenerateAndDownloadDocx(
      resumeId: widget.resume.id,
      targetRole: _roleCtrl.text.trim(),
      tone: _selectedTone,
      templateId: _selectedTemplate,
    );

    if (!mounted) return;
    setState(() => _aiGenerating = false);

    if (bytes != null) {
      _triggerDownload(
        bytes,
        '${_roleCtrl.text.trim().replaceAll(' ', '_').toLowerCase()}_${_selectedTone}_resume.docx',
      );
      setState(() => _aiDone = true);
      _snack('✅ AI Resume downloaded!');
    } else {
      _snack('❌ AI generation failed — parse your resume first', isError: true);
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD — root widget
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    // MODE SELECTOR — shown first, before any wizard step
    if (_mode == null) return _buildModeSelector();

    // AI MODE
    if (_mode == _DesignMode.ai) return _buildAiMode();

    // MANUAL MODE — Column with Expanded to prevent overflow in TabBarView
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _StepIndicator(current: _step),
        ),
        const SizedBox(height: 4),
        // Expanded prevents the Column from overflowing its TabBarView slot
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: [
                _buildStepTemplate(),
                _buildStepEdit(),
                _buildStepPreview(),
              ][_step],
            ),
          ),
        ),
        _buildNavButtons(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODE SELECTOR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildModeSelector() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Text('✨', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Build Your Resume',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('How do you want to create it?',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
              ),
            ]),
            const SizedBox(height: 24),

            // Manual card
            _ModeCard(
              emoji: '📝',
              title: 'Edit & Build Manually',
              subtitle: 'Full control over every field',
              description:
                  'Your parsed data is pre-filled. Edit your name, experience, skills, and projects freely, then download a polished DOCX.',
              features: const [
                'Pre-filled from your parsed resume',
                'Edit every field before generating',
                'Preview stats before downloading',
              ],
              accentColor: AppColors.violet,
              isDark: widget.isDark,
              onTap: () => setState(() => _mode = _DesignMode.manual),
            ),
            const SizedBox(height: 16),

            // AI card
            _ModeCard(
              emoji: '🤖',
              title: 'Let AI Write It',
              subtitle: 'AI rewrites your resume for your target role',
              description:
                  'AI reads your full parsed resume and rewrites it professionally for any role and tone. One click, ready-to-use result.',
              features: const [
                'Enter target role & select tone',
                'AI rewrites for maximum impact',
                'Choose Professional, Aggressive, or Technical',
              ],
              accentColor: AppColors.emerald,
              isDark: widget.isDark,
              badge: widget.resume.isParsed ? '✓ Parsed' : null,
              onTap: () {
                if (!widget.resume.isParsed) {
                  _snack('Parse your resume first — go to INFO tab → Parse',
                      isError: true);
                  return;
                }
                setState(() => _mode = _DesignMode.ai);
              },
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // AI MODE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAiMode() => Column(
        children: [
          // Back header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() {
                  _mode = null;
                  _aiDone = false;
                }),
              ),
              const Text('AI Resume Generator',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Text('🤖', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                        'AI reads your full parsed resume and rewrites it for your target role.',
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            height: 1.4),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Target role
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
                  const SizedBox(height: 20),

                  // Tone
                  _label('Writing Tone'),
                  const SizedBox(height: 8),
                  Row(children: [
                    _ToneChip(
                      emoji: '💼',
                      label: 'Professional',
                      selected: _selectedTone == 'professional',
                      color: AppColors.violet,
                      onTap: () =>
                          setState(() => _selectedTone = 'professional'),
                    ),
                    const SizedBox(width: 8),
                    _ToneChip(
                      emoji: '🔥',
                      label: 'Aggressive',
                      selected: _selectedTone == 'aggressive',
                      color: AppColors.rose,
                      onTap: () => setState(() => _selectedTone = 'aggressive'),
                    ),
                    const SizedBox(width: 8),
                    _ToneChip(
                      emoji: '⚙️',
                      label: 'Technical',
                      selected: _selectedTone == 'technical',
                      color: AppColors.cyan,
                      onTap: () => setState(() => _selectedTone = 'technical'),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Template
                  _label('Template'),
                  const SizedBox(height: 8),
                  ..._templates.map((t) => GestureDetector(
                        onTap: () => setState(() => _selectedTemplate = t.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTemplate == t.id
                                ? AppColors.violet.withValues(alpha: 0.1)
                                : (widget.isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedTemplate == t.id
                                  ? AppColors.violet
                                  : Colors.white12,
                              width: _selectedTemplate == t.id ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(t.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13)),
                                  Text(t.description,
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11)),
                                ])),
                            if (_selectedTemplate == t.id)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.violet, size: 18),
                          ]),
                        ),
                      )),

                  const SizedBox(height: 24),

                  // Success banner
                  if (_aiDone)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.emerald.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.emerald, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text(
                          '✅ AI Resume downloaded!',
                          style: TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.bold),
                        )),
                      ]),
                    ),

                  // Generate button
                  GestureDetector(
                    onTap: _aiGenerating ? null : _aiGenerate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: _aiGenerating || _aiDone
                            ? null
                            : const LinearGradient(colors: [
                                Color(0xFF059669),
                                Color(0xFF0891B2),
                              ]),
                        color: _aiGenerating
                            ? Colors.grey.shade800
                            : _aiDone
                                ? AppColors.emerald
                                : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_aiGenerating)
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                          else
                            Text(_aiDone ? '✅' : '🤖',
                                style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Text(
                            _aiGenerating
                                ? 'AI is writing...'
                                : _aiDone
                                    ? 'Download Again'
                                    : 'Generate AI Resume',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 0 — TEMPLATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepTemplate() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Choose Your Template', Icons.style_rounded),
            const SizedBox(height: 14),
            ..._templates.map((t) => _TemplateCard(
                  template: t,
                  selected: _selectedTemplate == t.id,
                  isDark: widget.isDark,
                  onTap: () => setState(() => _selectedTemplate = t.id),
                )),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _mode = null),
              child: Row(children: [
                const Icon(Icons.arrow_back_ios_rounded,
                    size: 11, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Switch to AI mode',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        decoration: TextDecoration.underline)),
              ]),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — EDIT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepEdit() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Edit Your Resume Data', Icons.edit_rounded),
                const SizedBox(height: 4),
                Text(
                  'Pre-filled from your parsed resume — edit anything.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const SizedBox(height: 10),
                TabBar(
                  controller: _editTabs,
                  isScrollable: true,
                  indicatorColor: AppColors.violet,
                  labelColor: AppColors.violet,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 10),
                  tabs: const [
                    Tab(text: 'CONTACT'),
                    Tab(text: 'EXPERIENCE'),
                    Tab(text: 'EDUCATION'),
                    Tab(text: 'SKILLS'),
                    Tab(text: 'PROJECTS'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _editTabs,
              children: [
                _editContact(),
                _editExperience(),
                _editEducation(),
                _editSkills(),
                _editProjects(),
              ],
            ),
          ),
        ],
      );

  Widget _editContact() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(children: [
          _field(_nameCtrl, 'Full Name *', Icons.person_rounded),
          _field(_emailCtrl, 'Email', Icons.email_rounded),
          _field(_phoneCtrl, 'Phone', Icons.phone_rounded),
          _field(_locationCtrl, 'Location / City', Icons.location_on_rounded),
          _field(_linkedinCtrl, 'LinkedIn URL', Icons.link_rounded),
          _field(_githubCtrl, 'GitHub URL', Icons.code_rounded),
          _field(_summaryCtrl, 'Professional Summary', Icons.notes_rounded,
              maxLines: 4),
        ]),
      );

  Widget _editExperience() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(children: [
          ..._experience.asMap().entries.map((e) {
            final i = e.key;
            return _ExpCard(
              exp: e.value,
              index: i,
              isDark: widget.isDark,
              onDelete: _experience.length > 1
                  ? () => setState(() => _experience.removeAt(i))
                  : null,
              onChange: (u) => setState(() => _experience[i] = u),
            );
          }),
          _addBtn('Add Experience',
              () => setState(() => _experience.add(_emptyExp()))),
        ]),
      );

  Widget _editEducation() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(children: [
          ..._education.asMap().entries.map((e) {
            final i = e.key;
            return _EduCard(
              edu: e.value,
              index: i,
              isDark: widget.isDark,
              onDelete: _education.length > 1
                  ? () => setState(() => _education.removeAt(i))
                  : null,
              onChange: (u) => setState(() => _education[i] = u),
            );
          }),
          _addBtn('Add Education',
              () => setState(() => _education.add(_emptyEdu()))),
        ]),
      );

  Widget _editSkills() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_skills.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('No skills yet — add below',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills
                  .asMap()
                  .entries
                  .map((e) => _SkillChip(
                        label: e.value,
                        onDelete: () => setState(() => _skills.removeAt(e.key)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            _AddSkillField(
              isDark: widget.isDark,
              onAdd: (s) {
                if (s.isNotEmpty && !_skills.contains(s)) {
                  setState(() => _skills.add(s));
                }
              },
            ),
            const SizedBox(height: 6),
            Text('${_skills.length} skills added',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      );

  Widget _editProjects() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(children: [
          ..._projects.asMap().entries.map((e) {
            final i = e.key;
            return _ProjectCard(
              project: e.value,
              index: i,
              isDark: widget.isDark,
              onDelete: () => setState(() => _projects.removeAt(i)),
              onChange: (u) => setState(() => _projects[i] = u),
            );
          }),
          _addBtn(
              'Add Project',
              () => setState(() => _projects.add({
                    'name': '',
                    'description': '',
                    'technologies': '',
                  }))),
        ]),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — PREVIEW + DOWNLOAD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStepPreview() {
    final tmpl = _templates.firstWhere((t) => t.id == _selectedTemplate);
    final data = _buildResumeData();
    final name = data['name']?.toString() ?? 'Your Name';
    final expList = data['experience'] as List? ?? [];
    final eduList = data['education'] as List? ?? [];
    final skillList = data['skills'] as List? ?? [];
    final projList = data['projects'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Preview & Download', Icons.download_rounded),
          const SizedBox(height: 14),
          GlassCard(
            isDark: widget.isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(tmpl.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(tmpl.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('DOCX',
                        style: TextStyle(
                            color: AppColors.violet,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ]),
                const Divider(height: 18, color: Colors.white10),
                Text(name.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 10),
                Row(children: [
                  _statBadge('${expList.length}', 'Exp', AppColors.violet),
                  const SizedBox(width: 8),
                  _statBadge('${eduList.length}', 'Edu', AppColors.cyan),
                  const SizedBox(width: 8),
                  _statBadge(
                      '${skillList.length}', 'Skills', AppColors.emerald),
                  const SizedBox(width: 8),
                  _statBadge('${projList.length}', 'Proj', AppColors.amber),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _generating ? 'Generating...' : '⬇  Download Resume (DOCX)',
            isLoading: _generating,
            onTap: _download,
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18, color: color)),
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
          ]),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // NAV BUTTONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNavButtons() => Container(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 14 + MediaQuery.of(context).padding.bottom + 70),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(children: [
          // Back / Mode button
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                if (_step == 0) {
                  setState(() => _mode = null);
                } else {
                  setState(() => _step--);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_step == 0 ? '← Mode' : '← Back'),
            ),
          ),
          if (_step < 2) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => setState(() => _step++),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    Text(_step == 0 ? 'Edit Data →' : ' Preview & Download →'),
              ),
            ),
          ],
        ]),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
        Icon(icon, size: 17, color: AppColors.violet),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ]);

  Widget _field(TextEditingController c, String hint, IconData icon,
          {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black87,
              fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 17, color: AppColors.violet),
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

  Widget _addBtn(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 15),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.violet,
            side: BorderSide(color: AppColors.violet.withValues(alpha: 0.35)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE CARD
// ─────────────────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: accentColor.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: accentColor.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14)),
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 13, color: accentColor),
              ]),
              const SizedBox(height: 12),
              Text(description,
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12, height: 1.4)),
              const SizedBox(height: 10),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded,
                          color: accentColor, size: 13),
                      const SizedBox(width: 7),
                      Text(f,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  )),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TONE CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _ToneChip extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ToneChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? color : Colors.white12,
                  width: selected ? 2 : 1),
            ),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: selected ? color : Colors.grey)),
            ]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final _Template template;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.violet.withValues(alpha: 0.08)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.violet : Colors.white12,
                width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Text(template.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(template.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13)),
                  Text(template.description,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ])),
            selected
                ? const Icon(Icons.check_circle_rounded,
                    color: AppColors.violet, size: 22)
                : Icon(Icons.radio_button_unchecked_rounded,
                    color: Colors.grey.shade600, size: 22),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) => Row(children: [
        _dot(0, 'Template', current),
        _line(0, current),
        _dot(1, 'Edit Data', current),
        _line(1, current),
        _dot(2, 'Download', current),
      ]);

  Widget _dot(int idx, String label, int cur) {
    final done = cur > idx;
    final active = cur == idx;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: done || active ? AppColors.violet : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
              : Text('${idx + 1}',
                  style: TextStyle(
                      color: active ? Colors.white : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
        ),
      ),
      const SizedBox(height: 3),
      Text(label,
          style: TextStyle(
              color: active ? AppColors.violet : Colors.grey,
              fontSize: 9,
              fontWeight: active ? FontWeight.w900 : FontWeight.normal)),
    ]);
  }

  Widget _line(int idx, int cur) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 16),
          color: cur > idx ? AppColors.violet : Colors.white12,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EXP CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ExpCard extends StatefulWidget {
  final Map<String, dynamic> exp;
  final int index;
  final bool isDark;
  final VoidCallback? onDelete;
  final ValueChanged<Map<String, dynamic>> onChange;
  const _ExpCard({
    required this.exp,
    required this.index,
    required this.isDark,
    required this.onChange,
    this.onDelete,
  });

  @override
  State<_ExpCard> createState() => _ExpCardState();
}

class _ExpCardState extends State<_ExpCard> {
  late TextEditingController _title, _company, _duration, _desc;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.exp['title']?.toString() ?? '');
    _company =
        TextEditingController(text: widget.exp['company']?.toString() ?? '');
    _duration =
        TextEditingController(text: widget.exp['duration']?.toString() ?? '');
    _desc = TextEditingController(
        text: widget.exp['description']?.toString() ?? '');
    for (final c in [_title, _company, _duration, _desc]) {
      c.addListener(_notify);
    }
  }

  void _notify() => widget.onChange({
        'title': _title.text,
        'company': _company.text,
        'duration': _duration.text,
        'description': _desc.text,
      });

  @override
  void dispose() {
    for (final c in [_title, _company, _duration, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Experience ${widget.index + 1}',
        color: AppColors.violet,
        isDark: widget.isDark,
        onDelete: widget.onDelete,
        child: Column(children: [
          _tf(_title, 'Job Title *'),
          _tf(_company, 'Company'),
          _tf(_duration, 'Duration (e.g. Jan 2022 – Present)'),
          _tf(_desc, 'Responsibilities...', maxLines: 3),
        ]),
      );

  Widget _tf(TextEditingController c, String hint, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
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
                : Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDU CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EduCard extends StatefulWidget {
  final Map<String, dynamic> edu;
  final int index;
  final bool isDark;
  final VoidCallback? onDelete;
  final ValueChanged<Map<String, dynamic>> onChange;
  const _EduCard({
    required this.edu,
    required this.index,
    required this.isDark,
    required this.onChange,
    this.onDelete,
  });

  @override
  State<_EduCard> createState() => _EduCardState();
}

class _EduCardState extends State<_EduCard> {
  late TextEditingController _degree, _institution, _year, _gpa;

  @override
  void initState() {
    super.initState();
    _degree =
        TextEditingController(text: widget.edu['degree']?.toString() ?? '');
    _institution = TextEditingController(
        text: (widget.edu['institution'] ?? widget.edu['university'] ?? '')
            .toString());
    _year = TextEditingController(text: widget.edu['year']?.toString() ?? '');
    _gpa = TextEditingController(text: widget.edu['gpa']?.toString() ?? '');
    for (final c in [_degree, _institution, _year, _gpa]) {
      c.addListener(_notify);
    }
  }

  void _notify() => widget.onChange({
        'degree': _degree.text,
        'institution': _institution.text,
        'year': _year.text,
        'gpa': _gpa.text,
      });

  @override
  void dispose() {
    for (final c in [_degree, _institution, _year, _gpa]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Education ${widget.index + 1}',
        color: AppColors.cyan,
        isDark: widget.isDark,
        onDelete: widget.onDelete,
        child: Column(children: [
          _tf(_degree, 'Degree / Qualification *'),
          _tf(_institution, 'University / Institution'),
          Row(children: [
            Expanded(child: _tf(_year, 'Year')),
            const SizedBox(width: 8),
            Expanded(child: _tf(_gpa, 'GPA')),
          ]),
        ]),
      );

  Widget _tf(TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black87,
              fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PROJECT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final int index;
  final bool isDark;
  final VoidCallback onDelete;
  final ValueChanged<Map<String, dynamic>> onChange;
  const _ProjectCard({
    required this.project,
    required this.index,
    required this.isDark,
    required this.onDelete,
    required this.onChange,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  late TextEditingController _name, _tech, _desc;

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: widget.project['name']?.toString() ?? '');
    _tech = TextEditingController(
        text: (widget.project['technologies'] ?? '').toString());
    _desc = TextEditingController(
        text: widget.project['description']?.toString() ?? '');
    for (final c in [_name, _tech, _desc]) {
      c.addListener(_notify);
    }
  }

  void _notify() => widget.onChange({
        'name': _name.text,
        'technologies': _tech.text,
        'description': _desc.text,
      });

  @override
  void dispose() {
    for (final c in [_name, _tech, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Project ${widget.index + 1}',
        color: AppColors.amber,
        isDark: widget.isDark,
        onDelete: widget.onDelete,
        child: Column(children: [
          _tf(_name, 'Project Name *'),
          _tf(_tech, 'Technologies (Flutter, FastAPI, ...)'),
          _tf(_desc, 'Description...', maxLines: 2),
        ]),
      );

  Widget _tf(TextEditingController c, String hint, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
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
                : Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD SHELL
// ─────────────────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final String title;
  final Color color;
  final bool isDark;
  final VoidCallback? onDelete;
  final Widget child;
  const _CardShell({
    required this.title,
    required this.color,
    required this.isDark,
    required this.child,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 11, color: color)),
              const Spacer(),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.rose, size: 18),
                ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SKILL CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _SkillChip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;
  const _SkillChip({required this.label, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.violet.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.violet.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.violet)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded,
                size: 13, color: AppColors.violet.withValues(alpha: 0.7)),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD SKILL FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _AddSkillField extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String> onAdd;
  const _AddSkillField({required this.isDark, required this.onAdd});

  @override
  State<_AddSkillField> createState() => _AddSkillFieldState();
}

class _AddSkillFieldState extends State<_AddSkillField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onAdd(_ctrl.text.trim());
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            onSubmitted: (_) => _submit(),
            style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Type a skill and press +',
              filled: true,
              fillColor: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade50,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _submit,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.violet,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]);
}
