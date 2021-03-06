defmodule ProcaWeb.Schema.UserTypes do
  use Absinthe.Schema.Notation
  alias ProcaWeb.Resolvers.Authorized
  alias ProcaWeb.Resolvers

  object :user_queries do
    field :current_user, non_null(:user) do
      middleware Authorized
      resolve(&Resolvers.User.current_user/3)
    end
  end

  object :user do
    field :id, non_null(:integer)
    field :email, non_null(:string)
    field :roles, non_null(list_of(non_null(:user_role)))
  end

  object :user_role do
    field :org, non_null(:org)
    field :role, non_null(:string)
  end

  object :user_mutations do
    field :add_org_user, type: :user do
      middleware Authorized, access: [:org, by: [name: :org_name]], can?: :change_org_settings
      arg :org_name, non_null(:string)
      arg :input, non_null(:user_input)
    end

    field :delete_org_user, type: :delete_user_result do
      arg :org_name, non_null(:string)
      arg :email, non_null(:string)
    end

    field :update_org_user, type: :user do
      middleware Authorized, access: [:org, by: [name: :org_name]], can?: :change_org_settings
      arg :org_name, non_null(:string)
      arg :input, non_null(:user_input)
    end
  end

  input_object :user_input do
    field :email, non_null(:string)
    field :roles, list_of(non_null(:string))
  end

  object :delete_user_result do
    field :status, non_null(:status)
  end

  object :update_user_result do
    field :id, non_null(:integer)
  end
end
