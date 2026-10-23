import '../../constants/app_lookups.dart';
import '../../controllers/registration_payload.dart';
import '../../controllers/lookup_controller.dart';
import '../../core/storage/registration_buffer.dart';
import '../../models/lookup_item_model.dart';

/// Turns the registration answers buffered so far into the profile the Bio AI
/// service expects (`AppProfile`: canonical fields, human-readable values).
///
/// The buffer holds lookup ids (`degree_id: 12`); the model needs words
/// ("BS Computer Science"), so every id is resolved through the
/// [LookupController], falling back to the bundled [BundledLookups] tables.
/// Contact details, surname, CNIC, income and religion are never sent.
class BioAiProfile {
  const BioAiProfile._();

  static Future<Map<String, dynamic>> build(
    RegistrationBuffer b,
    LookupController lookup,
  ) async {
    Future<String?> name(String key, int? id, {int? parentId}) async {
      if (id == null || id <= 0) return null;
      await lookup.ensure(key, parentId: parentId);
      for (final List<LookupItem> items in <List<LookupItem>>[
        lookup.itemsOf(key, parentId: parentId),
        lookup.itemsOf(key),
      ]) {
        for (final LookupItem item in items) {
          if (item.id == id && item.name.trim().isNotEmpty) {
            return item.name.trim();
          }
        }
      }
      for (final Map<String, dynamic> row
          in BundledLookups.byKey[key] ?? const <Map<String, dynamic>>[]) {
        if (row['id'] == id) return row['name']?.toString();
      }
      return null;
    }

    final Map<String, dynamic> p = <String, dynamic>{};
    void put(String key, dynamic v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      if (v is List && v.isEmpty) return;
      p[key] = v is String ? v.trim() : v;
    }

    // Personal. Only the first name: the service writes "I'm <name>." itself.
    final String? first = RegPayload.fullName(b)?.split(' ').first;
    if (first != null &&
        RegExp(r"^[^\W\d_]{2,40}$", unicode: true).hasMatch(first)) {
      p['first_name'] = first[0].toUpperCase() + first.substring(1);
    }
    put('age', _age(b.getString('date_of_birth')));
    final String? gender = (await name(
      LookupKeys.genders,
      b.getInt('gender'),
    ))?.toLowerCase();
    if (gender == 'male' || gender == 'female') p['gender'] = gender;
    final int? stateId = b.getInt('state_id');
    put(
      'city',
      await name(LookupKeys.cities, b.getInt('city_id'), parentId: stateId),
    );
    put('country', await name(LookupKeys.countries, b.getInt('country_id')));
    put(
      'marital_status',
      await name(LookupKeys.maritalStatuses, b.getInt('marital_status_id')),
    );

    // Education: "BS Computer Science from FAST University (in progress)".
    final int? levelId = b.getInt('education_level_id');
    final String? degree =
        await name(
          LookupKeys.degrees,
          b.getInt('degree_id'),
          parentId: levelId,
        ) ??
        await name(LookupKeys.educationLevels, levelId);
    if (degree != null) {
      final String? field = await name(
        LookupKeys.fieldsOfStudy,
        b.getInt('field_of_study_id'),
        parentId: b.getInt('degree_id'),
      );
      final String? institution = await name(
        LookupKeys.institutions,
        b.getInt('institution_id'),
        parentId: b.getInt('country_id'),
      );
      final StringBuffer edu = StringBuffer(degree);
      if (field != null &&
          !degree.toLowerCase().contains(field.toLowerCase())) {
        edu.write(' in $field');
      }
      if (institution != null) edu.write(' from $institution');
      if (b.getString('education_status') == 'in_progress') {
        edu.write(' (in progress)');
      }
      put('education', <String>[edu.toString()]);
    }

    // Career: "Software Engineer at Systems Ltd, 5 years of experience".
    final String? title =
        _text(b.getString('job_title')) ??
        await name(
          LookupKeys.professions,
          b.getInt('profession_id'),
          parentId: b.getInt('profession_category_id'),
        );
    if (title != null) {
      final StringBuffer job = StringBuffer(title);
      final String? org = _text(b.getString('organization'));
      if (org != null) job.write(' at $org');
      final int years = b.getInt('years_of_experience') ?? 0;
      if (years > 0) {
        job.write(', $years ${years == 1 ? 'year' : 'years'} of experience');
      }
      put('profession', job.toString());
    }

    // Answers from later optional steps, if the user went back and forth.
    put('hobbies', b.getStringList('hobbies').take(8).toList());
    final String? values = _text(b.getString('family_values'));
    if (values != null) put('family_values', '$values family values');

    put('preferred_language', 'en');
    return p;
  }

  static String? _text(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  static int? _age(String? dob) {
    final DateTime? d = dob == null ? null : DateTime.tryParse(dob);
    if (d == null) return null;
    final DateTime now = DateTime.now();
    int age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return (age >= 18 && age <= 100) ? age : null;
  }
}
