defmodule IvroneDsl.Processor.AstProcessor do
  @moduledoc """
  Functions for converting tokens to Abstract syntax trees

  ## Ast structure:

  ```
  {action_name_atom, [line_number], args_list}
  ```
  """

  alias IvroneDsl.Processor.Program

  @default_state %{proc: nil, clause_if: nil, prog: %Program{}}

  @clause_beginners ["if"]
  @noops ["else", "noop"]
  @operators ["*", "/", "%", "+", "-", "=", "==", "<=", ">=", "<", ">"]

  @doc """
  Generates an ast array of program

  ## Parameters
    - config: configuration of program
    - tokens: list of line splitted tokens
  """
  def generate_ast(config, tokens) do
    do_generate_ast(tokens, @default_state)
  end

  defp do_generate_ast([[_line_number | raw_line] | t], state) do
    line = reorder_line(raw_line)
    {:ok, ast, new_state} = glast(line, t, state)

    case ast do
      nil ->
        do_generate_ast(t, new_state)

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
    |> Enum.reverse()
    |> do_reorder_operators(@operators, [])
  end

  defp do_reorder_operators([token | t], [op | top], acc) when op == token do
    t = insert_operator(t, token, [])
    {:ok, t_count} = close_scope(acc, 0, 0)
    acc = List.insert_at(acc, t_count, ")")
    do_reorder_operators(t, top, ["," | acc])
  end

  defp do_reorder_operators([token | t], ops, acc) do
    do_reorder_operators(t, ops, [token | acc])
  end

  defp do_reorder_operators([], [_op | top], acc) do
    do_reorder_operators(Enum.reverse(acc), top, [])
  end

  defp do_reorder_operators([], [], acc) do
    acc
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

  defp close_scope(_, 0, token_count) do
    {:ok, token_count + 1}
  end

  defp insert_operator([], operator, acc) do
    [operator | acc]
  end

  defp insert_operator([")" | t], operator, acc) do
    insert_operator(t, operator, [")" | acc])
  end

  defp insert_operator([<<".", _::binary>> = h | t], operator, acc) do
    insert_operator(t, operator, [h | acc])
  end

  defp insert_operator([left | t], operator, acc) do
    insert_operator_skip(["(", "/" <> operator, left | acc], t)
  end

  defp insert_operator_skip(acc, []) do
    Enum.reverse(acc)
  end

  defp insert_operator_skip(acc, [h | t]) do
    insert_operator_skip([h | acc], t)
  end

  # glast = Generate Line AST
  defp glast(["def", str_proc_name], _t_lines, state) do
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

  defp glast(["if" | if_data], t_lines, state) do
    case find_end_else(t_lines) do
      {:ok, skip_amount} ->
        if_data

      :not_found ->
        raise("'end' for if not found!")
    end
  end

  defp glast([<<"$", var::binary>>, "=" | t], t_lines, state) do
    {:ok, ast, state} = glast(t, t_lines, state)
    {:ok, {:set_var, [], [var, ast]}, state}
  end

  defp glast([<<"$", var::binary>> | t], _t_lines, state) do
    {:ok, {:get_var, [], [var]}, state}
  end

  defp glast([<<"'", str::binary>> | t], _t_lines, state) do
    {:ok, String.slice(str, 0, String.length(str) - 1), state}
  end

  defp glast([num | t], _t_lines, state) when is_number(num) do
    {:ok, num, state}
  end

  defp glast(["\=" | t], t_lines, state) do
  end

  defp find_end_else(token_list, inner_clause_count \\ 0, acc \\ 0)

  defp find_end_else([[_, "else"] | t], 0, acc) do
    {:ok, acc}
  end

  defp find_end_else([[_, "end"] | t], 0, acc) do
    {:ok, acc}
  end

  defp find_end_else([[_, "end"] | t], inn, acc) do
    find_end_else(t, inn - 1, acc + 1)
  end

  Enum.each(@clause_beginners, fn cl ->
    defp find_end_else([[_, unquote(cl) | _] | t], inn, acc) do
      find_end_else(t, inn + 1, acc + 1)
    end
  end)

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
