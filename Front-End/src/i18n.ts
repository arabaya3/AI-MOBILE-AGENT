import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

i18n.use(initReactI18next).init({
  resources: {
    en: {
      translation: {
        "welcome": "Welcome to TEIA",
        "send_message": "Send message",
        "upload_document": "Upload document",
        "select_documents": "Select documents",
        "settings": "Settings",
        "logout": "Logout",
        "new_chat": "New Chat",
        "share": "Share",
        "regenerate": "Regenerate",
        "edit": "Edit",
        "typing": "TEIA is thinking...",
        "search_web": "Searching the web...",
        "no_messages": "Ask a question to start the conversation",
      }
    },
    ar: {
      translation: {
        "welcome": "مرحبا بك في TEIA",
        "send_message": "إرسال رسالة",
        "upload_document": "تحميل مستند",
        "select_documents": "اختر المستندات",
        "settings": "الإعدادات",
        "logout": "تسجيل الخروج",
        "new_chat": "محادثة جديدة",
        "share": "مشاركة",
        "regenerate": "إعادة توليد",
        "edit": "تعديل",
        "typing": "TEIA تفكر...",
        "search_web": "البحث في الويب...",
        "no_messages": "اطرح سؤالاً لبدء المحادثة",
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
