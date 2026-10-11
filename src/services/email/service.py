"""Email service for sending notifications and transactional emails."""

import hashlib
import logging
import smtplib
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional
from urllib.parse import urlencode

from src.core.settings.config import settings

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via SMTP."""

    def __init__(self):
        self.enabled = settings.EMAIL_ENABLED
        self.smtp_host = settings.SMTP_HOST
        self.smtp_port = settings.SMTP_PORT
        self.smtp_user = settings.SMTP_USER
        self.smtp_password = settings.SMTP_PASSWORD
        self.from_email = settings.EMAIL_FROM
        self.from_name = settings.EMAIL_FROM_NAME
        self.use_tls = settings.SMTP_USE_TLS

    def _send_email(self, to_email: str, subject: str, html_body: str, text_body: Optional[str] = None) -> bool:
        """Send an email via SMTP."""
        if not self.enabled:
            logger.info(f"Email disabled. Would send to {to_email}: {subject}")
            return False

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"{self.from_name} <{self.from_email}>"
            msg["To"] = to_email

            # Add text and HTML parts
            if text_body:
                msg.attach(MIMEText(text_body, "plain"))
            msg.attach(MIMEText(html_body, "html"))

            # Connect to SMTP server
            if self.use_tls:
                server = smtplib.SMTP(self.smtp_host, self.smtp_port)
                server.starttls()
            else:
                server = smtplib.SMTP_SSL(self.smtp_host, self.smtp_port)

            if self.smtp_user and self.smtp_password:
                server.login(self.smtp_user, self.smtp_password)

            server.send_message(msg)
            server.quit()

            logger.info(f"Email sent successfully to {to_email}")
            return True

        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {str(e)}")
            return False

    def send_verification_email(self, to_email: str, verification_token: str, user_name: Optional[str] = None) -> bool:
        """Send email verification link."""
        verification_link = f"{settings.FRONTEND_URL}/verify-email?token={verification_token}"
        
        subject = "Verify your email address"
        
        html_body = f"""
        <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: #2563eb;">Welcome to TEIA AI Agents!</h2>
                    <p>Hello{f" {user_name}" if user_name else ""},</p>
                    <p>Thank you for registering. Please verify your email address by clicking the button below:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{verification_link}" 
                           style="background-color: #2563eb; color: white; padding: 12px 30px; 
                                  text-decoration: none; border-radius: 5px; display: inline-block;">
                            Verify Email Address
                        </a>
                    </div>
                    <p>Or copy and paste this link into your browser:</p>
                    <p style="word-break: break-all; color: #666;">{verification_link}</p>
                    <p style="margin-top: 30px; color: #666; font-size: 14px;">
                        This link will expire in 24 hours. If you didn't create an account, you can safely ignore this email.
                    </p>
                </div>
            </body>
        </html>
        """
        
        text_body = f"""
        Welcome to TEIA AI Agents!
        
        Please verify your email address by visiting this link:
        {verification_link}
        
        This link will expire in 24 hours.
        """
        
        return self._send_email(to_email, subject, html_body, text_body)

    def send_password_reset_email(self, to_email: str, reset_token: str, user_name: Optional[str] = None) -> bool:
        """Send password reset link."""
        reset_link = f"{settings.FRONTEND_URL.rstrip('/')}/auth?{urlencode({'token': reset_token})}"
        
        subject = "Reset your password"
        
        html_body = f"""
        <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: #2563eb;">Password Reset Request</h2>
                    <p>Hello{f" {user_name}" if user_name else ""},</p>
                    <p>We received a request to reset your password. Click the button below to create a new password:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{reset_link}" 
                           style="background-color: #2563eb; color: white; padding: 12px 30px; 
                                  text-decoration: none; border-radius: 5px; display: inline-block;">
                            Reset Password
                        </a>
                    </div>
                    <p>Or copy and paste this link into your browser:</p>
                    <p style="word-break: break-all; color: #666;">{reset_link}</p>
                    <p style="margin-top: 30px; color: #666; font-size: 14px;">
                        This link will expire in 1 hour. If you didn't request a password reset, you can safely ignore this email.
                    </p>
                </div>
            </body>
        </html>
        """
        
        text_body = f"""
        Password Reset Request
        
        Click this link to reset your password:
        {reset_link}
        
        This link will expire in 1 hour.
        """
        
        return self._send_email(to_email, subject, html_body, text_body)

    def send_space_invitation_email(
        self, 
        to_email: str, 
        space_name: str, 
        inviter_name: Optional[str], 
        invite_token: str
    ) -> bool:
        """Send space invitation email."""
        invite_link = f"{settings.FRONTEND_URL}/join-space?token={invite_token}"
        
        subject = f"You've been invited to join {space_name}"
        
        inviter_text = f"{inviter_name} has" if inviter_name else "You have been"
        
        html_body = f"""
        <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: #2563eb;">Space Invitation</h2>
                    <p>{inviter_text} invited you to join the workspace <strong>{space_name}</strong> on TEIA AI Agents.</p>
                    <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px 14px; margin: 16px 0;">
                        <p style="margin: 0 0 6px 0;"><strong>Invitation details</strong></p>
                        <ul style="margin: 0; padding-left: 18px; color: #475569;">
                            <li><strong>Workspace:</strong> {space_name}</li>
                            <li><strong>Invited by:</strong> {inviter_name or 'Workspace admin'}</li>
                            <li><strong>Invite email:</strong> {to_email}</li>
                            <li><strong>Issued:</strong> {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}</li>
                        </ul>
                    </div>
                    <p>Click the button below to accept the invitation:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{invite_link}" 
                           style="background-color: #2563eb; color: white; padding: 12px 30px; 
                                  text-decoration: none; border-radius: 5px; display: inline-block;">
                            Join Workspace
                        </a>
                    </div>
                    <p>Or copy and paste this link into your browser:</p>
                    <p style="word-break: break-all; color: #666;">{invite_link}</p>
                    <p style="margin-top: 30px; color: #666; font-size: 14px;">
                        This invitation link will expire in 7 days.
                    </p>
                </div>
            </body>
        </html>
        """
        
        text_body = f"""
        Space Invitation
        
        {inviter_text} invited you to join {space_name}.

        Invitation details:
        - Workspace: {space_name}
        - Invited by: {inviter_name or 'Workspace admin'}
        - Invite email: {to_email}
        - Issued: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}
        
        Join by visiting: {invite_link}
        
        This invitation expires in 7 days.
        """
        
        return self._send_email(to_email, subject, html_body, text_body)

    def send_request_status_email(
        self,
        to_email: str,
        space_name: str,
        request_type: str,
        status: str,
        reviewer_note: Optional[str] = None
    ) -> bool:
        """Send notification about request status change."""
        status_text = "approved" if status == "approved" else "declined"
        subject = f"Your request has been {status_text}"
        
        color = "#10b981" if status == "approved" else "#ef4444"
        
        html_body = f"""
        <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h2 style="color: {color};">Request {status_text.title()}</h2>
                    <p>Your <strong>{request_type}</strong> request for workspace <strong>{space_name}</strong> has been {status_text}.</p>
                    <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px 14px; margin: 16px 0;">
                        <p style="margin: 0 0 6px 0;"><strong>Request details</strong></p>
                        <ul style="margin: 0; padding-left: 18px; color: #475569;">
                            <li><strong>Workspace:</strong> {space_name}</li>
                            <li><strong>Request type:</strong> {request_type}</li>
                            <li><strong>Status:</strong> {status_text.title()}</li>
                            <li><strong>Reviewed:</strong> {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}</li>
                        </ul>
                    </div>
                    {f'<p><strong>Note from reviewer:</strong> {reviewer_note}</p>' if reviewer_note else ''}
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{settings.FRONTEND_URL}/spaces" 
                           style="background-color: #2563eb; color: white; padding: 12px 30px; 
                                  text-decoration: none; border-radius: 5px; display: inline-block;">
                            Go to Spaces
                        </a>
                    </div>
                </div>
            </body>
        </html>
        """
        
        text_body = f"""
        Your {request_type} request for {space_name} has been {status_text}.
        
        Request details:
        - Workspace: {space_name}
        - Request type: {request_type}
        - Status: {status_text.title()}
        - Reviewed: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}
        {f'Note: {reviewer_note}' if reviewer_note else ''}
        """
        
        return self._send_email(to_email, subject, html_body, text_body)


# Singleton instance
email_service = EmailService()
