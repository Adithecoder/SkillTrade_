//
//  test-server.js
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/29/25.
//


// test-server.js
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'skilltrade.db');
const db = new sqlite3.Database(dbPath);

console.log('🧪 Szerver adatbázis tesztelése...');

// 1. Táblák listázása
db.all("SELECT name FROM sqlite_master WHERE type='table'", (err, tables) => {
    if (err) {
        console.error('❌ Hiba:', err);
        return;
    }
    
    console.log('📋 Táblák:');
    tables.forEach(table => console.log('  -', table.name));
    
    // 2. Munkák listázása
    db.all("SELECT * FROM works", (err, works) => {
        if (err) {
            console.error('❌ Hiba a munkák lekérése során:', err);
            return;
        }
        
        console.log(`\n📊 Munkák (${works.length} db):`);
        works.forEach(work => {
            console.log(`  🆔 ${work.id}`);
            console.log(`  📝 ${work.title}`);
            console.log(`  👤 ${work.employerName}`);
            console.log(`  💰 ${work.wage} Ft`);
            console.log(`  📍 ${work.location}`);
            console.log(`  📊 ${work.statusText}`);
            console.log('  ---');
        });
        
        db.close();
    });
});