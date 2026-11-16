defmodule AlbergueTest do
  use ExUnit.Case, async: true

  test "un albergue no supera su capacidad ni repite personas" do
    {:ok, a} = Albergue.crear("A1", "Norte", "norte", "1")
    {:ok, a} = Albergue.ingresar(a, "123")
    assert {:error, _} = Albergue.ingresar(a, "123")
    assert {:error, _} = Albergue.ingresar(a, "456")
  end

  test "la capacidad debe ser un número mayor que cero" do
    assert {:error, _} = Albergue.crear("A2", "Sur", "sur", "0")
    assert {:error, _} = Albergue.crear("A3", "Sur", "sur", "muchos")
  end
end
