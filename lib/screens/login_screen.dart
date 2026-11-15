import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/pixeldrain_api.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/wave_progress.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _totpController = TextEditingController();
  final _api = PixeldrainApi();

  bool _isLoading = false;
  bool _checking = true;
  bool _showOtp = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    final hasKey = await _api.loadSavedKey();
    if (!hasKey) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    final info = await _api.getUserInfo();
    if (!mounted) return;
    if (info != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(api: _api)),
      );
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final s = context.s;
    if (_userController.text.trim().isEmpty || _passController.text.isEmpty) {
      setState(() => _error = s.fillCredentials);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _api.login(
      _userController.text,
      _passController.text,
      totp: _totpController.text,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.needsOtp) _showOtp = true;
      _error = result.success ? null : s.loginError(result.code, result.message);
    });

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(api: _api)),
      );
    }
  }

  Future<void> _toggleLanguage() async {
    await LocaleController.instance.setMode(
      LocaleController.instance.mode == AppLanguage.english
          ? AppLanguage.system
          : AppLanguage.english,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: OrbBackground(
        child: SafeArea(
          child: Column(
            children: [
              _BrandBar(
                trailing: AnimatedSwitcher(
                  duration: AppMotion.base,
                  child: TextButton.icon(
                    key: ValueKey<String>(s.languageCode),
                    onPressed: _toggleLanguage,
                    icon: const Icon(Icons.translate_rounded, size: 17),
                    label: Text(
                      s.switchLanguage,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mutedStrong,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        child: _checking
                            ? const _Checking(key: ValueKey('checking'))
                            : _form(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final s = context.s;
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surface(
          radius: AppRadii.xl,
          elevation: SurfaceElevation.lg,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Entrance(
                  slide: 10,
                  child: OrbIcon(icon: Icons.cloud_download_rounded, size: 92),
                ),
              ),
              const SizedBox(height: 22),
              Entrance(
                delay: const Duration(milliseconds: 90),
                child: Text(
                  s.loginTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Entrance(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  s.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Entrance(
                delay: const Duration(milliseconds: 200),
                child: TextField(
                  controller: _userController,
                  style: TextStyle(color: AppColors.text, fontSize: 15),
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: s.usernameLabel,
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: const Duration(milliseconds: 250),
                child: TextField(
                  controller: _passController,
                  obscureText: _obscure,
                  style: TextStyle(color: AppColors.text, fontSize: 15),
                  textInputAction:
                      _showOtp ? TextInputAction.next : TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: s.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _isLoading ? null : _handleLogin(),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _showOtp
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                GlowIcon(
                                  icon: Icons.shield_outlined,
                                  size: 34,
                                  glow: false,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.otpLabel,
                                    style: TextStyle(
                                      color: AppColors.mutedStrong,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OtpField(
                              controller: _totpController,
                              onCompleted: () =>
                                  _isLoading ? null : _handleLogin(),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _ErrorBox(message: _error!),
                      ),
              ),
              const SizedBox(height: 22),
              Entrance(
                delay: const Duration(milliseconds: 300),
                child: PrimaryButton(
                  label: s.signIn,
                  icon: Icons.arrow_forward_rounded,
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _handleLogin,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: WaveProgressBar(
                          value: 0,
                          indeterminate: true,
                          height: 6,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Entrance(
          delay: const Duration(milliseconds: 360),
          child: Pressable(
            onTap: () => launchUrl(
              Uri.parse('https://pixeldrain.com/register'),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                s.noAccount,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.accentText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Baris logo + nama aplikasi, dipakai di layar login.
class _BrandBar extends StatelessWidget {
  const _BrandBar({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 12, 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: AppColors.glow(AppColors.accent, blur: 16, y: 6),
            ),
            child: const Icon(Icons.cloud_rounded, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Text(
            'Dropify',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Input OTP 6 kotak bergaya referensi (kotak rounded dengan glow aksen).
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final VoidCallback? onCompleted;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final active = _focus.hasFocus ? text.length.clamp(0, widget.length) : -1;

    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _OtpBox(
                    digit: i < text.length ? text[i] : '',
                    active: i == active,
                    filled: i < text.length,
                  ),
                ),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  if (widget.controller.text.length == widget.length) {
                    widget.onCompleted?.call();
                  }
                },
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                showCursor: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.active,
    required this.filled,
  });

  final String digit;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled
            ? AppColors.accent.withValues(alpha: AppColors.isDark ? 0.16 : 0.07)
            : (AppColors.isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.cardHigh),
        borderRadius: BorderRadius.circular(AppRadii.sm + 2),
        border: Border.all(
          color: active
              ? AppColors.accent
              : (filled
                  ? AppColors.accent.withValues(alpha: 0.35)
                  : AppColors.isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : AppColors.divider),
          width: active ? 1.8 : 1.2,
        ),
        boxShadow: active ? AppColors.glow(AppColors.accent, blur: 18, y: 6) : null,
      ),
      child: Text(
        digit,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Breathing(child: OrbIcon(icon: Icons.cloud_rounded, size: 128)),
        const SizedBox(height: 36),
        SizedBox(
          width: 190,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: const WaveProgressBar(value: 0, indeterminate: true, height: 6),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.s.preparingSession,
          style: TextStyle(color: AppColors.muted, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: AppColors.isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(AppRadii.sm + 2),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
