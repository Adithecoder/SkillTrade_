//
//  migrate-works.js
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/29/25.
//


// migrate-works.js
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Új SQLite adatbázis (szerver oldali)
const newDBPath = path.join(__dirname, 'skilltrade.db');
const newDB = new sqlite3.Database(newDBPath);

// Régi adatbázisod (ha más helyen van, add meg a path-ot)
const oldDBPath = path.join(__dirname, '..', '..', 'SkillTradeApp.sqlite'); // Módosítsd a path-ot!
const oldDB = new sqlite3.Database(oldDBPath);

async function migrateWorks() {
    console.log('🚀 Munkák migrálása...');
    
    try {
        // 1. Először ellenőrizzük, hogy van-e works tábla a régi adatbázisban
        oldDB.all("SELECT name FROM sqlite_master WHERE type='table' AND name='works'", (err, tables) => {
            if (err) {
                console.error('❌ Hiba a tábla ellenőrzése során:', err);
                return;
            }
            
            if (tables.length === 0) {
                console.log('ℹ️  Nincs works tábla a régi adatbázisban');
                createSampleWorks();
                return;
            }
            
            // 2. Munkák lekérése a régi adatbázisból
            oldDB.all("SELECT * FROM works", (err, oldWorks) => {
                if (err) {
                    console.error('❌ Hiba a munkák lekérése során:', err);
                    createSampleWorks();
                    return;
                }
                
                console.log(`📥 ${oldWorks.length} munka található a régi adatbázisban`);
                
                if (oldWorks.length === 0) {
                    createSampleWorks();
                    return;
                }
                
                // 3. Munkák migrálása az új adatbázisba
                let migratedCount = 0;
                oldWorks.forEach(work => {
                    const stmt = newDB.prepare(`
                        INSERT OR REPLACE INTO works (
                            id, title, employerName, employerID, employeeID,
                            wage, paymentType, statusText, startTime, endTime,
                            duration, progress, location, skills, category, description
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `);
                    
                    stmt.run(
                        work.id,
                        work.title,
                        work.employerName,
                        work.employerID,
                        work.employeeID,
                        work.wage,
                        work.paymentType,
                        work.statusText,
                        work.startTime,
                        work.endTime,
                        work.duration,
                        work.progress,
                        work.location || '',
                        work.skills ? JSON.stringify(work.skills) : '[]',
                        work.category || '',
                        work.description || '',
                        function(err) {
                            if (err) {
                                console.error('❌ Hiba a munka beszúrása során:', err);
                            } else {
                                migratedCount++;
                                console.log(`✅ Migrálva: ${work.title}`);
                            }
                            
                            if (migratedCount === oldWorks.length) {
                                console.log(`🎉 ${migratedCount} munka sikeresen migrálva!`);
                                stmt.finalize();
                                checkCurrentWorks();
                            }
                        }
                    );
                });
            });
        });
        
    } catch (error) {
        console.error('❌ Migrációs hiba:', error);
        createSampleWorks();
    }
}

function createSampleWorks() {
    console.log('📝 Minta munkák létrehozása...');
    
    const sampleWorks = [
        {
            id: '1',
            title: 'Webfejlesztő keresése',
            employerName: 'Kovács János',
            employerID: 'user-1',
            wage: 15000,
            paymentType: 'Bankkártya',
            statusText: 'Publikálva',
            location: 'Budapest',
            skills: JSON.stringify(['HTML', 'CSS', 'JavaScript']),
            description: 'Egy egyszerű weboldal fejlesztése'
        },
        {
            id: '2', 
            title: 'Kertész segéd',
            employerName: 'Nagy Éva',
            employerID: 'user-2',
            wage: 8000,
            paymentType: 'Készpénz',
            statusText: 'Publikálva',
            location: 'Debrecen',
            skills: JSON.stringify(['kertészkedés', 'növényápolás']),
            description: 'Kerti munkák elvégzése'
        },
        {
            id: '3',
            title: 'Nyelvezó tanár',
            employerName: 'Szabó Péter',
            employerID: 'user-3', 
            wage: 12000,
            paymentType: 'Átutalás',
            statusText: 'Publikálva',
            location: 'Szeged',
            skills: JSON.stringify(['angol', 'tanítás']),
            description: 'Angol nyelvtanítás kezdőknek'
        }
    ];
    
    let createdCount = 0;
    sampleWorks.forEach(work => {
        const stmt = newDB.prepare(`
            INSERT OR REPLACE INTO works (
                id, title, employerName, employerID, employeeID,
                wage, paymentType, statusText, startTime, endTime,
                duration, progress, location, skills, category, description
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        
        stmt.run(
            work.id,
            work.title,
            work.employerName,
            work.employerID,
            null, // employeeID
            work.wage,
            work.paymentType,
            work.statusText,
            null, // startTime
            null, // endTime
            null, // duration
            0.0,  // progress
            work.location,
            work.skills,
            '',   // category
            work.description,
            function(err) {
                if (err) {
                    console.error('❌ Hiba a minta munka beszúrása során:', err);
                } else {
                    createdCount++;
                    console.log(`✅ Létrehozva: ${work.title}`);
                }
                
                if (createdCount === sampleWorks.length) {
                    console.log(`🎉 ${createdCount} minta munka sikeresen létrehozva!`);
                    stmt.finalize();
                    checkCurrentWorks();
                }
            }
        );
    });
}

function checkCurrentWorks() {
    console.log('\n📊 Jelenlegi munkák az adatbázisban:');
    
    newDB.all("SELECT id, title, employerName, wage, statusText FROM works", (err, works) => {
        if (err) {
            console.error('❌ Hiba a munkák lekérése során:', err);
            return;
        }
        
        console.log(`Összesen ${works.length} munka:`);
        works.forEach(work => {
            console.log(`  - ${work.title} (${work.employerName}): ${work.wage} Ft - ${work.statusText}`);
        });
        
        // Adatbázisok bezárása
        oldDB.close();
        newDB.close();
        console.log('\n✅ Migráció befejezve!');
    });
}

// Migráció indítása
migrateWorks();