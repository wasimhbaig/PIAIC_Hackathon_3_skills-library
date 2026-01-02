-- V3: Add assessments, quizzes, and grading tables

-- Assessments (quizzes and assignments)
CREATE TABLE IF NOT EXISTS assessments (
    id SERIAL PRIMARY KEY,
    lesson_id INTEGER REFERENCES course_lessons(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    assessment_type VARCHAR(50) NOT NULL,
    max_score INTEGER NOT NULL DEFAULT 100,
    passing_score INTEGER NOT NULL DEFAULT 70,
    time_limit_minutes INTEGER,
    max_attempts INTEGER DEFAULT 1,
    is_published BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_assessment_type CHECK (assessment_type IN ('quiz', 'assignment', 'exam', 'practice')),
    CONSTRAINT check_passing_score CHECK (passing_score >= 0 AND passing_score <= max_score)
);

-- Assessment questions
CREATE TABLE IF NOT EXISTS assessment_questions (
    id SERIAL PRIMARY KEY,
    assessment_id INTEGER REFERENCES assessments(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_type VARCHAR(50) NOT NULL,
    points INTEGER DEFAULT 1,
    order_index INTEGER NOT NULL,
    options JSONB,
    correct_answer JSONB,
    explanation TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_question_type CHECK (question_type IN ('multiple_choice', 'true_false', 'short_answer', 'essay', 'code'))
);

-- Student submissions
CREATE TABLE IF NOT EXISTS assessment_submissions (
    id SERIAL PRIMARY KEY,
    assessment_id INTEGER REFERENCES assessments(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    attempt_number INTEGER DEFAULT 1,
    answers JSONB NOT NULL,
    score INTEGER,
    max_score INTEGER,
    percentage DECIMAL(5, 2),
    status VARCHAR(50) DEFAULT 'in_progress',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMP,
    graded_at TIMESTAMP,
    graded_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    feedback TEXT,
    time_spent_minutes INTEGER,
    CONSTRAINT check_submission_status CHECK (status IN ('in_progress', 'submitted', 'graded', 'returned'))
);

-- Grading rubrics
CREATE TABLE IF NOT EXISTS grading_rubrics (
    id SERIAL PRIMARY KEY,
    assessment_id INTEGER REFERENCES assessments(id) ON DELETE CASCADE,
    criteria_name VARCHAR(255) NOT NULL,
    criteria_description TEXT,
    max_points INTEGER NOT NULL,
    order_index INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Student progress tracking
CREATE TABLE IF NOT EXISTS student_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    lesson_id INTEGER REFERENCES course_lessons(id) ON DELETE CASCADE,
    completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMP,
    time_spent_minutes INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, lesson_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_assessments_lesson ON assessments(lesson_id);
CREATE INDEX IF NOT EXISTS idx_assessment_questions_assessment ON assessment_questions(assessment_id);
CREATE INDEX IF NOT EXISTS idx_submissions_assessment ON assessment_submissions(assessment_id);
CREATE INDEX IF NOT EXISTS idx_submissions_user ON assessment_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON assessment_submissions(status);
CREATE INDEX IF NOT EXISTS idx_student_progress_user ON student_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_student_progress_course ON student_progress(course_id);
CREATE INDEX IF NOT EXISTS idx_student_progress_lesson ON student_progress(lesson_id);

-- Apply updated_at triggers
CREATE TRIGGER update_assessments_updated_at
    BEFORE UPDATE ON assessments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
