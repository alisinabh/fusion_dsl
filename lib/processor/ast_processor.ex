defmodule IvroneDsl.Processor.AstProcessor do
  @moduledoc """
  Functions for converting tokens to Abstract syntax trees

  ## Ast structure:

  ```
  {action_name_atom, [line_number], args_list}
  ```
  """

  alias IvroneDsl.Processor.Program

  @default_state %{proc: nil, ln: 0, prog: %Program{}}

  @clause_beginners ["if"]
  @noops ["end", "else", "noop"]
  @operators ["*", "/", "%", "+", "-", "==", "!=", "<=", ">=", "<", ">", "="]
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
    "=" => :set
  }

  @functions [:play, :keycheck, :rand, :db_find, :db_insert, :db_update, :db_remove, :goto]

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
    |> do_reorder_operators(@operators, [])
  end

  defp do_reorder_operators([token | t], [op | _] = ops, acc) when op == token do
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

  # defp insert_operator(["," | t], operator, acc, in_count) do
  #   insert_operator(t, operator, ["," | acc], in_count)
  # end

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
        {:ok, {:jump_not, [ln: state.ln], [if_cond_ast, skip_amount]}, state}

      :not_found ->
        raise("'end' for if not found!")
    end
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
    {:ok, {:json, [ln: state.ln], String.slice(str, 0, String.length(str) - 1)}, state}
  end

  # Numbers
  defp gen_ast([num | _t], _t_lines, state) when is_number(num) do
    {:ok, num, state}
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

  defp gen_ast(["(", "!" | args], t_lines, state) do
    {:ok, asts, state} =
      args
      |> get_scope_tokens([], 0)
      |> split_args([], [], 0)
      |> gen_args_ast(t_lines, state, [])

    {:ok, {:not, [ln: state.ln], asts}, state}
  end

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

  # Operations that actualy does not do anything at runtime
  Enum.each(@noops, fn noop ->
    defp gen_ast([unquote(noop) | _], _t_lines, state) do
      {:ok, {:noop, [ln: state.ln], []}, state}
    end
  end)

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

  defp get_scope_tokens([")" | _t], acc, 0) do
    Enum.reverse(acc)
  end

  defp get_scope_tokens([], acc, 0) do
    Enum.reverse(acc)
  end

  defp get_scope_tokens([")" | t], acc, in_count) do
    get_scope_tokens(t, [")" | acc], in_count - 1)
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

  defp find_end_else(token_list, inner_clause_count \\ 0, acc \\ 0)

  Enum.each(@clause_beginners, fn cl ->
    defp find_end_else([[_, "(", unquote(cl) | _] | t], inn, acc) do
      find_end_else(t, inn + 1, acc + 1)
    end
  end)

  defp find_end_else([[_, "(", "else", ")"] | _t], 0, acc) do
    {:ok, acc + 1}
  end

  defp find_end_else([[_, "(", "end", ")"] | _t], 0, acc) do
    {:ok, acc + 1}
  end

  defp find_end_else([[_, "(", "end", ")"] | t], inn, acc) when inn > 0 do
    find_end_else(t, inn - 1, acc + 1)
  end

  defp find_end_else([[_, "def", _]], _, _) do
    :not_found
  end

  defp find_end_else([_ | tail], inn, acc) do
    find_end_else(tail, inn, acc + 1)
  end

  defp find_end_else([], _, _) do
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
