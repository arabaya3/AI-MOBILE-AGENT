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

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatTitle;

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newConversation;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation to ask a question in this space.'**
  String get chatEmptyBody;

  /// No description provided for @untitledConversation.
  ///
  /// In en, this message translates to:
  /// **'Untitled conversation'**
  String get untitledConversation;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get composerHint;

  /// No description provided for @sendAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendAction;

  /// No description provided for @stopAction.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopAction;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @noModels.
  ///
  /// In en, this message translates to:
  /// **'No models are available to you in this space.'**
  String get noModels;

  /// No description provided for @assistantTyping.
  ///
  /// In en, this message translates to:
  /// **'Writing a reply…'**
  String get assistantTyping;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard.'**
  String get copied;

  /// No description provided for @helpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get helpful;

  /// No description provided for @notHelpful.
  ///
  /// In en, this message translates to:
  /// **'Not helpful'**
  String get notHelpful;

  /// No description provided for @branchAction.
  ///
  /// In en, this message translates to:
  /// **'Continue in a new conversation'**
  String get branchAction;

  /// No description provided for @sourcesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesLabel;

  /// No description provided for @sourceExcerpt.
  ///
  /// In en, this message translates to:
  /// **'Excerpt {index}'**
  String sourceExcerpt(int index);

  /// No description provided for @turnQuota.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your usage limit in this space.'**
  String get turnQuota;

  /// No description provided for @turnRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a moment, then send again.'**
  String get turnRateLimited;

  /// No description provided for @turnPolicy.
  ///
  /// In en, this message translates to:
  /// **'This model isn\'t allowed in this space. Choose another model.'**
  String get turnPolicy;

  /// No description provided for @turnProvider.
  ///
  /// In en, this message translates to:
  /// **'The model couldn\'t finish this reply. Nothing was saved for it.'**
  String get turnProvider;

  /// No description provided for @turnInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The connection ended before the reply finished. The reply wasn\'t saved.'**
  String get turnInterrupted;

  /// No description provided for @turnStopped.
  ///
  /// In en, this message translates to:
  /// **'You stopped this reply. Stopping only ends it on this device, and the partial reply isn\'t saved.'**
  String get turnStopped;

  /// No description provided for @turnSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'This conversation is no longer available.'**
  String get turnSessionNotFound;

  /// No description provided for @turnDocumentAccess.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to a selected document.'**
  String get turnDocumentAccess;

  /// No description provided for @turnProtocol.
  ///
  /// In en, this message translates to:
  /// **'The reply couldn\'t be read.'**
  String get turnProtocol;

  /// No description provided for @turnGeneric.
  ///
  /// In en, this message translates to:
  /// **'The reply couldn\'t be completed.'**
  String get turnGeneric;

  /// No description provided for @turnUncertain.
  ///
  /// In en, this message translates to:
  /// **'Your question may already be saved. Check the conversation before sending it again.'**
  String get turnUncertain;

  /// No description provided for @sendAgain.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get sendAgain;

  /// No description provided for @dismissAction.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissAction;

  /// No description provided for @storedReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'This reply failed and contains no answer.'**
  String get storedReplyFailed;

  /// No description provided for @jumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get jumpToLatest;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// No description provided for @summaryAction.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get summaryAction;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryTitle;

  /// No description provided for @summaryCost.
  ///
  /// In en, this message translates to:
  /// **'Summaries are written by the model and count toward this space\'s usage.'**
  String get summaryCost;

  /// No description provided for @generateAction.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generateAction;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'Copy as Markdown'**
  String get exportAction;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Conversation copied as Markdown.'**
  String get exportDone;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get shareAction;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this conversation'**
  String get shareTitle;

  /// No description provided for @shareExplain.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can read this conversation\'s messages up to the moment you create it, until the link expires or you revoke it. Sources and document details aren\'t included.'**
  String get shareExplain;

  /// No description provided for @createLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Create link'**
  String get createLinkAction;

  /// No description provided for @shareCreated.
  ///
  /// In en, this message translates to:
  /// **'Link copied. It expires on {date}.'**
  String shareCreated(String date);

  /// No description provided for @activeLinks.
  ///
  /// In en, this message translates to:
  /// **'Active links'**
  String get activeLinks;

  /// No description provided for @noActiveLinks.
  ///
  /// In en, this message translates to:
  /// **'No active links.'**
  String get noActiveLinks;

  /// No description provided for @revokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revokeAction;

  /// No description provided for @linkRevoked.
  ///
  /// In en, this message translates to:
  /// **'Link revoked.'**
  String get linkRevoked;

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresOn(String date);

  /// No description provided for @openLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Open external link?'**
  String get openLinkTitle;

  /// No description provided for @openLinkBody.
  ///
  /// In en, this message translates to:
  /// **'This opens {host} in your browser.'**
  String openLinkBody(String host);

  /// No description provided for @openAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openAction;

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Open conversations'**
  String get openChat;

  /// No description provided for @openDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get openDocuments;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsTitle;

  /// No description provided for @documentsChatExplain.
  ///
  /// In en, this message translates to:
  /// **'Chat answers search your ready documents in this space. Choose documents in a conversation to search only those.'**
  String get documentsChatExplain;

  /// No description provided for @searchDocumentsHint.
  ///
  /// In en, this message translates to:
  /// **'Search documents'**
  String get searchDocumentsHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get filterInProgress;

  /// No description provided for @docStateReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get docStateReady;

  /// No description provided for @docStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get docStateFailed;

  /// No description provided for @docStateProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get docStateProcessing;

  /// No description provided for @docStateIndexing.
  ///
  /// In en, this message translates to:
  /// **'Preparing for search…'**
  String get docStateIndexing;

  /// No description provided for @documentHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden from members'**
  String get documentHidden;

  /// No description provided for @documentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get documentsEmptyTitle;

  /// No description provided for @documentsEmptyUploader.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF, Word, Excel, PowerPoint, CSV or text files up to 25 MB.'**
  String get documentsEmptyUploader;

  /// No description provided for @documentsEmptyReader.
  ///
  /// In en, this message translates to:
  /// **'Documents shared with you in this space appear here.'**
  String get documentsEmptyReader;

  /// No description provided for @noMatchingDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents match.'**
  String get noMatchingDocuments;

  /// No description provided for @uploadAction.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadAction;

  /// No description provided for @sizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String sizeMegabytes(String value);

  /// No description provided for @sizeKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String sizeKilobytes(String value);

  /// No description provided for @uploadSending.
  ///
  /// In en, this message translates to:
  /// **'Uploading {sent} of {total}'**
  String uploadSending(String sent, String total);

  /// No description provided for @uploadProcessing.
  ///
  /// In en, this message translates to:
  /// **'Uploaded. The server is reading and indexing the file; this can take a few minutes.'**
  String get uploadProcessing;

  /// No description provided for @uploadChecking.
  ///
  /// In en, this message translates to:
  /// **'The connection failed, so it\'s unclear whether the file arrived. Checking with the server before anything is sent again.'**
  String get uploadChecking;

  /// No description provided for @uploadReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to use in chat.'**
  String get uploadReady;

  /// No description provided for @uploadReceived.
  ///
  /// In en, this message translates to:
  /// **'Received by the server.'**
  String get uploadReceived;

  /// No description provided for @uploadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Stopped on this device. If the file had already arrived, the server keeps processing it and it will appear in the list.'**
  String get uploadCancelled;

  /// No description provided for @uploadNotReceived.
  ///
  /// In en, this message translates to:
  /// **'The upload didn\'t reach the server. You can upload the file again.'**
  String get uploadNotReceived;

  /// No description provided for @cancelUploadAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload'**
  String get cancelUploadAction;

  /// No description provided for @stopWaitingAction.
  ///
  /// In en, this message translates to:
  /// **'Stop waiting'**
  String get stopWaitingAction;

  /// No description provided for @checkAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgainAction;

  /// No description provided for @viewDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get viewDetailsAction;

  /// No description provided for @doneAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneAction;

  /// No description provided for @docErrorEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This file is password-protected or uses an old Office format. Remove the password or save it as a new file, then upload it again.'**
  String get docErrorEncrypted;

  /// No description provided for @docErrorCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The file is damaged or isn\'t what its name says.'**
  String get docErrorCorrupt;

  /// No description provided for @docErrorNoText.
  ///
  /// In en, this message translates to:
  /// **'No readable text was found. Scanned documents may need text recognition before upload.'**
  String get docErrorNoText;

  /// No description provided for @docErrorTooComplex.
  ///
  /// In en, this message translates to:
  /// **'The file is too large or complex to process.'**
  String get docErrorTooComplex;

  /// No description provided for @docErrorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported. Use PDF, Word, Excel, PowerPoint, CSV, or UTF-8 text.'**
  String get docErrorUnsupported;

  /// No description provided for @docErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Files must be 25 MB or smaller.'**
  String get docErrorTooLarge;

  /// No description provided for @docErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty.'**
  String get docErrorEmpty;

  /// No description provided for @docErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Processing took too long and was stopped.'**
  String get docErrorTimeout;

  /// No description provided for @docErrorInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Processing was interrupted on the server.'**
  String get docErrorInterrupted;

  /// No description provided for @docErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'The file couldn\'t be stored. Upload it again.'**
  String get docErrorStorage;

  /// No description provided for @docErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'The document couldn\'t be processed.'**
  String get docErrorGeneric;

  /// No description provided for @errorUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported.'**
  String get errorUnsupportedFile;

  /// No description provided for @documentDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get documentDetailsTitle;

  /// No description provided for @documentUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Document unavailable'**
  String get documentUnavailableTitle;

  /// No description provided for @documentUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'It was removed, hidden, or your access changed.'**
  String get documentUnavailableBody;

  /// No description provided for @docProcessingExplain.
  ///
  /// In en, this message translates to:
  /// **'The server is reading and indexing this document. It can be used in chat once it is ready.'**
  String get docProcessingExplain;

  /// No description provided for @retryProcessingAction.
  ///
  /// In en, this message translates to:
  /// **'Try processing again'**
  String get retryProcessingAction;

  /// No description provided for @documentInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get documentInfoTitle;

  /// No description provided for @fileTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fileTypeLabel;

  /// No description provided for @fileSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileSizeLabel;

  /// No description provided for @uploadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploadedLabel;

  /// No description provided for @sectionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Indexed sections'**
  String get sectionsLabel;

  /// No description provided for @useInChatAction.
  ///
  /// In en, this message translates to:
  /// **'Use in chat'**
  String get useInChatAction;

  /// No description provided for @selectedForChat.
  ///
  /// In en, this message translates to:
  /// **'Selected for chat'**
  String get selectedForChat;

  /// No description provided for @openDocumentAction.
  ///
  /// In en, this message translates to:
  /// **'Open document'**
  String get openDocumentAction;

  /// No description provided for @openFileFailed.
  ///
  /// In en, this message translates to:
  /// **'No app on this device could open the file.'**
  String get openFileFailed;

  /// No description provided for @localCopyExplain.
  ///
  /// In en, this message translates to:
  /// **'Opening downloads a copy into this app\'s private storage. It is deleted when you sign out or switch space. Copies you share to other apps can\'t be recalled.'**
  String get localCopyExplain;

  /// No description provided for @chooseDocumentsAction.
  ///
  /// In en, this message translates to:
  /// **'Choose documents'**
  String get chooseDocumentsAction;

  /// No description provided for @chooseDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents for this conversation'**
  String get chooseDocumentsTitle;

  /// No description provided for @chooseDocumentsExplain.
  ///
  /// In en, this message translates to:
  /// **'With nothing selected, answers search all your ready documents in this space. Select documents to search only those.'**
  String get chooseDocumentsExplain;

  /// No description provided for @scopeAllDocuments.
  ///
  /// In en, this message translates to:
  /// **'Searching all your ready documents'**
  String get scopeAllDocuments;

  /// No description provided for @scopeSelectedDocuments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Searching 1 selected document} other{Searching {count} selected documents}}'**
  String scopeSelectedDocuments(int count);

  /// No description provided for @documentsNotReadyHidden.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document is still processing and can\'t be selected yet.} other{{count} documents are still processing and can\'t be selected yet.}}'**
  String documentsNotReadyHidden(int count);

  /// No description provided for @noReadyDocuments.
  ///
  /// In en, this message translates to:
  /// **'No ready documents in this space yet.'**
  String get noReadyDocuments;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearSelection;

  /// No description provided for @removeFromSelection.
  ///
  /// In en, this message translates to:
  /// **'Remove from selection'**
  String get removeFromSelection;

  /// No description provided for @selectionPruned.
  ///
  /// In en, this message translates to:
  /// **'Removed from your selection because it\'s no longer available: {names}. Now: {scope}.'**
  String selectionPruned(String names, String scope);

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @reviewDocumentsAction.
  ///
  /// In en, this message translates to:
  /// **'Review documents'**
  String get reviewDocumentsAction;

  /// No description provided for @turnDocumentNotReady.
  ///
  /// In en, this message translates to:
  /// **'A selected document isn\'t ready yet. Nothing was searched instead.'**
  String get turnDocumentNotReady;

  /// No description provided for @sourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Source unavailable'**
  String get sourceUnavailable;

  /// No description provided for @sourceUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access to this source, so its excerpt isn\'t shown. The answer text you already received stays in the conversation.'**
  String get sourceUnavailableBody;

  /// No description provided for @sourceSavedNote.
  ///
  /// In en, this message translates to:
  /// **'This excerpt was saved with the answer. Access is checked again every time you open the conversation.'**
  String get sourceSavedNote;

  /// No description provided for @pageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageNumber(int page);

  /// No description provided for @imageNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Image not loaded'**
  String get imageNotLoaded;

  /// No description provided for @openLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'The link couldn\'t be opened.'**
  String get openLinkFailed;

  /// No description provided for @docErrorDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be added to this space. If you need it, ask a space admin for access.'**
  String get docErrorDuplicate;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread notification} other{{count} unread notifications}}'**
  String notificationsUnread(int count);

  /// No description provided for @markAllReadAction.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllReadAction;

  /// No description provided for @notificationsReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Live updates are paused; reconnecting. The list refreshes once connected.'**
  String get notificationsReconnecting;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Updates about your requests and spaces appear here.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationTargetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This is no longer available to you.'**
  String get notificationTargetUnavailable;

  /// No description provided for @notifApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request approved'**
  String get notifApprovedTitle;

  /// No description provided for @notifApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Your {type} request in {space} was approved.'**
  String notifApprovedBody(String type, String space);

  /// No description provided for @notifDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get notifDeclinedTitle;

  /// No description provided for @notifDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'Your {type} request in {space} was declined.'**
  String notifDeclinedBody(String type, String space);

  /// No description provided for @notifDeclinedBodyNote.
  ///
  /// In en, this message translates to:
  /// **'Your {type} request in {space} was declined. Note: {note}'**
  String notifDeclinedBodyNote(String type, String space, String note);

  /// No description provided for @notifPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Space settings changed'**
  String get notifPolicyTitle;

  /// No description provided for @notifPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'The models or limits in {space} were updated.'**
  String notifPolicyBody(String space);

  /// No description provided for @notifInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get notifInviteTitle;

  /// No description provided for @notifInviteBody.
  ///
  /// In en, this message translates to:
  /// **'You were invited to join {space}.'**
  String notifInviteBody(String space);

  /// No description provided for @notifQuotaTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage limit approaching'**
  String get notifQuotaTitle;

  /// No description provided for @notifQuotaBody.
  ///
  /// In en, this message translates to:
  /// **'You are close to a usage limit in {space}.'**
  String notifQuotaBody(String space);

  /// No description provided for @requestTypeJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get requestTypeJoin;

  /// No description provided for @requestTypeModel.
  ///
  /// In en, this message translates to:
  /// **'Model access'**
  String get requestTypeModel;

  /// No description provided for @requestTypeTool.
  ///
  /// In en, this message translates to:
  /// **'Tool access'**
  String get requestTypeTool;

  /// No description provided for @requestTypeQuota.
  ///
  /// In en, this message translates to:
  /// **'Higher limits'**
  String get requestTypeQuota;

  /// No description provided for @requestTypeUpload.
  ///
  /// In en, this message translates to:
  /// **'Document uploads'**
  String get requestTypeUpload;

  /// No description provided for @requestTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get requestTypeOther;

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usageTitle;

  /// No description provided for @periodDay.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get periodDay;

  /// No description provided for @periodDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String periodDays(int days);

  /// No description provided for @usageWindow.
  ///
  /// In en, this message translates to:
  /// **'From {start} to {end}, your local time. Windows roll back from now.'**
  String usageWindow(String start, String end);

  /// No description provided for @usageSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get usageSummaryTitle;

  /// No description provided for @usageRequests.
  ///
  /// In en, this message translates to:
  /// **'Replies requested'**
  String get usageRequests;

  /// No description provided for @usageUnknownRequests.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reply has no reported usage (for example stopped or interrupted).} other{{count} replies have no reported usage (for example stopped or interrupted).}}'**
  String usageUnknownRequests(int count);

  /// No description provided for @usageInputTokens.
  ///
  /// In en, this message translates to:
  /// **'Input tokens'**
  String get usageInputTokens;

  /// No description provided for @usageOutputTokens.
  ///
  /// In en, this message translates to:
  /// **'Output tokens'**
  String get usageOutputTokens;

  /// No description provided for @usageTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total tokens'**
  String get usageTotalTokens;

  /// No description provided for @usageCostTitle.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost'**
  String get usageCostTitle;

  /// No description provided for @usageCostBasis.
  ///
  /// In en, this message translates to:
  /// **'Estimated from list prices in US dollars; not a provider invoice.'**
  String get usageCostBasis;

  /// No description provided for @usageCostUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get usageCostUnavailable;

  /// No description provided for @usageCostIncomplete.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reply has no usage or price data and is not included.} other{{count} replies have no usage or price data and are not included.}}'**
  String usageCostIncomplete(int count);

  /// No description provided for @usageCostNone.
  ///
  /// In en, this message translates to:
  /// **'No reply in this period has usage and price data, so no cost can be shown. This does not mean it was free.'**
  String get usageCostNone;

  /// No description provided for @usageLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get usageLimitsTitle;

  /// No description provided for @usageLimitsExplain.
  ///
  /// In en, this message translates to:
  /// **'Limits count back from now. Conversation limits count conversations started.'**
  String get usageLimitsExplain;

  /// No description provided for @usageByModel.
  ///
  /// In en, this message translates to:
  /// **'By model'**
  String get usageByModel;

  /// No description provided for @usageModelLine.
  ///
  /// In en, this message translates to:
  /// **'{requests} replies · {tokens} tokens'**
  String usageModelLine(String requests, String tokens);

  /// No description provided for @usageTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get usageTools;

  /// No description provided for @usageToolCalls.
  ///
  /// In en, this message translates to:
  /// **'{count} calls'**
  String usageToolCalls(String count);

  /// No description provided for @limitTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get limitTokens;

  /// No description provided for @limitConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get limitConversations;

  /// No description provided for @limitToolRequests.
  ///
  /// In en, this message translates to:
  /// **'Tool calls'**
  String get limitToolRequests;

  /// No description provided for @limitLast24h.
  ///
  /// In en, this message translates to:
  /// **'last 24 hours'**
  String get limitLast24h;

  /// No description provided for @limitLast30d.
  ///
  /// In en, this message translates to:
  /// **'last 30 days'**
  String get limitLast30d;

  /// No description provided for @limitNone.
  ///
  /// In en, this message translates to:
  /// **'{used} used · no limit'**
  String limitNone(String used);

  /// No description provided for @limitValue.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} used · {remaining} left'**
  String limitValue(String used, String limit, String remaining);

  /// No description provided for @limitReserved.
  ///
  /// In en, this message translates to:
  /// **'Includes {tokens} counted for replies whose usage was never reported.'**
  String limitReserved(String tokens);

  /// No description provided for @invoiceAction.
  ///
  /// In en, this message translates to:
  /// **'Share invoice (PDF)'**
  String get invoiceAction;

  /// No description provided for @invoiceExplain.
  ///
  /// In en, this message translates to:
  /// **'The PDF is created by the server for the selected period and kept in this app\'s private storage until you sign out or switch space.'**
  String get invoiceExplain;

  /// No description provided for @invoiceShareSubject.
  ///
  /// In en, this message translates to:
  /// **'TEIA usage invoice'**
  String get invoiceShareSubject;

  /// No description provided for @shareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing isn\'t available on this device.'**
  String get shareUnavailable;

  /// No description provided for @requestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requestsTitle;

  /// No description provided for @requestsExplain.
  ///
  /// In en, this message translates to:
  /// **'Requests you sent to space administrators. Approvals update your access automatically.'**
  String get requestsExplain;

  /// No description provided for @requestsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get requestsEmptyTitle;

  /// No description provided for @requestsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Ask for model access, higher limits or upload rights.'**
  String get requestsEmptyBody;

  /// No description provided for @accountRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account requests'**
  String get accountRequestsTitle;

  /// No description provided for @requestPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get requestPending;

  /// No description provided for @requestApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get requestApproved;

  /// No description provided for @requestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get requestDeclined;

  /// No description provided for @requestSentOn.
  ///
  /// In en, this message translates to:
  /// **'Sent {date}'**
  String requestSentOn(String date);

  /// No description provided for @reviewerNote.
  ///
  /// In en, this message translates to:
  /// **'Reviewer\'s note'**
  String get reviewerNote;

  /// No description provided for @newRequestAction.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newRequestAction;

  /// No description provided for @newRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newRequestTitle;

  /// No description provided for @requestUploadExplain.
  ///
  /// In en, this message translates to:
  /// **'Ask to upload documents in this space.'**
  String get requestUploadExplain;

  /// No description provided for @requestReason.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get requestReason;

  /// No description provided for @requestReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get requestReasonOptional;

  /// No description provided for @requestChooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model.'**
  String get requestChooseModel;

  /// No description provided for @requestQuotaInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one whole number above zero.'**
  String get requestQuotaInvalid;

  /// No description provided for @requestReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Describe what you need.'**
  String get requestReasonRequired;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent.'**
  String get requestSent;

  /// No description provided for @requestAlreadyPending.
  ///
  /// In en, this message translates to:
  /// **'You already have this request pending.'**
  String get requestAlreadyPending;

  /// No description provided for @requestUncertain.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm the request. The list was refreshed; check it before sending again.'**
  String get requestUncertain;

  /// No description provided for @sendRequestAction.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequestAction;

  /// No description provided for @quotaDailyTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens per 24 hours'**
  String get quotaDailyTokens;

  /// No description provided for @quotaMonthlyTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens per 30 days'**
  String get quotaMonthlyTokens;

  /// No description provided for @quotaDailyConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations per 24 hours'**
  String get quotaDailyConversations;

  /// No description provided for @quotaMonthlyConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations per 30 days'**
  String get quotaMonthlyConversations;

  /// No description provided for @renameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameAction;

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get renameTitle;

  /// No description provided for @conversationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get conversationNameLabel;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @exportFileAction.
  ///
  /// In en, this message translates to:
  /// **'Share as file'**
  String get exportFileAction;

  /// No description provided for @deleteConversationAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteConversationAction;

  /// No description provided for @deleteConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get deleteConversationTitle;

  /// No description provided for @deleteConversationBody.
  ///
  /// In en, this message translates to:
  /// **'Its messages are deleted and its share links stop working. Usage records are kept. Copies you already shared or exported can\'t be recalled.'**
  String get deleteConversationBody;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @conversationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Conversation deleted.'**
  String get conversationDeleted;

  /// No description provided for @replyLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Reply language'**
  String get replyLanguageTitle;

  /// No description provided for @replyLanguageExplain.
  ///
  /// In en, this message translates to:
  /// **'The language the assistant answers in. Automatic follows your question.'**
  String get replyLanguageExplain;

  /// No description provided for @replyLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get replyLanguageAuto;

  /// No description provided for @upcomingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get upcomingNotifications;
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
