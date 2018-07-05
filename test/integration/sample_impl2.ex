defmodule FusionDslTest.SampleImpl2 do
  use FusionDsl.Impl

  @functions [:fibo, :pow]

  @impl true
  def list_functions, do: @functions

  @doc "Calculates fibonatchi"
  def fibo({:fibo, _ctx, [_] = args}, env) do
    {:ok, [max], env} = prep_arg(env, args)
    {:ok, fib(max), env}
  end

  @doc "Calculates power a^b"
  def pow({:pow, _ctx, [_, _] = args}, env) do
    {:ok, [a, b], env} = prep_arg(env, args)
    {:ok, :math.pow(a, b), env}
  end

  defp fib(0) do
    0
  end

  defp fib(1) do
    1
  end

  defp fib(n) do
    fib(n - 1) + fib(n - 2)
  end
end
