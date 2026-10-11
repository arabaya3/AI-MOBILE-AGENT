import AddRoundedIcon from "@mui/icons-material/AddRounded";
import DescriptionRoundedIcon from "@mui/icons-material/DescriptionRounded";
import HistoryRoundedIcon from "@mui/icons-material/HistoryRounded";
import MenuRoundedIcon from "@mui/icons-material/MenuRounded";
import {
  Badge,
  BottomNavigation,
  BottomNavigationAction,
  Paper,
} from "@mui/material";

export interface MobileBottomBarProps {
  /** Currently active tab key */
  activeTab?: "chat" | "sessions" | "docs" | "menu";
  onNewChat: () => void;
  onOpenSessions: () => void;
  onOpenDocuments: () => void;
  onOpenMenu: () => void;
  /** Badge count on the documents tab */
  selectedDocsCount?: number;
  /** Badge count on the sessions tab */
  sessionsCount?: number;
}

/**
 * Fixed bottom navigation bar for small screens.
 * Provides quick access to core actions without scrolling.
 */
export const MobileBottomBar = ({
  activeTab = "chat",
  onNewChat,
  onOpenSessions,
  onOpenDocuments,
  onOpenMenu,
  selectedDocsCount = 0,
  sessionsCount = 0,
}: MobileBottomBarProps) => {
  const tabIndex = { chat: 0, sessions: 1, docs: 2, menu: 3 }[activeTab];

  return (
    <Paper
      elevation={3}
      sx={{
        position: "fixed",
        bottom: 0,
        left: 0,
        right: 0,
        zIndex: (theme) => theme.zIndex.appBar,
        display: { xs: "block", lg: "none" },
        borderTop: "1px solid",
        borderColor: "divider",
        // Safe-area inset for iOS notch devices
        pb: "env(safe-area-inset-bottom, 0px)",
      }}
    >
      <BottomNavigation
        value={tabIndex}
        showLabels
        sx={{
          bgcolor: "background.paper",
          "& .MuiBottomNavigationAction-root": {
            minWidth: 64,
            py: 1,
            "&.Mui-selected": {
              color: "primary.main",
            },
          },
        }}
      >
        <BottomNavigationAction
          label="New"
          icon={<AddRoundedIcon />}
          onClick={onNewChat}
        />
        <BottomNavigationAction
          label="Sessions"
          icon={
            <Badge badgeContent={sessionsCount} color="primary" max={99} invisible={!sessionsCount}>
              <HistoryRoundedIcon />
            </Badge>
          }
          onClick={onOpenSessions}
        />
        <BottomNavigationAction
          label="Docs"
          icon={
            <Badge badgeContent={selectedDocsCount} color="secondary" max={99} invisible={!selectedDocsCount}>
              <DescriptionRoundedIcon />
            </Badge>
          }
          onClick={onOpenDocuments}
        />
        <BottomNavigationAction
          label="Menu"
          icon={<MenuRoundedIcon />}
          onClick={onOpenMenu}
        />
      </BottomNavigation>
    </Paper>
  );
};

export default MobileBottomBar;
