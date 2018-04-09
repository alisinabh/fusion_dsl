defmodule IvroneDsl.Processor.Lexer do
  @moduledoc """
  Tokenizer and normalizer for IVRONE DSL
  """

  @lang_ids [
    "if",
    "else",
    "do",
    "end",
    "nil",
    "play",
    "keycheck",
    "return",
    "rand"
  ]
  @lang_ops [
    ",",
    "+",
    "-",
    "/",
    "*",
    "==",
    "!=",
    "=",
    "!",
    "(",
    ")"
  ]
  @lang_var ["$", "@", "."]

  @r_header ~r/\A([A-Za-z0-9\-_]+)\:[ ]*(.+)\n/
  @r_lable ~r/\Adef[ \t]+([A-Za-z0-9\-_]+)\:[ \t]*\n/
  @r_number ~r/\A[0-9]+[\.]*[0-9]+/
  @r_string ~r/[^\\](\')/
  @r_var ~r/\A[A-Za-z0-9\_]+/
  @r_goto ~r/\Agoto[ \t]+([A-Za-z0-9\-_]+)/

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
    {:ok, headers, code} = tokenize_headers(raw_code, %{})
    {:ok, tokens} = do_tokenize(code, [])
    {:ok, headers, tokens}
  end

  # Normalizes string (Such as line endings)
  defp normalize(code) do
    String.replace(code, "\r\n", "\n")
  end

  # Headers finished
  defp tokenize_headers(<<"\n", code::binary>>, acc), do: {:ok, acc, code}

  # Headers process
  defp tokenize_headers(code, acc) do
    case Regex.run(@r_header, code) do
      [full_header, name, value] ->
        code = String.slice(code, String.length(full_header)..-1)

        tokenize_headers(
          code,
          Map.put(acc, String.to_atom(String.downcase(name)), value)
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
    defp do_tokenize(<<unquote(id), rest::binary>>, acc) do
      do_tokenize(rest, [unquote(id) | acc])
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

    defp do_tokenize_num(<<unquote(str), rest::binary>>, acc, neg) do
      num_cnt =
        case Regex.run(@r_number, rest, return: :index) do
          [{0, num_cnt}] ->
            num_cnt

          _ ->
            0
        end

      r_num = to_string(unquote(num)) <> String.slice(rest, 0, num_cnt)

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
  end)

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

  # handle strings
  defp do_tokenize(<<"'", rest::binary>>, acc) do
    do_tokenize_string(rest, acc, "'")
  end

  # handle json objects
  defp do_tokenize(<<"%'", rest::binary>>, acc) do
    do_tokenize_string(rest, acc, "%'")
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

  # Handles new line (Windows line ending)
  defp do_tokenize(<<"\r\n", rest::binary>>, acc) do
    do_tokenize(rest, ["\n" | acc])
  end

  # Ignores comment
  defp do_tokenize(<<"#", rest::binary>>, acc) do
    skip_line(rest, ["\n" | acc])
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
        {:error, acc, bin, "Unknown expression in line!"}
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
          rest
          |> String.slice(loc..-1)
          |> do_tokenize([string | acc])
        end

      _ ->
        {:error, acc, rest, "expected ' for end of string!"}
    end
  end

  # Skips a line until line ending or empty binary
  defp skip_line(<<"\n", _::binary>> = bin, acc), do: do_tokenize(bin, acc)

  defp skip_line(<<"\r\n", _::binary>> = bin, acc), do: do_tokenize(bin, acc)

  defp skip_line(<<>>, acc), do: do_tokenize(<<>>, acc)

  defp skip_line(<<_::utf8, rest::binary>>, acc), do: skip_line(rest, acc)

  defp inject(acc, x) do
    [x | acc]
  end

  defp p_line(acc) do
    "\nLine: #{get_line_number(acc)}"
  end

  defp get_line_number(acc) do
    Enum.reduce(acc, 1, fn l, acc ->
      if l == "\n" do
        acc + 1
      else
        acc
      end
    end)
  end
end
