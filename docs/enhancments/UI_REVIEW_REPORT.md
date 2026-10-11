# UI Review and Enhancement Report

## Overview
This report summarizes the UI issues identified in the mobile and web application and outlines the plan to address them.

## Identified Issues

### 1. Login Page Mobile Responsiveness
- **Issue:** The login page layout is broken on mobile devices. The branding section and the form section stack vertically, taking up too much space and requiring scrolling.
- **Location:** `Front-End/src/pages/AuthPage.tsx`
- **Proposed Fix:** Adjust the layout to better handle small screens. Hide or minimize the large branding panel on mobile to focus on the login form.

### 2. Spaces Sidebar & Mobile Navigation
- **Issue:** On mobile, the Spaces Sidebar takes up full width and can be very long, pushing other content down. The scroll behavior is "very bad". After creating a space, the user feels stuck (cannot "use it" or "use the chat").
- **Location:** `Front-End/src/components/SpaceSidebar.tsx`
- **Proposed Fix:** 
    - Ensure the sidebar has a max-height and proper scrolling overflow on mobile.
    - On mobile, `SpaceSidebar` is inside a Drawer. Ensure it closes or updates correctly after creation/selection.
    - Improve the scrollbar experience.

### 3. Usage Dashboard Loop & Error for Non-Admins
- **Issue:** Non-admin users encounter console errors and reloading loops when accessing usage stats.
- **Location:** `Front-End/src/components/SpaceAdminDialog.tsx` & `AdminAnalyticsDashboard.tsx`
- **Root Cause:** The "Usage" tab is visible to all users in the Space Admin dialog, but the API endpoint `getSpaceDashboardStats` likely restricts access to admins (403/401). 401 triggers a logout/reload.
- **Proposed Fix:** Hide the "Usage" tab for non-admin users in `SpaceAdminDialog`. Improve error handling in `AdminAnalyticsDashboard` to display a friendly error instead of spinning forever.

### 4. File Name Overflow
- **Issue:** Long filenames (e.g., `server4Lex-Techgpt[51].docx`) overflow the document selector widget on both mobile and web.
- **Location:** `Front-End/src/components/DocumentSelector.tsx`
- **Proposed Fix:** Apply text truncation (`noWrap`/`text-overflow: ellipsis`) to the file name list items.

### 5. Mobile Chat Layout
- **Issue:** Users cannot use chat and files effectively on mobile. The layout order puts Chat first, then Files/History below, which might be pushed off-screen or be hard to reach.
- **Location:** `Front-End/src/pages/ChatPage.tsx`
- **Proposed Fix:** 
    - Review the Flexbox layout rules. 
    - Ensure the main chat container has constrained height on mobile so scrolling works within the chat bubble list, not the whole page.

## Implementation Plan

1.  **Refactor `AuthPage.tsx`**: responsive adjustments.
2.  **Refactor `SpaceSidebar.tsx`**: Fix mobile height strings.
3.  **Refactor `DocumentSelector.tsx`**: Add truncation.
4.  **Refactor `SpaceAdminDialog.tsx`**: Conditionally render Usage tab.
5.  **Refactor `AdminAnalyticsDashboard.tsx`**: Better error state.
