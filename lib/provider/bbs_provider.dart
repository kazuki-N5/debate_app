// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'dart:async';
import 'dart:developer';
import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Models ---

class BbsRoomInfo {
  final String id;
  final String player1Id;
  final String theme;
  final String choice1;
  final String choice2;
  final bool hasPassword;
  final DateTime createdAt;

  BbsRoomInfo({
    required this.id,
    required this.player1Id,
    required this.theme,
    required this.choice1,
    required this.choice2,
    required this.hasPassword,
    required this.createdAt,
  });

  factory BbsRoomInfo.fromJson(Map<String, dynamic> json) {
    return BbsRoomInfo(
      id: json['id'],
      player1Id: json['player1_id'],
      theme: json['theme'] ?? '',
      choice1: json['choice1'] ?? '',
      choice2: json['choice2'] ?? '',
      hasPassword: json['has_password'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class BbsRoomState {
  final String? roomId;
  final String? challengerId;
  final String? player2Id;

  BbsRoomState({
    this.roomId,
    this.challengerId,
    this.player2Id,
  });

  BbsRoomState copyWith({
    String? roomId,
    String? challengerId,
    String? player2Id,
  }) {
    return BbsRoomState(
      roomId: roomId ?? this.roomId,
      challengerId: challengerId ?? this.challengerId,
      player2Id: player2Id ?? this.player2Id,
    );
  }
}

// --- Providers ---

final bbsListProvider = StateNotifierProvider<BbsListNotifier, List<BbsRoomInfo>>((ref) {
  return BbsListNotifier(ref);
});

class BbsListNotifier extends StateNotifier<List<BbsRoomInfo>> {
  final Ref ref;
  BbsListNotifier(this.ref) : super([]);

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> fetchRooms() async {
    try {
      final response = await supabase.rpc('get_bbs_rooms');
      if (response != null) {
        final List<dynamic> list = response as List<dynamic>;
        state = list.map((e) => BbsRoomInfo.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        state = [];
      }
    } catch (e) {
      log('fetchRooms error: $e');
      state = [];
    }
  }

  void addRoomLocally(BbsRoomInfo room) {
    // リストの一番下に追加
    state = [...state, room];
  }

  void removeRoomLocally(String roomId) {
    state = state.where((r) => r.id != roomId).toList();
  }
}

final bbsHostProvider = StateNotifierProvider<BbsHostNotifier, BbsRoomState?>((ref) {
  return BbsHostNotifier(ref);
});

class BbsHostNotifier extends StateNotifier<BbsRoomState?> {
  final Ref ref;
  RealtimeChannel? _subscription;

  BbsHostNotifier(this.ref) : super(null) {
    _checkExistingHostRoom();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> _checkExistingHostRoom() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final response = await supabase
          .from('rooms_v2')
          .select()
          .eq('player1_id', userId)
          .eq('is_bbs', true)
          .isFilter('player2_id', null)
          .maybeSingle();

      if (response != null) {
        state = BbsRoomState(
          roomId: response['id'],
          challengerId: response['challenger_id'],
        );
        _startListening(response['id']);
      }
    } catch (e) {
      log('checkExistingHostRoom error: $e');
    }
  }

  Future<String?> createRoom(String theme, String choice1, String choice2, String password) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return 'ユーザーが認証されていません';

    try {
      final response = await supabase.rpc('create_bbs_room', params: {
        'p_user_id': userId,
        'p_theme': theme,
        'p_choice1': choice1,
        'p_choice2': choice2,
        'p_password': password,
      });

      if (response['success'] == true) {
        final roomData = response['room'];
        final roomId = roomData['id'];
        state = BbsRoomState(roomId: roomId);
        
        // 作成した部屋を通信なしで即座にリストの一番下へ追加（Optimistic Update）
        // JSONキーをアプリのBbsRoomInfoに合わせて少し変換
        final newRoom = BbsRoomInfo(
          id: roomData['id'],
          player1Id: roomData['player1_id'],
          theme: roomData['current_theme'] ?? '',
          choice1: roomData['current_choice1'] ?? '',
          choice2: roomData['current_choice2'] ?? '',
          hasPassword: roomData['password'] != null && roomData['password'] != '',
          createdAt: DateTime.parse(roomData['created_at']),
        );
        ref.read(bbsListProvider.notifier).addRoomLocally(newRoom);

        _startListening(roomId);
        return null; // 成功
      } else {
        if (response['error'] == 'ALREADY_EXISTS') {
          return 'ALREADY_EXISTS';
        }
        return '作成に失敗しました: ${response['error']}';
      }
    } catch (e) {
      log('createRoom error: $e');
      return 'エラーが発生しました';
    }
  }

  Future<void> deleteRoom() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || state?.roomId == null) return;

    try {
      final response = await supabase.rpc('delete_bbs_room', params: {
        'p_room_id': state!.roomId,
        'p_user_id': userId,
      });

      if (response['success'] == true) {
        // リストから即座に削除
        ref.read(bbsListProvider.notifier).removeRoomLocally(state!.roomId!);
        _stopListening();
        state = null;
      }
    } catch (e) {
      log('deleteRoom error: $e');
    }
  }

  Future<void> approveChallenger(bool approve) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || state?.roomId == null) return;

    try {
      final response = await supabase.rpc('approve_bbs_room', params: {
        'p_room_id': state!.roomId,
        'p_user_id': userId,
        'p_approve': approve,
      });

      if (response['success'] == true) {
        if (approve) {
          _stopListening();
          state = state?.copyWith(player2Id: state?.challengerId, challengerId: null);
        } else {
          state = state?.copyWith(challengerId: null);
        }
      }
    } catch (e) {
      log('approveChallenger error: $e');
    }
  }

  void _startListening(String roomId) {
    _stopListening();
    _subscription = supabase
        .channel('bbs-host-$roomId')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'rooms_v2',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: roomId,
            ),
            callback: (payload) {
              final newData = payload.newRecord;
              state = BbsRoomState(
                roomId: newData['id'],
                challengerId: newData['challenger_id'],
                player2Id: newData['player2_id'],
              );
            })
        .subscribe();
  }

  void _stopListening() {
    if (_subscription != null) {
      supabase.removeChannel(_subscription!);
      _subscription = null;
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}


final bbsGuestProvider = StateNotifierProvider<BbsGuestNotifier, BbsRoomState?>((ref) {
  return BbsGuestNotifier(ref);
});

class BbsGuestNotifier extends StateNotifier<BbsRoomState?> {
  final Ref ref;
  RealtimeChannel? _subscription;

  BbsGuestNotifier(this.ref) : super(null) {
    _checkExistingGuestRoom();
  }

  SupabaseClient get supabase => ref.read(supabaseProvider);

  Future<void> _checkExistingGuestRoom() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final response = await supabase
          .from('rooms_v2')
          .select()
          .eq('challenger_id', userId)
          .eq('is_bbs', true)
          .isFilter('player2_id', null)
          .maybeSingle();

      if (response != null) {
        state = BbsRoomState(
          roomId: response['id'],
          challengerId: response['challenger_id'],
        );
        _startListening(response['id']);
      }
    } catch (e) {
      log('checkExistingGuestRoom error: $e');
    }
  }

  Future<String?> applyToRoom(String roomId, String password) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return 'ユーザーが認証されていません';

    try {
      final response = await supabase.rpc('apply_bbs_room', params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_password': password,
      });

      if (response['success'] == true) {
        state = BbsRoomState(roomId: roomId, challengerId: userId);
        _startListening(roomId);
        return null;
      } else {
        return '申し込みに失敗しました: ${response['error']}';
      }
    } catch (e) {
      log('applyToRoom error: $e');
      return 'エラーが発生しました';
    }
  }
  
  void clearState() {
    _stopListening();
    state = null;
  }

  void _startListening(String roomId) {
    _stopListening();
    final userId = ref.read(currentUserIdProvider);
    _subscription = supabase
        .channel('bbs-guest-$roomId')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'rooms_v2',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: roomId,
            ),
            callback: (payload) {
              final newData = payload.newRecord;
              final newChallengerId = newData['challenger_id'];
              final newPlayer2Id = newData['player2_id'];

              if (newPlayer2Id == userId) {
                // 承認された！
                state = BbsRoomState(roomId: roomId, challengerId: null, player2Id: userId);
                _stopListening();
              } else if (newChallengerId != userId && state?.challengerId == userId) {
                // 拒否された、または別の人がchallengerになった
                state = BbsRoomState(roomId: roomId, challengerId: null, player2Id: null);
                _stopListening();
              }
            })
        .subscribe();
  }

  void _stopListening() {
    if (_subscription != null) {
      supabase.removeChannel(_subscription!);
      _subscription = null;
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
