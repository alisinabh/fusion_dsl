defmodule FusionDsl.Helpers.FunctionNames do
  @moduledoc """
  This modules helps normalizing function names of packages so
  that they wont interfere with elixir or fusionDsl reserved
  keyworks.
  """

  @elixir_reserve [
    "when",
    "and",
    "or",
    "not",
    "in",
    "do",
    "end",
    "catch",
    "rescue",
    "after",
    "else"
  ]
  @invalid_keywords ["true", "false", "nil", "while", "def", "if"]

  @doc """
  Normalizes a word as atom or binary.

  If the world is in elixir reserved keywords it will return a new name
  with an `fn_` prefix.

  If the world is in FusionDSL reserced keywords it will raise an exception!

  ## Examples
      iex> FusionDsl.Helpers.FunctionNames.normalize!(:test)
      :test
      iex> FusionDsl.Helpers.FunctionNames.normalize!("test")
      "test"
  """
  def normalize(word)

  Enum.each(@invalid_keywords, fn bin_word ->
    word = String.to_atom(bin_word)

    def normalize!(unquote(bin_word)) do
      raise "You cannot use #{inspect(unquote(bin_word))} as your function name." <>
              "\nList of invalid function names: #{inspect(@invalid_keywords)}"
    end

    def normalize!(unquote(word)) do
      raise "You cannot use #{inspect(unquote(word))} as your function name." <>
              "\nList of invalid function names: #{inspect(@invalid_keywords)}"
    end
  end)

  Enum.each(@elixir_reserve, fn bin_word ->
    word = String.to_atom(bin_word)
    norm_bin = "fn_" <> bin_word
    norm = String.to_atom(norm_bin)

    def normalize!(unquote(bin_word)) do
      unquote(norm_bin)
    end

    def normalize!(unquote(word)) do
      unquote(norm)
    end
  end)

  def normalize!(fn_name), do: fn_name
end
