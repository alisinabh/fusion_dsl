defmodule FusionDsl.Processor.AstProcessor do
  @moduledoc """
  Functions for converting tokens to Abstract syntax trees

  ## Ast structure:

  ```
  {action_name_atom, [line_number], args_list}
  ```
  """

  @clause_beginners ["if", "for", "while"]
  @noops ["noop"]
  @operators [
    "*",
    "/",
    "%",
    "+",
    "-",
    "==",
    "!=",
    "<=",
    ">=",
    "<",
    ">",
    "and",
    "&&",
    "or",
    "||",
    "="
  ]
  @operator_names %{
    "*" => :mult,
    "/" => :div,
    "%" => :mod,
    "+" => :add,
    "-" => :sub,
    "==" => :eq,
    "!=" => :neq,
    "<=" => :lte,
    ">=" => :gte,
    "<" => :lt,
    ">" => :gt,
    "=" => :set,
    "and" => :and,
    "&&" => :and,
    "or" => :or,
    "||" => :or
  }

  @short_setters ["+=", "-=", "*=", "/=", "%="]

  @packages FusionDsl.get_packages()

  @doc """
  Generates an ast array of program

  ## Parameters
    - config: configuration of program
    - tokens: list of line splitted tokens
  """
  def generate_ast(config, tokens) do
    do_generate_ast(tokens, config)
  end

  defp do_generate_ast([[line_number | raw_line] | t], config) do
    config = Map.put(config, :ln, line_number)
    line = reorder_line(raw_line)

    {:ok, ast, config} = gen_ast(line, t, config)

    case ast do
      nil ->
        do_generate_ast(t, config)

      ast ->
        cmp_config = insert_ast_in_config(config, ast)
        do_generate_ast(t, cmp_config)
    end
  end

  defp do_generate_ast([], config) do
    {:ok, config}
  end

  def reorder_line(line) do
    line
    |> insert_array_scopes([])
    |> expand_short_setters()
    |> do_reorder_operators(@operators, [])
  end

  Enum.each(@short_setters, fn s ->
    defp expand_short_setters([<<"$", _::binary>> = var, unquote(s) | t]) do
      operator = String.slice(unquote(s), 0, 1)
      [var, "=", var, operator, "(" | t ++ [")"]]
    end
  end)

  defp expand_short_setters(line), do: line

  defp insert_array_scopes(["[" | t], acc) do
    insert_array_scopes(t, ["[", "(" | acc])
  end

  defp insert_array_scopes(["]" | t], acc) do
    insert_array_scopes(t, [")", "]" | acc])
  end

  defp insert_array_scopes([h | t], acc) do
    insert_array_scopes(t, [h | acc])
  end

  defp insert_array_scopes([], acc) do
    Enum.reverse(acc)
  end

  defp do_reorder_operators([token | t], [op | _] = ops, acc)
       when op == token do
    acc = insert_operator(acc, token, [], 0)
    {:ok, t_count} = close_scope(t, 0, 0)
    t = List.insert_at(t, t_count, ")")
    do_reorder_operators(t, ops, ["," | acc])
  end

  defp do_reorder_operators([token | t], ops, acc) do
    do_reorder_operators(t, ops, [token | acc])
  end

  defp do_reorder_operators([], [_op | top], acc) do
    do_reorder_operators(Enum.reverse(acc), top, [])
  end

  defp do_reorder_operators([], [], acc) do
    Enum.reverse(acc)
  end

  defp close_scope(["(" | t], in_count, token_count) do
    close_scope(t, in_count + 1, token_count + 1)
  end

  defp close_scope([")" | t], in_count, token_count) when in_count > 0 do
    close_scope(t, in_count - 1, token_count + 1)
  end

  defp close_scope([_ | t], in_count, token_count) when in_count > 0 do
    close_scope(t, in_count, token_count + 1)
  end

  Enum.each(@operators, fn op ->
    defp close_scope([unquote(op) | t], in_count, token_count) do
      close_scope(t, in_count, token_count + 1)
    end
  end)

  defp close_scope(_, 0, token_count) do
    {:ok, token_count + 1}
  end

  defp close_scope([], _, token_count) do
    {:ok, token_count}
  end

  defp insert_operator([], operator, acc, 0) do
    [operator | acc]
  end

  defp insert_operator(["(" | t], operator, acc, 1) do
    insert_operator_skip(["(", "/" <> operator, "(" | acc], t)
  end

  defp insert_operator(["(" | t], operator, acc, in_count) do
    insert_operator(t, operator, ["(" | acc], in_count - 1)
  end

  defp insert_operator([")" | t], operator, acc, in_count) do
    insert_operator(t, operator, [")" | acc], in_count + 1)
  end

  defp insert_operator([h | t], operator, acc, in_count) when in_count > 0 do
    insert_operator(t, operator, [h | acc], in_count)
  end

  defp insert_operator([<<".", _::binary>> = h | t], operator, acc, in_count) do
    insert_operator(t, operator, [h | acc], in_count)
  end

  defp insert_operator([left | t], operator, acc, 0) do
    insert_operator_skip(["(", "/" <> operator, left | acc], t)
  end

  defp insert_operator_skip(acc, [h | t]) do
    insert_operator_skip([h | acc], t)
  end

  defp insert_operator_skip(acc, []) do
    Enum.reverse(acc)
  end

  # gen_ast = Generate AST
  defp gen_ast(["def", str_proc_name], _t_lines, config) do
    proc_name = String.to_atom(str_proc_name)

    cur_proces =
      config.prog.procedures
      |> Map.put(proc_name, [])

    cur_prog =
      config.prog
      |> Map.put(:procedures, cur_proces)

    new_config =
      config
      |> Map.put(:proc, proc_name)
      |> Map.put(:prog, cur_prog)

    {:ok, nil, new_config}
  end

  defp gen_ast(["if" | if_data], t_lines, config) do
    case find_end_else(t_lines) do
      {:ok, skip_amount} ->
        {:ok, if_cond_ast, config} = gen_ast(if_data, t_lines, config)

        config =
          config
          |> Map.put(:end_asts, [{:noop, nil} | config.end_asts])
          |> Map.put(:clauses, [{:if, [ln: config.ln]} | config.clauses])

        {:ok,
         {{FusionDsl.Kernel, :jump_not}, [ln: config.ln],
          [if_cond_ast, skip_amount]}, config}

      :not_found ->
        raise("'end' for if not found!")
    end
  end

  defp gen_ast(["else"], t_lines, config) do
    case find_end_else(t_lines, 0, 0, false) do
      {:ok, skip_amount} ->
        {:ok, {:jump, [ln: config.ln], [skip_amount]}, config}

      :not_found ->
        raise("'end' for else not found!")
    end
  end

  defp gen_ast(["(", "while" | while_data], t_lines, config) do
    case find_end_else(t_lines, 0, 0, false) do
      {:ok, skip_amount} ->
        {:ok, [while_cond_ast | extra], config} =
          while_data
          |> get_scope_tokens([], 0)
          |> split_args([], [], 0)
          |> gen_args_ast(t_lines, config, [])

        opt =
          case extra do
            ["unsafe" | _] -> false
            _ -> true
          end

        config =
          config
          |> Map.put(:end_asts, [
            {:jump_to, [config.ln, 0, opt]} | config.end_asts
          ])
          |> Map.put(:clauses, [{:loop, [config.ln, 0, opt]} | config.clauses])

        {:ok,
         {{FusionDsl.Kernel, :jump_not}, [ln: config.ln],
          [while_cond_ast, skip_amount]}, config}

      :not_found ->
        raise("'end' for while not found!")
    end
  end

  defp gen_ast(["break"], t_lines, config) do
    inn_init =
      Enum.reduce(config.clauses, 0, fn x, acc ->
        case x do
          {:loop, _} ->
            acc

          _ ->
            acc + 1
        end
      end)

    case find_end_else(t_lines, inn_init, 0, false) do
      {:ok, skip_amount} ->
        {:ok, {:jump, [ln: config.ln], [skip_amount]}, config}

      :not_found ->
        raise("'end' for loop not found!")
    end
  end

  defp gen_ast(["continue"], _, config) do
    {:loop, jump_to_args} =
      Enum.find(config.clauses, nil, fn x ->
        case x do
          {:loop, _args} ->
            true

          _ ->
            nil
        end
      end)

    {:ok, {:jump_to, [ln: config.ln], jump_to_args}, config}
  end

  defp gen_ast(["return"], _, config) do
    {:ok, {:return, [ln: config.ln], nil}, config}
  end

  # Variables
  defp gen_ast([<<"$", var::binary>> | _t], _t_lines, config) do
    {:ok, {:var, [ln: config.ln], [var]}, config}
  end

  # Get env variables
  defp gen_ast([<<"@", var::binary>> | _t], _t_lines, config) do
    {:ok, {{FusionDsl.Kernel, :get_system}, [ln: config.ln], [var]}, config}
  end

  # Goto operation
  defp gen_ast(["goto", proc_name], _t_lines, config) do
    {:ok, {:goto, [ln: config.ln], [String.to_atom(proc_name)]}, config}
  end

  # Goto operation
  defp gen_ast(["nil"], _t_lines, config) do
    {:ok, nil, config}
  end

  # Strings
  defp gen_ast([<<"'", str::binary>> | _t], _t_lines, config) do
    {:ok, String.slice(str, 0, String.length(str) - 1), config}
  end

  # Json objects
  defp gen_ast([<<"%'", str::binary>> | _t], _t_lines, config) do
    {:ok,
     {{FusionDsl.Kernel, :json_decode}, [ln: config.ln],
      [String.slice(str, 0, String.length(str) - 1)]}, config}
  end

  # Numbers
  defp gen_ast([num | _t], _t_lines, config) when is_number(num) do
    {:ok, num, config}
  end

  # Numbers
  defp gen_ast([bool | _t], _t_lines, config) when is_boolean(bool) do
    {:ok, bool, config}
  end

  # Arrays
  defp gen_ast(["(", "[" | arr_data], t_lines, config) do
    {:ok, asts, config} =
      arr_data
      |> get_scope_tokens([], 0)
      |> split_args([], [], 0)
      |> gen_args_ast(t_lines, config, [])

    {:ok, {{FusionDsl.Kernel, :create_array}, [ln: config.ln], asts}, config}
  end

  Enum.each(@operators, fn op ->
    fun = @operator_names[op]

    defp gen_ast(["(", "/#{unquote(op)}" | args], t_lines, config) do
      {:ok, asts, config} =
        args
        |> get_scope_tokens([], 0)
        |> split_args([], [], 0)
        |> gen_args_ast(t_lines, config, [])

      {:ok, {{FusionDsl.Kernel, unquote(fun)}, [ln: config.ln], asts}, config}
    end
  end)

  Enum.each(@packages, fn {module, opts} ->
    pack_ids = apply(module, :list_functions, [])

    pack_name =
      case opts[:as] do
        nil ->
          module
          |> to_string
          |> String.split(".")
          |> List.last()

        name ->
          name
      end

    Enum.each(pack_ids, fn atom_id ->
      id = to_string(atom_id)

      defp gen_ast(
             ["(", <<unquote(pack_name), ":", unquote(id)>> | args],
             t_lines,
             config
           ) do
        {:ok, asts, config} =
          args
          |> get_scope_tokens([], 0)
          |> split_args([], [], 0)
          |> gen_args_ast(t_lines, config, [])

        {:ok,
         {{unquote(module), unquote(atom_id)},
          [ln: config.ln, package: unquote(module)], asts}, config}
      end
    end)
  end)

  defp gen_ast(["(" | args], t_lines, config) do
    sp_args =
      args
      |> get_scope_tokens([], 0)
      |> split_args([], [], 0)

    case sp_args do
      [single] ->
        gen_ast(single, t_lines, config)

      _ when is_list(sp_args) ->
        gen_args_ast(args, t_lines, config, [])
    end
  end

  # Operations that actualy does not do anything at runtime but ast
  # position matters
  Enum.each(@noops, fn noop ->
    defp gen_ast([unquote(noop) | _], _t_lines, config) do
      {:ok, {:noop, [ln: config.ln], []}, config}
    end
  end)

  defp gen_ast(["end"], _t_lines, config) do
    [_ | tail_c] = config.clauses

    case config.end_asts do
      [] ->
        config = Map.put(config, :clauses, tail_c)
        {:ok, {:noop, [ln: config.ln], nil}, config}

      [{fun, args} | t] ->
        config =
          config
          |> Map.put(:end_asts, t)
          |> Map.put(:clauses, tail_c)

        {:ok, {fun, [ln: config.ln], args}, config}
    end
  end

  defp gen_args_ast([arg | t], t_lines, config, asts) do
    {:ok, ast, config} = gen_ast(arg, t_lines, config)
    gen_args_ast(t, t_lines, config, [ast | asts])
  end

  defp gen_args_ast([], _, config, asts) do
    {:ok, Enum.reverse(asts), config}
  end

  defp get_scope_tokens(["(" | t], acc, in_count) do
    get_scope_tokens(t, ["(" | acc], in_count + 1)
  end

  defp get_scope_tokens(["[" | t], acc, in_count) do
    get_scope_tokens(t, ["[" | acc], in_count + 1)
  end

  defp get_scope_tokens(["]" | _t], acc, 0) do
    Enum.reverse(acc)
  end

  defp get_scope_tokens([")" | _t], acc, 0) do
    Enum.reverse(acc)
  end

  defp get_scope_tokens([], acc, 0) do
    Enum.reverse(acc)
  end

  defp get_scope_tokens([")" | t], acc, in_count) do
    get_scope_tokens(t, [")" | acc], in_count - 1)
  end

  defp get_scope_tokens(["]" | t], acc, in_count) do
    get_scope_tokens(t, ["]" | acc], in_count - 1)
  end

  defp get_scope_tokens([token | t], acc, in_count) do
    get_scope_tokens(t, [token | acc], in_count)
  end

  defp split_args(["(" | t], acc, f_acc, in_count) do
    split_args(t, acc, ["(" | f_acc], in_count + 1)
  end

  defp split_args([")" | t], acc, f_acc, in_count) do
    split_args(t, acc, [")" | f_acc], in_count - 1)
  end

  defp split_args(["," | t], acc, f_acc, 0) do
    split_args(t, [Enum.reverse(f_acc) | acc], [], 0)
  end

  defp split_args([arg | t], acc, f_acc, in_count) do
    split_args(t, acc, [arg | f_acc], in_count)
  end

  defp split_args([], acc, f_acc, 0) do
    Enum.reverse([Enum.reverse(f_acc) | acc])
  end

  # c_else = catch else: determines if else should be catched or not
  defp find_end_else(
         token_list,
         inner_clause_count \\ 0,
         acc \\ 0,
         c_else \\ true
       )

  Enum.each(@clause_beginners, fn cl ->
    defp find_end_else([[_, "(", unquote(cl) | _] | t], inn, acc, c_else) do
      find_end_else(t, inn + 1, acc + 1, c_else)
    end
  end)

  defp find_end_else([[_, "(", "else", ")"] | _t], 0, acc, true) do
    {:ok, acc + 1}
  end

  defp find_end_else([[_, "(", "end", ")"] | _t], 0, acc, _) do
    {:ok, acc + 1}
  end

  defp find_end_else([[_, "(", "end", ")"] | t], inn, acc, c_else)
       when inn > 0 do
    find_end_else(t, inn - 1, acc + 1, c_else)
  end

  defp find_end_else([[_, "def", _]], _, _, _) do
    :not_found
  end

  defp find_end_else([_ | tail], inn, acc, c_else) do
    find_end_else(tail, inn, acc + 1, c_else)
  end

  defp find_end_else([], _, _, _) do
    :not_found
  end

  defp insert_ast_in_config(config, ast) do
    %{
      config
      | prog: %{
          config.prog
          | procedures: %{
              config.prog.procedures
              | config.proc => config.prog.procedures[config.proc] ++ [ast]
            }
        }
    }
  end
end
