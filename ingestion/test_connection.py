import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


# Chemin du fichier .env situé à la racine du projet
env_path = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(env_path)

# Création sécurisée de l'adresse de connexion
database_url = URL.create(
    drivername="postgresql+psycopg2",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST"),
    port=int(os.getenv("DB_PORT", "5432")),
    database=os.getenv("DB_NAME"),
)

engine = create_engine(database_url)

with engine.connect() as connection:
    result = connection.execute(
        text("select current_database(), current_user")
    ).one()

    schemas = connection.execute(
        text(
            "select schema_name from information_schema.schemata "
            "where schema_name in ('raw', 'staging', 'marts') "
            "order by schema_name"
        )
    ).scalars().all()

    print("Connexion PostgreSQL réussie !")
    print(f"Base de données : {result[0]}")
    print(f"Utilisateur : {result[1]}")
    print(f"Schémas trouvés : {', '.join(schemas)}")