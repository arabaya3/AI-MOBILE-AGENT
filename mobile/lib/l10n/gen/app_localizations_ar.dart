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
  String get upcomingNotifications => 'الإشعارات';

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
}
