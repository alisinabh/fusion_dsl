defmodule FusionDslTest.SampleImpl do
  use FusionDsl.Impl

  @impl true
  def list_functions, do: [:test]

  @doc "Just adds two arguments..."
  def test({:test, ctx, [_, _] = args}, env) do
    {:ok, [a, b], evn} = prep_arg(args, env)
    {:ok, a + b, env}
  end
end
