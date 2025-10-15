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

    use Phoenix.View,
      root: "lib/gsmlg_app_web/templates",
      namespace: GsmlgAppWeb

    import Swoosh.Email

    def welcome(user) do
      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Welcome to GSMLG Platform!")
      |> html_body(render("user_email/welcome.html", user: user))
      |> text_body(render("user_email/welcome.txt", user: user))
    end

    def email_verification(user, token) do
      verification_url = "#{base_url()}/verify-email?token=#{token}"

      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Verify your email address")
      |> html_body(
        render("user_email/email_verification.html",
          user: user,
          verification_url: verification_url
        )
      )
      |> text_body(
        render("user_email/email_verification.txt",
          user: user,
          verification_url: verification_url
        )
      )
    end

    def password_reset(user, token) do
      reset_url = "#{base_url()}/reset-password?token=#{token}"

      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Reset your password")
      |> html_body(render("user_email/password_reset.html", user: user, reset_url: reset_url))
      |> text_body(render("user_email/password_reset.txt", user: user, reset_url: reset_url))
    end

    def account_suspended(user) do
      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Your account has been suspended")
      |> html_body(render("user_email/account_suspended.html", user: user))
      |> text_body(render("user_email/account_suspended.txt", user: user))
    end

    def account_activated(user) do
      new()
      |> to({user.display_name || user.email, user.email})
      |> from({"GSMLG Platform", "noreply@gsmlg.com"})
      |> subject("Your account has been activated")
      |> html_body(render("user_email/account_activated.html", user: user))
      |> text_body(render("user_email/account_activated.txt", user: user))
    end

    defp base_url do
      Application.get_env(:gsmlg_app, :base_url, "http://localhost:4152")
    end
  end
end
