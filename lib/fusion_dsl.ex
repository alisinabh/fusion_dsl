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

  @typedoc """
  Keywords used in package configs

   - `:as`: Defines name of module to be used inside fusion scripts. `SnakeCase` prefferred.
   - `:name`: An atom unique name for package. (In case of multiple use of same package)
  """
  @type package_options :: {:as, String.t()} | {:name, atom()}

  @doc """
  Returns a list of configured packages in their original configuration format
  """
  @spec get_packages :: [{atom(), [package_options]}]
  def get_packages do
    raw_packages = Application.get_env(:fusion_dsl, :packages, [])
    packages = FusionDsl.NativeImpl.create_native_packages(raw_packages)
    [{Kernel, []}] ++ packages
  end

  def test_ast_begin(filename \\ "test/samples/logical.fus") do
    {:ok, conf, tokens} = Lexer.tokenize(File.read!(filename))

    lines = Lexer.split_by_lines(tokens, conf.start_code)
    {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Environment.prepare_env(ast_data.prog)
    Executor.execute(env)
  end
end
