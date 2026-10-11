import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TEIA AI'**
  String get appTitle;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Foundation preview'**
  String get previewTitle;

  /// No description provided for @previewIntro.
  ///
  /// In en, this message translates to:
  /// **'This build shows the app\'s visual foundation only. Sign-in, chat, documents and administration arrive in later releases.'**
  String get previewIntro;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @sectionComponents.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get sectionComponents;

  /// No description provided for @componentsNote.
  ///
  /// In en, this message translates to:
  /// **'Samples only. These controls do not perform any action.'**
  String get componentsNote;

  /// No description provided for @sampleFilledButton.
  ///
  /// In en, this message translates to:
  /// **'Primary style'**
  String get sampleFilledButton;

  /// No description provided for @sampleOutlinedButton.
  ///
  /// In en, this message translates to:
  /// **'Secondary style'**
  String get sampleOutlinedButton;

  /// No description provided for @sampleTextButton.
  ///
  /// In en, this message translates to:
  /// **'Text style'**
  String get sampleTextButton;

  /// No description provided for @sampleFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample field'**
  String get sampleFieldLabel;

  /// No description provided for @sampleFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Type in English or Arabic'**
  String get sampleFieldHint;

  /// No description provided for @sampleFieldHelper.
  ///
  /// In en, this message translates to:
  /// **'Text direction follows what you type.'**
  String get sampleFieldHelper;

  /// No description provided for @bannerInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get bannerInfoTitle;

  /// No description provided for @bannerInfoBody.
  ///
  /// In en, this message translates to:
  /// **'Neutral updates use this style.'**
  String get bannerInfoBody;

  /// No description provided for @bannerSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get bannerSuccessTitle;

  /// No description provided for @bannerSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Completed actions use this style.'**
  String get bannerSuccessBody;

  /// No description provided for @bannerWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get bannerWarningTitle;

  /// No description provided for @bannerWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Situations that need attention use this style.'**
  String get bannerWarningBody;

  /// No description provided for @bannerErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get bannerErrorTitle;

  /// No description provided for @bannerErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Failures use this style together with a recovery action.'**
  String get bannerErrorBody;

  /// No description provided for @sectionStates.
  ///
  /// In en, this message translates to:
  /// **'Screen states'**
  String get sectionStates;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Content will appear here once it exists.'**
  String get emptyBody;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryLabel;

  /// No description provided for @sectionMixedText.
  ///
  /// In en, this message translates to:
  /// **'Mixed-language content'**
  String get sectionMixedText;

  /// No description provided for @mixedTextNote.
  ///
  /// In en, this message translates to:
  /// **'Each message keeps its own direction, regardless of the app language.'**
  String get mixedTextNote;

  /// No description provided for @sectionUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Coming in later releases'**
  String get sectionUpcoming;

  /// No description provided for @upcomingChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get upcomingChat;

  /// No description provided for @upcomingDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get upcomingDocuments;

  /// No description provided for @upcomingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get upcomingNotifications;

  /// No description provided for @upcomingSpaceAdmin.
  ///
  /// In en, this message translates to:
  /// **'Space administration'**
  String get upcomingSpaceAdmin;

  /// No description provided for @notAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get notAvailableYet;

  /// No description provided for @sectionDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer build'**
  String get sectionDeveloper;

  /// No description provided for @developerEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get developerEnvironment;

  /// No description provided for @developerApiBase.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get developerApiBase;

  /// No description provided for @sessionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get sessionExpiredMessage;

  /// No description provided for @configErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'This build cannot start'**
  String get configErrorTitle;

  /// No description provided for @configErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The app is not configured with a secure server address, so it will not connect to any service.'**
  String get configErrorBody;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorCancelled.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get errorCancelled;

  /// No description provided for @errorInsecure.
  ///
  /// In en, this message translates to:
  /// **'A secure connection to the server could not be established.'**
  String get errorInsecure;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The email or password is incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find what you were looking for.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'This conflicts with existing data.'**
  String get errorConflict;

  /// No description provided for @errorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large.'**
  String get errorTooLarge;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Some details need to be corrected.'**
  String get errorValidation;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorQuota.
  ///
  /// In en, this message translates to:
  /// **'You have reached your usage limit.'**
  String get errorQuota;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again later.'**
  String get errorServer;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected happened. Please try again.'**
  String get errorUnexpected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
