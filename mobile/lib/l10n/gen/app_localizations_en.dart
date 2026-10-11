// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TEIA AI';

  @override
  String get previewTitle => 'Foundation preview';

  @override
  String get previewIntro =>
      'This build shows the app\'s visual foundation only. Sign-in, chat, documents and administration arrive in later releases.';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get sectionComponents => 'Components';

  @override
  String get componentsNote =>
      'Samples only. These controls do not perform any action.';

  @override
  String get sampleFilledButton => 'Primary style';

  @override
  String get sampleOutlinedButton => 'Secondary style';

  @override
  String get sampleTextButton => 'Text style';

  @override
  String get sampleFieldLabel => 'Sample field';

  @override
  String get sampleFieldHint => 'Type in English or Arabic';

  @override
  String get sampleFieldHelper => 'Text direction follows what you type.';

  @override
  String get bannerInfoTitle => 'Information';

  @override
  String get bannerInfoBody => 'Neutral updates use this style.';

  @override
  String get bannerSuccessTitle => 'Success';

  @override
  String get bannerSuccessBody => 'Completed actions use this style.';

  @override
  String get bannerWarningTitle => 'Warning';

  @override
  String get bannerWarningBody =>
      'Situations that need attention use this style.';

  @override
  String get bannerErrorTitle => 'Error';

  @override
  String get bannerErrorBody =>
      'Failures use this style together with a recovery action.';

  @override
  String get sectionStates => 'Screen states';

  @override
  String get loadingLabel => 'Loading';

  @override
  String get emptyTitle => 'Nothing here yet';

  @override
  String get emptyBody => 'Content will appear here once it exists.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get retryLabel => 'Try again';

  @override
  String get sectionMixedText => 'Mixed-language content';

  @override
  String get mixedTextNote =>
      'Each message keeps its own direction, regardless of the app language.';

  @override
  String get sectionUpcoming => 'Coming in later releases';

  @override
  String get upcomingChat => 'Chat';

  @override
  String get upcomingDocuments => 'Documents';

  @override
  String get upcomingNotifications => 'Notifications';

  @override
  String get upcomingSpaceAdmin => 'Space administration';

  @override
  String get notAvailableYet => 'Not available yet';

  @override
  String get sectionDeveloper => 'Developer build';

  @override
  String get developerEnvironment => 'Environment';

  @override
  String get developerApiBase => 'API base URL';

  @override
  String get sessionExpiredMessage =>
      'Your session has expired. Please sign in again.';

  @override
  String get configErrorTitle => 'This build cannot start';

  @override
  String get configErrorBody =>
      'The app is not configured with a secure server address, so it will not connect to any service.';

  @override
  String get errorNetwork =>
      'You appear to be offline. Check your connection and try again.';

  @override
  String get errorTimeout =>
      'The server took too long to respond. Please try again.';

  @override
  String get errorCancelled => 'The request was cancelled.';

  @override
  String get errorInsecure =>
      'A secure connection to the server could not be established.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorInvalidCredentials => 'The email or password is incorrect.';

  @override
  String get errorForbidden => 'You don\'t have permission to do that.';

  @override
  String get errorNotFound => 'We couldn\'t find what you were looking for.';

  @override
  String get errorConflict => 'This conflicts with existing data.';

  @override
  String get errorTooLarge => 'The file is too large.';

  @override
  String get errorValidation => 'Some details need to be corrected.';

  @override
  String get errorRateLimited =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get errorQuota => 'You have reached your usage limit.';

  @override
  String get errorServer =>
      'The service is temporarily unavailable. Please try again later.';

  @override
  String get errorUnexpected =>
      'Something unexpected happened. Please try again.';
}
