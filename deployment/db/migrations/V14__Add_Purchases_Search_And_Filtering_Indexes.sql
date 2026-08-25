-- V14: Add Performance Indexes for Purchase Search, Status & Date Filtering
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Fast sorting and date range queries on purchases
CREATE INDEX IF NOT EXISTS idx_purchases_purchased_at ON purchases(purchased_at DESC);

-- Fast filtering by transaction status and payment gateway
CREATE INDEX IF NOT EXISTS idx_purchases_status ON purchases(status);
CREATE INDEX IF NOT EXISTS idx_purchases_provider ON purchases(payment_provider);
CREATE INDEX IF NOT EXISTS idx_purchases_course_id ON purchases(course_id);

-- Composite index for the most common ledger query: completed purchases sorted by timestamp
CREATE INDEX IF NOT EXISTS idx_purchases_status_date ON purchases(status, purchased_at DESC);

-- Fast substring searches on transaction ID and user mobile number
CREATE INDEX IF NOT EXISTS idx_purchases_tx_trgm ON purchases USING gin (transaction_id gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_mobile_trgm ON users USING gin (mobile_number gin_trgm_ops);
