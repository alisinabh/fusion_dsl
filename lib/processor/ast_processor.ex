defmodule FusionDsl.Processor.AstProcessor do
  @moduledoc """
  Functions for converting tokens to Abstract syntax trees

  ## Ast structure:

  ```
  {action_name_atom, [line_number], args_list}
  ```
  """

  alias FusionDsl.Processor.Program

  @default_state %{
    proc: nil,
    ln: 0,
    prog: %Program{},
    end_asts: [],
    clauses: []
  }

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

  @functions [
    :rand,
    :goto,
    :to_number,
    :to_string,
    :int,
    :round,
    :not,
    :insert,
    :elem,
    :wait,
    :remove,
    :dispose,
    :contains,
    :index_of,
    :last_index_of,
    :length,
    :starts_with,
    :ends_with,
    :slice,
    :replace,
    :reverse,
    :regex,
    :regex_match,
    :regex_replace,
    :regex_run,
    :regex_scan,
    :json_decode,
    :json_encode
  ]

  @packages Application.get_env(:fusion_dsl, :packages, [])

  @doc """
  Generates an ast array of program

  ## Parameters
    - config: configuration of program
    - tokens: list of line splitted tokens
  """
  def generate_ast(config, tokens) do
    do_generate_ast(tokens, @default_state)
  end

  defp do_generate_ast([[line_number | raw_line] | t], state) do
    state = Map.put(state, :ln, line_number)
    line = reorder_line(raw_line)

    {:ok, ast, state} = gen_ast(line, t, state)

    case ast do
      nil ->
        do_generate_ast(t, state)

      ast ->
        ast_state = insert_ast_in_state(state, ast)
        do_generate_ast(t, ast_state)
    end
  end

  defp do_generate_ast([], state) do
    {:ok, state}
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
  defp gen_ast(["def", str_proc_name], _t_lines, state) do
    proc_name = String.to_atom(str_proc_name)

    cur_proces =
      state.prog.procedures
      |> Map.put(proc_name, [])

    cur_prog =
      state.prog
      |> Map.put(:procedures, cur_proces)

    new_state =
      state
      |> Map.put(:proc, proc_name)
      |> Map.put(:prog, cur_prog)

    {:ok, nil, new_state}
  end

  defp gen_ast(["if" | if_data], t_lines, state) do
    case find_end_else(t_lines) do
      {:ok, skip_amount} ->
        {:ok, if_cond_ast, state} = gen_ast(if_data, t_lines, state)

        state =
          state
          |> Map.put(:end_asts, [{:noop, nil} | state.end_asts])
          |> Map.put(:clauses, [{:if, [ln: state.ln]} | state.clauses])

        {:ok, {:jump_not, [ln: state.ln], [if_cond_ast, skip_amount]}, state}

      :not_found ->
        raise("'end' for if not found!")
    end
  end

  defp gen_ast(["else"], t_lines, state) do
    case find_end_else(t_lines, 0, 0, false) do
      {:ok, skip_amount} ->
        {:ok, {:jump, [ln: state.ln], [skip_amount]}, state}

      :not_found ->
        raise("'end' for else not found!")
    end
  end

  defp gen_ast(["(", "while" | while_data], t_lines, state) do
    case find_end_else(t_lines, 0, 0, false) do
      {:ok, skip_amount} ->
        {:ok, [while_cond_ast | extra], state} =
          while_data
          |> get_scope_tokens([], 0)
          |> split_args([], [], 0)
          |> gen_args_ast(t_lines, state, [])

        opt =
          case extra do
            ["unsafe" | _] -> false
            _ -> true
          end

        state =
          state
          |> Map.put(:end_asts, [
            {:jump_to, [state.ln, 0, opt]} | state.end_asts
          ])
          |> Map.put(:clauses, [{:loop, [state.ln, 0, opt]} | state.clauses])

        {:ok, {:jump_not, [ln: state.ln], [while_cond_ast, skip_amount]}, state}

      :not_found ->
        raise("'end' for while not found!")
    end
  end

  defp gen_ast(["break"], t_lines, state) do
    inn_init =
      Enum.reduce(state.clauses, 0, fn x, acc ->
        case x do
          {:loop, _} ->
            acc

          _ ->
            acc + 1
        end
      end)

    case find_end_else(t_lines, inn_init, 0, false) do
      {:ok, skip_amount} ->
        {:ok, {:jump, [ln: state.ln], [skip_amount]}, state}

      :not_found ->
        raise("'end' for loop not found!")
    end
  end

  defp gen_ast(["continue"], _, state) do
    {:loop, jump_to_args} =
      Enum.find(state.clauses, nil, fn x ->
        case x do
          {:loop, args} ->
            true

          _ ->
            nil
        end
      end)

    {:ok, {:jump_to, [ln: state.ln], jump_to_args}, state}
  end

  defp gen_ast(["return"], _, state) do
    {:ok, {:return, [ln: state.ln], nil}, state}
  end

  # Variables
  defp gen_ast([<<"$", var::binary>> | _t], _t_lines, state) do
    {:ok, {:var, [ln: state.ln], [var]}, state}
  end

  # Get env variables
  defp gen_ast([<<"@", var::binary>> | _t], _t_lines, state) do
    {:ok, {:get_system, [ln: state.ln], [var]}, state}
  end

  # Goto operation
  defp gen_ast(["goto", proc_name], _t_lines, state) do
    {:ok, {:goto, [ln: state.ln], [String.to_atom(proc_name)]}, state}
  end

  # Goto operation
  defp gen_ast(["nil"], _t_lines, state) do
    {:ok, nil, state}
  end

  # Strings
  defp gen_ast([<<"'", str::binary>> | _t], _t_lines, state) do
    {:ok, String.slice(str, 0, String.length(str) - 1), state}
  end

  # Json objects
  defp gen_ast([<<"%'", str::binary>> | _t], _t_lines, state) do
    {:ok,
     {:json, [ln: state.ln], [String.slice(str, 0, String.length(str) - 1)]},
     state}
  end

  # Numbers
  defp gen_ast([num | _t], _t_lines, state) when is_number(num) do
    {:ok, num, state}
  end

  # Numbers
  defp gen_ast([bool | _t], _t_lines, state) when is_boolean(bool) do
    {:ok, bool, state}
  end

  # Arrays
  defp gen_ast(["(", "[" | arr_data], t_lines, state) do
    {:ok, asts, state} =
      arr_data
      |> get_scope_tokens([], 0)
      |> split_args([], [], 0)
      |> gen_args_ast(t_lines, state, [])

    {:ok, {:create_array, [ln: state.ln], asts}, state}
  end

  Enum.each(@operators, fn op ->
    defp gen_ast(["(", "/#{unquote(op)}" | args], t_lines, state) do
      {:ok, asts, state} =
        args
        |> get_scope_tokens([], 0)
        |> split_args([], [], 0)
        |> gen_args_ast(t_lines, state, [])

      {:ok, {@operator_names[unquote(op)], [ln: state.ln], asts}, state}
    end
  end)

  Enum.each(@functions, fn fun ->
    defp gen_ast(["(", unquote(to_string(fun)) | args], t_lines, state) do
      {:ok, asts, state} =
        args
        |> get_scope_tokens([], 0)
        |> split_args([], [], 0)
        |> gen_args_ast(t_lines, state, [])

      {:ok, {unquote(fun), [ln: state.ln], asts}, state}
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
             state
           ) do
        {:ok, asts, state} =
          args
          |> get_scope_tokens([], 0)
          |> split_args([], [], 0)
          |> gen_args_ast(t_lines, state, [])

        {:ok,
         {{unquote(module), unquote(atom_id)},
          [ln: state.ln, package: unquote(module)], asts}, state}
      end
    end)
  end)

  defp gen_ast(["(" | args], t_lines, state) do
    sp_args =
      args
      |> get_scope_tokens([], 0)
      |> split_args([], [], 0)

    case sp_args do
      [single] ->
        gen_ast(single, t_lines, state)

      _ when is_list(sp_args) ->
        gen_args_ast(args, t_lines, state, [])
    end
  end

  # Operations that actualy does not do anything at runtime but ast
  # position matters
  Enum.each(@noops, fn noop ->
    defp gen_ast([unquote(noop) | _], _t_lines, state) do
      {:ok, {:noop, [ln: state.ln], []}, state}
    end
  end)

  defp gen_ast(["end"], _t_lines, state) do
    [_ | tail_c] = state.clauses

    case state.end_asts do
      [] ->
        state = Map.put(state, :clauses, tail_c)
        {:ok, {:noop, [ln: state.ln], nil}, state}

      [{fun, args} | t] ->
        state =
          state
          |> Map.put(:end_asts, t)
          |> Map.put(:clauses, tail_c)

        {:ok, {fun, [ln: state.ln], args}, state}
    end
  end

  defp gen_args_ast([arg | t], t_lines, state, asts) do
    {:ok, ast, state} = gen_ast(arg, t_lines, state)
    gen_args_ast(t, t_lines, state, [ast | asts])
  end

  defp gen_args_ast([], _, state, asts) do
    {:ok, Enum.reverse(asts), state}
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

  defp insert_ast_in_state(state, ast) do
    %{
      state
      | prog: %{
          state.prog
          | procedures: %{
              state.prog.procedures
              | state.proc => state.prog.procedures[state.proc] ++ [ast]
            }
        }
    }
  end
end
