defmodule Validaciones do
  @moduledoc """
  Validaciones de las entradas del usuario antes de modificar el estado:
  números enteros y permisos según el tipo de usuario.
  Devuelven {:ok, valor} / {:error, mensaje} en lugar de lanzar errores.
  """

  # ======================= Números =======================

  # Como Util.ingresar(:entero), pero el texto llega en un comando:
  # en lugar de volver a preguntar, devuelve {:ok, numero} o :error
  def convertir_entero(texto) do
    try do
      numero =
        texto
        |> to_string()
        |> String.trim()
        |> String.to_integer()

      {:ok, numero}
    rescue
      ArgumentError -> :error
    end
  end

  def entero_no_negativo(texto, campo) do
    case convertir_entero(texto) do
      {:ok, numero} when numero >= 0 -> {:ok, numero}
      {:ok, _numero} -> {:error, "El campo #{campo} no puede ser negativo"}
      :error -> {:error, "El campo #{campo} debe ser un número entero"}
    end
  end

  def entero_positivo(texto, campo) do
    case entero_no_negativo(texto, campo) do
      {:ok, 0} -> {:error, "El campo #{campo} debe ser mayor que cero"}
      resultado -> resultado
    end
  end

  # ======================= Permisos por tipo de usuario =======================
  # Cada rol incluye los comandos del rol anterior

  @ciudadano ["help", "disconnect", "whoami", "list_zones", "zone_status", "register_need", "list_needs",
              "pending_needs", "list_resources", "report_person", "find_person", "person_history",
              "send_family_message", "list_family_messages", "report_pet", "list_pets", "list_shelters",
              "check_shelter"]

  @voluntario @ciudadano ++
                ["update_need", "update_person", "deliver_message", "match_pets", "register_entry",
                 "register_exit", "resource_in", "resource_out"]

  @coordinador @voluntario ++
                 ["register_zone", "register_sector", "register_point", "register_resource", "assign_resource",
                  "attend_pending", "transfer_resource", "resource_history", "critical_resources",
                  "register_shelter", "shelters_report", "confirm_match", "summary"]

  @administrador @coordinador ++ ["activity", "users"]

  @por_tipo %{
    "ciudadano" => @ciudadano,
    "voluntario" => @voluntario,
    "coordinador" => @coordinador,
    "administrador" => @administrador
  }

  def permitido?(tipo, comando), do: Enum.member?(comandos_permitidos(tipo), comando)
  def comandos_permitidos(tipo), do: Map.get(@por_tipo, tipo, [])
end
