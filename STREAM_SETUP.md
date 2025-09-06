# Stream Chat Setup Instructions

## Getting Your Stream API Key

1. **Create a Stream Account**
   - Go to [getstream.io](https://getstream.io)
   - Sign up for a free account

2. **Create a New App**
   - In the Stream Dashboard, create a new app
   - Choose "Chat" as the product
   - Select your preferred region

3. **Get Your API Key**
   - In your app dashboard, go to "Overview"
   - Copy your "Key" (API Key)

4. **Update the Code**
   - Open `lib/services/stream_service.dart`
   - Replace `YOUR_STREAM_API_KEY` with your actual API key:
   ```dart
   static const String _apiKey = 'your_actual_api_key_here';
   ```

## Development vs Production

**Current Setup (Development):**
- Uses development tokens (automatically generated)
- Perfect for testing and development
- No backend required

**For Production:**
- You'll need to generate user tokens on your backend
- Replace the `devToken` with proper JWT tokens
- See Stream's documentation for backend integration

## Features Implemented

✅ **Chat Channels**: Join and participate in group chats
✅ **Real-time Messaging**: Send and receive messages instantly
✅ **File Attachments**: Send images and videos with compression
✅ **User Avatars**: Display user profile pictures
✅ **Unread Counts**: See unread message indicators
✅ **Message Types**: Support for text, images, videos, and files
✅ **Typing Indicators**: See when others are typing
✅ **Video Compression**: Automatic video compression for better performance
✅ **Cloud Functions Integration**: Support for backend token generation

## Usage

1. **Login**: Use Google Sign-In to authenticate
2. **Chat**: View your joined events/channels
3. **Send Messages**: Text, images, and videos with attachment picker
4. **Video Sharing**: Automatic compression for videos up to 100MB
5. **Navigate**: Use the bottom navigation to switch between Home, Chat, and Profile

## Backend Integration

The app supports both development and production modes:
- **Development**: Uses Stream dev tokens (no backend required)
- **Production**: Falls back to dev tokens if cloud function fails

Your RumiTalk app is now ready with full chat functionality! 🚀
