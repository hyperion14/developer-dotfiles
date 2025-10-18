-- ==============================================
-- IONOS Legal-RAG Database Schema
-- Rechtsgebiet-spezifische Tabellen
-- ==============================================

-- Deutsche Rechtsgebiete Enum
CREATE TYPE legal_domain_enum AS ENUM (
    'vergaberecht', 'eu-beihilfen', 'zuwendungsrecht', 'privates baurecht', 'architektenrecht', 'verwaltungsrecht', 'öffentliches baurecht', 'arbeitsrecht',
    'steuerrecht', 'familienrecht', 'erbrecht', 'mietrecht',
    'gesellschaftsrecht', 'europarecht', 'verfassungsrecht'
);

-- Court Level Enum  
CREATE TYPE court_level_enum AS ENUM (
    'BGH', 'BVerfG', 'BAG', 'BFH', 'BVerwG', 'BSG',
    'OLG', 'LAG', 'FG', 'VGH', 'OVG',
    'LG', 'ArbG', 'SG', 'VG', 'AG', 'VK', 'EuGH', 'EuG'
);

-- Processing Status Enum
CREATE TYPE processing_status_enum AS ENUM (
    'uploaded', 'processing', 'completed', 'failed', 'archived'
);

-- Haupt-Dokumententabelle (bereits in main.py definiert, aber hier für Referenz)
-- Wird automatisch von SQLAlchemy erstellt

-- Zusätzliche Indizes für Performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_docs_domain_court 
ON legal_documents(primary_domain, court_level);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_docs_status_date
ON legal_documents(processing_status, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_docs_decision_date
ON legal_documents(decision_date DESC) WHERE decision_date IS NOT NULL;

-- Full-Text Search Index für deutsche Rechtsbegriffe
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_legal_entities_fulltext
ON legal_entities USING GIN(to_tsvector('german', entity_text));

-- Rechtsgebiet-Statistiken View
CREATE OR REPLACE VIEW legal_domain_stats AS
SELECT 
    primary_domain,
    court_level,
    COUNT(*) as document_count,
    COUNT(*) FILTER (WHERE processing_status = 'completed') as completed_count,
    AVG(legal_area_confidence) as avg_confidence,
    MIN(created_at) as earliest_doc,
    MAX(created_at) as latest_doc
FROM legal_documents
GROUP BY primary_domain, court_level;

-- Funktion: Dokument-Statistiken abrufen
CREATE OR REPLACE FUNCTION get_system_stats()
RETURNS JSON AS $
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_documents', (SELECT COUNT(*) FROM legal_documents),
        'by_domain', (
            SELECT json_object_agg(primary_domain, domain_count)
            FROM (
                SELECT primary_domain, COUNT(*) as domain_count
                FROM legal_documents
                GROUP BY primary_domain
            ) domain_stats
        ),
        'by_status', (
            SELECT json_object_agg(processing_status, status_count)
            FROM (
                SELECT processing_status, COUNT(*) as status_count
                FROM legal_documents
                GROUP BY processing_status
            ) status_stats
        ),
        'by_court_level', (
            SELECT json_object_agg(court_level, court_count)
            FROM (
                SELECT court_level, COUNT(*) as court_count
                FROM legal_documents
                WHERE court_level IS NOT NULL
                GROUP BY court_level
            ) court_stats
        )
    ) INTO result;
    
    RETURN result;
END;
$ LANGUAGE plpgsql;

-- Trigger: Automatische Zeitstempel
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

-- User für bessere Sicherheit erstellen
CREATE USER legal_readonly WITH PASSWORD 'readonly-password-123';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO legal_readonly;

COMMIT;
