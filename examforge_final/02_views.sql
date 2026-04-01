-- ================================================================
--  ExamForge · 02_views.sql
--  Reporting views — never write raw joins in application code
--  Run after 01_schema.sql
-- ================================================================

USE examforge;

-- ----------------------------------------------------------------
-- V1: Full test details with creator name and question count
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_test_details AS
SELECT
    t.TestID,
    t.Title,
    t.Description,
    t.Duration,
    t.StartTime,
    t.EndTime,
    t.TotalMarks,
    t.PassMarks,
    t.MaxAttempts,
    t.Shuffle,
    t.IsActive,
    t.CreatedAt,
    u.Name        AS CreatorName,
    u.Role        AS CreatorRole,
    c.Code        AS CourseCode,
    c.Title       AS CourseTitle,
    COUNT(q.QuestionID)                         AS TotalQuestions,
    COUNT(CASE WHEN q.IsApproved = 1 THEN 1 END) AS ApprovedQuestions
FROM TESTS t
JOIN USERS   u ON t.CreatedBy  = u.UserID
LEFT JOIN COURSES   c ON t.CourseID   = c.CourseID
LEFT JOIN QUESTIONS q ON t.TestID     = q.TestID
GROUP BY
    t.TestID, t.Title, t.Description, t.Duration,
    t.StartTime, t.EndTime, t.TotalMarks, t.PassMarks,
    t.MaxAttempts, t.Shuffle, t.IsActive, t.CreatedAt,
    u.Name, u.Role, c.Code, c.Title;

-- ----------------------------------------------------------------
-- V2: Student submission summary with test and user info
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_submission_summary AS
SELECT
    s.SubID,
    s.AttemptNumber,
    s.TotalScore,
    s.MaxScore,
    s.Percentage,
    s.IsPassed,
    s.TimeTaken,
    s.SubmittedAt,
    u.UserID,
    u.Name        AS StudentName,
    u.Email       AS StudentEmail,
    t.TestID,
    t.Title       AS TestTitle,
    t.Duration,
    t.TotalMarks,
    t.PassMarks,
    c.Code        AS CourseCode
FROM SUBMISSIONS s
JOIN USERS u ON s.UserID = u.UserID
JOIN TESTS t ON s.TestID = t.TestID
LEFT JOIN COURSES c ON t.CourseID = c.CourseID;

-- ----------------------------------------------------------------
-- V3: Leaderboard per test (best attempt per student)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_leaderboard AS
SELECT
    t.TestID,
    t.Title       AS TestTitle,
    u.UserID,
    u.Name        AS StudentName,
    best.TotalScore,
    best.Percentage,
    best.IsPassed,
    best.SubmittedAt,
    RANK() OVER (
        PARTITION BY t.TestID
        ORDER BY best.TotalScore DESC, best.TimeTaken ASC
    ) AS Rank_Position
FROM TESTS t
JOIN (
    SELECT UserID, TestID,
           MAX(TotalScore) AS TotalScore,
           MAX(Percentage) AS Percentage,
           MAX(IsPassed)   AS IsPassed,
           MIN(TimeTaken)  AS TimeTaken,
           MAX(SubmittedAt) AS SubmittedAt
    FROM SUBMISSIONS
    GROUP BY UserID, TestID
) best ON best.TestID = t.TestID
JOIN USERS u ON best.UserID = u.UserID;

-- ----------------------------------------------------------------
-- V4: Question accuracy report (how many got it right)
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_question_accuracy AS
SELECT
    q.QuestionID,
    q.TestID,
    LEFT(q.QuestionText, 80)   AS QuestionPreview,
    q.CorrectOption,
    q.Marks,
    COUNT(al.LogID)            AS TotalAttempts,
    SUM(al.IsCorrect)          AS CorrectAttempts,
    ROUND(
        100.0 * SUM(al.IsCorrect) / NULLIF(COUNT(al.LogID), 0), 2
    )                          AS AccuracyPct
FROM QUESTIONS q
LEFT JOIN ANSWERS_LOG al ON q.QuestionID = al.QuestionID
GROUP BY q.QuestionID, q.TestID, q.QuestionText, q.CorrectOption, q.Marks;

-- ----------------------------------------------------------------
-- V5: Instructor/TA contribution stats
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_contributor_stats AS
SELECT
    u.UserID,
    u.Name,
    u.Role,
    COUNT(q.QuestionID)                             AS TotalAdded,
    SUM(q.IsApproved)                               AS TotalApproved,
    COUNT(q.QuestionID) - SUM(q.IsApproved)         AS PendingApproval,
    ROUND(
        100.0 * SUM(q.IsApproved) / NULLIF(COUNT(q.QuestionID), 0), 2
    )                                               AS ApprovalRate
FROM USERS u
LEFT JOIN QUESTIONS q ON u.UserID = q.AddedBy
WHERE u.Role IN ('instructor', 'ta', 'incharge')
GROUP BY u.UserID, u.Name, u.Role;

-- ----------------------------------------------------------------
-- V6: Student performance across all tests
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_student_performance AS
SELECT
    u.UserID,
    u.Name        AS StudentName,
    u.Email,
    COUNT(DISTINCT s.TestID)               AS TestsAttempted,
    ROUND(AVG(s.Percentage), 2)            AS AvgPercentage,
    MAX(s.Percentage)                      AS BestPercentage,
    MIN(s.Percentage)                      AS LowestPercentage,
    SUM(s.IsPassed)                        AS TestsPassed,
    COUNT(DISTINCT s.TestID) - SUM(s.IsPassed) AS TestsFailed
FROM USERS u
JOIN SUBMISSIONS s ON u.UserID = s.UserID
WHERE u.Role = 'student'
GROUP BY u.UserID, u.Name, u.Email;
