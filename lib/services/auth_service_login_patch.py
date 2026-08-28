import re

with open('lib/services/auth_service.dart', 'r') as f:
    content = f.read()

# Replace the login method's response handling block
old = """      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login',
          'email': email,
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (
          success: true,
          needsDeviceVerification: false,
          error: null,
          user: data['user'] as Map<String, dynamic>?,
        );
      }

      if (data['needsDeviceVerification'] == true) {
        return (
          success: false,
          needsDeviceVerification: true,
          error: null,
          user: null,
        );
      }

      return (
        success: false,
        needsDeviceVerification: false,
        error: data['error'] as String?,
        user: null,
      );
    } catch (e) {"""

new = """      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login',
          'email': email.toLowerCase().trim(),
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 15));

      // Debug: log raw response for troubleshooting
      print('[AuthService] login response: \\${response.statusCode} \\${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode != 200) {
        return (
          success: false,
          needsDeviceVerification: false,
          error: 'Server error (\\${response.statusCode}). Please try again.',
          user: null,
        );
      }

      final data = jsonDecode(response.body);

      // Handle success — check both boolean true and string 'true'
      final isSuccess = data['success'] == true || data['success'] == 'true';
      if (isSuccess) {
        final user = data['user'] as Map<String, dynamic>?;
        if (user == null) {
          return (
            success: false,
            needsDeviceVerification: false,
            error: 'Login succeeded but user data was missing. Please try again.',
            user: null,
          );
        }
        return (
          success: true,
          needsDeviceVerification: false,
          error: null,
          user: user,
        );
      }

      // Handle device verification — check both boolean true and string 'true'
      final needsVerification = data['needsDeviceVerification'] == true || data['needsDeviceVerification'] == 'true';
      if (needsVerification) {
        return (
          success: false,
          needsDeviceVerification: true,
          error: null,
          user: null,
        );
      }

      // Return the backend's error message, or a specific fallback
      final backendError = data['error'] as String?;
      return (
        success: false,
        needsDeviceVerification: false,
        error: backendError ?? 'Unable to login. Please check your details and try again.',
        user: null,
      );
    } catch (e) {"""

assert old in content, "Could not find the login method block to replace"
content = content.replace(old, new)

with open('lib/services/auth_service.dart', 'w') as f:
    f.write(content)
print("✓ Patched auth_service.dart login method")
