defmodule FusionDslTest.SampleImpl do
  use FusionDsl.Impl

  def list_functions, do: [:test]

  def execute_ast(env, {:test, ctx, [_, _] = args}) do
    {:ok, [a, b], evn} = prep_arg(args, env)
    {:ok, a + b, env}
  end
end
