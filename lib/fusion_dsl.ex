defmodule FusionDsl do
  @moduledoc """
  Fusion DSL main API.

  This module is a standard interface for the following.

   - Managing packages.
   - Compiling Fusion Code (Lexing, AstProccess).
   - Configuring runtime enviornment.
   - Code execution.
  """

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
      if function_exported?(mod, :__info__, 1) do
        acc ++ [pack]
      else
        acc
      end
    end)
  end

  def test_ast_begin(filename \\ "logtest.fus") do
    {:ok, conf, tokens} = Lexer.tokenize(File.read!(filename))

    lines = Lexer.split_by_lines(tokens, conf.start_code)
    {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Environment.prepare_env(ast_data)
    Executor.execute(env)
  end
end
