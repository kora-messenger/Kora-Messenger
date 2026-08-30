import 'package:flutter/material.dart';
import '../theme/kora_colors.dart';
import '../models/message_model.dart';

/// Contact card widget — renders a vCard (contact card) inline in chat.
/// Shows the contact name, phone number, and an "Add to contacts" button.
/// Mirrors WhatsApp's contact card message display.
class ContactCardWidget extends StatelessWidget {
  final String contactName;
  final String? phoneNumber;
  final String? email;
  final String? avatarUrl;
  final bool isMe;
  final VoidCallback? onAddContact;

  const ContactCardWidget({
    super.key,
    required this.contactName,
    this.phoneNumber,
    this.email,
    this.avatarUrl,
    this.isMe = false,
    this.onAddContact,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = KoraColors.surfaceFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textMuted = KoraColors.textMutedFor(brightness);

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [KoraColors.purple, KoraColors.blue],
                  ),
                ),
                child: Center(
                  child: Text(
                    contactName.isNotEmpty
                        ? contactName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (phoneNumber != null)
                      Text(
                        phoneNumber!,
                        style: TextStyle(color: textMuted, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (email != null) ...[
            const SizedBox(height: 8),
            Text(email!, style: TextStyle(color: textMuted, fontSize: 12)),
          ],
          if (onAddContact != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddContact,
                icon: Icon(Icons.person_add_outlined, size: 16, color: KoraColors.purple),
                label: Text('Add to contacts',
                    style: TextStyle(color: KoraColors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: KoraColors.purple.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// vCard data — parsed from a vCard string or constructed manually.
class VCardData {
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String? organization;
  final String? avatarUrl;

  VCardData({
    required this.fullName,
    this.phoneNumber,
    this.email,
    this.organization,
    this.avatarUrl,
  });

  /// Parse a standard vCard (VCARD) string.
  factory VCardData.parse(String vcard) {
    String? name, phone, email, org;
    for (final line in vcard.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('FN:')) {
        name = trimmed.substring(3);
      } else if (trimmed.startsWith('TEL')) {
        phone = trimmed.split(':').last;
      } else if (trimmed.startsWith('EMAIL')) {
        email = trimmed.split(':').last;
      } else if (trimmed.startsWith('ORG:')) {
        org = trimmed.substring(4);
      }
    }
    return VCardData(
      fullName: name ?? 'Unknown',
      phoneNumber: phone,
      email: email,
      organization: org,
    );
  }

  /// Generate a vCard string.
  String toVCardString() {
    final buf = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:$fullName');
    if (phoneNumber != null) buf.writeln('TEL;TYPE=CELL:$phoneNumber');
    if (email != null) buf.writeln('EMAIL:$email');
    if (organization != null) buf.writeln('ORG:$organization');
    buf.writeln('END:VCARD');
    return buf.toString();
  }
}
