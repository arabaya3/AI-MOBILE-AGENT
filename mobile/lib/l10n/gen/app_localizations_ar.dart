// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'TEIA AI';

  @override
  String get previewTitle => 'معاينة الأساس';

  @override
  String get previewIntro =>
      'يعرض هذا الإصدار الأساس المرئي للتطبيق فقط. سيتوفر تسجيل الدخول والمحادثة والمستندات والإدارة في إصدارات لاحقة.';

  @override
  String get sectionAppearance => 'المظهر';

  @override
  String get themeLabel => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageSystem => 'لغة الجهاز';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get sectionComponents => 'المكوّنات';

  @override
  String get componentsNote => 'نماذج فقط. لا تنفّذ عناصر التحكم هذه أي إجراء.';

  @override
  String get sampleFilledButton => 'النمط الأساسي';

  @override
  String get sampleOutlinedButton => 'النمط الثانوي';

  @override
  String get sampleTextButton => 'نمط النص';

  @override
  String get sampleFieldLabel => 'حقل تجريبي';

  @override
  String get sampleFieldHint => 'اكتب بالعربية أو الإنجليزية';

  @override
  String get sampleFieldHelper => 'يتبع اتجاه النص ما تكتبه.';

  @override
  String get bannerInfoTitle => 'معلومة';

  @override
  String get bannerInfoBody => 'تُعرض التحديثات العامة بهذا النمط.';

  @override
  String get bannerSuccessTitle => 'تم بنجاح';

  @override
  String get bannerSuccessBody => 'تُعرض الإجراءات المكتملة بهذا النمط.';

  @override
  String get bannerWarningTitle => 'تنبيه';

  @override
  String get bannerWarningBody =>
      'تُعرض الحالات التي تتطلب الانتباه بهذا النمط.';

  @override
  String get bannerErrorTitle => 'خطأ';

  @override
  String get bannerErrorBody =>
      'تُعرض حالات الفشل بهذا النمط مع إجراء للمعالجة.';

  @override
  String get sectionStates => 'حالات الشاشة';

  @override
  String get loadingLabel => 'جارٍ التحميل';

  @override
  String get emptyTitle => 'لا يوجد شيء بعد';

  @override
  String get emptyBody => 'سيظهر المحتوى هنا عند توفره.';

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get retryLabel => 'إعادة المحاولة';

  @override
  String get sectionMixedText => 'محتوى متعدد اللغات';

  @override
  String get mixedTextNote =>
      'تحتفظ كل رسالة باتجاهها الخاص بغض النظر عن لغة التطبيق.';

  @override
  String get sectionUpcoming => 'قادم في إصدارات لاحقة';

  @override
  String get upcomingChat => 'المحادثة';

  @override
  String get upcomingDocuments => 'المستندات';

  @override
  String get upcomingSpaceAdmin => 'إدارة مساحة العمل';

  @override
  String get notAvailableYet => 'غير متاح بعد';

  @override
  String get sectionDeveloper => 'إصدار المطوّرين';

  @override
  String get developerEnvironment => 'البيئة';

  @override
  String get developerApiBase => 'عنوان واجهة البرمجة';

  @override
  String get sessionExpiredMessage =>
      'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get configErrorTitle => 'لا يمكن تشغيل هذا الإصدار';

  @override
  String get configErrorBody =>
      'لم يُضبط التطبيق بعنوان خادم آمن، لذلك لن يتصل بأي خدمة.';

  @override
  String get errorNetwork =>
      'يبدو أنك غير متصل بالإنترنت. تحقّق من اتصالك ثم حاول مرة أخرى.';

  @override
  String get errorTimeout =>
      'استغرق الخادم وقتًا طويلًا للرد. يرجى المحاولة مرة أخرى.';

  @override
  String get errorCancelled => 'أُلغي الطلب.';

  @override
  String get errorInsecure => 'تعذّر إنشاء اتصال آمن بالخادم.';

  @override
  String get errorSessionExpired => 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errorForbidden => 'ليست لديك صلاحية للقيام بذلك.';

  @override
  String get errorNotFound => 'تعذّر العثور على ما تبحث عنه.';

  @override
  String get errorConflict => 'يتعارض هذا مع بيانات موجودة.';

  @override
  String get errorTooLarge => 'حجم الملف كبير جدًا.';

  @override
  String get errorValidation => 'بعض البيانات تحتاج إلى تصحيح.';

  @override
  String get errorRateLimited =>
      'طلبات كثيرة جدًا. يرجى الانتظار قليلًا ثم المحاولة مرة أخرى.';

  @override
  String get errorQuota => 'لقد بلغت حد الاستخدام المسموح لك.';

  @override
  String get errorServer => 'الخدمة غير متاحة مؤقتًا. يرجى المحاولة لاحقًا.';

  @override
  String get errorUnexpected => 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get signInSubtitle => 'استخدم حسابك في TEIA للمتابعة.';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get signInAction => 'تسجيل الدخول';

  @override
  String get forgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get createAccountLink => 'إنشاء حساب';

  @override
  String get errorInactiveAccount => 'هذا الحساب غير مفعّل. تواصل مع المسؤول.';

  @override
  String get signedOutNotice => 'سجّلت الخروج من هذا الجهاز.';

  @override
  String get registerTitle => 'إنشاء حسابك';

  @override
  String get firstNameLabel => 'الاسم الأول';

  @override
  String get lastNameLabel => 'اسم العائلة';

  @override
  String get companyLabel => 'الشركة';

  @override
  String get jobTitleLabel => 'المسمّى الوظيفي';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get passwordHelper => '8 أحرف على الأقل.';

  @override
  String get optionalDetails => 'تفاصيل اختيارية';

  @override
  String get registerAction => 'إنشاء الحساب';

  @override
  String get haveAccountLink => 'لدي حساب بالفعل';

  @override
  String get errorEmailTaken => 'يوجد حساب مسجّل بهذا البريد الإلكتروني.';

  @override
  String get registeredSignInFailed => 'تم إنشاء حسابك. سجّل الدخول للمتابعة.';

  @override
  String get validationRequired => 'هذا الحقل مطلوب.';

  @override
  String get validationEmail => 'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get validationPasswordLength => 'استخدم 8 أحرف على الأقل.';

  @override
  String get validationPasswordMatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get forgotTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotBody =>
      'أدخل البريد الإلكتروني لحسابك. إذا كان الحساب موجودًا فسنرسل رابط إعادة التعيين.';

  @override
  String get sendResetLink => 'إرسال رابط إعادة التعيين';

  @override
  String get forgotSent =>
      'إذا كان هناك حساب بهذا البريد فسيصلك رابط إعادة التعيين قريبًا. تنتهي صلاحيته خلال ساعة.';

  @override
  String get haveResetLink => 'لدي رابط إعادة تعيين';

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get resetTitle => 'اختر كلمة مرور جديدة';

  @override
  String get resetCodeLabel => 'رابط إعادة التعيين';

  @override
  String get resetCodeHelper => 'الصق الرابط من رسالة إعادة التعيين.';

  @override
  String get resetCodeInvalid => 'هذا ليس رابط إعادة تعيين صالحًا.';

  @override
  String get resetLinkReady => 'تم استلام رابط إعادة التعيين.';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get resetAction => 'تحديث كلمة المرور';

  @override
  String get resetLinkExpired =>
      'رابط إعادة التعيين غير صالح أو منتهي الصلاحية. اطلب رابطًا جديدًا.';

  @override
  String get resetDone =>
      'تم تحديث كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.';

  @override
  String get requestNewLink => 'طلب رابط جديد';

  @override
  String get sessionProblemTitle => 'تعذّر التحقق من جلستك';

  @override
  String get sessionProblemOffline =>
      'تحقّق من اتصالك ثم حاول مرة أخرى. ما زلت مسجّل الدخول على هذا الجهاز.';

  @override
  String get sessionProblemServer => 'لم تستجب الخدمة. حاول مرة أخرى بعد قليل.';

  @override
  String get sessionProblemStorage =>
      'تعذّرت قراءة التخزين الآمن على هذا الجهاز.';

  @override
  String get signOutAction => 'تسجيل الخروج';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountDetails => 'تفاصيل الحساب';

  @override
  String get roleLabel => 'الدور';

  @override
  String get roleViewer => 'عضو';

  @override
  String get roleAdmin => 'مسؤول';

  @override
  String get roleSuperAdmin => 'مسؤول أعلى';

  @override
  String get changePasswordAction => 'تغيير كلمة المرور';

  @override
  String get signOutConfirmTitle => 'تسجيل الخروج من هذا الجهاز؟';

  @override
  String get signOutConfirmBody =>
      'ستُزال جلستك من هذا الجهاز. تبقى الجلسة الصادرة سابقًا صالحة على الخادم حتى تنتهي صلاحيتها.';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get designPreview => 'معاينة التصميم';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get currentPasswordLabel => 'كلمة المرور الحالية';

  @override
  String get errorCurrentPassword => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور.';

  @override
  String get persistenceFailedNotice =>
      'تعذّر على هذا الجهاز حفظ جلستك بأمان. قد تحتاج إلى تسجيل الدخول مرة أخرى لاحقًا.';

  @override
  String get spacesTitle => 'اختر مساحة العمل';

  @override
  String get spacesSubtitle => 'تفصل مساحات العمل مستندات ومحادثات كل فريق.';

  @override
  String get spacesYours => 'مساحات العمل الخاصة بك';

  @override
  String get spacesNoneTitle => 'لا توجد مساحة عمل بعد';

  @override
  String get spacesNoneBody =>
      'اطلب دعوة من المسؤول، أو اطلب الانضمام إلى إحدى المساحات أدناه.';

  @override
  String get spacesAvailable => 'مساحات عمل أخرى';

  @override
  String get spacesAvailableEmpty => 'لا توجد مساحات أخرى متاحة للطلب.';

  @override
  String get requestAccess => 'طلب الانضمام';

  @override
  String get accessPending => 'الطلب قيد المراجعة';

  @override
  String get accessRequested => 'أُرسل طلبك إلى مسؤولي مساحة العمل.';

  @override
  String get spaceAccessLost =>
      'لم تعد لديك صلاحية الوصول إلى مساحة العمل السابقة. اختر مساحة أخرى.';

  @override
  String get haveInvitation => 'لديك دعوة؟';

  @override
  String get inviteCodeLabel => 'رابط الدعوة';

  @override
  String get inviteCodeInvalid => 'هذا ليس رابط دعوة صالحًا.';

  @override
  String get inviteTitle => 'الانضمام إلى مساحة عمل';

  @override
  String get inviteBody =>
      'اقبل هذه الدعوة للانضمام إلى مساحة العمل باستخدام الحساب الذي سجّلت الدخول به.';

  @override
  String get inviteAction => 'قبول الدعوة';

  @override
  String get inviteAccepted => 'انضممت إلى مساحة العمل.';

  @override
  String get inviteInvalid =>
      'هذه الدعوة غير صالحة أو منتهية أو مرسلة إلى بريد إلكتروني آخر.';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get spaceRoleAdmin => 'مسؤول مساحة العمل';

  @override
  String get spaceRoleMember => 'عضو';

  @override
  String get switchSpace => 'تبديل مساحة العمل';

  @override
  String get currentSpace => 'مساحة العمل الحالية';

  @override
  String homeGreeting(String name) {
    return 'مرحبًا، $name';
  }

  @override
  String homeSignedInAs(String email) {
    return 'مسجّل الدخول باسم $email';
  }

  @override
  String get spaceRoleLabel => 'دورك في مساحة العمل';

  @override
  String get uploadsLabel => 'رفع المستندات';

  @override
  String get uploadsAllowed => 'مسموح';

  @override
  String get uploadsNotAllowed => 'غير مسموح';

  @override
  String get selectSpaceAction => 'فتح';

  @override
  String get continueAction => 'متابعة';

  @override
  String get nameLabel => 'الاسم';

  @override
  String get chatTitle => 'المحادثات';

  @override
  String get newConversation => 'محادثة جديدة';

  @override
  String get chatEmptyTitle => 'لا توجد محادثات بعد';

  @override
  String get chatEmptyBody => 'ابدأ محادثة لطرح سؤال في مساحة العمل هذه.';

  @override
  String get untitledConversation => 'محادثة بلا عنوان';

  @override
  String get composerHint => 'اكتب سؤالك';

  @override
  String get sendAction => 'إرسال';

  @override
  String get stopAction => 'إيقاف';

  @override
  String get modelLabel => 'النموذج';

  @override
  String get noModels => 'لا تتوفر لك نماذج في مساحة العمل هذه.';

  @override
  String get assistantTyping => 'جارٍ كتابة الرد…';

  @override
  String get copyAction => 'نسخ';

  @override
  String get copied => 'تم النسخ إلى الحافظة.';

  @override
  String get helpful => 'مفيد';

  @override
  String get notHelpful => 'غير مفيد';

  @override
  String get branchAction => 'المتابعة في محادثة جديدة';

  @override
  String get sourcesLabel => 'المصادر';

  @override
  String sourceExcerpt(int index) {
    return 'مقتطف $index';
  }

  @override
  String get turnQuota => 'لقد بلغت حد الاستخدام في مساحة العمل هذه.';

  @override
  String get turnRateLimited =>
      'طلبات كثيرة جدًا. انتظر قليلًا ثم أرسل مرة أخرى.';

  @override
  String get turnPolicy =>
      'هذا النموذج غير مسموح في مساحة العمل هذه. اختر نموذجًا آخر.';

  @override
  String get turnProvider =>
      'تعذّر على النموذج إكمال هذا الرد. لم يُحفظ أي رد.';

  @override
  String get turnInterrupted => 'انقطع الاتصال قبل اكتمال الرد. لم يُحفظ الرد.';

  @override
  String get turnStopped =>
      'أوقفت هذا الرد. الإيقاف ينهيه على هذا الجهاز فقط، ولا يُحفظ الجزء الظاهر منه.';

  @override
  String get turnSessionNotFound => 'لم تعد هذه المحادثة متاحة.';

  @override
  String get turnDocumentAccess =>
      'ليست لديك صلاحية للوصول إلى أحد المستندات المحددة.';

  @override
  String get turnProtocol => 'تعذّرت قراءة الرد.';

  @override
  String get turnGeneric => 'تعذّر إكمال الرد.';

  @override
  String get turnUncertain =>
      'ربما حُفظ سؤالك بالفعل. راجع المحادثة قبل إرساله مرة أخرى.';

  @override
  String get sendAgain => 'إرسال مرة أخرى';

  @override
  String get dismissAction => 'إغلاق';

  @override
  String get storedReplyFailed => 'فشل هذا الرد ولا يحتوي على إجابة.';

  @override
  String get jumpToLatest => 'الانتقال إلى الأحدث';

  @override
  String get moreActions => 'المزيد';

  @override
  String get summaryAction => 'تلخيص';

  @override
  String get summaryTitle => 'الملخص';

  @override
  String get summaryCost =>
      'يكتب النموذج الملخص، ويُحتسب ضمن استخدام مساحة العمل.';

  @override
  String get generateAction => 'إنشاء';

  @override
  String get exportAction => 'نسخ بتنسيق Markdown';

  @override
  String get exportDone => 'نُسخت المحادثة بتنسيق Markdown.';

  @override
  String get shareAction => 'رابط مشاركة';

  @override
  String get shareTitle => 'مشاركة هذه المحادثة';

  @override
  String get shareExplain =>
      'يستطيع أي شخص لديه الرابط قراءة رسائل هذه المحادثة حتى لحظة إنشائه، إلى أن تنتهي صلاحية الرابط أو تلغيه. لا تُضمَّن المصادر ولا تفاصيل المستندات.';

  @override
  String get createLinkAction => 'إنشاء رابط';

  @override
  String shareCreated(String date) {
    return 'نُسخ الرابط. تنتهي صلاحيته في $date.';
  }

  @override
  String get activeLinks => 'الروابط النشطة';

  @override
  String get noActiveLinks => 'لا توجد روابط نشطة.';

  @override
  String get revokeAction => 'إلغاء';

  @override
  String get linkRevoked => 'أُلغي الرابط.';

  @override
  String expiresOn(String date) {
    return 'تنتهي في $date';
  }

  @override
  String get openLinkTitle => 'فتح رابط خارجي؟';

  @override
  String openLinkBody(String host) {
    return 'سيُفتح $host في المتصفح.';
  }

  @override
  String get openAction => 'فتح';

  @override
  String get openChat => 'فتح المحادثات';

  @override
  String get openDocuments => 'المستندات';

  @override
  String get documentsTitle => 'المستندات';

  @override
  String get documentsChatExplain =>
      'تبحث إجابات المحادثة في مستنداتك الجاهزة في مساحة العمل هذه. اختر مستندات داخل المحادثة لحصر البحث فيها.';

  @override
  String get searchDocumentsHint => 'ابحث في المستندات';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterInProgress => 'قيد المعالجة';

  @override
  String get docStateReady => 'جاهز';

  @override
  String get docStateFailed => 'تعذّرت المعالجة';

  @override
  String get docStateProcessing => 'جارٍ المعالجة…';

  @override
  String get docStateIndexing => 'جارٍ التجهيز للبحث…';

  @override
  String get documentHidden => 'مخفي عن الأعضاء';

  @override
  String get documentsEmptyTitle => 'لا توجد مستندات بعد';

  @override
  String get documentsEmptyUploader =>
      'ارفع ملفات PDF أو Word أو Excel أو PowerPoint أو CSV أو ملفات نصية حتى 25 ميغابايت.';

  @override
  String get documentsEmptyReader =>
      'تظهر هنا المستندات التي تمت مشاركتها معك في مساحة العمل هذه.';

  @override
  String get noMatchingDocuments => 'لا توجد مستندات مطابقة.';

  @override
  String get uploadAction => 'رفع';

  @override
  String sizeMegabytes(String value) {
    return '$value ميغابايت';
  }

  @override
  String sizeKilobytes(String value) {
    return '$value كيلوبايت';
  }

  @override
  String uploadSending(String sent, String total) {
    return 'جارٍ الرفع: $sent من $total';
  }

  @override
  String get uploadProcessing =>
      'اكتمل الرفع. يقرأ الخادم الملف ويفهرسه، وقد يستغرق ذلك بضع دقائق.';

  @override
  String get uploadChecking =>
      'تعذّر الاتصال، ولم يتضح إن كان الملف قد وصل. جارٍ التحقق مع الخادم قبل إرسال أي شيء مرة أخرى.';

  @override
  String get uploadReady => 'جاهز للاستخدام في المحادثة.';

  @override
  String get uploadReceived => 'استلمه الخادم.';

  @override
  String get uploadCancelled =>
      'أُوقف على هذا الجهاز. إن كان الملف قد وصل بالفعل فسيواصل الخادم معالجته وسيظهر في القائمة.';

  @override
  String get uploadNotReceived =>
      'لم يصل الملف إلى الخادم. يمكنك رفعه مرة أخرى.';

  @override
  String get cancelUploadAction => 'إلغاء الرفع';

  @override
  String get stopWaitingAction => 'إيقاف الانتظار';

  @override
  String get checkAgainAction => 'تحقق مرة أخرى';

  @override
  String get viewDetailsAction => 'التفاصيل';

  @override
  String get doneAction => 'تم';

  @override
  String get docErrorEncrypted =>
      'هذا الملف محمي بكلمة مرور أو بتنسيق Office قديم. أزل كلمة المرور أو احفظه كملف جديد ثم ارفعه مرة أخرى.';

  @override
  String get docErrorCorrupt => 'الملف تالف أو لا يطابق نوعه المذكور في اسمه.';

  @override
  String get docErrorNoText =>
      'لم يُعثر على نص قابل للقراءة. قد تحتاج المستندات الممسوحة ضوئيًا إلى التعرّف على النص قبل رفعها.';

  @override
  String get docErrorTooComplex => 'الملف كبير أو معقّد جدًا ولا يمكن معالجته.';

  @override
  String get docErrorUnsupported =>
      'نوع الملف غير مدعوم. استخدم PDF أو Word أو Excel أو PowerPoint أو CSV أو نصًا بترميز UTF-8.';

  @override
  String get docErrorTooLarge => 'يجب ألا يتجاوز حجم الملف 25 ميغابايت.';

  @override
  String get docErrorEmpty => 'الملف فارغ.';

  @override
  String get docErrorTimeout => 'استغرقت المعالجة وقتًا طويلًا فأُوقفت.';

  @override
  String get docErrorInterrupted => 'انقطعت المعالجة على الخادم.';

  @override
  String get docErrorStorage => 'تعذّر تخزين الملف. ارفعه مرة أخرى.';

  @override
  String get docErrorGeneric => 'تعذّرت معالجة المستند.';

  @override
  String get errorUnsupportedFile => 'نوع الملف غير مدعوم.';

  @override
  String get documentDetailsTitle => 'المستند';

  @override
  String get documentUnavailableTitle => 'المستند غير متاح';

  @override
  String get documentUnavailableBody =>
      'ربما حُذف أو أُخفي، أو تغيّرت صلاحيتك.';

  @override
  String get docProcessingExplain =>
      'يقرأ الخادم هذا المستند ويفهرسه. يمكن استخدامه في المحادثة عندما يصبح جاهزًا.';

  @override
  String get retryProcessingAction => 'إعادة محاولة المعالجة';

  @override
  String get documentInfoTitle => 'التفاصيل';

  @override
  String get fileTypeLabel => 'النوع';

  @override
  String get fileSizeLabel => 'الحجم';

  @override
  String get uploadedLabel => 'تاريخ الرفع';

  @override
  String get sectionsLabel => 'الأقسام المفهرسة';

  @override
  String get useInChatAction => 'استخدامه في المحادثة';

  @override
  String get selectedForChat => 'محدد للمحادثة';

  @override
  String get openDocumentAction => 'فتح المستند';

  @override
  String get openFileFailed => 'لا يوجد تطبيق على هذا الجهاز يمكنه فتح الملف.';

  @override
  String get localCopyExplain =>
      'يؤدي الفتح إلى تنزيل نسخة في التخزين الخاص بهذا التطبيق، وتُحذف عند تسجيل الخروج أو تبديل مساحة العمل. أما النسخ التي تشاركها مع تطبيقات أخرى فلا يمكن استرجاعها.';

  @override
  String get chooseDocumentsAction => 'اختيار المستندات';

  @override
  String get chooseDocumentsTitle => 'مستندات هذه المحادثة';

  @override
  String get chooseDocumentsExplain =>
      'إذا لم تحدد شيئًا، تبحث الإجابات في كل مستنداتك الجاهزة في مساحة العمل هذه. حدّد مستندات لحصر البحث فيها.';

  @override
  String get scopeAllDocuments => 'البحث في كل مستنداتك الجاهزة';

  @override
  String scopeSelectedDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'البحث في $count مستندًا محددًا',
      few: 'البحث في $count مستندات محددة',
      two: 'البحث في مستندين محددين',
      one: 'البحث في مستند واحد محدد',
    );
    return '$_temp0';
  }

  @override
  String documentsNotReadyHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مستندًا ما زال قيد المعالجة ولا يمكن تحديده بعد.',
      few: '$count مستندات ما زالت قيد المعالجة ولا يمكن تحديدها بعد.',
      two: 'مستندان ما زالا قيد المعالجة ولا يمكن تحديدهما بعد.',
      one: 'مستند واحد ما زال قيد المعالجة ولا يمكن تحديده بعد.',
    );
    return '$_temp0';
  }

  @override
  String get noReadyDocuments =>
      'لا توجد مستندات جاهزة في مساحة العمل هذه بعد.';

  @override
  String get clearSelection => 'مسح';

  @override
  String get removeFromSelection => 'إزالة من التحديد';

  @override
  String selectionPruned(String names, String scope) {
    return 'أُزيل من تحديدك لأنه لم يعد متاحًا: $names. الآن: $scope.';
  }

  @override
  String get listSeparator => '، ';

  @override
  String get reviewDocumentsAction => 'مراجعة المستندات';

  @override
  String get turnDocumentNotReady =>
      'أحد المستندات المحددة ليس جاهزًا بعد، ولم يُجرَ بحث بديل.';

  @override
  String get sourceUnavailable => 'المصدر غير متاح';

  @override
  String get sourceUnavailableBody =>
      'لم تعد لديك صلاحية الوصول إلى هذا المصدر، لذلك لا يظهر مقتطفه. يبقى نص الإجابة الذي تلقيته في المحادثة.';

  @override
  String get sourceSavedNote =>
      'حُفظ هذا المقتطف مع الإجابة، ويُعاد التحقق من الصلاحية في كل مرة تفتح فيها المحادثة.';

  @override
  String pageNumber(int page) {
    return 'صفحة $page';
  }

  @override
  String get imageNotLoaded => 'لم تُحمَّل الصورة';

  @override
  String get openLinkFailed => 'تعذّر فتح الرابط.';

  @override
  String get docErrorDuplicate =>
      'لا يمكن إضافة هذا الملف إلى مساحة العمل هذه. إن كنت بحاجة إليه فاطلب الصلاحية من مسؤول مساحة العمل.';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String notificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعارًا غير مقروء',
      few: '$count إشعارات غير مقروءة',
      two: 'إشعاران غير مقروءين',
      one: 'إشعار واحد غير مقروء',
    );
    return '$_temp0';
  }

  @override
  String get markAllReadAction => 'تحديد الكل كمقروء';

  @override
  String get notificationsReconnecting =>
      'التحديثات المباشرة متوقفة مؤقتًا، وجارٍ إعادة الاتصال. ستُحدَّث القائمة بعد الاتصال.';

  @override
  String get notificationsEmptyTitle => 'لا توجد إشعارات';

  @override
  String get notificationsEmptyBody =>
      'تظهر هنا التحديثات الخاصة بطلباتك ومساحات العمل.';

  @override
  String get notificationTargetUnavailable => 'لم يعد هذا متاحًا لك.';

  @override
  String get notifApprovedTitle => 'تمت الموافقة على الطلب';

  @override
  String notifApprovedBody(String type, String space) {
    return 'تمت الموافقة على طلب $type في $space.';
  }

  @override
  String get notifDeclinedTitle => 'رُفض الطلب';

  @override
  String notifDeclinedBody(String type, String space) {
    return 'رُفض طلب $type في $space.';
  }

  @override
  String notifDeclinedBodyNote(String type, String space, String note) {
    return 'رُفض طلب $type في $space. ملاحظة: $note';
  }

  @override
  String get notifPolicyTitle => 'تغيّرت إعدادات مساحة العمل';

  @override
  String notifPolicyBody(String space) {
    return 'حُدّثت النماذج أو الحدود في $space.';
  }

  @override
  String get notifInviteTitle => 'دعوة';

  @override
  String notifInviteBody(String space) {
    return 'تمت دعوتك للانضمام إلى $space.';
  }

  @override
  String get notifQuotaTitle => 'اقتربت من حد الاستخدام';

  @override
  String notifQuotaBody(String space) {
    return 'أنت قريب من أحد حدود الاستخدام في $space.';
  }

  @override
  String get requestTypeJoin => 'انضمام';

  @override
  String get requestTypeModel => 'الوصول إلى نموذج';

  @override
  String get requestTypeTool => 'الوصول إلى أداة';

  @override
  String get requestTypeQuota => 'رفع الحدود';

  @override
  String get requestTypeUpload => 'رفع المستندات';

  @override
  String get requestTypeOther => 'أخرى';

  @override
  String get usageTitle => 'الاستخدام';

  @override
  String get periodDay => '24 ساعة';

  @override
  String periodDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يومًا',
      few: '$days أيام',
    );
    return '$_temp0';
  }

  @override
  String usageWindow(String start, String end) {
    return 'من $start إلى $end بتوقيتك المحلي. تُحسب المدة رجوعًا من الآن.';
  }

  @override
  String get usageSummaryTitle => 'الملخص';

  @override
  String get usageRequests => 'الردود المطلوبة';

  @override
  String usageUnknownRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ردًا بلا استخدام مُبلَّغ عنه (مثل ردود أُوقفت أو انقطعت).',
      few: '$count ردود بلا استخدام مُبلَّغ عنه (مثل ردود أُوقفت أو انقطعت).',
      two: 'ردّان بلا استخدام مُبلَّغ عنه (مثل ردود أُوقفت أو انقطعت).',
      one: 'ردّ واحد بلا استخدام مُبلَّغ عنه (مثل رد أُوقف أو انقطع).',
    );
    return '$_temp0';
  }

  @override
  String get usageInputTokens => 'رموز الإدخال';

  @override
  String get usageOutputTokens => 'رموز الإخراج';

  @override
  String get usageTotalTokens => 'إجمالي الرموز';

  @override
  String get usageCostTitle => 'التكلفة التقديرية';

  @override
  String get usageCostBasis =>
      'تقدير وفق الأسعار المعلنة بالدولار الأمريكي، وليست فاتورة من المزوّد.';

  @override
  String get usageCostUnavailable => 'غير متاحة';

  @override
  String usageCostIncomplete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ردًا بلا بيانات استخدام أو سعر وغير مشمول.',
      few: '$count ردود بلا بيانات استخدام أو سعر وغير مشمولة.',
      two: 'ردّان بلا بيانات استخدام أو سعر وغير مشمولين.',
      one: 'ردّ واحد بلا بيانات استخدام أو سعر وغير مشمول.',
    );
    return '$_temp0';
  }

  @override
  String get usageCostNone =>
      'لا يوجد في هذه المدة رد له بيانات استخدام وسعر، لذلك لا يمكن عرض تكلفة. هذا لا يعني أنه كان مجانيًا.';

  @override
  String get usageLimitsTitle => 'الحدود';

  @override
  String get usageLimitsExplain =>
      'تُحسب الحدود رجوعًا من الآن، وتُحسب حدود المحادثات بعدد المحادثات التي بدأتها.';

  @override
  String get usageByModel => 'حسب النموذج';

  @override
  String usageModelLine(String requests, String tokens) {
    return '$requests ردود · $tokens رمز';
  }

  @override
  String get usageTools => 'الأدوات';

  @override
  String usageToolCalls(String count) {
    return '$count استدعاءات';
  }

  @override
  String get limitTokens => 'الرموز';

  @override
  String get limitConversations => 'المحادثات';

  @override
  String get limitToolRequests => 'استدعاءات الأدوات';

  @override
  String get limitLast24h => 'آخر 24 ساعة';

  @override
  String get limitLast30d => 'آخر 30 يومًا';

  @override
  String limitNone(String used) {
    return 'المستخدم $used · بلا حد';
  }

  @override
  String limitValue(String used, String limit, String remaining) {
    return 'المستخدم $used من $limit · المتبقي $remaining';
  }

  @override
  String limitReserved(String tokens) {
    return 'يشمل $tokens محسوبة لردود لم يُبلَّغ عن استخدامها.';
  }

  @override
  String get invoiceAction => 'مشاركة الفاتورة (PDF)';

  @override
  String get invoiceExplain =>
      'يُنشئ الخادم ملف PDF للمدة المختارة، ويُحفظ في التخزين الخاص بالتطبيق حتى تسجيل الخروج أو تبديل مساحة العمل.';

  @override
  String get invoiceShareSubject => 'فاتورة استخدام TEIA';

  @override
  String get shareUnavailable => 'المشاركة غير متاحة على هذا الجهاز.';

  @override
  String get requestsTitle => 'الطلبات';

  @override
  String get requestsExplain =>
      'الطلبات التي أرسلتها إلى مسؤولي مساحات العمل. تُحدَّث صلاحياتك تلقائيًا عند الموافقة.';

  @override
  String get requestsEmptyTitle => 'لا توجد طلبات';

  @override
  String get requestsEmptyBody =>
      'اطلب الوصول إلى نموذج أو رفع الحدود أو صلاحية الرفع.';

  @override
  String get accountRequestsTitle => 'طلبات الحساب';

  @override
  String get requestPending => 'قيد المراجعة';

  @override
  String get requestApproved => 'مقبول';

  @override
  String get requestDeclined => 'مرفوض';

  @override
  String requestSentOn(String date) {
    return 'أُرسل في $date';
  }

  @override
  String get reviewerNote => 'ملاحظة المراجِع';

  @override
  String get newRequestAction => 'طلب جديد';

  @override
  String get newRequestTitle => 'طلب جديد';

  @override
  String get requestUploadExplain =>
      'اطلب صلاحية رفع المستندات في مساحة العمل هذه.';

  @override
  String get requestReason => 'ما الذي تحتاجه؟';

  @override
  String get requestReasonOptional => 'السبب (اختياري)';

  @override
  String get requestChooseModel => 'اختر نموذجًا.';

  @override
  String get requestQuotaInvalid =>
      'أدخل رقمًا صحيحًا أكبر من صفر في حقل واحد على الأقل.';

  @override
  String get requestReasonRequired => 'صِف ما تحتاجه.';

  @override
  String get requestSent => 'أُرسل الطلب.';

  @override
  String get requestAlreadyPending => 'لديك هذا الطلب بالفعل قيد المراجعة.';

  @override
  String get requestUncertain =>
      'تعذّر تأكيد الطلب. حُدّثت القائمة؛ راجعها قبل الإرسال مرة أخرى.';

  @override
  String get sendRequestAction => 'إرسال الطلب';

  @override
  String get quotaDailyTokens => 'الرموز لكل 24 ساعة';

  @override
  String get quotaMonthlyTokens => 'الرموز لكل 30 يومًا';

  @override
  String get quotaDailyConversations => 'المحادثات لكل 24 ساعة';

  @override
  String get quotaMonthlyConversations => 'المحادثات لكل 30 يومًا';

  @override
  String get renameAction => 'إعادة التسمية';

  @override
  String get renameTitle => 'إعادة تسمية المحادثة';

  @override
  String get conversationNameLabel => 'الاسم';

  @override
  String get saveAction => 'حفظ';

  @override
  String get exportFileAction => 'مشاركة كملف';

  @override
  String get deleteConversationAction => 'حذف';

  @override
  String get deleteConversationTitle => 'حذف هذه المحادثة؟';

  @override
  String get deleteConversationBody =>
      'تُحذف رسائلها وتتوقف روابط مشاركتها عن العمل، وتبقى سجلات الاستخدام. لا يمكن استرجاع النسخ التي شاركتها أو صدّرتها سابقًا.';

  @override
  String get deleteAction => 'حذف';

  @override
  String get conversationDeleted => 'حُذفت المحادثة.';

  @override
  String get replyLanguageTitle => 'لغة الردود';

  @override
  String get replyLanguageExplain =>
      'اللغة التي يجيب بها المساعد. التلقائي يتبع لغة سؤالك.';

  @override
  String get replyLanguageAuto => 'تلقائي';

  @override
  String get upcomingNotifications => 'الإشعارات';

  @override
  String get manageSpaceTitle => 'إدارة المساحة';

  @override
  String get adminOverviewTitle => 'المساحة';

  @override
  String get renameSpaceAction => 'إعادة تسمية المساحة';

  @override
  String get spaceNameLabel => 'اسم المساحة';

  @override
  String get spaceNameInvalid => 'استخدم من 2 إلى 80 حرفًا.';

  @override
  String get adminMembersTitle => 'الأعضاء';

  @override
  String get adminInvitesTitle => 'الدعوات';

  @override
  String get adminRequestsTitle => 'طلبات للمراجعة';

  @override
  String get adminModelsToolsTitle => 'النماذج والأدوات';

  @override
  String get adminLimitsTitle => 'حدود الاستخدام';

  @override
  String get adminDocumentsTitle => 'الوصول إلى المستندات';

  @override
  String get adminUsageTitle => 'استخدام المساحة';

  @override
  String get adminWebOnlyNote =>
      'إنشاء المساحات أو إيقافها والإعدادات العامة للمنصة وتعليمات النظام العامة تُدار من موقع الويب.';

  @override
  String get adminSaved => 'تم الحفظ.';

  @override
  String get adminAccessLost => 'لم تعد مسؤولًا عن إدارة هذه المساحة.';

  @override
  String get adminLastAdmin =>
      'يجب أن يبقى في المساحة مسؤول نشط واحد على الأقل. اجعل شخصًا آخر مسؤولًا أولًا.';

  @override
  String get adminSpaceInactive => 'هذه المساحة غير نشطة.';

  @override
  String get adminUnsupportedChoice => 'أحد الخيارات غير مدعوم في هذه الخدمة.';

  @override
  String get adminInvalidValue =>
      'هذه القيمة غير مسموح بها. تحقق من الأرقام وحاول مرة أخرى.';

  @override
  String get adminUncertain =>
      'تعذر تأكيد التغيير. تم تحديث الشاشة؛ تحقق منها قبل المحاولة مرة أخرى.';

  @override
  String get memberSearchLabel => 'البحث بالبريد الإلكتروني';

  @override
  String get membersEmptyTitle => 'لا يوجد أعضاء';

  @override
  String get membersEmptyBody => 'ادعُ أشخاصًا لإضافتهم إلى هذه المساحة.';

  @override
  String get membersNoMatch => 'لا يوجد عضو يطابق هذا البحث.';

  @override
  String get memberStatusRevoked => 'تمت إزالة الوصول';

  @override
  String get memberDetailTitle => 'العضو';

  @override
  String get memberGoneTitle => 'العضو غير موجود';

  @override
  String get memberGoneBody => 'لم يعد هذا الشخص مدرجًا في هذه المساحة.';

  @override
  String get memberIsYou => 'هذا أنت.';

  @override
  String get memberAccessTitle => 'الدور والوصول';

  @override
  String get memberAdminRole => 'مسؤول المساحة';

  @override
  String get memberAdminRoleExplain =>
      'يدير المسؤولون الأعضاء والدعوات والطلبات والسياسة والمستندات.';

  @override
  String get memberCanUpload => 'يمكنه رفع المستندات';

  @override
  String get memberAdminsCanUpload => 'يمكن للمسؤولين الرفع دائمًا.';

  @override
  String get makeAdminTitle => 'هل تريد جعل هذا العضو مسؤولًا؟';

  @override
  String get makeAdminBody =>
      'سيتمكن من إدارة كل شيء في هذه المساحة، بما في ذلك المسؤولون الآخرون.';

  @override
  String get makeAdminAction => 'جعله مسؤولًا';

  @override
  String get removeAdminTitle => 'هل تريد إزالة دور المسؤول؟';

  @override
  String get removeAdminBody =>
      'سيبقى عضوًا لكنه لن يتمكن من إدارة هذه المساحة.';

  @override
  String get removeOwnAdminTitle => 'هل تريد إزالة دور المسؤول عنك؟';

  @override
  String get removeOwnAdminBody =>
      'ستغادر هذه الشاشات فورًا ولن تتمكن من التراجع بنفسك. سيحتاج مسؤول آخر إلى إعادته.';

  @override
  String get removeAdminAction => 'إزالة دور المسؤول';

  @override
  String get revokeAccessTitle => 'هل تريد إزالة الوصول إلى هذه المساحة؟';

  @override
  String get revokeOwnAccessTitle => 'هل تريد إزالة وصولك أنت؟';

  @override
  String get revokeAccessBody =>
      'لن يتمكن من فتح المساحة أو محادثاتها أو مستنداتها. تُحفظ سجلاته، ويمكن إعادة الوصول لاحقًا.';

  @override
  String get revokeAccessAction => 'إزالة الوصول';

  @override
  String get restoreAccessTitle => 'هل تريد إعادة الوصول؟';

  @override
  String get restoreAccessBody =>
      'سيتمكن من استخدام هذه المساحة مرة أخرى بإعداداته السابقة.';

  @override
  String get restoreAccessAction => 'إعادة الوصول';

  @override
  String get memberLimitsTitle => 'حدود هذا العضو';

  @override
  String get memberLimitsExplain =>
      'الحدود غير المحددة تتبع الإعداد الافتراضي للمساحة. الحد المحدد هنا ينطبق على هذا العضو فقط.';

  @override
  String get memberExtraModelsTitle => 'نماذج إضافية';

  @override
  String get memberExtraToolsTitle => 'أدوات إضافية';

  @override
  String get memberAdditionsExplain =>
      'مُنحت لهذا العضو إضافة إلى سياسة المساحة، غالبًا عبر طلب تمت الموافقة عليه.';

  @override
  String get memberNoAdditions => 'لا شيء';

  @override
  String get removeGrantTitle => 'هل تريد إزالة هذا الوصول؟';

  @override
  String get removeGrantBody => 'سيحتفظ العضو بما تسمح به سياسة المساحة.';

  @override
  String get removeGrantAction => 'إزالة';

  @override
  String get limitUnlimited => 'بلا حد';

  @override
  String get limitBlocked => '0 (محظور)';

  @override
  String limitInherited(String value) {
    return 'الافتراضي للمساحة: $value';
  }

  @override
  String get limitInheritedShort => 'يتبع الإعداد الافتراضي للمساحة';

  @override
  String get limitExplicitShort => 'محدد لهذا العضو';

  @override
  String get limitUseDefault => 'استخدام الإعداد الافتراضي للمساحة';

  @override
  String get limitSetValue => 'تحديد حد';

  @override
  String get limitZeroBlocks => 'القيمة 0 تمنع ذلك تمامًا.';

  @override
  String get limitInvalid => 'أدخل عددًا صحيحًا من 0 إلى 1,000,000,000.';

  @override
  String get quotaDailyToolRequests => 'استخدامات الأدوات كل 24 ساعة';

  @override
  String get quotaMonthlyToolRequests => 'استخدامات الأدوات كل 30 يومًا';

  @override
  String get spaceDefaultsTitle => 'الإعدادات الافتراضية للمساحة';

  @override
  String get spaceDefaultsExplain =>
      'تنطبق على كل عضو ليس له حد خاص. تُحسب الفترات رجوعًا من الآن.';

  @override
  String get memberOverridesHint =>
      'لتحديد حد مختلف لعضو واحد، افتحه في قائمة الأعضاء.';

  @override
  String get blockLimitTitle => 'هل تريد منع ذلك عن الجميع؟';

  @override
  String get blockLimitBody => 'الحد 0 يوقف كل عضو ليس له حد خاص.';

  @override
  String get blockLimitAction => 'تعيين إلى 0';

  @override
  String get allowedModelsTitle => 'النماذج المسموح بها';

  @override
  String get allowedModelsExplain =>
      'يمكن للأعضاء اختيارها. إذا لم يُحدد أي منها، يُطبق الإعداد الافتراضي للخدمة.';

  @override
  String get allowedToolsTitle => 'الأدوات المسموح بها';

  @override
  String get allowedToolsExplain =>
      'قد يستخدمها المساعد في هذه المساحة. إذا لم يُحدد أي منها، يُطبق الإعداد الافتراضي للخدمة.';

  @override
  String get catalogEmpty => 'لا يتوفر شيء.';

  @override
  String get catalogNoLongerSupported => 'لم يعد متاحًا في هذه الخدمة';

  @override
  String get saveChangesAction => 'حفظ التغييرات';

  @override
  String get discardChangesTitle => 'هل تريد تجاهل التغييرات؟';

  @override
  String get discardChangesBody => 'ستفقد اختياراتك غير المحفوظة.';

  @override
  String get discardAction => 'تجاهل';

  @override
  String get invitesExplain =>
      'تُرسل الدعوات بالبريد الإلكتروني وتنتهي بعد 7 أيام. لا تُعرض الروابط هنا أبدًا.';

  @override
  String get invitesEmptyTitle => 'لا توجد دعوات';

  @override
  String get invitesEmptyBody => 'ادعُ شخصًا بالبريد الإلكتروني.';

  @override
  String get inviteMemberAction => 'دعوة';

  @override
  String get inviteMemberTitle => 'الدعوة بالبريد الإلكتروني';

  @override
  String get inviteExplain => 'ينضم كعضو بعد تسجيل الدخول بهذا العنوان.';

  @override
  String get sendInviteAction => 'إرسال الدعوة';

  @override
  String inviteSent(String email) {
    return 'تم إرسال الدعوة إلى $email.';
  }

  @override
  String inviteResent(String email) {
    return 'تم إرسال رابط جديد إلى $email. الروابط السابقة لم تعد تعمل.';
  }

  @override
  String get inviteRevoked => 'تم إلغاء الدعوة.';

  @override
  String get inviteAlreadyMember => 'هذا الشخص عضو بالفعل.';

  @override
  String get inviteEmailFailed =>
      'تعذر إرسال بريد الدعوة، لذلك لم تُنشأ أي دعوة. حاول لاحقًا.';

  @override
  String get inviteNewerOpen => 'توجد دعوة أحدث مفتوحة لهذا العنوان بالفعل.';

  @override
  String get inviteStatusPending => 'بانتظار القبول';

  @override
  String get inviteStatusAccepted => 'مقبولة';

  @override
  String get inviteStatusRevoked => 'ملغاة';

  @override
  String get inviteStatusExpired => 'منتهية';

  @override
  String inviteExpires(String date) {
    return 'تنتهي في $date';
  }

  @override
  String inviteSentTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُرسلت $count مرة',
      many: 'أُرسلت $count مرة',
      few: 'أُرسلت $count مرات',
      two: 'أُرسلت مرتين',
      one: 'أُرسلت مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get resendInviteAction => 'إرسال رابط جديد';

  @override
  String get revokeInviteAction => 'إلغاء الدعوة';

  @override
  String get revokeInviteTitle => 'هل تريد إلغاء هذه الدعوة؟';

  @override
  String revokeInviteBody(String email) {
    return 'سيتوقف الرابط المرسل إلى $email عن العمل.';
  }

  @override
  String get requestsPendingTab => 'قيد الانتظار';

  @override
  String get requestsHistoryTab => 'السجل';

  @override
  String get noPendingRequestsTitle => 'لا شيء للمراجعة';

  @override
  String get noPendingRequestsBody => 'تظهر هنا الطلبات الجديدة من الأعضاء.';

  @override
  String get noReviewedRequestsTitle => 'لا توجد طلبات تمت مراجعتها';

  @override
  String get noReviewedRequestsBody => 'تظهر هنا الطلبات المقبولة والمرفوضة.';

  @override
  String requestSummaryModel(String model) {
    return 'النموذج: $model';
  }

  @override
  String requestSummaryTool(String tool) {
    return 'الأداة: $tool';
  }

  @override
  String get requestSummaryUpload => 'إذن رفع المستندات';

  @override
  String get requestSummaryJoin => 'يريد الانضمام إلى هذه المساحة';

  @override
  String get requestReasonLabel => 'السبب';

  @override
  String get reviewNoteLabel => 'ملاحظة لمقدم الطلب (اختيارية)';

  @override
  String get approveAction => 'موافقة';

  @override
  String get declineAction => 'رفض';

  @override
  String get requestApprovedDone => 'تمت الموافقة. تم إشعار العضو.';

  @override
  String get requestDeclinedDone => 'تم الرفض. تم إشعار العضو.';

  @override
  String get reviewAlreadyDone =>
      'تمت مراجعة هذا الطلب بالفعل. تم تحديث القائمة.';

  @override
  String get reviewOwnRequest => 'يراجع طلباتك مسؤول آخر.';

  @override
  String get requestChooseTool => 'اختر أداة.';

  @override
  String get toolLabel => 'الأداة';

  @override
  String get adminDocumentsExplain =>
      'يرى الأعضاء المستندات التي رفعوها أو مُنحت لهم. المستندات المخفية يراها المسؤولون فقط.';

  @override
  String get adminDocumentsEmpty => 'لا توجد مستندات في هذه المساحة بعد.';

  @override
  String get documentHiddenSwitch => 'إخفاء عن الأعضاء';

  @override
  String get documentHiddenExplain =>
      'لا تُعرض المستندات المخفية ولا تُستخدم في إجابات الأعضاء، حتى من مُنح الوصول.';

  @override
  String get hideDocumentTitle => 'هل تريد إخفاء هذا المستند؟';

  @override
  String get hideDocumentBody =>
      'يفقد الأعضاء الوصول فورًا، وستظهر المصادر في الإجابات السابقة التي تستشهد به على أنها غير متاحة لهم.';

  @override
  String get hideDocumentAction => 'إخفاء';

  @override
  String get documentAccessTitle => 'الأعضاء الذين لديهم وصول';

  @override
  String get documentAccessExplain =>
      'يملك المسؤولون ومن رفع المستند الوصول دائمًا.';

  @override
  String get documentUploader => 'رفع المستند';

  @override
  String get documentNoMembers => 'لا يوجد أعضاء آخرون لمنحهم الوصول.';

  @override
  String get documentGone => 'لم يعد هذا المستند متاحًا.';

  @override
  String get removeDocAccessTitle => 'هل تريد إزالة الوصول إلى هذا المستند؟';

  @override
  String removeDocAccessBody(String email) {
    return 'لن يراه $email بعد الآن، وستظهر المصادر في الإجابات السابقة التي تستشهد به على أنها غير متاحة.';
  }

  @override
  String get removeDocAccessAction => 'إزالة الوصول';

  @override
  String get spaceTotalsTitle => 'الإجماليات';

  @override
  String get spaceUsageExplain =>
      'جميع الأعضاء، من الاستخدام المسجل. لا تُحتسب الردود التي لا يوجد لها استخدام مُبلغ عنه. التكاليف تقديرية بأسعار القائمة.';

  @override
  String get usageNoRequests => 'لا يوجد استخدام مسجل في هذه الفترة.';

  @override
  String get myUsageAction => 'استخدامي';
}
