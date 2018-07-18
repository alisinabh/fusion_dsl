defmodule FusionDsl.Helpers.CodeReloader do
  @moduledoc """
  This module helps with reloading modules.

  Main purpose is reloading modules `FusionDsl.Processor.AstProcessor` and
  `FusionDsl.Processor.Lexer` after loading package dependencies.
  """

  @doc "Reloads a specific module."
  def reload_module(module) do
    do_r(module)
  end

  # do_r function from IEx.Helpers
  defp do_r(module) do
    unless Code.ensure_loaded?(module) do
      raise ArgumentError, "could not load nor find module: #{inspect(module)}"
    end

    source = source(module)

    cond do
      source == nil ->
        raise ArgumentError,
              "could not find source for module: #{inspect(module)}"

      not File.exists?(source) ->
        raise ArgumentError,
              "could not find source (#{source}) for module: #{inspect(module)}"

      true ->
        Enum.map(Code.load_file(source), fn {name, _} -> name end)
    end
  end

  defp source(module) do
    source = module.module_info(:compile)[:source]

    case source do
      nil -> nil
      source -> List.to_string(source)
    end
  end
end
