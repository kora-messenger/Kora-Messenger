import 'dart:convert';

/// Business profile data model.
class BusinessProfile {
  final String businessName;
  final String category;
  final String description;
  final String address;
  final String email;
  final List<String> websites;
  final String? coverPhotoPath;
  final String? profilePhotoPath;

  const BusinessProfile({
    this.businessName = '',
    this.category = '',
    this.description = '',
    this.address = '',
    this.email = '',
    this.websites = const [],
    this.coverPhotoPath,
    this.profilePhotoPath,
  });

  BusinessProfile copyWith({
    String? businessName, String? category, String? description,
    String? address, String? email, List<String>? websites,
    String? coverPhotoPath, String? profilePhotoPath,
  }) => BusinessProfile(
    businessName: businessName ?? this.businessName,
    category: category ?? this.category,
    description: description ?? this.description,
    address: address ?? this.address,
    email: email ?? this.email,
    websites: websites ?? this.websites,
    coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
    profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
  );

  Map<String, dynamic> toJson() => {
    'businessName': businessName, 'category': category, 'description': description,
    'address': address, 'email': email, 'websites': websites,
    'coverPhotoPath': coverPhotoPath, 'profilePhotoPath': profilePhotoPath,
  };

  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
    businessName: j['businessName'] ?? '', category: j['category'] ?? '',
    description: j['description'] ?? '', address: j['address'] ?? '',
    email: j['email'] ?? '', websites: (j['websites'] as List?)?.cast<String>() ?? [],
    coverPhotoPath: j['coverPhotoPath'], profilePhotoPath: j['profilePhotoPath'],
  );
}

/// Catalog product item.
class CatalogItem {
  final String id;
  final String name;
  final String description;
  final String price;
  final String? imagePath;
  final String? link;
  final bool isVisible;

  const CatalogItem({
    required this.id, this.name = '', this.description = '', this.price = '',
    this.imagePath, this.link, this.isVisible = true,
  });

  CatalogItem copyWith({String? name, String? description, String? price,
    String? imagePath, String? link, bool? isVisible}) => CatalogItem(
    id: id, name: name ?? this.name, description: description ?? this.description,
    price: price ?? this.price, imagePath: imagePath ?? this.imagePath,
    link: link ?? this.link, isVisible: isVisible ?? this.isVisible,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'description': description,
    'price': price, 'imagePath': imagePath, 'link': link, 'isVisible': isVisible};

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
    id: j['id'] ?? '', name: j['name'] ?? '', description: j['description'] ?? '',
    price: j['price'] ?? '', imagePath: j['imagePath'], link: j['link'],
    isVisible: j['isVisible'] ?? true,
  );
}

/// Quick reply / message template.
class MessageTemplate {
  final String shortcut;
  final String message;
  final List<String> variables;

  const MessageTemplate({this.shortcut = '', this.message = '', this.variables = const []});

  Map<String, dynamic> toJson() => {'shortcut': shortcut, 'message': message, 'variables': variables};
  factory MessageTemplate.fromJson(Map<String, dynamic> j) => MessageTemplate(
    shortcut: j['shortcut'] ?? '', message: j['message'] ?? '',
    variables: (j['variables'] as List?)?.cast<String>() ?? [],
  );
}

/// Away message settings.
class AwayMessageSettings {
  final bool enabled;
  final String message;
  final String schedule; // 'always', 'custom', 'outside_hours'
  final String recipients; // 'everyone', 'my_contacts'

  const AwayMessageSettings({this.enabled = false, this.message = '',
    this.schedule = 'always', this.recipients = 'everyone'});

  AwayMessageSettings copyWith({bool? enabled, String? message,
    String? schedule, String? recipients}) => AwayMessageSettings(
    enabled: enabled ?? this.enabled, message: message ?? this.message,
    schedule: schedule ?? this.schedule, recipients: recipients ?? this.recipients);

  Map<String, dynamic> toJson() => {'enabled': enabled, 'message': message,
    'schedule': schedule, 'recipients': recipients};
  factory AwayMessageSettings.fromJson(Map<String, dynamic> j) => AwayMessageSettings(
    enabled: j['enabled'] ?? false, message: j['message'] ?? '',
    schedule: j['schedule'] ?? 'always', recipients: j['recipients'] ?? 'everyone',
  );
}

/// Greeting message settings.
class GreetingMessageSettings {
  final bool enabled;
  final String message;
  final String recipients;

  const GreetingMessageSettings({this.enabled = false, this.message = '',
    this.recipients = 'everyone'});

  GreetingMessageSettings copyWith({bool? enabled, String? message,
    String? recipients}) => GreetingMessageSettings(
    enabled: enabled ?? this.enabled, message: message ?? this.message,
    recipients: recipients ?? this.recipients);

  Map<String, dynamic> toJson() => {'enabled': enabled, 'message': message, 'recipients': recipients};
  factory GreetingMessageSettings.fromJson(Map<String, dynamic> j) => GreetingMessageSettings(
    enabled: j['enabled'] ?? false, message: j['message'] ?? '',
    recipients: j['recipients'] ?? 'everyone',
  );
}

/// Color-coded label for organizing chats.
class BusinessLabel {
  final String id;
  final String name;
  final int colorIndex;

  const BusinessLabel({required this.id, this.name = '', this.colorIndex = 0});

  BusinessLabel copyWith({String? name, int? colorIndex}) =>
    BusinessLabel(id: id, name: name ?? this.name, colorIndex: colorIndex ?? this.colorIndex);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'colorIndex': colorIndex};
  factory BusinessLabel.fromJson(Map<String, dynamic> j) => BusinessLabel(
    id: j['id'] ?? '', name: j['name'] ?? '', colorIndex: j['colorIndex'] ?? 0,
  );
}

/// Single day schedule.
class DaySchedule {
  final bool isOpen;
  final String? openTime;
  final String? closeTime;

  const DaySchedule({this.isOpen = false, this.openTime, this.closeTime});

  DaySchedule copyWith({bool? isOpen, String? openTime, String? closeTime}) => DaySchedule(
    isOpen: isOpen ?? this.isOpen, openTime: openTime ?? this.openTime,
    closeTime: closeTime ?? this.closeTime,
  );

  Map<String, dynamic> toJson() => {'isOpen': isOpen, 'openTime': openTime, 'closeTime': closeTime};
  factory DaySchedule.fromJson(Map<String, dynamic> j) => DaySchedule(
    isOpen: j['isOpen'] ?? false, openTime: j['openTime'], closeTime: j['closeTime'],
  );
}

/// Weekly business hours.
class BusinessHoursSettings {
  final String mode; // 'selected', 'always_open', 'appointment'
  final List<DaySchedule> days; // 7 entries, Mon-Sun

  const BusinessHoursSettings({this.mode = 'selected', this.days = const []});

  BusinessHoursSettings copyWith({String? mode, List<DaySchedule>? days}) =>
    BusinessHoursSettings(mode: mode ?? this.mode, days: days ?? this.days);

  Map<String, dynamic> toJson() => {'mode': mode, 'days': days.map((d) => d.toJson()).toList()};
  factory BusinessHoursSettings.fromJson(Map<String, dynamic> j) => BusinessHoursSettings(
    mode: j['mode'] ?? 'selected',
    days: (j['days'] as List?)?.map((d) => DaySchedule.fromJson(d as Map<String, dynamic>)).toList() ?? [],
  );
}
