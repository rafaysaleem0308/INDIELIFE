import { Box, Toolbar } from "@mui/material";
import Navbar from "./Navbar";
import Sidebar, { DRAWER_WIDTH } from "./Sidebar";

const MainLayout = ({ children }) => {
  return (
    <Box
      sx={{
        display: "flex",
        minHeight: "100vh",
        bgcolor: "background.default",
      }}
    >
      <Navbar />
      <Sidebar />
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          width: { sm: `calc(100% - ${DRAWER_WIDTH}px)` },
        }}
      >
        <Toolbar /> {/* Spacer for Navbar */}
        {children}
      </Box>
    </Box>
  );
};

export default MainLayout;
