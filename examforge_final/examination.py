from flask import Flask, render_template, request, redirect, url_for, session, jsonify, flash
import MySQLdb
from functools import wraps

app = Flask(__name__)
app.secret_key = 'examforge-secret-2026'

DB_CONFIG = dict(
    host='localhost',
    user='root',
    passwd='root',
    db='examforge',
    charset='utf8mb4'
)

def get_db():
    return MySQLdb.connect(**DB_CONFIG)

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

def role_required(*roles):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if session.get('role') not in roles:
                flash('Access denied.', 'danger')
                return redirect(url_for('dashboard'))
            return f(*args, **kwargs)
        return decorated
    return decorator

@app.route('/', methods=['GET', 'POST'])
@app.route('/login', methods=['GET', 'POST'])
def login():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))

    if request.method == 'POST':
        email = request.form.get('email', '').strip().lower()
        password = request.form.get('password', '')

        print("DEBUG:", email, password)

        if not email or not password:
            flash("Please enter email and password", "danger")
            return render_template('login.html')

        db = get_db()
        cur = db.cursor(MySQLdb.cursors.DictCursor)

        cur.execute("SELECT * FROM USERS WHERE Email=%s AND IsActive=1", (email,))
        user = cur.fetchone()
        db.close()

        # 🔥 IMPORTANT FIX (remove bcrypt dependency issue)
        if user and user['Password'] == password:
            session['user_id'] = user['UserID']
            session['name'] = user['Name']
            session['role'] = user['Role']
            return redirect(url_for('dashboard'))

        flash('Invalid credentials.', 'danger')

    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    role = session['role']
    uid = session['user_id']
    data = {}
    if role == 'student':
        cur.execute("""
            SELECT t.TestID, t.Title, t.Duration, t.TotalMarks,
                   t.StartTime, t.EndTime, t.PassMarks,
                   IFNULL(att.attempts, 0) AS attempts, t.MaxAttempts
            FROM TESTS t
            LEFT JOIN (
                SELECT TestID, COUNT(*) AS attempts
                FROM SUBMISSIONS WHERE UserID=%s GROUP BY TestID
            ) att ON att.TestID = t.TestID
            WHERE t.IsActive=1 AND t.StartTime <= NOW() AND t.EndTime >= NOW()
        """, (uid,))
        data['tests'] = cur.fetchall()
        cur.execute("""
            SELECT s.SubID, t.Title, s.TotalScore, s.MaxScore,
                   s.Percentage, s.IsPassed, s.SubmittedAt
            FROM SUBMISSIONS s JOIN TESTS t ON s.TestID=t.TestID
            WHERE s.UserID=%s AND s.IsGraded=1
            ORDER BY s.SubmittedAt DESC LIMIT 5
        """, (uid,))
        data['recent'] = cur.fetchall()
    elif role in ('instructor', 'ta', 'incharge', 'admin'):
        cur.execute("SELECT * FROM vw_test_details ORDER BY CreatedAt DESC LIMIT 10")
        data['tests'] = cur.fetchall()
        cur.execute("SELECT COUNT(*) AS cnt FROM QUESTIONS WHERE IsApproved=0")
        data['pending'] = cur.fetchone()['cnt']
        cur.execute("SELECT COUNT(*) AS cnt FROM USERS WHERE Role='student'")
        data['students'] = cur.fetchone()['cnt']
        cur.execute("SELECT COUNT(*) AS cnt FROM SUBMISSIONS WHERE IsGraded=1")
        data['graded'] = cur.fetchone()['cnt']
    db.close()
    return render_template('dashboard.html', data=data)

@app.route('/tests')
@login_required
@role_required('instructor', 'ta', 'incharge', 'admin')
def manage_tests():
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT * FROM vw_test_details ORDER BY StartTime DESC")
    tests = cur.fetchall()
    cur.execute("SELECT CourseID, Code, Title FROM COURSES ORDER BY Code")
    courses = cur.fetchall()
    db.close()
    return render_template('manage_tests.html', tests=tests, courses=courses)

@app.route('/tests/create', methods=['POST'])
@login_required
@role_required('instructor', 'incharge', 'admin')
def create_test():
    db = get_db()
    cur = db.cursor()
    cur.callproc('sp_create_test', [
        request.form['title'],
        request.form.get('course_id') or None,
        int(request.form['duration']),
        request.form['start_time'],
        request.form['end_time'],
        int(request.form['pass_marks']),
        int(request.form.get('shuffle', 0)),
        int(request.form.get('max_attempts', 1)),
        session['user_id'],
        0, ''
    ])
    cur.fetchall()
    db.commit()
    db.close()
    flash('Test created successfully.', 'success')
    return redirect(url_for('manage_tests'))

@app.route('/tests/<int:test_id>/toggle')
@login_required
@role_required('instructor', 'incharge', 'admin')
def toggle_test(test_id):
    db = get_db()
    cur = db.cursor()
    cur.execute("UPDATE TESTS SET IsActive = 1 - IsActive WHERE TestID=%s", (test_id,))
    db.commit()
    db.close()
    return redirect(url_for('manage_tests'))

@app.route('/tests/<int:test_id>/questions')
@login_required
@role_required('instructor', 'ta', 'incharge', 'admin')
def questions(test_id):
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT * FROM TESTS WHERE TestID=%s", (test_id,))
    test = cur.fetchone()
    cur.execute("""
        SELECT q.*, u.Name AS AddedByName
        FROM QUESTIONS q JOIN USERS u ON q.AddedBy = u.UserID
        WHERE q.TestID=%s ORDER BY q.CreatedAt
    """, (test_id,))
    qs = cur.fetchall()
    db.close()
    return render_template('questions.html', test=test, questions=qs)

@app.route('/questions/add', methods=['POST'])
@login_required
@role_required('instructor', 'ta', 'incharge', 'admin')
def add_question():
    db = get_db()
    cur = db.cursor()
    cur.callproc('sp_upsert_question', [
        0,
        int(request.form['test_id']),
        request.form['question_text'],
        request.form['option_a'],
        request.form['option_b'],
        request.form['option_c'],
        request.form['option_d'],
        request.form['correct_option'],
        int(request.form.get('marks', 1)),
        float(request.form.get('negative_marks', 0)),
        request.form.get('explanation', ''),
        session['user_id'],
        0, ''
    ])
    db.commit()
    db.close()
    flash('Question added. Awaiting approval.', 'success')
    return redirect(url_for('questions', test_id=request.form['test_id']))

@app.route('/questions/<int:qid>/edit', methods=['GET', 'POST'])
@login_required
@role_required('instructor', 'ta', 'incharge', 'admin')
def edit_question(qid):
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    if request.method == 'POST':
        cur2 = db.cursor()
        cur2.callproc('sp_upsert_question', [
            qid,
            int(request.form['test_id']),
            request.form['question_text'],
            request.form['option_a'],
            request.form['option_b'],
            request.form['option_c'],
            request.form['option_d'],
            request.form['correct_option'],
            int(request.form.get('marks', 1)),
            float(request.form.get('negative_marks', 0)),
            request.form.get('explanation', ''),
            session['user_id'],
            0, ''
        ])
        db.commit()
        db.close()
        flash('Question updated. Re-approval required.', 'info')
        return redirect(url_for('questions', test_id=request.form['test_id']))
    cur.execute("SELECT * FROM QUESTIONS WHERE QuestionID=%s", (qid,))
    q = cur.fetchone()
    db.close()
    return render_template('edit_question.html', q=q)

@app.route('/questions/<int:qid>/approve')
@login_required
@role_required('incharge', 'admin')
def approve_question(qid):
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT TestID FROM QUESTIONS WHERE QuestionID=%s", (qid,))
    row = cur.fetchone()
    cur2 = db.cursor()
    cur2.callproc('sp_approve_question', [qid, session['user_id'], ''])
    db.commit()
    db.close()
    flash('Question approved.', 'success')
    return redirect(url_for('questions', test_id=row['TestID']))

@app.route('/questions/<int:qid>/delete')
@login_required
@role_required('incharge', 'admin')
def delete_question(qid):
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT TestID FROM QUESTIONS WHERE QuestionID=%s", (qid,))
    row = cur.fetchone()
    cur.execute("DELETE FROM QUESTIONS WHERE QuestionID=%s", (qid,))
    db.commit()
    db.close()
    flash('Question deleted.', 'warning')
    return redirect(url_for('questions', test_id=row['TestID']))

@app.route('/exam/<int:test_id>/start')
@login_required
@role_required('student')
def start_exam(test_id):
    db = get_db()
    cur = db.cursor()
    cur.callproc('sp_start_submission', [session['user_id'], test_id, 0, ''])
    rows = cur.fetchall()
    db.commit()
    sub_id = rows[0][0] if rows else 0
    message = rows[0][1] if rows else 'Error'
    db.close()
    if sub_id == 0:
        flash(message, 'danger')
        return redirect(url_for('dashboard'))
    return redirect(url_for('take_exam', sub_id=sub_id))

@app.route('/exam/<int:sub_id>')
@login_required
@role_required('student')
def take_exam(sub_id):
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("""
        SELECT s.*, t.Title, t.Duration, t.Shuffle
        FROM SUBMISSIONS s JOIN TESTS t ON s.TestID=t.TestID
        WHERE s.SubID=%s AND s.UserID=%s AND s.IsGraded=0
    """, (sub_id, session['user_id']))
    sub = cur.fetchone()
    if not sub:
        db.close()
        flash('Invalid exam session.', 'danger')
        return redirect(url_for('dashboard'))
    order = "RAND()" if sub['Shuffle'] else "QuestionID"
    cur.execute("""
        SELECT QuestionID, QuestionText, OptionA, OptionB, OptionC, OptionD
        FROM QUESTIONS WHERE TestID=%s AND IsApproved=1
        ORDER BY {}
    """.format(order), (sub['TestID'],))
    questions = cur.fetchall()
    cur.execute("SELECT QuestionID, ChosenOption FROM ANSWERS_LOG WHERE SubID=%s", (sub_id,))
    saved = {r['QuestionID']: r['ChosenOption'] for r in cur.fetchall()}
    db.close()
    return render_template('take_test.html', sub=sub, questions=questions, saved=saved)

@app.route('/exam/save-answer', methods=['POST'])
@login_required
def save_answer():
    data = request.get_json()
    db = get_db()
    cur = db.cursor()
    cur.callproc('sp_save_answer', [data['sub_id'], data['question_id'], data['chosen']])
    db.commit()
    db.close()
    return jsonify(status='ok')

@app.route('/exam/<int:sub_id>/submit', methods=['POST'])
@login_required
@role_required('student')
def submit_exam(sub_id):
    time_taken = int(request.form.get('time_taken', 0))
    db = get_db()
    cur = db.cursor()
    cur.callproc('sp_finalise_submission', [sub_id, time_taken, 0, 0, 0, ''])
    db.commit()
    db.close()
    return redirect(url_for('result', sub_id=sub_id))

@app.route('/result/<int:sub_id>')
@login_required
def result(sub_id):
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT * FROM vw_submission_summary WHERE SubID=%s", (sub_id,))
    sub = cur.fetchone()
    if not sub:
        db.close()
        flash('Result not found.', 'danger')
        return redirect(url_for('dashboard'))
    if session['role'] == 'student' and sub['UserID'] != session['user_id']:
        db.close()
        flash('Access denied.', 'danger')
        return redirect(url_for('dashboard'))
    cur.execute("""
        SELECT q.QuestionText, q.OptionA, q.OptionB, q.OptionC, q.OptionD,
               q.CorrectOption, q.Explanation, q.Marks,
               al.ChosenOption, al.IsCorrect, al.MarksAwarded
        FROM ANSWERS_LOG al JOIN QUESTIONS q ON al.QuestionID = q.QuestionID
        WHERE al.SubID=%s ORDER BY al.LogID
    """, (sub_id,))
    answers = cur.fetchall()
    db.close()
    return render_template('result.html', sub=sub, answers=answers)

@app.route('/leaderboard/<int:test_id>')
@login_required
def leaderboard(test_id):
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT * FROM vw_test_details WHERE TestID=%s", (test_id,))
    test = cur.fetchone()
    cur.execute("SELECT * FROM vw_leaderboard WHERE TestID=%s ORDER BY Rank_Position", (test_id,))
    board = cur.fetchall()
    db.close()
    return render_template('leaderboard.html', test=test, board=board)

@app.route('/report/performance')
@login_required
@role_required('instructor', 'incharge', 'admin')
def report_performance():
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT * FROM vw_student_performance ORDER BY AvgPercentage DESC")
    perf = cur.fetchall()
    cur.execute("SELECT * FROM vw_contributor_stats ORDER BY TotalAdded DESC")
    contrib = cur.fetchall()
    db.close()
    return render_template('report_performance.html', performance=perf, contributors=contrib)

@app.route('/admin/audit')
@login_required
@role_required('admin')
def audit_log():
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("""
        SELECT a.*, u.Name AS UserName
        FROM AUDIT_LOG a LEFT JOIN USERS u ON a.UserID = u.UserID
        ORDER BY a.CreatedAt DESC LIMIT 200
    """)
    logs = cur.fetchall()
    db.close()
    return render_template('audit_log.html', logs=logs)

@app.route('/admin/users')
@login_required
@role_required('admin')
def admin_users():
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute("SELECT * FROM USERS ORDER BY Role, Name")
    users = cur.fetchall()
    db.close()
    return render_template('admin_users.html', users=users)

@app.route('/admin/users/<int:uid>/toggle')
@login_required
@role_required('admin')
def toggle_user(uid):
    db = get_db()
    cur = db.cursor()
    cur.execute("UPDATE USERS SET IsActive = 1 - IsActive WHERE UserID=%s", (uid,))
    db.commit()
    db.close()
    return redirect(url_for('admin_users'))

if __name__ == '__main__':
    app.run(debug=True, port=5000)
