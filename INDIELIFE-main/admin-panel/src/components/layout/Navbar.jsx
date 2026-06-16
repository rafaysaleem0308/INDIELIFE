import { useState, useEffect } from "react";
import {
  AppBar,
  Toolbar,
  Typography,
  IconButton,
  Box,
  Avatar,
  Menu,
  MenuItem,
  Tooltip,
  ListItemIcon,
  Divider,
  Badge,
  Chip,
} from "@mui/material";
import { Bell, LogOut, RefreshCw, Clock } from "lucide-react";
import { useAuth } from "../../context/AuthContext";
import { useNavigate } from "react-router-dom";
import { DRAWER_WIDTH } from "./Sidebar";
import api from "../../utils/api";

const Navbar = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [anchorEl, setAnchorEl] = useState(null);
  const [time, setTime] = useState(new Date());
  const [pendingCount, setPendingCount] = useState(0);

  // Live clock
  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  // Fetch pending providers count
  useEffect(() => {
    const fetch = () => {
      api
        .get("/admin/providers?status=pending")
        .then((r) => setPendingCount((r.data.providers || []).length))
        .catch((err) => {
          console.error(
            `Navbar Sync Error [${err.response?.status}]:`,
            err.message,
          );
        });
    };
    fetch();
    const interval = setInterval(fetch, 30000);
    return () => clearInterval(interval);
  }, []);

  const handleRefresh = () => {
    // If you want to refresh all dashboard data, you might want to use a global state or event bus.
    // For now, let's at least re-fetch the local notification count.
    api
      .get("/admin/providers?status=pending")
      .then((r) => setPendingCount((r.data.providers || []).length))
      .catch((err) =>
        console.error(
          `Manual Refresh Failed [${err.response?.status}]:`,
          err.message,
        ),
      );
  };

  const formatTime = (d) =>
    d.toLocaleTimeString("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: true,
    });
  const formatDate = (d) =>
    d.toLocaleDateString("en-US", {
      weekday: "short",
      day: "numeric",
      month: "short",
    });

  return (
    <AppBar
      position="fixed"
      elevation={0}
      sx={{
        width: `calc(100% - ${DRAWER_WIDTH}px)`,
        ml: `${DRAWER_WIDTH}px`,
        bgcolor: "white",
        color: "text.primary",
        borderBottom: "1px solid #979797",
      }}
    >
      <Toolbar sx={{ justifyContent: "space-between" }}>
        {/* Left: Page context */}
        <Box sx={{ display: "flex", alignItems: "center", gap: 2 }}>
          <Box
            sx={{
              display: "flex",
              alignItems: "center",
              gap: 1,
              bgcolor: "#f8f9fa",
              borderRadius: 2,
              px: 2,
              py: 0.8,
            }}
          >
            <Clock size={30} color="#888" />
            <Typography
              variant="caption"
              sx={{ fontWeight: 800 }}
              color="text.secondary"
            >
              {formatTime(time)}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              |
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {formatDate(time)}
            </Typography>
          </Box>
        </Box>

        <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
          {pendingCount > 0 && (
            <Chip
              size="small"
              label={`${pendingCount} Pending Approvals`}
              color="warning"
              variant="outlined"
              onClick={() => navigate("/providers")}
              sx={{ cursor: "pointer", fontWeight: 600, fontSize: "0.75rem" }}
            />
          )}

          <Tooltip title="Notifications">
            <IconButton onClick={() => navigate("/notifications")}>
              <Badge badgeContent={pendingCount} color="error" max={99}>
                <Bell size={20} />
              </Badge>
            </IconButton>
          </Tooltip>

          <Tooltip title="Refresh Data">
            <IconButton onClick={handleRefresh}>
              <RefreshCw size={18} />
            </IconButton>
          </Tooltip>

          <Tooltip title="Account">
            <IconButton onClick={(e) => setAnchorEl(e.currentTarget)}>
              <Avatar
                sx={{
                  width: 34,
                  height: 34,
                  bgcolor: "#FF6B2B",
                  fontSize: "0.85rem",
                  fontWeight: 700,
                }}
              >
                {user?.firstName?.charAt(0) || "A"}
              </Avatar>
            </IconButton>
          </Tooltip>

          <Menu
            anchorEl={anchorEl}
            open={Boolean(anchorEl)}
            onClose={() => setAnchorEl(null)}
            transformOrigin={{ horizontal: "right", vertical: "top" }}
            anchorOrigin={{ horizontal: "right", vertical: "bottom" }}
            slotProps={{ paper: { sx: { width: 220, mt: 1.5 } } }}
          >
            <Box sx={{ px: 2, py: 1.5 }}>
              <Typography variant="subtitle2" fontWeight={700}>
                {user?.firstName} {user?.lastName}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {user?.email || "Super Admin"}
              </Typography>
            </Box>
            <Divider />
            <MenuItem
              onClick={() => {
                navigate("/settings");
                setAnchorEl(null);
              }}
            >
              <ListItemIcon>
                <RefreshCw size={16} />
              </ListItemIcon>
              Platform Settings
            </MenuItem>
            <MenuItem onClick={logout} sx={{ color: "error.main", mt: 0.5 }}>
              <ListItemIcon>
                <LogOut size={16} color="#d32f2f" />
              </ListItemIcon>
              Logout
            </MenuItem>
          </Menu>
        </Box>
      </Toolbar>
    </AppBar>
  );
};

export default Navbar;
