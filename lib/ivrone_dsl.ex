defmodule IvroneDsl do
  @moduledoc """
  Documentation for IvroneDsl.
  """

  def test_ast_begin do
    {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(File.read!("begin.ivr"))

    lines = IvroneDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)
    {:ok, ast_data} = IvroneDsl.Processor.AstProcessor.generate_ast(conf, lines)

    {:ok, env} = IvroneDsl.Runtime.Enviornment.prepare_env
    IvroneDsl.Runtime.Executor.execute(ast_data.prog, env)
  end
end
