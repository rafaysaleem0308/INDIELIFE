import { useState, useEffect, useCallback } from "react";
import {
  Box,
  Typography,
  Card,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Avatar,
  Chip,
  IconButton,
  Button,
  Tabs,
  Tab,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Grid,
  Divider,
  Tooltip,
  Alert,
  CircularProgress,
  Snackbar,
} from "@mui/material";
import {
  Eye,
  Trash2,
  Home,
  MapPin,
} from "lucide-react";
import api from "../utils/api";

const statusColors = {
  Active: "success",
  Inactive: "error",
};

const statusMap = ["Active", "Inactive"];

const Housing = () => {
  const [properties, setProperties] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tabValue, setTabValue] = useState(0);
  const [selectedProperty, setSelectedProperty] = useState(null);
  const [detailOpen, setDetailOpen] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [stats, setStats] = useState(null);
  const [snackbar, setSnackbar] = useState({
    open: false,
    message: "",
    severity: "success",
  });

  const fetchProperties = useCallback(async () => {
    try {
      setLoading(true);
      const status = statusMap[tabValue];
      const response = await api.get("/admin/services", {
        params: {
          serviceType: "Hostel/Flat Accommodation",
          status: status,
        },
      });
      setProperties(response.data.services || []);
    } catch (error) {
      console.error("Failed to fetch housing services:", error);
      setProperties([]);
    } finally {
      setLoading(false);
    }
  }, [tabValue]);

  const fetchStats = useCallback(async () => {
    try {
      const response = await api.get("/admin/services", {
        params: { serviceType: "Hostel/Flat Accommodation" },
      });
      const services = response.data.services || [];
      const active = services.filter((s) => s.status === "Active").length;
      const inactive = services.filter((s) => s.status === "Inactive").length;
      setStats({
        total: services.length,
        active,
        inactive,
        totalBookings: 0,
      });
    } catch (e) {
      console.error("Failed to fetch housing stats:", e);
    }
  }, []);

  useEffect(() => {
    fetchProperties();
    fetchStats();
  }, [fetchProperties, fetchStats]);

  const handleDelete = async (id) => {
    if (
      !window.confirm(
        "Are you sure you want to permanently delete this service?",
      )
    )
      return;
    try {
      setActionLoading(true);
      await api.delete(`/admin/services/${id}`);
      setSnackbar({
        open: true,
        message: "Service deleted",
        severity: "success",
      });
      setDetailOpen(false);
      fetchProperties();
      fetchStats();
    } catch {
      setSnackbar({ open: true, message: "Delete failed", severity: "error" });
    } finally {
      setActionLoading(false);
    }
  };

  const viewProperty = async (id) => {
    try {
      const response = await api.get(`/admin/services/${id}`);
      setSelectedProperty(response.data.service);
      setDetailOpen(true);
    } catch {
      setSnackbar({
        open: true,
        message: "Failed to load property details",
        severity: "error",
      });
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" fontWeight="bold" gutterBottom>
        <Home style={{ verticalAlign: "middle", marginRight: 8 }} />
        Housing Management
      </Typography>

      {/* Stats Cards */}
      {stats && (
        <Grid container spacing={2} sx={{ mb: 3 }}>
          {[
            { label: "Total Services", value: stats.total, color: "#42A5F5" },
            { label: "Active", value: stats.active, color: "#66BB6A" },
            { label: "Inactive", value: stats.inactive, color: "#EF5350" },
          ].map((s, i) => (
            <Grid item xs={6} md={2} key={i}>
              <Card
                sx={{
                  p: 2,
                  textAlign: "center",
                  borderTop: `3px solid ${s.color}`,
                }}
              >
                <Typography variant="h5" fontWeight="bold" color={s.color}>
                  {s.value}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {s.label}
                </Typography>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}

      {/* Tabs */}
      <Card sx={{ mb: 3 }}>
        <Tabs
          value={tabValue}
          onChange={(_, v) => setTabValue(v)}
          variant="fullWidth"
          indicatorColor="primary"
          sx={{ borderBottom: 1, borderColor: "divider" }}
        >
          <Tab label={`Active (${stats?.active || 0})`} />
          <Tab label={`Inactive (${stats?.inactive || 0})`} />
        </Tabs>

        {loading ? (
          <Box display="flex" justifyContent="center" p={4}>
            <CircularProgress />
          </Box>
        ) : properties.length === 0 ? (
          <Box p={4} textAlign="center">
            <Typography color="text.secondary">No properties found</Typography>
          </Box>
        ) : (
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Service Name</TableCell>
                  <TableCell>Provider</TableCell>
                  <TableCell>Type</TableCell>
                  <TableCell>City</TableCell>
                  <TableCell>Price</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {properties.map((p) => {
                  return (
                    <TableRow key={p._id} hover>
                      <TableCell>
                        <Box display="flex" alignItems="center" gap={1.5}>
                          <Avatar
                            variant="rounded"
                            src={p.imageUrl || ""}
                            sx={{ width: 48, height: 48, bgcolor: "#42A5F5" }}
                          >
                            <Home size={20} />
                          </Avatar>
                          <Box>
                            <Typography
                              fontWeight={600}
                              fontSize={14}
                              noWrap
                              sx={{ maxWidth: 200 }}
                            >
                              {p.serviceName}
                            </Typography>
                            <Typography
                              variant="caption"
                              color="text.secondary"
                            >
                              {p.accommodationType}
                            </Typography>
                          </Box>
                        </Box>
                      </TableCell>
                      <TableCell>
                        <Typography fontSize={13}>
                          {p.providerName || "N/A"}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {p.providerCity || "N/A"}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={p.accommodationType || "Room"}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>{p.providerCity}</TableCell>
                      <TableCell>
                        <Typography fontWeight={600} color="#42A5F5">
                          Rs {(p.price || 0).toLocaleString()}/{p.unit}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={p.status?.replace("_", " ")}
                          color={statusColors[p.status] || "default"}
                          size="small"
                          sx={{ textTransform: "capitalize" }}
                        />
                      </TableCell>
                      <TableCell align="right">
                        <Tooltip title="View Details">
                          <IconButton
                            onClick={() => viewProperty(p._id)}
                            size="small"
                          >
                            <Eye size={18} />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Delete">
                          <IconButton
                            onClick={() => handleDelete(p._id)}
                            size="small"
                            color="error"
                          >
                            <Trash2 size={18} />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </Card>

      {/* Service Detail Dialog */}
      <Dialog
        open={detailOpen}
        onClose={() => setDetailOpen(false)}
        maxWidth="md"
        fullWidth
      >
        {selectedProperty && (
          <>
            <DialogTitle sx={{ fontWeight: 700 }}>
              {selectedProperty.serviceName}
            </DialogTitle>
            <DialogContent dividers>
              <Grid container spacing={3}>
                {/* Image */}
                <Grid item xs={12}>
                  <Box
                    component="img"
                    src={selectedProperty.imageUrl || ""}
                    alt={selectedProperty.serviceName}
                    sx={{
                      width: "100%",
                      height: 280,
                      objectFit: "cover",
                      borderRadius: 2,
                    }}
                  />
                </Grid>

                {/* Info Grid */}
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">
                    Accommodation Type
                  </Typography>
                  <Typography fontWeight={600}>
                    {selectedProperty.accommodationType}
                  </Typography>
                </Grid>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">
                    City
                  </Typography>
                  <Typography fontWeight={600}>
                    <MapPin size={14} style={{ verticalAlign: "middle" }} />{" "}
                    {selectedProperty.providerCity}
                  </Typography>
                </Grid>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">
                    Price
                  </Typography>
                  <Typography fontWeight={700} color="#42A5F5" fontSize={18}>
                    Rs {(selectedProperty.price || 0).toLocaleString()}/
                    {selectedProperty.unit}
                  </Typography>
                </Grid>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">
                    Rating
                  </Typography>
                  <Typography fontWeight={600}>
                    {selectedProperty.rating || "N/A"} ⭐ (
                    {selectedProperty.totalReviews || 0} reviews)
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Divider sx={{ my: 1 }} />
                  <Typography variant="caption" color="text.secondary">
                    Description
                  </Typography>
                  <Typography fontSize={14}>
                    {selectedProperty.description || "No description"}
                  </Typography>
                </Grid>

                {/* Owner Info */}
                <Grid item xs={12}>
                  <Divider sx={{ my: 1 }} />
                  <Typography fontWeight={600} gutterBottom>
                    Provider Information
                  </Typography>
                  <Box>
                    <Typography fontWeight={600}>
                      {selectedProperty.providerName || "N/A"}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      {selectedProperty.providerEmail} ·{" "}
                      {selectedProperty.providerPhone}
                    </Typography>
                  </Box>
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions sx={{ p: 2, gap: 1 }}>
              <Button
                variant="outlined"
                color="error"
                startIcon={<Trash2 size={16} />}
                onClick={() => handleDelete(selectedProperty._id)}
                disabled={actionLoading}
              >
                Delete
              </Button>
              <Button onClick={() => setDetailOpen(false)}>Close</Button>
            </DialogActions>
          </>
        )}
      </Dialog>

      {/* Snackbar */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={4000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
      >
        <Alert
          severity={snackbar.severity}
          onClose={() => setSnackbar({ ...snackbar, open: false })}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default Housing;
