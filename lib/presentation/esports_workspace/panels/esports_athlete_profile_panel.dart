import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

enum EsportsAthleteProfileTab { overview, matches, stats, video, ai, documents }

class EsportsAthleteProfilePanel extends StatefulWidget {
  final Map<String, dynamic> athlete;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> recordings;
  final List<Map<String, dynamic>> reports;

  const EsportsAthleteProfilePanel({
    super.key,
    required this.athlete,
    required this.matches,
    required this.recordings,
    required this.reports,
  });

  @override
  State<EsportsAthleteProfilePanel> createState() => _EsportsAthleteProfilePanelState();
}

class _EsportsAthleteProfilePanelState extends State<EsportsAthleteProfilePanel> {
  EsportsAthleteProfileTab _tab = EsportsAthleteProfileTab.overview;

  int get _athleteId => esportsInt(widget.athlete['id'] ?? widget.athlete['player_id']);
  String get _tag {
    final value = esportsText(widget.athlete['gamer_tag'] ?? widget.athlete['nickname']);
    if (value.isNotEmpty) return value;
    final full = '${esportsText(widget.athlete['first_name'])} ${esportsText(widget.athlete['last_name'])}'.trim();
    return full.isEmpty ? 'Киберспортсмен' : full;
  }
  String get _name => '${esportsText(widget.athlete['first_name'])} ${esportsText(widget.athlete['last_name'])}'.trim();

  List<Map<String, dynamic>> get _matches => widget.matches.where((m) {
    final id = esportsInt(m['player_id'] ?? m['athlete_id']);
    if (id > 0) return id == _athleteId;
    final ids = m['player_ids'];
    if (ids is List) return ids.any((e) => esportsInt(e) == _athleteId);
    return true;
  }).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: EsportsAthleteProfileTab.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (_, index) {
              final tab = EsportsAthleteProfileTab.values[index];
              final active = tab == _tab;
              return InkWell(
                onTap: () => setState(() => _tab = tab),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: active ? EsportsColors.greenSoft : EsportsColors.soft, borderRadius: BorderRadius.circular(10)),
                  child: Text(_tabTitle(tab), style: AppTypography.custom(size: 10.5, weight: active ? FontWeight.w600 : FontWeight.w500, color: active ? EsportsColors.greenDark : EsportsColors.muted)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _content(),
      ],
    );
  }

  Widget _header() {
    final rating = esportsInt(widget.athlete['rating']);
    return Row(children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.sports_esports_rounded, color: EsportsColors.greenDark, size: 29)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_tag, style: AppTypography.custom(size: 21, weight: FontWeight.w600, color: EsportsColors.text)),
        if (_name.isNotEmpty && _name != _tag) ...[const SizedBox(height: 3), Text(_name, style: AppTypography.captionMedium(color: EsportsColors.muted))],
        const SizedBox(height: 4),
        Text([esportsText(widget.athlete['game_title'] ?? widget.athlete['game']), esportsText(widget.athlete['platform']), if (rating > 0) 'Рейтинг $rating'].where((e) => e.isNotEmpty).join(' · '), style: AppTypography.captionMedium(color: EsportsColors.muted)),
      ])),
      const EsportsStatusPill(label: 'Esports', active: true),
    ]);
  }

  Widget _content() => switch (_tab) {
    EsportsAthleteProfileTab.overview => _overview(),
    EsportsAthleteProfileTab.matches => _matchesTab(),
    EsportsAthleteProfileTab.stats => _stats(),
    EsportsAthleteProfileTab.video => _simpleList(widget.recordings, Icons.video_library_outlined, 'Записей пока нет'),
    EsportsAthleteProfileTab.ai => _simpleList(widget.reports, Icons.auto_awesome_rounded, 'AI-отчётов пока нет'),
    EsportsAthleteProfileTab.documents => const EsportsEmptyState(icon: Icons.description_outlined, title: 'Документы', text: 'Здесь будут договоры, регламенты, заметки тренера и экспортированные AI-отчёты.'),
  };

  Widget _overview() {
    return Column(children: [
      Row(children: [
        Expanded(child: _metric(esportsText(widget.athlete['rank']).isEmpty ? '—' : esportsText(widget.athlete['rank']), 'Ранг')),
        const SizedBox(width: 8),
        Expanded(child: _metric(esportsText(widget.athlete['region']).isEmpty ? '—' : esportsText(widget.athlete['region']), 'Регион')),
        const SizedBox(width: 8),
        Expanded(child: _metric(esportsText(widget.athlete['team_role']).isEmpty ? '—' : esportsText(widget.athlete['team_role']), 'Роль')),
      ]),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(13), decoration: esportsCardDecoration(radius: 12), child: Column(children: [
        _line('Игровой ID', esportsText(widget.athlete['game_account_id'] ?? widget.athlete['game_id'])),
        _line('Режим', esportsText(widget.athlete['game_mode'] ?? widget.athlete['mode'])),
        _line('Email', esportsText(widget.athlete['email'])),
      ])),
    ]);
  }

  Widget _matchesTab() {
    if (_matches.isEmpty) return const EsportsEmptyState(icon: Icons.stadium_outlined, title: 'Матчей пока нет', text: 'Игровая история киберспортсмена появится после первых матчей.');
    return Container(padding: const EdgeInsets.all(13), decoration: esportsCardDecoration(radius: 12), child: Column(children: [for (var i=0;i<_matches.length;i++) ...[
      Row(children: [
        const Icon(Icons.stadium_outlined, size: 19, color: EsportsColors.greenDark),
        const SizedBox(width: 8),
        Expanded(child: Text(esportsText(_matches[i]['title'] ?? _matches[i]['opponent']).isEmpty ? 'Матч' : esportsText(_matches[i]['title'] ?? _matches[i]['opponent']), style: AppTypography.action(color: EsportsColors.text))),
        Text(esportsText(_matches[i]['score']), style: AppTypography.action(color: EsportsColors.text)),
      ]),
      if (i != _matches.length-1) const Divider(height: 18, color: EsportsColors.line),
    ]]));
  }

  Widget _stats() {
    int wins=0, draws=0, losses=0;
    for (final m in _matches) {
      final r=esportsText(m['result']).toUpperCase();
      if (r=='W'||r=='WIN') wins++;
      if (r=='D'||r=='DRAW') draws++;
      if (r=='L'||r=='LOSS') losses++;
    }
    final total=wins+draws+losses;
    final rate=total==0?0:(wins/total*100).round();
    return Column(children: [
      Row(children: [Expanded(child:_metric('$rate%','Win Rate')),const SizedBox(width:8),Expanded(child:_metric('$wins','Победы')),const SizedBox(width:8),Expanded(child:_metric('$total','Матчи'))]),
      const SizedBox(height:10),
      Container(padding: const EdgeInsets.all(13), decoration: esportsCardDecoration(radius:12), child: Wrap(spacing:8,runSpacing:8,children:['W/D/L','Голы / матч','xG','Владение','Удары','Передачи','Формации'].map((t)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:EsportsColors.soft,borderRadius:BorderRadius.circular(99)),child:Text(t,style:AppTypography.captionMedium(color:EsportsColors.text)))).toList())),
    ]);
  }

  Widget _simpleList(List<Map<String,dynamic>> items, IconData icon, String empty) {
    if (items.isEmpty) return EsportsEmptyState(icon: icon, title: empty, text: 'Данные будут автоматически привязываться к профилю киберспортсмена.');
    return Container(padding: const EdgeInsets.all(13), decoration: esportsCardDecoration(radius:12), child: Column(children:[for(var i=0;i<items.length;i++) ...[
      Row(children:[Icon(icon,size:19,color:EsportsColors.greenDark),const SizedBox(width:8),Expanded(child:Text(esportsText(items[i]['title'] ?? items[i]['match_title']).isEmpty?'Материал':esportsText(items[i]['title'] ?? items[i]['match_title']),style:AppTypography.action(color:EsportsColors.text)))]),
      if(i!=items.length-1) const Divider(height:18,color:EsportsColors.line),
    ]]));
  }

  Widget _metric(String value,String label)=>Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:EsportsColors.soft,borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:AppTypography.action(color:EsportsColors.text)),const SizedBox(height:3),Text(label,style:AppTypography.captionMedium(color:EsportsColors.muted))]));
  Widget _line(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[SizedBox(width:110,child:Text(label,style:AppTypography.captionMedium(color:EsportsColors.muted))),Expanded(child:Text(value.isEmpty?'—':value,textAlign:TextAlign.right,style:AppTypography.action(color:EsportsColors.text)))]));
  String _tabTitle(EsportsAthleteProfileTab t)=>switch(t){EsportsAthleteProfileTab.overview=>'Обзор',EsportsAthleteProfileTab.matches=>'Матчи',EsportsAthleteProfileTab.stats=>'Статистика',EsportsAthleteProfileTab.video=>'Видео',EsportsAthleteProfileTab.ai=>'ИИ',EsportsAthleteProfileTab.documents=>'Документы'};
}
