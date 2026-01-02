-- V4: Add analytics and metrics tables

-- Analytics events (for event sourcing from Kafka)
CREATE TABLE IF NOT EXISTS analytics_events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    course_id INTEGER REFERENCES courses(id) ON DELETE SET NULL,
    lesson_id INTEGER REFERENCES course_lessons(id) ON DELETE SET NULL,
    event_data JSONB NOT NULL,
    session_id VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Partitioning for analytics_events (by month)
-- Note: Requires PostgreSQL 10+ with declarative partitioning

-- User activity summary (materialized view for performance)
CREATE TABLE IF NOT EXISTS user_activity_summary (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_courses_enrolled INTEGER DEFAULT 0,
    total_courses_completed INTEGER DEFAULT 0,
    total_lessons_completed INTEGER DEFAULT 0,
    total_assessments_taken INTEGER DEFAULT 0,
    total_time_spent_minutes INTEGER DEFAULT 0,
    average_score DECIMAL(5, 2),
    last_activity_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Course analytics
CREATE TABLE IF NOT EXISTS course_analytics (
    course_id INTEGER PRIMARY KEY REFERENCES courses(id) ON DELETE CASCADE,
    total_enrollments INTEGER DEFAULT 0,
    active_students INTEGER DEFAULT 0,
    completion_rate DECIMAL(5, 2) DEFAULT 0.00,
    average_rating DECIMAL(3, 2),
    total_reviews INTEGER DEFAULT 0,
    average_completion_time_hours INTEGER,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Learning metrics (daily aggregates)
CREATE TABLE IF NOT EXISTS daily_metrics (
    id SERIAL PRIMARY KEY,
    metric_date DATE NOT NULL,
    total_active_users INTEGER DEFAULT 0,
    new_enrollments INTEGER DEFAULT 0,
    lessons_completed INTEGER DEFAULT 0,
    assessments_submitted INTEGER DEFAULT 0,
    average_session_duration_minutes INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(metric_date)
);

-- User engagement scores
CREATE TABLE IF NOT EXISTS user_engagement_scores (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    score_date DATE NOT NULL,
    engagement_score INTEGER NOT NULL,
    login_count INTEGER DEFAULT 0,
    content_views INTEGER DEFAULT 0,
    assessments_taken INTEGER DEFAULT 0,
    discussion_posts INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, score_date)
);

-- Create indexes for analytics
CREATE INDEX IF NOT EXISTS idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created ON analytics_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_course ON analytics_events(course_id);
CREATE INDEX IF NOT EXISTS idx_daily_metrics_date ON daily_metrics(metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_engagement_user ON user_engagement_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_user_engagement_date ON user_engagement_scores(score_date DESC);

-- Create GIN index for JSONB queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_data ON analytics_events USING GIN (event_data);

-- Function to update user activity summary
CREATE OR REPLACE FUNCTION update_user_activity_summary(p_user_id INTEGER)
RETURNS VOID AS $$
BEGIN
    INSERT INTO user_activity_summary (
        user_id,
        total_courses_enrolled,
        total_courses_completed,
        total_lessons_completed,
        total_assessments_taken,
        total_time_spent_minutes,
        average_score,
        last_activity_at
    )
    SELECT
        p_user_id,
        COUNT(DISTINCT e.course_id),
        COUNT(DISTINCT CASE WHEN e.completed_at IS NOT NULL THEN e.course_id END),
        COUNT(DISTINCT p.lesson_id),
        COUNT(DISTINCT s.id),
        COALESCE(SUM(p.time_spent_minutes), 0),
        AVG(s.percentage),
        MAX(GREATEST(e.last_accessed_at, p.last_accessed_at, s.submitted_at))
    FROM users u
    LEFT JOIN course_enrollments e ON u.id = e.user_id
    LEFT JOIN student_progress p ON u.id = p.user_id
    LEFT JOIN assessment_submissions s ON u.id = s.user_id
    WHERE u.id = p_user_id
    GROUP BY u.id
    ON CONFLICT (user_id) DO UPDATE SET
        total_courses_enrolled = EXCLUDED.total_courses_enrolled,
        total_courses_completed = EXCLUDED.total_courses_completed,
        total_lessons_completed = EXCLUDED.total_lessons_completed,
        total_assessments_taken = EXCLUDED.total_assessments_taken,
        total_time_spent_minutes = EXCLUDED.total_time_spent_minutes,
        average_score = EXCLUDED.average_score,
        last_activity_at = EXCLUDED.last_activity_at,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER update_user_activity_summary_updated_at
    BEFORE UPDATE ON user_activity_summary
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_course_analytics_updated_at
    BEFORE UPDATE ON course_analytics
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
