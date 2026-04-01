-- ================================================================
--  ExamForge · 04_triggers.sql
--  Triggers — automation, integrity, audit
--  Run after 03_procedures.sql
-- ================================================================

USE examforge;
DELIMITER $$

-- ----------------------------------------------------------------
-- T1: After INSERT on QUESTIONS → update TESTS.TotalMarks
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_question_insert$$
CREATE TRIGGER trg_after_question_insert
AFTER INSERT ON QUESTIONS
FOR EACH ROW
BEGIN
    IF NEW.IsApproved = 1 THEN
        UPDATE TESTS
        SET TotalMarks = (
            SELECT IFNULL(SUM(Marks), 0)
            FROM QUESTIONS
            WHERE TestID = NEW.TestID AND IsApproved = 1
        )
        WHERE TestID = NEW.TestID;
    END IF;
END$$

-- ----------------------------------------------------------------
-- T2: After UPDATE on QUESTIONS → recalculate TotalMarks
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_question_update$$
CREATE TRIGGER trg_after_question_update
AFTER UPDATE ON QUESTIONS
FOR EACH ROW
BEGIN
    -- Recalculate whenever marks or approval status changes
    IF OLD.Marks != NEW.Marks OR OLD.IsApproved != NEW.IsApproved THEN
        UPDATE TESTS
        SET TotalMarks = (
            SELECT IFNULL(SUM(Marks), 0)
            FROM QUESTIONS
            WHERE TestID = NEW.TestID AND IsApproved = 1
        )
        WHERE TestID = NEW.TestID;
    END IF;
END$$

-- ----------------------------------------------------------------
-- T3: After DELETE on QUESTIONS → recalculate TotalMarks
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_question_delete$$
CREATE TRIGGER trg_after_question_delete
AFTER DELETE ON QUESTIONS
FOR EACH ROW
BEGIN
    UPDATE TESTS
    SET TotalMarks = (
        SELECT IFNULL(SUM(Marks), 0)
        FROM QUESTIONS
        WHERE TestID = OLD.TestID AND IsApproved = 1
    )
    WHERE TestID = OLD.TestID;
END$$

-- ----------------------------------------------------------------
-- T4: Before INSERT on SUBMISSIONS → enforce MaxAttempts
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_before_submission_insert$$
CREATE TRIGGER trg_before_submission_insert
BEFORE INSERT ON SUBMISSIONS
FOR EACH ROW
BEGIN
    DECLARE v_attempts    INT DEFAULT 0;
    DECLARE v_max_att     INT DEFAULT 1;
    DECLARE v_test_active TINYINT DEFAULT 0;
    DECLARE v_now         DATETIME DEFAULT NOW();

    SELECT MaxAttempts, IsActive,
           (StartTime <= v_now AND EndTime >= v_now)
    INTO v_max_att, v_test_active, @win
    FROM TESTS WHERE TestID = NEW.TestID;

    SELECT COUNT(*) INTO v_attempts
    FROM SUBMISSIONS
    WHERE UserID = NEW.UserID AND TestID = NEW.TestID;

    IF v_attempts >= v_max_att THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Maximum attempts exceeded for this test.';
    END IF;

    IF v_test_active = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'This test is not currently active.';
    END IF;
END$$

-- ----------------------------------------------------------------
-- T5: After INSERT on SUBMISSIONS → audit log entry
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_submission_insert$$
CREATE TRIGGER trg_after_submission_insert
AFTER INSERT ON SUBMISSIONS
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (UserID, Action, TableName, RecordID, NewValue)
    VALUES (NEW.UserID, 'START_EXAM', 'SUBMISSIONS', NEW.SubID,
            CONCAT('TestID=', NEW.TestID, '; Attempt=', NEW.AttemptNumber));
END$$

-- ----------------------------------------------------------------
-- T6: After UPDATE on SUBMISSIONS (graded) → audit log
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_after_submission_graded$$
CREATE TRIGGER trg_after_submission_graded
AFTER UPDATE ON SUBMISSIONS
FOR EACH ROW
BEGIN
    IF OLD.IsGraded = 0 AND NEW.IsGraded = 1 THEN
        INSERT INTO AUDIT_LOG (UserID, Action, TableName, RecordID, NewValue)
        VALUES (NEW.UserID, 'EXAM_GRADED', 'SUBMISSIONS', NEW.SubID,
                CONCAT('Score=', NEW.TotalScore, '/', NEW.MaxScore,
                       ' (', NEW.Percentage, '%) Passed=', NEW.IsPassed));
    END IF;
END$$

-- ----------------------------------------------------------------
-- T7: Before UPDATE on USERS → log role changes
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_before_user_role_change$$
CREATE TRIGGER trg_before_user_role_change
BEFORE UPDATE ON USERS
FOR EACH ROW
BEGIN
    IF OLD.Role != NEW.Role THEN
        INSERT INTO AUDIT_LOG
            (UserID, Action, TableName, RecordID, OldValue, NewValue)
        VALUES
            (NEW.UserID, 'ROLE_CHANGE', 'USERS', NEW.UserID,
             OLD.Role, NEW.Role);
    END IF;
END$$

-- ----------------------------------------------------------------
-- T8: Before DELETE on USERS → prevent deleting last admin
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_before_user_delete$$
CREATE TRIGGER trg_before_user_delete
BEFORE DELETE ON USERS
FOR EACH ROW
BEGIN
    DECLARE v_admin_count INT DEFAULT 0;

    IF OLD.Role = 'admin' THEN
        SELECT COUNT(*) INTO v_admin_count
        FROM USERS WHERE Role = 'admin' AND UserID != OLD.UserID;

        IF v_admin_count = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot delete the last admin account.';
        END IF;
    END IF;
END$$

DELIMITER ;
