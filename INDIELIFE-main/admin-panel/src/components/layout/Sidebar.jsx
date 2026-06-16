import { useState, useEffect } from "react";
import { NavLink, useLocation } from "react-router-dom";
import {
  Box,
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  Divider,
  Badge,
} from "@mui/material";
import {
  LayoutDashboard,
  Users,
  Store,
  CalendarCheck,
  MessageSquare,
  CreditCard,
  Settings,
  Bell,
  Home,
  ShoppingBag,
} from "lucide-react";
import api from "../../utils/api";

const DRAWER_WIDTH = 260;

const Sidebar = () => {
  const location = useLocation();
  const [pendingCount, setPendingCount] = useState(0);

  useEffect(() => {
    api
      .get("/admin/providers?status=pending")
      .then((r) => {
        const providers = r.data.providers || [];
        setPendingCount(providers.length);
      })
      .catch((err) => {
        // Detailed error logging to help identify if it's a 404 or Auth issue
        console.error(
          `Sidebar Error [${err.response?.status}]:`,
          err.response?.data?.message || err.message,
        );
      });
  }, []);

  const menuItems = [
    {
      text: "Dashboard",
      icon: <LayoutDashboard size={20} />,
      path: "/dashboard",
    },
    {
      text: "Providers",
      icon: <Store size={20} />,
      path: "/providers",
      badge: pendingCount || null,
    },
    { text: "Users", icon: <Users size={20} />, path: "/users" },
    { text: "Services", icon: <ShoppingBag size={20} />, path: "/services" },
    { text: "Bookings", icon: <CalendarCheck size={20} />, path: "/bookings" },
    { text: "Chats", icon: <MessageSquare size={20} />, path: "/chats" },
    { text: "Payments", icon: <CreditCard size={20} />, path: "/payments" },
    { text: "Housing", icon: <Home size={20} />, path: "/housing" },
    { text: "Notifications", icon: <Bell size={20} />, path: "/notifications" },
    { text: "Settings", icon: <Settings size={20} />, path: "/settings" },
  ];

  return (
    <Drawer
      variant="permanent"
      sx={{
        width: DRAWER_WIDTH,
        flexShrink: 0,
        "& .MuiDrawer-paper": {
          width: DRAWER_WIDTH,
          boxSizing: "border-box",
          bgcolor: "#0F172A",
          px: 1.5,
          py: 3,
          borderRight: "none",
        },
      }}
    >
      <Box sx={{ mb: 4, px: 2 }}>
        <Typography
          variant="h5"
          sx={{ fontWeight: 900, letterSpacing: -0.5, color: "#FF6B2B" }}
        >
          INDIE
          <Box component="span" sx={{ color: "white" }}>
            LIFE
          </Box>
        </Typography>
        <Typography
          variant="caption"
          sx={{ color: "rgba(255,255,255,0.4)", fontWeight: 700 }}
        >
          Super Admin Portal
        </Typography>
      </Box>

      <Divider sx={{ borderColor: "rgba(255,255,255,0.08)", mb: 2 }} />

      <List sx={{ pt: 0 }}>
        {menuItems.map((item) => {
          const isActive = location.pathname === item.path;
          return (
            <ListItem key={item.text} disablePadding sx={{ mb: 0.5 }}>
              <ListItemButton
                component={NavLink}
                to={item.path}
                sx={{
                  borderRadius: 2,
                  bgcolor: isActive ? "rgba(255,107,43,0.15)" : "transparent",
                  color: isActive ? "#FF6B2B" : "rgba(255,255,255,0.6)",
                  "&:hover": {
                    bgcolor: isActive
                      ? "rgba(255,107,43,0.2)"
                      : "rgba(255,255,255,0.06)",
                    color: isActive ? "#FF6B2B" : "white",
                  },
                  borderLeft: isActive
                    ? "3px solid #FF6B2B"
                    : "3px solid transparent",
                }}
              >
                <ListItemIcon sx={{ color: "inherit", minWidth: 40 }}>
                  {item.badge ? (
                    <Badge badgeContent={item.badge} color="error" max={99}>
                      {item.icon}
                    </Badge>
                  ) : (
                    item.icon
                  )}
                </ListItemIcon>
                <ListItemText
                  primary={item.text}
                  primaryTypographyProps={{
                    fontWeight: isActive ? 700 : 500,
                    fontSize: "1.0rem",
                  }}
                />
              </ListItemButton>
            </ListItem>
          );
        })}
      </List>

      <Box
        sx={{ mt: "auto", p: 2, borderTop: "1px solid rgba(255,255,255,0.07)" }}
      >
        <Typography variant="caption" sx={{ color: "rgba(255,255,255,0.3)" }}>
          IndieLife Admin v2.0
        </Typography>
      </Box>
    </Drawer>
  );
};

export default Sidebar;
export { DRAWER_WIDTH };
