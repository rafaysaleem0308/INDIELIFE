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
  Chip,
  IconButton,
  Tooltip,
  CircularProgress,
  Snackbar,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  TextField,
  InputAdornment,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Avatar,
  Grid,
  Divider,
  Tabs,
  Tab,
} from "@mui/material";
import {
  Eye,
  Trash2,
  Search,
  Utensils,
  WashingMachine,
  Wrench,
  Building2,
} from "lucide-react";
import api, { resolveAssetUrl } from "../utils/api";

const typeIcons = {
  "Meal Provider": <Utensils size={16} />,
  Laundry: <WashingMachine size={16} />,
  Maintenance: <Wrench size={16} />,
  "Hostel/Flat Accommodation": <Building2 size={16} />,
};

const typeColors = {
  "Meal Provider": "warning",
  Laundry: "info",
  Maintenance: "success",
  "Hostel/Flat Accommodation": "secondary",
};

const Services = () => {
  const [services, setServices] = useState([]);
  const [filtered, setFiltered] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState("all");
  const [tab, setTab] = useState(0);
  const [selected, setSelected] = useState(null);
  const [detailOpen, setDetailOpen] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [snackbar, setSnackbar] = useState({
    open: false,
    message: "",
    severity: "success",
  });

  const tabStatuses = ["Active", "Inactive"];

  const fetchServices = useCallback(async () => {
    try {
      setLoading(true);
      const response = await api.get("/admin/services");
      setServices(response.data.services || []);
    } catch (err) {
      console.error(err);
      setServices([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchServices();
  }, [fetchServices]);

  useEffect(() => {
    let data = [...services];
    if (typeFilter !== "all")
      data = data.filter((s) => s.serviceType === typeFilter);
    if (tab === 1) data = data.filter((s) => s.status === "Inactive");
    else data = data.filter((s) => s.status !== "Inactive");
    if (search.trim()) {
      const t = search.toLowerCase();
      data = data.filter(
        (s) =>
          s.serviceName?.toLowerCase().includes(t) ||
          s.providerName?.toLowerCase().includes(t),
      );
    }
    setFiltered(data);
  }, [services, search, typeFilter, tab]);

  const handleDelete = async (id) => {
    if (!window.confirm("Delete this service permanently?")) return;
    try {
      setActionLoading(true);
      await api.delete(`/admin/services/${id}`);
      setSnackbar({
        open: true,
        message: "Service deleted",
        severity: "success",
      });
      setDetailOpen(false);
      fetchServices();
    } catch {
      setSnackbar({
        open: true,
        message: "Failed to delete service",
        severity: "error",
      });
    } finally {
      setActionLoading(false);
    }
  };

  const handleToggleStatus = async (id, currentStatus) => {
    const newStatus = currentStatus === "Active" ? "Inactive" : "Active";
    try {
      await api.patch(`/admin/services/${id}/status`, { status: newStatus });
      setSnackbar({
        open: true,
        message: `Service ${newStatus === "Active" ? "activated" : "deactivated"}`,
        severity: "success",
      });
      fetchServices();
    } catch {
      setSnackbar({
        open: true,
        message: "Failed to update status",
        severity: "error",
      });
    }
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
            Services Management
          </Typography>
          <Typography color="text.secondary">
            Monitor all provider services across the platform.
          </Typography>
        </Box>
        <Box sx={{ display: "flex", gap: 2, flexWrap: "wrap" }}>
          <TextField
            placeholder="Search services or provider..."
            size="small"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            sx={{ minWidth: 240, bgcolor: "white" }}
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
          <FormControl size="small" sx={{ minWidth: 160, bgcolor: "white" }}>
            <InputLabel>Service Type</InputLabel>
            <Select
              value={typeFilter}
              label="Service Type"
              onChange={(e) => setTypeFilter(e.target.value)}
            >
              <MenuItem value="all">All Types</MenuItem>
              <MenuItem value="Meal Provider">Meal</MenuItem>
              <MenuItem value="Laundry">Laundry</MenuItem>
              <MenuItem value="Maintenance">Maintenance</MenuItem>
              <MenuItem value="Hostel/Flat Accommodation">Housing</MenuItem>
            </Select>
          </FormControl>
        </Box>
      </Box>

      <Card>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v)}
          sx={{ borderBottom: 1, borderColor: "divider", px: 2 }}
        >
          <Tab label="Active Services" />
          <Tab label="Inactive" />
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
                  <TableCell>Service</TableCell>
                  <TableCell>Provider</TableCell>
                  <TableCell>Type</TableCell>
                  <TableCell>Price</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {filtered.map((s) => (
                  <TableRow key={s._id} hover>
                    <TableCell>
                      <Box
                        sx={{ display: "flex", alignItems: "center", gap: 2 }}
                      >
                        {s.imageUrl ? (
                          <Avatar
                            src={resolveAssetUrl(s.imageUrl)}
                            variant="rounded"
                            sx={{ width: 44, height: 44 }}
                          />
                        ) : (
                          <Avatar
                            variant="rounded"
                            sx={{
                              bgcolor: "primary.light",
                              color: "primary.main",
                              width: 44,
                              height: 44,
                            }}
                          >
                            {typeIcons[s.serviceType] || <Utensils size={16} />}
                          </Avatar>
                        )}
                        <Box>
                          <Typography variant="subtitle2" fontWeight={700}>
                            {s.serviceName}
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            {s.description?.slice(0, 40)}
                            {s.description?.length > 40 ? "..." : ""}
                          </Typography>
                        </Box>
                      </Box>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2">
                        {s.providerName || "N/A"}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {s.providerCity || ""}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        icon={typeIcons[s.serviceType]}
                        label={s.serviceType || "N/A"}
                        color={typeColors[s.serviceType] || "default"}
                        sx={{ borderRadius: 1.5, textTransform: "capitalize" }}
                      />
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" fontWeight={700}>
                        Rs. {s.price}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        per {s.unit}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        label={s.status || "Active"}
                        color={s.status === "Active" ? "success" : "default"}
                      />
                    </TableCell>
                    <TableCell align="right">
                      <Tooltip title="View Details">
                        <IconButton
                          size="small"
                          onClick={() => {
                            setSelected(s);
                            setDetailOpen(true);
                          }}
                        >
                          <Eye size={18} />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Delete Service">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => handleDelete(s._id)}
                          disabled={actionLoading}
                        >
                          <Trash2 size={18} />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))}
                {filtered.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6} align="center" sx={{ py: 10 }}>
                      <Typography color="text.secondary">
                        No services found.
                      </Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </Card>

      {/* Service Detail Dialog */}
      <Dialog
        open={detailOpen}
        onClose={() => setDetailOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        {selected && (
          <>
            <DialogTitle
              sx={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}
            >
              Service Details
              <Chip
                size="small"
                label={selected.serviceType}
                color={typeColors[selected.serviceType] || "default"}
                sx={{ textTransform: "capitalize" }}
              />
            </DialogTitle>
            <DialogContent dividers>
              {selected.imageUrl && (
                <Box
                  component="img"
                  src={resolveAssetUrl(selected.imageUrl)}
                  alt="Service"
                  sx={{
                    width: "100%",
                    height: 200,
                    objectFit: "cover",
                    borderRadius: 2,
                    mb: 2,
                  }}
                />
              )}
              <Grid container spacing={2}>
                <Grid size={{ xs: 12 }}>
                  <Typography variant="h6" fontWeight={700}>
                    {selected.serviceName}
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    {selected.description || "No description"}
                  </Typography>
                </Grid>
                <Grid size={{ xs: 6 }}>
                  <Typography variant="caption" color="text.secondary">
                    Price
                  </Typography>
                  <Typography
                    variant="h6"
                    fontWeight={700}
                    color="primary.main"
                  >
                    Rs. {selected.price} / {selected.unit}
                  </Typography>
                </Grid>
                <Grid size={{ xs: 6 }}>
                  <Typography variant="caption" color="text.secondary">
                    Status
                  </Typography>
                  <Typography variant="body1" fontWeight={600}>
                    {selected.status || "Active"}
                  </Typography>
                </Grid>
                <Grid size={{ xs: 12 }}>
                  <Divider />
                </Grid>
                <Grid size={{ xs: 12 }}>
                  <Typography
                    variant="subtitle2"
                    color="primary.main"
                    fontWeight={700}
                    gutterBottom
                  >
                    Provider Info
                  </Typography>
                  <Typography variant="body2">
                    Name: {selected.providerName || "N/A"}
                  </Typography>
                  <Typography variant="body2">
                    City: {selected.providerCity || "N/A"}
                  </Typography>
                  <Typography variant="body2">
                    Phone: {selected.providerPhone || "N/A"}
                  </Typography>
                </Grid>
                {selected.servicesOffered?.length > 0 && (
                  <Grid size={{ xs: 12 }}>
                    <Typography
                      variant="subtitle2"
                      color="primary.main"
                      fontWeight={700}
                      gutterBottom
                    >
                      Services Offered
                    </Typography>
                    <Box sx={{ display: "flex", gap: 1, flexWrap: "wrap" }}>
                      {selected.servicesOffered.map((s, i) => (
                        <Chip key={i} label={s} size="small" />
                      ))}
                    </Box>
                  </Grid>
                )}
              </Grid>
            </DialogContent>
            <DialogActions sx={{ px: 3, py: 2 }}>
              <Button onClick={() => setDetailOpen(false)}>Close</Button>
              <Button
                variant="outlined"
                color={selected.status === "Active" ? "warning" : "success"}
                onClick={() => {
                  handleToggleStatus(selected._id, selected.status);
                  setDetailOpen(false);
                }}
              >
                {selected.status === "Active" ? "Deactivate" : "Activate"}
              </Button>
              <Button
                variant="outlined"
                color="error"
                startIcon={<Trash2 size={16} />}
                onClick={() => handleDelete(selected._id)}
                disabled={actionLoading}
              >
                Delete
              </Button>
            </DialogActions>
          </>
        )}
      </Dialog>

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

export default Services;
