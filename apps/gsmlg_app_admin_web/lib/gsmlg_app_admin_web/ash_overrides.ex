defmodule GsmlgAppAdminWeb.AshOverrides do
  @moduledoc """
  This is the default overrides for our component UI.

  The CSS styles are based on [TailwindCSS](https://tailwindcss.com/).
  """

  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.{Components, ResetLive, SignInLive}

  override SignInLive do
    set(:root_class, "grid min-h-screen place-items-center bg-surface text-on-surface px-4 py-10")
  end

  override ResetLive do
    set(:root_class, "grid min-h-screen place-items-center bg-surface text-on-surface px-4 py-10")
  end

  override Components.Reset do
    set(:root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24
    """)

    set(:strategy_class, "mx-auth w-full max-w-sm lg:w-96")
  end

  override Components.Reset.Form do
    set(:root_class, nil)
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-on-surface")
    set(:form_class, nil)
    set(:spacer_class, "py-1")
    set(:button_text, "Change Password")
    set(:disable_button_text, "Changing password ...")
  end

  override Components.SignIn do
    set(:root_class, """
    w-full flex flex-col justify-center
    """)

    set(:strategy_class, """
    mx-auth w-full max-w-md rounded-2xl border border-outline-variant
    bg-surface-container p-6 shadow-lg
    """)

    set(:authentication_error_container_class, "text-error text-center")
    set(:authentication_error_text_class, "")
  end

  override Components.Banner do
    set(:root_class, "w-full flex justify-center py-2")
    set(:href_class, nil)
    set(:href_url, "/")
    set(:image_class, "block dark:hidden")
    set(:dark_image_class, "hidden dark:block")
    set(:image_url, nil)
    set(:dark_image_url, nil)
    set(:text_class, "text-3xl tracking-tight font-bold text-on-surface")
    set(:text, "GSMLG Admin")
  end

  override Components.HorizontalRule do
    set(:root_class, "relative my-2")
    set(:hr_outer_class, "absolute inset-0 flex items-center")
    set(:hr_inner_class, "w-full border-t border-outline-variant")
    set(:text_outer_class, "relative flex justify-center text-sm")

    set(
      :text_inner_class,
      "px-2 bg-surface-container text-on-surface-variant font-medium"
    )

    set(:text, "or")
  end

  override Components.MagicLink do
    set(:root_class, "mt-4 mb-4")
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-on-surface")
    set(:form_class, nil)

    set(
      :request_flash_text,
      "If this user exists in our database you will contacted with a sign-in link shortly."
    )

    set(:button_text, "Request Magic Link")
    set(:disable_button_text, "Requesting ...")
  end

  override Components.Password do
    set(:root_class, "mt-4 mb-4")
    set(:interstitial_class, "flex flex-row justify-between content-between text-sm font-medium")
    set(:toggler_class, "flex-none text-primary hover:text-secondary px-2 first:pl-0 last:pr-0")
    set(:sign_in_toggle_text, "Already have an account?")
    set(:register_toggle_text, "Need an account?")
    set(:reset_toggle_text, "Forgot your password?")
    set(:show_first, :sign_in)
    set(:hide_class, "hidden")
  end

  override Components.Password.SignInForm do
    set(:root_class, nil)
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-on-surface")
    set(:form_class, nil)
    set(:slot_class, "my-4")
    set(:button_text, "Sign In")
    set(:disable_button_text, "Signing in ...")
  end

  override Components.Password.RegisterForm do
    set(:root_class, nil)
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-on-surface")
    set(:form_class, nil)
    set(:slot_class, "my-4")
    set(:button_text, "Register")
    set(:disable_button_text, "Registering ...")
  end

  override Components.Password.ResetForm do
    set(:root_class, nil)
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-on-surface")
    set(:form_class, nil)
    set(:slot_class, "my-4")

    set(
      :reset_flash_text,
      "If this user exists in our system, you will be contacted with reset instructions shortly."
    )

    set(:button_text, "Reset Password")
    set(:disable_button_text, "Requesting ...")
  end

  override Components.Password.Input do
    set(:field_class, "mt-2 mb-2")
    set(:label_class, "block text-sm font-medium text-on-surface mb-1")

    set(:input_class, """
    input w-full bg-surface text-on-surface border border-outline
    placeholder:text-on-surface-variant focus:outline-none focus:border-primary sm:text-sm
    """)

    set(:input_class_with_error, """
    input w-full bg-surface text-on-surface border border-error
    placeholder:text-on-surface-variant focus:outline-none focus:border-error sm:text-sm
    """)

    set(:submit_class, """
    btn btn-primary w-full mt-4 mb-4
    """)

    set(:identity_input_label, "Email")
    set(:identity_input_placeholder, "admin@example.com")
    set(:password_input_label, "Password")
    set(:password_confirmation_input_label, "Password confirmation")
    set(:remember_me_input_label, "Remember me")
    set(:remember_me_class, "flex items-center gap-2 mt-2 mb-2")
    set(:checkbox_class, "checkbox checkbox-primary")
    set(:checkbox_label_class, "text-sm font-medium text-on-surface")
    set(:error_ul, "text-error font-light my-3 italic text-sm")
    set(:error_li, nil)
    set(:input_debounce, 350)
  end

  override Components.OAuth2 do
    set(:root_class, "w-full mt-2 mb-4")

    set(:link_class, """
    btn btn-outline w-full inline-flex items-center justify-center
    """)

    set(:icon_class, "-ml-0.4 mr-2 h-4 w-4")
  end
end
