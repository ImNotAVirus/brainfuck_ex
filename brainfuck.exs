# Setup
Mix.install([{:nimble_parsec, "~> 1.3"}])

# Code

defmodule Brainfuck.AST do
  @moduledoc """
  TODO
  """

  import NimbleParsec

  whitespace = ignore(ascii_string([?\s, ?\n], min: 1))
  inc_ptr = string(">") |> unwrap_and_tag(:inc_ptr)
  dec_ptr = string("<") |> unwrap_and_tag(:dec_ptr)
  inc = string("+") |> unwrap_and_tag(:inc)
  dec = string("-") |> unwrap_and_tag(:dec)
  putc = string(".") |> unwrap_and_tag(:putc)
  getc = string(",") |> unwrap_and_tag(:getc)

  defcombinatorp(
    :loop,
    ignore(string("["))
    |> repeat(choice([parsec(:loop), whitespace, inc_ptr, dec_ptr, inc, dec, putc, getc]))
    |> ignore(string("]"))
    |> tag(:loop)
  )

  ins = choice([parsec(:loop), whitespace, inc_ptr, dec_ptr, inc, dec, putc, getc])
  ast = repeat(ins) |> eos() |> map(:unwrap_op)

  defparsec(:parse_ast, ast)

  def string_to_ast(brainfuck) do
    case parse_ast(brainfuck) do
      {:ok, ast, "", _, _, _} -> ast
      {:error, msg, rest, _context, _, _} -> {:error, msg, rest}
    end
  end

  ## Helpers

  defp unwrap_op({op, char}) when is_binary(char), do: op
  defp unwrap_op({:loop, ins}), do: {:loop, Enum.map(ins, &unwrap_op/1)}
end

defmodule Brainfuck.Interpreter.VM do
  @moduledoc """
  TODO
  """

  alias __MODULE__
  import Bitwise, only: [{:&&&, 2}]

  @default_mem_size 30_000

  defstruct ptr: 0, mem: []

  ## Public API

  def new() do
    %VM{mem: List.duplicate(0, @default_mem_size)}
  end

  def run(vm, ast) do
    Enum.reduce(ast, vm, &exec/2)
  end

  ## Helpers

  defp exec(:inc, vm), do: %VM{vm | mem: List.update_at(vm.mem, vm.ptr, &inc_int/1)}
  defp exec(:dec, vm), do: %VM{vm | mem: List.update_at(vm.mem, vm.ptr, &dec_int/1)}
  defp exec(:inc_ptr, vm), do: %VM{vm | ptr: inc_ptr(vm.ptr)}
  defp exec(:dec_ptr, vm), do: %VM{vm | ptr: dec_ptr(vm.ptr)}
  defp exec(:getc, vm), do: %VM{vm | mem: List.insert_at(vm.mem, vm.ptr, getc())}
  defp exec(:putc, vm), do: vm.mem |> Enum.at(vm.ptr) |> List.wrap() |> IO.write() && vm

  defp exec({:loop, ins}, vm) do
    case Enum.at(vm.mem, vm.ptr) do
      0 -> vm
      _ -> vm |> run(ins) |> then(&exec({:loop, ins}, &1))
    end
  end

  defp inc_int(n), do: n + 1 &&& 0xFF
  defp dec_int(n), do: n - 1 &&& 0xFF
  defp inc_ptr(n), do: if(n + 1 < @default_mem_size, do: n + 1, else: raise("out of memory"))
  defp dec_ptr(n), do: if(n > 0, do: n - 1, else: raise("out of memory"))
  defp getc(), do: if((c = IO.getn(nil)) == :eof, do: 0, else: c)
end

defmodule Brainfuck.Interpreter do
  @moduledoc """
  TODO
  """

  alias Brainfuck.AST
  alias Brainfuck.Interpreter.VM

  def run(brainfuck) do
    ast = AST.string_to_ast(brainfuck)
    vm = VM.new()

    VM.run(vm, ast)
  end
end

# Exec

code = File.read!("examples/helloworld.bf")
Brainfuck.Interpreter.run(code)
