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

-- USERS (plain text passwords for demo)
INSERT INTO USERS (UserID, Name, Email, Role, Password) VALUES
(1,  'Admin',             'admin@examforge.edu',     'admin',      'password123'),
(2,  'Dr. Priya Sharma',  'priya@examforge.edu',     'instructor', 'password123'),
(3,  'Prof. Rahul Menon', 'rahul@examforge.edu',     'instructor', 'password123'),
(4,  'Anita Das',         'anita.ta@examforge.edu',  'ta',         'password123'),
(5,  'Vikram Nair',       'vikram.ta@examforge.edu', 'ta',         'password123'),
(6,  'Dr. Leela Iyer',    'leela@examforge.edu',     'incharge',   'password123'),
(7,  'Arjun Kumar',       's1@examforge.edu',        'student',    'password123'),
(8,  'Meera Nair',        's2@examforge.edu',        'student',    'password123'),
(9,  'Rohan Pillai',      's3@examforge.edu',        'student',    'password123'),
(10, 'Sneha Bhat',        's4@examforge.edu',        'student',    'password123'),
(11, 'Kiran Rao',         's5@examforge.edu',        'student',    'password123');

-- COURSES
INSERT INTO COURSES (CourseID, Code, Title, InchargeID) VALUES
(1, 'CS301', 'Database Management Systems', 6),
(2, 'CS201', 'Data Structures & Algorithms', 6),
(3, 'CS401', 'Computer Networks', 6);

-- COURSE_MEMBERS
INSERT INTO COURSE_MEMBERS (CourseID, UserID) VALUES
(1,2),(1,4),(1,7),(1,8),(1,9),(1,10),(1,11),
(2,3),(2,5),(2,7),(2,8),(2,9),
(3,2),(3,7),(3,10),(3,11);

-- TESTS
INSERT INTO TESTS (TestID, CourseID, Title, Description, Duration, StartTime, EndTime, TotalMarks, PassMarks, MaxAttempts, Shuffle, CreatedBy) VALUES
(1, 1, 'DBMS Mid-Term Exam',       'Covers ER diagrams, SQL, normalisation, transactions.', 60, '2026-01-01 09:00:00', '2026-12-31 23:59:59', 10, 6, 1, 1, 2),
(2, 2, 'DSA Quiz 1',               'Basic DSA concepts, time complexity, array operations.', 30, '2026-01-01 10:00:00', '2026-12-31 23:59:59', 5,  3, 2, 0, 3),
(3, 1, 'SQL Lab Test',             'Practical SQL queries: joins, subqueries, aggregation.', 45, '2026-01-01 14:00:00', '2026-12-31 23:59:59', 8,  5, 1, 1, 2);

-- QUESTIONS Test 1
INSERT INTO QUESTIONS (QuestionID, TestID, QuestionText, OptionA, OptionB, OptionC, OptionD, CorrectOption, Marks, NegativeMarks, Explanation, AddedBy, IsApproved) VALUES
(1,  1, 'Which of the following is NOT a type of SQL join?', 'INNER JOIN', 'OUTER JOIN', 'CROSS JOIN', 'CIRCULAR JOIN', 'D', 1, 0.25, 'CIRCULAR JOIN does not exist in SQL.', 2, 1),
(2,  1, 'What does ACID stand for in database transactions?', 'Atomicity, Consistency, Isolation, Durability', 'Access, Control, Integrity, Data', 'Automated, Consistent, Indexed, Dynamic', 'Associative, Cascading, Integrated, Distributed', 'A', 1, 0.25, 'ACID ensures reliable database transactions.', 2, 1),
(3,  1, 'Which normal form eliminates transitive functional dependencies?', '1NF', '2NF', '3NF', 'BCNF', 'C', 1, 0.25, '3NF removes transitive dependencies from non-prime attributes.', 4, 1),
(4,  1, 'A PRIMARY KEY constraint ensures which of the following?', 'Values can be NULL', 'Each row has a unique identifier, no NULLs allowed', 'It is always a single column', 'It can be duplicated across tables', 'B', 1, 0.25, 'Primary key = unique + NOT NULL.', 2, 1),
(5,  1, 'Which SQL command permanently removes a table and its data?', 'DELETE TABLE', 'REMOVE TABLE', 'DROP TABLE', 'TRUNCATE TABLE', 'C', 1, 0.25, 'DROP TABLE removes structure and data.', 4, 1),
(6,  1, 'In an ER diagram, a double rectangle represents:', 'A weak entity set', 'A strong entity set', 'A derived attribute', 'A multivalued attribute', 'A', 1, 0.25, 'Weak entities are shown with double rectangles.', 2, 1),
(7,  1, 'Which isolation level prevents dirty reads but allows non-repeatable reads?', 'READ UNCOMMITTED', 'READ COMMITTED', 'REPEATABLE READ', 'SERIALIZABLE', 'B', 1, 0.25, 'READ COMMITTED prevents dirty reads.', 4, 1),
(8,  1, 'The result of a NATURAL JOIN is:', 'Cartesian product of two tables', 'Join on all columns with the same name', 'Join specified with ON clause only', 'Same as a LEFT OUTER JOIN', 'B', 1, 0.25, 'NATURAL JOIN automatically joins on matching column names.', 2, 1),
(9,  1, 'Which command rolls back a transaction to a specific point?', 'ROLLBACK TO SAVEPOINT', 'UNDO', 'REVERT', 'RESTORE', 'A', 1, 0.25, 'SAVEPOINT and ROLLBACK TO SAVEPOINT provide partial rollback.', 4, 1),
(10, 1, 'A foreign key constraint enforces:', 'Entity integrity', 'Domain integrity', 'Referential integrity', 'User-defined integrity', 'C', 1, 0.25, 'Referential integrity ensures FK values exist in the referenced table.', 2, 1),

-- QUESTIONS Test 2
(11, 2, 'What is the time complexity of searching in an unsorted array?', 'O(1)', 'O(log n)', 'O(n)', 'O(n2)', 'C', 1, 0.00, 'Linear search on unsorted array is O(n).', 3, 1),
(12, 2, 'Which data structure uses LIFO order?', 'Queue', 'Stack', 'Linked List', 'Tree', 'B', 1, 0.00, 'Stack follows Last In First Out.', 5, 1),
(13, 2, 'In a singly linked list, insertion at the beginning is:', 'O(n)', 'O(log n)', 'O(1)', 'O(n2)', 'C', 1, 0.00, 'Prepend to linked list only requires updating the head pointer.', 3, 1),
(14, 2, 'What is stored in each node of a doubly linked list?', 'Data and one pointer', 'Data and two pointers (prev and next)', 'Only a pointer to next', 'Data and an index', 'B', 1, 0.00, 'Doubly linked list nodes hold data, next, and prev pointers.', 5, 1),
(15, 2, 'Binary search requires the array to be:', 'Unsorted', 'Sorted', 'Filled with integers only', 'Of even length', 'B', 1, 0.00, 'Binary search only works on sorted arrays.', 3, 1),

-- QUESTIONS Test 3
(16, 3, 'Which clause is used to filter groups in a GROUP BY query?', 'WHERE', 'HAVING', 'FILTER', 'GROUP FILTER', 'B', 1, 0.00, 'HAVING filters after aggregation; WHERE filters before.', 2, 1),
(17, 3, 'What does SELECT DISTINCT do?', 'Selects only NULL values', 'Returns only unique rows', 'Sorts results in ascending order', 'Selects the first distinct record only', 'B', 1, 0.00, 'DISTINCT eliminates duplicate rows.', 4, 1),
(18, 3, 'A correlated subquery differs from a regular subquery because:', 'It is faster', 'It references the outer query', 'It uses JOIN internally', 'It cannot use aggregate functions', 'B', 2, 0.00, 'A correlated subquery uses a column from the outer query.', 2, 1),
(19, 3, 'Which aggregate function returns the number of non-NULL values?', 'SUM()', 'AVG()', 'COUNT(column)', 'MAX()', 'C', 1, 0.00, 'COUNT(column) counts non-NULL values.', 4, 1),
(20, 3, 'What is the correct order of SQL clauses?', 'SELECT FROM WHERE GROUP BY HAVING ORDER BY', 'SELECT WHERE FROM GROUP BY HAVING ORDER BY', 'FROM WHERE SELECT GROUP BY ORDER BY HAVING', 'FROM SELECT GROUP BY WHERE ORDER BY HAVING', 'A', 2, 0.00, 'Standard SQL clause order.', 2, 1),
(21, 3, 'Which JOIN returns all rows from the left table even if there is no match?', 'INNER JOIN', 'RIGHT JOIN', 'LEFT JOIN', 'FULL JOIN', 'C', 1, 0.00, 'LEFT JOIN preserves all rows in the left table.', 4, 1);

-- SUBMISSIONS
INSERT INTO submissions (UserID, TestID, AttemptNumber, SubmittedAt, Percentage, IsPassed)
VALUES
(1,1,1,NOW(),80,1),
(2,1,1,NOW(),70,1),
(3,2,1,NOW(),50,0);

-- ANSWERS_LOG
INSERT INTO answers_log (SubID, QuestionID, SelectedOption, IsCorrect, MarksAwarded)
VALUES
(1,1,'A',1,1.0),
(1,2,'B',1,1.0),
(2,1,'C',0,0.0);
