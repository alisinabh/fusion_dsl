defmodule FusionDslTest.SampleImpl do
  use FusionDsl.Impl

  @functions [:test]

  @impl true
  def __list_fusion_functions__, do: @functions

  @doc "Just adds two arguments..."
  def test({:test, _ctx, [_, _] = args}, env) do
    {:ok, [a, b], env} = prep_arg(env, args)
    {:ok, a + b, env}
  end
end
