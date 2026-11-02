"""One-off merge of Phase 4 (notifications, usage, requests, conversation actions) strings into the ARB files."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib/l10n"

REMOVED: list[str] = []

STRINGS = {
    # Notifications
    "notificationsTitle": ("Notifications", "الإشعارات"),
    "notificationsUnread": (
        "{count, plural, =1{1 unread notification} other{{count} unread notifications}}",
        "{count, plural, =1{إشعار واحد غير مقروء} =2{إشعاران غير مقروءين} few{{count} إشعارات غير مقروءة} other{{count} إشعارًا غير مقروء}}",
    ),
    "markAllReadAction": ("Mark all read", "تحديد الكل كمقروء"),
    "notificationsReconnecting": (
        "Live updates are paused; reconnecting. The list refreshes once connected.",
        "التحديثات المباشرة متوقفة مؤقتًا، وجارٍ إعادة الاتصال. ستُحدَّث القائمة بعد الاتصال.",
    ),
    "notificationsEmptyTitle": ("No notifications", "لا توجد إشعارات"),
    "notificationsEmptyBody": (
        "Updates about your requests and spaces appear here.",
        "تظهر هنا التحديثات الخاصة بطلباتك ومساحات العمل.",
    ),
    "notificationTargetUnavailable": (
        "This is no longer available to you.",
        "لم يعد هذا متاحًا لك.",
    ),
    "notifApprovedTitle": ("Request approved", "تمت الموافقة على الطلب"),
    "notifApprovedBody": ("Your {type} request in {space} was approved.", "تمت الموافقة على طلب {type} في {space}."),
    "notifDeclinedTitle": ("Request declined", "رُفض الطلب"),
    "notifDeclinedBody": ("Your {type} request in {space} was declined.", "رُفض طلب {type} في {space}."),
    "notifDeclinedBodyNote": (
        "Your {type} request in {space} was declined. Note: {note}",
        "رُفض طلب {type} في {space}. ملاحظة: {note}",
    ),
    "notifPolicyTitle": ("Space settings changed", "تغيّرت إعدادات مساحة العمل"),
    "notifPolicyBody": ("The models or limits in {space} were updated.", "حُدّثت النماذج أو الحدود في {space}."),
    "notifInviteTitle": ("Invitation", "دعوة"),
    "notifInviteBody": ("You were invited to join {space}.", "تمت دعوتك للانضمام إلى {space}."),
    "notifQuotaTitle": ("Usage limit approaching", "اقتربت من حد الاستخدام"),
    "notifQuotaBody": ("You are close to a usage limit in {space}.", "أنت قريب من أحد حدود الاستخدام في {space}."),
    "requestTypeJoin": ("Join", "انضمام"),
    "requestTypeModel": ("Model access", "الوصول إلى نموذج"),
    "requestTypeTool": ("Tool access", "الوصول إلى أداة"),
    "requestTypeQuota": ("Higher limits", "رفع الحدود"),
    "requestTypeUpload": ("Document uploads", "رفع المستندات"),
    "requestTypeOther": ("Other", "أخرى"),
    # Usage
    "usageTitle": ("Usage", "الاستخدام"),
    "periodDay": ("24 hours", "24 ساعة"),
    "periodDays": (
        "{days} days",
        "{days, plural, few{{days} أيام} other{{days} يومًا}}",
    ),
    "usageWindow": (
        "From {start} to {end}, your local time. Windows roll back from now.",
        "من {start} إلى {end} بتوقيتك المحلي. تُحسب المدة رجوعًا من الآن.",
    ),
    "usageSummaryTitle": ("Summary", "الملخص"),
    "usageRequests": ("Replies requested", "الردود المطلوبة"),
    "usageUnknownRequests": (
        "{count, plural, =1{1 reply has no reported usage (for example stopped or interrupted).} other{{count} replies have no reported usage (for example stopped or interrupted).}}",
        "{count, plural, =1{ردّ واحد بلا استخدام مُبلَّغ عنه (مثل رد أُوقف أو انقطع).} =2{ردّان بلا استخدام مُبلَّغ عنه (مثل ردود أُوقفت أو انقطعت).} few{{count} ردود بلا استخدام مُبلَّغ عنه (مثل ردود أُوقفت أو انقطعت).} other{{count} ردًا بلا استخدام مُبلَّغ عنه (مثل ردود أُوقفت أو انقطعت).}}",
    ),
    "usageInputTokens": ("Input tokens", "رموز الإدخال"),
    "usageOutputTokens": ("Output tokens", "رموز الإخراج"),
    "usageTotalTokens": ("Total tokens", "إجمالي الرموز"),
    "usageCostTitle": ("Estimated cost", "التكلفة التقديرية"),
    "usageCostBasis": (
        "Estimated from list prices in US dollars; not a provider invoice.",
        "تقدير وفق الأسعار المعلنة بالدولار الأمريكي، وليست فاتورة من المزوّد.",
    ),
    "usageCostUnavailable": ("Unavailable", "غير متاحة"),
    "usageCostIncomplete": (
        "{count, plural, =1{1 reply has no usage or price data and is not included.} other{{count} replies have no usage or price data and are not included.}}",
        "{count, plural, =1{ردّ واحد بلا بيانات استخدام أو سعر وغير مشمول.} =2{ردّان بلا بيانات استخدام أو سعر وغير مشمولين.} few{{count} ردود بلا بيانات استخدام أو سعر وغير مشمولة.} other{{count} ردًا بلا بيانات استخدام أو سعر وغير مشمول.}}",
    ),
    "usageCostNone": (
        "No reply in this period has usage and price data, so no cost can be shown. This does not mean it was free.",
        "لا يوجد في هذه المدة رد له بيانات استخدام وسعر، لذلك لا يمكن عرض تكلفة. هذا لا يعني أنه كان مجانيًا.",
    ),
    "usageLimitsTitle": ("Limits", "الحدود"),
    "usageLimitsExplain": (
        "Limits count back from now. Conversation limits count conversations started.",
        "تُحسب الحدود رجوعًا من الآن، وتُحسب حدود المحادثات بعدد المحادثات التي بدأتها.",
    ),
    "usageByModel": ("By model", "حسب النموذج"),
    "usageModelLine": ("{requests} replies · {tokens} tokens", "{requests} ردود · {tokens} رمز"),
    "usageTools": ("Tools", "الأدوات"),
    "usageToolCalls": ("{count} calls", "{count} استدعاءات"),
    "limitTokens": ("Tokens", "الرموز"),
    "limitConversations": ("Conversations", "المحادثات"),
    "limitToolRequests": ("Tool calls", "استدعاءات الأدوات"),
    "limitLast24h": ("last 24 hours", "آخر 24 ساعة"),
    "limitLast30d": ("last 30 days", "آخر 30 يومًا"),
    "limitNone": ("{used} used · no limit", "المستخدم {used} · بلا حد"),
    "limitValue": ("{used} of {limit} used · {remaining} left", "المستخدم {used} من {limit} · المتبقي {remaining}"),
    "limitReserved": (
        "Includes {tokens} counted for replies whose usage was never reported.",
        "يشمل {tokens} محسوبة لردود لم يُبلَّغ عن استخدامها.",
    ),
    "invoiceAction": ("Share invoice (PDF)", "مشاركة الفاتورة (PDF)"),
    "invoiceExplain": (
        "The PDF is created by the server for the selected period and kept in this app's private storage until you sign out or switch space.",
        "يُنشئ الخادم ملف PDF للمدة المختارة، ويُحفظ في التخزين الخاص بالتطبيق حتى تسجيل الخروج أو تبديل مساحة العمل.",
    ),
    "invoiceShareSubject": ("TEIA usage invoice", "فاتورة استخدام TEIA"),
    "shareUnavailable": ("Sharing isn't available on this device.", "المشاركة غير متاحة على هذا الجهاز."),
    # Requests
    "requestsTitle": ("Requests", "الطلبات"),
    "requestsExplain": (
        "Requests you sent to space administrators. Approvals update your access automatically.",
        "الطلبات التي أرسلتها إلى مسؤولي مساحات العمل. تُحدَّث صلاحياتك تلقائيًا عند الموافقة.",
    ),
    "requestsEmptyTitle": ("No requests", "لا توجد طلبات"),
    "requestsEmptyBody": ("Ask for model access, higher limits or upload rights.", "اطلب الوصول إلى نموذج أو رفع الحدود أو صلاحية الرفع."),
    "accountRequestsTitle": ("Account requests", "طلبات الحساب"),
    "requestPending": ("Pending", "قيد المراجعة"),
    "requestApproved": ("Approved", "مقبول"),
    "requestDeclined": ("Declined", "مرفوض"),
    "requestSentOn": ("Sent {date}", "أُرسل في {date}"),
    "reviewerNote": ("Reviewer's note", "ملاحظة المراجِع"),
    "newRequestAction": ("New request", "طلب جديد"),
    "newRequestTitle": ("New request", "طلب جديد"),
    "requestUploadExplain": (
        "Ask to upload documents in this space.",
        "اطلب صلاحية رفع المستندات في مساحة العمل هذه.",
    ),
    "requestReason": ("What do you need?", "ما الذي تحتاجه؟"),
    "requestReasonOptional": ("Reason (optional)", "السبب (اختياري)"),
    "requestChooseModel": ("Choose a model.", "اختر نموذجًا."),
    "requestQuotaInvalid": ("Enter at least one whole number above zero.", "أدخل رقمًا صحيحًا أكبر من صفر في حقل واحد على الأقل."),
    "requestReasonRequired": ("Describe what you need.", "صِف ما تحتاجه."),
    "requestSent": ("Request sent.", "أُرسل الطلب."),
    "requestAlreadyPending": ("You already have this request pending.", "لديك هذا الطلب بالفعل قيد المراجعة."),
    "requestUncertain": (
        "We couldn't confirm the request. The list was refreshed; check it before sending again.",
        "تعذّر تأكيد الطلب. حُدّثت القائمة؛ راجعها قبل الإرسال مرة أخرى.",
    ),
    "sendRequestAction": ("Send request", "إرسال الطلب"),
    "quotaDailyTokens": ("Tokens per 24 hours", "الرموز لكل 24 ساعة"),
    "quotaMonthlyTokens": ("Tokens per 30 days", "الرموز لكل 30 يومًا"),
    "quotaDailyConversations": ("Conversations per 24 hours", "المحادثات لكل 24 ساعة"),
    "quotaMonthlyConversations": ("Conversations per 30 days", "المحادثات لكل 30 يومًا"),
    # Conversation actions
    "renameAction": ("Rename", "إعادة التسمية"),
    "renameTitle": ("Rename conversation", "إعادة تسمية المحادثة"),
    "conversationNameLabel": ("Name", "الاسم"),
    "saveAction": ("Save", "حفظ"),
    "exportFileAction": ("Share as file", "مشاركة كملف"),
    "deleteConversationAction": ("Delete", "حذف"),
    "deleteConversationTitle": ("Delete this conversation?", "حذف هذه المحادثة؟"),
    "deleteConversationBody": (
        "Its messages are deleted and its share links stop working. Usage records are kept. Copies you already shared or exported can't be recalled.",
        "تُحذف رسائلها وتتوقف روابط مشاركتها عن العمل، وتبقى سجلات الاستخدام. لا يمكن استرجاع النسخ التي شاركتها أو صدّرتها سابقًا.",
    ),
    "deleteAction": ("Delete", "حذف"),
    "conversationDeleted": ("Conversation deleted.", "حُذفت المحادثة."),
    # Account
    "replyLanguageTitle": ("Reply language", "لغة الردود"),
    "replyLanguageExplain": (
        "The language the assistant answers in. Automatic follows your question.",
        "اللغة التي يجيب بها المساعد. التلقائي يتبع لغة سؤالك.",
    ),
    "replyLanguageAuto": ("Automatic", "تلقائي"),
}

PLACEHOLDERS = {
    "notificationsUnread": {"count": "int"},
    "notifApprovedBody": {"type": "String", "space": "String"},
    "notifDeclinedBody": {"type": "String", "space": "String"},
    "notifDeclinedBodyNote": {"type": "String", "space": "String", "note": "String"},
    "notifPolicyBody": {"space": "String"},
    "notifInviteBody": {"space": "String"},
    "notifQuotaBody": {"space": "String"},
    "periodDays": {"days": "int"},
    "usageWindow": {"start": "String", "end": "String"},
    "usageUnknownRequests": {"count": "int"},
    "usageCostIncomplete": {"count": "int"},
    "usageModelLine": {"requests": "String", "tokens": "String"},
    "usageToolCalls": {"count": "String"},
    "limitNone": {"used": "String"},
    "limitValue": {"used": "String", "limit": "String", "remaining": "String"},
    "limitReserved": {"tokens": "String"},
    "requestSentOn": {"date": "String"},
}


def main() -> None:
    for index, locale in ((0, "en"), (1, "ar")):
        path = ROOT / f"app_{locale}.arb"
        data = json.loads(path.read_text(encoding="utf-8"))
        for key in REMOVED:
            data.pop(key, None)
            data.pop(f"@{key}", None)
        for key, values in STRINGS.items():
            data[key] = values[index]
            if locale == "en" and key in PLACEHOLDERS:
                data[f"@{key}"] = {"placeholders": {p: {"type": t} for p, t in PLACEHOLDERS[key].items()}}
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
