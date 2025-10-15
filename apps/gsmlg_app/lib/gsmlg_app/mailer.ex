defmodule GsmlgApp.Mailer do
  @moduledoc """
  Mailer for sending emails to users.
  """

  use Swoosh.Mailer, otp_app: :gsmlg_app

  # Email templates
  defmodule UserEmail do
    @moduledoc """
    User-related email templates.
    """

    import Swoosh.Email

    def welcome(user) do
      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Welcome to GSMLG Platform!")
      |> html_body(welcome_html(user))
      |> text_body(welcome_text(user))
    end

    def email_verification(user, token) do
      verification_url = "#{base_url()}/verify-email?token=#{token}"

      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Verify your email address")
      |> html_body(email_verification_html(user, verification_url))
      |> text_body(email_verification_text(user, verification_url))
    end

    def password_reset(user, token) do
      reset_url = "#{base_url()}/reset-password?token=#{token}"

      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Reset your password")
      |> html_body(password_reset_html(user, reset_url))
      |> text_body(password_reset_text(user, reset_url))
    end

    def account_suspended(user) do
      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Your account has been suspended")
      |> html_body(account_suspended_html(user))
      |> text_body(account_suspended_text(user))
    end

    def account_activated(user) do
      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Your account has been activated")
      |> html_body(account_activated_html(user))
      |> text_body(account_activated_text(user))
    end

    defp base_url do
      Application.get_env(:gsmlg_app, :base_url, "http://localhost:4152")
    end

    # Email template functions
    defp welcome_html(user) do
      """
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="utf-8">
          <title>Welcome to GSMLG Platform</title>
      </head>
      <body>
          <h1>Welcome to GSMLG Platform!</h1>
          <p>Hello #{user.display_name || user.first_name || user.email},</p>
          <p>Welcome to GSMLG Platform! We're excited to have you on board.</p>
          <p>Your account has been successfully created with the email: <strong>#{user.email}</strong></p>
          <p>Best regards,<br>The GSMLG Platform Team</p>
      </body>
      </html>
      """
    end

    defp welcome_text(user) do
      """
      Welcome to GSMLG Platform!

      Hello #{user.display_name || user.first_name || user.email},

      Welcome to GSMLG Platform! We're excited to have you on board.

      Your account has been successfully created with the email: #{user.email}

      Best regards,
      The GSMLG Platform Team
      """
    end

    defp email_verification_html(user, verification_url) do
      """
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="utf-8">
          <title>Verify Your Email Address</title>
      </head>
      <body>
          <h1>Verify Your Email Address</h1>
          <p>Hello #{user.display_name || user.first_name || user.email},</p>
          <p>Please verify your email address by clicking the link below:</p>
          <p><a href="#{verification_url}">Verify Email Address</a></p>
          <p>If the button doesn't work, you can also copy and paste this link into your browser:</p>
          <p>#{verification_url}</p>
          <p>This link will expire in 24 hours for security reasons.</p>
      </body>
      </html>
      """
    end

    defp email_verification_text(user, verification_url) do
      """
      Verify Your Email Address

      Hello #{user.display_name || user.first_name || user.email},

      Please verify your email address by clicking the link below:

      #{verification_url}

      This link will expire in 24 hours for security reasons.
      """
    end

    defp password_reset_html(user, reset_url) do
      """
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="utf-8">
          <title>Reset Your Password</title>
      </head>
      <body>
          <h1>Reset Your Password</h1>
          <p>Hello #{user.display_name || user.first_name || user.email},</p>
          <p>Please reset your password by clicking the link below:</p>
          <p><a href="#{reset_url}">Reset Password</a></p>
      </body>
      </html>
      """
    end

    defp password_reset_text(user, reset_url) do
      """
      Reset Your Password

      Hello #{user.display_name || user.first_name || user.email},

      Please reset your password by clicking the link below:

      #{reset_url}
      """
    end

    defp account_suspended_html(user) do
      """
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="utf-8">
          <title>Your account has been suspended</title>
      </head>
      <body>
          <h1>Your account has been suspended</h1>
          <p>Hello #{user.display_name || user.first_name || user.email},</p>
          <p>Your account has been suspended. Please contact support for more information.</p>
      </body>
      </html>
      """
    end

    defp account_suspended_text(user) do
      """
      Your account has been suspended

      Hello #{user.display_name || user.first_name || user.email},

      Your account has been suspended. Please contact support for more information.
      """
    end

    defp account_activated_html(user) do
      """
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="utf-8">
          <title>Your account has been activated</title>
      </head>
      <body>
          <h1>Your account has been activated</h1>
          <p>Hello #{user.display_name || user.first_name || user.email},</p>
          <p>Your account has been successfully activated!</p>
      </body>
      </html>
      """
    end

    defp account_activated_text(user) do
      """
      Your account has been activated

      Hello #{user.display_name || user.first_name || user.email},

      Your account has been successfully activated!
      """
    end
  end

  # Email delivery functions
  @doc """
  Deliver welcome email to a new user.
  """
  def deliver_welcome_email(user) do
    user
    |> UserEmail.welcome()
    |> deliver()
  end

  @doc """
  Deliver email verification email with token.
  """
  def deliver_email_verification(user, token) do
    user
    |> UserEmail.email_verification(token)
    |> deliver()
  end

  @doc """
  Deliver password reset email with token.
  """
  def deliver_password_reset(user, token) do
    user
    |> UserEmail.password_reset(token)
    |> deliver()
  end

  @doc """
  Deliver account suspension notification.
  """
  def deliver_account_suspended(user) do
    user
    |> UserEmail.account_suspended()
    |> deliver()
  end

  @doc """
  Deliver account activation notification.
  """
  def deliver_account_activated(user) do
    user
    |> UserEmail.account_activated()
    |> deliver()
  end
end
