import argparse
import os
import sqlite3
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parent
LOCAL_SOURCE = ROOT / "data" / "raw" / "coles_dirty_source_50_records.sqlite"
DOWNLOAD_SOURCE = Path(
    r"C:\Users\Ichsan\Downloads\coles_dirty_source_50_records"
    r"\coles_dirty_source_generated\coles_dirty_source_50_records.sqlite"
)
DEFAULT_SOURCE = LOCAL_SOURCE if LOCAL_SOURCE.exists() else DOWNLOAD_SOURCE
DEFAULT_OUTPUT = ROOT / "output" / "coles_warehouse_dw.sqlite"


DATE_FORMATS = (
    "%Y-%m-%d",
    "%d/%m/%Y",
    "%m-%d-%Y",
    "%Y/%m/%d",
    "%d-%b-%Y",
    "%d-%B-%Y",
)


def clean_text(value):
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def clean_id(value):
    text = clean_text(value)
    return text.upper() if text else None


def parse_date(value):
    text = clean_text(value)
    if not text:
        return None
    for fmt in DATE_FORMATS:
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def date_key(value):
    parsed = parse_date(value)
    return int(parsed.replace("-", "")) if parsed else None


def num(value):
    text = clean_text(value)
    if text is None:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def int_num(value):
    number = num(value)
    return int(number) if number is not None else None


def clean_bool(value):
    text = clean_text(value)
    if text is None:
        return None
    text = text.lower()
    if text in {"y", "yes", "true", "1"}:
        return 1
    if text in {"n", "no", "false", "0"}:
        return 0
    return None


def register_functions(conn):
    conn.create_function("CLEAN_TEXT", 1, clean_text)
    conn.create_function("CLEAN_ID", 1, clean_id)
    conn.create_function("PARSE_DATE", 1, parse_date)
    conn.create_function("DATE_KEY", 1, date_key)
    conn.create_function("NUM", 1, num)
    conn.create_function("INT_NUM", 1, int_num)
    conn.create_function("CLEAN_BOOL", 1, clean_bool)


def execute_script(conn, path):
    sql = path.read_text(encoding="utf-8")
    conn.executescript(sql)


def main():
    parser = argparse.ArgumentParser(description="Run Coles data warehouse ETL.")
    parser.add_argument("--source", default=str(DEFAULT_SOURCE), help="Dirty source SQLite database.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="Output data warehouse SQLite database.")
    parser.add_argument(
        "--incremental",
        action="store_true",
        help="Keep an existing warehouse and append only new natural-key fact rows.",
    )
    args = parser.parse_args()

    source = Path(args.source)
    output = Path(args.output)
    if not source.exists():
        raise FileNotFoundError(f"Source database not found: {source}")

    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and not args.incremental:
        try:
            output.unlink()
        except PermissionError as exc:
            raise PermissionError(
                f"Cannot rebuild because the warehouse database is open or locked: {output}. "
                "Close DB Browser for SQLite, Power BI, or any app using the file, then run the command again. "
                "You can also use --incremental if you do not need a clean rebuild."
            ) from exc

    batch_id = datetime.now().strftime("BATCH_%Y%m%d_%H%M%S")
    conn = sqlite3.connect(output)
    register_functions(conn)
    conn.create_function("BATCH_ID", 0, lambda: batch_id)
    conn.create_function("RUN_MODE", 0, lambda: "INCREMENTAL" if args.incremental else "REBUILD")
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.execute("ATTACH DATABASE ? AS raw;", (str(source),))

    try:
        for script_name in (
            "01_schema.sql",
            "02_staging.sql",
            "03_transform.sql",
            "03_load_dimensions.sql",
            "04_load_facts.sql",
        ):
            script_path = ROOT / "sql" / script_name
            print(f"Running {script_path.name}...")
            execute_script(conn, script_path)
            conn.commit()

        print(f"ETL complete: {output}")
        print(f"Batch: {batch_id} ({'incremental' if args.incremental else 'rebuild'})")
        print("Run sql/05_validation.sql for quality checks and sample analysis.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
