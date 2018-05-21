defmodule FusionDslTest.IntegrationTest do
  use ExUnit.Case

  alias FusionDsl.Processor.Lexer
  alias FusionDsl.Processor.AstProcessor
  alias FusionDsl.Runtime.Enviornment
  alias FusionDsl.Runtime.Executor

  @integration_file "test/samples/integration.fus"
  @correct_integration_trues 1

  test "integrated functions are working" do
    file_data = File.read!(@integration_file)
    assert {:ok, conf, tokens} = Lexer.tokenize(file_data)
    lines = Lexer.split_by_lines(tokens, conf.start_code)
    assert {:ok, ast_data} = AstProcessor.generate_ast(conf, lines)

    {:ok, env} = Enviornment.prepare_env(ast_data.prog)
    {:end, env} = Executor.execute(ast_data.prog, env)
    result = env.vars["result"]

    correct =
      Enum.reduce(1..@correct_integration_trues, "", fn _x, acc ->
        "true," <> acc
      end)

    assert result == correct
  end
end
