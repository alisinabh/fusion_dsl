defmodule FusionDslTest.IntegrationTest do
  use ExUnit.Case

  alias FusionDsl.Processor.Lexer
  alias FusionDsl.Processor.AstProcessor
  alias FusionDsl.Runtime.Environment
  alias FusionDsl.Runtime.Executor

  @sample_impl_file "test/samples/integration.fus"
  @multi_import_file "test/samples/multi_import.fus"

  @correct_sample_impl_trues 2
  @correct_multi_import_trues 3

  test "SamplImpl integrated function is working" do
    file_data = File.read!(@sample_impl_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Environment.prepare_env(ast_data.prog)
    {:end, env} = Executor.execute(env)
    result = env.vars["result"]

    correct =
      Enum.reduce(1..@correct_sample_impl_trues, "", fn _x, acc ->
        "true," <> acc
      end)

    assert result == correct
  end

  test "multi_import integrated function is working" do
    file_data = File.read!(@multi_import_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Environment.prepare_env(ast_data.prog)
    {:end, env} = Executor.execute(env)
    result = env.vars["result"]

    correct =
      Enum.reduce(1..@correct_multi_import_trues, "", fn _x, acc ->
        "true," <> acc
      end)

    assert result == correct
  end
end
