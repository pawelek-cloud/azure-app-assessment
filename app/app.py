from flask import Flask, request, render_template
from dotenv import load_dotenv
import psycopg2, os

load_dotenv()  # Loads variables from .env

app = Flask(__name__)

def get_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        database=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASS"),
        sslmode="require"
    )

def init_db():
    """Create demo_table if it doesn't exist."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS demo_table (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT now()
        );
    """)
    conn.commit()
    cur.close()
    conn.close()

@app.before_first_request
def setup():
    # Ensure table exists before serving any requests
    init_db()

@app.route("/", methods=["GET", "POST"])
def index():
    conn = get_connection()
    cur = conn.cursor()
    if request.method == "POST":
        name = request.form["name"]
        cur.execute("INSERT INTO demo_table (name) VALUES (%s)", (name,))
        conn.commit()
    cur.execute("SELECT * FROM demo_table")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("index.html", rows=rows)

@app.route("/db-check")
def db_check():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1;")
        conn.close()
        return "Database connection successful", 200
    except Exception as e:
        return f"Database connection failed: {str(e)}", 500

if __name__ == "__main__":
    # Ensure table exists even if running locally
    init_db()
    app.run(host="0.0.0.0", port=8081)
