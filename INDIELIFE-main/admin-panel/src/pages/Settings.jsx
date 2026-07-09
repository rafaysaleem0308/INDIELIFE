import { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Typography,
    Card,
    CardContent,
    TextField,
    Button,
    CircularProgress,
    Snackbar,
    Alert,
    Grid,
    Switch,
    FormControlLabel,
    Divider,
} from '@mui/material';
import { Save, RefreshCw } from 'lucide-react';
import api from '../utils/api';

const Settings = () => {
    const [settings, setSettings] = useState({
        platformName: 'IndieLife',
        commissionPercentage: 10,
        supportEmail: '',
        supportPhone: '',
        appVersion: '1.0.0',
        isMaintenanceMode: false,
    });
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

    const fetchSettings = useCallback(async () => {
        try {
            setLoading(true);
            const response = await api.get('/admin/settings');
            if (response.data.settings) {
                setSettings(response.data.settings);
            }
        } catch (error) {
            console.error('Failed to fetch settings:', error);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchSettings();
    }, [fetchSettings]);

    const handleChange = (field) => (event) => {
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        setSettings(prev => ({ ...prev, [field]: value }));
    };

    const handleSave = async () => {
        try {
            setSaving(true);
            await api.put('/admin/settings', {
                platformName: settings.platformName,
                commissionPercentage: parseFloat(settings.commissionPercentage) || 10,
                supportEmail: settings.supportEmail,
                supportPhone: settings.supportPhone,
                appVersion: settings.appVersion,
                isMaintenanceMode: settings.isMaintenanceMode,
            });
            setSnackbar({ open: true, message: 'Settings saved successfully', severity: 'success' });
        } catch {
            setSnackbar({ open: true, message: 'Failed to save settings', severity: 'error' });
        } finally {
            setSaving(false);
        }
    };

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Box>
            <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                    <Typography variant="h4" gutterBottom>
                        Platform Settings
                    </Typography>
                    <Typography color="text.secondary">
                        Configure global platform parameters.
                    </Typography>
                </Box>
                <Button
                    variant="outlined"
                    startIcon={<RefreshCw size={16} />}
                    onClick={fetchSettings}
                >
                    Refresh
                </Button>
            </Box>

            <Grid container spacing={3}>
                <Grid size={{ xs: 12, lg: 8 }}>
                    <Card>
                        <CardContent sx={{ p: 4 }}>
                            <Typography variant="h6" gutterBottom fontWeight={700}>
                                General Settings
                            </Typography>
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, mt: 2 }}>
                                <TextField
                                    label="Platform Name"
                                    fullWidth
                                    value={settings.platformName || ''}
                                    onChange={handleChange('platformName')}
                                />
                                <TextField
                                    label="App Version"
                                    fullWidth
                                    value={settings.appVersion || ''}
                                    onChange={handleChange('appVersion')}
                                />
                            </Box>

                            <Divider sx={{ my: 4 }} />

                            <Typography variant="h6" gutterBottom fontWeight={700}>
                                Commission & Revenue
                            </Typography>
                            <Box sx={{ mt: 2 }}>
                                <TextField
                                    label="Commission Percentage (%)"
                                    type="number"
                                    fullWidth
                                    value={settings.commissionPercentage || ''}
                                    onChange={handleChange('commissionPercentage')}
                                    helperText="The percentage charged on each transaction as platform fee."
                                    slotProps={{ htmlInput: { min: 0, max: 100, step: 0.5 } }}
                                />
                            </Box>

                            <Divider sx={{ my: 4 }} />

                            <Typography variant="h6" gutterBottom fontWeight={700}>
                                Support Contact
                            </Typography>
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, mt: 2 }}>
                                <TextField
                                    label="Support Email"
                                    fullWidth
                                    value={settings.supportEmail || ''}
                                    onChange={handleChange('supportEmail')}
                                />
                                <TextField
                                    label="Support Phone"
                                    fullWidth
                                    value={settings.supportPhone || ''}
                                    onChange={handleChange('supportPhone')}
                                />
                            </Box>

                            <Divider sx={{ my: 4 }} />

                            <Typography variant="h6" gutterBottom fontWeight={700}>
                                Maintenance
                            </Typography>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={settings.isMaintenanceMode || false}
                                        onChange={(e) => setSettings(prev => ({ ...prev, isMaintenanceMode: e.target.checked }))}
                                        color="warning"
                                    />
                                }
                                label="Enable Maintenance Mode"
                            />
                            <Typography variant="caption" color="text.secondary" display="block">
                                When enabled, the mobile app will display a maintenance message to users.
                            </Typography>

                            <Box sx={{ mt: 4 }}>
                                <Button
                                    variant="contained"
                                    size="large"
                                    startIcon={saving ? <CircularProgress size={20} color="inherit" /> : <Save size={18} />}
                                    onClick={handleSave}
                                    disabled={saving}
                                    sx={{ px: 4 }}
                                >
                                    {saving ? 'Saving...' : 'Save Changes'}
                                </Button>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid size={{ xs: 12, lg: 4 }}>
                    <Card>
                        <CardContent sx={{ p: 4 }}>
                            <Typography variant="h6" gutterBottom fontWeight={700}>
                                Current Configuration
                            </Typography>
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 2 }}>
                                {[
                                    { label: 'Platform', value: settings.platformName },
                                    { label: 'Version', value: settings.appVersion },
                                    { label: 'Commission', value: `${settings.commissionPercentage}%` },
                                    { label: 'Email', value: settings.supportEmail || 'Not set' },
                                    { label: 'Phone', value: settings.supportPhone || 'Not set' },
                                    { label: 'Maintenance', value: settings.isMaintenanceMode ? '⚠️ ON' : '✅ OFF' },
                                ].map((item, i) => (
                                    <Box key={i} sx={{ display: 'flex', justifyContent: 'space-between', py: 1, borderBottom: '1px solid #f0f0f0' }}>
                                        <Typography variant="body2" color="text.secondary" fontWeight={600}>{item.label}</Typography>
                                        <Typography variant="body2" fontWeight={600}>{item.value}</Typography>
                                    </Box>
                                ))}
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            <Snackbar
                open={snackbar.open}
                autoHideDuration={4000}
                onClose={() => setSnackbar(s => ({ ...s, open: false }))}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
            >
                <Alert severity={snackbar.severity} onClose={() => setSnackbar(s => ({ ...s, open: false }))}>
                    {snackbar.message}
                </Alert>
            </Snackbar>
        </Box>
    );
};

export default Settings;
