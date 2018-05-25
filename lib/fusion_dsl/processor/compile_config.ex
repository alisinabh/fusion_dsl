defmodule FusionDsl.Processor.CompileConfig do
  @moduledoc """
  Compile time configuration struct and helpers
  """

  alias FusionDsl.Processor.Program

  defstruct imports: %{"Kernel" => true},
            proc: nil,
            headers: %{},
            proc: nil,
            ln: 0,
            prog: %Program{},
            end_asts: [],
            clauses: [],
            start_code: -1

  @doc "Initiates a config struct"
  def init, do: %__MODULE__{}

  @doc """
  Analyses and Processes a header, adds neccessary data into CompileConfig
  """
  def process_header(config, :import, value) do
    packages = String.split(value, ",")

    process_imports(config, packages)
  end

  def process_header(config, key, value),
    do: %{config | headers: Map.put(config.headers, key, value)}

  @doc "Sets the `start_code` in config to finished line number of headers"
  def set_start_code(config, line_number) do
    %{config | start_code: line_number}
  end

  defp process_imports(config, [package | t]) do
    process_imports(
      Map.put(
        config,
        :imports,
        Map.put(config.imports, String.trim(package), true)
      ),
      t
    )
  end

  defp process_imports(config, []), do: config
end
