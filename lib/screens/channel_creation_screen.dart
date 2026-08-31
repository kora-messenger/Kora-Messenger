import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/kora_api.dart';

/// Channel Creation Screen — create a new broadcast channel.
/// Mirrors WhatsApp's channel creation flow.
///
/// Flow: name + description → privacy settings → create → success
class ChannelCreationScreen extends StatefulWidget {
  const ChannelCreationScreen({super.key});

  @override
  State<ChannelCreationScreen> createState() => _ChannelCreationScreenState();
}

class _ChannelCreationScreenState extends State<ChannelCreationScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  int _currentStep = 0;
  bool _isPrivate = true;
  bool _followersCanReact = true;
  bool _followersCanShare = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('New Channel',
            style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentStep < 2)
            TextButton(
              onPressed: _next,
              child: Text('Next', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600)),
            )
          else
            TextButton(
              onPressed: _create,
              child: Text('Create', style: TextStyle(color: KoraColors.purple, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _currentStep == 0
          ? _buildStep1(surface, textPrimary, textMuted)
          : _currentStep == 1
              ? _buildStep2(surface, textPrimary, textMuted)
              : _buildStep3(surface, textPrimary, textMuted),
    );
  }

  // Step 1: Channel name + description + icon
  Widget _buildStep1(Color surface, Color textPrimary, Color textMuted) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [KoraColors.purple.withValues(alpha: 0.2), KoraColors.blue.withValues(alpha: 0.15)]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_outlined, size: 36, color: KoraColors.purple),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Channel Name', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: TextStyle(color: textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter channel name',
              hintStyle: TextStyle(color: textMuted),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              counterText: '',
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 16),
          Text('Description (optional)', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            style: TextStyle(color: textPrimary, fontSize: 16),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tell people what this channel is about',
              hintStyle: TextStyle(color: textMuted),
              filled: true,
              fillColor: surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KoraColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: KoraColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Channels are a one-way broadcast tool. Only admins can post. Followers can react and share.',
                    style: TextStyle(color: KoraColors.purple, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Privacy settings
  Widget _buildStep2(Color surface, Color textPrimary, Color textMuted) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Channel Privacy', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Choose who can find and follow your channel',
            style: TextStyle(color: textMuted, fontSize: 14)),
        const SizedBox(height: 24),
        // Private option
        GestureDetector(
          onTap: () => setState(() => _isPrivate = true),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isPrivate ? KoraColors.purple : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: _isPrivate ? KoraColors.purple : textMuted, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Private Channel', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('Only people with the invite link can follow', style: TextStyle(color: textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(_isPrivate ? Icons.radio_button_checked : Icons.radio_button_off, color: _isPrivate ? KoraColors.purple : textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Public option
        GestureDetector(
          onTap: () => setState(() => _isPrivate = false),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: !_isPrivate ? KoraColors.purple : Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.public, color: !_isPrivate ? KoraColors.purple : textMuted, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Public Channel', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('Anyone can find and follow your channel', style: TextStyle(color: textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(!_isPrivate ? Icons.radio_button_checked : Icons.radio_button_off, color: !_isPrivate ? KoraColors.purple : textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Step 3: Review & create
  Widget _buildStep3(Color surface, Color textPrimary, Color textMuted) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [KoraColors.purple, KoraColors.blue]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(_nameController.text.isEmpty ? 'Channel' : _nameController.text,
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(_isPrivate ? 'Private Channel' : 'Public Channel',
              style: TextStyle(color: textMuted, fontSize: 14)),
        ),
        if (_descController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(_descController.text, style: TextStyle(color: textMuted, fontSize: 14),
                textAlign: TextAlign.center),
          ),
        ],
        const SizedBox(height: 32),
        Text('Settings', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text('Allow reactions', style: TextStyle(color: textPrimary, fontSize: 15)),
          subtitle: Text('Followers can react to posts', style: TextStyle(color: textMuted, fontSize: 13)),
          value: _followersCanReact,
          onChanged: (v) => setState(() => _followersCanReact = v),
          activeColor: KoraColors.purple,
        ),
        SwitchListTile(
          title: Text('Allow sharing', style: TextStyle(color: textPrimary, fontSize: 15)),
          subtitle: Text('Followers can share channel posts', style: TextStyle(color: textMuted, fontSize: 13)),
          value: _followersCanShare,
          onChanged: (v) => setState(() => _followersCanShare = v),
          activeColor: KoraColors.purple,
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.parse(KoraApi.channelsGuidelinesUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Text(
              'Read our Channels Guidelines',
              style: TextStyle(
                color: KoraColors.purple,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _next() {
    if (_currentStep == 0 && _nameController.text.trim().isEmpty) return;
    setState(() => _currentStep++);
  }

  void _create() {
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'isPrivate': _isPrivate,
      'canReact': _followersCanReact,
      'canShare': _followersCanShare,
    });
  }
}

