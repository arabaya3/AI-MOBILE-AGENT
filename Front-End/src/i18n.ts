import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

i18n.use(initReactI18next).init({
  resources: {
    en: {
      translation: {
        "welcome": "Welcome to LawTech - Palestinian Legal Assistant",
        "send_message": "Send message",
        "upload_document": "Upload legal document",
        "select_documents": "Select case documents",
        "settings": "Settings",
        "logout": "Logout",
        "new_chat": "New Legal Consultation",
        "share": "Share",
        "regenerate": "Regenerate",
        "edit": "Edit",
        "typing": "LawTech is analyzing your case...",
        "search_web": "Searching legal resources...",
        "no_messages": "Describe your legal situation to get started",
      }
    },
    ar: {
      translation: {
        "welcome": "مرحبا بك في LawTech - المستشار القانوني الفلسطيني",
        "send_message": "إرسال",
        "upload_document": "رفع مستند قانوني",
        "select_documents": "اختر ملفات القضية",
        "settings": "الإعدادات",
        "logout": "تسجيل الخروج",
        "new_chat": "استشارة قانونية جديدة",
        "share": "مشاركة",
        "regenerate": "إعادة توليد",
        "edit": "تعديل",
        "typing": "LawTech يحلل قضيتك...",
        "search_web": "البحث في المصادر القانونية...",
        "no_messages": "اشرح وضعك القانوني للحصول على استشارة",
      }
    }
  },
  lng: "en",
  fallbackLng: "en",
  interpolation: {
    escapeValue: false
  }
});

export default i18n;
