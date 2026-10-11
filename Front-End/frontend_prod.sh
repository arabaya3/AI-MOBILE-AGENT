npm install -g pm2
pm2 start npm --name frontend -- run dev
pm2 logs frontend
<-----------------------------------> If needed:
pm2 restart frontend
pm2 logs frontend
<----------------------------------->
vi package.json
<----------------------------------->
edit package.json to change dev script port to 5174:
<----------------------------------->
root@ubuntu:~/AI-Agents/Fron-End# cat package.json 
{
  "name": "fron-end",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "preview": "vite preview",
    "dev": "vite --host 0.0.0.0 --port 5174"
  },
  "dependencies": {
    "@emotion/react": "^11.14.0",
    "@emotion/styled": "^11.14.1",
    "@mui/icons-material": "^7.3.6",
    "@mui/material": "^7.3.6",
    "@types/react-syntax-highlighter": "^15.5.13",
    "axios": "^1.13.2",
    "i18next": "^25.6.2",
    "jwt-decode": "^4.0.0",
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "react-i18next": "^16.2.0",
    "react-markdown": "^10.1.0",
    "react-router-dom": "^7.10.1",
    "react-syntax-highlighter": "^16.1.0",
    "remark-gfm": "^4.0.1",
    "zustand": "^5.0.9"
  },
  "devDependencies": {
    "@eslint/js": "^9.39.1",
    "@types/node": "^24.10.1",
    "@types/react": "^19.2.5",
    "@types/react-dom": "^19.2.3",
    "@vitejs/plugin-react": "^5.1.1",
    "eslint": "^9.39.1",
    "eslint-plugin-react-hooks": "^7.0.1",
    "eslint-plugin-react-refresh": "^0.4.24",
    "globals": "^16.5.0",
    "typescript": "~5.9.3",
    "typescript-eslint": "^8.46.4",
    "vite": "npm:rolldown-vite@7.2.5"
  },
  "overrides": {
    "vite": "npm:rolldown-vite@7.2.5"
  }
}
root@ubuntu:~/AI-Agents/Fron-End# 
