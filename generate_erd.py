"""
generate_erd.py
Connects to Azure SQL using an ADO.NET connection string,
reads INFORMATION_SCHEMA, and writes a Mermaid erDiagram to a file.

Usage:
    python generate_erd.py --conn "<connection string>" --out docs/erd.mermaid
"""
import argparse
import os
import sys
import pyodbc

COLUMNS_QUERY = """
    SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
    FROM   INFORMATION_SCHEMA.COLUMNS
    WHERE  TABLE_SCHEMA = 'dbo'
    ORDER  BY TABLE_NAME, ORDINAL_POSITION
"""

FK_QUERY = """
    SELECT
        kcu1.TABLE_NAME  AS FK_TABLE,
        kcu1.COLUMN_NAME AS FK_COLUMN,
        kcu2.TABLE_NAME  AS PK_TABLE,
        kcu2.COLUMN_NAME AS PK_COLUMN
    FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu1
        ON  kcu1.CONSTRAINT_NAME  = rc.CONSTRAINT_NAME
    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu2
        ON  kcu2.CONSTRAINT_NAME  = rc.UNIQUE_CONSTRAINT_NAME
        AND kcu2.ORDINAL_POSITION = kcu1.ORDINAL_POSITION
    ORDER BY FK_TABLE, FK_COLUMN
"""

# ADO.NET keyword → ODBC keyword
_ADO_TO_ODBC = {
    "data source":           "SERVER",
    "server":                "SERVER",
    "initial catalog":       "DATABASE",
    "database":              "DATABASE",
    "user id":               "UID",
    "uid":                   "UID",
    "password":              "PWD",
    "pwd":                   "PWD",
    "encrypt":               "Encrypt",
    "trustservercertificate":"TrustServerCertificate",
    "connection timeout":    "Connection Timeout",
    "multipleactiveresultsets": None,   # not supported by ODBC — drop it
    "persist security info":    None,
    "application name":         None,
}


def ado_to_odbc(conn_str: str) -> str:
    """Convert an ADO.NET connection string to pyodbc / ODBC format.

    ODBC Driver 18 uses 'yes'/'no' for boolean attributes, not 'True'/'False'.
    """
    _BOOL = {"true": "yes", "false": "no"}

    parts = {"DRIVER": "{ODBC Driver 18 for SQL Server}"}
    for pair in conn_str.split(";"):
        pair = pair.strip()
        if "=" not in pair:
            continue
        key, _, value = pair.partition("=")
        key_lower = key.strip().lower()
        value = value.strip()
        odbc_key = _ADO_TO_ODBC.get(key_lower, key.strip())
        if odbc_key is not None:
            # Translate True/False → yes/no for ODBC boolean attributes
            parts[odbc_key] = _BOOL.get(value.lower(), value)
    return ";".join(f"{k}={v}" for k, v in parts.items())


def fetch_tables(conn):
    cursor = conn.cursor()
    cursor.execute(COLUMNS_QUERY)
    tables = {}
    for table, col, dtype, nullable in cursor.fetchall():
        tables.setdefault(table, []).append((col, dtype, nullable == "YES"))
    return tables


def fetch_fks(conn):
    cursor = conn.cursor()
    cursor.execute(FK_QUERY)
    return cursor.fetchall()


def build_mermaid(tables: dict, fks: list) -> str:
    lines = ["erDiagram"]
    for table, columns in sorted(tables.items()):
        lines.append(f"    {table} {{")
        for col, dtype, nullable in columns:
            marker = ' "nullable"' if nullable else ""
            lines.append(f"        {dtype} {col}{marker}")
        lines.append("    }")
    for fk_table, fk_col, pk_table, _ in fks:
        lines.append(f'    {pk_table} ||--o{{ {fk_table} : "{fk_col}"')
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--conn", required=True, help="ADO.NET connection string")
    parser.add_argument("--out",  required=True, help="Output .mermaid file path")
    args = parser.parse_args()

    odbc_conn = ado_to_odbc(args.conn)

    print("Connecting to database...")
    try:
        with pyodbc.connect(odbc_conn) as conn:
            tables = fetch_tables(conn)
            fks    = fetch_fks(conn)
    except pyodbc.Error as e:
        print(f"Database error: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(tables)} table(s), {len(fks)} FK relationship(s).")

    diagram = build_mermaid(tables, fks)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(diagram)

    print(f"ERD written to {args.out}")


if __name__ == "__main__":
    main()
