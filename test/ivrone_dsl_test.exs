defmodule IvroneDslTest do
  use ExUnit.Case
  doctest IvroneDsl

  @full_tokens_file "test/samples/full_tokens.ivr1"
  @scopes_file "test/samples/scopes.ivr1"
  @logical_file "test/samples/logical.ivr1"

  @full_tokens_first_ln 6
  @full_tokens_last_ln 37

  @correct_config %{
    db: "TestDb",
    format: "IVRONE1",
    name: "TestApp",
    sounds: "testsounddir",
    start_code: 6
  }
  @correct_logic_result "Start: add1 11,3,28,1.75,3,4,4,11,false,true,true,false,true,false,true,true,if,6 1,-7,-12,-0.75,-3,-2.6666666666666665,-3,11,false,false,false,false,true,true,false,false,else,11 end"

  test "lexical analyser works on all types of tokens" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, _conf, _tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
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
    assert {:ok, _ast} = IvroneDsl.Processor.AstProcessor.generate_ast(conf, lines)
  end

  test "no errors generated in different scope complexities" do
    file_data = File.read!(@scopes_file)
    assert {:ok, _conf, _tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
  end

  test "Headers are parsed correctly" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, _tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
    assert @correct_config = conf
  end

  test "Logics test produce expected result" do
    file_data = File.read!(@logical_file)
    assert {:ok, conf, tokens} = IvroneDsl.Processor.Lexer.tokenize(file_data)
    lines = IvroneDsl.Processor.Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = IvroneDsl.Processor.AstProcessor.generate_ast(conf, lines)

    {:ok, env} = IvroneDsl.Runtime.Enviornment.prepare_env()
    {:end, env} = IvroneDsl.Runtime.Executor.execute(ast_data.prog, env)
    assert %{vars: %{"result" => @correct_logic_result}}
  end
end
