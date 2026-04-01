-- ================================================================
--  ExamForge · 03_procedures.sql
--  Stored Procedures — all core business logic lives here
--  Run after 02_views.sql
-- ================================================================

USE examforge;
DELIMITER $$

-- ----------------------------------------------------------------
-- SP1: Register a new user
-- ----------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_register_user$$
CREATE PROCEDURE sp_register_user(
    IN  p_name      VARCHAR(100),
    IN  p_email     VARCHAR(150),
    IN  p_role      VARCHAR(20),
    IN  p_password  VARCHAR(255),   -- pass already-hashed value
    OUT p_user_id   INT,
    OUT p_message   VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_user_id = -1;
        SET p_message = 'Database error during registration.';
        ROLLBACK;
    END;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM USERS WHERE Email = p_email) THEN
        SET p_user_id = 0;
        SET p_message = 'Email already registered.';
        ROLLBACK;
    ELSE
        INSERT INTO USERS (Name, Email, Role, Password)
        VALUES (p_name, p_email, p_role, p_password);

        SET p_user_id = LAST_INSERT_ID();
        SET p_message = 'User registered successfully.';

        INSERT INTO AUDIT_LOG (UserID, Action, TableName, RecordID, NewValue)
        VALUES (p_user_id, 'REGISTER', 'USERS', p_user_id,
                CONCAT('name=', p_name, '; role=', p_role));

        COMMIT;
    END IF;
END$$

-- ----------------------------------------------------------------
-- SP2: Create a test
-- ----------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_create_test$$
CREATE PROCEDURE sp_create_test(
    IN  p_title       VARCHAR(200),
    IN  p_course_id   INT,
    IN  p_duration    INT,
    IN  p_start_time  DATETIME,
    IN  p_end_time    DATETIME,
    IN  p_pass_marks  INT,
    IN  p_shuffle     TINYINT,
    IN  p_max_att     INT,
    IN  p_created_by  INT,
    OUT p_test_id     INT,
    OUT p_message     VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_test_id = -1;
        SET p_message = 'Error creating test.';
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO TESTS (Title, CourseID, Duration, StartTime, EndTime,
                       PassMarks, Shuffle, MaxAttempts, CreatedBy)
    VALUES (p_title, p_course_id, p_duration, p_start_time, p_end_time,
            p_pass_marks, p_shuffle, p_max_att, p_created_by);

    SET p_test_id = LAST_INSERT_ID();
    SET p_message = 'Test created.';

    INSERT INTO AUDIT_LOG (UserID, Action, TableName, RecordID, NewValue)
    VALUES (p_created_by, 'CREATE_TEST', 'TESTS', p_test_id, p_title);

    COMMIT;
END$$

-- ----------------------------------------------------------------
-- SP3: Add / update a question
-- ----------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_upsert_question$$
CREATE PROCEDURE sp_upsert_question(
    IN  p_question_id   INT,          -- 0 = new, >0 = update
    IN  p_test_id       INT,
    IN  p_text          TEXT,
    IN  p_opt_a         VARCHAR(500),
    IN  p_opt_b         VARCHAR(500),
    IN  p_opt_c         VARCHAR(500),
    IN  p_opt_d         VARCHAR(500),
    IN  p_correct       CHAR(1),
    IN  p_marks         INT,
    IN  p_neg_marks     DECIMAL(4,2),
    IN  p_explanation   TEXT,
    IN  p_added_by      INT,
    OUT p_out_id        INT,
    OUT p_message       VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_out_id  = -1;
        SET p_message = 'Error saving question.';
        ROLLBACK;
    END;

    START TRANSACTION;

    IF p_question_id = 0 THEN
        INSERT INTO QUESTIONS
            (TestID, QuestionText, OptionA, OptionB, OptionC, OptionD,
             CorrectOption, Marks, NegativeMarks, Explanation, AddedBy)
        VALUES
            (p_test_id, p_text, p_opt_a, p_opt_b, p_opt_c, p_opt_d,
             p_correct, p_marks, p_neg_marks, p_explanation, p_added_by);

        SET p_out_id  = LAST_INSERT_ID();
        SET p_message = 'Question added.';
    ELSE
        UPDATE QUESTIONS SET
            QuestionText  = p_text,
            OptionA       = p_opt_a,
            OptionB       = p_opt_b,
            OptionC       = p_opt_c,
            OptionD       = p_opt_d,
            CorrectOption = p_correct,
            Marks         = p_marks,
            NegativeMarks = p_neg_marks,
            Explanation   = p_explanation,
            IsApproved    = 0            -- re-approval required on edit
        WHERE QuestionID = p_question_id;

        SET p_out_id  = p_question_id;
        SET p_message = 'Question updated. Re-approval required.';
    END IF;

    INSERT INTO AUDIT_LOG (UserID, Action, TableName, RecordID)
    VALUES (p_added_by,
            IF(p_question_id = 0, 'ADD_QUESTION', 'EDIT_QUESTION'),
            'QUESTIONS', p_out_id);

    COMMIT;
END$$

-- ----------------------------------------------------------------
-- SP4: Approve a question (incharge only)
-- ----------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_approve_question$$
CREATE PROCEDURE sp_approve_question(
    IN  p_question_id   INT,
    IN  p_approved_by   INT,
    OUT p_message       VARCHAR(200)
)
BEGIN
    UPDATE QUESTIONS SET IsApproved = 1
    WHERE QuestionID = p_question_id;

    INSERT INTO AUDIT_LOG (UserID, Action, TableName, RecordID)
    VALUES (p_approved_by, 'APPROVE_QUESTION', 'QUESTIONS', p_question_id);

    SET p_message = 'Question approved.';
END$$

-- ----------------------------------------------------------------
-- SP5: Start a submission (student begins exam)
-- ----------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_start_submission$$
CREATE PROCEDURE sp_start_submission(
    IN  p_user_id   INT,
    IN  p_test_id   INT,
    OUT p_sub_id    INT,
    OUT p_message   VARCHAR(200)
)
BEGIN
    DECLARE v_attempts      INT DEFAULT 0;
    DECLARE v_max_attempts  INT DEFAULT 1;
    DECLARE v_max_score     INT DEFAULT 0;

    SELECT MaxAttempts INTO v_max_attempts FROM TESTS WHERE TestID = p_test_id;
    SELECT COUNT(*)    INTO v_attempts
    FROM SUBMISSIONS WHERE UserID = p_user_id AND TestID = p_test_id;
    SELECT SUM(Marks)  INTO v_max_score
    FROM QUESTIONS WHERE TestID = p_test_id AND IsApproved = 1;

    IF v_attempts >= v_max_attempts THEN
        SET p_sub_id  = 0;
        SET p_message = 'Maximum attempts reached.';
    ELSE
        INSERT INTO SUBMISSIONS (UserID, TestID, AttemptNumber, MaxScore)
        VALUES (p_user_id, p_test_id, v_attempts + 1, IFNULL(v_max_score, 0));

        SET p_sub_id  = LAST_INSERT_ID();
        SET p_message = 'Submission started.';
    END IF;
END$$

-- ----------------------------------------------------------------
-- SP6: Save a single answer (called on each option click)
-- ----------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_save_answer$$
CREATE PROCEDURE sp_save_answer(
    IN  p_sub_id        INT,
    IN  p_question_id   INT,
    IN  p_chosen        CHAR(1)
)
BEGIN
    DECLARE v_correct   CHAR(1);
    DECLARE v_marks     INT;
    DECLARE v_neg       DECIMAL(4,2);
    DECLARE v_is_correct TINYINT DEFAULT 0;
    DECLARE v_awarded   DECIMAL(4,2) DEFAULT 0;

    SELECT CorrectOption, Marks, NegativeMarks
    INTO v_correct, v_marks, v_neg
    FROM QUESTIONS WHERE QuestionID = p_question_id;

    IF p_chosen = v_correct THEN
        SET v_is_correct = 1;
        SET v_awarded    = v_marks;
    ELSEIF p_chosen != '' THEN
        SET v_awarded    = -v_neg;
    END IF;

    INSERT INTO ANSWERS_LOG
        (SubID, QuestionID, ChosenOption, IsCorrect, MarksAwarded)
    VALUES
        (p_sub_id, p_question_id, p_chosen, v_is_correct, v_awarded)
    ON DUPLICATE KEY UPDATE
        ChosenOption  = VALUES(ChosenOption),
        IsCorrect     = VALUES(IsCorrect),
        MarksAwarded  = VALUES(MarksAwarded),
        AnsweredAt    = NOW();
END$$

-- ----------------------------------------------------------------
-- SP7: Finalise and grade a submission
-- ----------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_finalise_submission$$
CREATE PROCEDURE sp_finalise_submission(
    IN  p_sub_id    INT,
    IN  p_time_taken INT,
    OUT p_score     DECIMAL(6,2),
    OUT p_pct       DECIMAL(5,2),
    OUT p_passed    TINYINT,
    OUT p_message   VARCHAR(200)
)
BEGIN
    DECLARE v_total     DECIMAL(6,2) DEFAULT 0;
    DECLARE v_max       INT          DEFAULT 0;
    DECLARE v_pass      INT          DEFAULT 0;
    DECLARE v_test_id   INT;

    SELECT TestID INTO v_test_id FROM SUBMISSIONS WHERE SubID = p_sub_id;

    -- Insert unanswered questions as blank
    INSERT IGNORE INTO ANSWERS_LOG (SubID, QuestionID, ChosenOption, IsCorrect, MarksAwarded)
    SELECT p_sub_id, q.QuestionID, '', 0, 0
    FROM QUESTIONS q
    WHERE q.TestID = v_test_id AND q.IsApproved = 1
      AND NOT EXISTS (
          SELECT 1 FROM ANSWERS_LOG al
          WHERE al.SubID = p_sub_id AND al.QuestionID = q.QuestionID
      );

    -- Sum marks
    SELECT IFNULL(SUM(al.MarksAwarded), 0)
    INTO v_total
    FROM ANSWERS_LOG al
    WHERE al.SubID = p_sub_id;

    -- Clamp negatives to 0
    IF v_total < 0 THEN SET v_total = 0; END IF;

    SELECT MaxScore, PassMarks
    INTO v_max, v_pass
    FROM SUBMISSIONS s
    JOIN TESTS t ON s.TestID = t.TestID
    WHERE s.SubID = p_sub_id;

    SET p_score  = v_total;
    SET p_pct    = ROUND(100.0 * v_total / NULLIF(v_max, 0), 2);
    SET p_passed = IF(v_total >= v_pass, 1, 0);

    UPDATE SUBMISSIONS SET
        TotalScore  = p_score,
        Percentage  = p_pct,
        IsPassed    = p_passed,
        TimeTaken   = p_time_taken,
        IsGraded    = 1
    WHERE SubID = p_sub_id;

    SET p_message = 'Graded successfully.';
END$$

DELIMITER ;
