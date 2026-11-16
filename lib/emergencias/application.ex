defmodule Emergencias.Application do
  @moduledoc "Arranque de la aplicación: inicia el SupervisorPrincipal."
  use Application

  def start(_type, _args), do: SupervisorPrincipal.start_link(:ok)
end
