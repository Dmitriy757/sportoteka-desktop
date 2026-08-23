import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'player_profile_ui.dart';

class PlayerLineChart extends StatelessWidget {
  final List<double> values;
  final String emptyText;
  const PlayerLineChart({super.key, required this.values, this.emptyText='Нет данных для графика'});
  @override Widget build(BuildContext context) => SizedBox(height: 150, child: values.length < 2 ? Center(child: Text(emptyText, style: PpText.body(11))) : CustomPaint(painter: _LinePainter(values)));
}
class _LinePainter extends CustomPainter {
  final List<double> values; const _LinePainter(this.values);
  @override void paint(Canvas canvas, Size size) {
    final grid=Paint()..color=PpColors.line..strokeWidth=1;
    for(int i=1;i<4;i++) canvas.drawLine(Offset(0,size.height*i/4),Offset(size.width,size.height*i/4),grid);
    final minV=values.reduce(math.min), maxV=values.reduce(math.max), span=maxV-minV==0?1:maxV-minV;
    final path=Path();
    for(int i=0;i<values.length;i++) { final x=size.width*i/(values.length-1); final y=size.height-(values[i]-minV)/span*size.height*.82-size.height*.09; if(i==0) path.moveTo(x,y); else path.lineTo(x,y); }
    canvas.drawPath(path,Paint()..color=PpColors.green..style=PaintingStyle.stroke..strokeWidth=2.2..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
  }
  @override bool shouldRepaint(covariant _LinePainter oldDelegate)=>oldDelegate.values!=values;
}
