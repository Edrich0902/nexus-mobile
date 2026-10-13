import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

(String, Ambient) daypartNow([DateTime? at]) {
  final h = (at ?? DateTime.now()).hour;
  if (h >= 5 && h < 12) return ('morning', NxMoments.morning);
  if (h >= 12 && h < 17) return ('afternoon', NxMoments.afternoon);
  return ('evening', NxMoments.evening);
}

/// Sign in (web LoginView): clock eyebrow, "Good *evening*." and a quiet form.
/// The ambient follows the local time of day — nothing personal pre-auth.
class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  int _rejections = 0;
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(email: _email.text.trim(), password: _password.text, remember: _remember);
      unawaited(HapticFeedback.lightImpact());
    } on Object catch (e) {
      final err = ApiError.from(e, 'Could not sign in.');
      unawaited(HapticFeedback.heavyImpact());
      setState(() {
        _error = err.field('email') ?? err.message;
        _rejections++;
        _password.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final (word, moment) = daypartNow(_now);
    final expired = ref.watch(authProvider) is SignedOut && (ref.watch(authProvider) as SignedOut).expired;
    final mq = MediaQuery.of(context);

    return AmbientOverride(
      ambient: moment,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: -160,
              right: -120,
              child: IgnorePointer(
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [c.acc.withValues(alpha: .22), c.acc.withValues(alpha: 0)]),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: AutofillGroup(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + mq.viewInsets.bottom),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: c.acc, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Nexus',
                          style: NxText.sans(size: 15, weight: FontWeight.w600, color: c.ink),
                        ),
                      ],
                    ),
                    SizedBox(height: mq.size.height * .12),
                    NxRise(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('EEE d MMM, HH:mm').format(_now), style: NxText.eyebrow(context)),
                          const SizedBox(height: 12),
                          Semantics(
                            header: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Good '),
                                  TextSpan(
                                    text: word,
                                    style: TextStyle(color: c.acc, fontStyle: FontStyle.italic),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                              style: NxText.serif(size: 56, color: c.ink),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Sign in to pick up where you left off.', style: NxText.sans(size: 16, color: c.ink2)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (expired && _error == null) ...[
                      const _Note(icon: LucideIcons.clock, text: 'Your session ended. Sign in again to continue.'),
                      const SizedBox(height: 16),
                    ],
                    NxTextField(
                      label: 'Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    NxShake(
                      trigger: _rejections == 0 ? null : _rejections,
                      child: Stack(
                        children: [
                          NxTextField(
                            label: 'Password',
                            controller: _password,
                            obscure: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _submit(),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: NxIconButton(
                              _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    MergeSemantics(
                      child: Row(
                        children: [
                          Switch(value: _remember, onChanged: (v) => setState(() => _remember = v)),
                          const SizedBox(width: 10),
                          Text('Keep me signed in', style: NxText.sans(size: 14.5, color: c.ink2)),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: NxTiming.base,
                      curve: NxMotion.ease,
                      alignment: Alignment.topCenter,
                      child: NxSwitcher(
                        child: _error == null
                            ? const SizedBox(key: ValueKey('ok'), width: double.infinity)
                            : Padding(
                                key: ValueKey('error:$_rejections'),
                                padding: const EdgeInsets.only(top: 12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: _Note(icon: LucideIcons.circleAlert, text: _error!, error: true),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    NxButton('Sign in', onPressed: _submit, loading: _busy, wide: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? NexusColors.bad.withValues(alpha: .14) : c.tint,
        borderRadius: BorderRadius.circular(NxRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: error ? NexusColors.bad : c.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: NxText.sans(color: c.ink)),
          ),
        ],
      ),
    );
  }
}
