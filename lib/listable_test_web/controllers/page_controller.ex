defmodule ListableTestWeb.PageController do
  use ListableTestWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
