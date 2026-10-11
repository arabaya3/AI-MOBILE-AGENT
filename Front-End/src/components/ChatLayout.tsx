import { Box, Stack } from "@mui/material";
import type { ReactNode } from "react";

export interface ChatLayoutProps {
  header: ReactNode;
  sidebar?: ReactNode;
  children: ReactNode;
}

/**
 * Mobile-first layout wrapper.
 *
 * Key behaviors:
 * - Uses 100dvh to avoid iOS address-bar issues.
 * - Keeps the app from feeling "frozen" by enabling vertical scrolling on <main>.
 * - Prevents whole-page rubber-banding by applying overscrollBehavior to the scroll container.
 */
export const ChatLayout = ({ header, sidebar, children }: ChatLayoutProps) => {
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
      {header}

      <Box
        component="main"
        sx={{
          flex: 1,
          minHeight: 0,
          px: { xs: 1.5, md: 2.5 },
          py: { xs: 1.5, md: 2.5 },
          overflowY: "auto",
          overflowX: "hidden",
          overscrollBehaviorY: "none",
          WebkitOverflowScrolling: "touch",
        }}
      >
        <Stack
          direction={{ xs: "column", lg: "row" }}
          spacing={3}
          alignItems="stretch"
          sx={{ minHeight: "100%" }}
        >
          {sidebar ? <Box sx={{ flexShrink: 0, minHeight: 0 }}>{sidebar}</Box> : null}
          <Box sx={{ flex: 1, minWidth: 0, minHeight: 0, display: "flex", flexDirection: "column" }}>{children}</Box>
        </Stack>
      </Box>
    </Box>
  );
};

export default ChatLayout;
