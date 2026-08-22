import 'package:flutter/material.dart';
import '../../theme/kora_colors.dart';

/// A country entry for the country picker.
class CountryInfo {
  final String name;
  final String iso;
  final String dialCode;
  final String flagEmoji;

  const CountryInfo({
    required this.name,
    required this.iso,
    required this.dialCode,
    required this.flagEmoji,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryInfo && runtimeType == other.runtimeType && iso == other.iso;

  @override
  int get hashCode => iso.hashCode;
}

/// All countries from A to Z with dial codes and flag emojis.
const List<CountryInfo> allCountries = [
  CountryInfo(name: 'Afghanistan', iso: 'AF', dialCode: '+93', flagEmoji: '🇦🇫'),
  CountryInfo(name: 'Albania', iso: 'AL', dialCode: '+355', flagEmoji: '🇦🇱'),
  CountryInfo(name: 'Algeria', iso: 'DZ', dialCode: '+213', flagEmoji: '🇩🇿'),
  CountryInfo(name: 'Andorra', iso: 'AD', dialCode: '+376', flagEmoji: '🇦🇩'),
  CountryInfo(name: 'Angola', iso: 'AO', dialCode: '+244', flagEmoji: '🇦🇴'),
  CountryInfo(name: 'Antigua and Barbuda', iso: 'AG', dialCode: '+1', flagEmoji: '🇦🇬'),
  CountryInfo(name: 'Argentina', iso: 'AR', dialCode: '+54', flagEmoji: '🇦🇷'),
  CountryInfo(name: 'Armenia', iso: 'AM', dialCode: '+374', flagEmoji: '🇦🇲'),
  CountryInfo(name: 'Australia', iso: 'AU', dialCode: '+61', flagEmoji: '🇦🇺'),
  CountryInfo(name: 'Austria', iso: 'AT', dialCode: '+43', flagEmoji: '🇦🇹'),
  CountryInfo(name: 'Azerbaijan', iso: 'AZ', dialCode: '+994', flagEmoji: '🇦🇿'),
  CountryInfo(name: 'Bahamas', iso: 'BS', dialCode: '+1', flagEmoji: '🇧🇸'),
  CountryInfo(name: 'Bahrain', iso: 'BH', dialCode: '+973', flagEmoji: '🇧🇭'),
  CountryInfo(name: 'Bangladesh', iso: 'BD', dialCode: '+880', flagEmoji: '🇧🇩'),
  CountryInfo(name: 'Barbados', iso: 'BB', dialCode: '+1', flagEmoji: '🇧🇧'),
  CountryInfo(name: 'Belarus', iso: 'BY', dialCode: '+375', flagEmoji: '🇧🇾'),
  CountryInfo(name: 'Belgium', iso: 'BE', dialCode: '+32', flagEmoji: '🇧🇪'),
  CountryInfo(name: 'Belize', iso: 'BZ', dialCode: '+501', flagEmoji: '🇧🇿'),
  CountryInfo(name: 'Benin', iso: 'BJ', dialCode: '+229', flagEmoji: '🇧🇯'),
  CountryInfo(name: 'Bhutan', iso: 'BT', dialCode: '+975', flagEmoji: '🇧🇹'),
  CountryInfo(name: 'Bolivia', iso: 'BO', dialCode: '+591', flagEmoji: '🇧🇴'),
  CountryInfo(name: 'Bosnia and Herzegovina', iso: 'BA', dialCode: '+387', flagEmoji: '🇧🇦'),
  CountryInfo(name: 'Botswana', iso: 'BW', dialCode: '+267', flagEmoji: '🇧🇼'),
  CountryInfo(name: 'Brazil', iso: 'BR', dialCode: '+55', flagEmoji: '🇧🇷'),
  CountryInfo(name: 'Brunei', iso: 'BN', dialCode: '+673', flagEmoji: '🇧🇳'),
  CountryInfo(name: 'Bulgaria', iso: 'BG', dialCode: '+359', flagEmoji: '🇧🇬'),
  CountryInfo(name: 'Burkina Faso', iso: 'BF', dialCode: '+226', flagEmoji: '🇧🇫'),
  CountryInfo(name: 'Burundi', iso: 'BI', dialCode: '+257', flagEmoji: '🇧🇮'),
  CountryInfo(name: 'Cabo Verde', iso: 'CV', dialCode: '+238', flagEmoji: '🇨🇻'),
  CountryInfo(name: 'Cambodia', iso: 'KH', dialCode: '+855', flagEmoji: '🇰🇭'),
  CountryInfo(name: 'Cameroon', iso: 'CM', dialCode: '+237', flagEmoji: '🇨🇲'),
  CountryInfo(name: 'Canada', iso: 'CA', dialCode: '+1', flagEmoji: '🇨🇦'),
  CountryInfo(name: 'Central African Republic', iso: 'CF', dialCode: '+236', flagEmoji: '🇨🇫'),
  CountryInfo(name: 'Chad', iso: 'TD', dialCode: '+235', flagEmoji: '🇹🇩'),
  CountryInfo(name: 'Chile', iso: 'CL', dialCode: '+56', flagEmoji: '🇨🇱'),
  CountryInfo(name: 'China', iso: 'CN', dialCode: '+86', flagEmoji: '🇨🇳'),
  CountryInfo(name: 'Colombia', iso: 'CO', dialCode: '+57', flagEmoji: '🇨🇴'),
  CountryInfo(name: 'Comoros', iso: 'KM', dialCode: '+269', flagEmoji: '🇰🇲'),
  CountryInfo(name: 'Congo', iso: 'CG', dialCode: '+242', flagEmoji: '🇨🇬'),
  CountryInfo(name: 'Congo (DRC)', iso: 'CD', dialCode: '+243', flagEmoji: '🇨🇩'),
  CountryInfo(name: 'Costa Rica', iso: 'CR', dialCode: '+506', flagEmoji: '🇨🇷'),
  CountryInfo(name: 'Croatia', iso: 'HR', dialCode: '+385', flagEmoji: '🇭🇷'),
  CountryInfo(name: 'Cuba', iso: 'CU', dialCode: '+53', flagEmoji: '🇨🇺'),
  CountryInfo(name: 'Cyprus', iso: 'CY', dialCode: '+357', flagEmoji: '🇨🇾'),
  CountryInfo(name: 'Czech Republic', iso: 'CZ', dialCode: '+420', flagEmoji: '🇨🇿'),
  CountryInfo(name: 'Denmark', iso: 'DK', dialCode: '+45', flagEmoji: '🇩🇰'),
  CountryInfo(name: 'Djibouti', iso: 'DJ', dialCode: '+253', flagEmoji: '🇩🇯'),
  CountryInfo(name: 'Dominica', iso: 'DM', dialCode: '+1', flagEmoji: '🇩🇲'),
  CountryInfo(name: 'Dominican Republic', iso: 'DO', dialCode: '+1', flagEmoji: '🇩🇴'),
  CountryInfo(name: 'Ecuador', iso: 'EC', dialCode: '+593', flagEmoji: '🇪🇨'),
  CountryInfo(name: 'Egypt', iso: 'EG', dialCode: '+20', flagEmoji: '🇪🇬'),
  CountryInfo(name: 'El Salvador', iso: 'SV', dialCode: '+503', flagEmoji: '🇸🇻'),
  CountryInfo(name: 'Equatorial Guinea', iso: 'GQ', dialCode: '+240', flagEmoji: '🇬🇶'),
  CountryInfo(name: 'Eritrea', iso: 'ER', dialCode: '+291', flagEmoji: '🇪🇷'),
  CountryInfo(name: 'Estonia', iso: 'EE', dialCode: '+372', flagEmoji: '🇪🇪'),
  CountryInfo(name: 'Eswatini', iso: 'SZ', dialCode: '+268', flagEmoji: '🇸🇿'),
  CountryInfo(name: 'Ethiopia', iso: 'ET', dialCode: '+251', flagEmoji: '🇪🇹'),
  CountryInfo(name: 'Fiji', iso: 'FJ', dialCode: '+679', flagEmoji: '🇫🇯'),
  CountryInfo(name: 'Finland', iso: 'FI', dialCode: '+358', flagEmoji: '🇫🇮'),
  CountryInfo(name: 'France', iso: 'FR', dialCode: '+33', flagEmoji: '🇫🇷'),
  CountryInfo(name: 'Gabon', iso: 'GA', dialCode: '+241', flagEmoji: '🇬🇦'),
  CountryInfo(name: 'Gambia', iso: 'GM', dialCode: '+220', flagEmoji: '🇬🇲'),
  CountryInfo(name: 'Georgia', iso: 'GE', dialCode: '+995', flagEmoji: '🇬🇪'),
  CountryInfo(name: 'Germany', iso: 'DE', dialCode: '+49', flagEmoji: '🇩🇪'),
  CountryInfo(name: 'Ghana', iso: 'GH', dialCode: '+233', flagEmoji: '🇬🇭'),
  CountryInfo(name: 'Greece', iso: 'GR', dialCode: '+30', flagEmoji: '🇬🇷'),
  CountryInfo(name: 'Grenada', iso: 'GD', dialCode: '+1', flagEmoji: '🇬🇩'),
  CountryInfo(name: 'Guatemala', iso: 'GT', dialCode: '+502', flagEmoji: '🇬🇹'),
  CountryInfo(name: 'Guinea', iso: 'GN', dialCode: '+224', flagEmoji: '🇬🇳'),
  CountryInfo(name: 'Guinea-Bissau', iso: 'GW', dialCode: '+245', flagEmoji: '🇬🇼'),
  CountryInfo(name: 'Guyana', iso: 'GY', dialCode: '+592', flagEmoji: '🇬🇾'),
  CountryInfo(name: 'Haiti', iso: 'HT', dialCode: '+509', flagEmoji: '🇭🇹'),
  CountryInfo(name: 'Honduras', iso: 'HN', dialCode: '+504', flagEmoji: '🇭🇳'),
  CountryInfo(name: 'Hong Kong', iso: 'HK', dialCode: '+852', flagEmoji: '🇭🇰'),
  CountryInfo(name: 'Hungary', iso: 'HU', dialCode: '+36', flagEmoji: '🇭🇺'),
  CountryInfo(name: 'Iceland', iso: 'IS', dialCode: '+354', flagEmoji: '🇮🇸'),
  CountryInfo(name: 'India', iso: 'IN', dialCode: '+91', flagEmoji: '🇮🇳'),
  CountryInfo(name: 'Indonesia', iso: 'ID', dialCode: '+62', flagEmoji: '🇮🇩'),
  CountryInfo(name: 'Iran', iso: 'IR', dialCode: '+98', flagEmoji: '🇮🇷'),
  CountryInfo(name: 'Iraq', iso: 'IQ', dialCode: '+964', flagEmoji: '🇮🇶'),
  CountryInfo(name: 'Ireland', iso: 'IE', dialCode: '+353', flagEmoji: '🇮🇪'),
  CountryInfo(name: 'Israel', iso: 'IL', dialCode: '+972', flagEmoji: '🇮🇱'),
  CountryInfo(name: 'Italy', iso: 'IT', dialCode: '+39', flagEmoji: '🇮🇹'),
  CountryInfo(name: 'Jamaica', iso: 'JM', dialCode: '+1', flagEmoji: '🇯🇲'),
  CountryInfo(name: 'Japan', iso: 'JP', dialCode: '+81', flagEmoji: '🇯🇵'),
  CountryInfo(name: 'Jordan', iso: 'JO', dialCode: '+962', flagEmoji: '🇯🇴'),
  CountryInfo(name: 'Kazakhstan', iso: 'KZ', dialCode: '+7', flagEmoji: '🇰🇿'),
  CountryInfo(name: 'Kenya', iso: 'KE', dialCode: '+254', flagEmoji: '🇰🇪'),
  CountryInfo(name: 'Kiribati', iso: 'KI', dialCode: '+686', flagEmoji: '🇰🇮'),
  CountryInfo(name: 'Korea (North)', iso: 'KP', dialCode: '+850', flagEmoji: '🇰🇵'),
  CountryInfo(name: 'Korea (South)', iso: 'KR', dialCode: '+82', flagEmoji: '🇰🇷'),
  CountryInfo(name: 'Kuwait', iso: 'KW', dialCode: '+965', flagEmoji: '🇰🇼'),
  CountryInfo(name: 'Kyrgyzstan', iso: 'KG', dialCode: '+996', flagEmoji: '🇰🇬'),
  CountryInfo(name: 'Laos', iso: 'LA', dialCode: '+856', flagEmoji: '🇱🇦'),
  CountryInfo(name: 'Latvia', iso: 'LV', dialCode: '+371', flagEmoji: '🇱🇻'),
  CountryInfo(name: 'Lebanon', iso: 'LB', dialCode: '+961', flagEmoji: '🇱🇧'),
  CountryInfo(name: 'Lesotho', iso: 'LS', dialCode: '+266', flagEmoji: '🇱🇸'),
  CountryInfo(name: 'Liberia', iso: 'LR', dialCode: '+231', flagEmoji: '🇱🇷'),
  CountryInfo(name: 'Libya', iso: 'LY', dialCode: '+218', flagEmoji: '🇱🇾'),
  CountryInfo(name: 'Liechtenstein', iso: 'LI', dialCode: '+423', flagEmoji: '🇱🇮'),
  CountryInfo(name: 'Lithuania', iso: 'LT', dialCode: '+370', flagEmoji: '🇱🇹'),
  CountryInfo(name: 'Luxembourg', iso: 'LU', dialCode: '+352', flagEmoji: '🇱🇺'),
  CountryInfo(name: 'Madagascar', iso: 'MG', dialCode: '+261', flagEmoji: '🇲🇬'),
  CountryInfo(name: 'Malawi', iso: 'MW', dialCode: '+265', flagEmoji: '🇲🇼'),
  CountryInfo(name: 'Malaysia', iso: 'MY', dialCode: '+60', flagEmoji: '🇲🇾'),
  CountryInfo(name: 'Maldives', iso: 'MV', dialCode: '+960', flagEmoji: '🇲🇻'),
  CountryInfo(name: 'Mali', iso: 'ML', dialCode: '+223', flagEmoji: '🇲🇱'),
  CountryInfo(name: 'Malta', iso: 'MT', dialCode: '+356', flagEmoji: '🇲🇹'),
  CountryInfo(name: 'Marshall Islands', iso: 'MH', dialCode: '+692', flagEmoji: '🇲🇭'),
  CountryInfo(name: 'Mauritania', iso: 'MR', dialCode: '+222', flagEmoji: '🇲🇷'),
  CountryInfo(name: 'Mauritius', iso: 'MU', dialCode: '+230', flagEmoji: '🇲🇺'),
  CountryInfo(name: 'Mexico', iso: 'MX', dialCode: '+52', flagEmoji: '🇲🇽'),
  CountryInfo(name: 'Micronesia', iso: 'FM', dialCode: '+691', flagEmoji: '🇫🇲'),
  CountryInfo(name: 'Moldova', iso: 'MD', dialCode: '+373', flagEmoji: '🇲🇩'),
  CountryInfo(name: 'Monaco', iso: 'MC', dialCode: '+377', flagEmoji: '🇲🇨'),
  CountryInfo(name: 'Mongolia', iso: 'MN', dialCode: '+976', flagEmoji: '🇲🇳'),
  CountryInfo(name: 'Montenegro', iso: 'ME', dialCode: '+382', flagEmoji: '🇲🇪'),
  CountryInfo(name: 'Morocco', iso: 'MA', dialCode: '+212', flagEmoji: '🇲🇦'),
  CountryInfo(name: 'Mozambique', iso: 'MZ', dialCode: '+258', flagEmoji: '🇲🇿'),
  CountryInfo(name: 'Myanmar', iso: 'MM', dialCode: '+95', flagEmoji: '🇲🇲'),
  CountryInfo(name: 'Namibia', iso: 'NA', dialCode: '+264', flagEmoji: '🇳🇦'),
  CountryInfo(name: 'Nauru', iso: 'NR', dialCode: '+674', flagEmoji: '🇳🇷'),
  CountryInfo(name: 'Nepal', iso: 'NP', dialCode: '+977', flagEmoji: '🇳🇵'),
  CountryInfo(name: 'Netherlands', iso: 'NL', dialCode: '+31', flagEmoji: '🇳🇱'),
  CountryInfo(name: 'New Zealand', iso: 'NZ', dialCode: '+64', flagEmoji: '🇳🇿'),
  CountryInfo(name: 'Nicaragua', iso: 'NI', dialCode: '+505', flagEmoji: '🇳🇮'),
  CountryInfo(name: 'Niger', iso: 'NE', dialCode: '+227', flagEmoji: '🇳🇪'),
  CountryInfo(name: 'Nigeria', iso: 'NG', dialCode: '+234', flagEmoji: '🇳🇬'),
  CountryInfo(name: 'North Macedonia', iso: 'MK', dialCode: '+389', flagEmoji: '🇲🇰'),
  CountryInfo(name: 'Norway', iso: 'NO', dialCode: '+47', flagEmoji: '🇳🇴'),
  CountryInfo(name: 'Oman', iso: 'OM', dialCode: '+968', flagEmoji: '🇴🇲'),
  CountryInfo(name: 'Pakistan', iso: 'PK', dialCode: '+92', flagEmoji: '🇵🇰'),
  CountryInfo(name: 'Palau', iso: 'PW', dialCode: '+680', flagEmoji: '🇵🇼'),
  CountryInfo(name: 'Palestine', iso: 'PS', dialCode: '+970', flagEmoji: '🇵🇸'),
  CountryInfo(name: 'Panama', iso: 'PA', dialCode: '+507', flagEmoji: '🇵🇦'),
  CountryInfo(name: 'Papua New Guinea', iso: 'PG', dialCode: '+675', flagEmoji: '🇵🇬'),
  CountryInfo(name: 'Paraguay', iso: 'PY', dialCode: '+595', flagEmoji: '🇵🇾'),
  CountryInfo(name: 'Peru', iso: 'PE', dialCode: '+51', flagEmoji: '🇵🇪'),
  CountryInfo(name: 'Philippines', iso: 'PH', dialCode: '+63', flagEmoji: '🇵🇭'),
  CountryInfo(name: 'Poland', iso: 'PL', dialCode: '+48', flagEmoji: '🇵🇱'),
  CountryInfo(name: 'Portugal', iso: 'PT', dialCode: '+351', flagEmoji: '🇵🇹'),
  CountryInfo(name: 'Qatar', iso: 'QA', dialCode: '+974', flagEmoji: '🇶🇦'),
  CountryInfo(name: 'Romania', iso: 'RO', dialCode: '+40', flagEmoji: '🇷🇴'),
  CountryInfo(name: 'Russia', iso: 'RU', dialCode: '+7', flagEmoji: '🇷🇺'),
  CountryInfo(name: 'Rwanda', iso: 'RW', dialCode: '+250', flagEmoji: '🇷🇼'),
  CountryInfo(name: 'Saint Kitts and Nevis', iso: 'KN', dialCode: '+1', flagEmoji: '🇰🇳'),
  CountryInfo(name: 'Saint Lucia', iso: 'LC', dialCode: '+1', flagEmoji: '🇱🇨'),
  CountryInfo(name: 'Saint Vincent and the Grenadines', iso: 'VC', dialCode: '+1', flagEmoji: '🇻🇨'),
  CountryInfo(name: 'Samoa', iso: 'WS', dialCode: '+685', flagEmoji: '🇼🇸'),
  CountryInfo(name: 'San Marino', iso: 'SM', dialCode: '+378', flagEmoji: '🇸🇲'),
  CountryInfo(name: 'Sao Tome and Principe', iso: 'ST', dialCode: '+239', flagEmoji: '🇸🇹'),
  CountryInfo(name: 'Saudi Arabia', iso: 'SA', dialCode: '+966', flagEmoji: '🇸🇦'),
  CountryInfo(name: 'Senegal', iso: 'SN', dialCode: '+221', flagEmoji: '🇸🇳'),
  CountryInfo(name: 'Serbia', iso: 'RS', dialCode: '+381', flagEmoji: '🇷🇸'),
  CountryInfo(name: 'Seychelles', iso: 'SC', dialCode: '+248', flagEmoji: '🇸🇨'),
  CountryInfo(name: 'Sierra Leone', iso: 'SL', dialCode: '+232', flagEmoji: '🇸🇱'),
  CountryInfo(name: 'Singapore', iso: 'SG', dialCode: '+65', flagEmoji: '🇸🇬'),
  CountryInfo(name: 'Slovakia', iso: 'SK', dialCode: '+421', flagEmoji: '🇸🇰'),
  CountryInfo(name: 'Slovenia', iso: 'SI', dialCode: '+386', flagEmoji: '🇸🇮'),
  CountryInfo(name: 'Solomon Islands', iso: 'SB', dialCode: '+677', flagEmoji: '🇸🇧'),
  CountryInfo(name: 'Somalia', iso: 'SO', dialCode: '+252', flagEmoji: '🇸🇴'),
  CountryInfo(name: 'South Africa', iso: 'ZA', dialCode: '+27', flagEmoji: '🇿🇦'),
  CountryInfo(name: 'South Sudan', iso: 'SS', dialCode: '+211', flagEmoji: '🇸🇸'),
  CountryInfo(name: 'Spain', iso: 'ES', dialCode: '+34', flagEmoji: '🇪🇸'),
  CountryInfo(name: 'Sri Lanka', iso: 'LK', dialCode: '+94', flagEmoji: '🇱🇰'),
  CountryInfo(name: 'Sudan', iso: 'SD', dialCode: '+249', flagEmoji: '🇸🇩'),
  CountryInfo(name: 'Suriname', iso: 'SR', dialCode: '+597', flagEmoji: '🇸🇷'),
  CountryInfo(name: 'Sweden', iso: 'SE', dialCode: '+46', flagEmoji: '🇸🇪'),
  CountryInfo(name: 'Switzerland', iso: 'CH', dialCode: '+41', flagEmoji: '🇨🇭'),
  CountryInfo(name: 'Syria', iso: 'SY', dialCode: '+963', flagEmoji: '🇸🇾'),
  CountryInfo(name: 'Taiwan', iso: 'TW', dialCode: '+886', flagEmoji: '🇹🇼'),
  CountryInfo(name: 'Tajikistan', iso: 'TJ', dialCode: '+992', flagEmoji: '🇹🇯'),
  CountryInfo(name: 'Tanzania', iso: 'TZ', dialCode: '+255', flagEmoji: '🇹🇿'),
  CountryInfo(name: 'Thailand', iso: 'TH', dialCode: '+66', flagEmoji: '🇹🇭'),
  CountryInfo(name: 'Timor-Leste', iso: 'TL', dialCode: '+670', flagEmoji: '🇹🇱'),
  CountryInfo(name: 'Togo', iso: 'TG', dialCode: '+228', flagEmoji: '🇹🇬'),
  CountryInfo(name: 'Tonga', iso: 'TO', dialCode: '+676', flagEmoji: '🇹🇴'),
  CountryInfo(name: 'Trinidad and Tobago', iso: 'TT', dialCode: '+1', flagEmoji: '🇹🇹'),
  CountryInfo(name: 'Tunisia', iso: 'TN', dialCode: '+216', flagEmoji: '🇹🇳'),
  CountryInfo(name: 'Turkey', iso: 'TR', dialCode: '+90', flagEmoji: '🇹🇷'),
  CountryInfo(name: 'Turkmenistan', iso: 'TM', dialCode: '+993', flagEmoji: '🇹🇲'),
  CountryInfo(name: 'Tuvalu', iso: 'TV', dialCode: '+688', flagEmoji: '🇹🇻'),
  CountryInfo(name: 'Uganda', iso: 'UG', dialCode: '+256', flagEmoji: '🇺🇬'),
  CountryInfo(name: 'Ukraine', iso: 'UA', dialCode: '+380', flagEmoji: '🇺🇦'),
  CountryInfo(name: 'United Arab Emirates', iso: 'AE', dialCode: '+971', flagEmoji: '🇦🇪'),
  CountryInfo(name: 'United Kingdom', iso: 'GB', dialCode: '+44', flagEmoji: '🇬🇧'),
  CountryInfo(name: 'United States', iso: 'US', dialCode: '+1', flagEmoji: '🇺🇸'),
  CountryInfo(name: 'Uruguay', iso: 'UY', dialCode: '+598', flagEmoji: '🇺🇾'),
  CountryInfo(name: 'Uzbekistan', iso: 'UZ', dialCode: '+998', flagEmoji: '🇺🇿'),
  CountryInfo(name: 'Vanuatu', iso: 'VU', dialCode: '+678', flagEmoji: '🇻🇺'),
  CountryInfo(name: 'Vatican City', iso: 'VA', dialCode: '+379', flagEmoji: '🇻🇦'),
  CountryInfo(name: 'Venezuela', iso: 'VE', dialCode: '+58', flagEmoji: '🇻🇪'),
  CountryInfo(name: 'Vietnam', iso: 'VN', dialCode: '+84', flagEmoji: '🇻🇳'),
  CountryInfo(name: 'Yemen', iso: 'YE', dialCode: '+967', flagEmoji: '🇾🇪'),
  CountryInfo(name: 'Zambia', iso: 'ZM', dialCode: '+260', flagEmoji: '🇿🇲'),
  CountryInfo(name: 'Zimbabwe', iso: 'ZW', dialCode: '+263', flagEmoji: '🇿🇼'),
];

/// Full-screen "Select a country" page with A-Z list and search bar.
/// Uses Kora's dark visual identity with a purple-to-blue gradient accent.
class SelectCountryScreen extends StatefulWidget {
  final CountryInfo? currentCountry;

  const SelectCountryScreen({super.key, this.currentCountry});

  @override
  State<SelectCountryScreen> createState() => _SelectCountryScreenState();
}

class _SelectCountryScreenState extends State<SelectCountryScreen> {
  final _searchController = TextEditingController();
  List<CountryInfo> _filtered = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filtered = allCountries;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = allCountries;
      } else {
        _filtered = allCountries.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.dialCode.contains(query) ||
              c.iso.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = KoraColors.backgroundFor(brightness);
    final card = KoraColors.cardFor(brightness);
    final textPrimary = KoraColors.textPrimaryFor(brightness);
    final textSecondary = KoraColors.textSecondaryFor(brightness);
    final border = KoraColors.borderFor(brightness);
    final hintColor = KoraColors.hintFor(brightness);

    // Group filtered countries by first letter
    final sections = <String, List<CountryInfo>>{};
    for (final country in _filtered) {
      final letter = country.name[0].toUpperCase();
      sections.putIfAbsent(letter, () => []).add(country);
    }
    final sortedLetters = sections.keys.toList()..sort();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select a country',
          style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: textPrimary, size: 24),
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                _searchController.clear();
              }
            },
          ),
        ],
        bottom: _isSearching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border, width: 0.5),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search country, code, or dial code',
                        hintStyle: TextStyle(color: hintColor, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: textSecondary, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _isSearching && _searchController.text.isNotEmpty
          ? _buildFlatList(context, _filtered, card, textPrimary, textSecondary, border)
          : _buildSectionedList(context, sections, sortedLetters, card, textPrimary, textSecondary, border),
    );
  }

  /// Flat list used when searching — no section headers.
  Widget _buildFlatList(
    BuildContext context,
    List<CountryInfo> countries,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    if (countries.isEmpty) {
      return Center(
        child: Text(
          'No countries found',
          style: TextStyle(color: textSecondary, fontSize: 15),
        ),
      );
    }
    return ListView.separated(
      itemCount: countries.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: border, indent: 64),
      itemBuilder: (context, index) {
        final country = countries[index];
        final isSelected = widget.currentCountry?.iso == country.iso;
        return _countryTile(country, isSelected, card, textPrimary, textSecondary, border);
      },
    );
  }

  /// Sectioned A-Z list with letter headers.
  Widget _buildSectionedList(
    BuildContext context,
    Map<String, List<CountryInfo>> sections,
    List<String> letters,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    return CustomScrollView(
      slivers: [
        for (final letter in letters) ...[
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                letter,
                style: TextStyle(
                  color: KoraColors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final country = sections[letter]![index];
                final isSelected = widget.currentCountry?.iso == country.iso;
                return _countryTile(country, isSelected, card, textPrimary, textSecondary, border);
              },
              childCount: sections[letter]!.length,
            ),
          ),
          SliverToBoxAdapter(child: Divider(height: 1, color: border)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _countryTile(
    CountryInfo country,
    bool isSelected,
    Color card,
    Color textPrimary,
    Color textSecondary,
    Color border,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context, country),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              country.flagEmoji,
              style: const TextStyle(fontSize: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                country.name,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              country.dialCode,
              style: TextStyle(
                color: textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Icon(Icons.check_circle, color: KoraColors.purple, size: 22),
          ],
        ),
      ),
    );
  }
}
