CREATE USER IF NOT EXISTS '__MySqlServiceAccountUsername__' IDENTIFIED BY '__MySqlServiceAccountPassword__';
GRANT ALL PRIVILEGES ON * .__databaseName__ TO '__MySqlServiceAccountUsername__';
FLUSH PRIVILEGES;
