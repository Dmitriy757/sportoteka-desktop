import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player_profile_models.dart';

class PlayerTrackerField extends StatelessWidget {
  const PlayerTrackerField({super.key, required this.points});
  final List<PlayerProfilePoint> points;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: CustomPaint(painter: _PlayerTrackerFieldPainter(points), size: Size.infinite),
  );
}

class _PlayerTrackerFieldPainter extends CustomPainter {
  const _PlayerTrackerFieldPainter(this.points);
  final List<PlayerProfilePoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    final area = (Offset.zero & size).deflate(8);
    final pitch = _fitPitch(area);
    _drawAnalyticsPitch(canvas, pitch);
    if (points.isEmpty) return;
    var minX = points.first.x, maxX = points.first.x, minY = points.first.y, maxY = points.first.y;
    for (final p in points) { minX=math.min(minX,p.x); maxX=math.max(maxX,p.x); minY=math.min(minY,p.y); maxY=math.max(maxY,p.y); }
    final xSpan=math.max(0.000001,maxX-minX), ySpan=math.max(0.000001,maxY-minY);
    final routeArea=pitch.deflate(14);
    Offset position(PlayerProfilePoint p)=>Offset(routeArea.left+((p.x-minX)/xSpan)*routeArea.width, routeArea.bottom-((p.y-minY)/ySpan)*routeArea.height);
    final route=Path();
    for(var i=0;i<points.length;i++){final point=position(points[i]); if(i==0){route.moveTo(point.dx,point.dy);}else{route.lineTo(point.dx,point.dy);}}
    canvas.drawPath(route,Paint()..color=Colors.white.withOpacity(.95)..strokeWidth=2.4..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
    final pointPaint=Paint()..color=const Color(0xFFBFF5CE);
    for(final p in points){canvas.drawCircle(position(p),2.1,pointPaint);}
    canvas.drawCircle(position(points.last),5.4,Paint()..color=const Color(0xFFFFD84D));
    canvas.drawCircle(position(points.last),7.5,Paint()..color=Colors.white.withOpacity(.90)..style=PaintingStyle.stroke..strokeWidth=1.5);
  }
  Rect _fitPitch(Rect area){const aspectRatio=105/68; var width=area.width; var height=width/aspectRatio; if(height>area.height){height=area.height;width=height*aspectRatio;} return Rect.fromCenter(center:area.center,width:width,height:height);}
  void _drawAnalyticsPitch(Canvas canvas, Rect pitch){
    final roundedPitch=RRect.fromRectAndRadius(pitch,const Radius.circular(12));
    canvas.drawRRect(roundedPitch,Paint()..color=const Color(0xFF78977F));
    canvas.save(); canvas.clipRRect(roundedPitch); const stripeCount=12;
    for(var i=0;i<stripeCount;i++){canvas.drawRect(Rect.fromLTWH(pitch.left+pitch.width*i/stripeCount,pitch.top,pitch.width/stripeCount,pitch.height),Paint()..color=i.isEven?Colors.white.withOpacity(.055):Colors.black.withOpacity(.045));}
    canvas.restore();
    final inner=pitch.deflate(math.max(8.0,pitch.width*.016));
    final line=Paint()..color=Colors.white.withOpacity(.82)..style=PaintingStyle.stroke..strokeWidth=math.max(1.15,pitch.width*.0024);
    canvas.drawRRect(RRect.fromRectAndRadius(inner,const Radius.circular(8)),line);
    canvas.drawLine(Offset(inner.center.dx,inner.top),Offset(inner.center.dx,inner.bottom),line);
    canvas.drawCircle(inner.center,inner.height*.125,line);
    final penaltyWidth=inner.width*.175, penaltyHeight=inner.height*.46, goalWidth=inner.width*.078, goalHeight=inner.height*.23;
    canvas.drawRect(Rect.fromLTWH(inner.left,inner.center.dy-penaltyHeight/2,penaltyWidth,penaltyHeight),line);
    canvas.drawRect(Rect.fromLTWH(inner.right-penaltyWidth,inner.center.dy-penaltyHeight/2,penaltyWidth,penaltyHeight),line);
    canvas.drawRect(Rect.fromLTWH(inner.left,inner.center.dy-goalHeight/2,goalWidth,goalHeight),line);
    canvas.drawRect(Rect.fromLTWH(inner.right-goalWidth,inner.center.dy-goalHeight/2,goalWidth,goalHeight),line);
    final spotPaint=Paint()..color=Colors.white.withOpacity(.82);
    canvas.drawCircle(Offset(inner.left+inner.width*.115,inner.center.dy),math.max(1.8,inner.width*.0045),spotPaint);
    canvas.drawCircle(Offset(inner.right-inner.width*.115,inner.center.dy),math.max(1.8,inner.width*.0045),spotPaint);
  }
  @override bool shouldRepaint(covariant _PlayerTrackerFieldPainter oldDelegate)=>oldDelegate.points!=points;
}
