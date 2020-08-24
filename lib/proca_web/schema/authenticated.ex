defmodule ProcaWeb.Schema.Authenticated do
  @behaviour Absinthe.Middleware

  import Logger

  def call(resolution, opts) do
    case resolution.context do
      %{user: user} ->
        resolution
      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "unauthenticated"})
    end
  end
end
