defmodule GsmlgAppAdminWeb.AshOverrides do
  @moduledoc """
  This is the default overrides for our component UI.

  The CSS styles are based on [TailwindCSS](https://tailwindcss.com/).
  """

  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.{Components, ResetLive, SignInLive}

  override SignInLive do
    set(:root_class, "grid h-screen place-items-center dark:bg-gray-900")
  end

  override ResetLive do
    set(:root_class, "grid h-screen place-items-center dark:bg-gray-900")
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
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white")
    set(:form_class, nil)
    set(:spacer_class, "py-1")
    set(:button_text, "Change Password")
    set(:disable_button_text, "Changing password ...")
  end

  override Components.SignIn do
    set(:root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24
    """)

    set(:strategy_class, "mx-auth w-full max-w-sm lg:w-96")

    set(:authentication_error_container_class, "text-black dark:text-white text-center")
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
    set(:text_class, "text-4xl tracking-tight font-bold text-gray-900 dark:text-white")
    set(:text, "GSMLG APP Admin")
  end

  override Components.HorizontalRule do
    set(:root_class, "relative my-2")
    set(:hr_outer_class, "absolute inset-0 flex items-center")
    set(:hr_inner_class, "w-full border-t border-gray-300 dark:border-gray-700")
    set(:text_outer_class, "relative flex justify-center text-sm")

    set(
      :text_inner_class,
      "px-2 bg-white text-gray-400 font-medium dark:bg-gray-900 dark:text-gray-500"
    )

    set(:text, "or")
  end

  override Components.MagicLink do
    set(:root_class, "mt-4 mb-4")
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white")
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
    set(:toggler_class, "flex-none text-blue-500 hover:text-blue-600 px-2 first:pl-0 last:pr-0")
    set(:sign_in_toggle_text, "Already have an account?")
    set(:register_toggle_text, "Need an account?")
    set(:reset_toggle_text, "Forgot your password?")
    set(:show_first, :sign_in)
    set(:hide_class, "hidden")
  end

  override Components.Password.SignInForm do
    set(:root_class, nil)
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white")
    set(:form_class, nil)
    set(:slot_class, "my-4")
    set(:button_text, "Sign In")
    set(:disable_button_text, "Signing in ...")
  end

  override Components.Password.RegisterForm do
    set(:root_class, nil)
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white")
    set(:form_class, nil)
    set(:slot_class, "my-4")
    set(:button_text, "Register")
    set(:disable_button_text, "Registering ...")
  end

  override Components.Password.ResetForm do
    set(:root_class, nil)
    set(:label_class, "mt-2 mb-4 text-2xl tracking-tight font-bold text-gray-900 dark:text-white")
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
    set(:field_class, "mt-2 mb-2 dark:text-white")
    set(:label_class, "block text-sm font-medium text-gray-700 mb-1 dark:text-white")

    set(:input_class, """
    appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md
    shadow-sm placeholder-gray-400 focus:outline-none focus:ring-blue-pale-500
    focus:border-blue-pale-500 sm:text-sm dark:bg-gray-800 dark:text-white dark:border-gray-600
    dark:placeholder-gray-400
    """)

    set(:input_class_with_error, """
    appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md
    shadow-sm placeholder-gray-400 focus:outline-none border-red-400 sm:text-sm
    dark:bg-gray-800 dark:text-white dark:border-red-600 dark:placeholder-gray-400
    """)

    set(:submit_class, """
    btn btn-primary w-full mt-4 mb-4 text-white
    """)

    set(:error_ul, "text-red-400 font-light my-3 italic text-sm")
    set(:error_li, nil)
    set(:input_debounce, 350)
  end

  override Components.OAuth2 do
    set(:root_class, "w-full mt-2 mb-4")

    set(:link_class, """
    btn btn-outline w-full inline-flex items-center justify-center dark:border-gray-600 dark:text-white dark:hover:bg-gray-800
    """)

    set(:icon_class, "-ml-0.4 mr-2 h-4 w-4")
  end
end
