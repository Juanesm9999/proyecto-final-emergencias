defmodule UsuariosServer do
  @moduledoc "GenServer con los usuarios registrados (mapa usuario -> %Usuario{})."
  use GenServer

  @archivo "usuarios.csv"

  def start_link(_), do: GenServer.start_link(UsuariosServer, :ok, name: UsuariosServer)

  # Si el usuario no existe se registra; si existe se valida la contraseña
  def conectar(usuario, clave, tipo, zona, nombre),
    do: GenServer.call(UsuariosServer, {:conectar, usuario, clave, tipo, zona, nombre})

  def listar(), do: GenServer.call(UsuariosServer, :listar)
  def reiniciar(), do: GenServer.call(UsuariosServer, :reiniciar)

  def init(:ok) do
    usuarios =
      Almacen.leer_csv(@archivo, &Usuario.de_campos/1)
      |> Enum.into(%{}, fn u -> {u.usuario, u} end)

    {:ok, usuarios}
  end

  def handle_call({:conectar, usuario, clave, tipo, zona, nombre}, _from, usuarios) do
    case Map.get(usuarios, usuario) do
      nil -> registrar(usuarios, usuario, clave, tipo, zona, nombre)
      existente -> autenticar(usuarios, existente, clave)
    end
  end

  def handle_call(:listar, _from, usuarios), do: {:reply, Map.values(usuarios), usuarios}
  def handle_call(:reiniciar, _from, _usuarios), do: {:reply, :ok, %{}}

  defp registrar(usuarios, usuario, clave, tipo, zona, nombre) do
    case Usuario.crear(usuario, clave, tipo, zona, nombre) do
      {:ok, nuevo} ->
        usuarios = Map.put(usuarios, usuario, nuevo)
        Almacen.escribir_csv(Map.values(usuarios), @archivo, Usuario.titulos(), &Usuario.a_campos/1)
        {:reply, {:ok, nuevo, :registrado}, usuarios}

      error ->
        {:reply, error, usuarios}
    end
  end

  defp autenticar(usuarios, existente, clave) do
    if Usuario.clave_valida?(existente, clave) do
      {:reply, {:ok, existente, :autenticado}, usuarios}
    else
      {:reply, {:error, "Contraseña incorrecta para #{existente.usuario}"}, usuarios}
    end
  end
end
