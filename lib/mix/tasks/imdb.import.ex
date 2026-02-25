defmodule Mix.Tasks.Imdb.Import do
  use Mix.Task

  alias SelectoTest.Repo

  @shortdoc "Import IMDb movie data into Pagila tables"

  @moduledoc """
  Downloads IMDb non-commercial datasets and imports movie-level data into
  Pagila-compatible tables (`film`, `actor`, `film_actor`, `category`,
  `film_category`).

  This task is incremental: rerunning it updates existing IMDb-backed rows,
  inserts newly added titles/cast, and refreshes cast/category links for the
  movies in the current import.

  ## Examples

      mix imdb.import
      mix imdb.import --no-download
      mix imdb.import --limit-movies 5000
      mix imdb.import --prune

  ## Options

    * `--data-dir` - Directory for raw/derived IMDb files (default: `priv/imdb`)
    * `--no-download` - Skip download and reuse local `*.tsv.gz` files
    * `--limit-movies` - Import only the first N movies (useful for test runs)
    * `--prune` - Delete stale IMDb rows not present in the latest import extract
    * `--no-keep-derived` - Remove derived TSV files after import completes
  """

  @dataset_files [
    title_basics: "title.basics.tsv.gz",
    title_principals: "title.principals.tsv.gz",
    name_basics: "name.basics.tsv.gz"
  ]

  @imdb_base_url "https://datasets.imdbws.com"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    started_at = System.monotonic_time()
    opts = parse_options!(args)
    data_dir = Path.expand(opts.data_dir, File.cwd!())

    ensure_dependencies!(opts.download)
    File.mkdir_p!(data_dir)

    Mix.shell().info("Preparing IMDb source files in #{data_dir}")
    raw_paths = download_or_validate_raw_files!(data_dir, opts.download)

    Mix.shell().info("Building movie-only IMDb extracts")
    derived_paths = build_derived_files!(raw_paths, data_dir, opts.limit_movies)

    ensure_imdb_columns!()
    ensure_stage_tables!()

    Mix.shell().info("Loading staging tables")
    load_stage_tables!(derived_paths)

    language_id = ensure_english_language_id!()

    Mix.shell().info("Importing IMDb rows into Pagila tables")
    import_imdb_rows!(language_id, opts.prune)

    print_summary!()
    maybe_cleanup_derived_files!(derived_paths, opts.keep_derived)

    elapsed_ms =
      System.monotonic_time()
      |> Kernel.-(started_at)
      |> System.convert_time_unit(:native, :millisecond)

    Mix.shell().info("IMDb import complete in #{format_elapsed(elapsed_ms)}")
  end

  defp parse_options!(args) do
    {opts, remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          data_dir: :string,
          download: :boolean,
          limit_movies: :integer,
          prune: :boolean,
          keep_derived: :boolean
        ]
      )

    if invalid != [] do
      names = Enum.map_join(invalid, ", ", fn {name, _value} -> "--#{name}" end)
      Mix.raise("Invalid options: #{names}")
    end

    if remaining != [] do
      Mix.raise("Unexpected arguments: #{Enum.join(remaining, " ")}")
    end

    limit_movies = Keyword.get(opts, :limit_movies)

    if limit_movies && limit_movies <= 0 do
      Mix.raise("--limit-movies must be a positive integer")
    end

    %{
      data_dir: Keyword.get(opts, :data_dir, "priv/imdb"),
      download: Keyword.get(opts, :download, true),
      limit_movies: limit_movies,
      prune: Keyword.get(opts, :prune, false),
      keep_derived: Keyword.get(opts, :keep_derived, true)
    }
  end

  defp ensure_dependencies!(download?) do
    required = ["bash", "gzip", "awk", "psql"]
    required = if(download?, do: ["curl" | required], else: required)

    Enum.each(required, fn command ->
      if is_nil(System.find_executable(command)) do
        Mix.raise("Required command not found in PATH: #{command}")
      end
    end)
  end

  defp download_or_validate_raw_files!(data_dir, download?) do
    raw_paths =
      @dataset_files
      |> Enum.map(fn {key, filename} -> {key, Path.join(data_dir, filename)} end)
      |> Map.new()

    if download? do
      Enum.each(@dataset_files, fn {key, filename} ->
        file_path = Map.fetch!(raw_paths, key)
        download_file!(filename, file_path)
      end)
    else
      Enum.each(raw_paths, fn {key, path} ->
        unless File.exists?(path) do
          filename = key |> Atom.to_string() |> String.replace("_", ".")
          Mix.raise("Missing #{filename}.tsv.gz at #{path}. Re-run without --no-download")
        end
      end)
    end

    raw_paths
  end

  defp download_file!(filename, output_path) do
    Mix.shell().info("- #{filename}")

    conditional_time_args =
      if File.exists?(output_path) do
        ["-z", output_path]
      else
        []
      end

    args =
      ["-fL", "--retry", "3", "--retry-delay", "2", "--connect-timeout", "30"] ++
        conditional_time_args ++ ["-o", output_path, "#{@imdb_base_url}/#{filename}"]

    run_command!("curl", args, "download #{filename}")
  end

  defp build_derived_files!(raw_paths, data_dir, limit_movies) do
    movies_path = Path.join(data_dir, "imdb_movies.tsv")
    cast_path = Path.join(data_dir, "imdb_movie_cast.tsv")
    names_path = Path.join(data_dir, "imdb_movie_names.tsv")

    build_movies_extract!(Map.fetch!(raw_paths, :title_basics), movies_path, limit_movies)
    build_cast_extract!(Map.fetch!(raw_paths, :title_principals), movies_path, cast_path)
    build_names_extract!(Map.fetch!(raw_paths, :name_basics), cast_path, names_path)

    %{movies: movies_path, cast: cast_path, names: names_path}
  end

  defp build_movies_extract!(title_basics_path, movies_path, limit_movies) do
    awk_program =
      case limit_movies do
        nil ->
          "$2 == \"movie\" { print }"

        limit ->
          "$2 == \"movie\" && count < #{limit} { print; count++ }"
      end

    command =
      "set -euo pipefail; " <>
        "LC_ALL=C gzip -dc #{shell_escape(title_basics_path)} | " <>
        "awk -F '\\t' '#{awk_program}' > #{shell_escape(movies_path)}"

    run_bash!(command, "extract movie rows")
  end

  defp build_cast_extract!(title_principals_path, movies_path, cast_path) do
    awk_program =
      "FNR == NR { ids[$1] = 1; next } " <>
        "(($1 in ids) && ($4 == \"actor\" || $4 == \"actress\")) " <>
        "{ print $1 \"\\t\" $3 }"

    command =
      "set -euo pipefail; " <>
        "LC_ALL=C gzip -dc #{shell_escape(title_principals_path)} | " <>
        "awk -F '\\t' '#{awk_program}' #{shell_escape(movies_path)} - > #{shell_escape(cast_path)}"

    run_bash!(command, "extract movie cast rows")
  end

  defp build_names_extract!(name_basics_path, cast_path, names_path) do
    awk_program =
      "FNR == NR { ids[$2] = 1; next } " <>
        "($1 in ids) { print $1 \"\\t\" $2 }"

    command =
      "set -euo pipefail; " <>
        "LC_ALL=C gzip -dc #{shell_escape(name_basics_path)} | " <>
        "awk -F '\\t' '#{awk_program}' #{shell_escape(cast_path)} - > #{shell_escape(names_path)}"

    run_bash!(command, "extract cast name rows")
  end

  defp ensure_imdb_columns! do
    film_has_column = column_exists?("film", "imdb_tconst")
    actor_has_column = column_exists?("actor", "imdb_nconst")

    unless film_has_column and actor_has_column do
      Mix.raise("Missing IMDb columns. Run mix ecto.migrate before mix imdb.import")
    end
  end

  defp column_exists?(table_name, column_name) do
    query = """
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = $1
        AND column_name = $2
    )
    """

    %{rows: [[exists?]]} = Repo.query!(query, [table_name, column_name])
    exists?
  end

  defp ensure_stage_tables! do
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS imdb_stage_movies (
      tconst text,
      title_type text,
      primary_title text,
      original_title text,
      is_adult text,
      start_year text,
      end_year text,
      runtime_minutes text,
      genres text
    )
    """)

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS imdb_stage_cast (
      tconst text,
      nconst text
    )
    """)

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS imdb_stage_names (
      nconst text,
      primary_name text
    )
    """)

    Repo.query!(
      "CREATE INDEX IF NOT EXISTS imdb_stage_movies_tconst_idx ON imdb_stage_movies (tconst)"
    )

    Repo.query!(
      "CREATE INDEX IF NOT EXISTS imdb_stage_cast_tconst_idx ON imdb_stage_cast (tconst)"
    )

    Repo.query!(
      "CREATE INDEX IF NOT EXISTS imdb_stage_cast_nconst_idx ON imdb_stage_cast (nconst)"
    )

    Repo.query!(
      "CREATE INDEX IF NOT EXISTS imdb_stage_names_nconst_idx ON imdb_stage_names (nconst)"
    )
  end

  defp load_stage_tables!(derived_paths) do
    Repo.query!("TRUNCATE TABLE imdb_stage_movies, imdb_stage_cast, imdb_stage_names")

    copy_into_stage!(
      "imdb_stage_movies",
      [
        "tconst",
        "title_type",
        "primary_title",
        "original_title",
        "is_adult",
        "start_year",
        "end_year",
        "runtime_minutes",
        "genres"
      ],
      derived_paths.movies
    )

    copy_into_stage!("imdb_stage_cast", ["tconst", "nconst"], derived_paths.cast)
    copy_into_stage!("imdb_stage_names", ["nconst", "primary_name"], derived_paths.names)

    Repo.query!("ANALYZE imdb_stage_movies")
    Repo.query!("ANALYZE imdb_stage_cast")
    Repo.query!("ANALYZE imdb_stage_names")
  end

  defp copy_into_stage!(table_name, columns, file_path) do
    escaped_file = escape_sql_literal(file_path)
    columns_sql = Enum.join(columns, ", ")

    sql =
      "\\copy #{table_name} (#{columns_sql}) FROM '#{escaped_file}' " <>
        "WITH (FORMAT text, DELIMITER E'\\t', NULL '\\N')"

    run_psql!(sql, "copy #{Path.basename(file_path)} into #{table_name}")
  end

  defp ensure_english_language_id! do
    existing =
      Repo.query!(
        "SELECT language_id FROM language WHERE lower(trim(name)) = 'english' ORDER BY language_id LIMIT 1"
      )

    case existing.rows do
      [[language_id]] ->
        language_id

      [] ->
        %{rows: [[language_id]]} =
          Repo.query!("INSERT INTO language (name) VALUES ('English') RETURNING language_id")

        language_id
    end
  end

  defp import_imdb_rows!(language_id, prune?) do
    Repo.query!(upsert_films_sql(), [language_id])
    Repo.query!(upsert_actors_sql())
    Repo.query!(insert_new_categories_sql())

    Repo.query!(delete_current_film_actor_links_sql())
    Repo.query!(insert_film_actor_links_sql())

    Repo.query!(delete_current_film_category_links_sql())
    Repo.query!(insert_film_category_links_sql())

    if prune? do
      Repo.query!(delete_stale_film_actor_links_sql())
      Repo.query!(delete_stale_film_category_links_sql())
      Repo.query!(prune_stale_films_sql())
      Repo.query!(prune_stale_actors_sql())
    end
  end

  defp upsert_films_sql do
    """
    INSERT INTO film (
      imdb_tconst,
      title,
      description,
      release_year,
      language_id,
      rental_duration,
      rental_rate,
      length,
      replacement_cost,
      rating
    )
    SELECT
      m.tconst,
      m.primary_title,
      CASE
        WHEN m.original_title IS NULL OR m.original_title = '' OR m.original_title = m.primary_title
          THEN NULL
        ELSE 'Original title: ' || m.original_title
      END,
      CASE
        WHEN m.start_year ~ '^[0-9]{4}$' AND m.start_year::integer BETWEEN 1901 AND 2155
          THEN m.start_year::integer
        ELSE NULL
      END,
      $1::integer,
      3,
      4.99,
      CASE
        WHEN m.runtime_minutes ~ '^[0-9]+$' AND m.runtime_minutes::integer BETWEEN 1 AND 32767
          THEN m.runtime_minutes::smallint
        ELSE NULL
      END,
      CASE
        WHEN m.runtime_minutes ~ '^[0-9]+$' AND m.runtime_minutes::integer >= 150 THEN 29.99
        WHEN m.runtime_minutes ~ '^[0-9]+$' AND m.runtime_minutes::integer >= 110 THEN 24.99
        ELSE 19.99
      END,
      CASE
        WHEN m.is_adult = '1' THEN 'NC-17'::mpaa_rating
        WHEN m.genres ILIKE '%Family%' OR m.genres ILIKE '%Animation%' THEN 'G'::mpaa_rating
        WHEN m.genres ILIKE '%Horror%' OR m.genres ILIKE '%Crime%' OR m.genres ILIKE '%War%'
          THEN 'R'::mpaa_rating
        ELSE 'PG-13'::mpaa_rating
      END
    FROM imdb_stage_movies m
    WHERE m.tconst IS NOT NULL
    ON CONFLICT (imdb_tconst) DO UPDATE
    SET
      title = EXCLUDED.title,
      description = EXCLUDED.description,
      release_year = EXCLUDED.release_year,
      language_id = EXCLUDED.language_id,
      rental_duration = EXCLUDED.rental_duration,
      rental_rate = EXCLUDED.rental_rate,
      length = EXCLUDED.length,
      replacement_cost = EXCLUDED.replacement_cost,
      rating = EXCLUDED.rating
    """
  end

  defp upsert_actors_sql do
    """
    WITH cast_names AS (
      SELECT DISTINCT c.nconst, n.primary_name
      FROM imdb_stage_cast c
      JOIN imdb_stage_names n ON n.nconst = c.nconst
      WHERE c.nconst IS NOT NULL
    )
    INSERT INTO actor (imdb_nconst, first_name, last_name)
    SELECT
      cn.nconst,
      CASE
        WHEN cn.primary_name IS NULL OR btrim(cn.primary_name) = '' THEN 'Unknown'
        WHEN strpos(btrim(cn.primary_name), ' ') = 0 THEN btrim(cn.primary_name)
        ELSE split_part(btrim(cn.primary_name), ' ', 1)
      END AS first_name,
      CASE
        WHEN cn.primary_name IS NULL OR btrim(cn.primary_name) = '' THEN 'Unknown'
        WHEN strpos(btrim(cn.primary_name), ' ') = 0 THEN 'Unknown'
        ELSE ltrim(substring(btrim(cn.primary_name) from strpos(btrim(cn.primary_name), ' ') + 1))
      END AS last_name
    FROM cast_names cn
    ON CONFLICT (imdb_nconst) DO UPDATE
    SET
      first_name = EXCLUDED.first_name,
      last_name = EXCLUDED.last_name
    """
  end

  defp insert_new_categories_sql do
    """
    WITH genre_values AS (
      SELECT DISTINCT btrim(genre_name) AS genre_name
      FROM imdb_stage_movies m,
      LATERAL regexp_split_to_table(COALESCE(m.genres, ''), ',') AS genre_name
    )
    INSERT INTO category (name)
    SELECT gv.genre_name
    FROM genre_values gv
    WHERE gv.genre_name <> ''
      AND NOT EXISTS (
        SELECT 1
        FROM category c
        WHERE lower(btrim(c.name)) = lower(gv.genre_name)
      )
    """
  end

  defp delete_current_film_actor_links_sql do
    """
    DELETE FROM film_actor fa
    WHERE EXISTS (
      SELECT 1
      FROM film f
      JOIN imdb_stage_movies m ON m.tconst = f.imdb_tconst
      WHERE f.film_id = fa.film_id
    )
    """
  end

  defp insert_film_actor_links_sql do
    """
    INSERT INTO film_actor (actor_id, film_id)
    SELECT DISTINCT a.actor_id, f.film_id
    FROM imdb_stage_cast c
    JOIN film f ON f.imdb_tconst = c.tconst
    JOIN actor a ON a.imdb_nconst = c.nconst
    ON CONFLICT DO NOTHING
    """
  end

  defp delete_current_film_category_links_sql do
    """
    DELETE FROM film_category fc
    WHERE EXISTS (
      SELECT 1
      FROM film f
      JOIN imdb_stage_movies m ON m.tconst = f.imdb_tconst
      WHERE f.film_id = fc.film_id
    )
    """
  end

  defp insert_film_category_links_sql do
    """
    INSERT INTO film_category (film_id, category_id)
    SELECT DISTINCT f.film_id, c.category_id
    FROM imdb_stage_movies m
    JOIN film f ON f.imdb_tconst = m.tconst
    JOIN LATERAL regexp_split_to_table(COALESCE(m.genres, ''), ',') AS genre_name ON true
    JOIN category c ON lower(btrim(c.name)) = lower(btrim(genre_name))
    WHERE btrim(genre_name) <> ''
    ON CONFLICT DO NOTHING
    """
  end

  defp delete_stale_film_actor_links_sql do
    """
    DELETE FROM film_actor fa
    USING film f
    WHERE fa.film_id = f.film_id
      AND f.imdb_tconst IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM imdb_stage_movies m
        WHERE m.tconst = f.imdb_tconst
      )
    """
  end

  defp delete_stale_film_category_links_sql do
    """
    DELETE FROM film_category fc
    USING film f
    WHERE fc.film_id = f.film_id
      AND f.imdb_tconst IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM imdb_stage_movies m
        WHERE m.tconst = f.imdb_tconst
      )
    """
  end

  defp prune_stale_films_sql do
    """
    DELETE FROM film f
    WHERE f.imdb_tconst IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM imdb_stage_movies m
        WHERE m.tconst = f.imdb_tconst
      )
    """
  end

  defp prune_stale_actors_sql do
    """
    DELETE FROM actor a
    WHERE a.imdb_nconst IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM imdb_stage_names n
        WHERE n.nconst = a.imdb_nconst
      )
      AND NOT EXISTS (
        SELECT 1
        FROM film_actor fa
        WHERE fa.actor_id = a.actor_id
      )
    """
  end

  defp print_summary! do
    staged_movies = scalar_count("SELECT count(*) FROM imdb_stage_movies")
    staged_cast = scalar_count("SELECT count(*) FROM imdb_stage_cast")
    staged_names = scalar_count("SELECT count(*) FROM imdb_stage_names")

    imported_movies = scalar_count("SELECT count(*) FROM film WHERE imdb_tconst IS NOT NULL")
    imported_actors = scalar_count("SELECT count(*) FROM actor WHERE imdb_nconst IS NOT NULL")

    imported_cast_links =
      scalar_count("""
      SELECT count(*)
      FROM film_actor fa
      JOIN film f ON f.film_id = fa.film_id
      WHERE f.imdb_tconst IS NOT NULL
      """)

    imported_category_links =
      scalar_count("""
      SELECT count(*)
      FROM film_category fc
      JOIN film f ON f.film_id = fc.film_id
      WHERE f.imdb_tconst IS NOT NULL
      """)

    Mix.shell().info(
      "Staging rows: movies=#{staged_movies}, cast=#{staged_cast}, names=#{staged_names}"
    )

    Mix.shell().info(
      "Imported totals: films=#{imported_movies}, actors=#{imported_actors}, " <>
        "film_actor=#{imported_cast_links}, film_category=#{imported_category_links}"
    )
  end

  defp scalar_count(sql) do
    %{rows: [[count]]} = Repo.query!(sql)
    count
  end

  defp maybe_cleanup_derived_files!(derived_paths, keep_derived?) do
    if keep_derived? do
      Mix.shell().info("Derived files kept under #{Path.dirname(derived_paths.movies)}")
    else
      Enum.each(Map.values(derived_paths), fn path ->
        File.rm(path)
      end)

      Mix.shell().info("Removed derived movie extract files")
    end
  end

  defp run_psql!(sql, step) do
    repo_config = Repo.config()
    database = repo_config[:database] || Mix.raise("Repo database is not configured")

    host = to_string(repo_config[:hostname] || "localhost")
    port = to_string(repo_config[:port] || 5432)
    username = to_string(repo_config[:username] || "postgres")

    args = [
      "-h",
      host,
      "-p",
      port,
      "-U",
      username,
      "-d",
      to_string(database),
      "-v",
      "ON_ERROR_STOP=1",
      "-c",
      sql
    ]

    env =
      case repo_config[:password] do
        nil -> []
        password -> [{"PGPASSWORD", to_string(password)}]
      end

    run_command!("psql", args, step, env: env)
  end

  defp run_bash!(command, step) do
    run_command!("bash", ["-lc", command], step)
  end

  defp run_command!(command, args, step, extra_opts \\ []) do
    {output, exit_code} =
      System.cmd(command, args, Keyword.merge([stderr_to_stdout: true], extra_opts))

    if exit_code != 0 do
      Mix.raise("Failed to #{step}:\n#{output}")
    end

    output
  end

  defp shell_escape(path) do
    "'" <> String.replace(path, "'", "'\"'\"'") <> "'"
  end

  defp escape_sql_literal(value) do
    String.replace(value, "'", "''")
  end

  defp format_elapsed(elapsed_ms) when elapsed_ms < 1_000, do: "#{elapsed_ms}ms"
  defp format_elapsed(elapsed_ms), do: "#{Float.round(elapsed_ms / 1_000, 1)}s"
end
