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

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle => 'Use your TEIA account to continue.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInAction => 'Sign in';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get createAccountLink => 'Create an account';

  @override
  String get errorInactiveAccount =>
      'This account is inactive. Contact your administrator.';

  @override
  String get signedOutNotice => 'You signed out on this device.';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get lastNameLabel => 'Last name';

  @override
  String get companyLabel => 'Company';

  @override
  String get jobTitleLabel => 'Job title';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordHelper => 'At least 8 characters.';

  @override
  String get optionalDetails => 'Optional details';

  @override
  String get registerAction => 'Create account';

  @override
  String get haveAccountLink => 'I already have an account';

  @override
  String get errorEmailTaken => 'An account with this email already exists.';

  @override
  String get registeredSignInFailed =>
      'Your account was created. Sign in to continue.';

  @override
  String get validationRequired => 'This field is required.';

  @override
  String get validationEmail => 'Enter a valid email address.';

  @override
  String get validationPasswordLength => 'Use at least 8 characters.';

  @override
  String get validationPasswordMatch => 'The passwords don\'t match.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotBody =>
      'Enter your account email. If an account exists, we\'ll send a reset link.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get forgotSent =>
      'If an account exists for this email, a reset link is on its way. It expires in 1 hour.';

  @override
  String get haveResetLink => 'I have a reset link';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String get resetCodeLabel => 'Reset link';

  @override
  String get resetCodeHelper => 'Paste the link from the reset email.';

  @override
  String get resetCodeInvalid => 'This isn\'t a valid reset link.';

  @override
  String get resetLinkReady => 'Reset link received.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get resetAction => 'Update password';

  @override
  String get resetLinkExpired =>
      'This reset link is invalid or has expired. Request a new one.';

  @override
  String get resetDone =>
      'Your password was updated. Sign in with your new password.';

  @override
  String get requestNewLink => 'Request a new link';

  @override
  String get sessionProblemTitle => 'We couldn\'t confirm your session';

  @override
  String get sessionProblemOffline =>
      'Check your connection and try again. You\'re still signed in on this device.';

  @override
  String get sessionProblemServer =>
      'The service didn\'t respond. Try again in a moment.';

  @override
  String get sessionProblemStorage =>
      'This device\'s secure storage couldn\'t be read.';

  @override
  String get signOutAction => 'Sign out';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountDetails => 'Account details';

  @override
  String get roleLabel => 'Role';

  @override
  String get roleViewer => 'Member';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleSuperAdmin => 'Super administrator';

  @override
  String get changePasswordAction => 'Change password';

  @override
  String get signOutConfirmTitle => 'Sign out of this device?';

  @override
  String get signOutConfirmBody =>
      'Your session is removed from this device. A session already issued stays valid on the server until it expires.';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get designPreview => 'Design preview';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get errorCurrentPassword => 'The current password is incorrect.';

  @override
  String get passwordChanged => 'Your password was changed.';

  @override
  String get persistenceFailedNotice =>
      'This device couldn\'t store your session securely. You may need to sign in again next time.';

  @override
  String get spacesTitle => 'Choose a space';

  @override
  String get spacesSubtitle =>
      'Spaces keep each team\'s documents and conversations separate.';

  @override
  String get spacesYours => 'Your spaces';

  @override
  String get spacesNoneTitle => 'No space yet';

  @override
  String get spacesNoneBody =>
      'Ask an administrator for an invitation, or request access to a space below.';

  @override
  String get spacesAvailable => 'Other spaces';

  @override
  String get spacesAvailableEmpty => 'No other spaces are open for requests.';

  @override
  String get requestAccess => 'Request access';

  @override
  String get accessPending => 'Request pending';

  @override
  String get accessRequested =>
      'Your request was sent to the space administrators.';

  @override
  String get spaceAccessLost =>
      'You no longer have access to the space you used before. Choose another one.';

  @override
  String get haveInvitation => 'Have an invitation?';

  @override
  String get inviteCodeLabel => 'Invitation link';

  @override
  String get inviteCodeInvalid => 'This isn\'t a valid invitation link.';

  @override
  String get inviteTitle => 'Join a space';

  @override
  String get inviteBody =>
      'Accept this invitation to join the space with the account you\'re signed in to.';

  @override
  String get inviteAction => 'Accept invitation';

  @override
  String get inviteAccepted => 'You joined the space.';

  @override
  String get inviteInvalid =>
      'This invitation is invalid, has expired, or was sent to a different email.';

  @override
  String get notNow => 'Not now';

  @override
  String get spaceRoleAdmin => 'Space administrator';

  @override
  String get spaceRoleMember => 'Member';

  @override
  String get switchSpace => 'Switch space';

  @override
  String get currentSpace => 'Current space';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String homeSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get spaceRoleLabel => 'Your role in this space';

  @override
  String get uploadsLabel => 'Document uploads';

  @override
  String get uploadsAllowed => 'Allowed';

  @override
  String get uploadsNotAllowed => 'Not allowed';

  @override
  String get selectSpaceAction => 'Open';

  @override
  String get continueAction => 'Continue';

  @override
  String get nameLabel => 'Name';

  @override
  String get chatTitle => 'Conversations';

  @override
  String get newConversation => 'New conversation';

  @override
  String get chatEmptyTitle => 'No conversations yet';

  @override
  String get chatEmptyBody =>
      'Start a conversation to ask a question in this space.';

  @override
  String get untitledConversation => 'Untitled conversation';

  @override
  String get composerHint => 'Ask a question';

  @override
  String get sendAction => 'Send';

  @override
  String get stopAction => 'Stop';

  @override
  String get modelLabel => 'Model';

  @override
  String get noModels => 'No models are available to you in this space.';

  @override
  String get assistantTyping => 'Writing a reply…';

  @override
  String get copyAction => 'Copy';

  @override
  String get copied => 'Copied to clipboard.';

  @override
  String get helpful => 'Helpful';

  @override
  String get notHelpful => 'Not helpful';

  @override
  String get branchAction => 'Continue in a new conversation';

  @override
  String get sourcesLabel => 'Sources';

  @override
  String sourceExcerpt(int index) {
    return 'Excerpt $index';
  }

  @override
  String get turnQuota => 'You\'ve reached your usage limit in this space.';

  @override
  String get turnRateLimited =>
      'Too many requests. Wait a moment, then send again.';

  @override
  String get turnPolicy =>
      'This model isn\'t allowed in this space. Choose another model.';

  @override
  String get turnProvider =>
      'The model couldn\'t finish this reply. Nothing was saved for it.';

  @override
  String get turnInterrupted =>
      'The connection ended before the reply finished. The reply wasn\'t saved.';

  @override
  String get turnStopped =>
      'You stopped this reply. Stopping only ends it on this device, and the partial reply isn\'t saved.';

  @override
  String get turnSessionNotFound => 'This conversation is no longer available.';

  @override
  String get turnDocumentAccess =>
      'You don\'t have access to a selected document.';

  @override
  String get turnProtocol => 'The reply couldn\'t be read.';

  @override
  String get turnGeneric => 'The reply couldn\'t be completed.';

  @override
  String get turnUncertain =>
      'Your question may already be saved. Check the conversation before sending it again.';

  @override
  String get sendAgain => 'Send again';

  @override
  String get dismissAction => 'Dismiss';

  @override
  String get storedReplyFailed => 'This reply failed and contains no answer.';

  @override
  String get jumpToLatest => 'Jump to latest';

  @override
  String get moreActions => 'More';

  @override
  String get summaryAction => 'Summarize';

  @override
  String get summaryTitle => 'Summary';

  @override
  String get summaryCost =>
      'Summaries are written by the model and count toward this space\'s usage.';

  @override
  String get generateAction => 'Generate';

  @override
  String get exportAction => 'Copy as Markdown';

  @override
  String get exportDone => 'Conversation copied as Markdown.';

  @override
  String get shareAction => 'Share link';

  @override
  String get shareTitle => 'Share this conversation';

  @override
  String get shareExplain =>
      'Anyone with the link can read this conversation\'s messages up to the moment you create it, until the link expires or you revoke it. Sources and document details aren\'t included.';

  @override
  String get createLinkAction => 'Create link';

  @override
  String shareCreated(String date) {
    return 'Link copied. It expires on $date.';
  }

  @override
  String get activeLinks => 'Active links';

  @override
  String get noActiveLinks => 'No active links.';

  @override
  String get revokeAction => 'Revoke';

  @override
  String get linkRevoked => 'Link revoked.';

  @override
  String expiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String get openLinkTitle => 'Open external link?';

  @override
  String openLinkBody(String host) {
    return 'This opens $host in your browser.';
  }

  @override
  String get openAction => 'Open';

  @override
  String get openChat => 'Open conversations';

  @override
  String get openDocuments => 'Documents';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsChatExplain =>
      'Chat answers search your ready documents in this space. Choose documents in a conversation to search only those.';

  @override
  String get searchDocumentsHint => 'Search documents';

  @override
  String get filterAll => 'All';

  @override
  String get filterInProgress => 'In progress';

  @override
  String get docStateReady => 'Ready';

  @override
  String get docStateFailed => 'Failed';

  @override
  String get docStateProcessing => 'Processing…';

  @override
  String get docStateIndexing => 'Preparing for search…';

  @override
  String get documentHidden => 'Hidden from members';

  @override
  String get documentsEmptyTitle => 'No documents yet';

  @override
  String get documentsEmptyUploader =>
      'Upload PDF, Word, Excel, PowerPoint, CSV or text files up to 25 MB.';

  @override
  String get documentsEmptyReader =>
      'Documents shared with you in this space appear here.';

  @override
  String get noMatchingDocuments => 'No documents match.';

  @override
  String get uploadAction => 'Upload';

  @override
  String sizeMegabytes(String value) {
    return '$value MB';
  }

  @override
  String sizeKilobytes(String value) {
    return '$value KB';
  }

  @override
  String uploadSending(String sent, String total) {
    return 'Uploading $sent of $total';
  }

  @override
  String get uploadProcessing =>
      'Uploaded. The server is reading and indexing the file; this can take a few minutes.';

  @override
  String get uploadChecking =>
      'The connection failed, so it\'s unclear whether the file arrived. Checking with the server before anything is sent again.';

  @override
  String get uploadReady => 'Ready to use in chat.';

  @override
  String get uploadReceived => 'Received by the server.';

  @override
  String get uploadCancelled =>
      'Stopped on this device. If the file had already arrived, the server keeps processing it and it will appear in the list.';

  @override
  String get uploadNotReceived =>
      'The upload didn\'t reach the server. You can upload the file again.';

  @override
  String get cancelUploadAction => 'Cancel upload';

  @override
  String get stopWaitingAction => 'Stop waiting';

  @override
  String get checkAgainAction => 'Check again';

  @override
  String get viewDetailsAction => 'Details';

  @override
  String get doneAction => 'Done';

  @override
  String get docErrorEncrypted =>
      'This file is password-protected or uses an old Office format. Remove the password or save it as a new file, then upload it again.';

  @override
  String get docErrorCorrupt =>
      'The file is damaged or isn\'t what its name says.';

  @override
  String get docErrorNoText =>
      'No readable text was found. Scanned documents may need text recognition before upload.';

  @override
  String get docErrorTooComplex =>
      'The file is too large or complex to process.';

  @override
  String get docErrorUnsupported =>
      'This file type isn\'t supported. Use PDF, Word, Excel, PowerPoint, CSV, or UTF-8 text.';

  @override
  String get docErrorTooLarge => 'Files must be 25 MB or smaller.';

  @override
  String get docErrorEmpty => 'The file is empty.';

  @override
  String get docErrorTimeout => 'Processing took too long and was stopped.';

  @override
  String get docErrorInterrupted => 'Processing was interrupted on the server.';

  @override
  String get docErrorStorage =>
      'The file couldn\'t be stored. Upload it again.';

  @override
  String get docErrorGeneric => 'The document couldn\'t be processed.';

  @override
  String get errorUnsupportedFile => 'This file type isn\'t supported.';

  @override
  String get documentDetailsTitle => 'Document';

  @override
  String get documentUnavailableTitle => 'Document unavailable';

  @override
  String get documentUnavailableBody =>
      'It was removed, hidden, or your access changed.';

  @override
  String get docProcessingExplain =>
      'The server is reading and indexing this document. It can be used in chat once it is ready.';

  @override
  String get retryProcessingAction => 'Try processing again';

  @override
  String get documentInfoTitle => 'Details';

  @override
  String get fileTypeLabel => 'Type';

  @override
  String get fileSizeLabel => 'Size';

  @override
  String get uploadedLabel => 'Uploaded';

  @override
  String get sectionsLabel => 'Indexed sections';

  @override
  String get useInChatAction => 'Use in chat';

  @override
  String get selectedForChat => 'Selected for chat';

  @override
  String get openDocumentAction => 'Open document';

  @override
  String get openFileFailed => 'No app on this device could open the file.';

  @override
  String get localCopyExplain =>
      'Opening downloads a copy into this app\'s private storage. It is deleted when you sign out or switch space. Copies you share to other apps can\'t be recalled.';

  @override
  String get chooseDocumentsAction => 'Choose documents';

  @override
  String get chooseDocumentsTitle => 'Documents for this conversation';

  @override
  String get chooseDocumentsExplain =>
      'With nothing selected, answers search all your ready documents in this space. Select documents to search only those.';

  @override
  String get scopeAllDocuments => 'Searching all your ready documents';

  @override
  String scopeSelectedDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Searching $count selected documents',
      one: 'Searching 1 selected document',
    );
    return '$_temp0';
  }

  @override
  String documentsNotReadyHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count documents are still processing and can\'t be selected yet.',
      one: '1 document is still processing and can\'t be selected yet.',
    );
    return '$_temp0';
  }

  @override
  String get noReadyDocuments => 'No ready documents in this space yet.';

  @override
  String get clearSelection => 'Clear';

  @override
  String get removeFromSelection => 'Remove from selection';

  @override
  String selectionPruned(String names, String scope) {
    return 'Removed from your selection because it\'s no longer available: $names. Now: $scope.';
  }

  @override
  String get listSeparator => ', ';

  @override
  String get reviewDocumentsAction => 'Review documents';

  @override
  String get turnDocumentNotReady =>
      'A selected document isn\'t ready yet. Nothing was searched instead.';

  @override
  String get sourceUnavailable => 'Source unavailable';

  @override
  String get sourceUnavailableBody =>
      'You no longer have access to this source, so its excerpt isn\'t shown. The answer text you already received stays in the conversation.';

  @override
  String get sourceSavedNote =>
      'This excerpt was saved with the answer. Access is checked again every time you open the conversation.';

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get imageNotLoaded => 'Image not loaded';

  @override
  String get openLinkFailed => 'The link couldn\'t be opened.';
}
