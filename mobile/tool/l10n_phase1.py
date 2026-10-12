"""One-off merge of Phase 1 strings into the ARB files (kept for review traceability)."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib/l10n"

STRINGS = {
    "signInTitle": ("Sign in", "تسجيل الدخول"),
    "signInSubtitle": ("Use your TEIA account to continue.", "استخدم حسابك في TEIA للمتابعة."),
    "emailLabel": ("Email", "البريد الإلكتروني"),
    "passwordLabel": ("Password", "كلمة المرور"),
    "showPassword": ("Show password", "إظهار كلمة المرور"),
    "hidePassword": ("Hide password", "إخفاء كلمة المرور"),
    "signInAction": ("Sign in", "تسجيل الدخول"),
    "forgotPasswordLink": ("Forgot password?", "نسيت كلمة المرور؟"),
    "createAccountLink": ("Create an account", "إنشاء حساب"),
    "errorInactiveAccount": ("This account is inactive. Contact your administrator.", "هذا الحساب غير مفعّل. تواصل مع المسؤول."),
    "signedOutNotice": ("You signed out on this device.", "سجّلت الخروج من هذا الجهاز."),
    "registerTitle": ("Create your account", "إنشاء حسابك"),
    "firstNameLabel": ("First name", "الاسم الأول"),
    "lastNameLabel": ("Last name", "اسم العائلة"),
    "companyLabel": ("Company", "الشركة"),
    "jobTitleLabel": ("Job title", "المسمّى الوظيفي"),
    "confirmPasswordLabel": ("Confirm password", "تأكيد كلمة المرور"),
    "passwordHelper": ("At least 8 characters.", "8 أحرف على الأقل."),
    "optionalDetails": ("Optional details", "تفاصيل اختيارية"),
    "registerAction": ("Create account", "إنشاء الحساب"),
    "haveAccountLink": ("I already have an account", "لدي حساب بالفعل"),
    "errorEmailTaken": ("An account with this email already exists.", "يوجد حساب مسجّل بهذا البريد الإلكتروني."),
    "registeredSignInFailed": ("Your account was created. Sign in to continue.", "تم إنشاء حسابك. سجّل الدخول للمتابعة."),
    "validationRequired": ("This field is required.", "هذا الحقل مطلوب."),
    "validationEmail": ("Enter a valid email address.", "أدخل بريدًا إلكترونيًا صالحًا."),
    "validationPasswordLength": ("Use at least 8 characters.", "استخدم 8 أحرف على الأقل."),
    "validationPasswordMatch": ("The passwords don't match.", "كلمتا المرور غير متطابقتين."),
    "forgotTitle": ("Reset your password", "إعادة تعيين كلمة المرور"),
    "forgotBody": ("Enter your account email. If an account exists, we'll send a reset link.", "أدخل البريد الإلكتروني لحسابك. إذا كان الحساب موجودًا فسنرسل رابط إعادة التعيين."),
    "sendResetLink": ("Send reset link", "إرسال رابط إعادة التعيين"),
    "forgotSent": ("If an account exists for this email, a reset link is on its way. It expires in 1 hour.", "إذا كان هناك حساب بهذا البريد فسيصلك رابط إعادة التعيين قريبًا. تنتهي صلاحيته خلال ساعة."),
    "haveResetLink": ("I have a reset link", "لدي رابط إعادة تعيين"),
    "backToSignIn": ("Back to sign in", "العودة إلى تسجيل الدخول"),
    "resetTitle": ("Choose a new password", "اختر كلمة مرور جديدة"),
    "resetCodeLabel": ("Reset link", "رابط إعادة التعيين"),
    "resetCodeHelper": ("Paste the link from the reset email.", "الصق الرابط من رسالة إعادة التعيين."),
    "resetCodeInvalid": ("This isn't a valid reset link.", "هذا ليس رابط إعادة تعيين صالحًا."),
    "resetLinkReady": ("Reset link received.", "تم استلام رابط إعادة التعيين."),
    "newPasswordLabel": ("New password", "كلمة المرور الجديدة"),
    "resetAction": ("Update password", "تحديث كلمة المرور"),
    "resetLinkExpired": ("This reset link is invalid or has expired. Request a new one.", "رابط إعادة التعيين غير صالح أو منتهي الصلاحية. اطلب رابطًا جديدًا."),
    "resetDone": ("Your password was updated. Sign in with your new password.", "تم تحديث كلمة المرور. سجّل الدخول بكلمة المرور الجديدة."),
    "requestNewLink": ("Request a new link", "طلب رابط جديد"),
    "sessionProblemTitle": ("We couldn't confirm your session", "تعذّر التحقق من جلستك"),
    "sessionProblemOffline": ("Check your connection and try again. You're still signed in on this device.", "تحقّق من اتصالك ثم حاول مرة أخرى. ما زلت مسجّل الدخول على هذا الجهاز."),
    "sessionProblemServer": ("The service didn't respond. Try again in a moment.", "لم تستجب الخدمة. حاول مرة أخرى بعد قليل."),
    "sessionProblemStorage": ("This device's secure storage couldn't be read.", "تعذّرت قراءة التخزين الآمن على هذا الجهاز."),
    "signOutAction": ("Sign out", "تسجيل الخروج"),
    "accountTitle": ("Account", "الحساب"),
    "accountDetails": ("Account details", "تفاصيل الحساب"),
    "roleLabel": ("Role", "الدور"),
    "roleViewer": ("Member", "عضو"),
    "roleAdmin": ("Administrator", "مسؤول"),
    "roleSuperAdmin": ("Super administrator", "مسؤول أعلى"),
    "changePasswordAction": ("Change password", "تغيير كلمة المرور"),
    "signOutConfirmTitle": ("Sign out of this device?", "تسجيل الخروج من هذا الجهاز؟"),
    "signOutConfirmBody": ("Your session is removed from this device. A session already issued stays valid on the server until it expires.", "ستُزال جلستك من هذا الجهاز. تبقى الجلسة الصادرة سابقًا صالحة على الخادم حتى تنتهي صلاحيتها."),
    "cancelAction": ("Cancel", "إلغاء"),
    "designPreview": ("Design preview", "معاينة التصميم"),
    "changePasswordTitle": ("Change password", "تغيير كلمة المرور"),
    "currentPasswordLabel": ("Current password", "كلمة المرور الحالية"),
    "errorCurrentPassword": ("The current password is incorrect.", "كلمة المرور الحالية غير صحيحة."),
    "passwordChanged": ("Your password was changed.", "تم تغيير كلمة المرور."),
    "persistenceFailedNotice": ("This device couldn't store your session securely. You may need to sign in again next time.", "تعذّر على هذا الجهاز حفظ جلستك بأمان. قد تحتاج إلى تسجيل الدخول مرة أخرى لاحقًا."),
    "spacesTitle": ("Choose a space", "اختر مساحة العمل"),
    "spacesSubtitle": ("Spaces keep each team's documents and conversations separate.", "تفصل مساحات العمل مستندات ومحادثات كل فريق."),
    "spacesYours": ("Your spaces", "مساحات العمل الخاصة بك"),
    "spacesNoneTitle": ("No space yet", "لا توجد مساحة عمل بعد"),
    "spacesNoneBody": ("Ask an administrator for an invitation, or request access to a space below.", "اطلب دعوة من المسؤول، أو اطلب الانضمام إلى إحدى المساحات أدناه."),
    "spacesAvailable": ("Other spaces", "مساحات عمل أخرى"),
    "spacesAvailableEmpty": ("No other spaces are open for requests.", "لا توجد مساحات أخرى متاحة للطلب."),
    "requestAccess": ("Request access", "طلب الانضمام"),
    "accessPending": ("Request pending", "الطلب قيد المراجعة"),
    "accessRequested": ("Your request was sent to the space administrators.", "أُرسل طلبك إلى مسؤولي مساحة العمل."),
    "spaceAccessLost": ("You no longer have access to the space you used before. Choose another one.", "لم تعد لديك صلاحية الوصول إلى مساحة العمل السابقة. اختر مساحة أخرى."),
    "haveInvitation": ("Have an invitation?", "لديك دعوة؟"),
    "inviteCodeLabel": ("Invitation link", "رابط الدعوة"),
    "inviteCodeInvalid": ("This isn't a valid invitation link.", "هذا ليس رابط دعوة صالحًا."),
    "inviteTitle": ("Join a space", "الانضمام إلى مساحة عمل"),
    "inviteBody": ("Accept this invitation to join the space with the account you're signed in to.", "اقبل هذه الدعوة للانضمام إلى مساحة العمل باستخدام الحساب الذي سجّلت الدخول به."),
    "inviteAction": ("Accept invitation", "قبول الدعوة"),
    "inviteAccepted": ("You joined the space.", "انضممت إلى مساحة العمل."),
    "inviteInvalid": ("This invitation is invalid, has expired, or was sent to a different email.", "هذه الدعوة غير صالحة أو منتهية أو مرسلة إلى بريد إلكتروني آخر."),
    "notNow": ("Not now", "ليس الآن"),
    "spaceRoleAdmin": ("Space administrator", "مسؤول مساحة العمل"),
    "spaceRoleMember": ("Member", "عضو"),
    "switchSpace": ("Switch space", "تبديل مساحة العمل"),
    "currentSpace": ("Current space", "مساحة العمل الحالية"),
    "homeGreeting": ("Hello, {name}", "مرحبًا، {name}"),
    "homeSignedInAs": ("Signed in as {email}", "مسجّل الدخول باسم {email}"),
    "spaceRoleLabel": ("Your role in this space", "دورك في مساحة العمل"),
    "uploadsLabel": ("Document uploads", "رفع المستندات"),
    "uploadsAllowed": ("Allowed", "مسموح"),
    "uploadsNotAllowed": ("Not allowed", "غير مسموح"),
    "selectSpaceAction": ("Open", "فتح"),
    "continueAction": ("Continue", "متابعة"),
    "nameLabel": ("Name", "الاسم"),
}

PLACEHOLDERS = {"homeGreeting": ["name"], "homeSignedInAs": ["email"]}


def main() -> None:
    for index, locale in ((0, "en"), (1, "ar")):
        path = ROOT / f"app_{locale}.arb"
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, values in STRINGS.items():
            data[key] = values[index]
            if locale == "en" and key in PLACEHOLDERS:
                data[f"@{key}"] = {"placeholders": {p: {"type": "String"} for p in PLACEHOLDERS[key]}}
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
