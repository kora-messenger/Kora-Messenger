# Firebase Setup for Kora Messenger

## Steps to enable push notifications:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (or use existing)
3. Add an Android app with package name `com.kora.messenger`
4. Download `google-services.json` and place it in `android/app/`
5. Add the Google Services plugin to `android/build.gradle`:
   ```
   classpath 'com.google.gms:google-services:4.4.2'
   ```
6. Apply the plugin in `android/app/build.gradle`:
   ```
   apply plugin: 'com.google.gms.google-services'
   ```
7. Add Firebase Messaging dependency to `android/app/build.gradle`:
   ```
   implementation 'com.google.firebase:firebase-messaging:24.0.0'
   ```

## Server-side push payload format:

```json
{
  "to": "<FCM_TOKEN>",
  "data": {
    "type": "message",
    "chat_id": "user@example.com",
    "sender_name": "John Doe",
    "sender_jid": "john@example.com",
    "message": "Hello!",
    "timestamp": "1692873600000",
    "notification_id": "12345",
    "deep_link": "kora://chat/user@example.com"
  }
}
```

## Payload types:
- `message` — New 1-on-1 message
- `group_message` — New group message
- `call` — Incoming call
- `call_reject` — Call rejected
- `status` — Status update
- `channel_update` — Channel/community update
- `reaction` — Message reaction
- `security` — Security alert
- `reminder` — Draft/message reminder
