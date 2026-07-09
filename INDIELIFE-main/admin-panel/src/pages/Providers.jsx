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
  TextField,
  InputAdornment,
} from "@mui/material";
import {
  Eye,
  CheckCircle,
  XCircle,
  ShieldAlert,
  Phone,
  Mail,
  MapPin,
  Briefcase,
  Star,
  Trash2,
  Search,
} from "lucide-react";
import api from "../utils/api";

const statusMap = ["pending", "approved", "suspended", "rejected"];

const Providers = () => {
  const [providers, setProviders] = useState([]);
  const [filteredProviders, setFilteredProviders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tabValue, setTabValue] = useState(1);
  const [search, setSearch] = useState("");
  const [selectedProvider, setSelectedProvider] = useState(null);
  const [detailOpen, setDetailOpen] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [snackbar, setSnackbar] = useState({
    open: false,
    message: "",
    severity: "success",
  });

  const fetchProviders = useCallback(async () => {
    try {
      setLoading(true);
      const status = statusMap[tabValue];
      const response = await api.get(`/admin/providers?status=${status}`);
      setProviders(response.data.providers || []);
      setFilteredProviders(response.data.providers || []);
    } catch (error) {
      console.error("Failed to fetch providers:", error);
      setProviders([]);
      setFilteredProviders([]);
    } finally {
      setLoading(false);
    }
  }, [tabValue]);

  useEffect(() => {
    fetchProviders();
  }, [fetchProviders]);

  useEffect(() => {
    if (!search.trim()) {
      setFilteredProviders(providers);
      return;
    }
    const t = search.toLowerCase();
    setFilteredProviders(
      providers.filter(
        (p) =>
          `${p.firstName} ${p.lastName}`.toLowerCase().includes(t) ||
          p.email?.toLowerCase().includes(t) ||
          p.phone?.includes(search) ||
          p.city?.toLowerCase().includes(t),
      ),
    );
  }, [search, providers]);

  const handleStatusUpdate = async (id, status) => {
    try {
      setActionLoading(true);
      await api.patch(`/admin/providers/${id}/status`, { status });
      setSnackbar({
        open: true,
        message: `Provider ${status} successfully`,
        severity: "success",
      });
      setDetailOpen(false);
      setSelectedProvider(null);
      fetchProviders();
    } catch (error) {
      setSnackbar({
        open: true,
        message: error.response?.data?.message || "Action failed",
        severity: "error",
      });
    } finally {
      setActionLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (
      !window.confirm(
        "Are you sure you want to permanently delete this provider? This action cannot be undone.",
      )
    )
      return;
    try {
      setActionLoading(true);
      await api.delete(`/admin/providers/${id}`);
      setSnackbar({
        open: true,
        message: "Provider deleted",
        severity: "success",
      });
      setDetailOpen(false);
      setSelectedProvider(null);
      fetchProviders();
    } catch {
      setSnackbar({
        open: true,
        message: "Failed to delete provider",
        severity: "error",
      });
    } finally {
      setActionLoading(false);
    }
  };

  const openDetails = (provider) => {
    setSelectedProvider(provider);
    setDetailOpen(true);
  };

  const statusColors = {
    pending: "warning",
    approved: "success",
    rejected: "error",
    suspended: "default",
  };

  return (
    <Box>
      <Box
        sx={{
          mb: 4,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          flexWrap: "wrap",
          gap: 2,
        }}
      >
        <Box>
          <Typography variant="h4" gutterBottom>
            Service Providers
          </Typography>
          <Typography color="text.secondary">
            Manage and approve service provider registrations.
          </Typography>
        </Box>
        <TextField
          placeholder="Search by name, email, city..."
          size="small"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ minWidth: 280, bgcolor: "white" }}
          slotProps={{
            input: {
              startAdornment: (
                <InputAdornment position="start">
                  <Search size={18} />
                </InputAdornment>
              ),
            },
          }}
        />
      </Box>

      <Card sx={{ mb: 4 }}>
        <Tabs
          value={tabValue}
          onChange={(e, v) => {
            setTabValue(v);
            setSearch("");
          }}
          sx={{ borderBottom: 1, borderColor: "divider", px: 2 }}
        >
          <Tab label="Pending Approval" />
          <Tab label="Approved" />
          <Tab label="Suspended" />
          <Tab label="Rejected" />
        </Tabs>

        {loading ? (
          <Box sx={{ display: "flex", justifyContent: "center", py: 8 }}>
            <CircularProgress />
          </Box>
        ) : (
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Provider</TableCell>
                  <TableCell>Service Type</TableCell>
                  <TableCell>Location</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell>Join Date</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {filteredProviders.map((p) => (
                  <TableRow key={p._id} hover>
                    <TableCell>
                      <Box
                        sx={{ display: "flex", alignItems: "center", gap: 2 }}
                      >
                        <Avatar
                          src={p.profileImage}
                          sx={{
                            bgcolor: "secondary.light",
                            color: "secondary.main",
                          }}
                        >
                          {p.firstName?.charAt(0)}
                        </Avatar>
                        <Box>
                          <Typography variant="subtitle2" fontWeight={700}>
                            {p.firstName} {p.lastName}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {p.email}
                          </Typography>
                        </Box>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        label={p.spSubRole || "N/A"}
                        sx={{ borderRadius: 1.5 }}
                      />
                    </TableCell>
                    <TableCell>{p.city || "N/A"}</TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        label={p.status}
                        color={statusColors[p.status] || "default"}
                      />
                    </TableCell>
                    <TableCell>
                      {new Date(p.createdAt).toLocaleDateString()}
                    </TableCell>
                    <TableCell align="right">
                      <Tooltip title="View Details">
                        <IconButton onClick={() => openDetails(p)}>
                          <Eye size={18} />
                        </IconButton>
                      </Tooltip>
                      {p.status === "pending" && (
                        <>
                          <Tooltip title="Approve">
                            <IconButton
                              color="success"
                              onClick={() =>
                                handleStatusUpdate(p._id, "approved")
                              }
                            >
                              <CheckCircle size={18} />
                            </IconButton>
                          </Tooltip>
                          <Tooltip title="Reject">
                            <IconButton
                              color="error"
                              onClick={() =>
                                handleStatusUpdate(p._id, "rejected")
                              }
                            >
                              <XCircle size={18} />
                            </IconButton>
                          </Tooltip>
                        </>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
                {filteredProviders.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6} align="center" sx={{ py: 10 }}>
                      <Typography color="text.secondary">
                        No providers found in this category.
                      </Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </Card>

      {/* Provider Detail Dialog */}
      <Dialog
        open={detailOpen}
        onClose={() => setDetailOpen(false)}
        maxWidth="md"
        fullWidth
      >
        {selectedProvider && (
          <>
            <DialogTitle
              sx={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}
            >
              Provider Details
              <Chip
                label={selectedProvider.status}
                color={statusColors[selectedProvider.status] || "default"}
              />
            </DialogTitle>
            <DialogContent dividers>
              <Grid container spacing={3}>
                <Grid size={{ xs: 12, md: 4 }} sx={{ textAlign: "center" }}>
                  <Avatar
                    src={selectedProvider.profileImage}
                    sx={{
                      width: 120,
                      height: 120,
                      mx: "auto",
                      mb: 2,
                      border: "4px solid #f0f0f0",
                      fontSize: "2.5rem",
                    }}
                  >
                    {selectedProvider.firstName?.charAt(0)}
                  </Avatar>
                  <Typography variant="h6">
                    {selectedProvider.firstName} {selectedProvider.lastName}
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    {selectedProvider.spSubRole}
                  </Typography>
                  {selectedProvider.rating > 0 && (
                    <Box
                      sx={{
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        gap: 0.5,
                        mt: 1,
                      }}
                    >
                      <Star size={16} fill="#FFB300" color="#FFB300" />
                      <Typography variant="body2" fontWeight={600}>
                        {selectedProvider.rating}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        ({selectedProvider.reviewsCount} reviews)
                      </Typography>
                    </Box>
                  )}
                </Grid>
                <Grid size={{ xs: 12, md: 8 }}>
                  <Box
                    sx={{ display: "flex", flexDirection: "column", gap: 2 }}
                  >
                    <Typography
                      variant="subtitle2"
                      sx={{ color: "primary.main", fontWeight: 700 }}
                    >
                      Contact Information
                    </Typography>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                      <Mail size={16} />{" "}
                      <Typography variant="body2">
                        {selectedProvider.email}
                      </Typography>
                    </Box>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                      <Phone size={16} />{" "}
                      <Typography variant="body2">
                        {selectedProvider.phone}
                      </Typography>
                    </Box>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                      <MapPin size={16} />{" "}
                      <Typography variant="body2">
                        {selectedProvider.address}, {selectedProvider.city}
                      </Typography>
                    </Box>

                    <Divider />

                    <Typography
                      variant="subtitle2"
                      sx={{ color: "primary.main", fontWeight: 700 }}
                    >
                      District Details
                    </Typography>
                    <Typography variant="body2">
                      District: {selectedProvider.districtName || "N/A"}
                    </Typography>
                    <Typography variant="body2">
                      Nazim: {selectedProvider.districtNazim || "N/A"}
                    </Typography>

                    <Divider />

                    <Typography
                      variant="subtitle2"
                      sx={{ color: "primary.main", fontWeight: 700 }}
                    >
                      Professional Information
                    </Typography>
                    <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
                      <Briefcase size={16} />
                      <Typography variant="body2">
                        {selectedProvider.experienceYears || 0} years of
                        experience
                      </Typography>
                    </Box>
                    <Typography variant="body2" color="text.secondary">
                      {selectedProvider.bio || "No bio provided"}
                    </Typography>

                    {selectedProvider.serviceName && (
                      <>
                        <Divider />
                        <Typography
                          variant="subtitle2"
                          sx={{ color: "primary.main", fontWeight: 700 }}
                        >
                          Service Details
                        </Typography>
                        <Typography variant="body2">
                          Service: {selectedProvider.serviceName}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          {selectedProvider.description}
                        </Typography>
                      </>
                    )}

                    {selectedProvider.gallery &&
                      selectedProvider.gallery.length > 0 && (
                        <>
                          <Divider />
                          <Typography
                            variant="subtitle2"
                            sx={{ color: "primary.main", fontWeight: 700 }}
                          >
                            Gallery / Documents
                          </Typography>
                          <Box
                            sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}
                          >
                            {selectedProvider.gallery.map((img, idx) => (
                              <Box
                                key={idx}
                                component="img"
                                src={img}
                                sx={{
                                  width: 80,
                                  height: 80,
                                  borderRadius: 2,
                                  objectFit: "cover",
                                  border: "1px solid #eee",
                                }}
                                alt={`Gallery ${idx + 1}`}
                              />
                            ))}
                          </Box>
                        </>
                      )}

                    {selectedProvider.certifications &&
                      selectedProvider.certifications.length > 0 && (
                        <>
                          <Divider />
                          <Typography
                            variant="subtitle2"
                            sx={{ color: "primary.main", fontWeight: 700 }}
                          >
                            Certifications
                          </Typography>
                          <Box
                            sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}
                          >
                            {selectedProvider.certifications.map(
                              (cert, idx) => (
                                <Chip
                                  key={idx}
                                  label={cert}
                                  size="small"
                                  variant="outlined"
                                />
                              ),
                            )}
                          </Box>
                        </>
                      )}

                    <Divider />
                    <Typography
                      variant="subtitle2"
                      sx={{ color: "primary.main", fontWeight: 700 }}
                    >
                      Stats
                    </Typography>
                    <Box sx={{ display: "flex", gap: 4 }}>
                      <Box>
                        <Typography variant="h6" fontWeight={700}>
                          {selectedProvider.totalOrders || 0}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          Total Orders
                        </Typography>
                      </Box>
                      <Box>
                        <Typography variant="h6" fontWeight={700}>
                          Rs.{" "}
                          {(
                            selectedProvider.totalEarnings || 0
                          ).toLocaleString()}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          Total Earnings
                        </Typography>
                      </Box>
                    </Box>
                  </Box>
                </Grid>
              </Grid>
            </DialogContent>
            <DialogActions sx={{ px: 3, py: 2 }}>
              <Button onClick={() => setDetailOpen(false)}>Close</Button>
              <Button
                variant="outlined"
                color="error"
                startIcon={<Trash2 size={16} />}
                onClick={() => handleDelete(selectedProvider._id)}
                disabled={actionLoading}
              >
                Delete
              </Button>
              {selectedProvider.status === "pending" ? (
                <>
                  <Button
                    variant="contained"
                    color="success"
                    startIcon={<CheckCircle size={18} />}
                    onClick={() =>
                      handleStatusUpdate(selectedProvider._id, "approved")
                    }
                    disabled={actionLoading}
                  >
                    Approve Provider
                  </Button>
                  <Button
                    variant="outlined"
                    color="error"
                    startIcon={<XCircle size={18} />}
                    onClick={() =>
                      handleStatusUpdate(selectedProvider._id, "rejected")
                    }
                    disabled={actionLoading}
                  >
                    Reject
                  </Button>
                </>
              ) : selectedProvider.status === "approved" ? (
                <Button
                  variant="outlined"
                  color="error"
                  startIcon={<ShieldAlert size={18} />}
                  onClick={() =>
                    handleStatusUpdate(selectedProvider._id, "suspended")
                  }
                  disabled={actionLoading}
                >
                  Suspend Provider
                </Button>
              ) : (
                <Button
                  variant="contained"
                  color="success"
                  startIcon={<CheckCircle size={18} />}
                  onClick={() =>
                    handleStatusUpdate(selectedProvider._id, "approved")
                  }
                  disabled={actionLoading}
                >
                  Activate Provider
                </Button>
              )}
            </DialogActions>
          </>
        )}
      </Dialog>

      {/* Snackbar for feedback */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={4000}
        onClose={() => setSnackbar((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
      >
        <Alert
          severity={snackbar.severity}
          onClose={() => setSnackbar((s) => ({ ...s, open: false }))}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default Providers;
