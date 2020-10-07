defmodule Elixirsh do
  import IEx, only: [dont_display_result: 0]
  import IEx.Helpers, warn: false

  def parse(input, opts, buffer) do
    input |> String.trim_trailing() |> OptionParser.split() |> parse(input, opts, buffer)
  end

  def parse([], _input, _opts, buffer) do
    {:ok, dont_display_result(), buffer}
  end

  def parse(["time" | rest], input, opts, buffer) do
    quoted =
      quote do
        {time, result} =
          :timer.tc(fn ->
            Elixirsh.parse(
              unquote(rest),
              unquote(String.trim_leading(input, "time ")),
              unquote(opts),
              unquote(buffer)
            )
          end)

        formatted_time =
          if time > 1000 do
            [time |> div(1000) |> Integer.to_string(), "ms"]
          else
            [Integer.to_string(time), "µs"]
          end

        IO.puts([?\n, "time    ", formatted_time])
        dont_display_result()
      end

    {:ok, quoted, ""}
  end

  def parse(["elixir", "-e", expr], _input, _opts, buffer) do
    Code.eval_string(expr)
    {:ok, quote(do: dont_display_result()), buffer}
  end

  def parse(["mix", "test" | rest], _input, _opts, buffer) do
    System.put_env("MIX_ENV", "test")
    Mix.Task.rerun("test", rest)
    {:ok, dont_display_result(), buffer}
  end

  def parse(["mix", task, rest], _input, _opts, buffer) do
    Mix.Task.rerun(task, rest)
    {:ok, dont_display_result(), buffer}
  end

  def parse([cmd | _], input, _opts, buffer) do
    if System.find_executable(cmd) do
      0 = Mix.shell().cmd(input)
      {:ok, dont_display_result(), buffer}
    else
      default_colors = [
        atom: :cyan,
        string: :green,
        list: :default_color,
        boolean: :magenta,
        nil: :magenta,
        tuple: :default_color,
        binary: :default_color,
        map: :default_color
      ]

      eval_opts = __ENV__ |> Map.take([:functions, :macros, :requires]) |> Enum.to_list()
      {result, _} = Code.eval_string(input, [], eval_opts)

      if result != dont_display_result() do
        IO.inspect(result, pretty: true, syntax_colors: default_colors)
      end

      {:ok, dont_display_result(), buffer}
    end
  end
end
