"""One-off merge of Phase 3 (documents and citations) strings into the ARB files."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib/l10n"

REMOVED = ["sourcesSessionOnly", "attachmentsUnavailable"]

STRINGS = {
    "openDocuments": ("Documents", "المستندات"),
    "documentsTitle": ("Documents", "المستندات"),
    "documentsChatExplain": (
        "Chat answers search your ready documents in this space. Choose documents in a conversation to search only those.",
        "تبحث إجابات المحادثة في مستنداتك الجاهزة في مساحة العمل هذه. اختر مستندات داخل المحادثة لحصر البحث فيها.",
    ),
    "searchDocumentsHint": ("Search documents", "ابحث في المستندات"),
    "filterAll": ("All", "الكل"),
    "filterInProgress": ("In progress", "قيد المعالجة"),
    "docStateReady": ("Ready", "جاهز"),
    "docStateFailed": ("Failed", "تعذّرت المعالجة"),
    "docStateProcessing": ("Processing…", "جارٍ المعالجة…"),
    "docStateIndexing": ("Preparing for search…", "جارٍ التجهيز للبحث…"),
    "documentHidden": ("Hidden from members", "مخفي عن الأعضاء"),
    "documentsEmptyTitle": ("No documents yet", "لا توجد مستندات بعد"),
    "documentsEmptyUploader": (
        "Upload PDF, Word, Excel, PowerPoint, CSV or text files up to 25 MB.",
        "ارفع ملفات PDF أو Word أو Excel أو PowerPoint أو CSV أو ملفات نصية حتى 25 ميغابايت.",
    ),
    "documentsEmptyReader": (
        "Documents shared with you in this space appear here.",
        "تظهر هنا المستندات التي تمت مشاركتها معك في مساحة العمل هذه.",
    ),
    "noMatchingDocuments": ("No documents match.", "لا توجد مستندات مطابقة."),
    "uploadAction": ("Upload", "رفع"),
    "sizeMegabytes": ("{value} MB", "{value} ميغابايت"),
    "sizeKilobytes": ("{value} KB", "{value} كيلوبايت"),
    "uploadSending": ("Uploading {sent} of {total}", "جارٍ الرفع: {sent} من {total}"),
    "uploadProcessing": (
        "Uploaded. The server is reading and indexing the file; this can take a few minutes.",
        "اكتمل الرفع. يقرأ الخادم الملف ويفهرسه، وقد يستغرق ذلك بضع دقائق.",
    ),
    "uploadChecking": (
        "The connection failed, so it's unclear whether the file arrived. Checking with the server before anything is sent again.",
        "تعذّر الاتصال، ولم يتضح إن كان الملف قد وصل. جارٍ التحقق مع الخادم قبل إرسال أي شيء مرة أخرى.",
    ),
    "uploadReady": ("Ready to use in chat.", "جاهز للاستخدام في المحادثة."),
    "uploadReceived": ("Received by the server.", "استلمه الخادم."),
    "uploadCancelled": (
        "Stopped on this device. If the file had already arrived, the server keeps processing it and it will appear in the list.",
        "أُوقف على هذا الجهاز. إن كان الملف قد وصل بالفعل فسيواصل الخادم معالجته وسيظهر في القائمة.",
    ),
    "uploadNotReceived": (
        "The upload didn't reach the server. You can upload the file again.",
        "لم يصل الملف إلى الخادم. يمكنك رفعه مرة أخرى.",
    ),
    "cancelUploadAction": ("Cancel upload", "إلغاء الرفع"),
    "stopWaitingAction": ("Stop waiting", "إيقاف الانتظار"),
    "checkAgainAction": ("Check again", "تحقق مرة أخرى"),
    "viewDetailsAction": ("Details", "التفاصيل"),
    "doneAction": ("Done", "تم"),
    "docErrorEncrypted": (
        "This file is password-protected or uses an old Office format. Remove the password or save it as a new file, then upload it again.",
        "هذا الملف محمي بكلمة مرور أو بتنسيق Office قديم. أزل كلمة المرور أو احفظه كملف جديد ثم ارفعه مرة أخرى.",
    ),
    "docErrorCorrupt": ("The file is damaged or isn't what its name says.", "الملف تالف أو لا يطابق نوعه المذكور في اسمه."),
    "docErrorNoText": (
        "No readable text was found. Scanned documents may need text recognition before upload.",
        "لم يُعثر على نص قابل للقراءة. قد تحتاج المستندات الممسوحة ضوئيًا إلى التعرّف على النص قبل رفعها.",
    ),
    "docErrorTooComplex": ("The file is too large or complex to process.", "الملف كبير أو معقّد جدًا ولا يمكن معالجته."),
    "docErrorUnsupported": (
        "This file type isn't supported. Use PDF, Word, Excel, PowerPoint, CSV, or UTF-8 text.",
        "نوع الملف غير مدعوم. استخدم PDF أو Word أو Excel أو PowerPoint أو CSV أو نصًا بترميز UTF-8.",
    ),
    "docErrorTooLarge": ("Files must be 25 MB or smaller.", "يجب ألا يتجاوز حجم الملف 25 ميغابايت."),
    "docErrorEmpty": ("The file is empty.", "الملف فارغ."),
    "docErrorTimeout": ("Processing took too long and was stopped.", "استغرقت المعالجة وقتًا طويلًا فأُوقفت."),
    "docErrorInterrupted": ("Processing was interrupted on the server.", "انقطعت المعالجة على الخادم."),
    "docErrorStorage": (
        "The file couldn't be stored. Upload it again.",
        "تعذّر تخزين الملف. ارفعه مرة أخرى.",
    ),
    "docErrorGeneric": ("The document couldn't be processed.", "تعذّرت معالجة المستند."),
    "errorUnsupportedFile": ("This file type isn't supported.", "نوع الملف غير مدعوم."),
    "documentDetailsTitle": ("Document", "المستند"),
    "documentUnavailableTitle": ("Document unavailable", "المستند غير متاح"),
    "documentUnavailableBody": (
        "It was removed, hidden, or your access changed.",
        "ربما حُذف أو أُخفي، أو تغيّرت صلاحيتك.",
    ),
    "docProcessingExplain": (
        "The server is reading and indexing this document. It can be used in chat once it is ready.",
        "يقرأ الخادم هذا المستند ويفهرسه. يمكن استخدامه في المحادثة عندما يصبح جاهزًا.",
    ),
    "retryProcessingAction": ("Try processing again", "إعادة محاولة المعالجة"),
    "documentInfoTitle": ("Details", "التفاصيل"),
    "fileTypeLabel": ("Type", "النوع"),
    "fileSizeLabel": ("Size", "الحجم"),
    "uploadedLabel": ("Uploaded", "تاريخ الرفع"),
    "sectionsLabel": ("Indexed sections", "الأقسام المفهرسة"),
    "useInChatAction": ("Use in chat", "استخدامه في المحادثة"),
    "selectedForChat": ("Selected for chat", "محدد للمحادثة"),
    "openDocumentAction": ("Open document", "فتح المستند"),
    "openFileFailed": ("No app on this device could open the file.", "لا يوجد تطبيق على هذا الجهاز يمكنه فتح الملف."),
    "localCopyExplain": (
        "Opening downloads a copy into this app's private storage. It is deleted when you sign out or switch space. Copies you share to other apps can't be recalled.",
        "يؤدي الفتح إلى تنزيل نسخة في التخزين الخاص بهذا التطبيق، وتُحذف عند تسجيل الخروج أو تبديل مساحة العمل. أما النسخ التي تشاركها مع تطبيقات أخرى فلا يمكن استرجاعها.",
    ),
    "chooseDocumentsAction": ("Choose documents", "اختيار المستندات"),
    "chooseDocumentsTitle": ("Documents for this conversation", "مستندات هذه المحادثة"),
    "chooseDocumentsExplain": (
        "With nothing selected, answers search all your ready documents in this space. Select documents to search only those.",
        "إذا لم تحدد شيئًا، تبحث الإجابات في كل مستنداتك الجاهزة في مساحة العمل هذه. حدّد مستندات لحصر البحث فيها.",
    ),
    "scopeAllDocuments": ("Searching all your ready documents", "البحث في كل مستنداتك الجاهزة"),
    "scopeSelectedDocuments": (
        "{count, plural, =1{Searching 1 selected document} other{Searching {count} selected documents}}",
        "{count, plural, =1{البحث في مستند واحد محدد} =2{البحث في مستندين محددين} few{البحث في {count} مستندات محددة} other{البحث في {count} مستندًا محددًا}}",
    ),
    "documentsNotReadyHidden": (
        "{count, plural, =1{1 document is still processing and can't be selected yet.} other{{count} documents are still processing and can't be selected yet.}}",
        "{count, plural, =1{مستند واحد ما زال قيد المعالجة ولا يمكن تحديده بعد.} =2{مستندان ما زالا قيد المعالجة ولا يمكن تحديدهما بعد.} few{{count} مستندات ما زالت قيد المعالجة ولا يمكن تحديدها بعد.} other{{count} مستندًا ما زال قيد المعالجة ولا يمكن تحديده بعد.}}",
    ),
    "noReadyDocuments": ("No ready documents in this space yet.", "لا توجد مستندات جاهزة في مساحة العمل هذه بعد."),
    "clearSelection": ("Clear", "مسح"),
    "removeFromSelection": ("Remove from selection", "إزالة من التحديد"),
    "selectionPruned": (
        "Removed from your selection because it's no longer available: {names}. Now: {scope}.",
        "أُزيل من تحديدك لأنه لم يعد متاحًا: {names}. الآن: {scope}.",
    ),
    "listSeparator": (", ", "، "),
    "reviewDocumentsAction": ("Review documents", "مراجعة المستندات"),
    "turnDocumentNotReady": (
        "A selected document isn't ready yet. Nothing was searched instead.",
        "أحد المستندات المحددة ليس جاهزًا بعد، ولم يُجرَ بحث بديل.",
    ),
    "sourceUnavailable": ("Source unavailable", "المصدر غير متاح"),
    "sourceUnavailableBody": (
        "You no longer have access to this source, so its excerpt isn't shown. The answer text you already received stays in the conversation.",
        "لم تعد لديك صلاحية الوصول إلى هذا المصدر، لذلك لا يظهر مقتطفه. يبقى نص الإجابة الذي تلقيته في المحادثة.",
    ),
    "sourceSavedNote": (
        "This excerpt was saved with the answer. Access is checked again every time you open the conversation.",
        "حُفظ هذا المقتطف مع الإجابة، ويُعاد التحقق من الصلاحية في كل مرة تفتح فيها المحادثة.",
    ),
    "pageNumber": ("Page {page}", "صفحة {page}"),
    "imageNotLoaded": ("Image not loaded", "لم تُحمَّل الصورة"),
    "openLinkFailed": ("The link couldn't be opened.", "تعذّر فتح الرابط."),
}

PLACEHOLDERS = {
    "sizeMegabytes": {"value": "String"},
    "sizeKilobytes": {"value": "String"},
    "uploadSending": {"sent": "String", "total": "String"},
    "scopeSelectedDocuments": {"count": "int"},
    "documentsNotReadyHidden": {"count": "int"},
    "selectionPruned": {"names": "String", "scope": "String"},
    "pageNumber": {"page": "int"},
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
