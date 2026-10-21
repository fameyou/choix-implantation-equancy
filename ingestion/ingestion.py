from __future__ import annotations

import os
import re
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import Text, create_engine, text
from sqlalchemy.engine import URL


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIRECTORY = PROJECT_ROOT / "data" / "raw"
RAW_SCHEMA = "raw"
CSV_SEPARATOR = ";"

# fichier CSV -> (table dans raw, encodage, nombre de lignes attendu)
FILES = {
    "country_table.csv": ("country_table", "cp1252", 168),
    "table_date.csv": ("table_date", "utf-8-sig", 296),
    "population_thousands.csv": ("population_thousands", "utf-8-sig", 5171),
    "gdp_unesco.csv": ("gdp_unesco", "utf-8-sig", 4539),
    "demographic_indicators.csv": ("demographic_indicators", "utf-8-sig", 4825),
    "emissions_per_country.csv": ("emissions_per_country", "utf-8-sig", 63104),
    "government_expenses_in_education.csv": (
        "government_expenses_in_education",
        "utf-8-sig",
        1217,
    ),
    "expenditure_in_preservation_conservation.csv": (
        "expenditure_in_preservation_conservation",
        "utf-8-sig",
        528,
    ),
}


def require_environment(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"La variable d'environnement {name} est requise.")
    return value.strip()


def make_connection_url() -> URL:
    return URL.create(
        "postgresql+psycopg2",
        username=require_environment("DB_USER"),
        password=require_environment("DB_PASSWORD"),
        host=require_environment("DB_HOST"),
        port=int(require_environment("DB_PORT")),
        database=require_environment("DB_NAME"),
    )


def normalize_identifier(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9]+", "_", value.strip().lower())
    return cleaned.strip("_")


def prepare_schema(engine) -> None:
    with engine.begin() as connection:
        connection.execute(text(f"create schema if not exists {RAW_SCHEMA}"))


def load_csv_to_raw(engine, csv_path: Path, table_name: str, encoding: str) -> int:
    # Tout est lu en texte : le typage se fera dans dbt (staging).
    # Seules les cellules vides deviennent NULL.
    dataframe = pd.read_csv(
        csv_path,
        sep=CSV_SEPARATOR,
        encoding=encoding,
        dtype=str,
        keep_default_na=False,
        na_values=[""],
    )
    dataframe.columns = [normalize_identifier(column) for column in dataframe.columns]

    dtype_mapping = {column: Text() for column in dataframe.columns}
    dataframe.head(0).to_sql(
        name=table_name,
        con=engine,
        schema=RAW_SCHEMA,
        if_exists="replace",
        index=False,
        dtype=dtype_mapping,
    )
    dataframe.to_sql(
        name=table_name,
        con=engine,
        schema=RAW_SCHEMA,
        if_exists="append",
        index=False,
        dtype=dtype_mapping,
        chunksize=1_000,
        method="multi",
    )

    with engine.connect() as connection:
        return connection.execute(
            text(f"select count(*) from {RAW_SCHEMA}.{table_name}")
        ).scalar_one()


def main() -> None:
    load_dotenv(PROJECT_ROOT / ".env")

    engine = create_engine(make_connection_url())
    prepare_schema(engine)

    problems = []
    for file_name, (table_name, encoding, expected_rows) in FILES.items():
        csv_path = DATA_DIRECTORY / file_name
        if not csv_path.exists():
            problems.append(f"Fichier introuvable : {csv_path}")
            continue

        loaded_rows = load_csv_to_raw(engine, csv_path, table_name, encoding)
        status = "OK" if loaded_rows == expected_rows else "ÉCART"
        print(
            f"[{status}] raw.{table_name} : {loaded_rows:,} lignes "
            f"(attendu : {expected_rows:,})"
        )
        if loaded_rows != expected_rows:
            problems.append(f"{table_name} : {loaded_rows} lignes au lieu de {expected_rows}")

    print()
    if problems:
        print("Chargement terminé avec des problèmes :")
        for problem in problems:
            print(f" - {problem}")
        raise SystemExit(1)

    print("Chargement terminé : les 8 tables sont dans le schéma raw.")


if __name__ == "__main__":
    main()