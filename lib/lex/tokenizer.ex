defmodule IvroneDsl.Lex.Tokenizer do

  @lang_ids ["if", "else", "do", "end", "play", "keycheck", "goto", "return", "rand"]
  @lang_ops [",", "+", "-", "/", "*", "=", "==", "!=", "!", "{", "}", "@", "$", "(", ")"]

  @r_lable ~r/(\A[A-Za-z0-9-_]+)\:[ \t]*\n/
  @r_number ~r/\A[0-9.]+/
  @r_string ~r/[^\\](\')/
  @r_header ~r/[A-Za-z0-9_]+\: [A-Za-z0-9.\"\']\n/

  @doc """
  Tokenizes an IVRONE Code
  """
  def tokenize(raw_code) do
    raw_code = normalize(raw_code)
    {:ok, config, code} = tokenize_headers(raw_code, %{})
    {:ok, tokens} = do_tokenize(code, [])
  end

  defp normalize(code) do
    String.replace_leading(code, "\r\n", "\n")
  end

  defp tokenize_headers(code, acc) do
    [format | _] = String.split(binary, ["\n", "\r\n"])
    rest =
  end

  # Handle Lang identifires
  Enum.each(@lang_ids, fn id ->
    defp do_tokenize(<<unquote(id), rest::binary>>, acc) do
      do_tokenize(rest, acc ++ [unquote(id)])
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
      do_tokenize(String.slice(rest, num_cnt+1..-1), acc ++ [final_num])
    end
  end)

  # Handle operators
  Enum.each(@lang_ops, fn op ->
    defp do_tokenize(<<unquote(op), rest::binary>>, acc) do
      do_tokenize(rest, acc ++ [unquote(op)])
    end
  end)

  # handle strings
  defp do_tokenize(<<"'", rest::binary>>, acc) do
    case Regex.run(@r_string, rest, return: :index) do
      [_, {loc, _}] ->
        loc = loc + 1
        string = "'" <> String.slice(rest, 0, loc)

        if String.contains?(string, "\n") do
          {:error, acc, rest, "expected ' for end of string!"}
        else
          rest
          |> String.slice(loc..-1)
          |> do_tokenize(acc ++ [string])
        end

      _ ->
        {:error, acc, rest, "expected ' for end of string!"}
    end
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
    do_tokenize(rest, acc ++ ["\n"])
  end

  # Handles new line (Windows line ending)
  defp do_tokenize(<<"\r\n", rest::binary>>, acc) do
    do_tokenize(rest, acc ++ ["\n"])
  end

  # Ignores comment
  defp do_tokenize(<<"#", rest::binary>>, acc) do
    skip_line(rest, acc ++ ["\n"])
  end

  # Tokenize finished!
  defp do_tokenize(<<>>, acc) do
    {:ok, acc}
  end

  # Unmatched binary
  defp do_tokenize(bin, acc) do
    cond do
      Regex.match?(@r_lable, bin) ->
        # Lable
        [_, lable] = Regex.run(@r_lable, bin)
        skip_line(bin, acc ++ [lable <> ":"])
      true ->
        {:error, acc, bin, "Unknown expression in line!"}
    end

  end

  # Skips a line until line ending or empty binary
  defp skip_line(<<"\n", _::binary>> = bin, acc), do:
    do_tokenize(bin, acc)

  defp skip_line(<<"\r\n", _::binary>> = bin, acc), do:
    do_tokenize(bin, acc)

  defp skip_line(<<>>, acc), do:
    do_tokenize(<<>>, acc)

  defp skip_line(<<_::utf8, rest::binary>>, acc), do:
    skip_line(rest, acc)

  defp p_line(acc) do
    "\nLine: #{get_line_number(acc)}"
  end

  defp get_line_number(acc) do
    Enum.reduce(acc, 1, fn (l, acc) ->
      if l == "\n" do
        acc + 1
      else
        acc
      end
    end)
  end

end
