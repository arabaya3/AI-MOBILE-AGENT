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

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your TEIA account to continue.'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInAction;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @createAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccountLink;

  /// No description provided for @errorInactiveAccount.
  ///
  /// In en, this message translates to:
  /// **'This account is inactive. Contact your administrator.'**
  String get errorInactiveAccount;

  /// No description provided for @signedOutNotice.
  ///
  /// In en, this message translates to:
  /// **'You signed out on this device.'**
  String get signedOutNotice;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstNameLabel;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastNameLabel;

  /// No description provided for @companyLabel.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get companyLabel;

  /// No description provided for @jobTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Job title'**
  String get jobTitleLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get passwordHelper;

  /// No description provided for @optionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get optionalDetails;

  /// No description provided for @registerAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerAction;

  /// No description provided for @haveAccountLink.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get haveAccountLink;

  /// No description provided for @errorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get errorEmailTaken;

  /// No description provided for @registeredSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account was created. Sign in to continue.'**
  String get registeredSignInFailed;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get validationRequired;

  /// No description provided for @validationEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validationEmail;

  /// No description provided for @validationPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get validationPasswordLength;

  /// No description provided for @validationPasswordMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get validationPasswordMatch;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email. If an account exists, we\'ll send a reset link.'**
  String get forgotBody;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @forgotSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, a reset link is on its way. It expires in 1 hour.'**
  String get forgotSent;

  /// No description provided for @haveResetLink.
  ///
  /// In en, this message translates to:
  /// **'I have a reset link'**
  String get haveResetLink;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetTitle;

  /// No description provided for @resetCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset link'**
  String get resetCodeLabel;

  /// No description provided for @resetCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Paste the link from the reset email.'**
  String get resetCodeHelper;

  /// No description provided for @resetCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a valid reset link.'**
  String get resetCodeInvalid;

  /// No description provided for @resetLinkReady.
  ///
  /// In en, this message translates to:
  /// **'Reset link received.'**
  String get resetLinkReady;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @resetAction.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get resetAction;

  /// No description provided for @resetLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This reset link is invalid or has expired. Request a new one.'**
  String get resetLinkExpired;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'Your password was updated. Sign in with your new password.'**
  String get resetDone;

  /// No description provided for @requestNewLink.
  ///
  /// In en, this message translates to:
  /// **'Request a new link'**
  String get requestNewLink;

  /// No description provided for @sessionProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm your session'**
  String get sessionProblemTitle;

  /// No description provided for @sessionProblemOffline.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. You\'re still signed in on this device.'**
  String get sessionProblemOffline;

  /// No description provided for @sessionProblemServer.
  ///
  /// In en, this message translates to:
  /// **'The service didn\'t respond. Try again in a moment.'**
  String get sessionProblemServer;

  /// No description provided for @sessionProblemStorage.
  ///
  /// In en, this message translates to:
  /// **'This device\'s secure storage couldn\'t be read.'**
  String get sessionProblemStorage;

  /// No description provided for @signOutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutAction;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get accountDetails;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleViewer;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super administrator'**
  String get roleSuperAdmin;

  /// No description provided for @changePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordAction;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this device?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your session is removed from this device. A session already issued stays valid on the server until it expires.'**
  String get signOutConfirmBody;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @designPreview.
  ///
  /// In en, this message translates to:
  /// **'Design preview'**
  String get designPreview;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @errorCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'The current password is incorrect.'**
  String get errorCurrentPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed.'**
  String get passwordChanged;

  /// No description provided for @persistenceFailedNotice.
  ///
  /// In en, this message translates to:
  /// **'This device couldn\'t store your session securely. You may need to sign in again next time.'**
  String get persistenceFailedNotice;

  /// No description provided for @spacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a space'**
  String get spacesTitle;

  /// No description provided for @spacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spaces keep each team\'s documents and conversations separate.'**
  String get spacesSubtitle;

  /// No description provided for @spacesYours.
  ///
  /// In en, this message translates to:
  /// **'Your spaces'**
  String get spacesYours;

  /// No description provided for @spacesNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No space yet'**
  String get spacesNoneTitle;

  /// No description provided for @spacesNoneBody.
  ///
  /// In en, this message translates to:
  /// **'Ask an administrator for an invitation, or request access to a space below.'**
  String get spacesNoneBody;

  /// No description provided for @spacesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Other spaces'**
  String get spacesAvailable;

  /// No description provided for @spacesAvailableEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other spaces are open for requests.'**
  String get spacesAvailableEmpty;

  /// No description provided for @requestAccess.
  ///
  /// In en, this message translates to:
  /// **'Request access'**
  String get requestAccess;

  /// No description provided for @accessPending.
  ///
  /// In en, this message translates to:
  /// **'Request pending'**
  String get accessPending;

  /// No description provided for @accessRequested.
  ///
  /// In en, this message translates to:
  /// **'Your request was sent to the space administrators.'**
  String get accessRequested;

  /// No description provided for @spaceAccessLost.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access to the space you used before. Choose another one.'**
  String get spaceAccessLost;

  /// No description provided for @haveInvitation.
  ///
  /// In en, this message translates to:
  /// **'Have an invitation?'**
  String get haveInvitation;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation link'**
  String get inviteCodeLabel;

  /// No description provided for @inviteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a valid invitation link.'**
  String get inviteCodeInvalid;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a space'**
  String get inviteTitle;

  /// No description provided for @inviteBody.
  ///
  /// In en, this message translates to:
  /// **'Accept this invitation to join the space with the account you\'re signed in to.'**
  String get inviteBody;

  /// No description provided for @inviteAction.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get inviteAction;

  /// No description provided for @inviteAccepted.
  ///
  /// In en, this message translates to:
  /// **'You joined the space.'**
  String get inviteAccepted;

  /// No description provided for @inviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'This invitation is invalid, has expired, or was sent to a different email.'**
  String get inviteInvalid;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @spaceRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Space administrator'**
  String get spaceRoleAdmin;

  /// No description provided for @spaceRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get spaceRoleMember;

  /// No description provided for @switchSpace.
  ///
  /// In en, this message translates to:
  /// **'Switch space'**
  String get switchSpace;

  /// No description provided for @currentSpace.
  ///
  /// In en, this message translates to:
  /// **'Current space'**
  String get currentSpace;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String homeSignedInAs(String email);

  /// No description provided for @spaceRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Your role in this space'**
  String get spaceRoleLabel;

  /// No description provided for @uploadsLabel.
  ///
  /// In en, this message translates to:
  /// **'Document uploads'**
  String get uploadsLabel;

  /// No description provided for @uploadsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get uploadsAllowed;

  /// No description provided for @uploadsNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get uploadsNotAllowed;

  /// No description provided for @selectSpaceAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get selectSpaceAction;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;
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
