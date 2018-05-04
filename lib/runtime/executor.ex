defmodule IvroneDsl.Runtime.Executor do
  @moduledoc """
  Executes an Ivrone program
  """

  alias IvroneDsl.Processor.Program

  @r_json_vars ~r/\$([A-Za-z]{1}[A-Za-z0-9.\_]*)/

  @doc """
  Executes the program in given enviornment
  """
  def execute(%Program{} = prog, env) do
    proc = List.first(env.cur_proc)
    execute_procedure(prog, prog.procedures[proc], env)
  end

  defp execute_procedure(prog, [ast | t], env) do
    case execute_ast(prog, ast, env) do
      {:ok, _, env} ->
        execute_procedure(prog, t, env)

      {:jump, jump_amount, env} ->
        t = jump(t, jump_amount)
        execute_procedure(prog, t, env)

      {:jump_to, {line_number, skip}, env} ->
        proc = List.first(env.cur_proc)
        t = jump_to(prog.procedures[proc], line_number)
        t = jump(t, skip)
        jump_c = env.jump_c + 1
        env = Map.put(env, :jump_c, jump_c)

        if rem(jump_c, 5) == 0 do
          :timer.sleep(50)
        end

        execute_procedure(prog, t, env)

      {:end, env} ->
        [_ | t] = env.cur_proc
        env = Map.put(env, :cur_proc, t)
        {:end, env}
    end
  end

  defp execute_procedure(prog, [], env) do
    {:end, env}
  end

  defp jump(t, 0) do
    t
  end

  defp jump([_ | t], r_jmp) do
    jump(t, r_jmp - 1)
  end

  defp jump_to([{_, ctx, _} = h | t] = p, ln) do
    cond do
      ctx[:ln] == ln ->
        p

      true ->
        jump_to(t, ln)
    end
  end

  defp execute_ast(prog, {:and, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_boolean(left) and is_boolean(right) ->
        {:ok, left and right, env}

      true ->
        error(prog, ctx, "And(&&) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:or, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_boolean(left) and is_boolean(right) ->
        {:ok, left or right, env}

      true ->
        error(prog, ctx, "Or(||) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:not, ctx, args}, env) do
    {:ok, [value], env} = process_args(prog, env, args, [])

    cond do
      is_boolean(value) ->
        {:ok, not value, env}

      true ->
        error(prog, ctx, "not is not supported for #{inspect(value)}")
    end
  end

  defp execute_ast(prog, {:add, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left + right, env}

      is_binary(left) or is_binary(right) ->
        {:ok, to_string(left) <> to_string(right), env}

      is_list(left) and is_list(right) ->
        {:ok, left ++ right, env}

      true ->
        error(prog, ctx, "Add(+) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:sub, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left - right, env}

      true ->
        error(prog, ctx, "Sub(-) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:mult, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left * right, env}

      true ->
        error(prog, ctx, "Mult(*) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:div, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left / right, env}

      true ->
        error(prog, ctx, "Div(/) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:mod, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, rem(left, right), env}

      true ->
        error(prog, ctx, "Mod(%) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:eq, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left == right, env}

      is_binary(left) and is_binary(right) ->
        {:ok, left == right, env}

      true ->
        error(prog, ctx, "Equals(==) is not supported for #{inspect(left)} and #{inspect(right)}")
    end
  end

  defp execute_ast(prog, {:neq, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left != right, env}

      is_binary(left) and is_binary(right) ->
        {:ok, left != right, env}

      true ->
        error(
          prog,
          ctx,
          "Not-Equals(!=) is not supported for #{inspect(left)} and #{inspect(right)}"
        )
    end
  end

  defp execute_ast(prog, {:lte, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left <= right, env}

      true ->
        error(
          prog,
          ctx,
          "Lower-Than-Equal(<=) is not supported for #{inspect(left)} and #{inspect(right)}"
        )
    end
  end

  defp execute_ast(prog, {:gte, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left >= right, env}

      true ->
        error(
          prog,
          ctx,
          "Greater-Than-Equal(>=) is not supported for #{inspect(left)} and #{inspect(right)}"
        )
    end
  end

  defp execute_ast(prog, {:lt, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left < right, env}

      true ->
        error(
          prog,
          ctx,
          "Lower-Than(<) is not supported for #{inspect(left)} and #{inspect(right)}"
        )
    end
  end

  defp execute_ast(prog, {:gt, ctx, args}, env) do
    {:ok, [left, right], env} = process_args(prog, env, args, [])

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left > right, env}

      true ->
        error(
          prog,
          ctx,
          "Greater-Than(>) is not supported for #{inspect(left)} and #{inspect(right)}"
        )
    end
  end

  defp execute_ast(prog, {:set, ctx, [{:var, _, [var]}, right]}, env) do
    if String.starts_with?(var, "_") do
      case get_var(prog, var, env, ctx) do
        {:ok, _, _} ->
          error(prog, ctx, "Cannot reset an immutable object #{inspect(var)}")

        {:error, :not_initialized} ->
          :ok
      end
    end

    {:ok, val, env} = execute_ast(prog, right, env)

    env =
      case String.split(var, ".") do
        [_] ->
          %{env | vars: Map.put(env.vars, var, val)}

        [var | map_list] ->
          var_val =
            case get_var(prog, var, env, ctx) do
              {:ok, var_val, env} ->
                insert_map_var(map_list, val, var_val)

              _ ->
                insert_map_var(map_list, val, %{})
            end

          %{env | vars: Map.put(env.vars, var, var_val)}
      end

    {:ok, val, env}
  end

  defp execute_ast(prog, {:var, ctx, [var]}, env) do
    get_var(prog, var, env, ctx)
  end

  defp execute_ast(prog, {:rand, ctx, args}, env) do
    {:ok, [lower, upper], env} = process_args(prog, env, args, [])

    cond do
      is_number(lower) and is_number(upper) ->
        {:ok, Enum.random(lower..upper), env}

      true ->
        error(prog, ctx, "rand is not supported for #{inspect(lower)} and #{inspect(upper)}")
    end
  end

  defp execute_ast(prog, {:to_number, ctx, args}, env) do
    {:ok, [binary], env} = process_args(prog, env, args, [])

    cond do
      is_binary(binary) ->
        if String.contains?(binary, ".") do
          num =
            case Float.parse(binary) do
              {n, _} -> n
              :error -> nil
            end

          {:ok, num, env}
        else
          num =
            case Integer.parse(binary) do
              {n, _} -> n
              :error -> nil
            end

          {:ok, num, env}
        end

      true ->
        error(prog, ctx, "to_string is not supported for #{inspect(binary)}")
    end
  end

  defp execute_ast(prog, {:int, ctx, [_] = args}, env) do
    {:ok, [num], env} = process_args(prog, env, args, [])

    cond do
      is_binary(num) ->
        {val, _} = Integer.parse(num)
        {:ok, val, env}

      is_number(num) ->
        {:ok, trunc(num), env}

      true ->
        error(prog, ctx, "Cannot convert #{num} to int")
    end
  end

  defp execute_ast(prog, {:create_array, ctx, args}, env) do
    {:ok, arr_elems, env} = process_args(prog, env, args, [])

    {:ok, arr_elems, env}
  end

  defp execute_ast(prog, {:noop, ctx, _}, env) do
    {:ok, nil, env}
  end

  defp execute_ast(prog, {:jump, ctx, [jump_amount]}, env) do
    {:jump, jump_amount, env}
  end

  defp execute_ast(prog, {:jump_to, ctx, [line_number, skip]}, env) do
    {:jump_to, {line_number, skip}, env}
  end

  defp execute_ast(prog, {:jump_not, ctx, args}, env) do
    {:ok, [condition, jump_amount], env} = process_args(prog, env, args, [])

    cond do
      is_boolean(condition) ->
        if not condition do
          {:jump, jump_amount, env}
        else
          {:ok, nil, env}
        end

      true ->
        error(
          prog,
          ctx,
          "Only boolean (true|false) is accepted in condition. not #{inspect(condition)}"
        )
    end
  end

  defp execute_ast(prog, {:goto, ctx, [proc]}, env) when is_atom(proc) do
    case prog.procedures[proc] do
      proc_asts when is_list(proc_asts) ->
        :timer.sleep(50)
        # Sleep is to prevent high cpu utilization in case of an infinity recursion
        env = Map.put(env, :cur_proc, [proc | env.cur_proc])
        {:end, env} = execute_procedure(prog, proc_asts, env)
        {:ok, nil, env}

      nil ->
        error(prog, ctx, "Procedure #{proc} not found!")
    end
  end

  defp execute_ast(prog, {:elem, ctx, [_, _] = args}, env) do
    {:ok, [array, index], env} = process_args(prog, env, args, [])

    cond do
      is_list(array) and is_integer(index) ->
        {:ok, Enum.at(array, index), env}

      true ->
        error(prog, ctx, "elem is not supported for #{inspect(array)} at #{inspect(index)}")
    end
  end

  defp execute_ast(prog, {:insert, ctx, [_, _, _] = args}, env) do
    {:ok, [array, index, value], env} = process_args(prog, env, args, [])

    cond do
      is_list(array) and is_integer(index) ->
        {:ok, List.insert_at(array, index, value), env}

      true ->
        error(
          prog,
          ctx,
          "insert is not supported for #{inspect(array)} and #{inspect(value)} at #{
            inspect(index)
          }"
        )
    end
  end

  defp execute_ast(prog, {:return, _ctx, _}, env) do
    {:end, env}
  end

  defp execute_ast(prog, {:wait, ctx, [_] = args}, env) do
    {:ok, [amount], env} = process_args(prog, env, args, [])

    cond do
      is_number(amount) ->
        (amount * 1000)
        |> trunc
        |> :timer.sleep()

        {:ok, nil, env}

      true ->
        error(prog, ctx, "wait should be called with a valid number. not #{inspect(amount)}")
    end
  end

  defp execute_ast(prog, {:remove, ctx, [_, _] = args}, env) do
    {:ok, [value, index], env} = process_args(prog, env, args, [])

    cond do
      is_list(value) and is_integer(index) ->
        {:ok, List.delete_at(value, index), env}

      is_binary(value) and is_integer(index) ->
        {lead, <<_::utf8, tail::binary>>} = String.split_at(value, index)
        {:ok, lead <> tail, env}

      is_map(value) and is_binary(index) ->
        {:ok, Map.delete(value, index), env}

      true ->
        error(
          prog,
          ctx,
          "remove is not supported with args: #{inspect(value)} and #{inspect(index)}"
        )
    end
  end

  defp execute_ast(prog, {:dispose, ctx, [{:var, _, [name]}] = args}, env) do
    {:ok, [value], env} = process_args(prog, env, args, [])

    cond do
      String.contains?(name, ".") ->
        error(prog, ctx, "Dispose only works on variables (not maps) $#{inspect(name)}")

      true ->
        {:ok, value, Map.put(env, :vars, Map.delete(env.vars, name))}
    end
  end

  defp execute_ast(prog, {:json, ctx, [_] = args}, env) do
    {:ok, [json], env} = process_args(prog, env, args, [])

    variables = Regex.scan(@r_json_vars, json)

    {env, json} =
      case variables do
        [] ->
          {env, json}

        _ ->
          Enum.reduce(variables, {env, json}, fn [name, var], acc ->
            {env, json} = acc

            case get_var(prog, var, env, ctx) do
              {:ok, v, env} ->
                {env, String.replace(json, name, to_string(v))}

              {:error} ->
                {env, json}
            end
          end)
      end

    case Poison.decode(json) do
      {:ok, json_data} ->
        {:ok, json_data, env}

      _ ->
        error(prog, ctx, "Json decode error: #{inspect(json)}")
    end
  end

  defp execute_ast(prog, {:play, ctx, args}, env) do
    {:ok, [file_name | t], env} = process_args(prog, env, args, [])

    escape_digits =
      case t do
        [] -> "0123456789"
        [ed] when is_binary(ed) -> ed
        _ -> error(prog, ctx, "Unknown parametes given to play: #{inspect(args)}")
      end

    cond do
      is_binary(file_name) ->
        {:ok, _result, _env} = env.mod.play(prog, env, file_name, escape_digits)

      true ->
        error(prog, ctx, "play is not supported for #{inspect(file_name)}")
    end
  end

  defp execute_ast(prog, num, env) when is_number(num) do
    {:ok, num, env}
  end

  defp execute_ast(prog, string, env) when is_binary(string) do
    {:ok, string, env}
  end

  defp execute_ast(prog, bool, env) when is_boolean(bool) do
    {:ok, bool, env}
  end

  defp execute_ast(prog, list, env) when is_list(list) do
    {:ok, list, env}
  end

  defp execute_ast(prog, map, env) when is_map(map) do
    {:ok, map, env}
  end

  defp execute_ast(prog, {_, ctx, _} = unknown, env) do
    error(prog, ctx, "Unknown type #{inspect(unknown)}")
  end

  defp process_args(prog, env, [arg | t], acc) do
    {:ok, arg, env} = execute_ast(prog, arg, env)
    process_args(prog, env, t, [arg | acc])
  end

  defp process_args(_, env, [], acc) do
    {:ok, Enum.reverse(acc), env}
  end

  defp get_var(prog, var, env, ctx) when is_binary(var) do
    case do_get_var(prog, nil, String.split(var, "."), env) do
      {:ok, acc, env} ->
        {:ok, acc, env}

      {:error, :not_initialized} ->
        {:error, :not_initialized}
    end
  end

  defp do_get_var(prog, nil, [var | t], env) do
    case Map.fetch(env.vars, var) do
      :error ->
        {:error, :not_initialized}

      {:ok, v} ->
        do_get_var(prog, v, t, env)
    end
  end

  defp do_get_var(prog, acc, [var | t], env) when is_map(acc) do
    case Map.fetch(acc, var) do
      :error ->
        {:error, :not_initialized}

      {:ok, v} ->
        do_get_var(prog, v, t, env)
    end
  end

  defp do_get_var(prog, acc, [], env) do
    {:ok, acc, env}
  end

  defp insert_map_var([final_var], val, var_val) do
    Map.put(var_val, final_var, val)
  end

  defp insert_map_var([h | t], val, var_val) do
    acc =
      case Map.fetch(var_val, h) do
        {:ok, acc} when is_map(acc) ->
          acc

        _ ->
          %{}
      end

    final = insert_map_var(t, val, acc)

    Map.put(var_val, h, final)
  end

  defp error(prog, ctx, msg) do
    raise("Line: #{ctx[:ln]}: #{msg}")
  end
end
