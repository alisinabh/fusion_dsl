defmodule FusionDsl.Impl do
  @moduledoc """
  Implementation module for FusionDsl

  TODO: Add docs
  """

  alias FusionDsl.Runtime.Executor

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

  @doc "Puts a key in env assigns"
  def put_assign(env, key, value),
    do: %{env | assigns: Map.put(env.assigns, key, value)}

  @doc """
  Gets the value of an assign with given key, 
  `:error` in case of unset key
  """
  def get_assign(env, key), do: Map.fetch(env.assigns, key)

  @doc """
  Ensures that all asts in arguments (such as functions values in args)
  are converted to terms (raw values)

  For example an argument list may look like: args=`[1, {:rand, [ln: 2], [5, 10]}]`

  When called with prep_args(args, env) the output of prep_args will be:

  ```
  {:ok, [1, 6], env}
  ```

  ## Parameters
  - args: list of arguments or just one argument
  - env: the Environment struct
  """
  def prep_arg(args, env) when is_list(args) do
    do_prep_args(args, env, [])
  end

  def prep_arg(arg, env) do
    Executor.execute_ast(env.prog, arg, env)
  end

  @doc """
  Raises an exception and stops the flow of script
  """
  def error(_env, ctx, message) do
    raise("#{ctx[:package]} error\n Line: #{ctx[:ln]}\n#{message}")
  end

  defp do_prep_args([h | t], env, acc) do
    {:ok, res, env} = prep_arg(h, env)
    do_prep_args(t, env, [res | acc])
  end

  defp do_prep_args([], env, acc), do: {:ok, Enum.reverse(acc), env}
end
