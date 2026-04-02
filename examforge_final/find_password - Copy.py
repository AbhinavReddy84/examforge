import MySQLdb

passwords = ['Root@123', 'root', 'admin', 'mysql', 'Root@1234', 'password', 'admin123', '']

print("Testing MySQL passwords...\n")
for pwd in passwords:
    try:
        conn = MySQLdb.connect(host='localhost', user='root', passwd=pwd, db='mysql')
        conn.close()
        print(f"SUCCESS! Your MySQL password is: '{pwd}'")
        print(f"\nUpdate examination.py line 12 to:")
        print(f"    passwd='{pwd}',")
        break
    except Exception as e:
        print(f"FAILED '{pwd}': {str(e)[:50]}")
else:
    print("\nNone worked. Please open MySQL Workbench or MySQL Command Line")
    print("and reset your password with:")
    print("  ALTER USER 'root'@'localhost' IDENTIFIED BY 'admin123';")
    print("  FLUSH PRIVILEGES;")
    print("Then update examination.py with passwd='admin123'")
