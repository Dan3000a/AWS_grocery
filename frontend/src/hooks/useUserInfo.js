import { useState, useEffect } from 'react';
import { API_BASE_URL } from '../config';

const useUserInfo = () => {
  const [username, setUsername] = useState('');
  const [avatarUrl, setAvatarUrl] = useState(null);
  const [users, setUsers] = useState([]);
  const [s3Config, setS3Config] = useState({
    USE_S3_STORAGE: false,
    S3_BUCKET: '',
    S3_REGION: ''
  });

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/config`);
      if (response.ok) {
        const configData = await response.json();
        setS3Config(configData);
      } else {
        console.error(`Failed to fetch config: ${response.status} ${response.statusText}`);
        const text = await response.text();
        console.error("Response body:", text);
      }
    } catch (error) {
      console.error("Error fetching config:", error);
    }
  };

  const fetchUserInfo = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) return;
      const response = await fetch(`${API_BASE_URL}/api/me/info`, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        setUsername(data.username);
        setAvatarUrl(data.avatar);
      } else {
        console.error(`Failed to fetch user info: ${response.status} ${response.statusText}`);
        const text = await response.text();
        console.error("Response body:", text);
      }
    } catch (error) {
      console.error('Error fetching user info:', error);
    }
  };

  const fetchAllUsers = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) return;
      const response = await fetch(`${API_BASE_URL}/api/me/all-users`, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        setUsers(data);
      } else {
        console.error(`Failed to fetch users: ${response.status} ${response.statusText}`);
        const text = await response.text();
        console.error("Response body:", text);
      }
    } catch (error) {
      console.error('Error fetching users:', error);
    }
  };

  const updateAvatarInState = (newAvatar) => {
    const newAvatarUrl = newAvatar;
    setAvatarUrl(newAvatarUrl);

    setUsers((prevUsers) =>
      prevUsers.map((user) =>
        user.username === username ? { ...user, avatar: newAvatar } : user
      )
    );
  };

  useEffect(() => {
    fetchUserInfo();
    fetchAllUsers();
  }, []);

  const getAvatarUrl = (username) => {
    const user = users.find((user) => user.username === username);

    if (user && user.avatar) {
      if (s3Config.USE_S3_STORAGE) {
        return `https://${s3Config.S3_BUCKET}.s3.${s3Config.S3_REGION}.amazonaws.com/avatars/${user.avatar}`;
      }
      return user.avatar;
    }

    if (s3Config.USE_S3_STORAGE) {
      return `https://${s3Config.S3_BUCKET}.s3.${s3Config.S3_REGION}.amazonaws.com/avatars/user_default.png`;
    }
    return `${process.env.REACT_APP_BACKEND_SERVER}/api/me/avatar/user_default.png`;
  };

  return {
    username,
    avatarUrl,
    users,
    getAvatarUrl,
    fetchUserInfo,
    updateAvatarInState,
  };
};

export default useUserInfo;