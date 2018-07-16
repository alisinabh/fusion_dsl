defmodule FusionDsl.Kernel do
  @moduledoc """
  Kernel module of FusionDSL
  """

  use FusionDsl.Impl

  alias FusionDsl.Runtime.Executor

  @r_json_vars ~r/\$([A-Za-z]{1}[A-Za-z0-9.\_]*)/

  @functions [
    :last_index_of,
    :regex_replace,
    :create_array,
    :json_decode,
    :json_encode,
    :regex_match,
    :starts_with,
    :regex_scan,
    :ends_with,
    :regex_run,
    :to_number,
    :to_string,
    :contains,
    :index_of,
    :jump_not,
    :dispose,
    :jump_to,
    :replace,
    :reverse,
    :insert,
    :length,
    :remove,
    :error,
    :regex,
    :round,
    :slice,
    :elem,
    :json,
    :jump,
    :mult,
    :noop,
    :rand,
    :wait,
    :add,
    :and,
    :div,
    :gte,
    :int,
    :lte,
    :mod,
    :neq,
    :not,
    :set,
    :sub,
    :var,
    :eq,
    :gt,
    :lt,
    :or
  ]

  @impl true
  def __list_fusion_functions__, do: @functions

  def fn_and({:and, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_boolean(left) and is_boolean(right) ->
        {:ok, left and right, env}

      true ->
        {:error,
         "And(&&) is not supported for #{inspect(left)} and #{inspect(right)}"}
    end
  end

  def fn_or({:or, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_boolean(left) and is_boolean(right) ->
        {:ok, left or right, env}

      true ->
        {:error,
         "Or(||) is not supported for #{inspect(left)} and #{inspect(right)}"}
    end
  end

  def fn_not({:not, ctx, args}, env) do
    {:ok, [value], env} = prep_arg(env, args)

    cond do
      is_boolean(value) ->
        {:ok, not value, env}

      true ->
        error(env.prog, ctx, "not is not supported for #{inspect(value)}")
    end
  end

  def add({:add, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left + right, env}

      is_binary(left) or is_binary(right) ->
        {:ok, to_string(left) <> to_string(right), env}

      is_list(left) and is_list(right) ->
        {:ok, left ++ right, env}

      is_list(left) ->
        {:ok, left ++ [right], env}

      is_list(right) ->
        {:ok, [left | right], env}

      true ->
        {:error,
         "Add(+) is not supported for #{inspect(left)} and #{inspect(right)}"}
    end
  end

  def sub({:sub, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left - right, env}

      true ->
        {:error,
         "Sub(-) is not supported for #{inspect(left)} and #{inspect(right)}"}
    end
  end

  def mult({:mult, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left * right, env}

      true ->
        {:error,
         "Mult(*) is not supported for #{inspect(left)} and #{inspect(right)}"}
    end
  end

  def div({:div, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left / right, env}

      true ->
        {:error,
         "Div(/) is not supported for #{inspect(left)} and #{inspect(right)}"}
    end
  end

  def mod({:mod, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, rem(left, right), env}

      true ->
        {:error,
         "Mod(%) is not supported for #{inspect(left)} and #{inspect(right)}"}
    end
  end

  def eq({:eq, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_tuple(left) or is_tuple(right) ->
        {:error,
         "Equals(==) is not supported for #{inspect(left)} and #{inspect(right)}"}

      is_nil(left) ->
        {:ok, is_nil(right), env}

      is_nil(right) ->
        {:ok, is_nil(left), env}

      true ->
        {:ok, left == right, env}
    end
  end

  def neq({:neq, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_tuple(left) or is_tuple(right) ->
        {:error,
         "Not-Equals(!=) is not supported for #{inspect(left)} and #{
           inspect(right)
         }"}

      is_nil(left) ->
        {:ok, not is_nil(right), env}

      is_nil(right) ->
        {:ok, not is_nil(left), env}

      true ->
        {:ok, left != right, env}
    end
  end

  def lte({:lte, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left <= right, env}

      true ->
        {:error,
         "Lower-Than-Equal(<=) is not supported for #{inspect(left)} and #{
           inspect(right)
         }"}
    end
  end

  def gte({:gte, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left >= right, env}

      true ->
        {:error,
         "Greater-Than-Equal(>=) is not supported for #{inspect(left)} and #{
           inspect(right)
         }"}
    end
  end

  def lt({:lt, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left < right, env}

      true ->
        {:error,
         "Lower-Than(<) is not supported for #{inspect(left)} and #{
           inspect(right)
         }"}
    end
  end

  def gt({:gt, _ctx, args}, env) do
    {:ok, [left, right], env} = prep_arg(env, args)

    cond do
      is_number(left) and is_number(right) ->
        {:ok, left > right, env}

      true ->
        {:error,
         "Greater-Than(>) is not supported for #{inspect(left)} and #{
           inspect(right)
         }"}
    end
  end

  def set({:set, _ctx, [{:var, _, [var]}, right]}, env) do
    if String.starts_with?(var, "_") do
      case get_var(env, var) do
        {:ok, _, _} ->
          {:error, "Cannot reset an immutable object #{inspect(var)}"}

        {:error, :not_initialized} ->
          :ok
      end
    end

    {:ok, val, env} = Executor.execute_ast(right, env)

    env =
      case String.split(var, ".") do
        [_] ->
          %{env | vars: Map.put(env.vars, var, val)}

        [var | map_list] ->
          case get_var(env, var) do
            {:ok, var_val, env} ->
              %{
                env
                | vars:
                    Map.put(
                      env.vars,
                      var,
                      insert_map_var(map_list, val, var_val)
                    )
              }

            _ ->
              %{
                env
                | vars:
                    Map.put(env.vars, var, insert_map_var(map_list, val, %{}))
              }
          end
      end

    {:ok, val, env}
  end

  def rand({:rand, _ctx, args}, env) do
    {:ok, [lower, upper], env} = prep_arg(env, args)

    cond do
      is_number(lower) and is_number(upper) ->
        {:ok, Enum.random(lower..upper), env}

      true ->
        {:error,
         "rand is not supported for #{inspect(lower)} and #{inspect(upper)}"}
    end
  end

  def to_number({:to_number, _ctx, args}, env) do
    {:ok, [binary], env} = prep_arg(env, args)

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
        {:error, "to_string is not supported for #{inspect(binary)}"}
    end
  end

  def int({:int, ctx, [_] = args}, env) do
    {:ok, [num], env} = prep_arg(env, args)

    cond do
      is_binary(num) ->
        {val, _} = Integer.parse(num)
        {:ok, val, env}

      is_number(num) ->
        {:ok, trunc(num), env}

      true ->
        error(env.prog, ctx, "Cannot convert #{num} to int")
    end
  end

  def round({:round, ctx, [_] = args}, env) do
    {:ok, [num], env} = prep_arg(env, args)

    cond do
      is_binary(num) ->
        {val, _} = Float.parse(num)
        {:ok, round(val), env}

      is_number(num) ->
        {:ok, round(num), env}

      true ->
        error(env.prog, ctx, "Cannot convert #{num} to int")
    end
  end

  def create_array({:create_array, _ctx, args}, env) do
    {:ok, arr_elems, env} = prep_arg(env, args)

    {:ok, arr_elems, env}
  end

  def noop({:noop, _ctx, _}, env) do
    {:ok, nil, env}
  end

  def jump_not({:jump_not, _ctx, args}, env) do
    {:ok, [condition, jump_amount], env} = prep_arg(env, args)

    cond do
      is_boolean(condition) ->
        if not condition do
          {:jump, jump_amount, env}
        else
          {:ok, nil, env}
        end

      true ->
        {:error,
         "Only boolean (true|false) is accepted in condition. not #{
           inspect(condition)
         }"}
    end
  end

  def elem({:elem, _ctx, [_, _] = args}, env) do
    {:ok, [array, index], env} = prep_arg(env, args)

    cond do
      is_list(array) and is_integer(index) ->
        {:ok, Enum.at(array, index), env}

      true ->
        {:error,
         "elem is not supported for #{inspect(array)} at #{inspect(index)}"}
    end
  end

  def insert({:insert, _ctx, [_, _, _] = args}, env) do
    {:ok, [array, index, value], env} = prep_arg(env, args)

    cond do
      is_list(array) and is_integer(index) ->
        {:ok, List.insert_at(array, index, value), env}

      true ->
        {:error,
         "insert is not supported for #{inspect(array)} and #{inspect(value)} at #{
           inspect(index)
         }"}
    end
  end

  def wait({:wait, _ctx, [_] = args}, env) do
    {:ok, [amount], env} = prep_arg(env, args)

    cond do
      is_number(amount) ->
        :timer.sleep(trunc(amount * 1000))

        {:ok, nil, env}

      true ->
        {:error,
         "wait should be called with a valid number. not #{inspect(amount)}"}
    end
  end

  def remove({:remove, _ctx, [_, _] = args}, env) do
    {:ok, [value, index], env} = prep_arg(env, args)

    cond do
      is_list(value) and is_integer(index) ->
        {:ok, List.delete_at(value, index), env}

      is_binary(value) and is_integer(index) ->
        {lead, <<_::utf8, tail::binary>>} = String.split_at(value, index)
        {:ok, lead <> tail, env}

      is_map(value) and is_binary(index) ->
        {:ok, Map.delete(value, index), env}

      true ->
        {:error,
         "remove is not supported with args: #{inspect(value)} and #{
           inspect(index)
         }"}
    end
  end

  def dispose({:dispose, _ctx, [{:var, _, [name]}] = args}, env) do
    {:ok, [value], env} = prep_arg(env, args)

    cond do
      String.contains?(name, ".") ->
        {:error,
         "Dispose only works on variables (not map elements) $#{inspect(name)}"}

      true ->
        {:ok, value, Map.put(env, :vars, Map.delete(env.vars, name))}
    end
  end

  # TODO: Add an option to cancel variable injection
  def json_decode({:json_decode, _ctx, [_] = args}, env) do
    # {:ok, [json], env} = prep_arg(env, args)
    {:ok, [json], env} = prep_arg(env, args)

    variables = Regex.scan(@r_json_vars, json)

    {json, env} = replace_json_vars(variables, json, env)

    cond do
      is_binary(json) ->
        case Poison.decode(json) do
          {:ok, data} ->
            {:ok, data, env}

          _ ->
            {:error, "Invalid json binary for json_decode: #{inspect(json)}"}
        end

      true ->
        {:error,
         "Only binary(Strings) are accepted in json_decode, not #{inspect(json)}"}
    end
  end

  def json_encode({:json_encode, ctx, [_] = args}, env) do
    {:ok, [obj], env} = prep_arg(env, args)

    case Poison.encode(obj) do
      {:ok, string} ->
        {:ok, string, env}

      _ ->
        error(env.prog, ctx, "Invalid object to json_encode #{inspect(obj)}")
    end
  end

  def contains({:contains, _ctx, [_, _] = args}, env) do
    {:ok, [source, element], env} = prep_arg(env, args)

    cond do
      is_binary(source) and is_binary(element) ->
        {:ok, String.contains?(source, element), env}

      is_list(source) ->
        {:ok, Enum.member?(source, element), env}

      true ->
        {:error,
         "contains works on arrays and strings only. called with: #{
           inspect(source)
         } and #{inspect(element)}"}
    end
  end

  def index_of({:index_of, _ctx, [_, _] = args}, env) do
    {:ok, [source, element], env} = prep_arg(env, args)

    cond do
      is_binary(source) and is_binary(element) ->
        len =
          case String.split(source, element) do
            [h, _ | _] ->
              String.length(h)

            _ ->
              nil
          end

        {:ok, len, env}

      is_list(source) ->
        {:ok, Enum.find_index(source, &(&1 == element)), env}

      true ->
        {:error,
         "index_of works on arrays and strings only. called with: #{
           inspect(source)
         } and #{inspect(element)}"}
    end
  end

  def last_index_of({:last_index_of, _ctx, [_, _] = args}, env) do
    {:ok, [source, element], env} = prep_arg(env, args)

    cond do
      is_binary(source) and is_binary(element) ->
        source = String.reverse(source)

        len =
          case String.split(source, element) do
            [h, _ | _] ->
              String.length(source) - String.length(h) - 1

            _ ->
              nil
          end

        {:ok, len, env}

      is_list(source) ->
        source = Enum.reverse(source)

        case Enum.find_index(source, &(&1 == element)) do
          nil ->
            {:ok, nil, env}

          count when is_integer(count) ->
            {:ok, Enum.count(source) - count - 1, env}
        end

      true ->
        {:error,
         "last_index_of works on arrays and strings only. called with: #{
           inspect(source)
         } and #{inspect(element)}"}
    end
  end

  def starts_with({:starts_with, _ctx, [_, _] = args}, env) do
    {:ok, [source, element], env} = prep_arg(env, args)

    cond do
      is_binary(source) and is_binary(element) ->
        {:ok, String.starts_with?(source, element), env}

      is_list(source) ->
        case source do
          [^element | _] ->
            {:ok, true, env}

          _ ->
            {:ok, false, env}
        end

      true ->
        {:error,
         "starts_with works on arrays and strings only. called with: #{
           inspect(source)
         } and #{inspect(element)}"}
    end
  end

  def ends_with({:ends_with, _ctx, [_, _] = args}, env) do
    {:ok, [source, element], env} = prep_arg(env, args)

    cond do
      is_binary(source) and is_binary(element) ->
        {:ok, String.ends_with?(source, element), env}

      is_list(source) ->
        last = List.last(source)

        cond do
          is_nil(last) ->
            {:ok, false, env}

          last == element ->
            {:ok, true, env}

          true ->
            {:ok, false, env}
        end

      true ->
        {:error,
         "ends_with works on arrays and strings only. called with: #{
           inspect(source)
         } and #{inspect(element)}"}
    end
  end

  def replace({:replace, _ctx, [_, _, _] = args}, env) do
    {:ok, [source, element, replacement], env} = prep_arg(env, args)

    cond do
      is_binary(source) and is_binary(element) ->
        {:ok, String.replace(source, element, replacement), env}

      is_list(source) ->
        result = replace_in_list(source, element, replacement)

        {:ok, result, env}

      true ->
        {:error,
         "replace works on arrays and strings only. called with: #{
           inspect(source)
         } and #{inspect(element)} and #{inspect(replacement)}"}
    end
  end

  def reverse({:reverse, _ctx, [_] = args}, env) do
    {:ok, [source], env} = prep_arg(env, args)

    cond do
      is_binary(source) ->
        {:ok, String.reverse(source), env}

      is_list(source) ->
        {:ok, Enum.reverse(source), env}

      true ->
        {:error,
         "reverse works on arrays and strings only. called with: #{
           inspect(source)
         }"}
    end
  end

  def length({:length, _ctx, [_] = args}, env) do
    {:ok, [source], env} = prep_arg(env, args)

    cond do
      is_binary(source) ->
        {:ok, String.length(source), env}

      is_list(source) ->
        {:ok, Enum.count(source), env}

      true ->
        {:error,
         "length works on arrays and strings only. called with: #{
           inspect(source)
         }"}
    end
  end

  def slice({:slice, ctx, [_, _ | _] = args}, env) do
    {:ok, [source, start | count] = f_args, env} = prep_arg(env, args)

    count =
      case count do
        [] ->
          -1

        [num | _] when is_integer(num) ->
          num
      end

    cond do
      is_binary(source) and count == -1 ->
        {:ok, String.slice(source, start..-1), env}

      is_binary(source) ->
        {:ok, String.slice(source, start, count), env}

      is_list(source) and count == -1 ->
        {:ok, Enum.slice(source, start..-1), env}

      is_list(source) ->
        {:ok, Enum.slice(source, start, count), env}

      true ->
        error(env.prog, ctx, "Bad arguments for slice #{inspect(f_args)}")
    end
  end

  def regex({:regex, _ctx, args}, env) do
    {:ok, [regex_str | opts] = f_args, env} = prep_arg(env, args)

    opt =
      case opts do
        [] -> ""
        [str] -> str
      end

    cond do
      is_binary(regex_str) and is_binary(opt) ->
        {:ok, Regex.compile!(regex_str, opt), env}

      true ->
        {:error, "Invalid arguments for regex compile: #{inspect(f_args)}"}
    end
  end

  def regex_run({:regex_run, _ctx, args}, env) do
    {:ok, [%Regex{} = regex, string] = f_args, env} = prep_arg(env, args)

    cond do
      is_binary(string) ->
        {:ok, norm_regex(Regex.run(regex, string, return: :index)), env}

      true ->
        {:error, "Invalid arguments for regex run: #{inspect(f_args)}"}
    end
  end

  def regex_match({:regex_match, _ctx, args}, env) do
    {:ok, [%Regex{} = regex, string] = f_args, env} = prep_arg(env, args)

    cond do
      is_binary(string) ->
        {:ok, Regex.match?(regex, string), env}

      true ->
        {:error, "Invalid arguments for regex match: #{inspect(f_args)}"}
    end
  end

  def regex_replace({:regex_replace, _ctx, args}, env) do
    {:ok, [%Regex{} = regex, string, replacement] = f_args, env} =
      prep_arg(env, args)

    cond do
      is_binary(string) ->
        {:ok, Regex.replace(regex, string, replacement), env}

      true ->
        {:error, "Invalid arguments for regex replace: #{inspect(f_args)}"}
    end
  end

  def regex_scan({:regex_scan, _ctx, args}, env) do
    {:ok, [%Regex{} = regex, string] = f_args, env} = prep_arg(env, args)

    cond do
      is_binary(string) ->
        {:ok, norm_regex(Regex.scan(regex, string, return: :index)), env}

      true ->
        {:error, "Invalid arguments for regex replace: #{inspect(f_args)}"}
    end
  end

  def to_string({:to_string, _ctx, args}, env) do
    {:ok, [val], env} = prep_arg(env, args)

    {:ok, to_string(val), env}
  end

  defp norm_regex(list, acc \\ [])

  defp norm_regex([a | t], acc) when is_tuple(a) do
    norm_regex(t, [Tuple.to_list(a) | acc])
  end

  defp norm_regex([a | t], acc) when is_list(a) do
    a = norm_regex(a, [])
    norm_regex(t, [a | acc])
  end

  defp norm_regex([], acc) do
    Enum.reverse(acc)
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

  defp error(_prog, ctx, msg) do
    raise("Kernel error\n Line: #{ctx[:ln]}: #{msg}")
  end

  defp replace_in_list(source, pattern, replacement),
    do:
      source
      |> Enum.reduce([], fn x, acc ->
        if x == pattern do
          [replacement | acc]
        else
          [x | acc]
        end
      end)
      |> Enum.reverse()

  defp replace_json_vars([], json, env), do: {json, env}

  defp replace_json_vars(variables, json, env) do
    Enum.reduce(variables, {json, env}, fn [name, var], acc ->
      {json, env} = acc

      case get_var(env, var) do
        {:ok, v, env} ->
          {String.replace(json, name, to_string(v)), env}

        {:error} ->
          {json, env}
      end
    end)
  end
end
