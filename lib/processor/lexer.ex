defmodule IvroneDsl.Processor.Lexer do
  @moduledoc """
  Tokenizer and normalizer for IVRONE DSL
  """

  @lang_ids [
    "if",
    "else",
    "ends_with",
    "end",
    "play",
    "keycheck",
    "return",
    "rand",
    "json_encode",
    "json_decode",
    "db_find",
    "db_remove",
    "db_insert",
    "db_update",
    "to_number",
    "to_string",
    "int",
    "round",
    "not",
    "insert",
    "elem",
    "wait",
    "remove",
    "dispose",
    "for",
    "while",
    "break",
    "continue",
    "contains",
    "index_of",
    "last_index_of",
    "length",
    "starts_with",
    "ends_with",
    "slice",
    "replace",
    "reverse",
    "regex_match",
    "regex_replace",
    "regex_run",
    "regex_scan"
  ]
  @lang_ops [
    ",",
    "+=",
    "-=",
    "*=",
    "/=",
    "%=",
    "+",
    "-",
    "*",
    "/",
    "%",
    "==",
    "!=",
    "=",
    ">=",
    "<=",
    ">",
    "<",
    "(",
    ")",
    "[",
    "]",
    "and",
    "or",
    "&&",
    "||"
  ]
  @lang_var ["$", "@", "."]

  @r_header ~r/\A([A-Za-z0-9\-_]+)\:[ ]*(.+)\n/
  @r_lable ~r/\Adef[ \t]+([A-Za-z0-9\-_]+)\:[ \t]*\n/
  @r_number ~r/\A[0-9]+[\.]?[0-9]*/
  @r_string ~r/[^\\](\')/
  @r_var ~r/\A[\_]?[A-Za-z]+[A-Za-z0-9.\_]*/
  @r_goto ~r/\Agoto[ \t]+([A-Za-z0-9\-_]+)/
  @r_fnclosoure ~r/\A[ \t]+\(/
  @r_eol ~r/\n/

  @doc """
  Tokenizes an IVRONE Code

  Lexical types:
   - strings begining with quote ('): A literal string
   - strings begining with percent sign (%): A json object
   - strings: operators or identifires
   - number: A literal number. float or integer
  """
  @spec tokenize(String.t()) :: {:ok, Map.t(), List.t()} | {:error, String.t()}
  def tokenize(raw_code) do
    raw_code = normalize(raw_code)
    {:ok, headers, code} = tokenize_headers(raw_code, %{}, 1)
    {:ok, tokens} = do_tokenize(code, [])
    {:ok, headers, tokens}
  end

  @doc """
  Splits list of tokens to lists of lists by line with line number in beggining of each line
  """
  @spec split_by_lines(List.t(), Integer.t()) :: List.t()
  def split_by_lines(tokens, start_code_line \\ 1) do
    do_split_by_lines(tokens, [start_code_line], [], start_code_line)
  end

  defp do_split_by_lines(["\n" | t], [], acc, ln) do
    do_split_by_lines(t, [ln + 1], acc, ln + 1)
  end

  defp do_split_by_lines(["\n" | t], [_], acc, ln) do
    do_split_by_lines(t, [ln + 1], acc, ln + 1)
  end

  defp do_split_by_lines(["\n" | t], split_acc, acc, ln) do
    split_acc = Enum.reverse(split_acc)
    do_split_by_lines(t, [ln + 1], [split_acc | acc], ln + 1)
  end

  defp do_split_by_lines([token | t], split_acc, acc, ln) do
    do_split_by_lines(t, [token | split_acc], acc, ln)
  end

  defp do_split_by_lines([], [], acc, _ln) do
    Enum.reverse(acc)
  end

  defp do_split_by_lines([], [_], acc, ln) do
    do_split_by_lines([], [], acc, ln)
  end

  defp do_split_by_lines([], split_acc, acc, ln) do
    do_split_by_lines([], [], [split_acc | acc], ln)
  end

  # Normalizes string (Such as line endings)
  defp normalize(code) do
    code = String.replace(code, "\r\n", "\n")

    #
    if String.ends_with?(code, "\n") do
      # {:ok, env} = IvroneDsl.Runtime.Enviornment.prepare_env()
      # IvroneDsl.Runtime.Executor.execute(ast_data.prog, env)
      code
    else
      code <> "\n"
    end
  end

  # Headers finished
  defp tokenize_headers(<<"\n", code::binary>>, acc, ln) do
    {:ok, Map.put(acc, :start_code, ln + 1), code}
  end

  # Headers process
  defp tokenize_headers(code, acc, ln) do
    case Regex.run(@r_header, code) do
      [full_header, name, value] ->
        code = String.slice(code, String.length(full_header)..-1)

        tokenize_headers(
          code,
          Map.put(acc, String.to_atom(String.downcase(name)), value),
          ln + 1
        )

      _ ->
        {:error, :unknown_header, code}
    end
  end

  # Tokenize finished!
  defp do_tokenize(<<>>, acc) do
    {:ok, Enum.reverse(acc)}
  end

  # Handle Lang identifires
  Enum.each(@lang_ids, fn id ->
    defp do_tokenize(<<unquote(id), "(", rest::binary>>, acc) do
      cond do
        Regex.match?(@r_fnclosoure, rest) ->
          do_tokenize(rest, [unquote(id) | acc])

        true ->
          do_tokenize(rest, [unquote(id), "(" | acc])
      end
    end

    defp do_tokenize(<<unquote(id), rest::binary>>, acc) do
      cond do
        Regex.match?(@r_fnclosoure, rest) ->
          do_tokenize(rest, [unquote(id) | acc])

        true ->
          do_tokenize(inject_ending(rest), [unquote(id), "(" | acc])
      end
    end
  end)

  # Handle numbers
  Enum.each(0..9, fn num ->
    str = to_string(num)

    defp do_tokenize(<<"-", unquote(str), rest::binary>>, acc) do
      do_tokenize_num(unquote(str) <> rest, acc, true)
    end

    defp do_tokenize(<<unquote(str), rest::binary>>, acc) do
      do_tokenize_num(unquote(str) <> rest, acc, false)
    end
  end)

  # handle json objects
  defp do_tokenize(<<"%'", rest::binary>>, acc) do
    do_tokenize_string(rest, acc, "%'")
  end

  # Handle operators
  Enum.each(@lang_ops, fn op ->
    defp do_tokenize(<<unquote(op), rest::binary>>, acc) do
      do_tokenize(rest, [unquote(op) | acc])
    end
  end)

  # Variable indicators
  Enum.each(@lang_var, fn var ->
    defp do_tokenize(<<unquote(var), rest::binary>>, acc) do
      case Regex.run(@r_var, rest) do
        [var_name] ->
          rest = String.slice(rest, String.length(var_name)..-1)
          do_tokenize(rest, [unquote(var) <> var_name | acc])

        _ ->
          {:error, acc, rest, "Bad variable name!"}
      end
    end
  end)

  defp do_tokenize(<<"true", rest::binary>>, acc) do
    do_tokenize(rest, [true | acc])
  end

  defp do_tokenize(<<"false", rest::binary>>, acc) do
    do_tokenize(rest, [false | acc])
  end

  # handle empty strings
  defp do_tokenize(<<"''", rest::binary>>, acc) do
    do_tokenize(rest, ["''" | acc])
  end

  # handle strings
  defp do_tokenize(<<"'", rest::binary>>, acc) do
    do_tokenize_string(rest, acc, "'")
  end

  # Ignores space
  defp do_tokenize(<<" ", rest::binary>>, acc) do
    do_tokenize(rest, acc)
  end

  # Ignores tab
  defp do_tokenize(<<"\t", rest::binary>>, acc) do
    do_tokenize(rest, acc)
  end

  # Handles new line (Linux line ending)
  defp do_tokenize(<<"\n", rest::binary>>, acc) do
    do_tokenize(rest, ["\n" | acc])
  end

  # Ignores comment
  defp do_tokenize(<<"#", rest::binary>>, acc) do
    skip_line(rest, acc)
  end

  defp do_tokenize(<<"nil", rest::binary>>, acc) do
    do_tokenize(rest, ["nil" | acc])
  end

  # Unmatched binary
  defp do_tokenize(bin, acc) do
    cond do
      Regex.match?(@r_lable, bin) ->
        # Lable
        [_, lable] = Regex.run(@r_lable, bin)

        acc =
          acc
          |> inject("def")
          |> inject(lable)

        skip_line(bin, acc)

      Regex.match?(@r_goto, bin) ->
        # Goto instruction
        [_, destination] = Regex.run(@r_goto, bin)

        acc =
          acc
          |> inject("goto")
          |> inject(destination)

        skip_line(bin, acc)

      true ->
        # Unmatched code. error will be generated!
        {:error, acc, bin, "Unknown expression in line! #{Enum.count(acc)}"}
    end
  end

  defp do_tokenize_string(rest, acc, add) do
    case Regex.run(@r_string, rest, return: :index) do
      [_, {loc, _}] ->
        loc = loc + 1
        string = add <> String.slice(rest, 0, loc)

        if String.contains?(string, "\n") do
          {:error, acc, rest, "expected ' for end of string!"}
        else
          {cmp_string, _} = Code.eval_string("\"" <> String.replace(string, "\"", "\\\"") <> "\"")

          rest
          |> String.slice(loc..-1)
          |> do_tokenize([cmp_string | acc])
        end

      _ ->
        {:error, acc, rest, "expected ' for end of string!"}
    end
  end

  defp do_tokenize_num(rest, acc, neg) do
    num_cnt =
      case Regex.run(@r_number, rest, return: :index) do
        [{0, num_cnt}] ->
          num_cnt

        _ ->
          0
      end

    r_num = String.slice(rest, 0, num_cnt)

    final_num =
      cond do
        String.contains?(r_num, ".") ->
          {f_num, ""} = Float.parse(r_num)
          f_num

        true ->
          {i_num, ""} = Integer.parse(r_num)
          i_num
      end

    final_num =
      if neg do
        -1 * final_num
      else
        final_num
      end

    do_tokenize(String.slice(rest, num_cnt..-1), [final_num | acc])
  end

  # Skips a line until line ending or empty binary
  defp skip_line(<<"\n", _::binary>> = bin, acc), do: do_tokenize(bin, acc)

  defp skip_line(<<>>, acc), do: do_tokenize(<<>>, acc)

  defp skip_line(<<_::utf8, rest::binary>>, acc), do: skip_line(rest, acc)

  defp inject(acc, x) do
    [x | acc]
  end

  defp inject_ending(string) do
    Regex.replace(@r_eol, string, ")\n", global: false)
  end
end
