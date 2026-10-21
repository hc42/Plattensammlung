defmodule PlattensammlungWeb.AshJsonApiRouter do
  @moduledoc """
  JSON:API endpoints generated from the routes in `Plattensammlung.Records`,
  mounted at `/api/json`. The OpenAPI spec is at `/api/json/open_api`, the
  Swagger UI at `/api/json/swaggerui`.
  """
  use AshJsonApi.Router,
    domains: [Plattensammlung.Records],
    open_api: "/open_api",
    open_api_title: "Plattensammlung API",
    open_api_version: "1.0",
    modify_open_api: {__MODULE__, :modify_open_api, []}

  @doc false
  # "Try it out" should call the host the docs were loaded from (localhost:4000,
  # <name>.local:4001, the public domain). API keys are sent as Bearer tokens.
  def modify_open_api(spec, conn, _opts) do
    servers =
      if conn,
        do: [%OpenApiSpex.Server{url: PlattensammlungWeb.PublicUrl.base_url(conn)}],
        else: spec.servers

    bearer = %OpenApiSpex.SecurityScheme{
      type: "http",
      scheme: "bearer",
      description: "API-Key von der Kontoseite (/account), z. B. plattensammlung_…"
    }

    %{
      spec
      | servers: servers,
        components: Map.put(spec.components, :securitySchemes, %{"bearerAuth" => bearer})
    }
  end
end
