import 'package:flutter/material.dart';

import 'package:sportoteka/core/staff_access/staff_access_service.dart';

class StaffKeyActivationScreen extends StatefulWidget {
  final int userId;

  const StaffKeyActivationScreen({
    super.key,
    required this.userId,
  });

  @override
  State<StaffKeyActivationScreen> createState() =>
      _StaffKeyActivationScreenState();
}

class _StaffKeyActivationScreenState extends State<StaffKeyActivationScreen> {
  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF067A46);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _line = Color(0xFFE9ECEA);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF667085);

  final TextEditingController _keyController = TextEditingController();

  bool _loading = true;
  bool _activating = false;
  String? _error;
  Map<String, dynamic> _state = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  int get _activeCount => int.tryParse('${_state['active_count'] ?? 0}') ?? 0;

  List<Map<String, dynamic>> get _pending {
    return StaffAccessService.accesses(_state).where((access) {
      return '${access['status']}' == 'pending' &&
          access['requires_activation'] == true &&
          access['expired'] != true;
    }).toList();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final state = await StaffAccessService.loadMyStatus(widget.userId);

    if (!mounted) return;

    setState(() {
      _state = state;
      _loading = false;
      if (state['success'] != true) {
        _error = '${state['message'] ?? 'Не удалось проверить доступ'}';
      }
    });
  }

  Future<void> _activate() async {
    final code = _keyController.text.trim();

    if (code.isEmpty) {
      setState(() => _error = 'Введите Staff Key');
      return;
    }

    setState(() {
      _activating = true;
      _error = null;
    });

    final result = await StaffAccessService.activate(
      userId: widget.userId,
      staffKey: code,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _activating = false;
        _error = '${result['message'] ?? 'Ключ не принят'}';
      });
      return;
    }

    _keyController.clear();
    await _load();

    if (!mounted) return;

    if (_pending.isEmpty) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _activating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Доступ активирован'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _activeCount > 0;

    return PopScope(
      canPop: canContinue,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F6),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 260,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _green,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _greenSoft,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.vpn_key_outlined,
                                    color: _greenDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Доступ к клубу',
                                        style: const TextStyle(
                                          color: _text,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Для сотрудника выпущен Staff Key',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_pending.isNotEmpty) ...[
                              Text(
                                _pending.length == 1
                                    ? 'Ожидает активации'
                                    : 'Ожидают активации',
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final access in _pending)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 7),
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: _greenSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 7,
                                        height: 7,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: _green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          '${access['club_name'] ?? 'Клуб'} · '
                                          '${access['role_title'] ?? 'Сотрудник'}',
                                          style: const TextStyle(
                                            color: _text,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _keyController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: 'Staff Key',
                                  hintText: 'STAFF-XXXX-XXXX-XXXX-XXXX',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _activating ? null : _activate,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: _green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: _activating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Активировать доступ'),
                                ),
                              ),
                            ] else ...[
                              Text(
                                canContinue
                                    ? 'Активных доступов: $_activeCount'
                                    : 'Нет доступного Staff Key',
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFD92D20),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (canContinue) ...[
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text(
                                  'Продолжить с активным доступом',
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
