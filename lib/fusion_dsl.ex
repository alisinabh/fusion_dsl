defmodule FusionDsl do
  @moduledoc """
  Fusion DSL main API.

  This module is a standard interface for the following.

   - Managing packages.
   - Compiling Fusion Code (Lexing, AstProccess).
   - Configuring runtime enviornment.
   - Code execution.
  """

  @typedoc """
  Keywords used in package configs

   - `:as`: Defines name of module to be used inside fusion scripts. `SnakeCase` prefferred.
   - `:name`: An atom unique name for package. (In case of multiple use of same package)
  """
  @type package_options :: {:as, String.t()} | {:name, atom()}

  @doc """
  Returns a list of configured packages in their original configuration format
  """
  @spec get_packages() :: [{atom(), [package_options]}]
  def get_packages() do
    [{FusionDsl.Kernel, []}] ++ Application.get_env(:fusion_dsl, :packages, [])
  end

  def test_ast_begin(filename \\ "test/samples/logical.fus") do
    {:ok, conf, tokens} =
      FusionDsl.Processor.Lexer.tokenize(File.read!(filename))

    lines = FusionDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)
    {:ok, ast_data} = FusionDsl.Processor.AstProcessor.generate_ast(conf, lines)

    {:ok, env} = FusionDsl.Runtime.Enviornment.prepare_env(ast_data.prog)
    FusionDsl.Runtime.Executor.execute(env)
  end
end
