defmodule Usuario do
  @moduledoc "Usuario del sistema y validación de credenciales."

  @tipos ["ciudadano", "voluntario", "coordinador", "administrador"]
  @titulos "usuario,clave_cifrada,nombre,tipo,zona"

  defstruct usuario: "", clave_hash: "", nombre: "", tipo: "ciudadano", zona: ""

  def tipos(), do: @tipos
  def titulos(), do: @titulos

  def crear(usuario, clave, tipo, zona, nombre) do
    cond do
      usuario == "" or clave == "" ->
        {:error, "El usuario y la contraseña son obligatorios"}

      not Enum.member?(@tipos, tipo) ->
        {:error, "Tipo de usuario inválido. Use: #{Enum.join(@tipos, ", ")}"}

      zona == "" ->
        {:error, "La zona principal es obligatoria"}

      true ->
        nombre_final = if nombre == "", do: usuario, else: nombre

        {:ok,
         %Usuario{usuario: usuario, clave_hash: cifrar(clave), nombre: nombre_final, tipo: tipo, zona: zona}}
    end
  end

  def clave_valida?(%Usuario{clave_hash: hash}, clave), do: hash == cifrar(clave)

  # La contraseña no se guarda en texto plano (parecido a cookie.exs: :crypto + Base)
  defp cifrar(clave) do
    :crypto.hash(:sha256, clave)
    |> Base.encode16(case: :lower)
  end

  def a_campos(u), do: [u.usuario, u.clave_hash, u.nombre, u.tipo, u.zona]

  def de_campos([usuario, hash, nombre, tipo, zona]),
    do: {:ok, %Usuario{usuario: usuario, clave_hash: hash, nombre: nombre, tipo: tipo, zona: zona}}

  def de_campos(_), do: :error
end
