// lib/presentation/club_workspace/cmr_medical_cabinet_panel.dart
// Sportoteka CMR: медицинский кабинет клуба.
// Документы хранятся через существующие /api/medical/* endpoints.
// Родительский доступ сюда намеренно не подключён автоматически.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

class CmrMedicalCabinetPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final List<Map<String, dynamic>> players;

  const CmrMedicalCabinetPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.teamName,
    required this.players,
  });

  @override
  State<CmrMedicalCabinetPanel> createState() => _CmrMedicalCabinetPanelState();
}

class _CmrMedicalCabinetPanelState extends State<CmrMedicalCabinetPanel> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _getUrl = '$_apiBase/medical/get_medical_records.php';
  static const String _addUrl = '$_apiBase/medical/add_record.php';
  static const String _updateUrl = '$_apiBase/medical/update_record.php';
  static const String _deleteUrl = '$_apiBase/medical/delete_medical_record.php';

  final TextEditingController _search = TextEditingController();
  final TextEditingController _type = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _comment = TextEditingController();

  int? _selectedPlayerId;
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];

  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool _editing = false;
  Map<String, dynamic>? _editingRecord;
  DateTime _recordDate = DateTime.now();
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    _selectInitialPlayer();
  }

  @override
  void didUpdateWidget(covariant CmrMedicalCabinetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId) {
      _records = <Map<String, dynamic>>[];
      _selectedPlayerId = null;
      _cancelEditor(refresh: false);
      _selectInitialPlayer();
      return;
    }
    if (_selectedPlayerId != null &&
        !_players.any((p) => _playerId(p) == _selectedPlayerId)) {
      _selectedPlayerId = null;
      _records = <Map<String, dynamic>>[];
      _selectInitialPlayer();
    } else if (_selectedPlayerId == null && _players.isNotEmpty) {
      _selectInitialPlayer();
    }
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    _type.dispose();
    _title.dispose();
    _value.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _s(dynamic value) {
    final v = '${value ?? ''}'.trim();
    return v == 'null' ? '' : v;
  }

  dynamic _decode(String body) {
    final clear = body.trim();
    final obj = clear.indexOf('{');
    final arr = clear.indexOf('[');
    final starts = <int>[obj, arr].where((e) => e >= 0).toList();
    if (starts.isEmpty) return <String, dynamic>{};
    final start = starts.reduce((a, b) => a < b ? a : b);
    return jsonDecode(clear.substring(start));
  }

  List<Map<String, dynamic>> get _players {
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final raw in widget.players) {
      final p = Map<String, dynamic>.from(raw);
      final id = _playerId(p);
      if (id <= 0 || seen.contains(id)) continue;
      seen.add(id);
      out.add(p);
    }
    out.sort((a, b) => _playerName(a).toLowerCase().compareTo(_playerName(b).toLowerCase()));
    return out;
  }

  int _playerId(Map<String, dynamic> p) =>
      _i(p['player_id'] ?? p['playerId'] ?? p['id']);

  int _userId(Map<String, dynamic> p) =>
      _i(p['user_id'] ?? p['userId'] ?? p['userID']);

  String _playerName(Map<String, dynamic> p) {
    final full = _s(p['full_name'] ?? p['fullName'] ?? p['name']);
    if (full.isNotEmpty) return full;
    final first = _s(p['first_name'] ?? p['firstName']);
    final last = _s(p['last_name'] ?? p['lastName']);
    final joined = '$last $first'.trim();
    return joined.isEmpty ? 'Игрок #${_playerId(p)}' : joined;
  }

  String _playerSubtitle(Map<String, dynamic> p) {
    final bits = <String>[];
    final number = _s(p['jersey_number'] ?? p['number'] ?? p['player_number']);
    final position = _s(p['position']);
    if (number.isNotEmpty) bits.add('№$number');
    if (position.isNotEmpty) bits.add(position);
    return bits.isEmpty ? widget.teamName : bits.join(' · ');
  }

  Map<String, dynamic>? get _selectedPlayer {
    final id = _selectedPlayerId;
    if (id == null) return null;
    for (final p in _players) {
      if (_playerId(p) == id) return p;
    }
    return null;
  }

  List<Map<String, dynamic>> get _filteredPlayers {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _players;
    return _players.where((p) {
      final hay = '${_playerName(p)} ${_playerSubtitle(p)}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _selectInitialPlayer() {
    final list = _players;
    if (list.isEmpty) return;
    _selectedPlayerId = _playerId(list.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRecords();
    });
  }

  Future<void> _selectPlayer(Map<String, dynamic> player) async {
    final id = _playerId(player);
    if (id <= 0 || id == _selectedPlayerId) return;
    setState(() {
      _selectedPlayerId = id;
      _records = <Map<String, dynamic>>[];
      _error = null;
    });
    _cancelEditor(refresh: false);
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    final player = _selectedPlayer;
    if (player == null) return;
    final userId = _userId(player);
    if (userId <= 0) {
      if (!mounted) return;
      setState(() {
        _records = <Map<String, dynamic>>[];
        _error = 'У игрока не найден user_id. Медицинские документы привязываются к аккаунту игрока.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(_getUrl).replace(queryParameters: {
        'user_id': '$userId',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = _decode(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final raw = data is Map
          ? (data['records'] ?? data['items'] ?? data['data'] ?? const [])
          : const [];
      final list = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      list.sort((a, b) => _s(b['date'] ?? b['created_at']).compareTo(_s(a['date'] ?? a['created_at'])));
      if (!mounted) return;
      setState(() {
        _records = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить медкабинет: $e';
      });
    }
  }

  void _startAdd() {
    _type.text = 'Справка';
    _title.clear();
    _value.clear();
    _comment.clear();
    _recordDate = DateTime.now();
    _pickedFile = null;
    setState(() {
      _editing = true;
      _editingRecord = null;
    });
  }

  void _startEdit(Map<String, dynamic> record) {
    _type.text = _s(record['type']);
    _title.text = _s(record['title']);
    _value.text = _s(record['value']);
    _comment.text = _s(record['comment']);
    _recordDate = DateTime.tryParse(_s(record['date'])) ?? DateTime.now();
    _pickedFile = null;
    setState(() {
      _editing = true;
      _editingRecord = Map<String, dynamic>.from(record);
    });
  }

  void _cancelEditor({bool refresh = true}) {
    _type.clear();
    _title.clear();
    _value.clear();
    _comment.clear();
    _pickedFile = null;
    _recordDate = DateTime.now();
    _editingRecord = null;
    _editing = false;
    if (refresh && mounted) setState(() {});
  }

  String _dateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _C.green),
        ),
        child: child!,
      ),
    );
    if (d != null && mounted) setState(() => _recordDate = d);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    setState(() => _pickedFile = result.files.first);
  }

  Future<void> _save() async {
    final player = _selectedPlayer;
    if (player == null) return;
    final userId = _userId(player);
    if (userId <= 0) {
      _toast('Не найден user_id игрока');
      return;
    }
    if (_title.text.trim().isEmpty && _value.text.trim().isEmpty) {
      _toast('Заполните название или описание документа');
      return;
    }

    setState(() => _saving = true);
    try {
      final edit = _editingRecord != null;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(edit ? _updateUrl : _addUrl),
      );
      if (edit) {
        request.fields['id'] = _s(_editingRecord?['id']);
      } else {
        request.fields['user_id'] = '$userId';
      }
      request.fields['type'] = _type.text.trim().isEmpty ? 'Документ' : _type.text.trim();
      request.fields['title'] = _title.text.trim();
      request.fields['value'] = _value.text.trim();
      request.fields['comment'] = _comment.text.trim();
      request.fields['date'] = _dateIso(_recordDate);
      request.fields['club_id'] = '${widget.clubId}';
      request.fields['team_id'] = '${widget.teamId}';
      request.fields['player_id'] = '${_playerId(player)}';

      final path = _pickedFile?.path;
      if (path != null && path.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          path,
          filename: _pickedFile?.name,
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      final data = _decode(body);
      final ok = streamed.statusCode >= 200 &&
          streamed.statusCode < 300 &&
          (!(data is Map) ||
              data['success'] == true ||
              data['status'] == 'success' ||
              (data['success'] == null && data['status'] == null));
      if (!ok) {
        throw Exception(data is Map
            ? _s(data['message'] ?? data['error']).isEmpty
                ? 'сервер отклонил сохранение'
                : _s(data['message'] ?? data['error'])
            : 'сервер отклонил сохранение');
      }

      _cancelEditor(refresh: false);
      await _loadRecords();
      _toast(edit ? 'Медицинская запись обновлена' : 'Документ добавлен');
    } catch (e) {
      _toast('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final id = _i(record['id']);
    if (id <= 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: Text(_s(record['title']).isEmpty
            ? 'Медицинская запись будет удалена.'
            : '«${_s(record['title'])}» будет удалён.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить', style: TextStyle(color: _C.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await http.post(Uri.parse(_deleteUrl), body: {
        'id': '$id',
        'record_id': '$id',
      }).timeout(const Duration(seconds: 15));
      final data = _decode(res.body);
      final ok = res.statusCode >= 200 &&
          res.statusCode < 300 &&
          (!(data is Map) ||
              data['success'] == true ||
              data['status'] == 'success' ||
              (data['success'] == null && data['status'] == null));
      if (!ok) {
        throw Exception(data is Map
            ? _s(data['message'] ?? data['error'])
            : 'ошибка сервера');
      }
      await _loadRecords();
      _toast('Документ удалён');
    } catch (e) {
      _toast('Не удалось удалить: $e');
    }
  }

  String _fileUrl(Map<String, dynamic> r) {
    var raw = _s(r['file_url'] ?? r['file'] ?? r['document_url'] ?? r['url']);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (!raw.startsWith('/')) raw = '/$raw';
    return 'https://sportotekaapp.ru$raw';
  }

  Future<void> _openAttachment(Map<String, dynamic> record) async {
    final url = _fileUrl(record);
    if (url.isEmpty) {
      _toast('К записи не прикреплён файл');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('Некорректная ссылка на документ');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _toast('Не удалось открыть документ');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 860;

    if (_players.isEmpty) {
      return const _EmptyMedical(
        title: 'Нет игроков',
        subtitle: 'Добавьте игроков в выбранную команду — после этого здесь появятся их медицинские документы.',
      );
    }

    return Container(
      color: _C.bg,
      child: compact ? _buildCompact() : _buildDesktop(),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
        SizedBox(width: 280, child: _buildPlayersPane()),
        const VerticalDivider(width: 1, thickness: 1, color: _C.line),
        Expanded(child: _buildRightPane()),
      ],
    );
  }

  Widget _buildCompact() {
    final selected = _selectedPlayer;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _C.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedPlayerId,
                    items: _players
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: _playerId(p),
                            child: Text(
                              _playerName(p),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _T.value(12.2),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final p = _players.firstWhere((x) => _playerId(x) == id);
                      _selectPlayer(p);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TinyButton(
                icon: Icons.add_rounded,
                label: 'Документ',
                primary: true,
                onTap: selected == null ? null : _startAdd,
              ),
            ],
          ),
        ),
        Expanded(child: _buildRightPane()),
      ],
    );
  }

  Widget _buildPlayersPane() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Медкабинет', style: _T.title(17)),
                const SizedBox(height: 3),
                Text(
                  '${widget.teamName} · ${_players.length} игроков',
                  style: _T.muted(10.8),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  style: _T.value(12),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Найти игрока',
                    hintStyle: _T.muted(11.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: _C.soft,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _C.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _C.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _C.greenBorder),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.line),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _filteredPlayers.length,
              itemBuilder: (_, index) {
                final p = _filteredPlayers[index];
                final selected = _playerId(p) == _selectedPlayerId;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Material(
                    color: selected ? _C.greenSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => _selectPlayer(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                        child: Row(
                          children: [
                            _InitialAvatar(name: _playerName(p), selected: selected),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _playerName(p),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _T.value(11.8),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _playerSubtitle(p),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _T.muted(9.8),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 17,
                              color: selected ? _C.green : _C.muted2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane() {
    final player = _selectedPlayer;
    if (player == null) {
      return const _EmptyMedical(
        title: 'Выберите игрока',
        subtitle: 'Справа появятся документы, осмотры, справки, травмы и рекомендации.',
      );
    }

    if (_editing) return _buildEditor(player);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _C.line)),
          ),
          child: Row(
            children: [
              _InitialAvatar(name: _playerName(player), selected: true, large: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_playerName(player), style: _T.title(16)),
                    const SizedBox(height: 2),
                    Text(
                      'Медицинские документы · ${_records.length}',
                      style: _T.muted(10.5),
                    ),
                  ],
                ),
              ),
              _TinyButton(
                icon: Icons.refresh_rounded,
                label: 'Обновить',
                onTap: _loading ? null : _loadRecords,
              ),
              const SizedBox(width: 6),
              _TinyButton(
                icon: Icons.add_rounded,
                label: 'Добавить',
                primary: true,
                onTap: _startAdd,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.green,
                  ),
                )
              : _error != null
                  ? _ErrorPane(message: _error!, onRetry: _loadRecords)
                  : _records.isEmpty
                      ? const _EmptyMedical(
                          title: 'Документов пока нет',
                          subtitle: 'Добавьте справку, осмотр, анализ, запись о травме, вакцинации или рекомендацию врача.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _MedicalRecordCard(
                            record: _records[i],
                            fileUrl: _fileUrl(_records[i]),
                            onOpen: () => _openAttachment(_records[i]),
                            onEdit: () => _startEdit(_records[i]),
                            onDelete: () => _delete(_records[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildEditor(Map<String, dynamic> player) {
    final edit = _editingRecord != null;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _C.line)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Назад',
                onPressed: _saving ? null : () => _cancelEditor(),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(edit ? 'Редактировать документ' : 'Новый документ', style: _T.title(16)),
                    const SizedBox(height: 2),
                    Text(_playerName(player), style: _T.muted(10.5)),
                  ],
                ),
              ),
              _TinyButton(
                icon: Icons.save_outlined,
                label: _saving ? 'Сохранение…' : 'Сохранить',
                primary: true,
                onTap: _saving ? null : _save,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Тип и дата'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final type in const [
                        'Справка',
                        'Осмотр',
                        'Травма',
                        'Вакцинация',
                        'Анализ',
                        'Рекомендация',
                        'Документ',
                      ])
                        ChoiceChip(
                          label: Text(type, style: _T.value(10.7)),
                          selected: _type.text.trim() == type,
                          selectedColor: _C.greenSoft,
                          side: BorderSide(
                            color: _type.text.trim() == type ? _C.greenBorder : _C.line,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (_) => setState(() => _type.text = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Input(
                          controller: _type,
                          label: 'Тип записи',
                          hint: 'Например, справка',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(9),
                          child: InputDecorator(
                            decoration: _inputDecoration('Дата'),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 16, color: _C.green),
                                const SizedBox(width: 8),
                                Text(_dateIso(_recordDate), style: _T.value(11.8)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Документ'),
                  const SizedBox(height: 8),
                  _Input(
                    controller: _title,
                    label: 'Название',
                    hint: 'Например, справка о допуске к тренировкам',
                  ),
                  const SizedBox(height: 10),
                  _Input(
                    controller: _value,
                    label: 'Описание / результат',
                    hint: 'Основная информация',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  _Input(
                    controller: _comment,
                    label: 'Комментарий',
                    hint: 'Дополнительная заметка',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Файл'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _C.soft,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _C.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 18, color: _C.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickedFile?.name ??
                                (_fileUrl(_editingRecord ?? const <String, dynamic>{}).isNotEmpty
                                    ? 'Текущий файл уже прикреплён'
                                    : 'Файл не выбран'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _T.muted(11.2),
                          ),
                        ),
                        _TinyButton(
                          icon: Icons.folder_open_outlined,
                          label: 'Выбрать',
                          onTap: _pickFile,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _C.greenSoft,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _C.greenBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 17, color: _C.greenDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Медицинские документы доступны сотрудникам клуба. Родительский доступ к ним не выдаётся автоматически.',
                            style: _T.muted(10.6).copyWith(color: _C.greenDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: _T.muted(10.8),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.greenBorder),
        ),
      );
}

class _C {
  static const Color bg = Color(0xFFFAFBFA);
  static const Color soft = Color(0xFFF5F7F5);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted2 = Color(0xFF6B7280);
  static const Color line = Color(0xFFE8ECE9);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color greenBorder = Color(0xFFD7F0E2);
  static const Color red = Color(0xFFD92D20);
}

class _T {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _C.text,
        height: 1.16,
      );

  static TextStyle value(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _C.text,
        height: 1.18,
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _C.muted2,
        height: 1.3,
      );
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final bool selected;
  final bool large;

  const _InitialAvatar({
    required this.name,
    required this.selected,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final letters = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e.substring(0, 1).toUpperCase())
        .join();
    final size = large ? 38.0 : 31.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _C.greenSoft : _C.soft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: selected ? _C.greenBorder : _C.line),
      ),
      child: Text(
        letters.isEmpty ? 'И' : letters,
        style: _T.value(large ? 11.8 : 10.5).copyWith(
          color: selected ? _C.greenDark : _C.muted2,
        ),
      ),
    );
  }
}

class _TinyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  const _TinyButton({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: primary ? _C.greenSoft : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: primary ? _C.greenBorder : _C.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: enabled
                    ? (primary ? _C.greenDark : _C.muted2)
                    : _C.muted2.withOpacity(.45),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: _T.value(10.6).copyWith(
                  color: enabled
                      ? (primary ? _C.greenDark : _C.text)
                      : _C.muted2.withOpacity(.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: _T.value(11.5));
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _Input({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: _T.value(11.8),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: _T.muted(10.8),
        hintStyle: _T.muted(11.2),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _C.greenBorder),
        ),
      ),
    );
  }
}

class _MedicalRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final String fileUrl;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicalRecordCard({
    required this.record,
    required this.fileUrl,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  String _s(dynamic value) {
    final v = '${value ?? ''}'.trim();
    return v == 'null' ? '' : v;
  }

  @override
  Widget build(BuildContext context) {
    final type = _s(record['type']).isEmpty ? 'Документ' : _s(record['type']);
    final title = _s(record['title']).isEmpty ? type : _s(record['title']);
    final value = _s(record['value']);
    final comment = _s(record['comment']);
    final date = _s(record['date'] ?? record['created_at']);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _C.greenSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.greenBorder),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 17,
              color: _C.greenDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.soft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(type, style: _T.muted(9.3)),
                    ),
                    const SizedBox(width: 6),
                    if (date.isNotEmpty) Text(date, style: _T.muted(9.5)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(title, style: _T.value(12.2)),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(value, style: _T.muted(10.7)),
                ],
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(comment, style: _T.muted(10.3)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (fileUrl.isNotEmpty)
            IconButton(
              tooltip: 'Открыть файл',
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: _C.greenDark),
            ),
          IconButton(
            tooltip: 'Редактировать',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: _C.muted2),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _C.red),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedical extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyMedical({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _C.greenSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.greenBorder),
                  ),
                  child: const Icon(
                    Icons.medical_information_outlined,
                    color: _C.greenDark,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 10),
                Text(title, textAlign: TextAlign.center, style: _T.title(15)),
                const SizedBox(height: 4),
                Text(subtitle, textAlign: TextAlign.center, style: _T.muted(11.2)),
              ],
            ),
          ),
        ),
      );
}

class _ErrorPane extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorPane({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center, style: _T.muted(11.5)),
              const SizedBox(height: 10),
              _TinyButton(
                icon: Icons.refresh_rounded,
                label: 'Повторить',
                onTap: () {
                  onRetry();
                },
              ),
            ],
          ),
        ),
      );
}
