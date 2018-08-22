defmodule FusionDsl do
  @moduledoc """
  Fusion DSL main API.

  This module is a standard interface for the following.

   - Managing packages.
   - Compiling Fusion Code (Lexing, AstProccess).
   - Configuring runtime enviornment.
   - Code execution.
  """
  require FusionDsl.Kernel
  require FusionDsl.Logger
  require Logger

  alias FusionDsl.Kernel
  alias FusionDsl.Processor.Lexer
  alias FusionDsl.Processor.AstProcessor
  alias FusionDsl.Runtime.Environment
  alias FusionDsl.Runtime.Executor
  alias FusionDsl.NativeImpl
  alias FusionDsl.Helpers.CodeReloader

  @predefined_packages Application.get_env(:fusion_dsl, :predefined_packages, [
                         {Kernel, []},
                         {FusionDsl.Logger, []}
                       ])

  @typedoc """
  Keywords used in package configs

   - `:as`: Defines name of module to be used inside fusion scripts. `SnakeCase` prefferred.
   - `:name`: An atom unique name for package. (In case of multiple use of same package)
  """
  @type package_options :: {:as, String.t()} | {:name, atom()}

  def start(_type, _args) do
    :timer.sleep(100)

    CodeReloader.reload_module(FusionDsl.Processor.Lexer)
    CodeReloader.reload_module(FusionDsl.Processor.AstProcessor)

    {:ok, self()}
  end

  @doc """
  Returns a list of configured packages in their original configuration format
  """
  @spec get_packages :: [{atom(), [package_options]}]
  def get_packages do
    raw_packages = Application.get_env(:fusion_dsl, :packages, [])
    packages = NativeImpl.create_native_packages(raw_packages)
    all_packages = @predefined_packages ++ packages

    # Remove all unavailable packages
    Enum.reduce(all_packages, [], fn {mod, _} = pack, acc ->
      # Ensures that module is loaded
      Code.ensure_loaded(mod)

      if function_exported?(mod, :__list_fusion_functions__, 0) do
        # Adds the package if package module exists
        acc ++ [pack]
      else
        Logger.warn("Fusion package missing #{mod} (Ignore this on compile!)")
        acc
      end
    end)
  end

  @doc """
  Compiles a fusion code and returns the base environment 
  for code execution. This environment struct contains `:prog`
  data and basic default environment data.
  """
  @spec compile(String.t()) :: {:ok, Environment.t()}
  def compile(code) do
    {:ok, conf, tokens} = Lexer.tokenize(code)

    lines = Lexer.split_by_lines(tokens, conf.start_code)
    {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    Environment.prepare_env(ast_data)
  end

  @doc """
  Reads a file with fusion code and compiles it.
  """
  @spec compile_file(String.t()) :: {:ok, Environment.t()}
  def compile_file(filename) do
    filename
    |> File.read!()
    |> compile()
  end

  @doc """
  Executes and environment with the given procedure (default is `:main`)

  Returns the environment in case of success.
  """
  @spec execute(Environment.t()) :: {:end, Environment.t()}
  def execute(env, proc \\ :main) do
    Executor.execute(env, proc)
  end
end
