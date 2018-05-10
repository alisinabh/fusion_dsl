defmodule IvroneDslTest do
  use ExUnit.Case
  doctest IvroneDsl

  alias IvroneDsl.Processor.Lexer
  alias IvroneDsl.Processor.AstProcessor
  alias IvroneDsl.Runtime.Enviornment
  alias IvroneDsl.Runtime.Executor

  @full_tokens_file "test/samples/full_tokens.ivr1"
  @scopes_file "test/samples/scopes.ivr1"
  @logical_file "test/samples/logical.ivr1"
  @coditional_file "test/samples/conditional.ivr1"
  @strings_file "test/samples/strings.ivr1"
  @arrays_file "test/samples/arrays.ivr1"
  @regex_file "test/samples/regex.ivr1"

  @full_tokens_first_ln 6
  @full_tokens_last_ln 37

  @correct_config %{
    db: "TestDb",
    format: "IVRONE1",
    name: "TestApp",
    sounds: "testsounddir",
    start_code: 6
  }
  @correct_logic_result "Start: add1 11,3,28,1.75,3,4.0,4,11,false,true,true,false,true,false,true,true,if,6 1,-7,-12,-0.75,-3,-2.6666666666666665,-3,11,false,false,false,false,true,true,false,false,else,11 end"
  @correct_conditinal_result "start 1,1,1,1,1,1,1,end"
  @correct_strings_trues 14
  @correct_arrays_trues 15
  @correct_regex_trues 4

  test "lexer lang-id order is correct" do
    [id | t] = Lexer.get_lang_ids()
    assert ensure_desc(t, String.length(id)) == :ok
  end

  defp ensure_desc([h | t], cur_len) do
    assert String.length(h) <= cur_len
    ensure_desc(t, String.length(h))
  end

  defp ensure_desc([], _) do
    :ok
  end

  test "lexical analyser works on all types of tokens" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, _conf, _tokens} = Lexer.tokenize(file_data)
  end

  test "line splitter is correct on line numbers" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)

    lines = Lexer.split_by_lines(tokens, conf.start_code)

    assert is_list(lines)

    assert [@full_tokens_first_ln | _] = List.first(lines)
    assert [@full_tokens_last_ln | _] = List.last(lines)
  end

  test "AST generation does not give any errors on full_tokens" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, _ast} = AstProcessor.generate_ast(conf, lines)
  end

  test "no errors generated in different scope complexities" do
    file_data = File.read!(@scopes_file)
    assert {:ok, _conf, _tokens} = Lexer.tokenize(file_data)
  end

  test "Headers are parsed correctly" do
    file_data = File.read!(@full_tokens_file)
    assert {:ok, conf, _tokens} = Lexer.tokenize(file_data)
    assert @correct_config = conf
  end

  test "Logics test produces expected result" do
    file_data = File.read!(@logical_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Enviornment.prepare_env()
    {:end, env} = Executor.execute(ast_data.prog, env)
    assert env.vars["result"] == @correct_logic_result
  end

  test "Conditional test produces expected result" do
    file_data = File.read!(@coditional_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Enviornment.prepare_env()
    {:end, env} = Executor.execute(ast_data.prog, env)
    assert env.vars["result"] == @correct_conditinal_result
  end

  test "String operations work as expected" do
    file_data = File.read!(@strings_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Enviornment.prepare_env()
    {:end, env} = Executor.execute(ast_data.prog, env)
    result = env.vars["result"]

    correct =
      Enum.reduce(1..@correct_strings_trues, "", fn _x, acc ->
        "true," <> acc
      end)

    assert result == correct
  end

  test "Array operations work as expected" do
    file_data = File.read!(@arrays_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Enviornment.prepare_env()
    {:end, env} = Executor.execute(ast_data.prog, env)
    result = env.vars["result"]

    correct =
      Enum.reduce(1..@correct_arrays_trues, "", fn _x, acc ->
        "true," <> acc
      end)

    assert result == correct
  end

  test "Regex operations work as expected" do
    file_data = File.read!(@regex_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Enviornment.prepare_env()
    {:end, env} = Executor.execute(ast_data.prog, env)
    result = env.vars["result"]

    correct =
      Enum.reduce(1..@correct_regex_trues, "", fn _x, acc ->
        "true," <> acc
      end)

    assert result == correct
  end
end
