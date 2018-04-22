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

  # Enum.each(@operators, fn op ->
  #   defp do_reorder_operators([unquote(op) | t], acc) do
  #     t = insert_operator(t, unquote(op), [])
  #     do_reorder_operators(t, ["," | acc])
  #   end
  # end)

  defp do_reorder_operators([op | top], [token | t], acc) when op == token do
    t = insert_operator(t, token, [])
    do_reorder_operators(t, ["," | acc])
  end

  defp do_reorder_operators(ops, [token | t], acc) do
    do_reorder_operators(ops, t, [token | acc])
  end

  defp do_reorder_operators([_op | top], [], acc) do
    do_reorder_operators(top, Enum.reverse(acc), [])
  end

  defp do_reorder_operators([], _, acc) do
    acc
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
    insert_operator_skip(["/" <> operator, left | acc], t)
  end

  defp insert_operator_skip(acc, []) do
    Enum.reverse(acc)
  end

  defp insert_operator_skip(acc, [h | t]) do
    insert_operator_skip([h | acc], t)
  end

  # glast = Generate Line AST
  defp glast(["def", str_proc_name], _tail, state) do
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

  defp glast(["if" | if_data], tail, state) do
    case find_end_else(tail) do
      {:ok, skip_amount} ->
        if_data

      :not_found ->
        raise("'end' for if not found!")
    end
  end

  defp glast([<<"$", var::binary>>, "=" | t], tail, state) do
    {:ok, ast, state} = glast(t, tail, state)
    {:ok, {:set_var, [], [var, ast]}, state}
  end

  defp glast([<<"$", var::binary>> | t], _tail, state) do
    {:ok, {:get_var, [], [var]}, state}
  end

  defp glast([<<"'", str::binary>> | t], tail, state) do
    {:ok, String.slice(str, 0, String.length(str) - 1), state}
  end

  defp glast([num | t], tail, state) when is_number(num) do
    {:ok, num, state}
  end

  defp glast(["\=" | t], tail, state) do
  end

  defp seprate_args(["," | t], acc, arg_acc) do
    case acc do
      [] -> seprate_args(t, acc, [])
      _ -> seprate_args(t, acc ++ [arg_acc], [])
    end
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
