import SendRoundedIcon from "@mui/icons-material/SendRounded";
import AutoFixHighIcon from "@mui/icons-material/AutoFixHigh";
import { Box, IconButton, Stack, TextField, Typography, CircularProgress, Tooltip, useMediaQuery, useTheme } from "@mui/material";
import { useState } from "react";
import { isAxiosError } from "axios";
import { sendChatMessage } from "../api/chat";

interface ChatComposerProps {
  onSend: (message: string) => Promise<void> | void;
  disabled?: boolean;
  availableModels?: string[];
}

export const ChatComposer = ({ onSend, disabled, availableModels = [] }: ChatComposerProps) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));
  const [message, setMessage] = useState("");
  const [enhancing, setEnhancing] = useState(false);
  const [enhanceError, setEnhanceError] = useState<string | null>(null);

  const handleSend = async () => {
    if (!message.trim()) return;
    await onSend(message.trim());
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

      const enhancePrompt = `You are a prompt engineering expert. Enhance the following user prompt to be more clear, detailed, and effective for an AI assistant. Keep the core intent but make it more structured and specific. Return ONLY the enhanced prompt without any explanations or meta-commentary.\n\nOriginal prompt: ${message}`;

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
          setEnhanceError("Rate limit reached. Please wait a moment and try again.");
        } else if (detail) {
          setEnhanceError(String(detail));
        } else if (status) {
          setEnhanceError(`Request failed (${status}).`);
        } else {
          setEnhanceError("Network error. Please try again.");
        }
      } else {
        setEnhanceError("Failed to enhance prompt. Please try again or check your credits.");
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
          placeholder={isMobile ? "Message..." : "Ask about a policy, run analysis, or explore your documents..."}
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
        <Tooltip title={!message.trim() ? "Type a prompt to enhance" : "Enhance prompt with AI"}>
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
          {isMobile ? "Enter to send" : "⏎ to send • Shift+⏎ for newline"}
        </Typography>
        <Typography variant="caption" color="text.secondary">
          {message.length} chars
        </Typography>
      </Stack>
    </Stack>
  );
};

export default ChatComposer;
