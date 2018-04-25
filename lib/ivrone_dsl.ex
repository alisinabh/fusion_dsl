defmodule IvroneDsl do
  @moduledoc """
  Documentation for IvroneDsl.
  """

  @doc """
  Hello world.

  ## Examples

      iex> IvroneDsl.hello
      :world

  """
  def hello do
    {:ok, config, tokens} = IvroneDsl.Processor.Lexer.tokenize(File.read!("begin.ivr"))
    sp = IvroneDsl.Processor.Lexer.split_by_lines(tokens)
    IvroneDsl.Processor.AstProcessor.generate_ast(config, sp)
  end

  def test_ast_begin do
    {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize File.read!("begin.ivr")
    lines = IvroneDsl.Processor.Lexer.split_by_lines tokens
    IvroneDsl.Processor.AstProcessor.generate_ast conf, lines
  end
end
