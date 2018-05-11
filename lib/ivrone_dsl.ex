defmodule FusionDsl do
  @moduledoc """
  Documentation for FusionDsl.
  """

  def test_ast_begin(filename \\ "test/samples/arrays.ivr1") do
    {:ok, conf, tokens} =
      FusionDsl.Processor.Lexer.tokenize(File.read!(filename))

    lines = FusionDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)
    {:ok, ast_data} = FusionDsl.Processor.AstProcessor.generate_ast(conf, lines)

    {:ok, env} = FusionDsl.Runtime.Enviornment.prepare_env()
    FusionDsl.Runtime.Executor.execute(ast_data.prog, env)
  end
end
