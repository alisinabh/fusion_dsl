defmodule IvroneDslTest do
  use ExUnit.Case
  doctest IvroneDsl

  @full_tokens_file "test/samples/full_tokens.ivr1"
  @scopes_file "test/samples/scopes.ivr1"

  @correct_config %{
    db: "TestDb",
    format: "IVRONE1",
    name: "TestApp",
    sounds: "testsounddir",
    start_code: 6
  }

  test "lexical analyser works on all types of tokens" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
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
