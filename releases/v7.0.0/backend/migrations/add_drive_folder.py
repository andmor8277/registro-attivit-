from sqlalchemy import text
from .database import engine

def run_migration():
    with engine.connect() as conn:
        # Check if column exists
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'categorie' AND column_name = 'drive_folder_id'
        """))
        
        if result.fetchone() is None:
            conn.execute(text("""
                ALTER TABLE categorie ADD COLUMN drive_folder_id VARCHAR(100)
            """))
            conn.commit()
            print("Migration: Added drive_folder_id column to categorie")
        else:
            print("Migration: drive_folder_id column already exists")

if __name__ == "__main__":
    run_migration()
