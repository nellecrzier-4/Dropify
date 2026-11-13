import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/pixeldrain_api.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/star_badge.dart';
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
          child: Stack(
            children: [
              Positioned(
                top: 4,
                right: 12,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: TextButton.icon(
                    key: ValueKey<String>(s.languageCode),
                    onPressed: _toggleLanguage,
                    icon: const Icon(Icons.translate, size: 18),
                    label: Text(
                      s.languageCode == 'id' ? 'English' : 'Bahasa',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      child: _checking
                          ? const _Checking(key: ValueKey('checking'))
                          : _form(context),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Entrance(
            delay: const Duration(milliseconds: 40),
            slide: 14,
            child: Breathing(
              child: StarBadge(icon: Icons.cloud_outlined, size: 164),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Entrance(
          delay: const Duration(milliseconds: 140),
          child: Text(
            s.loginTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Entrance(
          delay: const Duration(milliseconds: 210),
          child: Text(
            s.loginSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 34),
        Entrance(
          delay: const Duration(milliseconds: 280),
          child: TextField(
            controller: _userController,
            style: const TextStyle(color: AppColors.text),
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: s.usernameLabel,
              prefixIcon: const Icon(Icons.alternate_email, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Entrance(
          delay: const Duration(milliseconds: 340),
          child: TextField(
            controller: _passController,
            obscureText: _obscure,
            style: const TextStyle(color: AppColors.text),
            textInputAction:
                _showOtp ? TextInputAction.next : TextInputAction.done,
            decoration: InputDecoration(
              labelText: s.passwordLabel,
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
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
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: _showOtp
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextField(
                    controller: _totpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      labelText: s.otpLabel,
                      counterText: '',
                      prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                    ),
                    onSubmitted: (_) => _isLoading ? null : _handleLogin(),
                  ),
                )
              : const SizedBox.shrink(),
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
        const SizedBox(height: 26),
        Entrance(
          delay: const Duration(milliseconds: 400),
          child: PressScale(
            child: FilledButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(s.signIn, key: const ValueKey('label')),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: WaveProgressBar(
                    value: 0,
                    indeterminate: true,
                    height: 10,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 8),
        Entrance(
          delay: const Duration(milliseconds: 470),
          child: TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://pixeldrain.com/register'),
              mode: LaunchMode.externalApplication,
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.muted,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: Text(s.noAccount),
          ),
        ),
      ],
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
        const Breathing(child: StarBadge(icon: Icons.cloud_outlined, size: 170)),
        const SizedBox(height: 40),
        const WaveProgressBar(value: 0, indeterminate: true, height: 10),
        const SizedBox(height: 16),
        Text(
          context.s.preparingSession,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.danger.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
