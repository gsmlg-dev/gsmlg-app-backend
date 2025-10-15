defmodule GsmlgAppAdmin.Accounts.User.Policies do
  @moduledoc "Policies for the user resource"
  use Spark.Dsl.Fragment, of: Ash.Resource, authorizers: [Ash.Policy.Authorizer]

  policies do
    # Bypass authentication checks for all AshAuthentication operations
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    # Allow user registration
    bypass action(:register_with_default) do
      authorize_if(always())
    end

    # Allow user sign in
    bypass action(:sign_in_with_default) do
      authorize_if(always())
    end

    policy action(:read) do
      authorize_if(expr(id == ^actor(:id)))
      authorize_if(expr(^actor(:is_admin) == true))
    end

    policy action(:update) do
      authorize_if(expr(id == ^actor(:id)))
      authorize_if(expr(^actor(:is_admin) == true))
    end

    policy action(:destroy) do
      authorize_if(expr(^actor(:is_admin) == true))
    end

    policy action(:create) do
      authorize_if(expr(^actor(:is_admin) == true))
    end

    policy action(:admin_create) do
      authorize_if(expr(^actor(:is_admin) == true))
    end
  end
end
