defmodule IvroneDsl.Runtime.Executor do
  @moduledoc """
  Executes an Ivrone program
  """

  alias IvroneDsl.Processor.Program

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

  defp execute_ast(prog, {:set, ctx, [{:var, _, [var]}, right]}, env) do
    {:ok, right, env} = execute_ast(prog, right, env)

    env =
      if String.contains?(var, ".") do
        env
        # TODO implemet set map
      else
        %{env | vars: Map.put(env.vars, var, right)}
      end

    {:ok, nil, env}
  end

  defp execute_ast(prog, {:var, ctx, [var]}, env) do
    case env.vars[var] do
      nil ->
        error(prog, ctx, "Variable #{var} is not initialized!")

      v ->
        {:ok, v, env}
    end
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
        {:end, env} = execute_procedure(prog, proc_asts, env)
        {:ok, nil, env}
      nil ->
        error(prog, ctx, "Procedure #{proc} not found!")
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

  def prepare_file() do
  end

  defp error(prog, ctx, msg) do
    raise("Line: #{ctx[:ln]}: #{msg}")
  end
end
