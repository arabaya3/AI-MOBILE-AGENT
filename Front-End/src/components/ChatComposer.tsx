import SendRoundedIcon from "@mui/icons-material/SendRounded";
import AutoFixHighIcon from "@mui/icons-material/AutoFixHigh";
import LanguageRoundedIcon from "@mui/icons-material/LanguageRounded";
import { Box, IconButton, Stack, TextField, Typography, CircularProgress, Tooltip, useMediaQuery, useTheme } from "@mui/material";
import { useState } from "react";
import { isAxiosError } from "axios";
import { sendChatMessage } from "../api/chat";

interface ChatComposerProps {
  onSend: (message: string, webSearchEnabled: boolean) => Promise<void> | void;
  disabled?: boolean;
  availableModels?: string[];
}

export const ChatComposer = ({ onSend, disabled, availableModels = [] }: ChatComposerProps) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));
  const [message, setMessage] = useState("");
  const [enhancing, setEnhancing] = useState(false);
  const [enhanceError, setEnhanceError] = useState<string | null>(null);
  const [webSearchEnabled, setWebSearchEnabled] = useState(false);

  const handleSend = async () => {
    if (!message.trim()) return;
    await onSend(message.trim(), webSearchEnabled);
    setMessage("");
  };

  const handleEnhance = async () => {
    if (!message.trim() || enhancing) return;

    setEnhancing(true);
    setEnhanceError(null);
    try {
      // Prefer GPT-5 Nano for prompt enhancement.
      const preferOrder = ["gpt-5-nano"];
      let modelToUse: string | undefined;

      if (availableModels.length > 0) {
        modelToUse = preferOrder.find((m) => availableModels.includes(m));
        if (!modelToUse) {
          modelToUse = availableModels[0];
        }
      }

      const enhancePrompt = `أنت خبير في هندسة الاستفسارات. حسّن السؤال القانوني التالي ليكون أكثر وضوحاً وتفصيلاً وفعالية. حافظ على المقصد الأصلي لكن اجعله أكثر تنظيماً وتحديداً. أعد فقط السؤال المحسّن دون أي شرح إضافي.\n\nالسؤال الأصلي: ${message}`;

      const { data } = await sendChatMessage({
        message: enhancePrompt,
        ...(modelToUse ? { model: modelToUse } : {}),
      });

      if (data.reply?.trim()) {
        setMessage(data.reply.trim());
      }
    } catch (error) {
      console.error("Failed to enhance prompt:", error);
      if (isAxiosError(error)) {
        const status = error.response?.status;
        const detail = (error.response?.data as any)?.detail;
        if (status === 429) {
          setEnhanceError("تجاوزت حد الطلبات. تنتظر لحظة ثم حاول مجدداً.");
        } else if (detail) {
          setEnhanceError(String(detail));
        } else if (status) {
          setEnhanceError(`Request failed (${status}).`);
        } else {
          setEnhanceError("خطأ في الشبكة. حاول مجدداً.");
        }
      } else {
        setEnhanceError("تعذّر تحسين السؤال. حاول مجدداً.");
      }
    } finally {
      setEnhancing(false);
    }
  };

  const handleKeyDown = async (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      await handleSend();
    }
  };

  return (
    <Stack spacing={1}
      sx={{
        width: "100%",
        maxWidth: 900,
        mx: "auto",
      }}
    >
      <Box sx={{ display: "flex", alignItems: "flex-end", gap: 1 }}>
        <TextField
          placeholder={isMobile ? "اكتب سؤالك القانوني..." : "اشرح قضيتك أو اطرح سؤالك القانوني هنا... مثال: ما هي حقوقي كمستأجر؟"}
          variant="outlined"
          multiline
          fullWidth
          value={message}
          onChange={(event) => {
            setMessage(event.target.value);
            if (enhanceError) setEnhanceError(null);
          }}
          onKeyDown={handleKeyDown}
          InputProps={{
            sx: {
              bgcolor: theme.palette.mode === "dark" ? "grey.900" : "grey.50",
              borderRadius: 3,
              "& .MuiOutlinedInput-notchedOutline": { 
                borderColor: "divider",
              },
              "&:hover .MuiOutlinedInput-notchedOutline": {
                borderColor: "primary.main",
              },
            },
          }}
          disabled={disabled || enhancing}
          minRows={1}
          maxRows={6}
          error={!!enhanceError}
          helperText={enhanceError}
        />
        <Tooltip title={webSearchEnabled ? "إيقاف البحث على الإنترنت" : "تفعيل البحث على الإنترنت"}>
          <span>
            <IconButton
              onClick={() => setWebSearchEnabled((prev) => !prev)}
              disabled={disabled || enhancing}
              sx={{
                width: 44,
                height: 44,
                bgcolor: webSearchEnabled ? "primary.main" : "background.default",
                color: webSearchEnabled ? "white" : "text.secondary",
                border: "1px solid",
                borderColor: webSearchEnabled ? "primary.main" : "divider",
                "&:hover": {
                  bgcolor: webSearchEnabled ? "primary.dark" : "action.hover",
                  borderColor: "primary.main",
                },
              }}
            >
              <LanguageRoundedIcon />
            </IconButton>
          </span>
        </Tooltip>
        <Tooltip title={!message.trim() ? "اكتب سؤالك لتحسينه" : "تحسين صياغة السؤال بالذكاء الاصطناعي"}>
          <span>
            <IconButton
              color="secondary"
              onClick={handleEnhance}
              disabled={disabled || !message.trim() || enhancing}
              sx={{
                width: 44,
                height: 44,
                bgcolor: "background.default",
                border: "1px solid",
                borderColor: "divider",
                "&:hover": { 
                  bgcolor: "action.hover", 
                  borderColor: "primary.main",
                  color: "primary.main",
                },
              }}
            >
              {enhancing ? (
                <CircularProgress size={20} color="inherit" />
              ) : (
                <AutoFixHighIcon />
              )}
            </IconButton>
          </span>
        </Tooltip>
        <IconButton
          color="primary"
          onClick={handleSend}
          disabled={disabled || !message.trim() || enhancing}
          sx={{
            width: 44,
            height: 44,
            bgcolor: "primary.main",
            color: "white",
            "&:hover": { 
              bgcolor: "primary.dark",
            },
            "&.Mui-disabled": {
              bgcolor: "action.disabledBackground",
            },
          }}
        >
          <SendRoundedIcon />
        </IconButton>
      </Box>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ px: 1 }}>
        <Typography variant="caption" color="text.secondary">
          {isMobile ? "اضغط Enter للإرسال" : "⏎ للإرسال • Shift+⏎ لسطر جديد"}
          {webSearchEnabled ? " • البحث على الإنترنت مفعّل" : ""}
        </Typography>
        <Typography variant="caption" color="text.secondary">
          {message.length} chars
        </Typography>
      </Stack>
    </Stack>
  );
};

export default ChatComposer;
