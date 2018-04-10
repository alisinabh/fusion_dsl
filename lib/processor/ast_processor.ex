defmodule IvroneDsl.Processor.AstProcessor do
  @moduledoc """
  Functions for converting tokens to Abstract syntax trees

  ## Ast structure:

  ```
  {action_name_atom, [line_number], args_list}
  ```
  """

  @default_state %{proc: nil, clause_if: nil}

  @clause_beginners ["if"]
  @noops ["else", "noop"]

  @doc """
  Generates an ast array of program

  ## Parameters
    - config: configuration of program
    - tokens: list of line splitted tokens
  """
  def generate_ast(config, tokens) do
    do_generate_ast(tokens, [], @default_state)
  end

  defp do_generate_ast([line | t], acc, state) do
    {:ok, ast, new_state} = glast(line, t, state)

    new_acc =
      case ast do
        nil -> acc
        {_, _, _} -> [ast | acc]
      end

    do_generate_ast(t, new_acc, new_state)
  end

  defp glast([ln, "def", proc_name], _tail, state) do
    {:ok, nil, Map.put(state, :proc, to_atom(proc_name))}
  end

  defp glast([ln, "if" | if_data], tail, state) do
    case find_end_else(tail) do
      {:ok, skip_amount} ->
        if_data

      :not_found ->
        raise("'end' for if not found! Line: #{ln}")
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
end
