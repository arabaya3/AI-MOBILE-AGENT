"""One-off merge of Phase 2 (chat) strings into the ARB files."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib/l10n"

STRINGS = {
    "chatTitle": ("Conversations", "المحادثات"),
    "newConversation": ("New conversation", "محادثة جديدة"),
    "chatEmptyTitle": ("No conversations yet", "لا توجد محادثات بعد"),
    "chatEmptyBody": ("Start a conversation to ask a question in this space.", "ابدأ محادثة لطرح سؤال في مساحة العمل هذه."),
    "untitledConversation": ("Untitled conversation", "محادثة بلا عنوان"),
    "composerHint": ("Ask a question", "اكتب سؤالك"),
    "sendAction": ("Send", "إرسال"),
    "stopAction": ("Stop", "إيقاف"),
    "attachmentsUnavailable": ("Attachments and documents arrive in a later release.", "سيتوفر إرفاق الملفات والمستندات في إصدار لاحق."),
    "modelLabel": ("Model", "النموذج"),
    "noModels": ("No models are available to you in this space.", "لا تتوفر لك نماذج في مساحة العمل هذه."),
    "assistantTyping": ("Writing a reply…", "جارٍ كتابة الرد…"),
    "copyAction": ("Copy", "نسخ"),
    "copied": ("Copied to clipboard.", "تم النسخ إلى الحافظة."),
    "helpful": ("Helpful", "مفيد"),
    "notHelpful": ("Not helpful", "غير مفيد"),
    "branchAction": ("Continue in a new conversation", "المتابعة في محادثة جديدة"),
    "sourcesLabel": ("Sources", "المصادر"),
    "sourcesSessionOnly": ("Sources are shown in this view only and aren't saved with the conversation.", "تظهر المصادر في هذا العرض فقط ولا تُحفظ مع المحادثة."),
    "sourceExcerpt": ("Excerpt {index}", "مقتطف {index}"),
    "turnQuota": ("You've reached your usage limit in this space.", "لقد بلغت حد الاستخدام في مساحة العمل هذه."),
    "turnRateLimited": ("Too many requests. Wait a moment, then send again.", "طلبات كثيرة جدًا. انتظر قليلًا ثم أرسل مرة أخرى."),
    "turnPolicy": ("This model isn't allowed in this space. Choose another model.", "هذا النموذج غير مسموح في مساحة العمل هذه. اختر نموذجًا آخر."),
    "turnProvider": ("The model couldn't finish this reply. Nothing was saved for it.", "تعذّر على النموذج إكمال هذا الرد. لم يُحفظ أي رد."),
    "turnInterrupted": ("The connection ended before the reply finished. The reply wasn't saved.", "انقطع الاتصال قبل اكتمال الرد. لم يُحفظ الرد."),
    "turnStopped": ("You stopped this reply. Stopping only ends it on this device, and the partial reply isn't saved.", "أوقفت هذا الرد. الإيقاف ينهيه على هذا الجهاز فقط، ولا يُحفظ الجزء الظاهر منه."),
    "turnSessionNotFound": ("This conversation is no longer available.", "لم تعد هذه المحادثة متاحة."),
    "turnDocumentAccess": ("You don't have access to a selected document.", "ليست لديك صلاحية للوصول إلى أحد المستندات المحددة."),
    "turnProtocol": ("The reply couldn't be read.", "تعذّرت قراءة الرد."),
    "turnGeneric": ("The reply couldn't be completed.", "تعذّر إكمال الرد."),
    "turnUncertain": ("Your question may already be saved. Check the conversation before sending it again.", "ربما حُفظ سؤالك بالفعل. راجع المحادثة قبل إرساله مرة أخرى."),
    "sendAgain": ("Send again", "إرسال مرة أخرى"),
    "dismissAction": ("Dismiss", "إغلاق"),
    "storedReplyFailed": ("This reply failed and contains no answer.", "فشل هذا الرد ولا يحتوي على إجابة."),
    "jumpToLatest": ("Jump to latest", "الانتقال إلى الأحدث"),
    "moreActions": ("More", "المزيد"),
    "summaryAction": ("Summarize", "تلخيص"),
    "summaryTitle": ("Summary", "الملخص"),
    "summaryCost": ("Summaries are written by the model and count toward this space's usage.", "يكتب النموذج الملخص، ويُحتسب ضمن استخدام مساحة العمل."),
    "generateAction": ("Generate", "إنشاء"),
    "exportAction": ("Copy as Markdown", "نسخ بتنسيق Markdown"),
    "exportDone": ("Conversation copied as Markdown.", "نُسخت المحادثة بتنسيق Markdown."),
    "shareAction": ("Share link", "رابط مشاركة"),
    "shareTitle": ("Share this conversation", "مشاركة هذه المحادثة"),
    "shareExplain": (
        "Anyone with the link can read this conversation's messages up to the moment you create it, until the link expires or you revoke it. Sources and document details aren't included.",
        "يستطيع أي شخص لديه الرابط قراءة رسائل هذه المحادثة حتى لحظة إنشائه، إلى أن تنتهي صلاحية الرابط أو تلغيه. لا تُضمَّن المصادر ولا تفاصيل المستندات.",
    ),
    "createLinkAction": ("Create link", "إنشاء رابط"),
    "shareCreated": ("Link copied. It expires on {date}.", "نُسخ الرابط. تنتهي صلاحيته في {date}."),
    "activeLinks": ("Active links", "الروابط النشطة"),
    "noActiveLinks": ("No active links.", "لا توجد روابط نشطة."),
    "revokeAction": ("Revoke", "إلغاء"),
    "linkRevoked": ("Link revoked.", "أُلغي الرابط."),
    "expiresOn": ("Expires {date}", "تنتهي في {date}"),
    "openLinkTitle": ("Open external link?", "فتح رابط خارجي؟"),
    "openLinkBody": ("This opens {host} in your browser.", "سيُفتح {host} في المتصفح."),
    "openAction": ("Open", "فتح"),
    "openChat": ("Open conversations", "فتح المحادثات"),
}

PLACEHOLDERS = {
    "sourceExcerpt": {"index": "int"},
    "shareCreated": {"date": "String"},
    "expiresOn": {"date": "String"},
    "openLinkBody": {"host": "String"},
}


def main() -> None:
    for index, locale in ((0, "en"), (1, "ar")):
        path = ROOT / f"app_{locale}.arb"
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, values in STRINGS.items():
            data[key] = values[index]
            if locale == "en" and key in PLACEHOLDERS:
                data[f"@{key}"] = {"placeholders": {p: {"type": t} for p, t in PLACEHOLDERS[key].items()}}
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
