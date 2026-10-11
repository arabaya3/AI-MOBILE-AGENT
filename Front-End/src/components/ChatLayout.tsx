import { Box } from "@mui/material";
import type { ReactNode } from "react";

export interface ChatLayoutProps {
  /** Sticky header bar */
  header: ReactNode;
  /** Optional left-side sidebar (desktop docs/sessions panel) */
  sidebar?: ReactNode;
  /** Main content area (chat messages + composer) */
  children: ReactNode;
  /** Optional mobile bottom bar (shown only on small screens) */
  bottomBar?: ReactNode;
}

/**
 * Mobile-first layout wrapper for the chat experience.
 *
 * Key behaviors:
 * - Uses 100dvh to avoid iOS address-bar issues.
 * - Prevents whole-page rubber-banding with overflow hidden on root.
 * - Sidebar collapses below lg breakpoint.
 * - Bottom bar rendered inside the flex column, above composer on mobile.
 */
export const ChatLayout = ({ header, sidebar, children, bottomBar }: ChatLayoutProps) => {
  return (
    <Box
      sx={{
        height: "100dvh",
        minHeight: "100dvh",
        bgcolor: "background.default",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      {/* Sticky header */}
      {header}

      {/* Main body — flex row on desktop, column on mobile */}
      <Box
        component="main"
        role="main"
        sx={{
          flex: 1,
          minHeight: 0,
          display: "flex",
          overflow: "hidden",
        }}
      >
        {/* Desktop sidebar */}
        {sidebar && (
          <Box
            sx={{
              display: { xs: "none", lg: "flex" },
              flexDirection: "column",
              flexShrink: 0,
              minHeight: 0,
            }}
          >
            {sidebar}
          </Box>
        )}

        {/* Chat area */}
        <Box
          sx={{
            flex: 1,
            minWidth: 0,
            minHeight: 0,
            display: "flex",
            flexDirection: "column",
            overflow: "hidden",
          }}
        >
          {children}
        </Box>
      </Box>

      {/* Mobile bottom bar */}
      {bottomBar && (
        <Box sx={{ display: { xs: "block", lg: "none" }, flexShrink: 0 }}>
          {bottomBar}
        </Box>
      )}
    </Box>
  );
};

export default ChatLayout;
