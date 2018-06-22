defmodule FusionDsl.Impl do
  @moduledoc """
  Implementation module for FusionDsl. This module helps with developing packages for fusion dsl.

  TODO: Add docs
  """

  alias FusionDsl.Runtime.Executor

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
  def list_functions(), do: [:foo, :bar]
  ```
  """
  @callback list_functions() :: [atom()]

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
    case Executor.execute_ast(arg, env) do
      {:ok, result, env} ->
        {:ok, result, env}

      {:error, msg} ->
        {:error, "argument execute resulted in an error: #{msg}"}
    end
  end

  @doc """
  Returns value of a variable in env
  """
  def get_var(prog, var, env) when is_binary(var) do
    case do_get_var(prog, nil, String.split(var, "."), env) do
      {:ok, acc, env} ->
        {:ok, acc, env}

      {:error, :not_initialized} ->
        {:error, :not_initialized}
    end
  end

  # Runs prep_arg on each argument in the list and returns the 
  # result in same order
  defp do_prep_args([h | t], env, acc) do
    case prep_arg(h, env) do
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
