export interface NotificationRequest {
  room_id: string;
  user_id: string;
}

export interface UserRecord {
  id: string;
  name: string;
  fcm_token: string | null;
  is_notification_enabled: boolean;
}

export interface NotificationLog {
  created_at: string;
}
