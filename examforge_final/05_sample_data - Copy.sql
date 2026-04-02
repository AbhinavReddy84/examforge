-- ExamForge · 05_sample_data.sql (Fixed)
USE examforge;

-- Clear existing data
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE ANSWERS_LOG;
TRUNCATE TABLE SUBMISSIONS;
TRUNCATE TABLE QUESTIONS;
TRUNCATE TABLE TESTS;
TRUNCATE TABLE COURSE_MEMBERS;
TRUNCATE TABLE COURSES;
TRUNCATE TABLE AUDIT_LOG;
TRUNCATE TABLE USERS;
SET FOREIGN_KEY_CHECKS = 1;

-- USERS (password stored as plain text for demo; use bcrypt in production)
INSERT INTO USERS (UserID, Name, Email, Role, Password, IsActive) VALUES
(1,'Admin','admin@examforge.edu','admin','password123',1),
(2,'Dr. Priya Sharma','priya@examforge.edu','instructor','password123',1),
(3,'Prof. Rahul Menon','rahul@examforge.edu','instructor','password123',1),
(4,'Anita Das','anita.ta@examforge.edu','ta','password123',1),
(5,'Vikram Nair','vikram.ta@examforge.edu','ta','password123',1),
(6,'Dr. Leela Iyer','leela@examforge.edu','incharge','password123',1),
(7,'Arjun Kumar','s1@examforge.edu','student','password123',1),
(8,'Meera Nair','s2@examforge.edu','student','password123',1),
(9,'Rohan Pillai','s3@examforge.edu','student','password123',1),
(10,'Sneha Bhat','s4@examforge.edu','student','password123',1),
(11,'Kiran Rao','s5@examforge.edu','student','password123',1);

-- COURSES
INSERT INTO COURSES (CourseID, Code, Title, InchargeID) VALUES
(1,'CS301','Database Management Systems',6),
(2,'CS201','Data Structures & Algorithms',6),
(3,'CS401','Computer Networks',6);

-- COURSE_MEMBERS
INSERT INTO COURSE_MEMBERS (CourseID, UserID) VALUES
(1,2),(1,4),(1,7),(1,8),(1,9),(1,10),(1,11),
(2,3),(2,5),(2,7),(2,8),(2,9),
(3,2),(3,7),(3,10),(3,11);

-- TESTS (open window so students can attempt them)
INSERT INTO TESTS (TestID, CourseID, Title, Description, Duration, StartTime, EndTime,
                   TotalMarks, PassMarks, MaxAttempts, Shuffle, CreatedBy, IsActive) VALUES
(1,1,'DBMS Mid-Term Exam','Covers ER diagrams, SQL basics, normalization.',60,
 '2026-01-01 09:00:00','2026-12-31 23:59:59',0,6,1,1,2,1),
(2,2,'DSA Quiz 1','Basic data structures and algorithm complexity.',30,
 '2026-01-01 10:00:00','2026-12-31 23:59:59',0,3,2,0,3,1),
(3,1,'SQL Lab Test','Practical SQL query writing.',45,
 '2026-01-01 14:00:00','2026-12-31 23:59:59',0,5,1,1,2,1);

-- QUESTIONS for Test 1 (DBMS)
INSERT INTO QUESTIONS (QuestionID, TestID, QuestionText, OptionA, OptionB, OptionC, OptionD,
                        CorrectOption, Marks, NegativeMarks, Explanation, AddedBy, IsApproved) VALUES
(1,1,'Which of the following SQL JOIN types is NOT valid?',
 'INNER JOIN','OUTER JOIN','CROSS JOIN','CIRCULAR JOIN','D',1,0.25,'CIRCULAR JOIN does not exist in SQL.',2,1),
(2,1,'What does ACID stand for in database transactions?',
 'Atomicity, Consistency, Isolation, Durability',
 'Access, Control, Integrity, Durability',
 'Atomicity, Concurrency, Isolation, Data',
 'Auto-commit, Consistency, Indexing, Durability','A',1,0.25,'ACID = Atomicity, Consistency, Isolation, Durability.',2,1),
(3,1,'Which normal form eliminates partial dependencies?',
 'First Normal Form (1NF)','Second Normal Form (2NF)',
 'Third Normal Form (3NF)','Boyce-Codd Normal Form (BCNF)','B',1,0.25,'2NF removes partial dependencies on the primary key.',2,1),
(4,1,'What is a PRIMARY KEY constraint?',
 'Allows duplicate values','Allows NULL values',
 'Uniquely identifies each row','Links two tables together','C',1,0,'A primary key uniquely identifies each record in a table.',2,1),
(5,1,'Which command removes all rows from a table without logging individual deletions?',
 'DELETE','DROP','TRUNCATE','REMOVE','C',1,0.25,'TRUNCATE removes all rows quickly without row-level logging.',6,1);

-- QUESTIONS for Test 2 (DSA)
INSERT INTO QUESTIONS (QuestionID, TestID, QuestionText, OptionA, OptionB, OptionC, OptionD,
                        CorrectOption, Marks, NegativeMarks, Explanation, AddedBy, IsApproved) VALUES
(11,2,'What is the time complexity of searching in an unsorted array?',
 'O(1)','O(log n)','O(n)','O(n²)','C',1,0,'Linear search in an unsorted array is O(n).',3,1),
(12,2,'Which data structure uses LIFO ordering?',
 'Queue','Stack','LinkedList','Heap','B',1,0.25,'Stack uses Last-In First-Out (LIFO).',3,1),
(13,2,'What is the worst-case time complexity of QuickSort?',
 'O(n log n)','O(n)','O(n²)','O(log n)','C',1,0,'QuickSort worst case is O(n²) when pivot is always the smallest/largest.',5,1);

-- QUESTIONS for Test 3 (SQL Lab)
INSERT INTO QUESTIONS (QuestionID, TestID, QuestionText, OptionA, OptionB, OptionC, OptionD,
                        CorrectOption, Marks, NegativeMarks, Explanation, AddedBy, IsApproved) VALUES
(16,3,'Which clause is used to filter groups in SQL?',
 'WHERE','HAVING','FILTER','GROUP BY','B',1,0,'HAVING filters groups; WHERE filters rows.',2,1),
(17,3,'What does the COUNT(*) function do?',
 'Counts non-NULL values only','Counts all rows including NULLs',
 'Counts distinct values','Counts only numeric columns','B',1,0.25,'COUNT(*) counts all rows including those with NULL values.',2,1),
(18,3,'Which keyword prevents duplicate rows in SELECT results?',
 'UNIQUE','DISTINCT','DIFFERENT','NODUPLICATE','B',1,0,'SELECT DISTINCT removes duplicate rows from result set.',6,1);