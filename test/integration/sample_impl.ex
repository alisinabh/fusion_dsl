defmodule FusionDslTest.SampleImpl do
  use FusionDsl.Impl

  @functions [:test]

  @impl true
  def list_functions, do: @functions

  @doc "Just adds two arguments..."
  def test({:test, _ctx, [_, _] = args}, env) do
    {:ok, [a, b], env} = prep_arg(env, args)
    {:ok, a + b, env}
  end
end
