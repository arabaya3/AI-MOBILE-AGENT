import AutoAwesomeRoundedIcon from "@mui/icons-material/AutoAwesomeRounded";
import PersonRoundedIcon from "@mui/icons-material/PersonRounded";
import RefreshIcon from "@mui/icons-material/Refresh";
import EditIcon from "@mui/icons-material/Edit";
import ShareIcon from "@mui/icons-material/Share";
import CallSplitIcon from "@mui/icons-material/CallSplit";
import ThumbUpAltOutlinedIcon from "@mui/icons-material/ThumbUpAltOutlined";
import ThumbDownAltOutlinedIcon from "@mui/icons-material/ThumbDownAltOutlined";
import { Avatar, Box, Chip, Divider, IconButton, Link, Popover, Stack, Tooltip, Typography, useTheme, alpha } from "@mui/material";
import { useEffect, useRef, useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { vscDarkPlus } from "react-syntax-highlighter/dist/esm/styles/prism";

import type { ConversationMessage, VectorSearchMatch } from "../api/chat";

interface ChatMessageListProps {
  messages: ConversationMessage[];
  sources: VectorSearchMatch[];
  onRegenerate?: (messageId: string) => void;
  onEdit?: (messageId: string) => void;
  onShare?: () => void;
  onBranch?: (messageId: string) => void;
  onReact?: (messageId: string, reaction: "up" | "down") => void;
  isTyping?: boolean;
  suggestedPrompts?: string[];
  onPromptClick?: (prompt: string) => void;
}

export const ChatMessageList = ({ 
  messages, 
  sources, 
  onRegenerate,
  onEdit,
  onShare,
  onBranch,
  onReact,
  isTyping,
  suggestedPrompts,
  onPromptClick,
}: ChatMessageListProps) => { 
  const bottomRef = useRef<HTMLDivElement>(null);
  const theme = useTheme();
  const [sourcePopover, setSourcePopover] = useState<{ anchor: HTMLElement; source: VectorSearchMatch } | null>(null);

  useEffect(() => {
    if (messages.length > 0 || isTyping) {
      bottomRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, isTyping]);

  const roleMeta = {
      user: {
        icon: <PersonRoundedIcon sx={{ fontSize: 20 }} />,
        // More "chat bubble" than "developer card".
        bg: theme.palette.mode === "dark"
          ? alpha(theme.palette.primary.main, 0.18)
          : alpha(theme.palette.primary.light, 0.35),
        color: theme.palette.primary.main,
        label: "You",
      },
      assistant: {
        icon: <AutoAwesomeRoundedIcon sx={{ fontSize: 20 }} />,
        bg: theme.palette.mode === "dark" 
            ? "rgba(30,41,59,0.5)" 
            : "rgba(255,255,255,0.8)",
        color: theme.palette.secondary.main,
        label: "TEIA",
      },
    } as const;

    return (
      <Box
        sx={{
          // Key: Use flex:1 to fill remaining height, enable scrolling
          flex: 1,
          minHeight: 0,
          overflowY: "auto",
          overscrollBehaviorY: "contain",
          scrollBehavior: "smooth",
          WebkitOverflowScrolling: "touch",
        }}
      >
        <Stack spacing={2.5} sx={{ maxWidth: 900, mx: "auto", width: "100%", p: { xs: 2, sm: 3 } }}>
          {messages.map((message, index) => {
            const isUser = message.role === "user";
            // Hide empty assistant messages
            if (message.role === "assistant" && (!message.content || !message.content.trim()) && !isTyping) return null;
            
            // Skip rendering if it's the last message, is assistant, is empty and we're showing typing indicator
            if (message.role === "assistant" && (!message.content || !message.content.trim()) && isTyping && index === messages.length - 1) return null;

            return (
                  <Stack 
                    key={message.id} 
                    direction={isUser ? "row-reverse" : "row"} 
                    alignItems="flex-start" 
                    spacing={1.5} 
                    sx={{ width: "100%" }}
                  >
                <Avatar
                  sx={{
                    bgcolor: "transparent",
                    color: roleMeta[message.role].color,
                    width: 32,
                    height: 32,
                    border: "1px solid",
                    borderColor: alpha(roleMeta[message.role].color, 0.2),
                    background: alpha(roleMeta[message.role].color, 0.05),
                  }}
                >
                  {roleMeta[message.role].icon}
                </Avatar>

                <Stack spacing={0.5} sx={{ flex: 1, minWidth: 0, maxWidth: isUser ? "80%" : "100%", alignItems: isUser ? "flex-end" : "flex-start" }}>
                  <Stack direction="row" alignItems="center" spacing={0.5}>
                     <Typography variant="caption" fontWeight={600} color={isUser ? "primary" : "text.primary"}>
                        {roleMeta[message.role].label}
                     </Typography>
                     <Typography variant="caption" color="text.secondary">
                        {message.created_at ? new Date(message.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : ""}
                     </Typography>
                  </Stack>
                  <Box
                    sx={{
                      width: "fit-content",
                      maxWidth: "100%",
                      minWidth: 0,
                      // User messages: indigo bubble; Assistant: subtle grey
                      bgcolor: isUser ? "#e0e7ff" : roleMeta[message.role].bg,
                      color: isUser ? "#312e81" : "text.primary",
                      borderRadius: isUser ? 2 : "4px 16px 16px 16px",
                      px: 2,
                      py: 1.5,
                      boxShadow: theme.palette.mode === "dark" ? "0 2px 8px rgba(0,0,0,0.15)" : "0 1px 4px rgba(0,0,0,0.08)",
                      border: isUser ? "none" : "1px solid",
                      borderColor: isUser ? undefined : "divider",
                      overflowWrap: "anywhere",
                      wordBreak: "break-word",
                    }}
                  >
            {message.role === "assistant" ? (
              <Box sx={{
                '& p': { margin: 0 },
                '& p + p': { marginTop: 1 },
                '& ul, & ol': { marginTop: 1, marginBottom: 1, paddingLeft: 3 },
                    '& code': { fontFamily: 'monospace', background: 'rgba(99,102,241,0.12)', padding: '0 6px', borderRadius: 4, wordBreak: 'break-word' },
                    '& pre': { overflowX: 'auto', padding: 1.5, borderRadius: 8, border: '1px solid', borderColor: 'divider', maxWidth: '100%' },
                    '& a': { wordBreak: 'break-word', overflowWrap: 'anywhere' },
              }}>
                <ReactMarkdown
                  remarkPlugins={[remarkGfm]}
                  components={{
                    a: ({ href, children }) => (
                      <Link href={href} target="_blank" rel="noreferrer">
                        {children}
                      </Link>
                    ),
                    h1: ({ children }) => <Typography variant="h6" fontWeight={700}>{children}</Typography>,
                    h2: ({ children }) => <Typography variant="subtitle1" fontWeight={700}>{children}</Typography>,
                    h3: ({ children }) => <Typography variant="subtitle2" fontWeight={700}>{children}</Typography>,
                    p: ({ children }) => <Typography variant="body1">{children}</Typography>,
                    li: ({ children }) => <Typography component="li" variant="body1">{children}</Typography>,
                    code: ({ inline, className, children, ...props }: any) => {
                      const match = /language-(\w+)/.exec(className || '');
                      return !inline && match ? (
                        <SyntaxHighlighter
                          style={vscDarkPlus}
                          language={match[1]}
                          PreTag="div"
                          {...props}
                        >
                          {String(children).replace(/\n$/, '')}
                        </SyntaxHighlighter>
                      ) : (
                        <code className={className} {...props}>
                          {children}
                        </code>
                      );
                    },
                  }}
                >
                  {message.content}
                </ReactMarkdown>
              </Box>
            ) : (
              <Typography variant="body1" whiteSpace="pre-line" sx={{ fontSize: "1rem", lineHeight: 1.5 }}>
                {message.content}
              </Typography>
            )}
                  </Box>

                  {/* Action buttons */}
                  <Stack direction="row" spacing={0.5} sx={{ opacity: 0.7, "&:hover": { opacity: 1 } }}>
            {onRegenerate && message.role === "assistant" && index === messages.length - 1 && (
              <Stack direction="row" spacing={0.5}>
                <Tooltip title="Regenerate">
                  <IconButton size="small" onClick={() => onRegenerate(message.id)}>
                    <RefreshIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
                {onBranch && messages.length > 0 ? (
                  <Tooltip title="Branch from here">
                    <IconButton size="small" onClick={() => onBranch(message.id)}>
                      <CallSplitIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                ) : null}
                {onShare && (
                  <Tooltip title="Share">
                    <IconButton size="small" onClick={onShare}>
                      <ShareIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                )}
              </Stack>
            )}
            {message.role === "user" && onEdit && (
              <Tooltip title="Edit">
                <IconButton size="small" onClick={() => onEdit(message.id)}>
                  <EditIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            )}

            {message.role === "assistant" && onReact ? (
              <Stack direction="row" spacing={0.5}>
                <Tooltip title="Helpful">
                  <IconButton size="small" onClick={() => onReact(message.id, "up")}>
                    <ThumbUpAltOutlinedIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
                <Tooltip title="Not helpful">
                  <IconButton size="small" onClick={() => onReact(message.id, "down")}>
                    <ThumbDownAltOutlinedIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
              </Stack>
            ) : null}
                  </Stack>
            {message.role === "assistant" && (message.sources?.length || (index === messages.length - 1 && sources.length > 0)) ? (
            <Stack spacing={1}>
              <Typography variant="caption" color="text.secondary">
                Sources:
              </Typography>
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                {(message.sources || sources).map((source, idx) => (
                  idx < 4 ? (
                    <Tooltip key={idx} title={source.filename || `Source ${idx + 1}`}>
                      <Chip
                        label={source.filename ? source.filename.replace(/\.[^.]+$/, "") : `Source ${idx + 1}`}
                        size="small"
                        variant="outlined"
                        clickable
                        color="primary"
                        onClick={(e) => setSourcePopover({ anchor: e.currentTarget, source })}
                        sx={{ maxWidth: 160, cursor: "pointer" }}
                      />
                    </Tooltip>
                  ) : null
                ))}
                {(message.sources || sources).length > 4 && (
                  <Tooltip title="Click any chip to see source details">
                    <Chip
                      label={`+${(message.sources || sources).length - 4} more`}
                      size="small"
                      variant="outlined"
                      onClick={(e) => setSourcePopover({ anchor: e.currentTarget, source: (message.sources || sources)[4] })}
                      clickable
                      sx={{ cursor: "pointer" }}
                    />
                  </Tooltip>
                )}
              </Stack>
            </Stack>
          ) : null}

          {/* Source detail popover */}
          <Popover
            open={Boolean(sourcePopover)}
            anchorEl={sourcePopover?.anchor}
            onClose={() => setSourcePopover(null)}
            anchorOrigin={{ vertical: "top", horizontal: "left" }}
            transformOrigin={{ vertical: "bottom", horizontal: "left" }}
            slotProps={{ paper: { sx: { maxWidth: 380, p: 0 } } }}
          >
            {sourcePopover && (
              <Box sx={{ p: 2 }}>
                <Stack direction="row" alignItems="center" justifyContent="space-between" mb={1}>
                  <Typography variant="subtitle2" fontWeight={700} noWrap sx={{ maxWidth: 260 }}>
                    {sourcePopover.source.filename || "Unknown document"}
                  </Typography>
                  {sourcePopover.source.score >= 0 && (
                    <Typography variant="caption" color="text.secondary" sx={{ ml: 1, flexShrink: 0 }}>
                      Score: {(sourcePopover.source.score * 100).toFixed(0)}%
                    </Typography>
                  )}
                </Stack>
                <Divider sx={{ mb: 1 }} />
                <Typography variant="body2" color="text.secondary" sx={{ fontStyle: "italic", mb: 1 }}>
                  {sourcePopover.source.file_type?.toUpperCase()}{sourcePopover.source.chunk_index !== undefined ? ` · chunk ${sourcePopover.source.chunk_index + 1}` : ""}
                </Typography>
                <Typography
                  variant="body2"
                  sx={{
                    display: "-webkit-box",
                    WebkitLineClamp: 8,
                    WebkitBoxOrient: "vertical",
                    overflow: "hidden",
                    whiteSpace: "pre-wrap",
                    wordBreak: "break-word",
                    lineHeight: 1.6,
                  }}
                >
                  {sourcePopover.source.text || "No preview available."}
                </Typography>
              </Box>
            )}
          </Popover>
                </Stack>
              </Stack>
            );
          })}

          {isTyping && (
             <Stack direction="row" spacing={2} alignItems="flex-start">
             <Avatar
               sx={{
                 bgcolor: "transparent",
                 color: roleMeta.assistant.color,
                 width: 36,
                 height: 36,
                 border: "1px solid",
                 borderColor: alpha(roleMeta.assistant.color, 0.2),
                 background: alpha(roleMeta.assistant.color, 0.05),
               }}
             >
               {roleMeta.assistant.icon}
             </Avatar>
             <Box
                 sx={{
                   bgcolor: roleMeta.assistant.bg,
                   borderRadius: "4px 20px 20px 20px",
                   p: 2,
                   display: "flex",
                   alignItems: "center",
                   gap: 1
                 }}
               >
                 <Box className="typing-dot" sx={{ width: 6, height: 6, borderRadius: "50%", bgcolor: "text.secondary", animation: "bounce 1.4s infinite ease-in-out both", animationDelay: "-0.32s" }} />
                 <Box className="typing-dot" sx={{ width: 6, height: 6, borderRadius: "50%", bgcolor: "text.secondary", animation: "bounce 1.4s infinite ease-in-out both", animationDelay: "-0.16s" }} />
                 <Box className="typing-dot" sx={{ width: 6, height: 6, borderRadius: "50%", bgcolor: "text.secondary", animation: "bounce 1.4s infinite ease-in-out both" }} />
               </Box>
           </Stack>
          )}

          {!messages.length && suggestedPrompts && (
            <Stack spacing={4} alignItems="center" justifyContent="center" sx={{ py: 8 }}>
              <Box 
                sx={{ 
                  p: 3, 
                  borderRadius: "50%", 
                  bgcolor: alpha(theme.palette.primary.main, 0.05),
                  border: "1px solid",
                  borderColor: alpha(theme.palette.primary.main, 0.1),
                }}
              >
                <AutoAwesomeRoundedIcon sx={{ fontSize: 48, color: "primary.main" }} />
              </Box>
              <Typography variant="h6" color="text.secondary" fontWeight={500}>
                How can I help you today?
              </Typography>
              <Box 
                sx={{ 
                  display: "grid", 
                  gridTemplateColumns: { xs: "1fr", sm: "repeat(2, 1fr)" }, 
                  gap: 2, 
                  width: "100%", 
                  maxWidth: 720 
                }}
              >
                {suggestedPrompts.map((prompt) => (
                  <Box
                    key={prompt}
                    sx={{
                      p: 2.5,
                      borderRadius: 2,
                      border: "1px solid",
                      borderColor: "divider",
                      cursor: "pointer",
                      bgcolor: "background.paper",
                      transition: "all 0.2s",
                      "&:hover": {
                        borderColor: "primary.main",
                        transform: "translateY(-2px)",
                        boxShadow: "0 4px 12px rgba(0,0,0,0.05)",
                      },
                    }}
                    onClick={() => onPromptClick?.(prompt)}
                  >
                     <Typography variant="body2" fontWeight={500}>{prompt}</Typography>
                  </Box>
                ))}
              </Box>
            </Stack>
          )}

          {!messages.length && !suggestedPrompts && (
            <Stack spacing={1} alignItems="center" justifyContent="center" sx={{ py: 8, color: "text.secondary" }}>
              <AutoAwesomeRoundedIcon />
              <Typography variant="body2">Ask a question to start the conversation.</Typography>
            </Stack>
          )}
          <div ref={bottomRef} />
        </Stack>
        <style>{`
          @keyframes bounce {
            0%, 80%, 100% { transform: scale(0); }
            40% { transform: scale(1); }
          }
        `}</style>
      </Box>
    );
};

export default ChatMessageList;
