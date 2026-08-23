import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerOverviewSection extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final PlayerProfileSession? session;
  const PlayerOverviewSection({super.key, required this.data, this.session});
  int get attendancePercent {
    if (data.attendance.isEmpty) return 0;
    final present=data.attendance.where((e)=>'${e['status']}'.toLowerCase().contains('present')||'${e['status']}'.toLowerCase().contains('прис')).length;
    return (present/data.attendance.length*100).round();
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    LayoutBuilder(builder:(context,c){final w=(c.maxWidth-30)/4;return Wrap(spacing:10,runSpacing:10,children:[SizedBox(width:w,child:PpMetric(label:'Рейтинг',value:'${_rating()}',note:'Общий индекс')),SizedBox(width:w,child:PpMetric(label:'Готовность',value:'${_readiness()}%',note:'На сегодня')),SizedBox(width:w,child:PpMetric(label:'Посещаемость',value:'$attendancePercent%',note:'За период')),SizedBox(width:w,child:PpMetric(label:'Нагрузка',value:_loadLabel(),note:'GPS + Polar'))]);}),
    const SizedBox(height:14),
    _PhysicalMetrics(data:data),
    const SizedBox(height:14),
    LayoutBuilder(builder:(context,c){final split=c.maxWidth>=820;final left=_LatestActivity(session:session);final right=_StatusPanel(data:data);return split?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:left),const SizedBox(width:12),Expanded(child:right)]):Column(children:[left,const SizedBox(height:12),right]);}),
    const SizedBox(height:14),
    PpSurface(color:Colors.white,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PpSectionTitle(title:'История игрока',subtitle:'Тренировки, матчи, трекер и тестирование в одной ленте'),const SizedBox(height:10),if(data.timeline.isEmpty)const SizedBox(height:180,child:PpEmpty(title:'История пока пуста',text:'Записи появятся после тренировок, матчей и тестов'))else ...data.timeline.take(12).map((e)=>_TimelineRow(item:e))]))
  ]);
  int _rating()=>((_readiness()*.4)+(attendancePercent*.25)+(session==null?55:75)*.35).round();
  int _readiness()=>session==null?60:((session!.maxSpeedKmh>0?75:55)+(session!.avgHr>0?10:0)).clamp(0,100);
  String _loadLabel(){if(session==null)return 'Нет данных';if(session!.distanceM>5000)return 'Высокая';if(session!.distanceM>2500)return 'Средняя';return 'Низкая';}
}
class _LatestActivity extends StatelessWidget { final PlayerProfileSession? session; const _LatestActivity({this.session}); @override Widget build(BuildContext context)=>PpSurface(color:Colors.white,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PpSectionTitle(title:'Последняя активность',subtitle:'Последняя доступная сессия игрока'),const SizedBox(height:14),if(session==null)const SizedBox(height:160,child:PpEmpty(title:'Нет сессий',text:'После тренировки здесь появятся показатели'))else ...[Text(session!.title,style:PpText.title(14)),const SizedBox(height:5),Text(session!.date==null?'Без даты':DateFormat('dd.MM.yyyy HH:mm').format(session!.date!),style:PpText.body(10.8)),const SizedBox(height:16),Wrap(spacing:18,runSpacing:12,children:[_value('Дистанция','${(session!.distanceM/1000).toStringAsFixed(1)} км'),_value('Макс. скорость','${session!.maxSpeedKmh.toStringAsFixed(1)} км/ч'),_value('Спринты','${session!.sprintCount}'),_value('Пульс','${session!.avgHr.round()} / ${session!.maxHr.round()}')])]])); Widget _value(String l,String v)=>SizedBox(width:120,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(l,style:PpText.body(10.2)),const SizedBox(height:4),Text(v,style:PpText.value(14))])); }
class _StatusPanel extends StatelessWidget { final PlayerProfileSnapshot data; const _StatusPanel({required this.data}); @override Widget build(BuildContext context)=>PpSurface(color:Colors.white,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PpSectionTitle(title:'Состояние игрока',subtitle:'Доступность данных и ограничения'),const SizedBox(height:10),_row('GPS / BLE',data.sessions.isEmpty?'Нет данных':'Подключён'),_row('Polar',data.sessions.any((e)=>e.avgHr>0)?'Есть данные':'Нет данных'),_row('Медицинские записи',data.medical.isEmpty?'Нет':'${data.medical.length}'),_row('Матчи','${data.matches.length}') ])); Widget _row(String l,String v)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Expanded(child:Text(l,style:PpText.body(11.3,color:PpColors.text,weight:FontWeight.w500))),Text(v,style:PpText.body(11.3,weight:FontWeight.w600))])); }
class _TimelineRow extends StatelessWidget { final PlayerTimelineItem item; const _TimelineRow({required this.item}); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:PpColors.greenSoft,borderRadius:BorderRadius.circular(9)),child:Icon(item.icon,size:16,color:PpColors.green)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.title,style:PpText.body(11.8,color:PpColors.text,weight:FontWeight.w600)),if(item.subtitle.isNotEmpty)Text(item.subtitle,style:PpText.body(10.5))])),Text(item.date==null?'—':DateFormat('dd.MM').format(item.date!),style:PpText.body(10.5))])); }

class _PhysicalMetrics extends StatelessWidget {
  final PlayerProfileSnapshot data;
  const _PhysicalMetrics({required this.data});
  String _s(dynamic v)=>'${v??''}'.trim();
  String _v(dynamic v,String unit){final s=_s(v);return s.isEmpty||s=='null'?'—':'$s $unit';}
  @override Widget build(BuildContext context){final p=data.player;final h=double.tryParse(_s(p['height']).replaceAll(',','.'))??0;final w=double.tryParse(_s(p['weight']).replaceAll(',','.'))??0;final bmi=h>0&&w>0?(w/((h/100)*(h/100))).toStringAsFixed(1):'—';final maxSession=data.trackerMaxHrSession;final restSession=data.trackerRestHrSession;return PpSurface(color:Colors.white,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const PpSectionTitle(title:'Физические метрики',subtitle:'Антропометрия и фактические показатели Polar / трекера'),const SizedBox(height:12),Wrap(spacing:24,runSpacing:14,children:[_item('Рост',_v(p['height'],'см')),_item('Вес',_v(p['weight'],'кг')),_item('ИМТ',bmi),_item('Пульс покоя',restSession==null?'—':'${restSession.minHr.round()} уд/мин'),_item('HR max',maxSession==null?'—':'${maxSession.maxHr.round()} уд/мин')]) ]));}
  Widget _item(String l,String v)=>SizedBox(width:135,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(l,style:PpText.body(10.3)),const SizedBox(height:4),Text(v,style:PpText.value(14))]));
}
