-- ================================================================
--  ExamForge · 01_schema.sql
--  Core DDL — tables, constraints, indexes
--  DBMS : MySQL 8.0+
--  Run  : mysql -u root -p < 01_schema.sql
-- ================================================================

CREATE DATABASE IF NOT EXISTS examforge
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE examforge;

-- ----------------------------------------------------------------
-- 1. USERS
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS USERS (
    UserID      INT            NOT NULL AUTO_INCREMENT,
    Name        VARCHAR(100)   NOT NULL,
    Email       VARCHAR(150)   NOT NULL,
    Role        ENUM('admin','instructor','ta','incharge','student')
                               NOT NULL DEFAULT 'student',
    Password    VARCHAR(255)   NOT NULL,          -- bcrypt hash
    IsActive    TINYINT(1)     NOT NULL DEFAULT 1,
    CreatedAt   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                               ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (UserID),
    UNIQUE  KEY uq_users_email (Email),
    INDEX   ix_users_role      (Role)
);

-- ----------------------------------------------------------------
-- 2. COURSES
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS COURSES (
    CourseID    INT            NOT NULL AUTO_INCREMENT,
    Code        VARCHAR(20)    NOT NULL,
    Title       VARCHAR(200)   NOT NULL,
    InchargeID  INT            NOT NULL,          -- FK → USERS(incharge)
    CreatedAt   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (CourseID),
    UNIQUE  KEY uq_courses_code (Code),
    CONSTRAINT fk_course_incharge
        FOREIGN KEY (InchargeID) REFERENCES USERS(UserID)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------
-- 3. COURSE_MEMBERS  (who belongs to which course)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS COURSE_MEMBERS (
    MemberID    INT            NOT NULL AUTO_INCREMENT,
    CourseID    INT            NOT NULL,
    UserID      INT            NOT NULL,
    JoinedAt    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (MemberID),
    UNIQUE  KEY uq_course_member (CourseID, UserID),
    CONSTRAINT fk_cm_course FOREIGN KEY (CourseID) REFERENCES COURSES(CourseID) ON DELETE CASCADE,
    CONSTRAINT fk_cm_user   FOREIGN KEY (UserID)   REFERENCES USERS(UserID)     ON DELETE CASCADE
);

-- ----------------------------------------------------------------
-- 4. TESTS
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS TESTS (
    TestID          INT            NOT NULL AUTO_INCREMENT,
    CourseID        INT                NULL,               -- optional link
    Title           VARCHAR(200)   NOT NULL,
    Description     TEXT               NULL,
    Duration        INT            NOT NULL,               -- minutes
    StartTime       DATETIME       NOT NULL,
    EndTime         DATETIME       NOT NULL,
    TotalMarks      INT            NOT NULL DEFAULT 0,     -- updated by trigger
    PassMarks       INT            NOT NULL DEFAULT 0,
    MaxAttempts     INT            NOT NULL DEFAULT 1,
    Shuffle         TINYINT(1)     NOT NULL DEFAULT 0,     -- shuffle questions
    CreatedBy       INT            NOT NULL,
    IsActive        TINYINT(1)     NOT NULL DEFAULT 1,
    CreatedAt       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (TestID),
    CONSTRAINT fk_test_course  FOREIGN KEY (CourseID)  REFERENCES COURSES(CourseID) ON DELETE SET NULL,
    CONSTRAINT fk_test_creator FOREIGN KEY (CreatedBy) REFERENCES USERS(UserID)    ON DELETE RESTRICT,
    CONSTRAINT chk_test_times  CHECK (EndTime > StartTime),
    INDEX ix_tests_active (IsActive, StartTime)
);

-- ----------------------------------------------------------------
-- 5. QUESTIONS
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS QUESTIONS (
    QuestionID      INT            NOT NULL AUTO_INCREMENT,
    TestID          INT            NOT NULL,
    QuestionText    TEXT           NOT NULL,
    OptionA         VARCHAR(500)   NOT NULL,
    OptionB         VARCHAR(500)   NOT NULL,
    OptionC         VARCHAR(500)   NOT NULL,
    OptionD         VARCHAR(500)   NOT NULL,
    CorrectOption   ENUM('A','B','C','D') NOT NULL,
    Marks           INT            NOT NULL DEFAULT 1,
    NegativeMarks   DECIMAL(4,2)   NOT NULL DEFAULT 0.00,
    Explanation     TEXT               NULL,
    AddedBy         INT            NOT NULL,               -- instructor/ta
    IsApproved      TINYINT(1)     NOT NULL DEFAULT 0,     -- incharge approves
    CreatedAt       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (QuestionID),
    CONSTRAINT fk_question_test  FOREIGN KEY (TestID)   REFERENCES TESTS(TestID) ON DELETE CASCADE,
    CONSTRAINT fk_question_added FOREIGN KEY (AddedBy)  REFERENCES USERS(UserID) ON DELETE RESTRICT,
    INDEX ix_questions_test     (TestID),
    INDEX ix_questions_approved (IsApproved)
);

-- ----------------------------------------------------------------
-- 6. SUBMISSIONS
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SUBMISSIONS (
    SubID           INT            NOT NULL AUTO_INCREMENT,
    UserID          INT            NOT NULL,
    TestID          INT            NOT NULL,
    AttemptNumber   INT            NOT NULL DEFAULT 1,
    TotalScore      DECIMAL(6,2)   NOT NULL DEFAULT 0.00,
    MaxScore        INT            NOT NULL DEFAULT 0,
    Percentage      DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
    IsPassed        TINYINT(1)     NOT NULL DEFAULT 0,
    TimeTaken       INT            NOT NULL DEFAULT 0,     -- seconds
    SubmittedAt     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    IsGraded        TINYINT(1)     NOT NULL DEFAULT 0,

    PRIMARY KEY (SubID),
    CONSTRAINT fk_sub_user FOREIGN KEY (UserID) REFERENCES USERS(UserID)  ON DELETE CASCADE,
    CONSTRAINT fk_sub_test FOREIGN KEY (TestID) REFERENCES TESTS(TestID)  ON DELETE CASCADE,
    UNIQUE  KEY uq_sub_attempt (UserID, TestID, AttemptNumber),
    INDEX   ix_sub_test  (TestID),
    INDEX   ix_sub_user  (UserID)
);

-- ----------------------------------------------------------------
-- 7. ANSWERS_LOG
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ANSWERS_LOG (
    LogID           INT            NOT NULL AUTO_INCREMENT,
    SubID           INT            NOT NULL,
    QuestionID      INT            NOT NULL,
    ChosenOption    ENUM('A','B','C','D','') NOT NULL DEFAULT '',
    IsCorrect       TINYINT(1)     NOT NULL DEFAULT 0,
    MarksAwarded    DECIMAL(4,2)   NOT NULL DEFAULT 0.00,
    AnsweredAt      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (LogID),
    CONSTRAINT fk_log_sub      FOREIGN KEY (SubID)      REFERENCES SUBMISSIONS(SubID)  ON DELETE CASCADE,
    CONSTRAINT fk_log_question FOREIGN KEY (QuestionID) REFERENCES QUESTIONS(QuestionID) ON DELETE CASCADE,
    UNIQUE  KEY uq_log_answer (SubID, QuestionID),
    INDEX   ix_log_sub (SubID)
);

-- ----------------------------------------------------------------
-- 8. AUDIT_LOG
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AUDIT_LOG (
    AuditID     INT            NOT NULL AUTO_INCREMENT,
    UserID      INT                NULL,
    Action      VARCHAR(100)   NOT NULL,
    TableName   VARCHAR(50)        NULL,
    RecordID    INT                NULL,
    OldValue    TEXT               NULL,
    NewValue    TEXT               NULL,
    IPAddress   VARCHAR(45)        NULL,
    CreatedAt   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (AuditID),
    INDEX ix_audit_user  (UserID),
    INDEX ix_audit_table (TableName, RecordID)
);
