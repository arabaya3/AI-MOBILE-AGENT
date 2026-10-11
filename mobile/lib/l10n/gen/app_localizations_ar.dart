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
}
