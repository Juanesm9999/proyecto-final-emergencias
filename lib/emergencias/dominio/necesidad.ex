defmodule Necesidad do
  @moduledoc "Necesidades puntuales y sus estados. El orden por prioridad está en Algoritmos."

  @tipos ["agua", "alimentos", "medicamentos", "primeros_auxilios", "refugio", "transporte", "rescate", "otra"]
  @prioridades ["critica", "alta", "media", "baja"]
  @peso %{"critica" => 4, "alta" => 3, "media" => 2, "baja" => 1}
  @titulos "id,tipo,descripcion,cantidad,asignada,zona,prioridad,responsable,estado,referencia,fecha"

  # Transiciones válidas (pendiente -> asignada -> en_atencion -> atendida)
  @transiciones %{
    "pendiente" => ["asignada", "en_atencion", "cancelada"],
    "asignada" => ["en_atencion", "cancelada"],
    "en_atencion" => ["atendida"],
    "atendida" => [],
    "cancelada" => []
  }

  defstruct id: "", tipo: "", descripcion: "", cantidad: 0, asignada: 0, zona: "",
            prioridad: "media", responsable: "", estado: "pendiente", referencia: "", fecha: ""

  def tipos(), do: @tipos
  def prioridades(), do: @prioridades
  def titulos(), do: @titulos
  def peso(prioridad), do: Map.get(@peso, prioridad, 0)

  def crear(id, tipo, cantidad, prioridad, zona, descripcion, responsable, referencia) do
    cond do
      not Enum.member?(@tipos, tipo) ->
        {:error, "Tipo de necesidad inválido. Use: #{Enum.join(@tipos, ", ")}"}

      not Enum.member?(@prioridades, prioridad) ->
        {:error, "Prioridad inválida. Use: #{Enum.join(@prioridades, ", ")}"}

      zona == "" ->
        {:error, "La zona es obligatoria"}

      true ->
        case Validaciones.entero_positivo(cantidad, "cantidad") do
          {:ok, numero} ->
            {:ok,
             %Necesidad{id: id, tipo: tipo, cantidad: numero, prioridad: prioridad, zona: zona,
                        descripcion: descripcion, responsable: responsable, referencia: referencia,
                        fecha: Util.ahora()}}

          error ->
            error
        end
    end
  end

  def pendiente(n), do: n.cantidad - n.asignada

  # Valida si se pueden asignar 'cantidad' unidades (antes de tocar el inventario)
  def puede_recibir(%Necesidad{estado: estado}, _cantidad) when estado in ["atendida", "cancelada", "en_atencion"],
    do: {:error, "La necesidad está #{estado} y no puede recibir más recursos"}

  def puede_recibir(n, cantidad) do
    cond do
      cantidad <= 0 -> {:error, "La cantidad debe ser mayor que cero"}
      pendiente(n) == 0 -> {:error, "La necesidad #{n.id} ya tiene asignados todos sus recursos"}
      cantidad > pendiente(n) -> {:error, "La necesidad #{n.id} solo requiere #{pendiente(n)} unidades más"}
      true -> :ok
    end
  end

  # Registra la asignación ya confirmada por el inventario
  def registrar_asignacion(n, cantidad) do
    nueva = %{n | asignada: n.asignada + cantidad}
    if pendiente(nueva) == 0, do: %{nueva | estado: "asignada"}, else: nueva
  end

  def cambiar_estado(n, nuevo) do
    cond do
      n.estado == nuevo -> {:error, "La necesidad #{n.id} ya está #{nuevo}"}
      Enum.member?(Map.get(@transiciones, n.estado, []), nuevo) -> {:ok, %{n | estado: nuevo}}
      true -> {:error, "No se puede pasar de #{n.estado} a #{nuevo}"}
    end
  end

  def a_campos(n),
    do: [n.id, n.tipo, n.descripcion, n.cantidad, n.asignada, n.zona, n.prioridad, n.responsable, n.estado, n.referencia, n.fecha]

  def de_campos([id, tipo, descripcion, cantidad, asignada, zona, prioridad, responsable, estado, referencia, fecha]) do
    case {Validaciones.convertir_entero(cantidad), Validaciones.convertir_entero(asignada)} do
      {{:ok, c}, {:ok, a}} ->
        {:ok,
         %Necesidad{id: id, tipo: tipo, descripcion: descripcion, cantidad: c, asignada: a, zona: zona,
                    prioridad: prioridad, responsable: responsable, estado: estado, referencia: referencia,
                    fecha: fecha}}

      _ ->
        :error
    end
  end

  def de_campos(_), do: :error
end
