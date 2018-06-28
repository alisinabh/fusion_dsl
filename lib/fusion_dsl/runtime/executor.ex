defmodule FusionDsl.Runtime.Executor do
  @moduledoc """
  Executes an Ivrone program
  """

  alias FusionDsl.Helpers.FunctionNames
  alias FusionDsl.Impl

  @jump_start_throttle Application.get_env(:fusion_dsl, :jump_start_throttle)
  @jump_throttle_every Application.get_env(:fusion_dsl, :jump_throttle_every)
  @jump_throttle_time_ms Application.get_env(
                           :fusion_dsl,
                           :jump_throttle_time_ms
                         )

  @doc """
  Executes the program in given enviornment
  """
  def execute(env) do
    proc = List.first(env.cur_proc)
    execute_procedure(env.prog.procedures[proc], env)
  end

  defp execute_procedure([ast | t], env) do
    case execute_ast(ast, env) do
      {:ok, _, env} ->
        execute_procedure(t, env)

      {:jump, jump_amount, env} ->
        t = jump(t, jump_amount)
        execute_procedure(t, env)

      {:jump_to, {line_number, skip, opt}, env} ->
        proc = List.first(env.cur_proc)
        t = jump_to(env.prog.procedures[proc], line_number)
        t = jump(t, skip)
        jump_c = env.jump_c + 1
        env = Map.put(env, :jump_c, jump_c)

        if opt and jump_c > @jump_start_throttle and
             rem(jump_c, @jump_throttle_every) == 0 do
          :timer.sleep(@jump_throttle_time_ms)
        end

        execute_procedure(t, env)

      {:end, env} ->
        [_ | t] = env.cur_proc
        env = Map.put(env, :cur_proc, t)
        {:end, env}
    end
  end

  defp execute_procedure([], env) do
    [_ | t] = env.cur_proc
    env = Map.put(env, :cur_proc, t)
    {:end, env}
  end

  defp jump(t, 0), do: t

  defp jump([_ | t], r_jmp) do
    jump(t, r_jmp - 1)
  end

  defp jump_to([{_, ctx, _} | t] = p, ln) do
    cond do
      ctx[:ln] == ln ->
        p

      true ->
        jump_to(t, ln)
    end
  end

  def execute_ast({{module, func}, ctx, args}, env) do
    module_func = FunctionNames.normalize!(func)

    case apply(module, module_func, [{func, ctx, args}, env]) do
      {:ok, output, env} ->
        {:ok, output, env}

      {:jump, amount, env} ->
        {:jump, amount, env}

      {:jump_to, data, env} ->
        {:jump_to, data, env}

      {:error, message} ->
        error(env.prog, ctx, message)
    end
  end

  def execute_ast({:return, _, _}, env) do
    {:end, env}
  end

  def execute_ast({:var, _ctx, [var]}, env) do
    Impl.get_var(env.prog, var, env)
  end

  def execute_ast({:goto, ctx, [proc]}, env) when is_atom(proc) do
    case env.prog.procedures[proc] do
      proc_asts when is_list(proc_asts) ->
        :timer.sleep(50)

        # Sleep is to prevent high cpu utilization in case of an infinity
        # recursion
        env = Map.put(env, :cur_proc, [proc | env.cur_proc])
        {:end, env} = execute_procedure(proc_asts, env)
        {:ok, nil, env}

      nil ->
        error(env.prog, ctx, "Procedure #{proc} not found!")
    end
  end

  def execute_ast({:jump, _ctx, [jump_amount]}, env) do
    {:jump, jump_amount, env}
  end

  def execute_ast({:jump_to, _ctx, [line_number, skip, opt]}, env) do
    {:jump_to, {line_number, skip, opt}, env}
  end

  def execute_ast({:noop, _, _}, env), do: {:ok, nil, env}

  def execute_ast(num, env) when is_number(num) do
    {:ok, num, env}
  end

  def execute_ast(string, env) when is_binary(string) do
    {:ok, string, env}
  end

  def execute_ast(bool, env) when is_boolean(bool) do
    {:ok, bool, env}
  end

  def execute_ast(list, env) when is_list(list) do
    {:ok, list, env}
  end

  def execute_ast(map, env) when is_map(map) do
    {:ok, map, env}
  end

  def execute_ast(v, env) when is_nil(v) do
    {:ok, nil, env}
  end

  def execute_ast(%Regex{} = v, env) do
    {:ok, v, env}
  end

  defp error(_prog, ctx, msg) do
    raise("Kernel error\n Line: #{ctx[:ln]}: #{msg}")
  end
end
