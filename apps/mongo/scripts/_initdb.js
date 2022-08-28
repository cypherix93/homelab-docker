use admin;

db.createUser({
    // user: 'USERNAME',
    // pwd: 'PASSWORD',
    roles: [
        {role: 'root', db: 'admin'}
    ]
});