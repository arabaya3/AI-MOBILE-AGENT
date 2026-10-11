import { useEffect, useState, useCallback } from "react";
import {
  IconButton,
  Badge,
  Menu,
  MenuItem,
  ListItemText,
  Typography,
  Box,
  Divider,
  Button,
  CircularProgress,
} from "@mui/material";
import {
  Notifications as NotificationsIcon,
  CheckCircle,
  Info,
  Warning,
  Error as ErrorIcon,
} from "@mui/icons-material";
import { useNavigate } from "react-router-dom";
import {
  getNotifications,
  getUnreadCount,
  markNotificationRead,
  markAllNotificationsRead,
  connectNotificationStream,
  type Notification,
} from "../api/notifications";

const NotificationBell = () => {
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const fetchNotifications = useCallback(async () => {
    try {
      const { data } = await getNotifications({ limit: 20 });
      setNotifications(data);
    } catch (error) {
      console.error("Failed to fetch notifications:", error);
    }
  }, []);

  const fetchUnreadCount = useCallback(async () => {
    try {
      const { data } = await getUnreadCount();
      setUnreadCount(data.count);
    } catch (error) {
      console.error("Failed to fetch unread count:", error);
    }
  }, []);

  useEffect(() => {
    fetchUnreadCount();
    fetchNotifications();

    // Connect to real-time notification stream
    const eventSource = connectNotificationStream(
      (notification) => {
        // Add new notification to the list
        setNotifications((prev) => [notification, ...prev]);
        setUnreadCount((prev) => prev + 1);
        
        // Optional: Show browser notification
        if ("Notification" in window && Notification.permission === "granted") {
          new Notification(notification.title, {
            body: notification.message,
            icon: "/icon.png",
          });
        }
      },
      (error) => {
        console.error("Notification stream error:", error);
      }
    );

    // Request notification permission
    if ("Notification" in window && Notification.permission === "default") {
      Notification.requestPermission();
    }

    return () => {
      if (eventSource) {
        eventSource.close();
      }
    };
  }, [fetchNotifications, fetchUnreadCount]);

  const handleOpen = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
    if (unreadCount > 0) {
      fetchNotifications();
    }
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleNotificationClick = async (notification: Notification) => {
    if (!notification.read) {
      try {
        await markNotificationRead(notification.id);
        setNotifications((prev) =>
          prev.map((n) => (n.id === notification.id ? { ...n, read: true } : n))
        );
        setUnreadCount((prev) => Math.max(0, prev - 1));
      } catch (error) {
        console.error("Failed to mark notification as read:", error);
      }
    }

    handleClose();

    if (notification.link) {
      navigate(notification.link);
    }
  };

  const handleMarkAllRead = async () => {
    setLoading(true);
    try {
      await markAllNotificationsRead();
      setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
      setUnreadCount(0);
    } catch (error) {
      console.error("Failed to mark all as read:", error);
    } finally {
      setLoading(false);
    }
  };

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case "request_approved":
        return <CheckCircle color="success" fontSize="small" />;
      case "request_declined":
        return <ErrorIcon color="error" fontSize="small" />;
      case "policy_updated":
        return <Info color="info" fontSize="small" />;
      case "quota_warning":
        return <Warning color="warning" fontSize="small" />;
      default:
        return <Info color="info" fontSize="small" />;
    }
  };

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return "Just now";
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  return (
    <>
      <IconButton color="inherit" onClick={handleOpen}>
        <Badge badgeContent={unreadCount} color="error">
          <NotificationsIcon />
        </Badge>
      </IconButton>

      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl)}
        onClose={handleClose}
        PaperProps={{
          sx: {
            width: 400,
            maxHeight: 600,
          },
        }}
      >
        <Box sx={{ p: 2, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <Typography variant="h6">الإشعارات</Typography>
          {unreadCount > 0 && (
            <Button
              size="small"
              onClick={handleMarkAllRead}
              disabled={loading}
              startIcon={loading ? <CircularProgress size={16} /> : null}
            >
              تحديد الكل كمقروءة
            </Button>
          )}
        </Box>
        <Divider />

        {notifications.length === 0 ? (
          <Box sx={{ p: 4, textAlign: "center" }}>
            <Typography color="text.secondary">لا توجد إشعارات</Typography>
          </Box>
        ) : (
          notifications.map((notification, index) => (
            <div key={notification.id}>
              <MenuItem
                onClick={() => handleNotificationClick(notification)}
                sx={{
                  backgroundColor: notification.read ? "transparent" : "action.hover",
                  "&:hover": {
                    backgroundColor: notification.read ? "action.hover" : "action.selected",
                  },
                }}
              >
                <Box sx={{ mr: 2 }}>{getNotificationIcon(notification.type)}</Box>
                <ListItemText
                  primary={
                    <Typography
                      variant="body2"
                      fontWeight={notification.read ? 400 : 600}
                      component="span"
                    >
                      {notification.title}
                    </Typography>
                  }
                  secondary={
                    <>
                      <Typography variant="body2" color="text.secondary" component="span" display="block">
                        {notification.message}
                      </Typography>
                      <Typography variant="caption" color="text.secondary" component="span" display="block">
                        {formatTimestamp(notification.created_at)}
                      </Typography>
                    </>
                  }
                />
              </MenuItem>
              {index < notifications.length - 1 && <Divider />}
            </div>
          ))
        )}
      </Menu>
    </>
  );
};

export default NotificationBell;
