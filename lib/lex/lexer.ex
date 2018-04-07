defmodule IvroneDsl.Lex.Lexer do
  @moduledoc """
  Tokenizer (or lexer) of the IVRONE dsl
  """

  @lang_ids ["if", "else", "do", "end"]
  @lang_ops [",", "+", "=", "==", "!=", "!", "{", "}"]
  @lang_immidiate_ops ["@", "$"]

  @spec lex_string(String.t) :: type
  def lex_string(code) do

  end

  defp normalize_code(code) do

  end

  defp lex(<<" ", rest::binary>>, prg, state) do
    lex(rest, prg, state)
  end

  defp lex(<<"\t", rest::binary>>, prg, state) do
    lex(rest, prg, state)
  end

  Enum.each(@lang_ids, fn id ->
    defp lex(<<unquote(id), rest::binary>>, prg, state) do

    end
  end)
end
