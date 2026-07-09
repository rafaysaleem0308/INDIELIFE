import { useState, useEffect, useCallback } from 'react';
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
    TextField,
    InputAdornment,
    Tooltip,
    CircularProgress,
    Snackbar,
    Alert,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    Grid,
    Divider,
} from '@mui/material';
import { Search, Eye, ShieldAlert, Trash2, ShieldCheck, Mail, Phone, MapPin } from 'lucide-react';
import api from '../utils/api';

const Users = () => {
    const [users, setUsers] = useState([]);
    const [filteredUsers, setFilteredUsers] = useState([]);
    const [searchTerm, setSearchTerm] = useState('');
    const [loading, setLoading] = useState(true);
    const [actionLoading, setActionLoading] = useState(false);
    const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
    const [selectedUser, setSelectedUser] = useState(null);
    const [detailOpen, setDetailOpen] = useState(false);

    const fetchUsers = useCallback(async () => {
        try {
            setLoading(true);
            const response = await api.get('/admin/users');
            setUsers(response.data.users || []);
        } catch (error) {
            console.error('Failed to fetch users:', error);
            setUsers([]);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchUsers();
    }, [fetchUsers]);

    useEffect(() => {
        if (!searchTerm.trim()) {
            setFilteredUsers(users);
            return;
        }
        const term = searchTerm.toLowerCase();
        const filtered = users.filter(user =>
            `${user.firstName} ${user.lastName}`.toLowerCase().includes(term) ||
            user.email?.toLowerCase().includes(term) ||
            user.phone?.includes(searchTerm)
        );
        setFilteredUsers(filtered);
    }, [searchTerm, users]);

    const handleToggleStatus = async (id, currentStatus) => {
        try {
            setActionLoading(true);
            const newStatus = currentStatus === 'active' ? 'suspended' : 'active';
            await api.patch(`/admin/users/${id}/status`, { accountStatus: newStatus });
            setSnackbar({ open: true, message: `User ${newStatus === 'active' ? 'activated' : 'suspended'} successfully`, severity: 'success' });
            fetchUsers();
        } catch {
            setSnackbar({ open: true, message: 'Failed to update user status', severity: 'error' });
        } finally {
            setActionLoading(false);
        }
    };

    const handleDeleteUser = async (id) => {
        if (!window.confirm('Are you sure you want to delete this user? This action cannot be undone.')) return;
        try {
            setActionLoading(true);
            await api.delete(`/admin/users/${id}`);
            setSnackbar({ open: true, message: 'User deleted successfully', severity: 'success' });
            setDetailOpen(false);
            setSelectedUser(null);
            fetchUsers();
        } catch {
            setSnackbar({ open: true, message: 'Failed to delete user', severity: 'error' });
        } finally {
            setActionLoading(false);
        }
    };

    return (
        <Box>
            <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
                <Box>
                    <Typography variant="h4" gutterBottom>
                        User Management
                    </Typography>
                    <Typography color="text.secondary">
                        View and manage platform users.
                    </Typography>
                </Box>
                <TextField
                    placeholder="Search by name, email, or phone..."
                    variant="outlined"
                    size="small"
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    sx={{ minWidth: 300, bgcolor: 'white' }}
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

            <Card>
                {loading ? (
                    <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <TableContainer>
                        <Table>
                            <TableHead>
                                <TableRow>
                                    <TableCell>User</TableCell>
                                    <TableCell>Phone</TableCell>
                                    <TableCell>Location</TableCell>
                                    <TableCell>Orders</TableCell>
                                    <TableCell>Status</TableCell>
                                    <TableCell>Joined</TableCell>
                                    <TableCell align="right">Actions</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {filteredUsers.map((user) => (
                                    <TableRow key={user._id} hover>
                                        <TableCell>
                                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                                <Avatar src={user.profileImage} sx={{ bgcolor: 'primary.light', color: 'primary.main' }}>
                                                    {user.firstName?.charAt(0)}
                                                </Avatar>
                                                <Box>
                                                    <Typography variant="subtitle2" fontWeight={700}>
                                                        {user.firstName} {user.lastName}
                                                    </Typography>
                                                    <Typography variant="caption" color="text.secondary">
                                                        {user.email}
                                                    </Typography>
                                                </Box>
                                            </Box>
                                        </TableCell>
                                        <TableCell>{user.phone || 'N/A'}</TableCell>
                                        <TableCell>{user.city || 'N/A'}</TableCell>
                                        <TableCell>
                                            <Typography variant="body2">{user.totalOrders || 0}</Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Chip
                                                size="small"
                                                label={user.accountStatus || 'active'}
                                                color={user.accountStatus === 'active' ? 'success' : 'error'}
                                            />
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="caption">{new Date(user.createdAt).toLocaleDateString()}</Typography>
                                        </TableCell>
                                        <TableCell align="right">
                                            <Tooltip title="View Profile">
                                                <IconButton size="small" onClick={() => { setSelectedUser(user); setDetailOpen(true); }}>
                                                    <Eye size={18} />
                                                </IconButton>
                                            </Tooltip>
                                            <Tooltip title={user.accountStatus === 'active' ? 'Suspend' : 'Activate'}>
                                                <IconButton
                                                    size="small"
                                                    color={user.accountStatus === 'active' ? 'error' : 'success'}
                                                    onClick={() => handleToggleStatus(user._id, user.accountStatus)}
                                                    disabled={actionLoading}
                                                >
                                                    {user.accountStatus === 'active' ? <ShieldAlert size={18} /> : <ShieldCheck size={18} />}
                                                </IconButton>
                                            </Tooltip>
                                            <Tooltip title="Delete">
                                                <IconButton size="small" color="error" onClick={() => handleDeleteUser(user._id)} disabled={actionLoading}>
                                                    <Trash2 size={18} />
                                                </IconButton>
                                            </Tooltip>
                                        </TableCell>
                                    </TableRow>
                                ))}
                                {filteredUsers.length === 0 && (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center" sx={{ py: 10 }}>
                                            <Typography color="text.secondary">No users found.</Typography>
                                        </TableCell>
                                    </TableRow>
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}
            </Card>

            {/* User Detail Dialog */}
            <Dialog open={detailOpen} onClose={() => setDetailOpen(false)} maxWidth="sm" fullWidth>
                {selectedUser && (
                    <>
                        <DialogTitle>User Profile</DialogTitle>
                        <DialogContent dividers>
                            <Box sx={{ textAlign: 'center', mb: 3 }}>
                                <Avatar
                                    src={selectedUser.profileImage}
                                    sx={{ width: 80, height: 80, mx: 'auto', mb: 2, fontSize: '2rem', bgcolor: 'primary.main' }}
                                >
                                    {selectedUser.firstName?.charAt(0)}
                                </Avatar>
                                <Typography variant="h6">{selectedUser.firstName} {selectedUser.lastName}</Typography>
                                <Chip
                                    size="small"
                                    label={selectedUser.accountStatus || 'active'}
                                    color={selectedUser.accountStatus === 'active' ? 'success' : 'error'}
                                    sx={{ mt: 1 }}
                                />
                            </Box>
                            <Divider sx={{ mb: 2 }} />
                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <Mail size={16} /> <Typography variant="body2">{selectedUser.email}</Typography>
                                </Box>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <Phone size={16} /> <Typography variant="body2">{selectedUser.phone}</Typography>
                                </Box>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <MapPin size={16} /> <Typography variant="body2">{selectedUser.address || selectedUser.city || 'N/A'}</Typography>
                                </Box>
                            </Box>
                            <Divider sx={{ my: 2 }} />
                            <Grid container spacing={2}>
                                <Grid size={{ xs: 4 }}>
                                    <Typography variant="h6" fontWeight={700} align="center">{selectedUser.totalOrders || 0}</Typography>
                                    <Typography variant="caption" color="text.secondary" display="block" align="center">Total Orders</Typography>
                                </Grid>
                                <Grid size={{ xs: 4 }}>
                                    <Typography variant="h6" fontWeight={700} align="center">{selectedUser.activeOrders || 0}</Typography>
                                    <Typography variant="caption" color="text.secondary" display="block" align="center">Active</Typography>
                                </Grid>
                                <Grid size={{ xs: 4 }}>
                                    <Typography variant="h6" fontWeight={700} align="center">{selectedUser.points || 0}</Typography>
                                    <Typography variant="caption" color="text.secondary" display="block" align="center">Points</Typography>
                                </Grid>
                            </Grid>
                            <Divider sx={{ my: 2 }} />
                            <Typography variant="caption" color="text.secondary">
                                Joined: {new Date(selectedUser.createdAt).toLocaleDateString()} | Last Login: {selectedUser.lastLogin ? new Date(selectedUser.lastLogin).toLocaleDateString() : 'N/A'}
                            </Typography>
                        </DialogContent>
                        <DialogActions>
                            <Button onClick={() => setDetailOpen(false)}>Close</Button>
                            <Button
                                variant="outlined"
                                color="error"
                                startIcon={<Trash2 size={16} />}
                                onClick={() => handleDeleteUser(selectedUser._id)}
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

export default Users;
