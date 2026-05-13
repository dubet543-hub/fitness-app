const BASE = '/api';

export const getToken = () => localStorage.getItem('sc_token');
export const getUser  = () => {
  const raw = localStorage.getItem('sc_user');
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    localStorage.removeItem('sc_user');
    localStorage.removeItem('sc_token');
    return null;
  }
};
export const setSession = (token, user) => {
  localStorage.setItem('sc_token', token);
  localStorage.setItem('sc_user', JSON.stringify(user));
};
export const clearSession = () => {
  localStorage.removeItem('sc_token');
  localStorage.removeItem('sc_user');
};

async function req(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${getToken()}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = {};
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      throw new Error(`Server returned ${res.status} instead of JSON. Check that the backend is running.`);
    }
  }
  if (!res.ok) {
    throw new Error(data.error || `Request failed with status ${res.status}`);
  }
  return data;
}

export const api = {
  post:   (path, body) => req('POST',   path, body),
  get:    (path)       => req('GET',    path),
  put:    (path, body) => req('PUT',    path, body),
  delete: (path)       => req('DELETE', path),
};
