/// English → Urdu translations for the registration flow.
///
/// The shared form widgets ([BiText] via FieldLabel / chips / StepScaffold)
/// look up their English copy here and render the Urdu line beneath it. Any
/// string that is absent simply shows English-only, so this map can grow
/// incrementally without risk.
///
/// Keys must match the English source strings EXACTLY (after trimming). For
/// multi-line concatenated strings, the key is the joined single-spaced result.
class AppUrdu {
  const AppUrdu._();

  /// Returns the Urdu translation for [en], or null when none is registered.
  static String? of(String? en) {
    if (en == null) return null;
    final String key = en.trim();
    if (key.isEmpty) return null;
    return _map[key];
  }

  static const Map<String, String> _map = <String, String>{
    // ---- Step titles --------------------------------------------------------
    'Account for': 'اکاؤنٹ کس کے لیے',
    'Basic information': 'بنیادی معلومات',
    'Religion & language': 'مذہب اور زبان',
    'Location': 'مقام',
    'Contact information': 'رابطہ کی معلومات',
    'Caste': 'ذات',
    'Marital status': 'ازدواجی حیثیت',
    'Education': 'تعلیم',
    'Physical information': 'جسمانی معلومات',
    'Career & income': 'پیشہ اور آمدنی',
    'Account security': 'اکاؤنٹ کی حفاظت',
    'Upload photos': 'تصاویر اپ لوڈ کریں',
    'About yourself': 'اپنے بارے میں',
    'Identity verification': 'شناخت کی تصدیق',
    'What are your interests?': 'آپ کی دلچسپیاں کیا ہیں؟',
    'Family information': 'خاندانی معلومات',
    'Family details': 'خاندان کی تفصیلات',
    'Partner preferences': 'شریکِ حیات کی ترجیحات',

    // ---- Subtitles ----------------------------------------------------------
    'Who is this profile being created for?': 'یہ پروفائل کس کے لیے بنائی جا رہی ہے؟',
    'Tell us your name and date of birth.': 'ہمیں اپنا نام اور تاریخِ پیدائش بتائیں۔',
    'Your faith and mother tongue.': 'آپ کا مذہب اور مادری زبان۔',
    'Where do you currently live?': 'آپ اس وقت کہاں رہتے ہیں؟',
    'We use this to secure your account.': 'ہم اسے آپ کے اکاؤنٹ کو محفوظ بنانے کے لیے استعمال کرتے ہیں۔',
    'Select the caste that best describes your community.':
        'وہ ذات منتخب کریں جو آپ کی برادری کی بہترین عکاسی کرے۔',
    'What is your current marital status?': 'آپ کی موجودہ ازدواجی حیثیت کیا ہے؟',
    'Your highest qualification.': 'آپ کی اعلیٰ ترین تعلیمی قابلیت۔',
    'Your height and dietary preference.': 'آپ کا قد اور کھانے کی ترجیح۔',
    'Your work and annual income.': 'آپ کا کام اور سالانہ آمدنی۔',
    'Create a strong password to protect your account.':
        'اپنے اکاؤنٹ کی حفاظت کے لیے مضبوط پاس ورڈ بنائیں۔',
    'You need to upload at least 3 photos to continue. You can change them later.':
        'جاری رکھنے کے لیے کم از کم 3 تصاویر اپ لوڈ کریں۔ آپ انہیں بعد میں تبدیل کر سکتے ہیں۔',
    'Write a short introduction (max 300 characters).':
        'مختصر تعارف لکھیں (زیادہ سے زیادہ 300 حروف)۔',
    'Verify your identity to earn a trusted badge.':
        'معتبر بیج حاصل کرنے کے لیے اپنی شناخت کی تصدیق کریں۔',
    'Select up to 15 interests to make your profile stand out!':
        'اپنی پروفائل کو نمایاں بنانے کے لیے 15 تک دلچسپیاں منتخب کریں!',
    'A little about your family (optional).': 'اپنے خاندان کے بارے میں مختصر (اختیاری)۔',
    'A little more about your family (optional).':
        'اپنے خاندان کے بارے میں کچھ مزید (اختیاری)۔',
    'Describe your ideal match.': 'اپنے مثالی رشتے کی وضاحت کریں۔',

    // ---- Info notes ---------------------------------------------------------
    'These details help us show you matches with compatible lifestyles and preferences.':
        'یہ تفصیلات ہمیں آپ کو ملتے جلتے طرزِ زندگی اور ترجیحات والے رشتے دکھانے میں مدد دیتی ہیں۔',
    'Private. Used only for account security.': 'نجی۔ صرف اکاؤنٹ کی حفاظت کے لیے۔',

    // ---- Help sheets --------------------------------------------------------
    'Choose whose profile this is. If it is for you, a friend or a relative, please also tell us the gender.':
        'منتخب کریں کہ یہ پروفائل کس کی ہے۔ اگر یہ آپ کی، کسی دوست یا رشتہ دار کی ہے تو براہِ کرم جنس بھی بتائیں۔',
    'Your email and phone must be unique. They are verified when you set your password in a later step.':
        'آپ کا ای میل اور فون منفرد ہونا چاہیے۔ ان کی تصدیق اُس وقت ہوتی ہے جب آپ اگلے مرحلے میں پاس ورڈ مقرر کرتے ہیں۔',
    'Your account is created at this step. If your email or phone is already registered, go back and update it.':
        'آپ کا اکاؤنٹ اسی مرحلے پر بنتا ہے۔ اگر آپ کا ای میل یا فون پہلے سے رجسٹرڈ ہے تو واپس جا کر اسے تبدیل کریں۔',
    'Use clear, recent photos of yourself. Avoid group photos for your main picture.':
        'اپنی واضح اور حالیہ تصاویر استعمال کریں۔ مرکزی تصویر کے لیے گروپ تصاویر سے گریز کریں۔',
    'Capture your CNIC (front and back) and a selfie. Your CNIC number is read automatically from the front image.':
        'اپنے شناختی کارڈ (آگے اور پیچھے) اور ایک سیلفی کھینچیں۔ آپ کا شناختی کارڈ نمبر سامنے والی تصویر سے خودکار پڑھ لیا جاتا ہے۔',

    // ---- Field labels -------------------------------------------------------
    'First name': 'پہلا نام',
    'Last name': 'آخری نام',
    'Date of birth': 'تاریخِ پیدائش',
    'This profile is for': 'یہ پروفائل کس کے لیے ہے',
    'Gender': 'جنس',
    'When are you planning to get married?': 'آپ شادی کب کرنے کا ارادہ رکھتے ہیں؟',
    'Will you continue working after marriage?': 'کیا آپ شادی کے بعد کام جاری رکھیں گی؟',
    'Do you expect your spouse to work after marriage?':
        'کیا آپ چاہتے ہیں کہ آپ کا شریکِ حیات شادی کے بعد کام کرے؟',
    'Religion': 'مذہب',
    'Language': 'زبان',
    'Country': 'ملک',
    'Province / State': 'صوبہ / ریاست',
    'City': 'شہر',
    'Area / Neighbourhood': 'علاقہ / محلہ',
    'Mobile number': 'موبائل نمبر',
    'Email address': 'ای میل ایڈریس',
    'Highest education': 'اعلیٰ ترین تعلیم',
    'College / University': 'کالج / یونیورسٹی',
    'Height': 'قد',
    'Diet': 'خوراک',
    'Annual income (PKR)': 'سالانہ آمدنی (روپے)',
    'Work category': 'کام کی نوعیت',
    'Profession': 'پیشہ',
    'Password': 'پاس ورڈ',
    'Confirm password': 'پاس ورڈ کی تصدیق',
    'CNIC front': 'شناختی کارڈ (سامنے)',
    'CNIC back': 'شناختی کارڈ (پیچھے)',
    'CNIC number (auto-detected)': 'شناختی کارڈ نمبر (خودکار)',
    'Selfie': 'سیلفی',
    "Father's occupation": 'والد کا پیشہ',
    "Mother's occupation": 'والدہ کا پیشہ',
    'Number of brothers': 'بھائیوں کی تعداد',
    'Number of sisters': 'بہنوں کی تعداد',
    'Family location': 'خاندان کا مقام',
    'Do you live with your family?': 'کیا آپ اپنے خاندان کے ساتھ رہتے ہیں؟',
    'Family financial status': 'خاندان کی مالی حیثیت',
    'Family country': 'خاندان کا ملک',
    'Family province / state': 'خاندان کا صوبہ / ریاست',
    'Family city': 'خاندان کا شہر',
    'Min age': 'کم از کم عمر',
    'Max age': 'زیادہ سے زیادہ عمر',
    'Min height': 'کم از کم قد',
    'Max height': 'زیادہ سے زیادہ قد',
    'Preferred marital status': 'پسندیدہ ازدواجی حیثیت',
    'Preferred religion / sect': 'پسندیدہ مذہب / فرقہ',
    'Preferred caste': 'پسندیدہ ذات',
    'Preferred mother tongue': 'پسندیدہ مادری زبان',
    'Preferred education': 'پسندیدہ تعلیم',
    'Preferred profession': 'پسندیدہ پیشہ',
    'Min income': 'کم از کم آمدنی',
    'Max income': 'زیادہ سے زیادہ آمدنی',
    'Profile managed by': 'پروفائل کا انتظام',
    'Preferred diet': 'پسندیدہ خوراک',

    // ---- Interest category headers (step 15) --------------------------------
    'Arts & Culture': 'فنون و ثقافت',
    'Sport': 'کھیل',
    'Food & Drink': 'کھانا پینا',
    'Fitness & Wellness': 'فٹنس اور صحت',
    'Going Out': 'باہر گھومنا',

    // ---- Auth: login & forgot-password --------------------------------------
    'Welcome back': 'خوش آمدید',
    'Sign in to continue your journey': 'اپنے سفر کو جاری رکھنے کے لیے سائن اِن کریں',
    'Login': 'لاگ اِن',
    'Email': 'ای میل',
    'Forgot password?': 'پاس ورڈ بھول گئے؟',
    "Don't have?": 'اکاؤنٹ نہیں ہے؟',
    'Create Account': 'اکاؤنٹ بنائیں',
    'Already registered?': 'پہلے سے رجسٹرڈ ہیں؟',
    'Mobile OTP': 'موبائل او ٹی پی',
    'or': 'یا',
    'With Google': 'گوگل کے ساتھ جاری رکھیں',
    'Send OTP': 'او ٹی پی بھیجیں',
    'OTP code': 'او ٹی پی کوڈ',
    'Verify & Login': 'تصدیق کریں اور لاگ اِن ہوں',
    'Change number / resend': 'نمبر تبدیل کریں / دوبارہ بھیجیں',
    'Reset password': 'پاس ورڈ ری سیٹ کریں',
    'Forgot your password?': 'اپنا پاس ورڈ بھول گئے؟',
    'Enter OTP & new password': 'او ٹی پی اور نیا پاس ورڈ درج کریں',
    'We sent a one-time code to your email. Enter it with your new password.':
        'ہم نے آپ کے ای میل پر ایک بار کا کوڈ بھیجا ہے۔ اسے اپنے نئے پاس ورڈ کے ساتھ درج کریں۔',
    'Enter your registered email and we will send you an OTP to reset your password.':
        'اپنا رجسٹرڈ ای میل درج کریں، ہم آپ کو پاس ورڈ ری سیٹ کرنے کے لیے او ٹی پی بھیجیں گے۔',
    'New password': 'نیا پاس ورڈ',
    'Confirm new password': 'نئے پاس ورڈ کی تصدیق',
    'Change email / resend OTP': 'ای میل تبدیل کریں / او ٹی پی دوبارہ بھیجیں',

    // ---- Onboarding -----------------------------------------------------------
    'Find Your Perfect Match': 'اپنا مثالی جوڑ تلاش کریں',
    'Meet Couples on Our App': 'ہمارے ایپ پر جوڑے تلاش کریں',
    'Revitalize Your Marriage': 'اپنی ازدواجی زندگی کو نئی زندگی دیں',
    'Marriage Made Easy': 'شادی کو آسان بنائیں',
    'Forever and always, together as one': 'ہمیشہ اور ہمیشہ کے لیے، ایک ساتھ',
    'We may not have it all together, but together we have it all':
        'شاید ہمارے پاس سب کچھ نہ ہو، لیکن ساتھ مل کر ہمارے پاس سب کچھ ہے',
    'Get Started': 'شروع کریں',

    // ---- Buttons & common UI ------------------------------------------------
    'Continue': 'جاری رکھیں',
    'Back': 'واپس',
    'Done': 'ہو گیا',
    'Finish': 'مکمل کریں',
    'Create account': 'اکاؤنٹ بنائیں',
    'Add photos': 'تصاویر شامل کریں',
    'Skip': 'چھوڑ دیں',
    'Save': 'محفوظ کریں',
    'Tap to upload': 'اپ لوڈ کرنے کے لیے دبائیں',
    'Interests': 'دلچسپیاں',
    'Select interests': 'دلچسپیاں منتخب کریں',

    // ---- Profile completion (skipped sections) ------------------------------
    'Complete your profile': 'اپنی پروفائل مکمل کریں',
    'Marriage plans': 'شادی کے منصوبے',
    'Sections you can still complete': 'وہ حصے جو آپ اب بھی مکمل کر سکتے ہیں',
    'Everything is filled in': 'سب کچھ مکمل ہو چکا ہے',
    'Your profile is complete.': 'آپ کی پروفائل مکمل ہے۔',
    'Complete the remaining sections to get better matches.':
        'بہتر رشتے پانے کے لیے باقی حصے مکمل کریں۔',
    'You skipped some sections. You can complete them anytime from your profile.':
        'آپ نے کچھ حصے چھوڑ دیے تھے۔ آپ انہیں کسی بھی وقت اپنی پروفائل سے مکمل کر سکتے ہیں۔',
    'Please fill in at least one field before saving.':
        'محفوظ کرنے سے پہلے کم از کم ایک خانہ ضرور بھریں۔',
    'Add your religion first — the caste list depends on it.':
        'پہلے اپنا مذہب شامل کریں — ذات کی فہرست اسی پر منحصر ہے۔',

    // ---- Options: account for (step 1) --------------------------------------
    'Myself': 'میں خود',
    'My Son': 'میرا بیٹا',
    'My Daughter': 'میری بیٹی',
    'My Brother': 'میرا بھائی',
    'My Sister': 'میری بہن',
    'My Friend': 'میرا دوست',
    'My Relative': 'میرا رشتہ دار',

    // ---- Options: gender ----------------------------------------------------
    'Male': 'مرد',
    'Female': 'عورت',

    // ---- Options: marriage timeline -----------------------------------------
    'Immediate': 'فوری',
    'Within 3 Months': '3 ماہ کے اندر',
    'Within 6 Months': '6 ماہ کے اندر',
    '1 Year': '1 سال',

    // ---- Options: work intent / yes-no --------------------------------------
    'Yes': 'جی ہاں',
    'No': 'نہیں',
    'Depends on Mutual Understanding': 'باہمی رضامندی پر منحصر',

    // ---- Options: marital status --------------------------------------------
    'Never Married': 'کبھی شادی نہیں ہوئی',
    'Divorced': 'طلاق یافتہ',
    'Widow / Widower': 'بیوہ / رنڈوا',
    'Awaiting Divorce': 'طلاق کے انتظار میں',

    // ---- Options: education -------------------------------------------------
    'Matric': 'میٹرک',
    'Intermediate': 'انٹرمیڈیٹ',
    'Diploma': 'ڈپلومہ',
    'Bachelors': 'بیچلرز',
    'Masters': 'ماسٹرز',
    'MPhil': 'ایم فل',
    'PhD': 'پی ایچ ڈی',

    // ---- Options: diet ------------------------------------------------------
    'Vegetarian': 'سبزی خور',
    'Non-Vegetarian': 'گوشت خور',

    // ---- Options: work category ---------------------------------------------
    'Government': 'سرکاری',
    'Private': 'نجی',
    'Civil': 'سول',
    'Defence': 'دفاع',
    'Self-Employed': 'خود کاروبار',

    // ---- Options: family financial status -----------------------------------
    'Elite': 'اعلیٰ طبقہ',
    'High': 'بلند',
    'Middle': 'متوسط',
    'Aspiring': 'ترقی پذیر',
    'Poor': 'کمزور',

    // ---- Options: partner pick-lists ----------------------------------------
    'Any': 'کوئی بھی',
    'Matric or above': 'میٹرک یا اس سے زیادہ',
    'Intermediate or above': 'انٹرمیڈیٹ یا اس سے زیادہ',
    'Bachelors or above': 'بیچلرز یا اس سے زیادہ',
    'Masters or above': 'ماسٹرز یا اس سے زیادہ',
    'Business / Self-Employed': 'کاروبار / خود روزگار',
    'Professional (Doctor/Engineer/Lawyer)': 'پیشہ ور (ڈاکٹر/انجینئر/وکیل)',

    // ---- Options: profile managed by ----------------------------------------
    'Self': 'خود',
    'Parents': 'والدین',
    'Sibling': 'بہن بھائی',
    'Relative': 'رشتہ دار',
    'Guardian': 'سرپرست',

    // ---- Section titles (step 18) & misc step content ----------------------
    'Preferred age range': 'پسندیدہ عمر کی حد',
    'Preferred height range': 'پسندیدہ قد کی حد',
    'Community': 'برادری',
    'Preferred location': 'پسندیدہ مقام',
    'Preferred annual income (PKR)': 'پسندیدہ سالانہ آمدنی (روپے)',
    'Other preferences': 'دیگر ترجیحات',
    'Main': 'مرکزی',
    'Reading CNIC number…': 'شناختی کارڈ نمبر پڑھا جا رہا ہے…',

    // ---- Step-level validation messages (shown in the error banner) ---------
    'Please choose who this profile is for.': 'براہِ کرم منتخب کریں کہ یہ پروفائل کس کے لیے ہے۔',
    'Please select a gender.': 'براہِ کرم جنس منتخب کریں۔',
    'Please choose when you plan to get married.':
        'براہِ کرم منتخب کریں کہ آپ شادی کب کرنا چاہتے ہیں۔',
    'Please answer whether you will work after marriage.':
        'براہِ کرم بتائیں کہ کیا آپ شادی کے بعد کام کریں گی۔',
    'Please answer the spouse-work question.':
        'براہِ کرم شریکِ حیات کے کام سے متعلق سوال کا جواب دیں۔',
    'Please select your religion.': 'براہِ کرم اپنا مذہب منتخب کریں۔',
    'Please select your language.': 'براہِ کرم اپنی زبان منتخب کریں۔',
    'Please select your country, province and city.':
        'براہِ کرم اپنا ملک، صوبہ اور شہر منتخب کریں۔',
    'Please select your caste.': 'براہِ کرم اپنی ذات منتخب کریں۔',
    'Please select your marital status.': 'براہِ کرم اپنی ازدواجی حیثیت منتخب کریں۔',
    'Please select your highest education.': 'براہِ کرم اپنی اعلیٰ ترین تعلیم منتخب کریں۔',
    'Please select your height.': 'براہِ کرم اپنا قد منتخب کریں۔',
    'Please select your diet.': 'براہِ کرم اپنی خوراک منتخب کریں۔',
    'Please select your work category.': 'براہِ کرم اپنے کام کی نوعیت منتخب کریں۔',
    'Please select your profession.': 'براہِ کرم اپنا پیشہ منتخب کریں۔',
    'Please add at least 3 photos (1 main + 2 more).':
        'براہِ کرم کم از کم 3 تصاویر شامل کریں (1 مرکزی + 2 مزید)۔',
    'Please capture the CNIC front, back and a selfie.':
        'براہِ کرم شناختی کارڈ کا سامنے، پیچھے اور ایک سیلفی کھینچیں۔',
    'Please select a preferred height range.': 'براہِ کرم پسندیدہ قد کی حد منتخب کریں۔',
    'Minimum height cannot exceed the maximum.':
        'کم از کم قد زیادہ سے زیادہ سے بڑھ نہیں سکتا۔',
    'Please select a preferred marital status.':
        'براہِ کرم پسندیدہ ازدواجی حیثیت منتخب کریں۔',
    'Please select a preferred religion.': 'براہِ کرم پسندیدہ مذہب منتخب کریں۔',
    'Please select preferred education and profession.':
        'براہِ کرم پسندیدہ تعلیم اور پیشہ منتخب کریں۔',
    'Minimum age cannot exceed the maximum.': 'کم از کم عمر زیادہ سے زیادہ سے بڑھ نہیں سکتی۔',
    'Age must be between 18 and 99.': 'عمر 18 اور 99 کے درمیان ہونی چاہیے۔',
    'Please select a preferred education.': 'براہِ کرم پسندیدہ تعلیم منتخب کریں۔',
    'Please select a preferred profession.': 'براہِ کرم پسندیدہ پیشہ منتخب کریں۔',
    'Minimum income cannot exceed the maximum.':
        'کم از کم آمدنی زیادہ سے زیادہ سے بڑھ نہیں سکتی۔',

    // ---- Interests (step 15 chips, emoji preserved on English line) ---------
    '🎭 Acting': 'اداکاری',
    '🍿 Anime': 'اینیمے',
    '🖼️ Art galleries': 'آرٹ گیلریاں',
    '🎲 Board games': 'بورڈ گیمز',
    '✍️ Creative writing': 'تخلیقی تحریر',
    '🎨 Design': 'ڈیزائن',
    '🪚 DIY': 'خود سازی',
    '👗 Fashion': 'فیشن',
    '🎥 Film & Cinema': 'فلم و سنیما',
    '🎼 Live music': 'زندہ موسیقی',
    '🏛️ Museums': 'عجائب گھر',
    '📷 Photography': 'فوٹوگرافی',
    '🌍 Learning languages': 'زبانیں سیکھنا',
    '🏈 American football': 'امریکن فٹبال',
    '🏸 Badminton': 'بیڈمنٹن',
    '🏏 Cricket': 'کرکٹ',
    '🏀 Basketball': 'باسکٹ بال',
    '🥊 Boxing': 'باکسنگ',
    '🚴 Cycling': 'سائیکلنگ',
    '💃 Dancing': 'رقص',
    '⛳ Golf': 'گالف',
    '🏋️ Gym': 'جِم',
    '🏇 Horse Riding': 'گھڑ سواری',
    '🏊 Swimming': 'تیراکی',
    '🎾 Tennis': 'ٹینس',
    '🧘 Yoga': 'یوگا',
    '🧁 Baking': 'بیکنگ',
    '🧋 Bubble tea': 'ببل ٹی',
    '🍫 Chocolate': 'چاکلیٹ',
    '☕ Coffee': 'کافی',
    '👨‍🍳 Cooking': 'کھانا پکانا',
    '🍽️ Eating out': 'باہر کھانا',
    '🥗 Healthy eating': 'صحت مند کھانا',
    '🍔 Junk food': 'جنک فوڈ',
    '🍕 Pizza': 'پیزا',
    '🍣 Sushi': 'سوشی',
    '🌱 Vegetarian': 'سبزی خور',
    '🏃 Running': 'دوڑنا',
    '🥾 Hiking': 'پیدل سفر',
    '🧘‍♀️ Meditation': 'مراقبہ',
    '🚶 Walking': 'چہل قدمی',
    '🤸 Calisthenics': 'جسمانی ورزش',
    '🥤 Nutrition': 'غذائیت',
    '🎬 Movies': 'فلمیں',
    '🛍️ Shopping': 'خریداری',
    '🌳 Nature': 'قدرت',
    '✈️ Travel': 'سفر',
    '🏖️ Beaches': 'ساحل',
    '🎡 Theme parks': 'تفریحی پارک',
  };
}
