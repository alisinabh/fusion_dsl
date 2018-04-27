defmodule IvroneDslTest do
  use ExUnit.Case
  doctest IvroneDsl

  @full_tokens_file "test/samples/full_tokens.ivr1"
  @scopes_file "test/samples/scopes.ivr1"

  @full_tokens_first_ln 7
  @full_tokens_last_ln 33

  #lines = IvroneDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)
  #IvroneDsl.Processor.AstProcessor.generate_ast(conf, lines)

  @correct_config %{
    db: "TestDb",
    format: "IVRONE1",
    name: "TestApp",
    sounds: "testsounddir",
    start_code: 7
  }

  test "lexical analyser works on all types of tokens" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
  end

  test "line splitter is correct on line numbers" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)

    lines = IvroneDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)

    assert is_list(lines)

    assert [@full_tokens_first_ln | _] = List.first(lines)
    assert [@full_tokens_last_ln | _] = List.last(lines)
  end

  test "AST generation does not give any errors on full_tokens" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
    lines = IvroneDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast} = IvroneDsl.Processor.AstProcessor.generate_ast(conf, lines)
  end

  test "no errors generated in different scope complexities" do
    file_data = File.read!(@scopes_file)
    assert {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
  end

  test "Headers are parsed correctly" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
    assert @correct_config = conf
  end
end
