//
//  server.js
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/26/25.
//

const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const path = require('path');

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // ← Növeld meg 50MB-ra
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// SQLite adatbázis
const DB_PATH = path.join(__dirname, 'skilltrade.db');
const db = new sqlite3.Database(DB_PATH);

// Adatbázis inicializálás
db.serialize(() => {
    // Users tábla létrehozása
    db.run(`CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        age INTEGER NOT NULL,
        bio TEXT DEFAULT '',
        rating REAL DEFAULT 0.0,
        location_city TEXT DEFAULT '',
        location_country TEXT DEFAULT '',
        skills TEXT DEFAULT '[]',
        pricing TEXT DEFAULT '[]',
        isVerified BOOLEAN DEFAULT 0,
        servicesOffered TEXT DEFAULT '',
        servicesAdvertised TEXT DEFAULT '',
        userRole TEXT DEFAULT 'client',
        status TEXT DEFAULT 'active',
        phoneNumber TEXT,
        address TEXT,
        profileImageUrl TEXT,
        profileImageData TEXT,
        photos TEXT DEFAULT '[]',
        xp INTEGER DEFAULT 0,
        permanentQRCodeUrl TEXT,
        typeofservice TEXT,
        price REAL DEFAULT 0.0,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    console.log('✅ SQLite adatbázis inicializálva');
});

// JWT konfiguráció
const JWT_SECRET = process.env.JWT_SECRET || 'skilltrade-sqlite-secret-123';

// Helper függvények
const userToObject = (row) => {
    return {
        _id: row.id.toString(),
        name: row.name,
        email: row.email,
        username: row.username,
        age: row.age,
        bio: row.bio || '',
        rating: row.rating || 0.0,
        location: {
            city: row.location_city || '',
            country: row.location_country || ''
        },
        skills: JSON.parse(row.skills || '[]'),
        pricing: JSON.parse(row.pricing || '[]'),
        isVerified: Boolean(row.isVerified),
        servicesOffered: row.servicesOffered || '',
        servicesAdvertised: row.servicesAdvertised || '',
        userRole: row.userRole || 'client',
        status: row.status || 'active',
        phoneNumber: row.phoneNumber,
        address: row.address ? JSON.parse(row.address) : null,
        profileImageUrl: row.profileImageUrl,
        profileImageData: row.profileImageData,
        photos: JSON.parse(row.photos || '[]'),
        xp: row.xp || 0,
        permanentQRCodeUrl: row.permanentQRCodeUrl,
        typeofservice: row.typeofservice,
        price: row.price || 0.0,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt
    };
};

// Routes

// REGISZTRÁCIÓ
app.post('/api/auth/register', async (req, res) => {
    try {
        const { name, email, username, password, age } = req.body;

        console.log('Register request:', { name, email, username, age });

        // Validáció
        if (!name || !email || !username || !password || !age) {
            return res.status(400).json({
                message: 'Minden mező kitöltése kötelező.'
            });
        }

        if (password.length < 6) {
            return res.status(400).json({
                message: 'A jelszónak legalább 6 karakter hosszúnak kell lennie.'
            });
        }

        if (age < 16) {
            return res.status(400).json({
                message: 'A regisztrációhoz legalább 16 évesnek kell lenned.'
            });
        }

        // Ellenőrizzük, hogy létezik-e már ilyen email vagy username
        db.get(
            'SELECT * FROM users WHERE email = ? OR username = ?',
            [email, username],
            async (err, existingUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (existingUser) {
                    if (existingUser.email === email) {
                        return res.status(400).json({
                            message: 'Ez az email cím már regisztrálva van.'
                        });
                    }
                    if (existingUser.username === username) {
                        return res.status(400).json({
                            message: 'Ez a felhasználónév már foglalt.'
                        });
                    }
                }

                // Jelszó hash-elés
                const hashedPassword = await bcrypt.hash(password, 12);

                // Új user beszúrása
                const stmt = db.prepare(`
                    INSERT INTO users (
                        name, email, username, password, age,
                        location_city, location_country, skills, pricing, photos
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                `);

                stmt.run(
                    name,
                    email,
                    username,
                    hashedPassword,
                    age,
                    '', // location_city
                    '', // location_country
                    '[]', // skills
                    '[]', // pricing
                    '[]', // photos
                    function(err) {
                        if (err) {
                            console.error('Insert error:', err);
                            return res.status(500).json({
                                message: 'Hiba a felhasználó létrehozásakor'
                            });
                        }

                        // Új user lekérése
                        db.get(
                            'SELECT * FROM users WHERE id = ?',
                            [this.lastID],
                            (err, newUser) => {
                                if (err) {
                                    console.error('Select error:', err);
                                    return res.status(500).json({
                                        message: 'Hiba a felhasználó lekérésekor'
                                    });
                                }

                                // Token generálás
                                const token = jwt.sign(
                                    { id: newUser.id },
                                    JWT_SECRET,
                                    { expiresIn: '30d' }
                                );

                                const userResponse = userToObject(newUser);

                                res.status(201).json({
                                    token,
                                    user: userResponse
                                });

                                console.log('✅ Sikeres regisztráció:', userResponse.username);
                            }
                        );
                    }
                );

                stmt.finalize();
            }
        );

    } catch (error) {
        console.error('Register error:', error);
        res.status(500).json({
            message: 'Szerver hiba a regisztráció során.',
            error: error.message
        });
    }
});

// BEJELENTKEZÉS
app.post('/api/auth/login', async (req, res) => {
    try {
        const { identifier, password } = req.body;

        console.log('🔐 Login request received:', {
            identifier: identifier,
            passwordLength: password ? password.length : 0,
            timestamp: new Date().toISOString()
        });

        // Validáció
        if (!identifier || !password) {
            return res.status(400).json({
                message: 'Email/felhasználónév és jelszó megadása kötelező.'
            });
        }

        // User keresése email vagy username alapján
        db.get(
            'SELECT * FROM users WHERE email = ? OR username = ?',
            [identifier, identifier],
            async (err, user) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (!user) {
                    return res.status(401).json({
                        message: 'Hibás email/felhasználónév vagy jelszó.'
                    });
                }

                // Jelszó ellenőrzés
                const isPasswordValid = await bcrypt.compare(password, user.password);
                
                if (!isPasswordValid) {
                    return res.status(401).json({
                        message: 'Hibás email/felhasználónév vagy jelszó.'
                    });
                }

                // Token generálás
                const token = jwt.sign(
                    { id: user.id },
                    JWT_SECRET,
                    { expiresIn: '30d' }
                );

                const userResponse = userToObject(user);

                res.status(200).json({
                    token,
                    user: userResponse
                });

                console.log('✅ Sikeres bejelentkezés:', userResponse.username);
            }
        );

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            message: 'Szerver hiba a bejelentkezés során.',
            error: error.message
        });
    }
});

// USER ADATOK LEKÉRÉSE (token alapján)
app.get('/api/auth/me', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({
                message: 'Hozzáférés megtagadva. Nincs token.'
            });
        }

        // Token ellenőrzés
        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({
                    message: 'Érvénytelen token.'
                });
            }

            // User keresése ID alapján
            db.get(
                'SELECT * FROM users WHERE id = ?',
                [decoded.id],
                (err, user) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({
                            message: 'Adatbázis hiba'
                        });
                    }

                    if (!user) {
                        return res.status(404).json({
                            message: 'Felhasználó nem található.'
                        });
                    }

                    const userResponse = userToObject(user);

                    res.status(200).json({
                        user: userResponse
                    });
                }
            );
        });

    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({
            message: 'Szerver hiba az adatok lekérése során.'
        });
    }
});

// server.js - Verified státusz módosítása
// server.js - ADD THIS ROUTE

// USER ADATOK FRISSÍTÉSE
app.put('/api/auth/user/:userId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;
        const updates = req.body;

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Csak a saját profilodat módosíthatod, kivéve ha admin vagy
            if (decoded.id !== userId) {
                db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                    if (err || adminUser.userRole !== 'admin') {
                        return res.status(403).json({ message: 'Nincs jogosultság' });
                    }

                    updateUser();
                });
            } else {
                updateUser();
            }
        });

        function updateUser() {
            const allowedFields = ['name', 'email', 'username', 'bio', 'age', 'location_city', 'location_country', 'phoneNumber'];
            const setClause = [];
            const values = [];

            Object.keys(updates).forEach(key => {
                if (allowedFields.includes(key)) {
                    if (key.startsWith('location_')) {
                        setClause.push(`${key} = ?`);
                        values.push(updates[key]);
                    } else {
                        setClause.push(`${key} = ?`);
                        values.push(updates[key]);
                    }
                }
            });

            if (setClause.length === 0) {
                return res.status(400).json({ message: 'Nincs érvényes frissítendő mező' });
            }

            setClause.push('updatedAt = CURRENT_TIMESTAMP');
            values.push(userId);

            const query = `UPDATE users SET ${setClause.join(', ')} WHERE id = ?`;

            db.run(query, values, function(err) {
                if (err) {
                    console.error('Update user error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                // Visszaadjuk a frissített usert
                db.get('SELECT * FROM users WHERE id = ?', [userId], (err, user) => {
                    if (err) {
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    const userResponse = userToObject(user);
                    res.status(200).json({
                        message: 'Profil sikeresen frissítve',
                        user: userResponse
                    });
                });
            });
        }

    } catch (error) {
        console.error('Update user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


// USER HITELESÍTÉSI STÁTUSZ MÓDOSÍTÁSA (Admin funkció)
app.put('/api/auth/verify-user/:userId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;
        const { isVerified } = req.body;

        console.log('🔐 Verify user request:', { userId, isVerified });

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        // Token ellenőrzés
        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy admin-e
            db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!adminUser || adminUser.userRole !== 'admin') {
                    return res.status(403).json({ message: 'Csak admin módosíthatja a hitelesítési státuszt' });
                }

                // Frissítjük a user hitelesítési státuszát
                db.run(
                    'UPDATE users SET isVerified = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                    [isVerified ? 1 : 0, userId],
                    function(err) {
                        if (err) {
                            console.error('Update verification error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        if (this.changes === 0) {
                            return res.status(404).json({ message: 'Felhasználó nem található' });
                        }

                        console.log('✅ User verification updated:', { userId, isVerified });
                        
                        res.status(200).json({
                            message: `Felhasználó hitelesítési státusza ${isVerified ? 'aktiválva' : 'deaktiválva'}`,
                            userId: userId,
                            isVerified: isVerified
                        });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Verify user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// USER HITELESÍTÉS FRISSÍTÉSE EMAIL ALAPJÁN
app.put('/api/auth/verify-by-email', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { email, isVerified } = req.body;

        console.log('🔐 Verify user by email:', { email, isVerified });

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Frissítjük a user hitelesítési státuszát email alapján
            db.run(
                'UPDATE users SET isVerified = ?, updatedAt = CURRENT_TIMESTAMP WHERE email = ?',
                [isVerified ? 1 : 0, email],
                function(err) {
                    if (err) {
                        console.error('Update verification error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    console.log('✅ Database changes:', this.changes);

                    if (this.changes === 0) {
                        return res.status(404).json({
                            message: 'Felhasználó nem található ezzel az email címmel',
                            email: email
                        });
                    }

                    console.log('✅ User verification updated by email:', { email, isVerified });
                    
                    res.status(200).json({
                        message: `Felhasználó hitelesítési státusza ${isVerified ? 'aktiválva' : 'deaktiválva'}`,
                        email: email,
                        isVerified: isVerified
                    });
                }
            );
        });

    } catch (error) {
        console.error('Verify user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});
// HEALTH CHECK
app.get('/api/health', (req, res) => {
    res.json({
        status: 'OK',
        message: 'SkillTrade API működik',
        database: 'SQLite'
    });
});

// JAVÍTOTT users endpoint - include isVerified field
app.get('/api/auth/users', (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({
            message: 'Hozzáférés megtagadva. Nincs token.'
        });
    }

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(401).json({
                message: 'Érvénytelen token.'
            });
        }

        // Ellenőrizzük, hogy admin-e a felhasználó
        db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, user) => {
            if (err || !user || user.userRole !== 'admin') {
                return res.status(403).json({
                    message: 'Nincs jogosultság az admin panelhez.'
                });
            }

            // MÓDOSÍTOTT: include isVerified field
            db.all('SELECT id, name, email, username, age, isVerified, createdAt FROM users ORDER BY createdAt DESC', (err, rows) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }
                
                res.status(200).json({
                    users: rows,
                    count: rows.length
                });
            });
        });
    });
});

// server.js - JAVÍTOTT PROFILKÉP ENDPOINT
app.put('/api/auth/profile-image', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({
                message: 'Hozzáférés megtagadva. Nincs token.'
            });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({
                    message: 'Érvénytelen token.'
                });
            }

            const { profileImageData } = req.body;
            
            if (!profileImageData) {
                return res.status(400).json({
                    message: 'Hiányzó kép adatok.'
                });
            }

            console.log('📸 Profilkép frissítése user ID:', decoded.id);
            console.log('📏 Kép adat mérete:', profileImageData.length, 'karakter');
            
            // Képtömörítés - csak az első 100 karaktert logoljuk
            console.log('📸 Kép adat (első 100 karakter):', profileImageData.substring(0, 100) + '...');

            db.run(
                'UPDATE users SET profileImageData = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                [profileImageData, decoded.id],
                function(err) {
                    if (err) {
                        console.error('❌ Profile image update error:', err);
                        return res.status(500).json({
                            message: 'Hiba a profilkép frissítésekor'
                        });
                    }

                    console.log('✅ Profilkép frissítve, changes:', this.changes);
                    
                    res.status(200).json({
                        message: 'Profilkép sikeresen frissítve',
                        userId: decoded.id
                    });
                }
            );
        });

    } catch (error) {
        console.error('❌ Profile image update error:', error);
        res.status(500).json({
            message: 'Szerver hiba a profilkép frissítése során.'
        });
    }
});

// PROFILKÉP LEKÉRÉSE
// server.js - Ellenőrizd, hogy ez a route megfelelően működik
app.get('/api/auth/profile-image/:userId', (req, res) => {
    try {
        const { userId } = req.params;

        db.get(
            'SELECT profileImageData FROM users WHERE id = ?',
            [userId],
            (err, row) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (!row) {
                    return res.status(404).json({
                        message: 'Felhasználó nem található.'
                    });
                }

                res.status(200).json({
                    profileImageData: row.profileImageData
                });
            }
        );

    } catch (error) {
        console.error('Profile image fetch error:', error);
        res.status(500).json({
            message: 'Szerver hiba a profilkép lekérése során.'
        });
    }
});

// server.js - Add these routes

// MUNKÁRA JELENTKEZÉS
app.post('/api/works/apply', (req, res) => {
    try {
        const {
            workId,
            applicantId,
            applicantName,
            serviceTitle,
            employerId,
            applicationDate
        } = req.body;

        console.log('\n📝 ÚJ JELENTKEZÉS:');
        console.log('  - Munka ID:', workId);
        console.log('  - Jelentkező ID:', applicantId);
        console.log('  - Jelentkező neve:', applicantName);
        console.log('  - Szolgáltatás:', serviceTitle);
        console.log('  - Munkáltató ID:', employerId);

        // Validáció
        if (!workId || !applicantId || !applicantName || !employerId) {
            return res.status(400).json({
                message: 'Hiányzó kötelező adatok.'
            });
        }

        // Ellenőrizzük, hogy létezik-e a munka
        db.get('SELECT id FROM works WHERE id = ?', [workId], (err, work) => {
            if (err) {
                console.error('❌ Adatbázis hiba:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            if (!work) {
                return res.status(404).json({
                    message: 'Munka nem található.'
                });
            }

            // Ellenőrizzük, hogy a jelentkező már jelentkezett-e
            db.get(
                'SELECT id FROM work_applications WHERE workId = ? AND applicantId = ?',
                [workId, applicantId],
                (err, existingApplication) => {
                    if (err) {
                        console.error('❌ Adatbázis hiba:', err);
                        return res.status(500).json({
                            message: 'Adatbázis hiba'
                        });
                    }

                    if (existingApplication) {
                        return res.status(400).json({
                            message: 'Már jelentkeztél erre a munkára.'
                        });
                    }

                    // Új jelentkezés beszúrása
                    const applicationId = uuidv4();
                    const stmt = db.prepare(`
                        INSERT INTO work_applications (
                            id, workId, applicantId, applicantName, 
                            serviceTitle, employerId, applicationDate, status
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    `);

                    stmt.run(
                        applicationId,
                        workId,
                        applicantId,
                        applicantName,
                        serviceTitle,
                        employerId,
                        applicationDate || new Date().toISOString(),
                        'pending',
                        function(err) {
                            if (err) {
                                console.error('❌ Hiba a jelentkezés beszúrása során:', err);
                                return res.status(500).json({
                                    message: 'Hiba a jelentkezés során'
                                });
                            }

                            console.log('✅ JELENTKEZÉS SIKERESEN ROGZÍTVE!');
                            
                            res.status(200).json({
                                message: 'Sikeresen jelentkeztél a munkára!',
                                applicationId: applicationId
                            });
                        }
                    );

                    stmt.finalize();
                }
            );
        });

    } catch (error) {
        console.error('❌ Apply for work error:', error);
        res.status(500).json({
            message: 'Szerver hiba a jelentkezés során.',
            error: error.message
        });
    }
});

// JELENTKEZÉS ÁLLAPOTÁNAK LEKÉRÉSE
app.get('/api/works/:workId/applications/:applicantId', (req, res) => {
    try {
        const { workId, applicantId } = req.params;

        db.get(
            'SELECT * FROM work_applications WHERE workId = ? AND applicantId = ?',
            [workId, applicantId],
            (err, application) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (application) {
                    res.status(200).json({
                        hasApplied: true,
                        applicationDate: application.applicationDate,
                        status: application.status
                    });
                } else {
                    res.status(200).json({
                        hasApplied: false,
                        applicationDate: null
                    });
                }
            }
        );

    } catch (error) {
        console.error('Check application error:', error);
        res.status(500).json({
            message: 'Szerver hiba'
        });
    }
});

// MUNKA JELENTKEZÉSEINEK LEKÉRÉSE
app.get('/api/works/:workId/applications', (req, res) => {
    try {
        const { workId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                // Csak a munkáltató érheti el a jelentkezéseket
                if (work.employerID !== decoded.id) {
                    return res.status(403).json({ message: 'Nincs jogosultság a jelentkezések megtekintéséhez' });
                }

                // Jelentkezések lekérése
                db.all(
                    `SELECT * FROM work_applications 
                     WHERE workId = ? 
                     ORDER BY applicationDate DESC`,
                    [workId],
                    (err, applications) => {
                        if (err) {
                            console.error('Database error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        res.status(200).json({
                            applications: applications,
                            count: applications.length
                        });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Get work applications error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

app.put('/api/works/applications/:applicationId/status', (req, res) => {
    try {
        const { applicationId } = req.params;
        const { status } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Először lekérjük a jelentkezést, hogy megtudjuk a munkát
            db.get(
                'SELECT wa.*, w.employerID FROM work_applications wa JOIN works w ON wa.workId = w.id WHERE wa.id = ?',
                [applicationId],
                (err, application) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!application) {
                        return res.status(404).json({ message: 'Jelentkezés nem található' });
                    }

                    // Csak a munkáltató módosíthatja a státuszt
                    if (application.employerID !== decoded.id) {
                        return res.status(403).json({ message: 'Nincs jogosultság a jelentkezés módosításához' });
                    }

                    // Frissítjük a státuszt
                    db.run(
                        'UPDATE work_applications SET status = ? WHERE id = ?',
                        [status, applicationId],
                        function(err) {
                            if (err) {
                                console.error('Update application status error:', err);
                                return res.status(500).json({ message: 'Hiba a státusz frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Jelentkezés státusza sikeresen frissítve',
                                applicationId: applicationId,
                                status: status
                            });

                            console.log('✅ Jelentkezés státusz frissítve:', { applicationId, status });
                        }
                    );
                }
            );
        });

    } catch (error) {
        console.error('Update application status error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.put('/api/works/:workId/employee', (req, res) => {
    try {
        const { workId } = req.params;
        const { employeeID, statusText } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== decoded.id) {
                    return res.status(403).json({ message: 'Nincs jogosultság a munka módosításához' });
                }

                // Ellenőrizzük, hogy az employeeID létező user-e
                db.get('SELECT id FROM users WHERE id = ?', [employeeID], (err, user) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!user) {
                        return res.status(404).json({ message: 'Munkavállaló nem található' });
                    }

                    // Frissítjük a munkát
                    db.run(
                        'UPDATE works SET employeeID = ?, statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [employeeID, statusText, workId],
                        function(err) {
                            if (err) {
                                console.error('Update work employee error:', err);
                                return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Munka sikeresen frissítve',
                                workId: workId,
                                employeeID: employeeID,
                                statusText: statusText
                            });

                            console.log('✅ Munka frissítve:', { workId, employeeID, statusText });
                        }
                    );
                });
            });
        });

    } catch (error) {
        console.error('Update work employee error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.delete('/api/works/:workId', (req, res) => {
    try {
        const { workId } = req.params;
        const { employerID } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== employerID) {
                    return res.status(403).json({ message: 'Nincs jogosultság a munka törléséhez' });
                }

                // Először töröljük a kapcsolódó jelentkezéseket
                db.run('DELETE FROM work_applications WHERE workId = ?', [workId], (err) => {
                    if (err) {
                        console.error('Delete applications error:', err);
                        return res.status(500).json({ message: 'Hiba a jelentkezések törlésekor' });
                    }

                    // Majd töröljük a munkát
                    db.run('DELETE FROM works WHERE id = ?', [workId], function(err) {
                        if (err) {
                            console.error('Delete work error:', err);
                            return res.status(500).json({ message: 'Hiba a munka törlésekor' });
                        }

                        res.status(200).json({
                            message: 'Munka sikeresen törölve',
                            workId: workId
                        });

                        console.log('✅ Munka törölve:', workId);
                    });
                });
            });
        });

    } catch (error) {
        console.error('Delete work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// WORK_APPLICATIONS tábla létrehozása
db.run(`CREATE TABLE IF NOT EXISTS work_applications (
    id TEXT PRIMARY KEY,
    workId TEXT NOT NULL,
    applicantId TEXT NOT NULL,
    applicantName TEXT NOT NULL,
    serviceTitle TEXT NOT NULL,
    employerId TEXT NOT NULL,
    applicationDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'pending',
    FOREIGN KEY (workId) REFERENCES works(id),
    FOREIGN KEY (applicantId) REFERENCES users(id),
    FOREIGN KEY (employerId) REFERENCES users(id)
)`);

console.log('✅ Work applications tábla inicializálva');

// UUID generálás helper function
function uuidv4() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}



// Add hozzá a server.js fájlhoz a works tábla létrehozását és a route-okat

// Works tábla létrehozása
db.run(`CREATE TABLE IF NOT EXISTS works (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    employerName TEXT NOT NULL,
    employerID TEXT NOT NULL,
    employeeID TEXT,
    wage REAL NOT NULL,
    paymentType TEXT NOT NULL,
    statusText TEXT DEFAULT 'Publikálva',
    startTime DATETIME,
    endTime DATETIME,
    duration INTEGER,
    progress REAL DEFAULT 0.0,
    location TEXT,
    skills TEXT DEFAULT '[]',
    category TEXT,
    description TEXT,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employerID) REFERENCES users(id)
)`);

console.log('✅ Works tábla inicializálva');

// WORK PUBLIKÁLÁS
// server.js - /api/works/publish endpoint frissítése

// server.js - /api/works/publish endpoint javítása

app.post('/api/works/publish', (req, res) => {
    try {
        const {
            id, title, employerName, employerID, employeeID,
            wage, paymentType, statusText, startTime, endTime,
            duration, progress, location, skills, category, description
        } = req.body;

        console.log('\n🎯 ÚJ MUNKA ÉRKEZETT:');
        console.log('  - ID:', id);
        console.log('  - Cím:', title);
        console.log('  - Munkáltató:', employerName);
        console.log('  - Munkáltató ID:', employerID);
        console.log('  - Bér:', wage, 'Ft');
        console.log('  - Fizetési mód:', paymentType);
        console.log('  - Hely:', location);
        console.log('  - Készségek:', skills);
        console.log('  - Leírás:', description);
        console.log('  - Státusz:', statusText);

        // Validáció
        if (!id || !title || !employerName || !employerID || !wage || !paymentType) {
            console.log('❌ Hiányzó adatok!');
            return res.status(400).json({
                message: 'Hiányzó kötelező adatok.'
            });
        }

        // Ellenőrizzük, hogy létezik-e a user - MÓDOSÍTOTT RÉSZ
        db.get('SELECT id FROM users WHERE id = ?', [employerID], (err, user) => {
            if (err) {
                console.error('❌ Adatbázis hiba:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            if (!user) {
                console.log('⚠️  Figyelem: Felhasználó nem található ezzel az ID-vel:', employerID);
                console.log('📝 Ellenőrizzük, hogy létezik-e a felhasználó más formátumban...');
                
                // Alternatív keresés - UUID formátum ellenőrzése
                db.get('SELECT id FROM users', (err, allUsers) => {
                    if (err) {
                        console.error('❌ Hiba a felhasználók lekérésekor:', err);
                    } else {
                        console.log('📋 Elérhető felhasználók:', allUsers);
                    }
                });

                // INGYENES MEGOLDÁS: Elfogadjuk a munkát anélkül, hogy a user létezne
                // (Ez lehetővé teszi a tesztelést, de éles környezetben ezt meg kell oldani)
                console.log('✅ Munka elfogadva (fejlesztési mód)');
                insertWork();
                return;
            }

            // Ha a user létezik, beszúrjuk a munkát
            insertWork();
        });

        function insertWork() {
            // Munka beszúrása
            const stmt = db.prepare(`
                INSERT INTO works (
                    id, title, employerName, employerID, employeeID,
                    wage, paymentType, statusText, startTime, endTime,
                    duration, progress, location, skills, category, description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `);

            stmt.run(
                id,
                title,
                employerName,
                employerID, // Ezt most mindig elfogadjuk
                employeeID || null,
                wage,
                paymentType,
                statusText || 'Publikálva',
                startTime || null,
                endTime || null,
                duration || null,
                progress || 0.0,
                location || '',
                JSON.stringify(skills || []),
                category || '',
                description || '',
                function(err) {
                    if (err) {
                        console.error('❌ Hiba a munka beszúrása során:', err);
                        return res.status(500).json({
                            message: 'Hiba a munka publikálásakor'
                        });
                    }

                    console.log('✅ MUNKA SIKERESEN FELTÖLTVE!');
                    console.log('   - ID:', id);
                    console.log('   - Cím:', title);
                    console.log('   - Adatbázis ID:', this.lastID);

                    res.status(201).json({
                        message: 'Munka sikeresen publikálva',
                        workId: id
                    });
                }
            );

            stmt.finalize();
        }

    } catch (error) {
        console.error('❌ Publish work error:', error);
        res.status(500).json({
            message: 'Szerver hiba a munka publikálása során.',
            error: error.message
        });
    }
});

// MUNKÁK LEKÉRÉSE
// server.js - Javított /api/works endpoint

// MUNKÁK LEKÉRÉSE - JAVÍTOTT VERZIÓ
app.get('/api/works', (req, res) => {
    try {
        const { employerID, limit = 50 } = req.query;

        let query = `
            SELECT 
                w.id,
                w.title,
                COALESCE(u.name, w.employerName) as employerName,
                w.employerID,
                w.employeeID,
                w.wage,
                w.paymentType,
                w.statusText,
                w.startTime,
                w.endTime,
                w.duration,
                w.progress,
                w.location,
                w.skills,
                w.category,
                w.description,
                w.createdAt,
                w.updatedAt,
                u.profileImageUrl as employerProfileImage
            FROM works w
            LEFT JOIN users u ON w.employerID = u.id
            WHERE 1=1
        `;
        let params = [];

        if (employerID) {
            query += ' AND w.employerID = ?';
            params.push(employerID);
        }

        query += ' ORDER BY w.createdAt DESC LIMIT ?';
        params.push(parseInt(limit));

        console.log('📥 Works lekérdezés:', query);
        console.log('📥 Paraméterek:', params);

        db.all(query, params, (err, rows) => {
            if (err) {
                console.error('❌ Database error:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            console.log(`📥 ${rows.length} munka lekérdezve`);

            // Részletes debug információk
            rows.forEach((row, index) => {
                console.log(`  Munka ${index + 1}:`);
                console.log(`    - ID: ${row.id}`);
                console.log(`    - Cím: ${row.title}`);
                console.log(`    - Munkáltató név: ${row.employerName}`);
                console.log(`    - Munkáltató ID: ${row.employerID}`);
                console.log(`    - Bér: ${row.wage}`);
                console.log(`    - Hely: ${row.location}`);
            });

            const works = rows.map(row => {
                // Biztosítjuk, hogy minden kötelező mező legyen értéke
                const work = {
                    id: row.id || '',
                    title: row.title || 'Névtelen munka',
                    employerName: row.employerName || 'Ismeretlen munkáltató',
                    employerID: row.employerID || '',
                    employeeID: row.employeeID || null,
                    wage: row.wage || 0,
                    paymentType: row.paymentType || 'Ismeretlen',
                    statusText: row.statusText || 'Publikálva',
                    startTime: row.startTime || null,
                    endTime: row.endTime || null,
                    duration: row.duration || null,
                    progress: row.progress || 0.0,
                    location: row.location || '',
                    skills: JSON.parse(row.skills || '[]'),
                    category: row.category || '',
                    description: row.description || '',
                    createdAt: row.createdAt || new Date().toISOString(),
                    updatedAt: row.updatedAt || new Date().toISOString(),
                    employerProfileImage: row.employerProfileImage || null
                };
                
                console.log(`  🔧 Feldolgozott munka: ${work.title} - ${work.employerName}`);
                return work;
            });

            res.status(200).json({
                works: works,
                count: works.length
            });
        });

    } catch (error) {
        console.error('❌ Get works error:', error);
        res.status(500).json({
            message: 'Szerver hiba a munkák lekérése során.'
        });
    }
});
// server.js - Add hozzá ezeket a végpontokat

// MUNKA LEKÉRÉSE ID ALAPJÁN
app.get('/api/works/:workId', (req, res) => {
    try {
        const { workId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            db.get(
                `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
                 FROM works w
                 LEFT JOIN users u ON w.employerID = u.id
                 WHERE w.id = ?`,
                [workId],
                (err, row) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!row) {
                        return res.status(404).json({ message: 'Munka nem található' });
                    }

                    const work = {
                        id: row.id,
                        title: row.title,
                        employerName: row.employerName,
                        employerID: row.employerID,
                        employeeID: row.employeeID,
                        wage: row.wage,
                        paymentType: row.paymentType,
                        statusText: row.statusText,
                        startTime: row.startTime,
                        endTime: row.endTime,
                        duration: row.duration,
                        progress: row.progress,
                        location: row.location,
                        skills: JSON.parse(row.skills || '[]'),
                        category: row.category,
                        description: row.description,
                        createdAt: row.createdAt,
                        updatedAt: row.updatedAt,
                        employerProfileImage: row.employerProfileImage
                    };

                    res.status(200).json({ work });
                }
            );
        });

    } catch (error) {
        console.error('Get work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// AKTÍV MUNKA LEKÉRÉSE DOLGOZÓ SZÁMÁRA
app.get('/api/works/employee/:employeeId/active', (req, res) => {
    try {
        const { employeeId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Aktív munka keresése (Folyamatban státuszú)
            db.get(
                `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
                 FROM works w
                 LEFT JOIN users u ON w.employerID = u.id
                 WHERE w.employeeID = ? AND w.statusText = 'Folyamatban'`,
                [employeeId],
                (err, row) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!row) {
                        return res.status(404).json({ message: 'Nincs aktív munka' });
                    }

                    const work = {
                        id: row.id,
                        title: row.title,
                        employerName: row.employerName,
                        employerID: row.employerID,
                        employeeID: row.employeeID,
                        wage: row.wage,
                        paymentType: row.paymentType,
                        statusText: row.statusText,
                        startTime: row.startTime,
                        endTime: row.endTime,
                        duration: row.duration,
                        progress: row.progress,
                        location: row.location,
                        skills: JSON.parse(row.skills || '[]'),
                        category: row.category,
                        description: row.description,
                        createdAt: row.createdAt,
                        updatedAt: row.updatedAt,
                        employerProfileImage: row.employerProfileImage
                    };

                    res.status(200).json({ work });
                }
            );
        });

    } catch (error) {
        console.error('Get active work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// MUNKA HOZZÁRENDELÉSE DOLGOZÓHOZ
app.put('/api/works/:workId/assign', (req, res) => {
    try {
        const { workId } = req.params;
        const { employeeID, statusText } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a munka létezik-e
            db.get('SELECT * FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                // Ellenőrizzük, hogy a dolgozó létezik-e
                db.get('SELECT id FROM users WHERE id = ?', [employeeID], (err, employee) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!employee) {
                        return res.status(404).json({ message: 'Dolgozó nem található' });
                    }

                    // Frissítjük a munkát
                    db.run(
                        'UPDATE works SET employeeID = ?, statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [employeeID, statusText, workId],
                        function(err) {
                            if (err) {
                                console.error('Assign employee error:', err);
                                return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Dolgozó sikeresen hozzárendelve a munkához',
                                workId: workId,
                                employeeID: employeeID,
                                statusText: statusText
                            });

                            console.log('✅ Dolgozó hozzárendelve:', { workId, employeeID, statusText });
                        }
                    );
                });
            });
        });

    } catch (error) {
        console.error('Assign employee error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

app.put('/api/works/:workId/status', (req, res) => {
    try {
        const { workId } = req.params;
        const { statusText, employerID } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a munka létezik-e
            db.get('SELECT * FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                // Ellenőrizzük, hogy a munkáltató létezik-e
                db.get('SELECT id FROM users WHERE id = ?', [employerID], (err, employer) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!employer) {
                        return res.status(404).json({ message: 'Munkáltató nem található' });
                    }

                    // Frissítjük a munka státuszát
                    db.run(
                        'UPDATE works SET statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [statusText, workId],
                        function(err) {
                            if (err) {
                                console.error('Update work status error:', err);
                                return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Munka státusza sikeresen frissítve',
                                workId: workId,
                                statusText: statusText
                            });

                            console.log('✅ Munka státusz frissítve:', { workId, statusText });
                        }
                    );
                });
            });
        });

    } catch (error) {
        console.error('Update work status error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


// MANUÁLIS KÓD ALAPJÁN MUNKA LEKÉRÉSE
app.get('/api/works/code/:manualCode', (req, res) => {
    try {
        const { manualCode } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Kód alapján munka keresése
            // A kód az első 8 karaktere a work ID-nek
            db.all('SELECT id FROM works', (err, allWorks) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                // Keresünk egy munkát, aminek az ID-jének első 8 karaktere megegyezik a kóddal
                const matchingWork = allWorks.find(work =>
                    work.id.substring(0, 8) === manualCode
                );

                if (!matchingWork) {
                    return res.status(404).json({ message: 'Nem található munka ezzel a kóddal' });
                }

                // Lekérjük a teljes munka adatokat
                db.get(
                    `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
                     FROM works w
                     LEFT JOIN users u ON w.employerID = u.id
                     WHERE w.id = ?`,
                    [matchingWork.id],
                    (err, row) => {
                        if (err) {
                            console.error('Database error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        if (!row) {
                            return res.status(404).json({ message: 'Munka nem található' });
                        }

                        const work = {
                            id: row.id,
                            title: row.title,
                            employerName: row.employerName,
                            employerID: row.employerID,
                            employeeID: row.employeeID,
                            wage: row.wage,
                            paymentType: row.paymentType,
                            statusText: row.statusText,
                            startTime: row.startTime,
                            endTime: row.endTime,
                            duration: row.duration,
                            progress: row.progress,
                            location: row.location,
                            skills: JSON.parse(row.skills || '[]'),
                            category: row.category,
                            description: row.description,
                            createdAt: row.createdAt,
                            updatedAt: row.updatedAt,
                            employerProfileImage: row.employerProfileImage
                        };

                        res.status(200).json({ work });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Get work by code error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// DEBUG: Token ellenőrző végpont
app.get('/api/auth/debug-token', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({
                message: 'Nincs token',
                hasToken: false
            });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({
                    message: 'Érvénytelen token',
                    isValid: false,
                    error: err.message
                });
            }

            res.status(200).json({
                message: 'Token érvényes',
                isValid: true,
                userId: decoded.id,
                expires: decoded.exp
            });
        });

    } catch (error) {
        console.error('Debug token error:', error);
        res.status(500).json({
            message: 'Szerver hiba',
            error: error.message
        });
    }
});
// MUNKA TÖRLÉSE
app.put('/api/works/:id', (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [id], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== updates.employerID) {
                    return res.status(403).json({ message: 'Nincs jogosultság a munka frissítéséhez' });
                }

                // Megengedett mezők
                const allowedFields = ['title', 'wage', 'paymentType', 'statusText', 'location', 'skills', 'category', 'description'];
                const setClause = [];
                const values = [];

                Object.keys(updates).forEach(key => {
                    if (allowedFields.includes(key)) {
                        if (key === 'skills') {
                            setClause.push(`${key} = ?`);
                            values.push(JSON.stringify(updates[key]));
                        } else {
                            setClause.push(`${key} = ?`);
                            values.push(updates[key]);
                        }
                    }
                });

                if (setClause.length === 0) {
                    return res.status(400).json({ message: 'Nincs érvényes frissítendő mező' });
                }

                setClause.push('updatedAt = CURRENT_TIMESTAMP');
                values.push(id);

                const query = `UPDATE works SET ${setClause.join(', ')} WHERE id = ?`;

                db.run(query, values, function(err) {
                    if (err) {
                        console.error('Update work error:', err);
                        return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                    }

                    res.status(200).json({
                        message: 'Munka sikeresen frissítve',
                        workId: id
                    });

                    console.log('✅ Munka frissítve:', id);
                });
            });
        });

    } catch (error) {
        console.error('Update work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.get('/api/works/:id', (req, res) => {
    try {
        const { id } = req.params;

        db.get(
            `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
             FROM works w
             LEFT JOIN users u ON w.employerID = u.id
             WHERE w.id = ?`,
            [id],
            (err, row) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!row) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                const work = {
                    id: row.id,
                    title: row.title,
                    employerName: row.employerName,
                    employerID: row.employerID,
                    employeeID: row.employeeID,
                    wage: row.wage,
                    paymentType: row.paymentType,
                    statusText: row.statusText,
                    startTime: row.startTime,
                    endTime: row.endTime,
                    duration: row.duration,
                    progress: row.progress,
                    location: row.location,
                    skills: JSON.parse(row.skills || '[]'),
                    category: row.category,
                    description: row.description,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt,
                    employerProfileImage: row.employerProfileImage
                };

                res.status(200).json({ work });
            }
        );

    } catch (error) {
        console.error('Get work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.put('/api/works/:id/status', (req, res) => {
    try {
        const { id } = req.params;
        const { statusText, employerID } = req.body;
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [id], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== employerID) {
                    return res.status(403).json({ message: 'Nincs jogosultság a státusz frissítéséhez' });
                }

                // Frissítjük a státuszt
                db.run(
                    'UPDATE works SET statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                    [statusText, id],
                    function(err) {
                        if (err) {
                            console.error('Status update error:', err);
                            return res.status(500).json({ message: 'Hiba a státusz frissítésekor' });
                        }

                        res.status(200).json({
                            message: 'Munka státusza sikeresen frissítve',
                            workId: id,
                            statusText: statusText
                        });

                        console.log('✅ Munka státusz frissítve:', { id, statusText });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Update work status error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// Szerver indítása
const PORT = process.env.PORT || 3000;
const HOST = 'http://192.168.1.100:3000/api';
app.listen(PORT, () => {
    console.log(`🚀 SkillTrade szerver fut a http://localhost:${PORT} címen`);
    console.log(`📊 SQLite adatbázis: ${DB_PATH}`);
});
