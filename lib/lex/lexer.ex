defmodule IvroneDsl.Lex.Lexer do
  @moduledoc """
  Tokenizer (or lexer) of the IVRONE dsl
  """

  # alias IvroneDsl.Lex.Program
  # alias IvroneDsl.Lex.Action
  #
  # @lang_ids ["if", "else", "do", "end", "play", "keycheck", "goto", "return"]
  # @lang_ops [",", "+", "=", "==", "!=", "!", "{", "}"]
  # @lang_immidiate_ops ["@", "$"]
  #
  # @spec lex_string(String.t) :: :ok
  # def lex_string(code) do
  #   lines = prepare_code(code)
  #   lex_lines(lines, %Program{}, %{proc: nil, line: 0})
  # end
  #
  # def prepare_code(code) do
  #   code
  #   |> String.split(["\r\n", "\n"])
  #   |> Enum.reduce([], fn(x, acc) -> acc ++ [String.trim(x)] end)
  # end
  #
  # def lex_lines([raw_line | rest], prg, state) do
  #   first_op =
  #     raw_line
  #     |> String.split([" ", "\t"])
  #     |> List.first
  #
  #   data =
  #     raw_line
  #     |> String.slice(String.length(first_op)..-1)
  #     |> String.trim
  #     |> String.split(",")
  #     |> Enum.reduce([], fn(x, acc) -> acc ++ [String.trim(x)] end)
  #
  #   {:ok, alt_prg, alt_state} = lex(line_data, data, prg, state)
  #   lex_lines(rest, prg, %{state | line: state.line + 1})
  # end
  #
  # def lex_lines([], prg, _) do
  #   {:ok, prg}
  # end
  #
  # defp lex("play", args, prg, state) do
  #   ctx = prg.procedures[state.proc]
  #   action =
  #     case args do
  #       [] ->
  #         raise "Play must have file name!"
  #       [file] ->
  #         %Action{name: :play, args: [lex(file, )]}
  #     end
  # end
  #
  # defp lex_arg(arg) do
  #   cond do
  #
  #   end
  # end
end
