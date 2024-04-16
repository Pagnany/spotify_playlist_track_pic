defmodule Spotify do
  use Application

  def get_access_token(client_id, client_secret) do
    HTTPoison.start()
    auth_url = "https://accounts.spotify.com/api/token"

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    body =
      "grant_type=client_credentials" <>
        "&client_id=#{client_id}" <> "&client_secret=#{client_secret}"

    case HTTPoison.post(auth_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        # get the access token from the response body
        body = Jason.decode!(body)
        access_token = Map.get(body, "access_token")
        IO.puts("Access token: #{access_token}")
        access_token

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts("Bad request")
        nil

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        IO.puts("Unauthorized")
        nil

      {:ok, %HTTPoison.Response{status_code: _}} ->
        IO.puts("Something went wrong")
        nil

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Error: #{reason}")
        nil
    end
  end

  def get_playlist(access_token, playlist_id) do
    playlist_url = "https://api.spotify.com/v1/playlists/"

    headers = [
      {"Authorization", "Bearer #{access_token}"}
    ]

    case HTTPoison.get(playlist_url <> playlist_id, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        bodyjson = Jason.decode!(body)

        # get images from playlist
        # tracks.items.track.album.images
        images =
          Enum.map(bodyjson["tracks"]["items"], fn item ->
            Enum.map(item["track"]["album"]["images"], fn image ->
              image["url"]
            end)
          end)

        flatten_images = List.flatten(images)
        flatten_images

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts("Bad request")

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Error: #{reason}")
    end
  end

  def download_file(url) do
    :inets.start()
    :ssl.start()
    headers = []

    file_name =
      url
      |> String.split("/")
      |> List.last()

    file_name = file_name <> ".jpeg"

    path_to_file =
      "./pictures/"
      |> Path.join(file_name)
      |> String.to_charlist()

    if File.exists?(path_to_file) do
      IO.puts("File already exists: #{file_name}")
    else
      http_request_opts = []

      case :httpc.request(:get, {url, headers}, http_request_opts, stream: path_to_file) do
        {:ok, :saved_to_file} ->
          IO.puts("Downloaded file: #{file_name}")

        {:ok, _} ->
          IO.puts("Dont know really")

        {:error, _} ->
          IO.puts("Failed to download file: #{file_name}")
      end
    end
  end

  def start(_type, _args) do
    # 0: client_id
    # 1: client_secret
    crets =
      File.stream!("credentials/cre.txt")
      |> Stream.map(&String.trim/1)
      |> Enum.to_list()

    playlist_id = "37i9dQZF1DXcBWIGoYBM5M"

    get_access_token(Enum.at(crets, 0), Enum.at(crets, 1))
    |> get_playlist(playlist_id)
    |> Enum.each(fn url -> download_file(url) end)

    children = []

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
