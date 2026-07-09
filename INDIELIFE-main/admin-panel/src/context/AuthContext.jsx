import { useState, useCallback } from 'react';
import api from '../utils/api';
import { AuthContext } from './useAuth';

const getStoredAdminUser = () => {
    try {
        const storedUser = localStorage.getItem('admin_user');
        const token = localStorage.getItem('admin_token');
        return storedUser && token ? JSON.parse(storedUser) : null;
    } catch {
        localStorage.removeItem('admin_user');
        localStorage.removeItem('admin_token');
        return null;
    }
};

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(getStoredAdminUser);
    const [loading] = useState(false);

    const login = useCallback(async (email, password) => {
        try {
            const response = await api.post('/admin/login', { email, password });
            const { user: userData, accessToken } = response.data;

            localStorage.setItem('admin_token', accessToken);
            localStorage.setItem('admin_user', JSON.stringify(userData));
            setUser(userData);
            return { success: true };
        } catch (error) {
            return {
                success: false,
                message: error.response?.data?.message || 'Login failed. Please check your credentials.',
            };
        }
    }, []);

    const logout = useCallback(() => {
        localStorage.removeItem('admin_token');
        localStorage.removeItem('admin_user');
        setUser(null);
        window.location.href = '/login';
    }, []);

    return (
        <AuthContext.Provider value={{ user, login, logout, loading }}>
            {children}
        </AuthContext.Provider>
    );
};
