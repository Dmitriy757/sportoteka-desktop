import 'dart:convert';
import 'package:http/http.dart' as http;

class AiWorkspaceAction {
  final String id,type,title,description,status;
  final bool requiresConfirmation;
  final Map<String,dynamic> payload,result;
  const AiWorkspaceAction({required this.id,required this.type,required this.title,required this.description,required this.status,required this.requiresConfirmation,required this.payload,required this.result});
  factory AiWorkspaceAction.fromMap(Map<String,dynamic> m)=>AiWorkspaceAction(id:'${m['id']??''}',type:'${m['type']??''}',title:'${m['title']??''}',description:'${m['description']??''}',status:'${m['status']??'pending'}',requiresConfirmation:m['requires_confirmation']!=false,payload:m['payload'] is Map?Map<String,dynamic>.from(m['payload']):{},result:m['result'] is Map?Map<String,dynamic>.from(m['result']):{});
  Map<String,dynamic> toJson()=>{'id':id,'type':type,'title':title,'description':description,'status':status,'requires_confirmation':requiresConfirmation,'payload':payload,'result':result};
}

class AiWorkspaceActionApi {
  static const endpoint='https://sportotekaapp.ru/api/ai/v1/assistant/action';
  static Future<Map<String,dynamic>> execute({required int clubId,required int userId,int? teamId,required AiWorkspaceAction action,required bool confirmed}) async {
    final r=await http.post(Uri.parse(endpoint),headers:{'Content-Type':'application/json; charset=utf-8'},body:jsonEncode({'club_id':clubId,'user_id':userId,if(teamId!=null)'team_id':teamId,'confirmed':confirmed,'action':action.toJson()})).timeout(const Duration(seconds:30));
    final data=jsonDecode(r.body);
    if(r.statusCode!=200||data is! Map) throw Exception('Action HTTP ${r.statusCode}');
    return Map<String,dynamic>.from(data);
  }
}
