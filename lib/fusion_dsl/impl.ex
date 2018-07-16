defmodule FusionDsl.Impl do
  @moduledoc """
  Implementation module for FusionDsl. This module helps with developing packages for fusion dsl.

  Read [packages](packages.html) docs for more info.
  """

  alias FusionDsl.Runtime.Executor
  alias FusionDsl.Runtime.Environment

  defmacro __using__(_opts) do
    quote do
      import FusionDsl.Impl
      @behaviour FusionDsl.Impl
    end
  end

  @doc """
  Should return list of function names this package provides as atoms.

  ## Example
  ```elixir
  @impl true
  def __list_fusion_functions__, do: [:foo, :bar]
  ```
  """
  @callback __list_fusion_functions__() :: [atom()]

  @doc """
  Puts or updates value of a key of assigns in environment.

  Every package in Fusion can have their assigns in the runtime environment
  of script (Somehow like assigns in plug). 

  The assigns are not accessible directly by fusion code and is meant for
  packages to hold any elixir data type in them.

  ## Keys

  Keys of assigns are recommended to be atoms which start with projects short
  otp name. e.g. `:fusion_dsl_assgn1`

  ## Values

  Values of the assigns can be any elixir data type. But putting large amounts
  of data into assigns is **not** recommended.

  ## Examples

  ```elixir
  # Put some value into environment assigns
  env = FusionDsl.Impl.put_assign(env, :fusion_dsl_engine_state, :rocks)
  %Environment{...}

  # Get that value from environment assigns
  FusionDsl.Impl.get_assign(env, :fusion_dsl_engine_state)
  {:ok, :rocks}
  ```
  """
  @spec put_assign(Environment.t(), atom() | String.t(), any()) ::
          Environment.t()
  def put_assign(env, key, value),
    do: %{env | assigns: Map.put(env.assigns, key, value)}

  @doc """
  Gets the value of an assign with given key, 
  `:error` in case of unset key
  """
  @spec get_assign(Environment.t(), atom() | String.t()) ::
          {:ok, any()} | :error
  def get_assign(env, key), do: Map.fetch(env.assigns, key)

  @doc """
  Ensures that all asts in arguments (such as functions values in args)
  are converted to terms (raw values)

  For example an argument list may look like: args=`[1, {:rand, [ln: 2], [5, 10]}]`

  When called with prep_arg(env, args) the output of prep_args will be:

  ```
  {:ok, [1, 6], env}
  ```

  ## Parameters
  - args: list of arguments or just one argument
  - env: the Environment struct
  """
  @spec prep_arg(Environment.t(), list() | any()) ::
          {:ok, list() | any(), Environment.t()}
  def prep_arg(%Environment{} = env, args) when is_list(args) do
    do_prep_args(args, env, [])
  end

  def prep_arg(%Environment{} = env, arg) do
    case Executor.execute_ast(arg, env) do
      {:ok, result, env} ->
        {:ok, result, env}

      {:error, msg} ->
        {:error, "argument execute resulted in an error: #{msg}"}
    end
  end

  @doc """
  Returns value of a variable in environment
  """
  @spec get_var(Environment.t(), String.t()) :: {:ok, any(), Environment.t()}
  def get_var(env, var) when is_binary(var) do
    case do_get_var(env.prog, nil, String.split(var, "."), env) do
      {:ok, acc, env} ->
        {:ok, acc, env}

      {:error, :not_initialized} ->
        {:error, :not_initialized}
    end
  end

  # Runs prep_arg on each argument in the list and returns the
  # result in same order
  defp do_prep_args([h | t], env, acc) do
    case prep_arg(env, h) do
      {:ok, res, env} ->
        do_prep_args(t, env, [res | acc])

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp do_prep_args([], env, acc), do: {:ok, Enum.reverse(acc), env}

  defp do_get_var(prog, nil, [var | t], env) do
    case Map.fetch(env.vars, var) do
      :error ->
        {:error, :not_initialized}

      {:ok, v} ->
        do_get_var(prog, v, t, env)
    end
  end

  defp do_get_var(prog, acc, [var | t], env) when is_map(acc) do
    case Map.fetch(acc, var) do
      :error ->
        {:error, :not_initialized}

      {:ok, v} ->
        do_get_var(prog, v, t, env)
    end
  end

  defp do_get_var(_prog, acc, [], env) do
    {:ok, acc, env}
  end
end
