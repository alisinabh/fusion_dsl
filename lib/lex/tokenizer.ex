defmodule IvroneDsl.Lex.Tokenizer do

  @lang_ids ["if", "else", "do", "end", "play", "keycheck", "goto", "return", "rand"]
  @lang_ops [",", "+", "-", "/", "*", "=", "==", "!=", "!", "{", "}", "@", "$", "(", ")"]

  def tokenize(code) do
    do_tokenize(code, [])
  end

  Enum.each(@lang_ids, fn id ->
    defp do_tokenize(<<unquote(id), rest::binary>>, acc) do
      do_tokenize(rest, acc ++ [unquote(id)])
    end
  end)

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
        case Regex.run(~r/\A[0-9.]+/, rest, return: :index) do
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

  Enum.each(@lang_ops, fn op ->
    defp do_tokenize(<<unquote(op), rest::binary>>, acc) do
      do_tokenize(rest, acc ++ [unquote(op)])
    end
  end)

  defp do_tokenize(<<"'", rest::binary>>, acc) do
    case Regex.run(~r/[^\\](\')/, rest, return: :index) do
      [_, {loc, _}] ->
        loc = loc + 1
        string = "'" <> String.slice(rest, 0, loc)

        if String.contains?(string, "\n") do
          raise("expected ' for end of string!#{p_line(acc)}")
        end

        rest
        |> String.slice(loc..-1)
        |> do_tokenize(acc ++ [string])
      res ->
        raise("expected ' for end of string!#{p_line(acc)}")
    end
  end

  defp do_tokenize(<<" ", rest::binary>>, acc) do
    do_tokenize(rest, acc)
  end

  defp do_tokenize(<<"\t", rest::binary>>, acc) do
    do_tokenize(rest, acc)
  end

  defp do_tokenize(<<"\n", rest::binary>>, acc) do
    do_tokenize(rest, acc ++ ["\n"])
  end

  defp do_tokenize(<<"\r\n", rest::binary>>, acc) do
    do_tokenize(rest, acc ++ ["\n"])
  end

  defp do_tokenize(<<>>, acc) do
    IO.puts "Tokenize success!"
    acc
  end

  defp do_tokenize(bin, acc) do
    IO.puts "Tokenize error: " <> bin
    acc
  end

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
