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
    execute_procedure(prog, prog.procedures.main, env)
  end

  defp execute_procedure(prog, [ast | t], env) do
    case execute_ast(prog, ast, env) do
      {:ok, _, env} ->
        execute_procedure(prog, t, env)

      {:end, env} ->
        {:end, env}
    end
  end

  defp execute_procedure(prog, [], env) do
    {:end, env}
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

  defp execute_ast(prog, {:goto, ctx, [proc]}, env) when is_atom(proc) do
    case prog.procedures[proc] do
      proc_asts when is_list(proc_asts) ->
        :timer.sleep(100)
        # Sleep is to prevent high cpu utilization in case of an infinity recursion
        {:end, env} = execute_procedure(prog, proc_asts, env)
        {:ok, nil, env}

      nil ->
        error(prog, ctx, "Procedure #{proc} not found!")
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

  defp error(prog, ctx, msg) do
    raise("Line: #{ctx[:ln]}: #{msg}")
  end
end
