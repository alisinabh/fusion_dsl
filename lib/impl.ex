defmodule FusionDsl.Impl do
  @moduledoc """
  Implementation module for FusionDsl

  TODO: Add docs
  """

  @type env :: %FusionDsl.Runtime.Enviornment{}
  @type ast :: {atom(), Keyword.t(), List.t()}
  @type prog :: %FusionDsl.Processor.Program{}

  defmacro __using__(opts) do
    quote do
      import FusionDsl.Impl
      @behaviour FusionDsl.Impl
    end
  end

  @callback execute_ast(env, Tuple.t()) ::
              {:ok, term, env} | {:error, String.t()}
  @callback list_functions() :: List.t()

  def put_assign(env, key, value),
    do: %{env | assigns: Map.put(env.assigns, key, value)}

  def get_assign(env, key), do: Map.fetch(env.assigns, key)
end
