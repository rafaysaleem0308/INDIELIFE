import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello/core/services/ai_budget_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THEME TOKENS
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFFFF9D42);
  static const primaryDk = Color(0xFFFF512F);
  static const accent = Color(0xFF6C63FF);
  static const success = Color(0xFF22C55E);
  static const text = Color(0xFF1E293B);
  static const subtle = Color(0xFF64748B);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFFE5E7EB);
  static const calcBg = Color(0xFFFFFBF5);
  static const calcBorder = Color(0xFFFFE0BB);
}

// ─────────────────────────────────────────────────────────────────────────────
//  UTF-16 SAFE HELPERS
//  Dart strings are UTF-16. Emoji and many Unicode characters outside the Basic
//  Multilingual Plane occupy TWO code units (a surrogate pair). Slicing a
//  string at an odd code-unit index that lands *inside* a surrogate pair
//  produces an ill-formed UTF-16 string, which Flutter's text engine rejects
//  with "string is not well-formed UTF-16".
//
//  _safeSubstring  – like substring() but snaps the end index forward past any
//                    dangling lead surrogate so the result is always well-formed.
//  _runeLength     – number of Unicode scalar values (runes) in a string, used
//                    to drive the typewriter tick count.
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `s.substring(0, end)` but advances `end` by 1 if it would split a
/// surrogate pair (lead surrogate U+D800–U+DBFF at position end-1).
// ─────────────────────────────────────────────────────────────────────────────
//  BOLD MARKDOWN PARSER
// ─────────────────────────────────────────────────────────────────────────────
List<TextSpan> _buildFormattedSpans(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final bold = RegExp(r'\*\*(.*?)\*\*', dotAll: true);
  int last = 0;
  for (final m in bold.allMatches(text)) {
    if (m.start > last)
      spans.add(TextSpan(text: text.substring(last, m.start)));
    spans.add(
      TextSpan(
        text: m.group(1) ?? '',
        style: base.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION MODEL
// ─────────────────────────────────────────────────────────────────────────────
enum _SectionKind { plain, calculation, tip }

class _Section {
  final _SectionKind kind;
  final String content;
  const _Section(this.kind, this.content);
}

// ─────────────────────────────────────────────────────────────────────────────
//  MESSAGE MODEL
// ─────────────────────────────────────────────────────────────────────────────
enum _MsgType { normal, combined, guide }

class ChatMessage {
  final String role;
  final String content;
  final bool isTyping;
  final _MsgType type;
  final List<_Section> sections;

  // Stable identity key — assigned once when the message is created.
  final UniqueKey stableKey;

  ChatMessage({
    required this.role,
    required this.content,
    this.isTyping = false,
    this.type = _MsgType.normal,
    this.sections = const [],
  }) : stableKey = UniqueKey();
}

// ─────────────────────────────────────────────────────────────────────────────
//  TYPEWRITER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class TypingText extends StatefulWidget {
  final String text;
  final int msPerChar;
  final TextStyle? baseStyle;
  final VoidCallback? onDone;

  const TypingText({
    super.key,
    required this.text,
    this.msPerChar = 28,
    this.baseStyle,
    this.onDone,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _shown = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Pre-compute rune-boundary end-indices so the timer never slices inside
    // a surrogate pair (which would cause "string is not well-formed UTF-16").
    final boundaries = <int>[];
    int pos = 0;
    for (final rune in widget.text.runes) {
      pos += rune > 0xFFFF ? 2 : 1;
      boundaries.add(pos);
    }
    int tick = 0;
    _timer = Timer.periodic(Duration(milliseconds: widget.msPerChar), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (tick >= boundaries.length) {
        t.cancel();
        widget.onDone?.call();
        return;
      }
      final end = boundaries[tick++];
      setState(() => _shown = widget.text.substring(0, end));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.baseStyle ??
        GoogleFonts.inter(fontSize: 14, color: _C.text, height: 1.55);
    final isDone = _shown.length >= widget.text.length;
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          ..._buildFormattedSpans(_shown, base),
          if (!isDone)
            TextSpan(
              text: '▋',
              style: TextStyle(color: _C.primary, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMBINED BUBBLE — types each section sequentially
//  Uses AutomaticKeepAliveClientMixin to survive list scroll recycling.
// ─────────────────────────────────────────────────────────────────────────────
class _CombinedBubble extends StatefulWidget {
  final List<_Section> sections;
  final double maxWidth;

  const _CombinedBubble({
    super.key,
    required this.sections,
    required this.maxWidth,
  });

  @override
  State<_CombinedBubble> createState() => _CombinedBubbleState();
}

class _CombinedBubbleState extends State<_CombinedBubble>
    with AutomaticKeepAliveClientMixin {
  // Keeps this widget alive even when scrolled off-screen.
  @override
  bool get wantKeepAlive => true;

  int _visible = 1;
  int get _typingIdx => _visible - 1;

  void _onSectionDone() {
    if (!mounted) return;
    if (_visible < widget.sections.length) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _visible++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Container(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.calcBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.calcBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < _visible; i++) ...[
                  _SectionTile(
                        key: ValueKey(i),
                        section: widget.sections[i],
                        isTyping: i == _typingIdx,
                        onDone: i == _typingIdx ? _onSectionDone : null,
                      )
                      .animate()
                      .fadeIn(duration: 240.ms)
                      .slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 240.ms,
                        curve: Curves.easeOut,
                      ),
                  if (i < _visible - 1 && i < widget.sections.length - 1)
                    _divider(widget.sections[i + 1].kind),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_C.primary, _C.primaryDk],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
        const SizedBox(width: 8),
        Text(
          'AI BUDGET PLAN',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'PKR',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _divider(_SectionKind nextKind) {
    final extra =
        nextKind == _SectionKind.calculation || nextKind == _SectionKind.tip;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: extra ? 14 : 10),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _C.calcBorder.withOpacity(0.0),
              _C.calcBorder,
              _C.calcBorder.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION TILE
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTile extends StatelessWidget {
  final _Section section;
  final bool isTyping;
  final VoidCallback? onDone;

  const _SectionTile({
    super.key,
    required this.section,
    required this.isTyping,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    switch (section.kind) {
      case _SectionKind.plain:
        return _plain();
      case _SectionKind.calculation:
        return _calc();
      case _SectionKind.tip:
        return _tip();
    }
  }

  Widget _plain() {
    final base = GoogleFonts.inter(fontSize: 14, height: 1.55, color: _C.text);
    return isTyping
        ? TypingText(
            text: section.content,
            msPerChar: 16,
            baseStyle: base,
            onDone: onDone,
          )
        : RichText(
            text: TextSpan(
              style: base,
              children: _buildFormattedSpans(section.content, base),
            ),
          );
  }

  Widget _calc() {
    final base = GoogleFonts.sourceCodePro(
      fontSize: 12.5,
      height: 1.65,
      color: _C.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _C.text.withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(
              bottom: BorderSide(color: _C.border.withOpacity(0.5)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calculate_outlined,
                color: _C.primaryDk,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                'CALCULATION BREAKDOWN',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _C.primaryDk,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _C.calcBg.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(10),
            ),
          ),
          child: isTyping
              ? TypingText(
                  text: section.content,
                  msPerChar: 14,
                  baseStyle: base,
                  onDone: onDone,
                )
              : RichText(
                  text: TextSpan(
                    style: base,
                    children: _buildFormattedSpans(section.content, base),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tip() {
    final base = GoogleFonts.inter(fontSize: 13.5, height: 1.6, color: _C.text);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEFBF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.success.withOpacity(0.35), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _C.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: _C.success,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isTyping
                ? TypingText(
                    text: section.content,
                    msPerChar: 20,
                    baseStyle: base,
                    onDone: onDone,
                  )
                : RichText(
                    text: TextSpan(
                      style: base,
                      children: _buildFormattedSpans(section.content, base),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KEEP-ALIVE WRAPPER
//  Wraps any widget so it survives ListView scroll recycling.
// ─────────────────────────────────────────────────────────────────────────────
class _KeepAliveItem extends StatefulWidget {
  final Widget child;
  const _KeepAliveItem({required this.child});

  @override
  State<_KeepAliveItem> createState() => _KeepAliveItemState();
}

class _KeepAliveItemState extends State<_KeepAliveItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AIBudgetRecommendation extends StatefulWidget {
  const AIBudgetRecommendation({super.key});

  @override
  State<AIBudgetRecommendation> createState() => _AIBudgetRecommendationState();
}

class _AIBudgetRecommendationState extends State<AIBudgetRecommendation>
    with SingleTickerProviderStateMixin {
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <ChatMessage>[];
  bool _isLoading = false;
  late final AnimationController _pulseCtrl;

  static const _stepLabels = [
    '🔍 Parsing your input...',
    '🧮 Running calculations...',
    '📊 Building budget plan...',
    '💡 Generating tips...',
    '✅ Done!',
  ];
  int _stepIndex = 0;
  bool _showStep = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _addIntroMessages();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _addIntroMessages() {
    _messages.add(
      ChatMessage(
        role: 'assistant',
        type: _MsgType.guide,
        content:
            '**👋 Welcome to AI Budget Assistant**\n\n'
            'Write your request in simple English and I will build a plan for you.\n\n'
            '**Supported areas:**  Meals · Laundry · Maintenance\n\n'
            '**Try typing like this:**\n'
            '• "5000 for 10 days for food"\n'
            '• "need laundry plan for 2 weeks budget 3000"\n'
            '• "12000 for 1 month home maintenance"',
      ),
    );
  }

  String _normalize(String s) =>
      s.replaceAll(RegExp(r'\bRs\b', caseSensitive: false), 'PKR');

  void _scroll() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  void _push(ChatMessage msg) {
    setState(() => _messages.add(msg));
    _scroll();
  }

  Future<void> _advanceStep(int idx) async {
    setState(() {
      _stepIndex = idx;
      _showStep = true;
    });
    await Future.delayed(const Duration(milliseconds: 600));
  }

  String _buildCalc(Map<String, dynamic> plan, Map<String, dynamic> nlp) {
    final double budget = ((plan['budget'] ?? 0) as num).toDouble();
    final int days = (plan['days'] ?? 1) as int;
    final double daily = ((plan['daily_budget'] ?? 0) as num).toDouble();
    final double spent = ((plan['total_spent'] ?? 0) as num).toDouble();
    final double remaining = ((plan['remaining'] ?? 0) as num).toDouble();
    final double util = budget > 0 ? (spent / budget) * 100 : 0;
    final cat = (nlp['category'] ?? 'auto-detected').toString();
    final weekly = daily * 7;
    final monthly = daily * 30;

    return '**📐 Step-by-Step Calculations**\n\n'
        '**Step 1 — Daily Budget**\n'
        '  Formula : Budget ÷ Days\n'
        '  Result  : PKR ${budget.toStringAsFixed(0)} ÷ $days = **PKR ${daily.toStringAsFixed(2)}/day**\n\n'
        '**Step 2 — Extended Projections**\n'
        '  Weekly  : PKR ${daily.toStringAsFixed(2)} × 7 = **PKR ${weekly.toStringAsFixed(2)}**\n'
        '  Monthly : PKR ${daily.toStringAsFixed(2)} × 30 = **PKR ${monthly.toStringAsFixed(2)}**\n\n'
        '**Step 3 — Budget Utilization**\n'
        '  Planned Spend : PKR ${spent.toStringAsFixed(2)}\n'
        '  Remaining     : PKR ${remaining.toStringAsFixed(2)}\n'
        '  Utilization   : ${spent.toStringAsFixed(2)} ÷ ${budget.toStringAsFixed(2)} × 100 = **${util.toStringAsFixed(1)}%**\n\n'
        '**Detected Area :** ${cat[0].toUpperCase()}${cat.substring(1)}';
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty || _isLoading) return;

    _push(ChatMessage(role: 'user', content: _normalize(prompt)));
    _promptCtrl.clear();

    setState(() {
      _isLoading = true;
      _stepIndex = 0;
      _showStep = true;
      _messages.add(
        ChatMessage(role: 'assistant', content: '', isTyping: true),
      );
    });
    _scroll();

    try {
      await _advanceStep(0);
      final result = await AIBudgetService.getAIRecommendationFromText(
        text: prompt,
      );

      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.isTyping));

      if (result['success'] == true) {
        final chatMsgs = (result['chat_messages'] as List<dynamic>? ?? []);
        final plan = (result['plan'] as Map<String, dynamic>? ?? {});
        final nlp = (result['nlp_analysis'] as Map<String, dynamic>? ?? {});

        await _advanceStep(1);

        final sections = <_Section>[];

        if (chatMsgs.isEmpty) {
          sections.add(
            const _Section(
              _SectionKind.plain,
              'Plan created, but no detailed output was returned from the server.',
            ),
          );
        } else {
          await _advanceStep(2);
          for (final msg in chatMsgs) {
            final role = (msg is Map<String, dynamic>)
                ? (msg['role']?.toString() ?? 'assistant')
                : 'assistant';
            if (role != 'assistant') continue;
            final raw = _normalize(
              (msg is Map<String, dynamic>)
                  ? (msg['content']?.toString() ?? '')
                  : msg.toString(),
            );
            if (raw.isNotEmpty) sections.add(_Section(_SectionKind.plain, raw));
          }
        }

        if (plan.isNotEmpty) {
          await _advanceStep(3);
          sections.add(
            _Section(
              _SectionKind.calculation,
              _normalize(_buildCalc(plan, nlp)),
            ),
          );
          sections.add(
            const _Section(
              _SectionKind.tip,
              '**💼 Professional Tip**\n'
              'Track actual daily spending vs the suggested daily budget. '
              'If actual spend exceeds plan for 2 consecutive days, reduce optional items '
              'the next day to stay within your PKR targets.',
            ),
          );
        }

        await _advanceStep(4);

        _push(
          ChatMessage(
            role: 'assistant',
            content: '',
            type: _MsgType.combined,
            sections: sections,
          ),
        );
      } else {
        final err = _normalize(
          result['error']?.toString() ?? 'Could not process request.',
        );
        final suggestion = result['suggestion']?.toString();
        _push(
          ChatMessage(
            role: 'assistant',
            content: suggestion == null
                ? '⚠️ $err'
                : '⚠️ $err\n\n**Suggestion:** ${_normalize(suggestion)}',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.isTyping));
      _push(
        ChatMessage(
          role: 'assistant',
          content: '⚠️ ${_normalize(e.toString())}',
        ),
      );
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _showStep = false;
        });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.bg,
    resizeToAvoidBottomInset: true,
    appBar: _buildAppBar(),
    body: SafeArea(
      child: Column(
        children: [
          _buildHintBanner(),
          if (_showStep) _buildStepBanner(),
          Expanded(child: _buildMessageList()),
          _buildComposer(),
        ],
      ),
    ),
  );

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    elevation: 0,
    backgroundColor: _C.surface,
    surfaceTintColor: Colors.transparent,
    titleSpacing: 0,
    actions: [
      IconButton(
        tooltip: 'Reset Chat',
        onPressed: () {
          setState(() {
            _messages.clear();
            _addIntroMessages();
          });
        },
        icon: const Icon(Icons.refresh_rounded, color: _C.subtle),
      ),
      const SizedBox(width: 8),
    ],
    leading: const BackButton(color: _C.text),
    title: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_C.primary, _C.primaryDk],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Budget Assistant',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.success.withOpacity(
                        0.5 + 0.5 * _pulseCtrl.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Online · PKR mode',
                  style: GoogleFonts.inter(fontSize: 10.5, color: _C.muted),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _C.border),
    ),
  );

  // ── Hint banner ───────────────────────────────────────────────────────────
  Widget _buildHintBanner() => Container(
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_C.primary, _C.primaryDk],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: _C.primary.withOpacity(0.25),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(
          Icons.tips_and_updates_outlined,
          color: Colors.white70,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Write your full requirement in simple language — I will detect budget and duration automatically.',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Step banner ───────────────────────────────────────────────────────────
  Widget _buildStepBanner() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    child: Container(
      key: ValueKey(_stepIndex),
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(_C.accent),
              value: _stepIndex == 4 ? 1.0 : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _stepLabels[_stepIndex.clamp(0, _stepLabels.length - 1)],
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _C.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Message list ──────────────────────────────────────────────────────────
  // FIX: Use ListView with explicit children instead of ListView.builder.
  // ListView.builder lazily creates/destroys items as they scroll in/out of
  // view, which resets StatefulWidget state (typewriter animations, section
  // counters). Using a plain ListView keeps every item alive in the tree.
  Widget _buildMessageList() => ListView(
    controller: _scrollCtrl,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    children: [
      for (int i = 0; i < _messages.length; i++) _buildBubble(_messages[i], i),
    ],
  );

  // ── Bubble dispatch ───────────────────────────────────────────────────────
  Widget _buildBubble(ChatMessage msg, int index) {
    final isUser = msg.role == 'user';
    if (msg.isTyping) return _typingBubble();

    Widget body;
    switch (msg.type) {
      case _MsgType.combined:
        // Key is the message's own UniqueKey — stable across rebuilds.
        body = _CombinedBubble(
          key: msg.stableKey,
          sections: msg.sections,
          maxWidth: MediaQuery.of(context).size.width * 0.94,
        );
        break;
      case _MsgType.guide:
        body = _guideBubble(msg.content);
        break;
      default:
        // Animate only the very last assistant message that isn't loading.
        final animate = !isUser && index == _messages.length - 1 && !_isLoading;
        body = _plainBubble(msg.content, isUser, animate);
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: body
          .animate()
          .fadeIn(duration: 280.ms)
          .slideX(
            begin: isUser ? 0.06 : -0.06,
            end: 0,
            duration: 280.ms,
            curve: Curves.easeOut,
          ),
    );
  }

  // ── Plain bubble ──────────────────────────────────────────────────────────
  Widget _plainBubble(String text, bool isUser, bool animate) {
    final maxW = MediaQuery.of(context).size.width * 0.82;
    final base = GoogleFonts.inter(
      fontSize: 14,
      height: 1.55,
      color: isUser ? Colors.white : _C.text,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? _C.primary : _C.surface,
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomRight: isUser ? const Radius.circular(4) : null,
          bottomLeft: !isUser ? const Radius.circular(4) : null,
        ),
        border: isUser ? null : Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: animate && !isUser
          ? TypingText(text: text, msPerChar: 22, baseStyle: base)
          : RichText(
              text: TextSpan(
                style: base,
                children: _buildFormattedSpans(text, base),
              ),
            ),
    );
  }

  // ── Guide bubble ──────────────────────────────────────────────────────────
  Widget _guideBubble(String text) {
    final maxW = MediaQuery.of(context).size.width * 0.92;
    final base = GoogleFonts.inter(fontSize: 13.5, height: 1.6, color: _C.text);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_C.primary, _C.primaryDk]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  'GETTING STARTED',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: RichText(
              text: TextSpan(
                style: base,
                children: _buildFormattedSpans(text, base),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────────
  Widget _typingBubble() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(
          16,
        ).copyWith(bottomLeft: const Radius.circular(4)),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(
            3,
            (i) =>
                Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: const BoxDecoration(
                        color: _C.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleY(
                      begin: 1,
                      end: 1.8,
                      duration: 500.ms,
                      delay: (i * 160).ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          const SizedBox(width: 10),
          Text(
            'AI is thinking...',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: _C.subtle,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Composer ──────────────────────────────────────────────────────────────
  Widget _buildComposer() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottom),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _areaChip('Meals'),
              const SizedBox(width: 6),
              _areaChip('Laundry'),
              const SizedBox(width: 6),
              _areaChip('Maintenance'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _promptCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  style: GoogleFonts.inter(fontSize: 14, color: _C.text),
                  decoration: InputDecoration(
                    hintText: 'e.g. 5000 for 10 days food',
                    hintStyle: GoogleFonts.inter(color: _C.muted, fontSize: 13),
                    filled: true,
                    fillColor: _C.bg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _C.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _C.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _C.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _areaChip(String label) => GestureDetector(
    onTap: () {
      final text = _promptCtrl.text.trim();
      if (text.isEmpty) {
        _promptCtrl.text = "I need a budget for $label... ";
      } else {
        _promptCtrl.text = "$text $label";
      }
      _promptCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _promptCtrl.text.length),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.primary.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: _C.primaryDk,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _sendButton() => SizedBox(
    width: 46,
    height: 46,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _C.primary,
        disabledBackgroundColor: _C.border,
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
    ),
  );
}
