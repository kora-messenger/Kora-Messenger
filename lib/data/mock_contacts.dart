/// Shared mock Kora contacts — used by the New Group flow until the
/// real contacts/connections backend is wired up.
///
/// `recent: true` marks contacts the user has messaged recently (shown
/// under "RECENT" in the picker). `premium: true` marks Kora Premium
/// subscribers, who get a blue Premium badge on their avatar.
final List<Map<String, Object>> koraMockContacts = [
  {'name': 'Amara Chukwu', 'koraId': 'KM-830192746', 'username': '@amara_c', 'recent': true, 'premium': false},
  {'name': 'David Okoro', 'koraId': 'KM-471038291', 'username': '@davido', 'recent': true, 'premium': true},
  {'name': 'Grace Adeyemi', 'koraId': 'KM-205918374', 'username': '@grace_a', 'recent': true, 'premium': false},
  {'name': 'Emeka Nwosu', 'koraId': 'KM-673920184', 'username': '@emeka_n', 'recent': false, 'premium': false},
  {'name': 'Chidi Okafor', 'koraId': 'KM-918273645', 'username': '@chidi_o', 'recent': false, 'premium': false},
  {'name': 'Fatima Bello', 'koraId': 'KM-384756102', 'username': '@fatima_b', 'recent': false, 'premium': false},
  {'name': 'Tunde Bakare', 'koraId': 'KM-561029384', 'username': '@tunde_b', 'recent': false, 'premium': false},
  {'name': 'Ngozi Eze', 'koraId': 'KM-728394016', 'username': '@ngozi_e', 'recent': false, 'premium': false},
  {'name': 'Kola Adekunle', 'koraId': 'KM-193847562', 'username': '@kola_a', 'recent': false, 'premium': true},
  {'name': 'Zainab Ibrahim', 'koraId': 'KM-640192837', 'username': '@zainab_i', 'recent': false, 'premium': false},
];
