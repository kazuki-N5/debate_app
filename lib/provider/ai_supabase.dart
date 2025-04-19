import 'package:debate_project/main.dart';

class chat_with_ai {
  


   Future<void> gemini (String my_Id, String roomId,String theme,bool player1_choice)async{
    print('gemini');
     try {
      await supabase.functions.invoke(
        'gemini',
        body: {'my_id': my_Id, 'room_id': roomId,'theme':theme,'player1_choice':player1_choice },
      );
      return;
    } catch (e) {
      print('error occurred');
    }
  }

  
}
