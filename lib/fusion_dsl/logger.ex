defmodule FusionDsl.Logger do
  @moduledoc """
  Logger package for fusion dsl.

  The Logger package can be used in 
  """

  use FusionDsl.Impl

  require Logger

  alias FusionDsl.Runtime.Environment

  @functions [:debug, :info, :warn, :error]
  @loggers Application.get_env(:fusion_dsl, :logger_module, [Logger])

  @impl true
  def __list_fusion_functions__, do: @functions

  @doc """
  Writes to defined logger module as `:debug`
  """
  def debug({:debug, _ctx, [_]} = ast, env) do
    log(ast, env)
  end

  @doc """
  Writes to defined logger module as `:info`
  """
  def info({:info, _ctx, [_]} = ast, env) do
    log(ast, env)
  end

  @doc """
  Writes to defined logger module as `:warn`
  """
  def warn({:warn, _ctx, [_]} = ast, env) do
    log(ast, env)
  end

  @doc """
  Writes to defined logger module as `:error`
  """
  def error({:error, _ctx, [_]} = ast, env) do
    log(ast, env)
  end

  defp log({type, ctx, args}, env) do
    {:ok, [log_str], env} = prep_arg(env, args)

    prog_info = Environment.get_info(env, :small)

    full_log =
      "#{to_string(type)} line #{ctx[:ln]} package:#{prog_info}\n" <>
        to_string(log_str)

    Enum.each(@loggers, fn logger ->
      if logger == Elixir.Logger do
        Logger.log(type, full_log)
      else
        logger.log(type, full_log)
      end
    end)

    {:ok, nil, env}
  end
end
