require('dotenv').config(); // carrega as variáveis de ambiente do arquivo .env
const sql = require('mssql'); // carrega a biblioteca mssql

const config ={
    server: process.env.DB_SERVER,
    port: Number(process.env.DB_PORT),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,  
    options: {
        encrypt: true, 
        trustServerCertificate: true, 

    },  
};

const pool = sql.connect(config);
module.exports = {sql, pool};