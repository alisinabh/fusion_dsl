defmodule IvroneDsl do
  @moduledoc """
  Documentation for IvroneDsl.
  """

  def test_ast_begin do
    {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(File.read!("test/samples/full_tokens.ivr1"))
    lines = IvroneDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)
    IvroneDsl.Processor.AstProcessor.generate_ast(conf, lines)
  end
end
