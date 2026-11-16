defmodule AlmacenTest do
  use ExUnit.Case, async: false

  setup do
    Emergencias.reiniciar_todo()
    :ok
  end

  test "guarda y lee un CSV con títulos, aunque los textos tengan comas" do
    {:ok, r1} = Recurso.crear("R1", "agua", "50", "litros", "bodega, sur", "centro", "Agua potable")
    {:ok, r2} = Recurso.crear("R2", "alimentos", "20", "kg", "albergue_1", "", "")

    Almacen.escribir_csv([r1, r2], "prueba.csv", Recurso.titulos(), &Recurso.a_campos/1)
    leidos = Almacen.leer_csv("prueba.csv", &Recurso.de_campos/1)

    assert leidos == [r1, r2]
    assert File.read!(Almacen.ruta("prueba.csv")) =~ "codigo,nombre,categoria"
  end

  test "si el archivo no existe se devuelve una lista vacía" do
    assert Almacen.leer_csv("no_existe.csv", &Recurso.de_campos/1) == []
  end

  test "las líneas dañadas se ignoran" do
    File.write!(Almacen.ruta("danado.csv"), "titulos\n\"R1\",\"agua\"\n\n" <> Serializador.a_linea(["R2", "agua", "agua", 5, "l", "x", ""]))
    assert [%Recurso{codigo: "R2"}] = Almacen.leer_csv("danado.csv", &Recurso.de_campos/1)
  end
end
