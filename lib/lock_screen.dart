import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_lock.dart';

/// Màn khoá phủ lên terminal: mở khoá bằng sinh trắc học hoặc mã PIN,
/// hoặc tạo mã PIN lần đầu ([setup]) khi máy không có sinh trắc học.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.lock,
    required this.setup,
    required this.onUnlocked,
    required this.onLogout,
  });

  final AppLock lock;
  final bool setup;
  final VoidCallback onUnlocked;
  final void Function(String? error) onLogout;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  LockMethod? _method;
  String _label = '';
  bool _wentBackground = false;
  String _pin = '';
  String? _firstPin;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _usesSystemAuth => _method == LockMethod.biometric || _method == LockMethod.device;

  /// Hộp Face ID chỉ làm app `inactive`; chỉ hỏi lại khi thật sự đã ra nền rồi quay về.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _wentBackground = true;
    } else if (state == AppLifecycleState.resumed && _wentBackground) {
      _wentBackground = false;
      if (_usesSystemAuth) _authenticate();
    }
  }

  Future<void> _init() async {
    final method = widget.setup ? LockMethod.pin : await widget.lock.unlockMethod();
    final label = method == LockMethod.biometric ? await widget.lock.biometricLabel() : 'mật mã máy';
    if (!mounted) return;
    setState(() {
      _method = method;
      _label = label;
    });
    if (_usesSystemAuth) _authenticate();
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.lock.authenticate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) widget.onUnlocked();
  }

  void _digit(String d) {
    if (_busy || _pin.length >= AppLock.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == AppLock.pinLength) _submitPin();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submitPin() async {
    final pin = _pin;
    if (widget.setup) {
      if (_firstPin == null) {
        setState(() {
          _firstPin = pin;
          _pin = '';
        });
        return;
      }
      if (_firstPin != pin) {
        HapticFeedback.heavyImpact();
        setState(() {
          _firstPin = null;
          _pin = '';
          _error = 'Hai lần nhập không khớp, nhập lại.';
        });
        return;
      }
      setState(() => _busy = true);
      try {
        await widget.lock.setPin(pin);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _firstPin = null;
          _pin = '';
          _error = 'Không lưu được mã PIN, thử lại.';
        });
        return;
      }
      if (mounted) widget.onUnlocked();
      return;
    }

    setState(() => _busy = true);
    PinResult result;
    try {
      result = await widget.lock.verifyPin(pin);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _error = 'Không đọc được mã PIN, thử lại.';
      });
      return;
    }
    if (!mounted) return;
    switch (result) {
      case PinOk():
        widget.onUnlocked();
      case PinWrong(:final remaining):
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _pin = '';
          _error = 'Sai mã PIN, còn $remaining lần thử.';
        });
      case PinExhausted():
        widget.onLogout('Nhập sai mã PIN quá ${AppLock.maxPinAttempts} lần, đã đăng xuất.');
      case PinMissing():
        widget.onLogout('Không đọc được mã PIN đã lưu, đăng nhập lại.');
    }
  }

  String get _title {
    if (!widget.setup) return 'Terminal đang khoá';
    return _firstPin == null ? 'Tạo mã PIN ${AppLock.pinLength} số' : 'Nhập lại mã PIN';
  }

  @override
  Widget build(BuildContext context) {
    final method = _method;
    return Material(
      color: const Color(0xFF111214),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 40, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 12),
                  Text(_title, style: Theme.of(context).textTheme.titleLarge),
                  if (widget.setup) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Máy không có Face ID/vân tay. Mã PIN dùng để mở khoá app khi mở lại hoặc rời app quá 10 phút.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (method == null)
                    const CircularProgressIndicator()
                  else if (_usesSystemAuth)
                    FilledButton.icon(
                      onPressed: _busy ? null : _authenticate,
                      icon: Icon(_label == 'Face ID' ? Icons.face : Icons.fingerprint),
                      label: Text('Mở khoá bằng $_label'),
                    )
                  else if (method == LockMethod.pin)
                    _pinPad()
                  else
                    const Text(
                      'Máy không có Face ID, mật mã máy hay mã PIN. Đăng xuất để đăng nhập lại.',
                      textAlign: TextAlign.center,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFF87171)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => widget.onLogout(null), child: const Text('Đăng xuất')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinPad() {
    Widget key(Widget? child, VoidCallback? onTap) => SizedBox.square(
      dimension: 72,
      child: child == null
          ? null
          : InkResponse(
              onTap: onTap,
              radius: 36,
              child: Center(child: child),
            ),
    );
    Widget digit(String d) => key(Text(d, style: const TextStyle(fontSize: 28)), () => _digit(d));
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < AppLock.pinLength; i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white70),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) digit(d)]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [key(null, null), digit('0'), key(const Icon(Icons.backspace_outlined), _backspace)],
        ),
      ],
    );
  }
}
