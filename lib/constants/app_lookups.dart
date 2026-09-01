/// Bundled fallback lookup data + fixed enum option lists.
///
/// IMPORTANT: The HamQadam API (v1) does **not** document any lookup/reference
/// endpoints, yet several fields require server IDs (marital_status_id,
/// religion_id, country_id, …). [LookupRepository] therefore tries a
/// conventional `/lookups/{key}` endpoint first and falls back to the data
/// below. When the backend ships real lookup endpoints, no UI change is needed.
///
/// Each entry uses the API-style shape `{id, name, parent_id}` so parsing is
/// identical whether the data comes from the network or from here.
class BundledLookups {
  const BundledLookups._();

  static const List<Map<String, dynamic>> onBehalf = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Self'},
    {'id': 2, 'name': 'Son'},
    {'id': 3, 'name': 'Daughter'},
    {'id': 4, 'name': 'Brother'},
    {'id': 5, 'name': 'Sister'},
    {'id': 6, 'name': 'Relative'},
    {'id': 7, 'name': 'Friend'},
  ];

  static const List<Map<String, dynamic>> gender = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Male'},
    {'id': 2, 'name': 'Female'},
  ];

  static const List<Map<String, dynamic>> maritalStatus = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Never Married'},
    {'id': 2, 'name': 'Divorced'},
    {'id': 3, 'name': 'Widowed'},
    {'id': 4, 'name': 'Annulled'},
    {'id': 5, 'name': 'Separated'},
  ];

static const List<Map<String, dynamic>> languages =
    <Map<String, dynamic>>[
  // Pakistan
  {'id': 1, 'name': 'Urdu'},
  {'id': 2, 'name': 'Punjabi'},
  {'id': 3, 'name': 'Sindhi'},
  {'id': 4, 'name': 'Pashto'},
  {'id': 5, 'name': 'Balochi'},
  {'id': 6, 'name': 'Saraiki'},
  {'id': 7, 'name': 'Hindko'},
  {'id': 8, 'name': 'Brahui'},
  {'id': 9, 'name': 'Shina'},
  {'id': 10, 'name': 'Balti'},
  {'id': 11, 'name': 'Burushaski'},
  {'id': 12, 'name': 'Khowar'},
  {'id': 13, 'name': 'Wakhi'},
  {'id': 14, 'name': 'Gujari'},
  {'id': 15, 'name': 'Gawri'},
  {'id': 16, 'name': 'Torwali'},
  {'id': 17, 'name': 'Kalasha'},
  {'id': 18, 'name': 'Domaaki'},
  {'id': 19, 'name': 'Yidgha'},
  {'id': 20, 'name': 'Dameli'},
  {'id': 21, 'name': 'Gawar-Bati'},
  {'id': 22, 'name': 'Ormuri'},
  {'id': 23, 'name': 'Shumashti'},
  {'id': 24, 'name': 'Ushojo'},
  {'id': 25, 'name': 'Palula'},

  // International
  {'id': 26, 'name': 'English'},
  {'id': 27, 'name': 'Arabic'},
  {'id': 28, 'name': 'Hindi'},
  {'id': 29, 'name': 'Bengali'},
  {'id': 30, 'name': 'Persian'},
  {'id': 31, 'name': 'Chinese (Mandarin)'},
  {'id': 32, 'name': 'Japanese'},
  {'id': 33, 'name': 'Korean'},
  {'id': 34, 'name': 'Turkish'},
  {'id': 35, 'name': 'French'},
  {'id': 36, 'name': 'Spanish'},
  {'id': 37, 'name': 'Portuguese'},
  {'id': 38, 'name': 'German'},
  {'id': 39, 'name': 'Italian'},
  {'id': 40, 'name': 'Russian'},
  {'id': 41, 'name': 'Ukrainian'},
  {'id': 42, 'name': 'Dutch'},
  {'id': 43, 'name': 'Greek'},
  {'id': 44, 'name': 'Hebrew'},
  {'id': 45, 'name': 'Thai'},
  {'id': 46, 'name': 'Vietnamese'},
  {'id': 47, 'name': 'Malay'},
  {'id': 48, 'name': 'Indonesian'},
  {'id': 49, 'name': 'Filipino'},
  {'id': 50, 'name': 'Tamil'},
  {'id': 51, 'name': 'Telugu'},
  {'id': 52, 'name': 'Marathi'},
  {'id': 53, 'name': 'Gujarati'},
  {'id': 54, 'name': 'Kannada'},
  {'id': 55, 'name': 'Malayalam'},
  {'id': 56, 'name': 'Nepali'},
  {'id': 57, 'name': 'Sinhala'},
  {'id': 58, 'name': 'Burmese'},
  {'id': 59, 'name': 'Kurdish'},
  {'id': 60, 'name': 'Azerbaijani'},
  {'id': 61, 'name': 'Kazakh'},
  {'id': 62, 'name': 'Uzbek'},
  {'id': 63, 'name': 'Turkmen'},
  {'id': 64, 'name': 'Swedish'},
  {'id': 65, 'name': 'Norwegian'},
  {'id': 66, 'name': 'Danish'},
  {'id': 67, 'name': 'Finnish'},
  {'id': 68, 'name': 'Polish'},
  {'id': 69, 'name': 'Czech'},
  {'id': 70, 'name': 'Slovak'},
  {'id': 71, 'name': 'Hungarian'},
  {'id': 72, 'name': 'Romanian'},
  {'id': 73, 'name': 'Bulgarian'},
  {'id': 74, 'name': 'Serbian'},
  {'id': 75, 'name': 'Croatian'},
  {'id': 76, 'name': 'Bosnian'},
  {'id': 77, 'name': 'Albanian'},
  {'id': 78, 'name': 'Swahili'},
  {'id': 79, 'name': 'Amharic'},
  {'id': 80, 'name': 'Somali'},
  {'id': 81, 'name': 'Afrikaans'},
  {'id': 82, 'name': 'Zulu'},
  {'id': 83, 'name': 'Yoruba'},
  {'id': 84, 'name': 'Igbo'},
  {'id': 85, 'name': 'Hausa'},
  {'id': 86, 'name': 'Farsi (Persian)'},
  {'id': 87, 'name': 'Pashto'},
  {'id': 88, 'name': 'Kurdish (Sorani)'},
  {'id': 89, 'name': 'Kurdish (Kurmanji)'},
  {'id': 90, 'name': 'Tajik'},
  {'id': 91, 'name': 'Kyrgyz'},
  {'id': 92, 'name': 'Mongolian'},
  {'id': 93, 'name': 'Tibetan'},
  {'id': 94, 'name': 'Uyghur'},
  {'id': 95, 'name': 'Pashto (Afghanistan)'},
  {'id': 96, 'name': 'Pashto (Pakistan)'},
  {'id': 97, 'name': 'Kashmiri'},
  {'id': 98, 'name': 'Sindhi (Pakistan)'},
  {'id': 99, 'name': 'Sindhi (India)'},
  {'id': 100, 'name': 'Balochi (Pakistan)'},
  {'id': 101, 'name': 'Balochi (Iran)'},
  {'id': 102, 'name': 'Balochi (Afghanistan)'},
];

 static const List<Map<String, dynamic>> countries =
      <Map<String, dynamic>>[
    {'id': 1, 'name': 'Afghanistan'},
    {'id': 2, 'name': 'Albania'},
    {'id': 3, 'name': 'Algeria'},
    {'id': 4, 'name': 'Andorra'},
    {'id': 5, 'name': 'Angola'},
    {'id': 6, 'name': 'Antigua and Barbuda'},
    {'id': 7, 'name': 'Argentina'},
    {'id': 8, 'name': 'Armenia'},
    {'id': 9, 'name': 'Australia'},
    {'id': 10, 'name': 'Austria'},
    {'id': 11, 'name': 'Azerbaijan'},
    {'id': 12, 'name': 'Bahamas'},
    {'id': 13, 'name': 'Bahrain'},
    {'id': 14, 'name': 'Bangladesh'},
    {'id': 15, 'name': 'Barbados'},
    {'id': 16, 'name': 'Belarus'},
    {'id': 17, 'name': 'Belgium'},
    {'id': 18, 'name': 'Belize'},
    {'id': 19, 'name': 'Benin'},
    {'id': 20, 'name': 'Bhutan'},
    {'id': 21, 'name': 'Bolivia'},
    {'id': 22, 'name': 'Bosnia and Herzegovina'},
    {'id': 23, 'name': 'Botswana'},
    {'id': 24, 'name': 'Brazil'},
    {'id': 25, 'name': 'Brunei'},
    {'id': 26, 'name': 'Bulgaria'},
    {'id': 27, 'name': 'Burkina Faso'},
    {'id': 28, 'name': 'Burundi'},
    {'id': 29, 'name': 'Cabo Verde'},
    {'id': 30, 'name': 'Cambodia'},
    {'id': 31, 'name': 'Cameroon'},
    {'id': 32, 'name': 'Canada'},
    {'id': 33, 'name': 'Central African Republic'},
    {'id': 34, 'name': 'Chad'},
    {'id': 35, 'name': 'Chile'},
    {'id': 36, 'name': 'China'},
    {'id': 37, 'name': 'Colombia'},
    {'id': 38, 'name': 'Comoros'},
    {'id': 39, 'name': 'Congo'},
    {'id': 40, 'name': 'Costa Rica'},
    {'id': 41, 'name': 'Croatia'},
    {'id': 42, 'name': 'Cuba'},
    {'id': 43, 'name': 'Cyprus'},
    {'id': 44, 'name': 'Czechia'},
    {'id': 45, 'name': 'Democratic Republic of the Congo'},
    {'id': 46, 'name': 'Denmark'},
    {'id': 47, 'name': 'Djibouti'},
    {'id': 48, 'name': 'Dominica'},
    {'id': 49, 'name': 'Dominican Republic'},
    {'id': 50, 'name': 'Ecuador'},
    {'id': 51, 'name': 'Egypt'},
    {'id': 52, 'name': 'El Salvador'},
    {'id': 53, 'name': 'Equatorial Guinea'},
    {'id': 54, 'name': 'Eritrea'},
    {'id': 55, 'name': 'Estonia'},
    {'id': 56, 'name': 'Eswatini'},
    {'id': 57, 'name': 'Ethiopia'},
    {'id': 58, 'name': 'Fiji'},
    {'id': 59, 'name': 'Finland'},
    {'id': 60, 'name': 'France'},
    {'id': 61, 'name': 'Gabon'},
    {'id': 62, 'name': 'Gambia'},
    {'id': 63, 'name': 'Georgia'},
    {'id': 64, 'name': 'Germany'},
    {'id': 65, 'name': 'Ghana'},
    {'id': 66, 'name': 'Greece'},
    {'id': 67, 'name': 'Grenada'},
    {'id': 68, 'name': 'Guatemala'},
    {'id': 69, 'name': 'Guinea'},
    {'id': 70, 'name': 'Guinea-Bissau'},
    {'id': 71, 'name': 'Guyana'},
    {'id': 72, 'name': 'Haiti'},
    {'id': 73, 'name': 'Honduras'},
    {'id': 74, 'name': 'Hungary'},
    {'id': 75, 'name': 'Iceland'},
    {'id': 76, 'name': 'India'},
    {'id': 77, 'name': 'Indonesia'},
    {'id': 78, 'name': 'Iran'},
    {'id': 79, 'name': 'Iraq'},
    {'id': 80, 'name': 'Ireland'},
    {'id': 81, 'name': 'Israel'},
    {'id': 82, 'name': 'Italy'},
    {'id': 83, 'name': 'Jamaica'},
    {'id': 84, 'name': 'Japan'},
    {'id': 85, 'name': 'Jordan'},
    {'id': 86, 'name': 'Kazakhstan'},
    {'id': 87, 'name': 'Kenya'},
    {'id': 88, 'name': 'Kiribati'},
    {'id': 89, 'name': 'Kuwait'},
    {'id': 90, 'name': 'Kyrgyzstan'},
    {'id': 91, 'name': 'Laos'},
    {'id': 92, 'name': 'Latvia'},
    {'id': 93, 'name': 'Lebanon'},
    {'id': 94, 'name': 'Lesotho'},
    {'id': 95, 'name': 'Liberia'},
    {'id': 96, 'name': 'Libya'},
    {'id': 97, 'name': 'Liechtenstein'},
    {'id': 98, 'name': 'Lithuania'},
    {'id': 99, 'name': 'Luxembourg'},
    {'id': 100, 'name': 'Madagascar'},
    {'id': 101, 'name': 'Malawi'},
    {'id': 102, 'name': 'Malaysia'},
    {'id': 103, 'name': 'Maldives'},
    {'id': 104, 'name': 'Mali'},
    {'id': 105, 'name': 'Malta'},
    {'id': 106, 'name': 'Marshall Islands'},
    {'id': 107, 'name': 'Mauritania'},
    {'id': 108, 'name': 'Mauritius'},
    {'id': 109, 'name': 'Mexico'},
    {'id': 110, 'name': 'Micronesia'},
    {'id': 111, 'name': 'Moldova'},
    {'id': 112, 'name': 'Monaco'},
    {'id': 113, 'name': 'Mongolia'},
    {'id': 114, 'name': 'Montenegro'},
    {'id': 115, 'name': 'Morocco'},
    {'id': 116, 'name': 'Mozambique'},
    {'id': 117, 'name': 'Myanmar'},
    {'id': 118, 'name': 'Namibia'},
    {'id': 119, 'name': 'Nauru'},
    {'id': 120, 'name': 'Nepal'},
    {'id': 121, 'name': 'Netherlands'},
    {'id': 122, 'name': 'New Zealand'},
    {'id': 123, 'name': 'Nicaragua'},
    {'id': 124, 'name': 'Niger'},
    {'id': 125, 'name': 'Nigeria'},
    {'id': 126, 'name': 'North Korea'},
    {'id': 127, 'name': 'North Macedonia'},
    {'id': 128, 'name': 'Norway'},
    {'id': 129, 'name': 'Oman'},
    {'id': 130, 'name': 'Pakistan'},
    {'id': 131, 'name': 'Palau'},
    {'id': 132, 'name': 'Palestine'},
    {'id': 133, 'name': 'Panama'},
    {'id': 134, 'name': 'Papua New Guinea'},
    {'id': 135, 'name': 'Paraguay'},
    {'id': 136, 'name': 'Peru'},
    {'id': 137, 'name': 'Philippines'},
    {'id': 138, 'name': 'Poland'},
    {'id': 139, 'name': 'Portugal'},
    {'id': 140, 'name': 'Qatar'},
    {'id': 141, 'name': 'Romania'},
    {'id': 142, 'name': 'Russia'},
    {'id': 143, 'name': 'Rwanda'},
    {'id': 144, 'name': 'Saint Kitts and Nevis'},
    {'id': 145, 'name': 'Saint Lucia'},
    {'id': 146, 'name': 'Saint Vincent and the Grenadines'},
    {'id': 147, 'name': 'Samoa'},
    {'id': 148, 'name': 'San Marino'},
    {'id': 149, 'name': 'Sao Tome and Principe'},
    {'id': 150, 'name': 'Saudi Arabia'},
    {'id': 151, 'name': 'Senegal'},
    {'id': 152, 'name': 'Serbia'},
    {'id': 153, 'name': 'Seychelles'},
    {'id': 154, 'name': 'Sierra Leone'},
    {'id': 155, 'name': 'Singapore'},
    {'id': 156, 'name': 'Slovakia'},
    {'id': 157, 'name': 'Slovenia'},
    {'id': 158, 'name': 'Solomon Islands'},
    {'id': 159, 'name': 'Somalia'},
    {'id': 160, 'name': 'South Africa'},
    {'id': 161, 'name': 'South Korea'},
    {'id': 162, 'name': 'South Sudan'},
    {'id': 163, 'name': 'Spain'},
    {'id': 164, 'name': 'Sri Lanka'},
    {'id': 165, 'name': 'Sudan'},
    {'id': 166, 'name': 'Suriname'},
    {'id': 167, 'name': 'Sweden'},
    {'id': 168, 'name': 'Switzerland'},
    {'id': 169, 'name': 'Syria'},
    {'id': 170, 'name': 'Tajikistan'},
    {'id': 171, 'name': 'Tanzania'},
    {'id': 172, 'name': 'Thailand'},
    {'id': 173, 'name': 'Timor-Leste'},
    {'id': 174, 'name': 'Togo'},
    {'id': 175, 'name': 'Tonga'},
    {'id': 176, 'name': 'Trinidad and Tobago'},
    {'id': 177, 'name': 'Tunisia'},
    {'id': 178, 'name': 'Turkey'},
    {'id': 179, 'name': 'Turkmenistan'},
    {'id': 180, 'name': 'Tuvalu'},
    {'id': 181, 'name': 'Uganda'},
    {'id': 182, 'name': 'Ukraine'},
    {'id': 183, 'name': 'United Arab Emirates'},
    {'id': 184, 'name': 'United Kingdom'},
    {'id': 185, 'name': 'United States'},
    {'id': 186, 'name': 'Uruguay'},
    {'id': 187, 'name': 'Uzbekistan'},
    {'id': 188, 'name': 'Vanuatu'},
    {'id': 189, 'name': 'Vatican City'},
    {'id': 190, 'name': 'Venezuela'},
    {'id': 191, 'name': 'Vietnam'},
    {'id': 192, 'name': 'Yemen'},
    {'id': 193, 'name': 'Zambia'},
    {'id': 194, 'name': 'Zimbabwe'},
  ];

  // ============================================================
  // STATES / PROVINCES / REGIONS
  // parent_id => country id
  // ============================================================

  static const List<Map<String, dynamic>> states =
      <Map<String, dynamic>>[
    // Pakistan - 130
    {'id': 1, 'name': 'Punjab', 'parent_id': 130},
    {'id': 2, 'name': 'Sindh', 'parent_id': 130},
    {'id': 3, 'name': 'Khyber Pakhtunkhwa', 'parent_id': 130},
    {'id': 4, 'name': 'Balochistan', 'parent_id': 130},
    {'id': 5, 'name': 'Islamabad Capital Territory', 'parent_id': 130},
    {'id': 6, 'name': 'Gilgit-Baltistan', 'parent_id': 130},
    {'id': 7, 'name': 'Azad Jammu and Kashmir', 'parent_id': 130},

    // UAE - 183
    {'id': 8, 'name': 'Abu Dhabi', 'parent_id': 183},
    {'id': 9, 'name': 'Dubai', 'parent_id': 183},
    {'id': 10, 'name': 'Sharjah', 'parent_id': 183},
    {'id': 11, 'name': 'Ajman', 'parent_id': 183},
    {'id': 12, 'name': 'Umm Al Quwain', 'parent_id': 183},
    {'id': 13, 'name': 'Ras Al Khaimah', 'parent_id': 183},
    {'id': 14, 'name': 'Fujairah', 'parent_id': 183},

    // Saudi Arabia - 150
    {'id': 15, 'name': 'Riyadh Province', 'parent_id': 150},
    {'id': 16, 'name': 'Makkah Province', 'parent_id': 150},
    {'id': 17, 'name': 'Madinah Province', 'parent_id': 150},
    {'id': 18, 'name': 'Eastern Province', 'parent_id': 150},
    {'id': 19, 'name': 'Asir Province', 'parent_id': 150},
    {'id': 20, 'name': 'Tabuk Province', 'parent_id': 150},
    {'id': 21, 'name': 'Qassim Province', 'parent_id': 150},
    {'id': 22, 'name': 'Jazan Province', 'parent_id': 150},
    {'id': 23, 'name': 'Hail Province', 'parent_id': 150},
    {'id': 24, 'name': 'Najran Province', 'parent_id': 150},
    {'id': 25, 'name': 'Al Bahah Province', 'parent_id': 150},
    {'id': 26, 'name': 'Al Jawf Province', 'parent_id': 150},
    {'id': 27, 'name': 'Northern Borders Province', 'parent_id': 150},

    // UK
    {'id': 28, 'name': 'England', 'parent_id': 184},
    {'id': 29, 'name': 'Scotland', 'parent_id': 184},
    {'id': 30, 'name': 'Wales', 'parent_id': 184},
    {'id': 31, 'name': 'Northern Ireland', 'parent_id': 184},

    // USA - Major States
    {'id': 32, 'name': 'Alabama', 'parent_id': 185},
    {'id': 33, 'name': 'Alaska', 'parent_id': 185},
    {'id': 34, 'name': 'Arizona', 'parent_id': 185},
    {'id': 35, 'name': 'Arkansas', 'parent_id': 185},
    {'id': 36, 'name': 'California', 'parent_id': 185},
    {'id': 37, 'name': 'Colorado', 'parent_id': 185},
    {'id': 38, 'name': 'Connecticut', 'parent_id': 185},
    {'id': 39, 'name': 'Delaware', 'parent_id': 185},
    {'id': 40, 'name': 'Florida', 'parent_id': 185},
    {'id': 41, 'name': 'Georgia', 'parent_id': 185},
    {'id': 42, 'name': 'Hawaii', 'parent_id': 185},
    {'id': 43, 'name': 'Idaho', 'parent_id': 185},
    {'id': 44, 'name': 'Illinois', 'parent_id': 185},
    {'id': 45, 'name': 'Indiana', 'parent_id': 185},
    {'id': 46, 'name': 'Iowa', 'parent_id': 185},
    {'id': 47, 'name': 'Kansas', 'parent_id': 185},
    {'id': 48, 'name': 'Kentucky', 'parent_id': 185},
    {'id': 49, 'name': 'Louisiana', 'parent_id': 185},
    {'id': 50, 'name': 'Maine', 'parent_id': 185},
    {'id': 51, 'name': 'Maryland', 'parent_id': 185},
    {'id': 52, 'name': 'Massachusetts', 'parent_id': 185},
    {'id': 53, 'name': 'Michigan', 'parent_id': 185},
    {'id': 54, 'name': 'Minnesota', 'parent_id': 185},
    {'id': 55, 'name': 'Mississippi', 'parent_id': 185},
    {'id': 56, 'name': 'Missouri', 'parent_id': 185},
    {'id': 57, 'name': 'Montana', 'parent_id': 185},
    {'id': 58, 'name': 'Nebraska', 'parent_id': 185},
    {'id': 59, 'name': 'Nevada', 'parent_id': 185},
    {'id': 60, 'name': 'New Hampshire', 'parent_id': 185},
    {'id': 61, 'name': 'New Jersey', 'parent_id': 185},
    {'id': 62, 'name': 'New Mexico', 'parent_id': 185},
    {'id': 63, 'name': 'New York', 'parent_id': 185},
    {'id': 64, 'name': 'North Carolina', 'parent_id': 185},
    {'id': 65, 'name': 'North Dakota', 'parent_id': 185},
    {'id': 66, 'name': 'Ohio', 'parent_id': 185},
    {'id': 67, 'name': 'Oklahoma', 'parent_id': 185},
    {'id': 68, 'name': 'Oregon', 'parent_id': 185},
    {'id': 69, 'name': 'Pennsylvania', 'parent_id': 185},
    {'id': 70, 'name': 'Rhode Island', 'parent_id': 185},
    {'id': 71, 'name': 'South Carolina', 'parent_id': 185},
    {'id': 72, 'name': 'South Dakota', 'parent_id': 185},
    {'id': 73, 'name': 'Tennessee', 'parent_id': 185},
    {'id': 74, 'name': 'Texas', 'parent_id': 185},
    {'id': 75, 'name': 'Utah', 'parent_id': 185},
    {'id': 76, 'name': 'Vermont', 'parent_id': 185},
    {'id': 77, 'name': 'Virginia', 'parent_id': 185},
    {'id': 78, 'name': 'Washington', 'parent_id': 185},
    {'id': 79, 'name': 'West Virginia', 'parent_id': 185},
    {'id': 80, 'name': 'Wisconsin', 'parent_id': 185},
    {'id': 81, 'name': 'Wyoming', 'parent_id': 185},

    // Canada - Provinces & Territories
    {'id': 82, 'name': 'Alberta', 'parent_id': 32},
    {'id': 83, 'name': 'British Columbia', 'parent_id': 32},
    {'id': 84, 'name': 'Manitoba', 'parent_id': 32},
    {'id': 85, 'name': 'New Brunswick', 'parent_id': 32},
    {'id': 86, 'name': 'Newfoundland and Labrador', 'parent_id': 32},
    {'id': 87, 'name': 'Nova Scotia', 'parent_id': 32},
    {'id': 88, 'name': 'Ontario', 'parent_id': 32},
    {'id': 89, 'name': 'Prince Edward Island', 'parent_id': 32},
    {'id': 90, 'name': 'Quebec', 'parent_id': 32},
    {'id': 91, 'name': 'Saskatchewan', 'parent_id': 32},
    {'id': 92, 'name': 'Northwest Territories', 'parent_id': 32},
    {'id': 93, 'name': 'Nunavut', 'parent_id': 32},
    {'id': 94, 'name': 'Yukon', 'parent_id': 32},
  ];

  // ============================================================
  // CITIES
  // parent_id => state/province/region id
  // ============================================================

  static const List<Map<String, dynamic>> cities =
      <Map<String, dynamic>>[
    // Punjab
    {'id': 1, 'name': 'Lahore', 'parent_id': 1},
    {'id': 2, 'name': 'Rawalpindi', 'parent_id': 1},
    {'id': 3, 'name': 'Faisalabad', 'parent_id': 1},
    {'id': 4, 'name': 'Multan', 'parent_id': 1},
    {'id': 5, 'name': 'Gujranwala', 'parent_id': 1},
    {'id': 6, 'name': 'Sialkot', 'parent_id': 1},
    {'id': 7, 'name': 'Bahawalpur', 'parent_id': 1},
    {'id': 8, 'name': 'Sargodha', 'parent_id': 1},
    {'id': 9, 'name': 'Sheikhupura', 'parent_id': 1},
    {'id': 10, 'name': 'Jhelum', 'parent_id': 1},
    {'id': 11, 'name': 'Gujrat', 'parent_id': 1},
    {'id': 12, 'name': 'Sahiwal', 'parent_id': 1},
    {'id': 13, 'name': 'Okara', 'parent_id': 1},
    {'id': 14, 'name': 'Kasur', 'parent_id': 1},
    {'id': 15, 'name': 'Dera Ghazi Khan', 'parent_id': 1},
    {'id': 16, 'name': 'Mianwali', 'parent_id': 1},
    {'id': 17, 'name': 'Attock', 'parent_id': 1},
    {'id': 18, 'name': 'Chakwal', 'parent_id': 1},

    // Sindh
    {'id': 19, 'name': 'Karachi', 'parent_id': 2},
    {'id': 20, 'name': 'Hyderabad', 'parent_id': 2},
    {'id': 21, 'name': 'Sukkur', 'parent_id': 2},
    {'id': 22, 'name': 'Larkana', 'parent_id': 2},
    {'id': 23, 'name': 'Nawabshah', 'parent_id': 2},
    {'id': 24, 'name': 'Mirpur Khas', 'parent_id': 2},
    {'id': 25, 'name': 'Thatta', 'parent_id': 2},
    {'id': 26, 'name': 'Jacobabad', 'parent_id': 2},

    // Khyber Pakhtunkhwa
    {'id': 27, 'name': 'Peshawar', 'parent_id': 3},
    {'id': 28, 'name': 'Mardan', 'parent_id': 3},
    {'id': 29, 'name': 'Mingora', 'parent_id': 3},
    {'id': 30, 'name': 'Abbottabad', 'parent_id': 3},
    {'id': 31, 'name': 'Kohat', 'parent_id': 3},
    {'id': 32, 'name': 'Bannu', 'parent_id': 3},
    {'id': 33, 'name': 'Dera Ismail Khan', 'parent_id': 3},
    {'id': 34, 'name': 'Swabi', 'parent_id': 3},
    {'id': 35, 'name': 'Nowshera', 'parent_id': 3},

    // Balochistan
    {'id': 36, 'name': 'Quetta', 'parent_id': 4},
    {'id': 37, 'name': 'Gwadar', 'parent_id': 4},
    {'id': 38, 'name': 'Turbat', 'parent_id': 4},
    {'id': 39, 'name': 'Khuzdar', 'parent_id': 4},
    {'id': 40, 'name': 'Chaman', 'parent_id': 4},
    {'id': 41, 'name': 'Sibi', 'parent_id': 4},

    // Islamabad
    {'id': 42, 'name': 'Islamabad', 'parent_id': 5},

    // Gilgit-Baltistan
    {'id': 43, 'name': 'Gilgit', 'parent_id': 6},
    {'id': 44, 'name': 'Skardu', 'parent_id': 6},
    {'id': 45, 'name': 'Hunza', 'parent_id': 6},
    {'id': 46, 'name': 'Chilas', 'parent_id': 6},

    // Azad Kashmir
    {'id': 47, 'name': 'Muzaffarabad', 'parent_id': 7},
    {'id': 48, 'name': 'Mirpur', 'parent_id': 7},
    {'id': 49, 'name': 'Rawalakot', 'parent_id': 7},
    {'id': 50, 'name': 'Kotli', 'parent_id': 7},

    // UAE
    {'id': 51, 'name': 'Abu Dhabi', 'parent_id': 8},
    {'id': 52, 'name': 'Al Ain', 'parent_id': 8},
    {'id': 53, 'name': 'Dubai', 'parent_id': 9},
    {'id': 54, 'name': 'Sharjah', 'parent_id': 10},
    {'id': 55, 'name': 'Ajman', 'parent_id': 11},
    {'id': 56, 'name': 'Umm Al Quwain', 'parent_id': 12},
    {'id': 57, 'name': 'Ras Al Khaimah', 'parent_id': 13},
    {'id': 58, 'name': 'Fujairah', 'parent_id': 14},

    // Saudi Arabia
    {'id': 59, 'name': 'Riyadh', 'parent_id': 15},
    {'id': 60, 'name': 'Jeddah', 'parent_id': 16},
    {'id': 61, 'name': 'Makkah', 'parent_id': 16},
    {'id': 62, 'name': 'Madinah', 'parent_id': 17},
    {'id': 63, 'name': 'Dammam', 'parent_id': 18},
    {'id': 64, 'name': 'Khobar', 'parent_id': 18},
    {'id': 65, 'name': 'Abha', 'parent_id': 19},
    {'id': 66, 'name': 'Tabuk', 'parent_id': 20},
    {'id': 67, 'name': 'Buraydah', 'parent_id': 21},
    {'id': 68, 'name': 'Jazan', 'parent_id': 22},
    {'id': 69, 'name': 'Hail', 'parent_id': 23},
    {'id': 70, 'name': 'Najran', 'parent_id': 24},

    // UK
    {'id': 71, 'name': 'London', 'parent_id': 28},
    {'id': 72, 'name': 'Birmingham', 'parent_id': 28},
    {'id': 73, 'name': 'Manchester', 'parent_id': 28},
    {'id': 74, 'name': 'Liverpool', 'parent_id': 28},
    {'id': 75, 'name': 'Leeds', 'parent_id': 28},
    {'id': 76, 'name': 'Edinburgh', 'parent_id': 29},
    {'id': 77, 'name': 'Glasgow', 'parent_id': 29},
    {'id': 78, 'name': 'Cardiff', 'parent_id': 30},
    {'id': 79, 'name': 'Belfast', 'parent_id': 31},

    // USA
    {'id': 80, 'name': 'Los Angeles', 'parent_id': 36},
    {'id': 81, 'name': 'San Francisco', 'parent_id': 36},
    {'id': 82, 'name': 'San Diego', 'parent_id': 36},
    {'id': 83, 'name': 'New York City', 'parent_id': 63},
    {'id': 84, 'name': 'Buffalo', 'parent_id': 63},
    {'id': 85, 'name': 'Houston', 'parent_id': 74},
    {'id': 86, 'name': 'Dallas', 'parent_id': 74},
    {'id': 87, 'name': 'Austin', 'parent_id': 74},
    {'id': 88, 'name': 'Chicago', 'parent_id': 44},
    {'id': 89, 'name': 'Miami', 'parent_id': 40},
    {'id': 90, 'name': 'Orlando', 'parent_id': 40},
    {'id': 91, 'name': 'Washington, D.C.', 'parent_id': 185},

    // Canada
    {'id': 92, 'name': 'Toronto', 'parent_id': 88},
    {'id': 93, 'name': 'Ottawa', 'parent_id': 88},
    {'id': 94, 'name': 'Mississauga', 'parent_id': 88},
    {'id': 95, 'name': 'Vancouver', 'parent_id': 83},
    {'id': 96, 'name': 'Calgary', 'parent_id': 82},
    {'id': 97, 'name': 'Edmonton', 'parent_id': 82},
    {'id': 98, 'name': 'Montreal', 'parent_id': 89},
    {'id': 99, 'name': 'Quebec City', 'parent_id': 89},
  ];
static const List<Map<String, dynamic>> religions =
    <Map<String, dynamic>>[
  {'id': 1, 'name': 'Islam'},
  {'id': 2, 'name': 'Christianity'},
  {'id': 3, 'name': 'Hinduism'},
  {'id': 4, 'name': 'Buddhism'},
  {'id': 5, 'name': 'Sikhism'},
  {'id': 6, 'name': 'Judaism'},
  {'id': 7, 'name': 'Jainism'},
  {'id': 8, 'name': 'Baháʼí Faith'},
  {'id': 9, 'name': 'Shinto'},
  {'id': 10, 'name': 'Taoism'},
  {'id': 11, 'name': 'Confucianism'},
  {'id': 12, 'name': 'Zoroastrianism'},
  {'id': 13, 'name': 'Paganism'},
  {'id': 14, 'name': 'Rastafari'},
  {'id': 15, 'name': 'Animism'},
  {'id': 16, 'name': 'Indigenous Religions'},
  {'id': 17, 'name': 'African Traditional Religions'},
  {'id': 18, 'name': 'Chinese Folk Religion'},
  {'id': 19, 'name': 'Other'},
  {'id': 20, 'name': 'Prefer not to say'},
];

  // parent_id => religion id
// ============================================================
// CASTES / BIRADARIS
// parent_id => religion id
// 1 = Islam
// 2 = Christianity
// 3 = Hinduism
// 4 = Other
// ============================================================

static const List<Map<String, dynamic>> castes =
    <Map<String, dynamic>>[
  // ==========================================================
  // MUSLIM CASTES / BIRADARIS
  // ==========================================================

  {'id': 1, 'name': 'Syed', 'parent_id': 1},
  {'id': 2, 'name': 'Sheikh', 'parent_id': 1},
  {'id': 3, 'name': 'Mughal', 'parent_id': 1},
  {'id': 4, 'name': 'Rajput', 'parent_id': 1},
  {'id': 5, 'name': 'Jatt', 'parent_id': 1},
  {'id': 6, 'name': 'Arain', 'parent_id': 1},
  {'id': 7, 'name': 'Awan', 'parent_id': 1},
  {'id': 8, 'name': 'Gujjar', 'parent_id': 1},
  {'id': 9, 'name': 'Pathan / Pashtun', 'parent_id': 1},
  {'id': 10, 'name': 'Baloch', 'parent_id': 1},
  {'id': 11, 'name': 'Brahui', 'parent_id': 1},
  {'id': 12, 'name': 'Kashmiri', 'parent_id': 1},
  {'id': 13, 'name': 'Kakar', 'parent_id': 1},
  {'id': 14, 'name': 'Afridi', 'parent_id': 1},
  {'id': 15, 'name': 'Yousafzai', 'parent_id': 1},
  {'id': 16, 'name': 'Orakzai', 'parent_id': 1},
  {'id': 17, 'name': 'Khattak', 'parent_id': 1},
  {'id': 18, 'name': 'Shinwari', 'parent_id': 1},
  {'id': 19, 'name': 'Mohmand', 'parent_id': 1},
  {'id': 20, 'name': 'Wazir', 'parent_id': 1},
  {'id': 21, 'name': 'Mehsud', 'parent_id': 1},
  {'id': 22, 'name': 'Tareen', 'parent_id': 1},
  {'id': 23, 'name': 'Niazi', 'parent_id': 1},
  {'id': 24, 'name': 'Durrani', 'parent_id': 1},
  {'id': 25, 'name': 'Qureshi', 'parent_id': 1},
  {'id': 26, 'name': 'Ansari', 'parent_id': 1},
  {'id': 27, 'name': 'Siddiqui', 'parent_id': 1},
  {'id': 28, 'name': 'Farooqi', 'parent_id': 1},
  {'id': 29, 'name': 'Usmani', 'parent_id': 1},
  {'id': 30, 'name': 'Abbasi', 'parent_id': 1},
  {'id': 31, 'name': 'Malik', 'parent_id': 1},
  {'id': 32, 'name': 'Chaudhary', 'parent_id': 1},
  {'id': 33, 'name': 'Khan', 'parent_id': 1},
  {'id': 34, 'name': 'Memon', 'parent_id': 1},
  {'id': 35, 'name': 'Bohra', 'parent_id': 1},
  {'id': 36, 'name': 'Khoja', 'parent_id': 1},
  {'id': 37, 'name': 'Lohana', 'parent_id': 1},
  {'id': 38, 'name': 'Soomro', 'parent_id': 1},
  {'id': 39, 'name': 'Samma', 'parent_id': 1},
  {'id': 40, 'name': 'Junejo', 'parent_id': 1},
  {'id': 41, 'name': 'Jokhio', 'parent_id': 1},
  {'id': 42, 'name': 'Brohi', 'parent_id': 1},
  {'id': 43, 'name': 'Leghari', 'parent_id': 1},
  {'id': 44, 'name': 'Mazari', 'parent_id': 1},
  {'id': 45, 'name': 'Bugti', 'parent_id': 1},
  {'id': 46, 'name': 'Marri', 'parent_id': 1},
  {'id': 47, 'name': 'Mengal', 'parent_id': 1},
  {'id': 48, 'name': 'Rind', 'parent_id': 1},
  {'id': 49, 'name': 'Khoso', 'parent_id': 1},
  {'id': 50, 'name': 'Talpur', 'parent_id': 1},
  {'id': 51, 'name': 'Solangi', 'parent_id': 1},
  {'id': 52, 'name': 'Bajwa', 'parent_id': 1},
  {'id': 53, 'name': 'Gondal', 'parent_id': 1},
  {'id': 54, 'name': 'Cheema', 'parent_id': 1},
  {'id': 55, 'name': 'Sandhu', 'parent_id': 1},
  {'id': 56, 'name': 'Waraich', 'parent_id': 1},
  {'id': 57, 'name': 'Kahlon', 'parent_id': 1},
  {'id': 58, 'name': 'Randhawa', 'parent_id': 1},
  {'id': 59, 'name': 'Gujral', 'parent_id': 1},
  {'id': 60, 'name': 'Bhatti', 'parent_id': 1},
  {'id': 61, 'name': 'Chauhan', 'parent_id': 1},
  {'id': 62, 'name': 'Khichi', 'parent_id': 1},
  {'id': 63, 'name': 'Khokhar', 'parent_id': 1},
  {'id': 64, 'name': 'Gakhar', 'parent_id': 1},
  {'id': 65, 'name': 'Janjua', 'parent_id': 1},
  {'id': 66, 'name': 'Minhas', 'parent_id': 1},
  {'id': 67, 'name': 'Awan', 'parent_id': 1},
  {'id': 68, 'name': 'Kharal', 'parent_id': 1},
  {'id': 69, 'name': 'Sial', 'parent_id': 1},
  {'id': 70, 'name': 'Tiwana', 'parent_id': 1},
  {'id': 71, 'name': 'Nawaz', 'parent_id': 1},
  {'id': 72, 'name': 'Joya', 'parent_id': 1},
  {'id': 73, 'name': 'Dhareja', 'parent_id': 1},
  {'id': 74, 'name': 'Langrial', 'parent_id': 1},
  {'id': 75, 'name': 'Bodla', 'parent_id': 1},
  {'id': 76, 'name': 'Makhdoom', 'parent_id': 1},
  {'id': 77, 'name': 'Qazi', 'parent_id': 1},
  {'id': 78, 'name': 'Pirzada', 'parent_id': 1},
  {'id': 79, 'name': 'Dar', 'parent_id': 1},
  {'id': 80, 'name': 'Butt', 'parent_id': 1},
  {'id': 81, 'name': 'Mir', 'parent_id': 1},
  {'id': 82, 'name': 'Lone', 'parent_id': 1},
  {'id': 83, 'name': 'Bhat', 'parent_id': 1},
  {'id': 84, 'name': 'Wani', 'parent_id': 1},
  {'id': 85, 'name': 'Khan', 'parent_id': 1},
  {'id': 86, 'name': 'Other', 'parent_id': 1},

  // ==========================================================
  // CHRISTIAN COMMUNITIES
  // ==========================================================

  {'id': 87, 'name': 'Catholic', 'parent_id': 2},
  {'id': 88, 'name': 'Protestant', 'parent_id': 2},
  {'id': 89, 'name': 'Anglican', 'parent_id': 2},
  {'id': 90, 'name': 'Presbyterian', 'parent_id': 2},
  {'id': 91, 'name': 'Pentecostal', 'parent_id': 2},
  {'id': 92, 'name': 'Other Christian', 'parent_id': 2},

  // ==========================================================
  // HINDU COMMUNITIES
  // ==========================================================

  {'id': 93, 'name': 'Brahmin', 'parent_id': 3},
  {'id': 94, 'name': 'Rajput', 'parent_id': 3},
  {'id': 95, 'name': 'Baniya', 'parent_id': 3},
  {'id': 96, 'name': 'Lohana', 'parent_id': 3},
  {'id': 97, 'name': 'Khatri', 'parent_id': 3},
  {'id': 98, 'name': 'Meghwar', 'parent_id': 3},
  {'id': 99, 'name': 'Kohli', 'parent_id': 3},
  {'id': 100, 'name': 'Bheel', 'parent_id': 3},
  {'id': 101, 'name': 'Other Hindu', 'parent_id': 3},

  // ==========================================================
  // OTHER
  // ==========================================================

  {'id': 102, 'name': 'Other', 'parent_id': 4},
];


// ============================================================
// SUB-CASTES / CLANS
// parent_id => caste id
// ============================================================

static const List<Map<String, dynamic>> subCastes =
    <Map<String, dynamic>>[
  // ==========================================================
  // SYED
  // ==========================================================

  {'id': 1, 'name': 'Bukhari', 'parent_id': 1},
  {'id': 2, 'name': 'Gilani', 'parent_id': 1},
  {'id': 3, 'name': 'Rizvi', 'parent_id': 1},
  {'id': 4, 'name': 'Naqvi', 'parent_id': 1},
  {'id': 5, 'name': 'Kazmi', 'parent_id': 1},
  {'id': 6, 'name': 'Jafri', 'parent_id': 1},
  {'id': 7, 'name': 'Hussaini', 'parent_id': 1},
  {'id': 8, 'name': 'Tirmizi', 'parent_id': 1},

  // ==========================================================
  // SHEIKH
  // ==========================================================

  {'id': 9, 'name': 'Siddiqui', 'parent_id': 2},
  {'id': 10, 'name': 'Farooqi', 'parent_id': 2},
  {'id': 11, 'name': 'Usmani', 'parent_id': 2},
  {'id': 12, 'name': 'Abbasi', 'parent_id': 2},
  {'id': 13, 'name': 'Qureshi', 'parent_id': 2},
  {'id': 14, 'name': 'Ansari', 'parent_id': 2},

  // ==========================================================
  // MUGHAL
  // ==========================================================

  {'id': 15, 'name': 'Chughtai', 'parent_id': 3},
  {'id': 16, 'name': 'Mirza', 'parent_id': 3},
  {'id': 17, 'name': 'Baig', 'parent_id': 3},
  {'id': 18, 'name': 'Mughal', 'parent_id': 3},

  // ==========================================================
  // RAJPUT
  // ==========================================================

  {'id': 19, 'name': 'Bhatti', 'parent_id': 4},
  {'id': 20, 'name': 'Chauhan', 'parent_id': 4},
  {'id': 21, 'name': 'Janjua', 'parent_id': 4},
  {'id': 22, 'name': 'Minhas', 'parent_id': 4},
  {'id': 23, 'name': 'Gakhar', 'parent_id': 4},
  {'id': 24, 'name': 'Khichi', 'parent_id': 4},
  {'id': 25, 'name': 'Khokhar', 'parent_id': 4},
  {'id': 26, 'name': 'Jarral', 'parent_id': 4},
  {'id': 27, 'name': 'Sial', 'parent_id': 4},
  {'id': 28, 'name': 'Kharal', 'parent_id': 4},

  // ==========================================================
  // JATT
  // ==========================================================

  {'id': 29, 'name': 'Bajwa', 'parent_id': 5},
  {'id': 30, 'name': 'Cheema', 'parent_id': 5},
  {'id': 31, 'name': 'Sandhu', 'parent_id': 5},
  {'id': 32, 'name': 'Waraich', 'parent_id': 5},
  {'id': 33, 'name': 'Kahlon', 'parent_id': 5},
  {'id': 34, 'name': 'Randhawa', 'parent_id': 5},
  {'id': 35, 'name': 'Gondal', 'parent_id': 5},
  {'id': 36, 'name': 'Chatha', 'parent_id': 5},
  {'id': 37, 'name': 'Dhillon', 'parent_id': 5},
  {'id': 38, 'name': 'Gill', 'parent_id': 5},
  {'id': 39, 'name': 'Sidhu', 'parent_id': 5},
  {'id': 40, 'name': 'Maan', 'parent_id': 5},
  {'id': 41, 'name': 'Brar', 'parent_id': 5},
  {'id': 42, 'name': 'Aulakh', 'parent_id': 5},
  {'id': 43, 'name': 'Tarar', 'parent_id': 5},
  {'id': 44, 'name': 'Virk', 'parent_id': 5},

  // ==========================================================
  // ARAIN
  // ==========================================================

  {'id': 45, 'name': 'Chaudhary', 'parent_id': 6},
  {'id': 46, 'name': 'Mian', 'parent_id': 6},
  {'id': 47, 'name': 'Bhatti', 'parent_id': 6},
  {'id': 48, 'name': 'Randhawa', 'parent_id': 6},
  {'id': 49, 'name': 'Other Arain', 'parent_id': 6},

  // ==========================================================
  // AWAN
  // ==========================================================

  {'id': 50, 'name': 'Khattar', 'parent_id': 7},
  {'id': 51, 'name': 'Khokhar', 'parent_id': 7},
  {'id': 52, 'name': 'Malik', 'parent_id': 7},
  {'id': 53, 'name': 'Other Awan', 'parent_id': 7},

  // ==========================================================
  // GUJJAR
  // ==========================================================

  {'id': 54, 'name': 'Chechi', 'parent_id': 8},
  {'id': 55, 'name': 'Chauhan', 'parent_id': 8},
  {'id': 56, 'name': 'Bains', 'parent_id': 8},
  {'id': 57, 'name': 'Khatana', 'parent_id': 8},
  {'id': 58, 'name': 'Kasana', 'parent_id': 8},
  {'id': 59, 'name': 'Gorsi', 'parent_id': 8},
  {'id': 60, 'name': 'Bajar', 'parent_id': 8},
  {'id': 61, 'name': 'Other Gujjar', 'parent_id': 8},

  // ==========================================================
  // PATHAN / PASHTUN
  // ==========================================================

  {'id': 62, 'name': 'Yousafzai', 'parent_id': 9},
  {'id': 63, 'name': 'Afridi', 'parent_id': 9},
  {'id': 64, 'name': 'Khattak', 'parent_id': 9},
  {'id': 65, 'name': 'Orakzai', 'parent_id': 9},
  {'id': 66, 'name': 'Shinwari', 'parent_id': 9},
  {'id': 67, 'name': 'Mohmand', 'parent_id': 9},
  {'id': 68, 'name': 'Wazir', 'parent_id': 9},
  {'id': 69, 'name': 'Mehsud', 'parent_id': 9},
  {'id': 70, 'name': 'Kakar', 'parent_id': 9},
  {'id': 71, 'name': 'Tareen', 'parent_id': 9},
  {'id': 72, 'name': 'Niazi', 'parent_id': 9},
  {'id': 73, 'name': 'Durrani', 'parent_id': 9},
  {'id': 74, 'name': 'Achakzai', 'parent_id': 9},
  {'id': 75, 'name': 'Bettani', 'parent_id': 9},
  {'id': 76, 'name': 'Bangash', 'parent_id': 9},
  {'id': 77, 'name': 'Afridi', 'parent_id': 9},
  {'id': 78, 'name': 'Other Pashtun', 'parent_id': 9},

  // ==========================================================
  // BALOCH - MAJOR TRIBES / CLANS
  // ==========================================================

  {'id': 79, 'name': 'Rind', 'parent_id': 10},
  {'id': 80, 'name': 'Gopang', 'parent_id': 10},
  {'id': 81, 'name': 'Bugti', 'parent_id': 10},
  {'id': 82, 'name': 'Marri', 'parent_id': 10},
  {'id': 83, 'name': 'Mengal', 'parent_id': 10},
  {'id': 84, 'name': 'Mazari', 'parent_id': 10},
  {'id': 85, 'name': 'Leghari', 'parent_id': 10},
  {'id': 86, 'name': 'Khoso', 'parent_id': 10},
  {'id': 87, 'name': 'Buzdar', 'parent_id': 10},
  {'id': 88, 'name': 'Gichki', 'parent_id': 10},
  {'id': 89, 'name': 'Bizenjo', 'parent_id': 10},
  {'id': 90, 'name': 'Jamaldini', 'parent_id': 10},
  {'id': 91, 'name': 'Khetran', 'parent_id': 10},
  {'id': 92, 'name': 'Domki', 'parent_id': 10},
  {'id': 93, 'name': 'Umrani', 'parent_id': 10},
  {'id': 94, 'name': 'Noshwani', 'parent_id': 10},
  {'id': 95, 'name': 'Dashti', 'parent_id': 10},
  {'id': 96, 'name': 'Hooth', 'parent_id': 10},
  {'id': 97, 'name': 'Magsi', 'parent_id': 10},
  {'id': 98, 'name': 'Jatoi', 'parent_id': 10},
  {'id': 99, 'name': 'Buledi', 'parent_id': 10},
  {'id': 100, 'name': 'Kalmati', 'parent_id': 10},
  {'id': 101, 'name': 'Sanjrani', 'parent_id': 10},
  {'id': 102, 'name': 'Yalanzai', 'parent_id': 10},
  {'id': 103, 'name': 'Kurd', 'parent_id': 10},
  {'id': 104, 'name': 'Gurgnari', 'parent_id': 10},
  {'id': 105, 'name': 'Barkzai', 'parent_id': 10},
  {'id': 106, 'name': 'Sasoli', 'parent_id': 10},
  {'id': 107, 'name': 'Hassani', 'parent_id': 10},
  {'id': 108, 'name': 'Badini', 'parent_id': 10},
  {'id': 109, 'name': 'Rodeni', 'parent_id': 10},
  {'id': 110, 'name': 'Other Baloch', 'parent_id': 10},

  // ==========================================================
  // BRAHUI
  // ==========================================================

  {'id': 111, 'name': 'Mengal', 'parent_id': 11},
  {'id': 112, 'name': 'Bizanjo', 'parent_id': 11},
  {'id': 113, 'name': 'Zehri', 'parent_id': 11},
  {'id': 114, 'name': 'Bangulzai', 'parent_id': 11},
  {'id': 115, 'name': 'Sasoli', 'parent_id': 11},
  {'id': 116, 'name': 'Kurd', 'parent_id': 11},
  {'id': 117, 'name': 'Other Brahui', 'parent_id': 11},

  // ==========================================================
  // KASHMIRI
  // ==========================================================

  {'id': 118, 'name': 'Butt', 'parent_id': 12},
  {'id': 119, 'name': 'Dar', 'parent_id': 12},
  {'id': 120, 'name': 'Mir', 'parent_id': 12},
  {'id': 121, 'name': 'Lone', 'parent_id': 12},
  {'id': 122, 'name': 'Bhat', 'parent_id': 12},
  {'id': 123, 'name': 'Wani', 'parent_id': 12},
  {'id': 124, 'name': 'Khan', 'parent_id': 12},
  {'id': 125, 'name': 'Other Kashmiri', 'parent_id': 12},

  // ==========================================================
  // MEMON
  // ==========================================================

  {'id': 126, 'name': 'Halai Memon', 'parent_id': 34},
  {'id': 127, 'name': 'Kutchi Memon', 'parent_id': 34},
  {'id': 128, 'name': 'Sindhi Memon', 'parent_id': 34},
  {'id': 129, 'name': 'Other Memon', 'parent_id': 34},

  // ==========================================================
  // SINDHI COMMUNITIES
  // ==========================================================

  {'id': 130, 'name': 'Soomro', 'parent_id': 38},
  {'id': 131, 'name': 'Samma', 'parent_id': 39},
  {'id': 132, 'name': 'Junejo', 'parent_id': 40},
  {'id': 133, 'name': 'Jokhio', 'parent_id': 41},
  {'id': 134, 'name': 'Talpur', 'parent_id': 50},
  {'id': 135, 'name': 'Solangi', 'parent_id': 51},
  {'id': 136, 'name': 'Other Sindhi', 'parent_id': 38},

  // ==========================================================
  // HINDU COMMUNITIES
  // ==========================================================

  {'id': 137, 'name': 'Khatri', 'parent_id': 97},
  {'id': 138, 'name': 'Lohana', 'parent_id': 96},
  {'id': 139, 'name': 'Brahmin', 'parent_id': 93},
  {'id': 140, 'name': 'Meghwar', 'parent_id': 98},
  {'id': 141, 'name': 'Kohli', 'parent_id': 99},
  {'id': 142, 'name': 'Bheel', 'parent_id': 100},
  {'id': 143, 'name': 'Other Hindu', 'parent_id': 101},
];

  /// Maps a logical lookup key to its bundled dataset. Keys are the ones the
  /// API's `dropdown-reference-data` payload uses, so a bundled list is a
  /// drop-in replacement whenever that endpoint is unreachable.
  static const Map<String, List<Map<String, dynamic>>> byKey = <String, List<Map<String, dynamic>>>{
    'on_behalves': onBehalf,
    'gender': gender,
    'marital_statuses': maritalStatus,
    'languages': languages,
    'countries': countries,
    'states': states,
    'cities': cities,
    'religions': religions,
    'castes': castes,
    'sub_castes': subCastes,
  };
}

/// Canonical lookup keys — these are the exact keys returned by
/// `GET /api/v1/profile/dropdown-reference-data`.
class LookupKeys {
  const LookupKeys._();

  // ---- Dynamic (database-backed) -------------------------------------------
  static const String onBehalf = 'on_behalves';
  static const String genders = 'gender';
  static const String maritalStatuses = 'marital_statuses';
  static const String languages = 'languages';
  static const String countries = 'countries';
  static const String states = 'states';
  static const String cities = 'cities';
  static const String areas = 'areas';
  static const String religions = 'religions';
  static const String castes = 'castes';
  static const String subCastes = 'sub_castes';
  static const String sectMain = 'sect_main';
  static const String schoolOfThought = 'school_of_thought';
  static const String traditions = 'traditions';
  static const String educationLevels = 'education_levels';
  static const String degrees = 'degrees';
  static const String fieldsOfStudy = 'fields_of_study';
  static const String institutions = 'institutions';
  static const String professionCategories = 'profession_categories';
  static const String professions = 'professions';
  static const String hobbies = 'hobbies';

  // ---- Hardcoded lists (also served by the same endpoint) -------------------
  static const String marriageTimeline = 'marriage_timeline';
  static const String willingToWork = 'willing_to_work_after_marriage';
  static const String expectsSpouseToWork = 'expects_spouse_to_work';
  static const String diet = 'diet';
  static const String employmentStatus = 'employment_status';
  static const String educationStatus = 'education_status';
  static const String liveWithFamily = 'live_with_family';
  static const String familyValues = 'family_values';

  // ---- App-supplied lists ---------------------------------------------------
  // The reference endpoint returns neither of these, so they are generated
  // client-side by LookupRepository. The keys still follow the endpoint's
  // naming, so if the backend ever starts serving them the server copy wins
  // without any change here.

  /// The member's own annual income (`members.annual_income`, decimal).
  ///
  /// Superseded by [annualSalaryRanges] for registration: `/auth/register/steps`
  /// now lists `annual_salary_range_id` — not `annual_income` — as step 10's
  /// income field, and `POST /auth/register/complete` rejects a payload without
  /// it. The band list is kept because the profile still reports
  /// `career.annual_income`.
  static const String annualIncome = 'annual_income';

  /// Salary bands backing `annual_salary_range_id` (step 10 and the Career &
  /// Income section of profile edit).
  ///
  /// The backend owns these ids — `annual_salary_ranges` currently holds 16
  /// rows (1–16 validate, 17 and up are rejected). They are served under this
  /// key by `GET /profile/dropdown-reference-data`; the local list in
  /// [SalaryRangeOptions] is only a fallback for when that call has not
  /// happened yet.
  static const String annualSalaryRanges = 'annual_salary_ranges';

  /// Income bands offered for partner preferences (`income_min` / `income_max`).
  static const String partnerIncome = 'partner_annual_income';

  /// Brother / sister counts (`siblings_brothers`, `siblings_sisters`).
  static const String siblings = 'siblings';

  /// Lists that are safe (and useful) to warm up as soon as a token exists.
  static const List<String> preload = <String>[
    onBehalf,
    religions,
    languages,
    countries,
    maritalStatuses,
    castes,
    educationLevels,
    professionCategories,
    hobbies,
  ];
}

/// Fixed enum option lists for free-choice (non-ID) fields. These come straight
/// from the documented request samples, so they are safe to keep client-side.
class FieldOptions {
  const FieldOptions._();

  static const List<String> yesNo = <String>['yes', 'no'];
  static const List<String> childrenStatus = <String>[
    'No children',
    'Yes, living with me',
    'Yes, not living with me',
  ];
  static const List<String> complexion = <String>['Very Fair', 'Fair', 'Wheatish', 'Brown', 'Dark'];
  static const List<String> bodyType = <String>['Slim', 'Average', 'Athletic', 'Heavy'];
  static const List<String> personalityType = <String>['Introvert', 'Extrovert', 'Ambivert'];
  static const List<String> communicationStyle = <String>[
    'Calm',
    'Expressive',
    'Direct',
    'Reserved',
  ];
  static const List<String> loveLanguage = <String>[
    'Quality Time',
    'Words of Affirmation',
    'Acts of Service',
    'Physical Touch',
    'Receiving Gifts',
  ];
  static const List<String> conflictStyle = <String>[
    'Calm Discussion',
    'Compromise',
    'Give Space',
    'Seek Advice',
  ];
  static const List<String> lifeValues = <String>[
    'Honesty',
    'Respect',
    'Family First',
    'Faith',
    'Ambition',
    'Kindness',
    'Loyalty',
  ];
  static const List<String> personalValue = <String>[
    'Practicing',
    'Moderate',
    'Religious',
    'Spiritual',
    'Cultural',
  ];
  static const List<String> practiceLevel = <String>[
    'Practicing',
    'Moderate',
    'Occasional',
    'Non-practicing',
  ];
  static const List<String> prayerFrequency = <String>[
    'Five Times',
    'Sometimes',
    'Only Friday',
    'Rarely',
    'Never',
  ];
  static const List<String> educationLevel = <String>[
    'Matric',
    'Intermediate',
    'Bachelors',
    'Masters',
    'MPhil',
    'PhD',
    'Diploma',
  ];
  static const List<String> employmentStatus = <String>[
    'yes',
    'no',
    'student',
    'self-employed',
    'homemaker',
  ];
  static const List<String> familyType = <String>['Nuclear', 'Joint'];
  static const List<String> marriageTimeline = <String>[
    '3 Months',
    '6 Months',
    '1 Year',
    'Whenever right',
    'Undecided',
  ];
  static const List<String> childrenPreference = <String>['Want', 'Do not want', 'Open', 'Depends'];
  static const List<String> yesNoDepends = <String>['Yes', 'No', 'Depends'];
  static const List<String> financialResponsibility = <String>[
    'Husband',
    'Joint',
    'Shared as needed',
  ];
  static const List<String> diet = <String>['Halal', 'Vegetarian', 'Non-Vegetarian', 'Vegan'];
  static const List<String> livingWith = <String>['Family', 'Alone', 'Friends', 'Hostel'];
  static const List<String> expectationsAfterMarriage = <String>[
    'Career',
    'Separate Home',
    'Mutual Respect',
    'Live with Family',
    'Higher Studies',
  ];
  static const List<String> interests = <String>[
    'Reading',
    'Cooking',
    'Travel',
    'Photography',
    'Sports',
    'Music',
    'Art',
    'Gardening',
    'Volunteering',
  ];
  static const List<String> communicationPreferences = <String>[
    'chat',
    'voice call',
    'video call',
    'family first',
  ];
  static const List<String> proposalPreferences = <String>[
    'verified_only',
    'anyone',
    'family_managed',
  ];
  static const List<String> dealBreakers = <String>[
    'Smoking',
    'Alcohol',
    'Long Distance',
    'No Hijab',
    'Not Practicing',
    'Different Sect',
  ];
  static const List<String> relocationPreference = <String>['Yes', 'No', 'Depends'];
}
